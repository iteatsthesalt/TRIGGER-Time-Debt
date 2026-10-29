## An encounter on the field (Combat Laws Bible §2.1–2.3): enemies wander inside a zone; touching one
## spawns the battle plane over this ground. Advantage is decided by who touched whom and from where.
class_name EncounterZone
extends Node3D

signal triggered(zone: EncounterZone, advantage: String)

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


func _ready() -> void:
	_rng.seed = hash(String(encounter_id) + name)
	add_to_group("encounter_zones")


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
				e.velocity = Vector3.ZERO
				e.sprite.update_from_velocity(Vector3.ZERO)
				continue
			var ang: float = _rng.randf_range(0.0, TAU)
			var r: float = _rng.randf_range(0.5, radius * 0.7)
			_targets[e] = global_position + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
			_waits[e] = _rng.randf_range(0.8, 2.5)
		var to: Vector3 = _targets[e]
		var flat := Vector3(to.x - e.global_position.x, 0.0, to.z - e.global_position.z)
		var spd: float = 1.4
		e.velocity.x = flat.normalized().x * spd
		e.velocity.z = flat.normalized().z * spd
		if not e.is_on_floor():
			e.velocity.y -= 20.0 * delta
		e.move_and_slide()
		e.sprite.update_from_velocity(e.velocity)


## Called every physics frame by the location with the leader; starts the fight on contact.
func check_contact(leader: CombatActor) -> bool:
	if not active:
		return false
	for e in enemies:
		if not is_instance_valid(e) or not e.stats.is_alive():
			continue
		var d: float = e.global_position.distance_to(leader.global_position)
		if d < 1.1:
			var advantage: String = "normal"
			var to_leader: Vector3 = (leader.global_position - e.global_position).normalized()
			var e_facing: Vector3 = e.velocity.normalized() if e.velocity.length() > 0.1 else Vector3.ZERO
			var l_facing: Vector3 = leader.velocity.normalized() if leader.velocity.length() > 0.1 else Vector3.ZERO
			if l_facing != Vector3.ZERO and e_facing != Vector3.ZERO and e_facing.dot(to_leader) < -0.3 and l_facing.dot(to_leader) < -0.3:
				advantage = "preemptive"
			elif l_facing == Vector3.ZERO and e_facing.dot(to_leader) > 0.5:
				advantage = "ambush"
			active = false
			triggered.emit(self, advantage)
			return true
	return false


func living() -> Array[CombatActor]:
	var out: Array[CombatActor] = []
	for e in enemies:
		if is_instance_valid(e) and e.stats.is_alive():
			out.append(e)
	return out


func clear_defeated() -> void:
	for e in enemies.duplicate():
		if not is_instance_valid(e) or not e.stats.is_alive():
			enemies.erase(e)
			if is_instance_valid(e):
				e.queue_free()
	if enemies.is_empty() and not respawn:
		active = false
	elif not enemies.is_empty():
		active = true
