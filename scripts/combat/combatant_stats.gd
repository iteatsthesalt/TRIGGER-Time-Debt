## Stat block for any battler (Combat Laws Bible §6.1, §18.1). Lives as a child node named
## "CombatantStats"; read it with CombatantStats.of(actor), never off the body.
class_name CombatantStats
extends Node

signal hp_changed(current: int, max_value: int)
signal mp_changed(current: int, max_value: int)
signal defeated
signal revived

enum Team { PARTY, ENEMY }

@export var actor_id: StringName = &""
@export var display_name: String = ""
@export var team: Team = Team.PARTY
@export var level: int = 1
@export var archetype: String = "balanced"
@export var kind: String = "regular"  ## enemies: regular | elite | miniboss | boss
@export var home_universe: int = 0
@export var canvas_fps: float = 60.0
@export var body_radius: float = 0.5
@export var move_range: float = 6.0

@export_group("Base stats")
@export var base_max_hp: int = 100
@export var max_mp: int = 20
@export var p_atk: float = 40.0
@export var e_atk: float = 40.0
@export var p_def: float = 20.0
@export var e_def: float = 20.0
@export var spd: float = 100.0
@export var luk: float = 5.0

@export_group("Tags")
## What this battler is made of / attacks with (ally resistances and Canvas Clash read these).
@export var tags: Array[StringName] = []
## Attack tags of the plain Attack command, e.g. [SWORD] for Crono (2 hits).
@export var weapon_tags: Array[StringName] = [&"SWORD"]
@export var weapon_hits: int = 1
@export var vulnerable: Array[StringName] = []
@export var resistant: Array[StringName] = []

@export_group("Rewards")
@export var xp: int = 0
@export var xp_reward: int = 0

var hp: int = -1
var mp: int = -1
var is_guarding: bool = false
var true_null: bool = false
var null_shield: bool = false
## Temporary shield points granted by fields (Divinity): absorbed before HP.
var temp_shield: int = 0


func _ready() -> void:
	if hp < 0:
		reset_vitals()


## The effective maximum HP: Crono's ceiling is lowered by the TimeDebtComponent.
func max_hp() -> int:
	var td := get_parent().get_node_or_null("TimeDebtComponent") if get_parent() else null
	if td != null and td.has_method("max_hp_factor"):
		return maxi(1, roundi(float(base_max_hp) * float(td.call("max_hp_factor"))))
	return base_max_hp


func reset_vitals() -> void:
	hp = max_hp()
	mp = max_mp
	temp_shield = 0
	is_guarding = false


func is_alive() -> bool:
	_ensure_init()
	return hp > 0


func hp_ratio() -> float:
	_ensure_init()
	return float(hp) / float(maxi(1, max_hp()))


## Applies damage after Guard and temporary shields. Returns HP actually removed.
func apply_damage(amount: int, ignore_guard: bool = false) -> int:
	_ensure_init()
	if hp <= 0:
		return 0
	var incoming: int = maxi(0, amount)
	if is_guarding and not ignore_guard and incoming > 0:
		incoming = maxi(1, roundi(float(incoming) * CombatConstants.GUARD_DAMAGE_MULT))
	if temp_shield > 0 and incoming > 0:
		var absorbed: int = mini(temp_shield, incoming)
		temp_shield -= absorbed
		incoming -= absorbed
	var dealt: int = mini(incoming, hp)
	hp -= dealt
	hp_changed.emit(hp, max_hp())
	if hp == 0:
		defeated.emit()
	return dealt


## Self-costs never kill: they stop at 1 HP (§6.3).
func apply_self_cost(amount: int) -> int:
	_ensure_init()
	if hp <= 1:
		return 0
	var dealt: int = mini(maxi(0, amount), hp - 1)
	hp -= dealt
	hp_changed.emit(hp, max_hp())
	return dealt


func heal(amount: int) -> int:
	_ensure_init()
	if hp <= 0:
		return 0
	var before: int = hp
	hp = mini(max_hp(), hp + maxi(0, amount))
	hp_changed.emit(hp, max_hp())
	return hp - before


func revive(ratio: float) -> void:
	_ensure_init()
	if hp > 0:
		return
	hp = maxi(1, roundi(float(max_hp()) * ratio))
	hp_changed.emit(hp, max_hp())
	revived.emit()


## Clamp HP when the ceiling changes mid-battle (Crono's strain).
func clamp_to_ceiling() -> void:
	_ensure_init()
	var m: int = max_hp()
	if hp > m:
		hp = m
		hp_changed.emit(hp, m)


func can_pay_mp(cost: int) -> bool:
	_ensure_init()
	return mp >= cost


func spend_mp(cost: int) -> void:
	_ensure_init()
	mp = maxi(0, mp - maxi(0, cost))
	mp_changed.emit(mp, max_mp)


func restore_mp(amount: int) -> void:
	_ensure_init()
	mp = mini(max_mp, mp + maxi(0, amount))
	mp_changed.emit(mp, max_mp)


func gauge_speed() -> float:
	return spd * CombatConstants.SPD_TO_GAUGE


func is_vulnerable_to(hit_tags: Array) -> bool:
	if true_null or null_shield:
		return false
	for t in hit_tags:
		if vulnerable.has(t):
			return true
	return false


func is_resistant_to(hit_tags: Array) -> bool:
	if true_null or null_shield:
		return false
	for t in hit_tags:
		if resistant.has(t):
			return true
	return false


func _ensure_init() -> void:
	if hp < 0:
		reset_vitals()


## Fill this block from the party balancing tables for a character at a level.
func apply_party_curve(id: StringName, lv: int) -> void:
	actor_id = id
	level = lv
	team = Team.PARTY
	archetype = StatCurves.archetype_of(id)
	base_max_hp = StatCurves.party_hp(lv, archetype)
	var d: Vector2 = StatCurves.party_def(lv, archetype)
	p_def = d.x
	e_def = d.y
	var a: Vector2 = StatCurves.party_atk(lv, id)
	p_atk = a.x
	e_atk = a.y
	max_mp = StatCurves.party_mp(lv, id)
	spd = StatCurves.party_spd(lv, id)
	luk = StatCurves.party_luk(lv, id)


## Fill this block from the enemy curves.
func apply_enemy_curve(lv: int, enemy_kind: String) -> void:
	level = lv
	kind = enemy_kind
	team = Team.ENEMY
	base_max_hp = StatCurves.enemy_hp(lv, enemy_kind)
	p_atk = StatCurves.enemy_atk(lv)
	e_atk = StatCurves.enemy_atk(lv)
	p_def = StatCurves.enemy_pdef(lv, enemy_kind)
	e_def = StatCurves.enemy_edef(lv, enemy_kind)
	spd = StatCurves.enemy_spd(lv, enemy_kind)
	luk = 5.0 + 0.5 * lv
	xp_reward = CombatConstants.xp_for_enemy(lv, enemy_kind)


## Adds XP and applies level-ups along the balancing curve. Returns levels gained.
func gain_xp(amount: int) -> int:
	_ensure_init()
	xp += maxi(0, amount)
	var gained: int = 0
	while level < 99 and xp >= CombatConstants.xp_to_next(level):
		xp -= CombatConstants.xp_to_next(level)
		var ratio: float = hp_ratio()
		var mp_ratio: float = float(mp) / float(maxi(1, max_mp))
		apply_party_curve(actor_id, level + 1)
		hp = maxi(1, roundi(float(max_hp()) * ratio))
		mp = roundi(float(max_mp) * mp_ratio)
		gained += 1
	return gained


## Finds the stats node on an actor (or returns the node itself if it is one).
static func of(actor: Node) -> CombatantStats:
	if actor == null:
		return null
	if actor is CombatantStats:
		return actor as CombatantStats
	return actor.get_node_or_null("CombatantStats") as CombatantStats
