class_name HD2DCameraRig
extends Node3D
## Tilted perspective follow camera for HD-2D maps.
## Smoothly follows `target`, clamps the focus point to `map_bounds`, and keeps a
## depth-of-field band centred on whatever it is looking at. During combat it frames
## the arena centre instead. Blur *amount* belongs to the coordinator's combat tween;
## this rig only owns the focus distances.

@export var target: Node3D
@export var coordinator: HybridBattleCoordinator
@export var pitch_degrees: float = 32.0
@export var distance: float = 16.5
## Higher = snappier. Frame-rate independent (exponential decay per second).
@export var follow_speed: float = 6.0
## Focus-point limits on the XZ plane: position = (min x, min z), size = (width, depth).
## A zero-size rect means no limit.
@export var map_bounds: Rect2 = Rect2()
## Metres either side of the focus point that stay sharp.
@export var focus_band: float = 3.0
## When false the rig only moves when step() is called (tests, replays).
@export var auto_follow: bool = true

var focus: Vector3 = Vector3.ZERO
var camera: Camera3D

var _combat_focus: Variant = null


func _ready() -> void:
	camera = _find_camera()
	if coordinator:
		coordinator.combat_started.connect(_on_combat_started)
		coordinator.combat_ended.connect(_on_combat_ended)
	snap()


func _process(delta: float) -> void:
	if auto_follow:
		step(delta)


## Jump straight to the goal with no smoothing (map load, teleports).
func snap() -> void:
	focus = desired_focus()
	_apply()


func step(delta: float) -> void:
	var t: float = 1.0 - exp(-follow_speed * maxf(delta, 0.0))
	focus = focus.lerp(desired_focus(), t)
	_apply()


func desired_focus() -> Vector3:
	var p: Vector3 = focus
	if _combat_focus != null:
		p = _combat_focus
	elif is_instance_valid(target):
		p = target.global_position
	return clamp_to_bounds(p)


func clamp_to_bounds(p: Vector3) -> Vector3:
	if not map_bounds.has_area():
		return p
	p.x = clampf(p.x, map_bounds.position.x, map_bounds.end.x)
	p.z = clampf(p.z, map_bounds.position.y, map_bounds.end.y)
	return p


func camera_offset() -> Vector3:
	var pitch := deg_to_rad(pitch_degrees)
	return Vector3(0.0, sin(pitch), cos(pitch)) * distance


# ------------------------------------------------------------------ internals

func _apply() -> void:
	if camera == null or not camera.is_inside_tree():
		return
	camera.global_position = focus + camera_offset()
	camera.global_rotation = Vector3(-deg_to_rad(pitch_degrees), 0.0, 0.0)
	var attrs := camera.attributes as CameraAttributesPractical
	if attrs:
		attrs.dof_blur_near_enabled = true
		attrs.dof_blur_far_enabled = true
		attrs.dof_blur_near_distance = maxf(0.1, distance - focus_band)
		attrs.dof_blur_near_transition = focus_band
		attrs.dof_blur_far_distance = distance + focus_band
		attrs.dof_blur_far_transition = focus_band


func _find_camera() -> Camera3D:
	for child in get_children():
		if child is Camera3D:
			return child
	return null


func _on_combat_started(arena_center: Vector3) -> void:
	_combat_focus = arena_center


func _on_combat_ended(_victory: bool) -> void:
	_combat_focus = null
