## Boost-scaled floor preview for the selected Tech (ported from Source 02).
## Fixes: shared shader file instead of an inline string copy; CLEAVE_CONE shown;
## sizes come from TechResource.aoe_scale() so preview == hit test.
class_name AoEDecalVisualizer3D
extends Node3D

const SHADER := preload("res://shaders/aoe_floor_ring.gdshader")

var _mesh: MeshInstance3D
var _mat: ShaderMaterial


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	_mesh.mesh = plane
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	visible = false


func show_preview(tech: TechResource, caster: Node3D, target: Node3D, boost_level: int) -> void:
	if tech == null or caster == null or (target == null and tech.shape_type != TechResource.SpatialShape.SELF_AURA):
		visible = false
		return
	visible = true
	var s: float = tech.aoe_scale(boost_level)
	var radius: float = tech.base_radius_or_width * s
	var length: float = tech.base_length * s
	_mat.set_shader_parameter("boost_ratio", clampf(float(boost_level) / 3.0, 0.0, 1.0))
	_mesh.position = Vector3.ZERO
	rotation = Vector3.ZERO
	var lift := Vector3(0.0, 0.05, 0.0)

	match tech.shape_type:
		TechResource.SpatialShape.SINGLE_TARGET:
			_mat.set_shader_parameter("shape_mode", 0)
			global_position = target.global_position + lift
			_mesh.scale = Vector3(0.75, 1.0, 0.75)
		TechResource.SpatialShape.CIRCLE_AROUND_TARGET:
			_mat.set_shader_parameter("shape_mode", 0)
			global_position = target.global_position + lift
			_mesh.scale = Vector3(radius, 1.0, radius)
		TechResource.SpatialShape.SELF_AURA:
			_mat.set_shader_parameter("shape_mode", 0)
			global_position = caster.global_position + lift
			_mesh.scale = Vector3(radius, 1.0, radius)
		TechResource.SpatialShape.LINE_PIERCE, TechResource.SpatialShape.CLEAVE_CONE:
			var is_cone: bool = tech.shape_type == TechResource.SpatialShape.CLEAVE_CONE
			_mat.set_shader_parameter("shape_mode", 2 if is_cone else 1)
			_mat.set_shader_parameter("cone_half_angle", deg_to_rad(tech.cone_angle_deg) * 0.5)
			global_position = caster.global_position + lift
			var dir: Vector3 = target.global_position - caster.global_position
			dir.y = 0.0
			if dir.length_squared() > 0.001:
				look_at(global_position + dir.normalized(), Vector3.UP)
			var half_w: float = length if is_cone else radius * 0.5
			_mesh.scale = Vector3(half_w, 1.0, length * 0.5)
			_mesh.position = Vector3(0.0, 0.0, -length * 0.5)


func hide_preview() -> void:
	visible = false
