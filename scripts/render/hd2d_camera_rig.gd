## The HD-2D camera rig (Reference Bible §2.3; Combat Laws §17.1): a tilted follow camera at FOV 32°,
## lerping to 24° with depth of field on truth moments, 35° pitch in battle. Reads Game settings.
class_name HD2DCameraRig
extends Node3D

@export var target: Node3D
@export var pitch_degrees: float = 30.0
@export var battle_pitch_degrees: float = CombatConstants.TACTICAL_PITCH_DEG
@export var distance: float = 15.0
@export var follow_speed: float = 6.0
@export var map_bounds: Rect2 = Rect2()
@export var auto_follow: bool = true
@export var height_offset: float = 1.0

var camera: Camera3D
var focus: Vector3 = Vector3.ZERO
var truth: bool = false
var _battle_focus: Variant = null
var _shake: float = 0.0
var _fov_tween: Tween
var _pitch_target: float = 30.0
var _yaw: float = 0.0


func _ready() -> void:
	camera = _find_camera()
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	camera.fov = CombatConstants.FOV_EXPLORE
	camera.near = 0.2
	camera.far = 200.0
	if camera.attributes == null:
		var attrs := CameraAttributesPractical.new()
		attrs.dof_blur_far_enabled = false
		attrs.dof_blur_near_enabled = false
		camera.attributes = attrs
	_pitch_target = pitch_degrees
	snap()


func _process(delta: float) -> void:
	if auto_follow:
		step(delta)


func snap() -> void:
	focus = desired_focus()
	_apply()


func step(delta: float) -> void:
	var t: float = 1.0 - exp(-follow_speed * maxf(delta, 0.0))
	focus = focus.lerp(desired_focus(), t)
	pitch_degrees = lerpf(pitch_degrees, _pitch_target, t)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
	_apply()


func desired_focus() -> Vector3:
	var p: Vector3 = focus
	if _battle_focus != null:
		p = _battle_focus
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
	var off := Vector3(0.0, sin(pitch), cos(pitch)) * distance
	return off.rotated(Vector3.UP, deg_to_rad(_yaw))


func _apply() -> void:
	if camera == null or not camera.is_inside_tree():
		return
	var shake_off := Vector3.ZERO
	if _shake > 0.0 and bool(Game.settings.get("screen_shake", true)):
		shake_off = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * _shake * 0.15
	var look_at_point: Vector3 = focus + Vector3(0.0, height_offset, 0.0)
	camera.global_position = look_at_point + camera_offset() + shake_off
	camera.look_at(look_at_point, Vector3.UP)
	var attrs := camera.attributes as CameraAttributesPractical
	if attrs and truth:
		attrs.dof_blur_far_distance = distance + CombatConstants.DOF_FAR * 0.5
		attrs.dof_blur_far_transition = CombatConstants.DOF_FAR
		attrs.dof_blur_near_distance = maxf(0.1, distance - 2.0)
		attrs.dof_blur_near_transition = 2.0


## Truth moments: FOV 32° → 24° over 0.45 s with depth of field (Reference §2.3).
func set_truth(on: bool) -> void:
	if truth == on:
		return
	truth = on
	if _fov_tween and _fov_tween.is_valid():
		_fov_tween.kill()
	var allow: bool = bool(Game.settings.get("truth_lerp", true))
	var goal: float = CombatConstants.FOV_TRUTH if (on and allow) else CombatConstants.FOV_EXPLORE
	_fov_tween = create_tween()
	_fov_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fov_tween.tween_property(camera, "fov", goal, CombatConstants.FOV_LERP_S)
	var attrs := camera.attributes as CameraAttributesPractical
	if attrs:
		var dof: bool = on and bool(Game.settings.get("dof", true))
		attrs.dof_blur_far_enabled = dof
		attrs.dof_blur_near_enabled = dof
		attrs.dof_blur_amount = 0.08 if dof else 0.0
	if is_instance_valid(Audio):
		Audio.set_rtpc("camera_fov", goal)


func enter_battle(center: Vector3) -> void:
	_battle_focus = center
	_pitch_target = battle_pitch_degrees


func exit_battle() -> void:
	_battle_focus = null
	_pitch_target = (pitch_degrees if _pitch_target == pitch_degrees else 30.0)
	_pitch_target = 30.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _find_camera() -> Camera3D:
	for child in get_children():
		if child is Camera3D:
			return child
	return null
