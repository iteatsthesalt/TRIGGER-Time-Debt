## Active statuses on one battler (Combat Laws Bible §12). Durations are seconds of battle time
## or turns (the bearer's own actions). The pipeline queries the modifiers; the coordinator ticks.
class_name StatusComponent
extends Node

signal status_added(id: StringName, stacks: int)
signal status_removed(id: StringName)
signal periodic(id: StringName, stacks: int)

## id -> {seconds: float, turns: int, stacks: int, data: Dictionary, period_accum: float}
var statuses: Dictionary = {}

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
	var cap: int = int(MAX_STACKS.get(id, 99))
	if statuses.has(id):
		var s: Dictionary = statuses[id]
		s["seconds"] = seconds
		s["turns"] = turns
		s["stacks"] = mini(cap, int(s["stacks"]) + add_stacks)
		for k in extra.keys():
			s["data"][k] = extra[k]
		status_added.emit(id, int(s["stacks"]))
		return
	statuses[id] = {"seconds": seconds, "turns": turns, "stacks": mini(cap, maxi(1, add_stacks)), "data": extra.duplicate(), "period_accum": 0.0}
	status_added.emit(id, mini(cap, add_stacks))


func remove(id: StringName) -> void:
	if statuses.erase(id):
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


## Cleanse everything that is a debuff and not permanent-by-design.
func cleanse() -> void:
	for id in ids():
		if not [&"light_stack", &"reinforced", &"ens_ring", &"glass_ward", &"ruin_infused", &"ward", &"concerned", &"ruin"].has(id):
			remove(id)


## Battle-time tick. Emits periodic() for statuses with a period.
func tick(dt: float) -> void:
	if dt <= 0.0:
		return
	for id in ids():
		var s: Dictionary = statuses[id]
		if PERIODS.has(id):
			s["period_accum"] = float(s["period_accum"]) + dt
			var period: float = float(PERIODS[id])
			while float(s["period_accum"]) >= period:
				s["period_accum"] = float(s["period_accum"]) - period
				periodic.emit(id, int(s["stacks"]))
		if float(s["seconds"]) > 0.0:
			s["seconds"] = float(s["seconds"]) - dt
			if float(s["seconds"]) <= 0.0:
				remove(id)


## Called when the bearer finishes an action: turn-counted statuses count down.
func on_turn_taken() -> void:
	for id in ids():
		var s: Dictionary = statuses[id]
		if int(s["turns"]) > 0:
			s["turns"] = int(s["turns"]) - 1
			if int(s["turns"]) <= 0:
				remove(id)


# ---------------------------------------------------------------- modifiers

func gauge_multiplier() -> float:
	var m: float = 1.0
	if has(&"time_stop"):
		return 0.0
	if has(&"mercury_slow"):
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


func movement_multiplier() -> float:
	var m: float = 1.0
	if has(&"mercury_slow") or has(&"ash_field") or has(&"slow"):
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


func hitch_seconds() -> float:
	var h: float = 0.0
	if has(&"magnetized") or has(&"knock_static"):
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
