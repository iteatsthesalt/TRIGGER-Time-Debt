## Followers trail the leader along a breadcrumb path, each one spaced further back (the Chrono line).
class_name PartyFollow
extends Node

@export var spacing: float = 1.1
@export var leader: CombatActor
var followers: Array[CombatActor] = []
var _crumbs: PackedVector3Array = PackedVector3Array()
var _last: Vector3 = Vector3.INF
var paused: bool = false


func set_party(lead: CombatActor, others: Array) -> void:
	leader = lead
	followers.clear()
	for o in others:
		followers.append(o)
	_crumbs.clear()
	_last = Vector3.INF
	if leader != null:
		for i in 64:
			_crumbs.append(leader.global_position)


func _physics_process(_delta: float) -> void:
	if paused or leader == null or not is_instance_valid(leader):
		return
	var p: Vector3 = leader.global_position
	if _last == Vector3.INF or p.distance_to(_last) >= 0.25:
		_crumbs.insert(0, p)
		_last = p
		if _crumbs.size() > 96:
			_crumbs.resize(96)
	for i in followers.size():
		var f: CombatActor = followers[i]
		if not is_instance_valid(f) or f.frozen:
			continue
		var want: Vector3 = _point_behind(spacing * float(i + 1))
		var flat := Vector3(want.x - f.global_position.x, 0.0, want.z - f.global_position.z)
		if flat.length() > 0.2:
			var spd: float = clampf(flat.length() * 4.0, 1.5, CombatActor.RUN_SPEED)
			f.velocity.x = flat.normalized().x * spd
			f.velocity.z = flat.normalized().z * spd
		else:
			f.velocity.x = 0.0
			f.velocity.z = 0.0
		if not f.is_on_floor():
			f.velocity.y -= 20.0 * _delta
		else:
			f.velocity.y = 0.0
		f.move_and_slide()
		if f.sprite:
			f.sprite.update_from_velocity(f.velocity)


func _point_behind(distance: float) -> Vector3:
	var acc: float = 0.0
	for i in range(_crumbs.size() - 1):
		var seg: float = _crumbs[i].distance_to(_crumbs[i + 1])
		if acc + seg >= distance:
			var t: float = (distance - acc) / maxf(seg, 0.0001)
			return _crumbs[i].lerp(_crumbs[i + 1], t)
		acc += seg
	return _crumbs[_crumbs.size() - 1] if not _crumbs.is_empty() else (leader.global_position if leader else Vector3.ZERO)


func snap_behind() -> void:
	if leader == null:
		return
	_crumbs.clear()
	for i in 64:
		_crumbs.append(leader.global_position + Vector3(0, 0, 0.1 * i))
	for i in followers.size():
		followers[i].global_position = leader.global_position + Vector3(0, 0, spacing * float(i + 1))
