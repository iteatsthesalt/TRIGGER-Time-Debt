## Crono's Time Debt (Combat Laws Bible §10.1): three HP layers and the crack state.
## max_hp = base × (0.5 + 0.5 × integrity/100) × (1 − battle_strain − camp_strain − 0.15 × ruin), floor 10%.
class_name TimeDebtComponent
extends Node

signal integrity_changed(value: float)
signal strain_changed(battle: float, camp: float)
signal crack_state_changed(state: int)

enum CrackState { PRISTINE, HAIRLINE, GALAXY, FLATLINE }

## Persistent porcelain integrity, 0–100.
@export var integrity: float = 100.0
## Fractions of base max HP (0–1).
var battle_strain: float = 0.0
var camp_strain: float = 0.0
var ruin_stacks: int = 0
var ruin_cap: int = CombatConstants.RUIN_STACK_CAP
## Gate jumps left at reduced accrual (Reinforced).
var reinforced_jumps: int = 0
var reinforced_factor: float = CombatConstants.REINFORCED_REDUCTION
## Battle-scoped: Ens ring nulls debt costs for 5 s.
var debt_null_left: float = 0.0
## The strain taken in the current battle, for the interest rule (−1 integrity per full 20%).
var strain_this_battle: float = 0.0
## Heart hazard: ASTRAL casts cost more.
var cost_multiplier: float = 1.0
var _last_state: int = -1


func max_hp_factor() -> float:
	var ceiling: float = 0.5 + 0.5 * clampf(integrity, 0.0, 100.0) / 100.0
	var f: float = ceiling * (1.0 - battle_strain - camp_strain - CombatConstants.RUIN_STACK * float(ruin_stacks))
	return maxf(CombatConstants.CRONO_CEILING_FLOOR, f)


## The crack state reads the worse of integrity and current HP as a % of *base* max HP.
func crack_state(hp_ratio_of_base: float) -> int:
	var worst: float = minf(integrity, hp_ratio_of_base * 100.0)
	var s: int
	if worst <= 0.0:
		s = CrackState.FLATLINE
	elif worst <= 20.0:
		s = CrackState.GALAXY
	elif worst <= 60.0:
		s = CrackState.HAIRLINE
	else:
		s = CrackState.PRISTINE
	if s != _last_state:
		_last_state = s
		crack_state_changed.emit(s)
	return s


func is_hairline_or_worse(hp_ratio_of_base: float) -> bool:
	return crack_state(hp_ratio_of_base) >= CrackState.HAIRLINE


## Pay a technique's Battle Strain (fraction of base max HP). Returns what was actually paid.
func pay_battle_strain(fraction: float) -> float:
	if debt_null_left > 0.0 or fraction <= 0.0:
		return 0.0
	var cost: float = fraction * cost_multiplier
	var before: float = max_hp_factor()
	battle_strain = minf(1.0, battle_strain + cost)
	strain_this_battle += cost
	strain_changed.emit(battle_strain, camp_strain)
	return before - max_hp_factor()


func pay_camp_strain(fraction: float) -> void:
	if fraction <= 0.0:
		return
	camp_strain = minf(1.0, camp_strain + fraction)
	strain_changed.emit(battle_strain, camp_strain)


func restore_battle_strain(fraction: float) -> void:
	battle_strain = maxf(0.0, battle_strain - fraction)
	strain_changed.emit(battle_strain, camp_strain)


func pay_integrity(amount: float) -> void:
	if amount <= 0.0:
		return
	integrity = clampf(integrity - amount, 0.0, 100.0)
	integrity_changed.emit(integrity)


func repair_integrity(amount: float) -> void:
	if amount <= 0.0:
		return
	integrity = clampf(integrity + amount, 0.0, 100.0)
	integrity_changed.emit(integrity)


## A new gate jump along the story thread: the collarbone (§10.1), halved by Reinforced.
func on_gate_jump() -> void:
	var cost: float = CombatConstants.CRONO_JUMP_COLLARBONE
	if reinforced_jumps > 0:
		cost *= (1.0 - reinforced_factor)
		reinforced_jumps -= 1
	pay_integrity(cost)


func add_ruin(stacks: int = 1) -> void:
	ruin_stacks = mini(ruin_cap, ruin_stacks + stacks)
	strain_changed.emit(battle_strain, camp_strain)


func thaw_ruin(stacks: int = 1) -> void:
	ruin_stacks = maxi(0, ruin_stacks - stacks)
	strain_changed.emit(battle_strain, camp_strain)


## End of battle: strain clears, interest is charged (−1 integrity per full 20% of strain taken).
func end_battle() -> void:
	var interest: int = int(floor(strain_this_battle / CombatConstants.CRONO_STRAIN_INTEREST_STEP))
	if interest > 0:
		pay_integrity(float(interest))
	battle_strain = 0.0
	strain_this_battle = 0.0
	debt_null_left = 0.0
	strain_changed.emit(battle_strain, camp_strain)


## Camp, inn or the Atrium bed.
func rest() -> void:
	camp_strain = 0.0
	ruin_stacks = 0
	strain_changed.emit(battle_strain, camp_strain)


func tick(dt: float) -> void:
	if debt_null_left > 0.0:
		debt_null_left = maxf(0.0, debt_null_left - dt)


static func of(actor: Node) -> TimeDebtComponent:
	if actor == null:
		return null
	return actor.get_node_or_null("TimeDebtComponent") as TimeDebtComponent
