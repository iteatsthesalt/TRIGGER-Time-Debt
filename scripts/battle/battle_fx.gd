## The battle's one-shot presentation pieces (Combat Laws Bible §17.1): the telegraph decal on the plane, the gold
## shatter of a Break, the Lv3+ style bleed and the screen flash. Pure presentation, no rule reads them; each
## is parented under the node it is given and frees itself.
class_name BattleFx
extends RefCounted

## The ground overlays draw before every sprite in the transparent list (Material.render_priority): a body
## faded by its Debt, a phase or a style bleed writes no depth, so a plane or decal sorted after it by its
## centre would wash it. The plane goes first, the wind-up decals over it, the sprites (priority 0) last.
const PLANE_RENDER_PRIORITY := -2
const DECAL_RENDER_PRIORITY := -1

static var _aoe_shader: Shader


## The decal of an enemy wind-up (CIRCLE, LINE / LINE_PIERCE, CONE, else a small ring at the aim), on the
## plane at `floor_y`. The caller drives its `boost_ratio` (the wind-up progress) and frees it.
static func telegraph(parent: Node3D, action: Dictionary, origin: Vector3, floor_y: float) -> MeshInstance3D:
	if _aoe_shader == null:
		_aoe_shader = load("res://shaders/aoe_floor_ring.gdshader")
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = _aoe_shader
	mat.render_priority = DECAL_RENDER_PRIORITY
	var aim: Vector3 = action.get("aim", origin)
	var flat := Vector3(origin.x, floor_y, origin.z)
	var dir: Vector3 = Vector3(aim.x - origin.x, 0.0, aim.z - origin.z).normalized()
	match String(action.get("shape", "SINGLE")):
		"CIRCLE":
			var r: float = float(action.get("radius", 1.5))
			pm.size = Vector2(r * 2.0, r * 2.0)
			mat.set_shader_parameter("shape_mode", 0)
			mi.position = Vector3(aim.x, floor_y, aim.z)
		"LINE_PIERCE", "LINE":
			var l: float = float(action.get("length", 6.0))
			pm.size = Vector2(float(action.get("width", 1.2)), l)
			mat.set_shader_parameter("shape_mode", 1)
			mi.position = flat + dir * l * 0.5
			mi.rotation.y = atan2(dir.x, dir.z) + PI
		"CONE":
			var l2: float = float(action.get("length", 4.0))
			var r2: float = float(action.get("radius", 2.0))
			pm.size = Vector2(r2 * 2.0, l2)
			mat.set_shader_parameter("shape_mode", 2)
			mat.set_shader_parameter("cone_half_angle", atan2(r2, l2))
			mi.position = flat + dir * l2 * 0.5
			mi.rotation.y = atan2(dir.x, dir.z) + PI
		_:
			pm.size = Vector2(2.2, 2.2)
			mat.set_shader_parameter("shape_mode", 0)
			mi.position = Vector3(aim.x, floor_y, aim.z)
	mi.mesh = pm
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## The gold porcelain spill of a Break (or of a debt paid with the bowl still whole).
static func gold_shatter(parent: Node3D, pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.95
	p.fixed_fps = int(Universe.current_fps())
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.05
	pm.scale_max = 0.16
	pm.color = Color(1.0, 0.82, 0.35)
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.3)
	mat.emission_energy_multiplier = 2.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.material = mat
	p.draw_pass_1 = qm
	p.position = pos + Vector3(0, 1.0, 0)
	parent.add_child(p)
	p.emitting = true
	var tw := parent.create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(p.queue_free)


## Boost Lv3+ style bleed: watercolour afterimages (U0), ink splitting (U1): a few fading ghost copies.
static func style_bleed(parent: Node3D, a: CombatActor) -> void:
	for i in 3:
		var ghost := ActorSprite.new()
		ghost.material.set_shader_parameter("sheet", a.sprite.material.get_shader_parameter("sheet"))
		ghost.material.set_shader_parameter("frame_rect", a.sprite.material.get_shader_parameter("frame_rect"))
		ghost.material.set_shader_parameter("sheet_px", a.sprite.material.get_shader_parameter("sheet_px"))
		ghost.mesh = a.sprite.mesh
		ghost.set_tint(Color(0.7, 0.8, 1.0) if a.home_universe == 0 else Color(0.2, 0.2, 0.3))
		ghost.set_opacity(0.5)
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ghost)
		ghost.global_position = a.sprite.global_position + Vector3(-0.25 * float(i + 1), 0.0, 0.0)
		var tw := parent.create_tween()
		tw.tween_property(ghost, "transparency", 1.0, 0.35 + 0.1 * float(i))
		tw.tween_callback(ghost.queue_free)


## A full-screen flash over the HUD that fades in `seconds` (toned down under Reduced flicker, §3.7).
static func flash(hud: BattleHUD, color: Color, seconds: float) -> void:
	var rect: ColorRect = hud.root.get_node_or_null("Flash")
	if rect == null:
		rect = ColorRect.new()
		rect.name = "Flash"
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.root.add_child(rect)
	if bool(Game.settings.get("reduced_flicker", false)):
		color.a *= 0.3
	rect.color = color
	var tw := hud.create_tween()
	tw.tween_property(rect, "color:a", 0.0, seconds)
