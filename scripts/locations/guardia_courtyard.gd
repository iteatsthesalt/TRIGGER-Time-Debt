## Guardia Castle courtyard in the rain (Prologue beat 9): Glenn and Magus wait with the Epoch gauntlet.
extends Location

var rain: GPUParticles3D


func build() -> void:
	location_id = &"guardia_courtyard"
	universe_id = 0
	field_music = &"mus_u0_truce_1024"
	ambience = &"amb_u0"
	camera_distance = 15.0
	camera_pitch = 30.0
	map_bounds = Rect2(-12, -12, 24, 22)
	var stone := SceneKit.material("res://assets/textures/stone_mossy_albedo.png", "res://assets/textures/stone_normal.png", 0.9, Color(0.85, 0.87, 0.9), true)
	var gravel := SceneKit.material("res://assets/textures/gravel_albedo.png", "res://assets/textures/gravel_normal.png", 1.0, Color(0.9, 0.9, 0.92), true)
	var wall := SceneKit.material("res://assets/textures/castle_wall_albedo.png", "res://assets/textures/castle_wall_normal.png", 0.9, Color(0.9, 0.9, 0.95), true)
	SceneKit.floor_plane(self, Vector2(26, 24), Vector3(0, 0, -1), gravel, "Ground")
	# a flagstone path from the keep door (north) to the gatehouse (south)
	SceneKit.box(self, Vector3(3.0, 0.04, 20.0), Vector3(0, 0.02, -1), stone, "Path", false)
	# keep wall with the door the party came through
	SceneKit.box(self, Vector3(26, 7.0, 1.0), Vector3(0, 3.5, -12.0), wall, "KeepWall")
	var door_dark := SceneKit.flat_color(Color(0.05, 0.05, 0.06), Color.BLACK, 0.0, 1.0)
	SceneKit.box(self, Vector3(2.2, 3.4, 0.4), Vector3(0, 1.7, -11.4), door_dark, "KeepDoor", false)
	# side walls and two towers
	SceneKit.box(self, Vector3(1.0, 6.0, 24), Vector3(-12.5, 3.0, -1), wall, "WestWall")
	SceneKit.box(self, Vector3(1.0, 6.0, 24), Vector3(12.5, 3.0, -1), wall, "EastWall")
	for tx in [-12.5, 12.5]:
		SceneKit.cylinder(self, 2.2, 9.0, Vector3(tx, 4.5, -12.0), wall, "Tower")
	# gatehouse to the south with the portcullis opening to Truce
	SceneKit.box(self, Vector3(10.0, 6.0, 1.0), Vector3(-7.0, 3.0, 10.5), wall, "GateWallW")
	SceneKit.box(self, Vector3(10.0, 6.0, 1.0), Vector3(7.0, 3.0, 10.5), wall, "GateWallE")
	SceneKit.box(self, Vector3(4.0, 2.0, 1.0), Vector3(0, 5.0, 10.5), wall, "GateLintel")
	# a well, a cart, flower beds gone to moss
	SceneKit.cylinder(self, 0.9, 1.0, Vector3(-6.0, 0.5, 2.0), stone, "Well")
	var wood := SceneKit.material("res://assets/textures/wood_albedo.png", "res://assets/textures/wood_normal.png", 0.85, Color(0.75, 0.7, 0.65), true)
	SceneKit.box(self, Vector3(2.2, 0.8, 1.2), Vector3(7.0, 0.6, -5.0), wood, "Cart")
	SceneKit.cylinder(self, 0.5, 0.2, Vector3(6.0, 0.5, -4.3), wood, "Wheel", false)
	var moss := SceneKit.flat_color(Color(0.3, 0.38, 0.22), Color.BLACK, 0.0, 1.0)
	for bx in [-8.0, 8.0]:
		SceneKit.box(self, Vector3(3.0, 0.4, 1.2), Vector3(bx, 0.2, -8.5), stone, "Bed")
		SceneKit.box(self, Vector3(2.8, 0.1, 1.0), Vector3(bx, 0.45, -8.5), moss, "BedMoss", false)
	# rain
	_build_rain()
	add_marker("start", Vector3(0, 0, -9.5))
	add_marker("glenn", Vector3(-1.8, 0, -4.5))
	add_marker("magus", Vector3(2.2, 0, -5.0))
	add_marker("gate", Vector3(0, 0, 9.0))
	add_npc(&"glenn_marshall", "glenn_marshall", get_marker("glenn"), "s", 60.0, &"courtyard_glenn_after", "Glenn")
	add_npc(&"magus", "magus", get_marker("magus"), "s", 60.0, &"courtyard_magus_after", "Magus")
	add_door("GateDoor", Vector3(0, 0.8, 9.6), &"atrium", &"arrival", "Truce — the Horologe")


func after_ready() -> void:
	if not Flags.has(&"Prologue_Courtyard_Done"):
		controller.enabled = false
		await get_tree().create_timer(0.4).timeout
		controller.enabled = true
		await Story.run(&"prologue_courtyard")


func _build_rain() -> void:
	rain = GPUParticles3D.new()
	rain.amount = 900
	rain.lifetime = 1.6
	rain.position = Vector3(0, 9.0, -1.0)
	rain.visibility_aabb = AABB(Vector3(-15, -10, -15), Vector3(30, 12, 30))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 0.2, 13)
	pm.direction = Vector3(0.08, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 7.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, -2.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	pm.color = Color(0.75, 0.8, 0.9, 0.55)
	rain.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.02, 0.35)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.8, 0.85, 0.95, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	qm.material = mat
	rain.draw_pass_1 = qm
	add_child(rain)
