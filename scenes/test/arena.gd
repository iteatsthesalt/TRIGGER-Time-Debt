## Open-ground test arena: a flat mossy field with encounter zones, for battle smoke tests and clips.
extends Location

func build() -> void:
	location_id = &"test_arena"
	universe_id = 0
	camera_distance = 15.0
	var stone := SceneKit.material("res://assets/textures/stone_mossy_albedo.png", "res://assets/textures/stone_normal.png", 0.95, Color.WHITE, true)
	var wall := SceneKit.material("res://assets/textures/castle_wall_albedo.png", "res://assets/textures/castle_wall_normal.png", 0.9, Color.WHITE, true)
	SceneKit.floor_plane(self, Vector2(60, 60), Vector3.ZERO, stone)
	SceneKit.box(self, Vector3(60, 3.0, 1.0), Vector3(0, 1.5, -20), wall, "NorthWall")
	for i in 4:
		var wood := SceneKit.material("res://assets/textures/wood_albedo.png", "res://assets/textures/wood_normal.png", 0.9, Color.WHITE, true)
		SceneKit.box(self, Vector3(0.8, 0.8, 0.8), Vector3(-10.0 + float(i) * 6.5, 0.4, -12.0), wood, "Crate%d" % i)
	add_marker("start", Vector3(0, 0, 6))
	var enc: String = "kitchen_spoons"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--encounter="):
			enc = arg.trim_prefix("--encounter=")
	add_zone(StringName(enc), Vector3(0, 0, -4), 5.0)

func after_ready() -> void:
	# Autobattle runs: walk the leader into the zone on the first frames.
	for arg in OS.get_cmdline_user_args():
		if arg == "--autobattle":
			await get_tree().create_timer(0.5).timeout
			if not party_actors.is_empty():
				party_actors[0].walk_to(Vector3(0, 0, -3.0), 5.0)
