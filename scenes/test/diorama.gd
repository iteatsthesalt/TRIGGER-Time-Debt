## The HD-2D proof: one lit diorama (a Guardia-kitchen corner) with crisp billboard sprites under the
## compositor canvas stack. Cycles universes when --cycle is passed, for the canvas-switch test.
extends Node3D

var rig: HD2DCameraRig
var world: HD2DWorld
var actors: Dictionary = {}
var _t: float = 0.0
var _cycle: bool = false
var _hold_universe: int = 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--cycle":
			_cycle = true
		elif arg.begins_with("--universe="):
			_hold_universe = int(arg.trim_prefix("--universe="))
	world = HD2DWorld.new()
	world.name = "World"
	add_child(world)
	HD2DWorld.add_three_point_lights(self)
	_build_room()
	_build_sprites()
	rig = HD2DCameraRig.new()
	rig.name = "CameraRig"
	rig.distance = 13.0
	rig.pitch_degrees = 30.0
	rig.height_offset = 0.9
	add_child(rig)
	rig.target = actors["crono"]
	rig.snap()
	if _hold_universe > 0:
		Universe.set_universe(_hold_universe, true)
	else:
		Universe.set_universe(0, true)


func _build_room() -> void:
	var stone := SceneKit.material("res://assets/textures/stone_mossy_albedo.png", "res://assets/textures/stone_normal.png", 0.95, Color(0.9, 0.9, 0.9), true)
	var wall := SceneKit.material("res://assets/textures/castle_wall_albedo.png", "res://assets/textures/castle_wall_normal.png", 0.9, Color(0.95, 0.95, 0.95), true)
	var wood := SceneKit.material("res://assets/textures/wood_albedo.png", "res://assets/textures/wood_normal.png", 0.85, Color.WHITE, true)
	SceneKit.floor_plane(self, Vector2(16, 16), Vector3.ZERO, stone)
	# Back wall and left wall, 4 m tall, with a window opening in the back wall.
	SceneKit.box(self, Vector3(16, 4.5, 0.6), Vector3(0, 2.25, -6.3), wall, "BackWall")
	SceneKit.box(self, Vector3(0.6, 4.5, 16), Vector3(-8.3, 2.25, 0), wall, "LeftWall")
	# Stained-glass window: an emissive quad with a warm/cool pattern and a light behind it.
	var glass := _stained_glass_material()
	var win := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.2, 3.0)
	win.mesh = q
	win.material_override = glass
	win.position = Vector3(2.5, 2.4, -5.98)
	add_child(win)
	var frame := SceneKit.flat_color(Color(0.18, 0.17, 0.16), Color.BLACK, 0.0, 0.7)
	SceneKit.box(self, Vector3(2.5, 0.15, 0.2), Vector3(2.5, 3.95, -6.0), frame, "WinTop", false)
	SceneKit.box(self, Vector3(2.5, 0.15, 0.2), Vector3(2.5, 0.85, -6.0), frame, "WinBottom", false)
	SceneKit.box(self, Vector3(0.15, 3.2, 0.2), Vector3(1.35, 2.4, -6.0), frame, "WinL", false)
	SceneKit.box(self, Vector3(0.15, 3.2, 0.2), Vector3(3.65, 2.4, -6.0), frame, "WinR", false)
	var sun := SpotLight3D.new()
	sun.position = Vector3(2.5, 3.2, -5.6)
	sun.rotation_degrees = Vector3(-55, 0, 0)
	sun.light_color = Color(0.75, 0.62, 0.95)
	sun.light_energy = 6.0
	sun.spot_range = 10.0
	sun.spot_angle = 32.0
	sun.shadow_enabled = false
	add_child(sun)
	# Hearth on the left wall with a fire light.
	var hearth := SceneKit.flat_color(Color(0.22, 0.2, 0.19), Color.BLACK, 0.0, 0.9)
	SceneKit.box(self, Vector3(1.0, 2.4, 2.6), Vector3(-7.5, 1.2, -2.0), hearth, "Hearth")
	SceneKit.box(self, Vector3(1.1, 0.25, 2.8), Vector3(-7.45, 2.5, -2.0), hearth, "HearthMantle", false)
	var ember := SceneKit.flat_color(Color(1.0, 0.45, 0.1), Color(1.0, 0.5, 0.12), 4.0)
	SceneKit.box(self, Vector3(0.3, 0.3, 1.4), Vector3(-7.0, 0.3, -2.0), ember, "Embers", false)
	SceneKit.omni(self, Vector3(-6.3, 1.0, -2.0), Color(1.0, 0.62, 0.3), 2.6, 7.0, true)
	# The stone counter and the long wooden table with the porridge pot and two bowls.
	SceneKit.box(self, Vector3(4.0, 0.9, 1.0), Vector3(-5.0, 0.45, -5.2), stone, "Counter")
	SceneKit.box(self, Vector3(3.6, 0.12, 1.4), Vector3(0.0, 0.84, 0.0), wood, "TableTop")
	for p in [Vector3(-1.6, 0.4, -0.55), Vector3(1.6, 0.4, -0.55), Vector3(-1.6, 0.4, 0.55), Vector3(1.6, 0.4, 0.55)]:
		SceneKit.box(self, Vector3(0.14, 0.8, 0.14), p, wood, "Leg", false)
	var copper := SceneKit.flat_color(Color(0.72, 0.45, 0.28), Color.BLACK, 0.0, 0.35, 0.8)
	SceneKit.cylinder(self, 0.32, 0.36, Vector3(-4.6, 1.08, -5.2), copper, "Pot", false)
	SceneKit.cylinder(self, 0.2, 0.2, Vector3(-3.6, 1.0, -5.2), copper, "Pot2", false)
	var porcelain := SceneKit.flat_color(Color(0.93, 0.92, 0.88), Color.BLACK, 0.0, 0.4)
	SceneKit.cylinder(self, 0.14, 0.08, Vector3(-0.6, 0.94, 0.1), porcelain, "Bowl", false)
	SceneKit.cylinder(self, 0.14, 0.08, Vector3(0.7, 0.94, -0.2), porcelain, "Bowl2", false)
	# Sera's stool with the ink-burned groove, a shelf, a few crates.
	SceneKit.cylinder(self, 0.22, 0.45, Vector3(0.9, 0.225, 1.3), wood, "Stool")
	SceneKit.box(self, Vector3(2.4, 0.08, 0.4), Vector3(-2.0, 2.2, -6.0), wood, "Shelf", false)
	SceneKit.box(self, Vector3(0.7, 0.7, 0.7), Vector3(5.5, 0.35, -5.2), wood, "Crate")
	SceneKit.box(self, Vector3(0.6, 0.6, 0.6), Vector3(6.2, 0.3, -4.4), wood, "Crate2")
	# Brass speaking tube on the back wall.
	var brass := SceneKit.flat_color(Color(0.78, 0.6, 0.3), Color.BLACK, 0.0, 0.3, 0.9)
	SceneKit.cylinder(self, 0.08, 2.0, Vector3(-1.0, 1.6, -5.9), brass, "Tube", false)
	SceneKit.cylinder(self, 0.22, 0.2, Vector3(-1.0, 2.7, -5.8), brass, "TubeHorn", false)
	SceneKit.marker(self, "start", Vector3(-2.0, 0.0, 1.5))
	SceneKit.marker(self, "sera_seat", Vector3(1.4, 0.0, 1.6))
	SceneKit.marker(self, "marle_spot", Vector3(-3.0, 0.0, -0.8))


func _stained_glass_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	vec2 uv = UV;
	vec2 g = floor(uv * vec2(4.0, 6.0));
	float h = fract(sin(dot(g, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 a = vec3(0.17, 0.30, 0.61); vec3 b = vec3(0.76, 0.27, 0.43); vec3 c = vec3(0.88, 0.64, 0.23); vec3 d = vec3(0.31, 0.72, 0.69);
	vec3 col = h < 0.25 ? a : (h < 0.5 ? b : (h < 0.75 ? c : d));
	vec2 f = fract(uv * vec2(4.0, 6.0));
	float lead = step(f.x, 0.06) + step(0.94, f.x) + step(f.y, 0.06) + step(0.94, f.y);
	float dust = 0.55 + 0.45 * fract(sin(dot(floor(uv * 40.0), vec2(4.1, 9.7))) * 1234.5);
	col = mix(col * dust, vec3(0.08), clamp(lead, 0.0, 1.0));
	ALBEDO = col * 0.4;
	EMISSION = col * 1.6 * (1.0 - clamp(lead, 0.0, 1.0));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _build_sprites() -> void:
	_sprite("crono", "res://assets/characters/crono/crono_painted.png", Vector3(-2.0, 0.0, 1.5), 60.0)
	_sprite("sera", "res://assets/characters/sera/sera_painted.png", Vector3(1.4, 0.06, 1.6), 60.0)
	_sprite("marle", "res://assets/npcs/marle/marle_painted.png", Vector3(-3.2, 0.0, -0.9), 60.0)
	# Porcelain proof: Crono's crack states on three dolls at the back.
	for i in 3:
		var s: ActorSprite = _sprite("doll%d" % i, "res://assets/characters/crono/crono_painted.png", Vector3(3.8 + float(i) * 1.3, 0.0, -3.5), 60.0)
		s.set_porcelain(i + 2 if i > 0 else 1, [0.0, 0.5, 0.95][i], 0.0 if i < 2 else 0.4)
		s.set_tint(Color(0.9, 0.9, 0.92))


func _sprite(id: String, path: String, pos: Vector3, fps: float) -> ActorSprite:
	var holder := Node3D.new()
	holder.name = id
	holder.position = pos
	add_child(holder)
	var s := ActorSprite.new()
	s.name = "Sprite"
	holder.add_child(s)
	if ResourceLoader.exists(path):
		s.set_standin(load(path), fps)
	actors[id] = holder
	return s


func get_actor(id: StringName) -> Node:
	return actors.get(String(id), null)


func get_marker(name: StringName) -> Variant:
	var m := get_node_or_null(String(name))
	return m.global_position if m != null else null


func _process(delta: float) -> void:
	_t += delta
	if _cycle:
		var u: int = int(_t / 2.5) % 9
		if Universe.target != u:
			Universe.set_universe(u)
