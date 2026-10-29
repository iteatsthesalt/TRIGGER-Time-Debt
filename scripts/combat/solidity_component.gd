## Sera's solidity (Combat Laws Bible §10.2): persistent Translucency Debt and per-battle solidity,
## with the 80/60/40/20 thresholds crossed once per battle on the way down.
class_name SolidityComponent
extends Node

signal solidity_changed(value: float)
signal threshold_crossed(threshold: float)
signal phased_out(turns: int)
signal phased_in
signal debt_changed(value: float)

## Persistent Translucency Debt (0–55 outside scripted scenes; the Heart sets solidity to 60).
@export var debt: float = 0.0
var battle_start: float = 100.0
var solidity: float = 100.0
var thresholds_crossed: Array[float] = []
var phased_turns_left: int = 0
var spent_this_battle: float = 0.0
## Scripted override of the battle-start solidity (the Heart: 60).
var forced_start: float = -1.0
## Set by the coordinator while a party gauge has been parked at 99.0 for 3 s or more.
var voluntary_window: bool = false
## Record of the last phase-out: "voluntary", "forced" or "".
var last_phase_kind: String = ""
var voluntary_phase_count: int = 0
var token_duplicate_available: bool = false
var hold_step_seconds: float = CombatConstants.SERA_HOLD_BREAK_EXTENSION_S
var permanent_baseline: float = 0.0


func begin_battle() -> void:
	battle_start = forced_start if forced_start > 0.0 else clampf(100.0 - debt - permanent_baseline, 0.0, 100.0)
	solidity = battle_start
	thresholds_crossed.clear()
	phased_turns_left = 0
	spent_this_battle = 0.0
	token_duplicate_available = false
	solidity_changed.emit(solidity)


func ghost_layers() -> int:
	if solidity <= 40.0:
		return 7
	if solidity <= 60.0:
		return 5
	if solidity <= 80.0:
		return 3
	return 1


func is_phased() -> bool:
	return phased_turns_left > 0


func can_spend(pct: float) -> bool:
	return solidity > 0.0 or pct <= 0.0


## Spend solidity. Returns the thresholds crossed by this spend (in order).
## If solidity is already 0 the cost is returned as `overflow` for Crono to pay 1:1 (§10.2).
func spend(pct: float) -> Dictionary:
	var crossed: Array[float] = []
	var overflow: float = 0.0
	if pct <= 0.0:
		return {"crossed": crossed, "overflow": 0.0}
	if solidity <= 0.0:
		return {"crossed": crossed, "overflow": pct}
	var before: float = solidity
	solidity = maxf(0.0, solidity - pct)
	if before - pct < 0.0:
		overflow = pct - before
	spent_this_battle += before - solidity
	for t in CombatConstants.SERA_THRESHOLDS:
		if before > t and solidity <= t and not thresholds_crossed.has(t):
			thresholds_crossed.append(t)
			crossed.append(t)
			threshold_crossed.emit(t)
			if is_equal_approx(t, 60.0):
				token_duplicate_available = true
			if is_equal_approx(t, CombatConstants.SERA_PHASE_THRESHOLD):
				_phase_out()
	solidity_changed.emit(solidity)
	return {"crossed": crossed, "overflow": overflow}


func _phase_out() -> void:
	phased_turns_left = CombatConstants.SERA_PHASE_TURNS
	if voluntary_window:
		last_phase_kind = "voluntary"
		voluntary_phase_count += 1
	else:
		last_phase_kind = "forced"
	phased_out.emit(phased_turns_left)


## A turn of hers passes while phased (her gauge would have filled).
func on_phased_turn() -> void:
	if phased_turns_left > 0:
		phased_turns_left -= 1
		if phased_turns_left == 0:
			phased_in.emit()


## A turn spent without a TACHYON skill gives back 2, up to the battle-start value.
func on_turn_without_tachyon() -> void:
	solidity = minf(battle_start, solidity + CombatConstants.SERA_TURN_REGEN)
	solidity_changed.emit(solidity)


func restore(pct: float) -> void:
	solidity = minf(battle_start, solidity + pct)
	solidity_changed.emit(solidity)


func set_solidity(value: float) -> void:
	solidity = clampf(value, 0.0, 100.0)
	solidity_changed.emit(solidity)


## End of battle: +1 Debt interest per full 20% spent.
func end_battle() -> void:
	var interest: float = floor(spent_this_battle / 20.0)
	if interest > 0.0:
		add_debt(interest)
	phased_turns_left = 0
	spent_this_battle = 0.0


func add_debt(amount: float) -> void:
	debt = clampf(debt + amount, 0.0, CombatConstants.SERA_DEBT_CAP)
	debt_changed.emit(debt)


## Lotus-pond kintsugi, Moon Meditation, the Time Egg at camp.
func repair_debt(amount: float) -> void:
	debt = maxf(permanent_baseline, debt - amount)
	debt_changed.emit(debt)


func on_gate_jump() -> void:
	add_debt(CombatConstants.SERA_DEBT_PER_JUMP)


static func of(actor: Node) -> SolidityComponent:
	if actor == null:
		return null
	return actor.get_node_or_null("SolidityComponent") as SolidityComponent
