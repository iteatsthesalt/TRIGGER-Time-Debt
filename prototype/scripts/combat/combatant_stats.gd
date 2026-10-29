## Stat block for any combatant. The original doc referenced this node
## everywhere but never defined it; TechResource also read stats off the
## actor body instead of this child, which returned null at runtime.
class_name CombatantStats
extends Node

signal hp_changed(current: int, max_value: int)
signal mp_changed(current: int, max_value: int)
signal defeated

## Stable id used by TechResource.required_actor_ids (e.g. &"crono").
## Don't rely on node names — two scenes can't both be called "TravelerActor".
@export var actor_id: StringName = &""
@export var team: CombatTypes.Team = CombatTypes.Team.PARTY
@export var max_hp: int = 100
@export var max_mp: int = 20
@export var speed: float = 25.0
@export var physical_attack: float = 40.0
@export var elemental_attack: float = 40.0
@export var physical_defense: float = 20.0
@export var elemental_defense: float = 20.0
@export var weapon_type: CombatTypes.DamageType = CombatTypes.DamageType.SWORD
## Horizontal radius used by AoE geometry tests.
@export var body_radius: float = 0.5

@export_group("Progression")
@export var level: int = 1
## XP banked toward the next level.
@export var xp: int = 0
## Enemies only: what defeating this combatant is worth.
@export var xp_reward: int = 0
@export var gold_reward: int = 0

var hp: int = -1
var mp: int = -1
## Set by HybridBattleCoordinator.execute_defend(); halves the next incoming
## hits until this actor's own next turn, when the coordinator clears it.
var is_defending: bool = false


func _ready() -> void:
	if hp < 0:
		reset_vitals()


func reset_vitals() -> void:
	hp = max_hp
	mp = max_mp


func is_alive() -> bool:
	_ensure_init()
	return hp > 0


func apply_damage(amount: int) -> int:
	_ensure_init()
	if hp <= 0:
		return 0
	var incoming: int = maxi(0, amount)
	if is_defending:
		incoming = maxi(1, roundi(incoming * 0.5)) if incoming > 0 else 0
	var dealt: int = mini(incoming, hp)
	hp -= dealt
	hp_changed.emit(hp, max_hp)
	if hp == 0:
		defeated.emit()
	return dealt


func heal(amount: int) -> void:
	_ensure_init()
	if hp <= 0:
		return
	hp = mini(max_hp, hp + maxi(0, amount))
	hp_changed.emit(hp, max_hp)


func can_pay_mp(cost: int) -> bool:
	_ensure_init()
	return mp >= cost


func spend_mp(cost: int) -> void:
	_ensure_init()
	mp = maxi(0, mp - maxi(0, cost))
	mp_changed.emit(mp, max_mp)


func _ensure_init() -> void:
	if hp < 0:
		reset_vitals()


## XP needed to go from `lvl` to lvl + 1 (DECISIONS.md: 10 * L^2 + 10 * L -> 20, 60, 120, 200 ...).
static func xp_to_next(lvl: int) -> int:
	return 10 * lvl * lvl + 10 * lvl


## Adds XP and applies any level-ups. Returns how many levels were gained.
## Growth per level (DECISIONS.md): +8% max HP (at least 1), +2 MP, +2 to both attacks
## and both defences; HP and MP are topped up by the amount gained.
func gain_xp(amount: int) -> int:
	_ensure_init()
	xp += maxi(0, amount)
	var gained := 0
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
		var hp_up: int = maxi(1, int(round(max_hp * 0.08)))
		max_hp += hp_up
		max_mp += 2
		physical_attack += 2.0
		elemental_attack += 2.0
		physical_defense += 2.0
		elemental_defense += 2.0
		if hp > 0:
			hp += hp_up
		mp += 2
	return gained


## Finds the stats node on an actor (or returns the node itself if it is one).
static func of(actor: Node) -> CombatantStats:
	if actor == null:
		return null
	if actor is CombatantStats:
		return actor as CombatantStats
	return actor.get_node_or_null("CombatantStats") as CombatantStats
