## Field control of the party leader: movement, interaction, Porcelain Insight (hold focus) and the menu.
class_name PlayerController
extends Node

signal interact_requested(target: Node)
signal focus_changed(on: bool)
signal menu_requested
signal rewind_requested

@export var leader: CombatActor
@export var enabled: bool = true
@export var speed: float = CombatActor.WALK_SPEED
@export var run_speed: float = CombatActor.RUN_SPEED

var focusing: bool = false
## A focus release that came while a battle or a cutscene held the controls: `focusing` dropped at once (no
## 0.4x walk afterwards), focus_changed(false) waits until the controls are back (it never cuts a cutscene's lens).
var _release_pending: bool = false
var _interact_area: Area3D
var _last_dir: Vector3 = Vector3(0, 0, 1)


func _ready() -> void:
	set_physics_process(true)
	process_physics_priority = -1  # step the leader before its own CombatActor tick (gravity once per tick)


func attach(actor: CombatActor) -> void:
	leader = actor
	if _interact_area != null and is_instance_valid(_interact_area):
		_interact_area.queue_free()
	_interact_area = Area3D.new()
	_interact_area.name = "InteractProbe"
	_interact_area.collision_layer = 0
	_interact_area.collision_mask = 8
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	cs.shape = sphere
	_interact_area.add_child(cs)
	_interact_area.position = Vector3(0, 0.8, 0.9)
	leader.add_child(_interact_area)


func _physics_process(delta: float) -> void:
	if not enabled or leader == null or not is_instance_valid(leader) or leader.frozen:
		return
	if Story.is_running():
		leader.velocity = Vector3(0, leader.velocity.y, 0)
		leader.sprite.update_from_velocity(Vector3.ZERO)
		return
	if _release_pending:
		_release_pending = false
		focus_changed.emit(false)
	if leader.is_walking():  # a scripted walk owns the body until it resolves
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0.0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var spd: float = speed
	if focusing:
		spd *= 0.4
	leader.step(dir * spd, delta)
	if dir.length() > 0.05:
		_last_dir = dir.normalized()
		if _interact_area:
			_interact_area.position = Vector3(_last_dir.x, 0.8, _last_dir.z) * 0.9


func _unhandled_input(event: InputEvent) -> void:
	if focusing and event.is_action_released("focus"):
		focusing = false
		if not enabled or leader == null or Story.is_running():
			_release_pending = true
		else:
			focus_changed.emit(false)
		return
	if not enabled or leader == null or Story.is_running():
		return
	if event.is_action_pressed("confirm"):
		var target: Node = nearest_interactable()
		if target != null:
			interact_requested.emit(target)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("focus"):
		focusing = true
		_release_pending = false
		focus_changed.emit(true)
	elif event.is_action_pressed("menu"):
		menu_requested.emit()
	elif event.is_action_pressed("rewind"):
		rewind_requested.emit()


func nearest_interactable() -> Node:
	if _interact_area == null:
		return null
	var best: Node = null
	var best_d: float = INF
	for a in _interact_area.get_overlapping_areas():
		var owner_node: Node = a
		if a.has_meta("interactable"):
			owner_node = a.get_meta("interactable")
		var d: float = (a as Node3D).global_position.distance_to(leader.global_position)
		if d < best_d:
			best_d = d
			best = owner_node
	return best
