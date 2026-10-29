## Shared body for party members and enemies (CharacterBody3D).
## Moves toward a combat anchor; uses the NavigationAgent3D path when a
## navigation map is baked, otherwise steers straight (prototype maps).
class_name CombatActor
extends CharacterBody3D

signal arrived

@export var move_speed: float = 5.0
@export var arrive_distance: float = 0.15
## Exploration: read arrow keys / WASD-mapped ui_* actions while not input_locked.
@export var player_controlled: bool = false

var frozen: bool = false
var input_locked: bool = false
var _has_target: bool = false
var _target: Vector3

@onready var stats: CombatantStats = $CombatantStats
@onready var nav: NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var sprite: ActorSprite = get_node_or_null("ActorSprite")


func _ready() -> void:
	add_to_group("party" if stats.team == CombatTypes.Team.PARTY else "enemies")


func move_to(point: Vector3) -> void:
	_target = point
	_has_target = true
	if nav:
		nav.target_position = point


## Break lock: stop in place until unfrozen.
func freeze() -> void:
	frozen = true
	_has_target = false
	velocity = Vector3.ZERO
	if nav:
		nav.target_position = global_position


func unfreeze() -> void:
	frozen = false


func _physics_process(_delta: float) -> void:
	_move()
	if sprite:
		sprite.update_from_velocity(velocity)


func _move() -> void:
	if player_controlled and not input_locked and not _has_target:
		var v: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		velocity = Vector3(v.x, 0.0, v.y) * move_speed
		move_and_slide()
		return
	if frozen or not _has_target:
		velocity = Vector3.ZERO
		return
	var next: Vector3 = _target
	# Without a baked navmesh the agent's "next" point is the actor itself; steer straight then.
	if nav and nav.get_current_navigation_path().size() > 1 and not nav.is_navigation_finished():
		var p: Vector3 = nav.get_next_path_position()
		if (p - global_position).length_squared() > 0.0004:
			next = p
	var to: Vector3 = next - global_position
	to.y = 0.0
	if (_target - global_position).length() <= arrive_distance:
		_has_target = false
		velocity = Vector3.ZERO
		arrived.emit()
		return
	velocity = to.normalized() * move_speed
	move_and_slide()
