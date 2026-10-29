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
		if arg.begins_with("--party="):
			var ids: Array[StringName] = []
			for p in arg.trim_prefix("--party=").split(","):
				ids.append(StringName(p))
			Game.set_party(ids)
		if arg.begins_with("--level="):
			for id in Game.roster.keys():
				Game.roster[id]["level"] = int(arg.trim_prefix("--level="))
	add_zone(StringName(enc), Vector3(0, 0, -4), 5.0)
	add_marker("boss", Vector3(0, 0, -6))
	add_marker("center", Vector3(0, 0, -2))

func after_ready() -> void:
	# Autobattle runs: walk the leader into the zone on the first frames. --boss=<id> starts a boss fight.
	var boss_id: String = ""
	var auto: bool = false
	var boss_hp: int = 0
	for arg in OS.get_cmdline_user_args():
		if arg == "--autobattle":
			auto = true
		if arg.begins_with("--boss="):
			boss_id = arg.trim_prefix("--boss=")
		if arg.begins_with("--boss_hp="):
			boss_hp = int(arg.trim_prefix("--boss_hp="))
	if auto:
		Story.auto_advance_s = 0.2
		Story.auto_choice = 0
		Game.settings["flow_speed"] = 3.0
	if boss_id != "":
		await get_tree().create_timer(0.3).timeout
		Story.run(&"arena_boss", [{"battle": "", "boss_id": boss_id, "boss": true, "at": "boss", "center": "center", "boss_hp": boss_hp, "on_win": "won", "on_lose": "lost"}, {"end": true}, {"label": "won"}, {"caption": "[boss defeated]"}, {"end": true}, {"label": "lost"}, {"caption": "[party fell]"}, {"end": true}])
	elif auto:
		await get_tree().create_timer(0.5).timeout
		if not party_actors.is_empty():
			party_actors[0].walk_to(Vector3(0, 0, -3.0), 5.0)
