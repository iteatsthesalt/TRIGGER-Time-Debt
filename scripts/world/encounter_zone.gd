## An encounter on the field (Combat Laws Bible §2.1–2.3): enemies wander inside a zone; touching one
## spawns the battle plane over this ground. Advantage is decided by who touched whom and from where: the
## facings of the two bodies (ActorSprite.facing), never their velocities (DECISIONS "Engagement").
class_name EncounterZone
extends Node3D

signal triggered(zone: EncounterZone, advantage: String)

## A body counts as "from behind" when the other one stands more than ~107° off its facing.
const BEHIND_DOT := -0.3
## Contact: the leader's capsule (0.35 m) plus a small reach, against the enemy's body radius; never
## tighter than the 1.1 m the zones were laid out with.
const CONTACT_REACH := 0.6
const MIN_CONTACT := 1.1
## Field statuses that leave an enemy helpless to a pre-emptive touch ("asleep or stunned", §2.3).
const HELPLESS_STATUSES: Array[StringName] = [&"sleep", &"stun", &"time_stop"]
const FACING_VECTORS := {
	&"s": Vector3(0, 0, 1), &"n": Vector3(0, 0, -1), &"e": Vector3(1, 0, 0), &"w": Vector3(-1, 0, 0),
	&"se": Vector3(0.7071, 0, 0.7071), &"sw": Vector3(-0.7071, 0, 0.7071),
	&"ne": Vector3(0.7071, 0, -0.7071), &"nw": Vector3(-0.7071, 0, -0.7071),
}

@export var encounter_id: StringName = &""
@export var radius: float = 6.0
@export var wander: bool = true
@export var respawn: bool = false
@export var boss: bool = false
var enemies: Array[CombatActor] = []
var active: bool = true
var _rng := RandomNumberGenerator.new()
var _targets: Dictionary = {}
var _waits: Dictionary = {}
## After a battle the zone re-arms only once the leader has stepped out of contact with every enemy.
var _await_separation: bool = false


func _ready() -> void:
	_rng.seed = hash(String(encounter_id) + name)
	add_to_group("encounter_zones")
	process_physics_priority = -1  # step the wanderers before their own CombatActor tick (gravity once per tick)


func spawn(parent: Node) -> void:
	var enc: Dictionary = Data.encounters.get(encounter_id, {})
	if enc.is_empty():
		push_warning("EncounterZone: unknown encounter %s" % encounter_id)
		return
	var idx: int = 0
	for ek in enc.get("enemies", []):
		var key: StringName = StringName(String(ek if ek is String else ek.get("key", "")))
		var def: EnemyDef = Data.enemy(key)
		if def == null:
			continue
		var level: int = int(ek.get("level", -1)) if ek is Dictionary else -1
		var a: CombatActor = CombatActor.create_enemy(def, level, "_%d" % idx)
		parent.add_child(a)
		var ang: float = _rng.randf_range(0.0, TAU)
		var r: float = _rng.randf_range(0.0, radius * 0.6)
		a.global_position = global_position + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		enemies.append(a)
		idx += 1


func _physics_process(delta: float) -> void:
	if not active or not wander or Story.is_running():
		return
	for e in enemies:
		if not is_instance_valid(e) or e.frozen or not e.stats.is_alive():
			continue
		if not _targets.has(e) or e.global_position.distance_to(_targets[e]) < 0.3:
			if _waits.get(e, 0.0) > 0.0:
				_waits[e] = float(_waits[e]) - delta
				e.velocity = Vector3(0.0, e.velocity.y, 0.0)  # standing: its own tick keeps the fall
				e.sprite.update_from_velocity(Vector3.ZERO)
				continue
			var ang: float = _rng.randf_range(0.0, TAU)
			var r: float = _rng.randf_range(0.5, radius * 0.7)
			_targets[e] = global_position + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
			_waits[e] = _rng.randf_range(0.8, 2.5)
		var to: Vector3 = _targets[e]
		var flat := Vector3(to.x - e.global_position.x, 0.0, to.z - e.global_position.z)
		e.step(flat.normalized() * 1.4, delta)


## Called every physics frame by the location with the leader; starts the fight on contact.
func check_contact(leader: CombatActor) -> bool:
	if not active:
		return false
	var touched: CombatActor = _touching(leader)
	if _await_separation:
		_await_separation = touched != null
		return false
	if touched == null:
		return false
	active = false
	triggered.emit(self, engagement(touched, leader))
	return true


func _touching(leader: CombatActor) -> CombatActor:
	for e in enemies:
		if not is_instance_valid(e) or not e.stats.is_alive():
			continue
		if e.global_position.distance_to(leader.global_position) < maxf(MIN_CONTACT, e.stats.body_radius + CONTACT_REACH):
			return e
	return null


## Combat Laws 2.3 for two bodies in contact: pre-emptive when the party touches the enemy from behind
## (the leader stands behind the enemy's facing) or while it is asleep or stunned; ambush when the enemy
## touches the party from behind (the leader faces away from it); otherwise, back to back included, normal.
func engagement(e: CombatActor, leader: CombatActor) -> String:
	var helpless: bool = e.frozen
	for id in HELPLESS_STATUSES:
		helpless = helpless or (e.statuses != null and e.statuses.has(id))
	return advantage_for(e.global_position, e.sprite.facing if e.sprite else &"s", leader.global_position, leader.sprite.facing if leader.sprite else &"s", helpless)


static func advantage_for(enemy_pos: Vector3, enemy_facing: StringName, leader_pos: Vector3, leader_facing: StringName, helpless: bool = false) -> String:
	var to_leader := Vector3(leader_pos.x - enemy_pos.x, 0.0, leader_pos.z - enemy_pos.z).normalized()
	var party_behind: bool = facing_vector(enemy_facing).dot(to_leader) < BEHIND_DOT
	var enemy_behind: bool = facing_vector(leader_facing).dot(-to_leader) < BEHIND_DOT
	if helpless or (party_behind and not enemy_behind):
		return "preemptive"
	if enemy_behind and not party_behind:
		return "ambush"
	return "normal"


static func facing_vector(facing: StringName) -> Vector3:
	return FACING_VECTORS.get(facing, Vector3(0, 0, 1))


func living() -> Array[CombatActor]:
	var out: Array[CombatActor] = []
	for e in enemies:
		if is_instance_valid(e) and e.stats.is_alive():
			out.append(e)
	return out


## After a battle over this ground (Combat Laws 4.2, 16.1, 16.5; BattleAftermath): on a win or a withdraw
## the dead and the spared leave the zone (a spared enemy is removed from the fight alive); a defeat jumps
## back to the moment before the encounter, so everyone stands again. Whoever stays is at full strength,
## un-Broken and back on a fresh wander route, and the zone re-arms once the leader steps out of contact.
func settle(outcome: String, spared: Array = []) -> void:
	var kept: Array[CombatActor] = []
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if outcome != BattleAftermath.DEFEAT and (spared.has(e) or not e.stats.is_alive()):
			e.queue_free()
		else:
			BattleAftermath.restore_enemy(e)
			kept.append(e)
	enemies = kept
	_targets.clear()
	_waits.clear()
	_await_separation = true
	if enemies.is_empty() and not respawn:
		active = false
	elif not enemies.is_empty():
		active = true
