## Active statuses on one battler (Combat Laws Bible §12). Durations are seconds of battle time
## or turns (the bearer's own actions). The pipeline queries the modifiers; the coordinator ticks.
## "N turns" counts the bearer's actions after the one that gave it the status: a status added while the
## bearer's own action is in progress (begin_action .. on_turn_taken: Prism Guard, Rooted, Fragile) is not
## counted down by that action (DECISIONS "Turn statuses").
## StatusRules decides how a status lands (boss rules, Ruin, Stripped); StatusTicks answers `periodic`.
## A status whose data carries an "undo" Callable runs it when it is removed (expiry, cleanse, clear_all):
## Stripped and NULL's strip give their plates back that way.
class_name StatusComponent
extends Node

signal status_added(id: StringName, stacks: int)
signal status_removed(id: StringName)
signal periodic(id: StringName, stacks: int)

## id -> {seconds: float, turns: int, stacks: int, data: Dictionary, period_accum: float}
var statuses: Dictionary = {}
## id -> stack cap for this battle, over MAX_STACKS (Porcelain Silence's Ruin scaling, RuinRules).
var cap_overrides: Dictionary = {}
## True from begin_action until the action's on_turn_taken: statuses added meanwhile are "fresh".
var acting: bool = false

## Periodic statuses: id -> seconds between ticks.
const PERIODS := {
	&"grief": CombatConstants.GRIEF_PERIOD_S,
	&"laugh_track_drain": 8.0,
	&"oil_dot": 2.0,
	&"ink_dot": 1.0,
	&"bleed": 1.0,
	&"burn": 1.0,
	&"regen": 2.0,
}
## Mycelia Time Lapse (§11.12): periodic statuses on its targets tick this many times faster ("300%").
const TIME_LAPSE_RATE := 3.0
const MAX_STACKS := {
	&"grief": CombatConstants.GRIEF_MAX_STACKS,
	&"mercury_slow": CombatConstants.MERCURY_MAX_STACKS,
	&"ruin": CombatConstants.RUIN_STACK_CAP,
	&"light_stack": CombatConstants.LIGHT_STACK_CAP,
	&"anti_vaelos": 20,
}


func has(id: StringName) -> bool:
	return statuses.has(id)


func stacks(id: StringName) -> int:
	return int(statuses.get(id, {}).get("stacks", 0))


func data(id: StringName) -> Dictionary:
	return statuses.get(id, {}).get("data", {})


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in statuses.keys():
		out.append(k)
	return out


## Apply a status. seconds < 0 and turns < 0 mean "until removed".
func add(id: StringName, seconds: float = -1.0, turns: int = -1, add_stacks: int = 1, extra: Dictionary = {}) -> void:
	var cap: int = int(cap_overrides.get(id, MAX_STACKS.get(id, 99)))
	if statuses.has(id):
		var s: Dictionary = statuses[id]
		s["seconds"] = seconds
		s["turns"] = turns
		s["fresh"] = acting
		s["stacks"] = mini(cap, int(s["stacks"]) + add_stacks)
		for k in extra.keys():
			s["data"][k] = extra[k]
		status_added.emit(id, int(s["stacks"]))
		return
	statuses[id] = {"seconds": seconds, "turns": turns, "stacks": mini(cap, maxi(1, add_stacks)), "data": extra.duplicate(), "period_accum": 0.0, "fresh": acting}
	status_added.emit(id, mini(cap, add_stacks))


func remove(id: StringName) -> void:
	if not statuses.has(id):
		return
	var undo: Variant = statuses[id]["data"].get("undo", null)
	statuses.erase(id)
	if undo is Callable and (undo as Callable).is_valid():
		(undo as Callable).call()
	status_removed.emit(id)


func remove_stacks(id: StringName, n: int) -> void:
	if not statuses.has(id):
		return
	var s: Dictionary = statuses[id]
	s["stacks"] = int(s["stacks"]) - n
	if int(s["stacks"]) <= 0:
		remove(id)


func clear_all() -> void:
	for id in ids():
		remove(id)


## What a cleanse leaves: buffs that last past a battle, Concerned (until camp, §12.3) and Ruin, which only
## thaws (§12.2; RuinRules clears it when the battle ends). Ens rings live in the coordinator, not here.
const CLEANSE_KEEPS: Array[StringName] = [
	&"light_stack", &"reinforced", &"glass_ward", &"ruin_infused", &"ward", &"concerned_target", &"ruin",
]


## Cleanse everything that is a debuff and not permanent-by-design.
func cleanse() -> void:
	for id in ids():
		if not CLEANSE_KEEPS.has(id):
			remove(id)


## Battle-time tick. Emits periodic() for statuses with a period.
func tick(dt: float) -> void:
	if dt <= 0.0:
		return
	var period_dt: float = dt * (TIME_LAPSE_RATE if has(&"time_lapse") else 1.0)  # Mycelia Time Lapse
	for id in ids():
		var s: Dictionary = statuses[id]
		if PERIODS.has(id):
			s["period_accum"] = float(s["period_accum"]) + period_dt
			var period: float = float(PERIODS[id])
			while float(s["period_accum"]) >= period:
				s["period_accum"] = float(s["period_accum"]) - period
				periodic.emit(id, int(s["stacks"]))
		if float(s["seconds"]) > 0.0:
			s["seconds"] = float(s["seconds"]) - dt
			if float(s["seconds"]) <= 0.0:
				remove(id)


## The bearer's action begins (its decision window opened, or it joins a Dual): what it gives itself from now
## until on_turn_taken is not counted down by this action.
func begin_action() -> void:
	acting = true


## Called when the bearer finishes an action: turn-counted statuses count down, except those this action gave.
func on_turn_taken() -> void:
	acting = false
	for id in ids():
		var s: Dictionary = statuses[id]
		if bool(s.get("fresh", false)):
			s["fresh"] = false
			continue
		if int(s["turns"]) > 0:
			s["turns"] = int(s["turns"]) - 1
			if int(s["turns"]) <= 0:
				remove(id)


# ---------------------------------------------------------------- modifiers

func gauge_multiplier() -> float:
	var m: float = 1.0
	if has(&"time_stop") or has(&"shutdown"):  # Prometheus Overload's shutdown: the next gauge starts below zero
		return 0.0
	if has(&"mercury_slow") or has(&"ash_inhale"):  # Ash Inhale is one SLOW stack (§12.2)
		m *= CombatConstants.MERCURY_SLOW
	if has(&"chrono_lag"):
		m *= CombatConstants.CHRONO_LAG
	if has(&"displaced") or has(&"heavy_drift") or has(&"knock_static"):
		m *= CombatConstants.HEAVY_DRIFT
	if has(&"haste"):
		m *= 1.5
	if has(&"slow"):
		m *= 0.5
	if has(&"ghost_ring"):
		m *= 1.15
	if has(&"rubber_chicken"):
		m *= 0.6
	if has(&"pollen_haze"):
		m *= 0.8
	return m


## Movement range in battle (cmd_move): Mercury SLOW, Ash Inhale's SLOW stack, the RUIN ash field, SLOW.
func movement_multiplier() -> float:
	var m: float = 1.0
	if has(&"mercury_slow") or has(&"ash_inhale") or has(&"ash_field") or has(&"slow"):
		m *= 0.5
	return m


## Accuracy modifier (additive, 0 = normal).
func accuracy_mod() -> float:
	var a: float = 0.0
	if has(&"blind"):
		a += CombatConstants.BLIND_ACCURACY
	if has(&"ink_blot"):
		a += -0.60
	if has(&"ash_inhale"):
		a += -0.20
	if has(&"white_noise_blind"):
		a += -1.0
	return a


func evasion_bonus() -> float:
	var e: float = 0.0
	if has(&"white_noise_blind") or has(&"vhs_blind_self"):
		e += 0.30
	if has(&"phase_evasion"):
		e += 0.50
	return e


func def_multiplier(is_metal: bool = false) -> float:
	var m: float = 1.0
	if has(&"corroded") and bool(data(&"corroded").get("def", false)):
		m *= 0.9
	if has(&"magnetized") and is_metal:
		m *= 0.9
	if has(&"anti_vaelos"):
		m *= maxf(0.1, 1.0 - 0.05 * stacks(&"anti_vaelos"))
	if has(&"core_lattice"):
		m *= 1.3
	return m


func damage_taken_multiplier() -> float:
	var m: float = 1.0
	if has(&"fragile"):
		m *= 1.5
	if has(&"prism_guard"):
		m *= 0.6
	if has(&"rooted"):
		m *= 1.0 - CombatConstants.PHOTOSYNTHETIC_DR
	if has(&"marked"):
		m *= 1.25
	return m


func healing_multiplier() -> float:
	var m: float = 1.0
	if has(&"corroded"):
		m *= 0.5
	if has(&"concerned_target"):
		m *= 1.5
	return m


func can_cast_techs() -> bool:
	return not has(&"silence")


func can_wind_up() -> bool:
	return not has(&"jammed")


func is_untargetable() -> bool:
	return has(&"phased") or has(&"cloaked") or has(&"untargetable")


## The hitch (late start) of the bearer's action (§12.2): 0.5 s under Magnetized or Gramophone Resonance's
## hitched, which hitch the 'next action' (turns 2, read after the turn's countdown: DECISIONS "Readings chosen"),
## or under Knock-Static, which hitches every action of its turns: EnemyBrain reads it when the action is chosen,
## before the countdown, and passes it as `stepped`; 0.5 s more from Mercury SLOW's second stack.
func hitch_seconds(stepped: bool = false) -> float:
	var h: float = 0.0
	if stepped or has(&"magnetized") or has(&"knock_static") or has(&"hitched"):
		h += 0.5
	if has(&"mercury_slow") and stacks(&"mercury_slow") >= 2:
		h += 0.5
	return h


static func of(actor: Node) -> StatusComponent:
	if actor == null:
		return null
	if actor is StatusComponent:
		return actor as StatusComponent
	return actor.get_node_or_null("StatusComponent") as StatusComponent
