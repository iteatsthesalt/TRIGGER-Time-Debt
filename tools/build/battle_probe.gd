## Headless battle probe: boots the game into a location (default test_arena) with the given user args,
## then prints battle state every --every=N frames and the summary when the battle ends. Exits after
## --frames=N or when the boss battle finishes.
##   godot --headless --path . --script res://tools/build/battle_probe.gd -- --scene=test_arena --autobattle --boss=atrium_cradle --party=crono,sera,marle
extends SceneTree

var frames_total: int = 6000
var every: int = 300
var scene_id: String = "test_arena"
var _frame: int = 0
var _started: bool = false
var _battle_seen: bool = false
var _done: bool = false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			frames_total = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--every="):
			every = int(arg.trim_prefix("--every="))
		elif arg.begins_with("--scene="):
			scene_id = arg.trim_prefix("--scene=")
	_boot.call_deferred()


func _boot() -> void:
	var packed: PackedScene = load("res://scenes/boot/boot.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	current_scene = node
	_started = true
	await process_frame
	var router: Node = root.get_node("Router")
	if router.call("has_location", StringName(scene_id)):
		router.call("go", StringName(scene_id), &"start", 0.0)
	await process_frame
	await process_frame
	var loc: Node = router.get("current_scene")
	if loc != null and loc.has_signal("battle_finished"):
		loc.connect("battle_started", func() -> void:
			_battle_seen = true
			print("PROBE battle started"))
		loc.connect("battle_finished", func(victory: bool) -> void:
			print("PROBE battle finished victory=%s" % str(victory))
			_done = true)


func _process(_delta: float) -> bool:
	if not _started:
		return false
	_frame += 1
	if _frame % every == 0:
		_report()
	if _frame >= frames_total or _done:
		_report()
		print("PROBE_END frames=%d battle_seen=%s done=%s" % [_frame, str(_battle_seen), str(_done)])
		return true
	return false


func _report() -> void:
	var router: Node = root.get_node_or_null("Router")
	var loc: Node = router.get("current_scene") if router else null
	if loc == null:
		print("PROBE f%d no location" % _frame)
		return
	var battle: Node = loc.get("battle") if loc.get("battle") != null else null
	var story: Node = root.get_node_or_null("Story")
	var line: String = "PROBE f%d story=%s" % [_frame, str(story.call("is_running")) if story else "?"]
	if battle == null or not is_instance_valid(battle):
		print(line + " no battle")
		return
	var coord: Node = battle.get("coordinator")
	if coord != null:
		line += " state=%d t=%.1f bp=%d paused=%s" % [int(coord.get("state")), float(coord.get("battle_time")), int(coord.get("bank").get("bp")), str(coord.get("paused"))]
		for u in coord.get("party"):
			var st: Node = u.get_node_or_null("CombatantStats")
			if st:
				line += " | %s hp=%d/%d" % [String(st.get("actor_id")), int(st.get("hp")), int(st.call("max_hp"))]
		for e in coord.get("enemies"):
			var st2: Node = e.get_node_or_null("CombatantStats")
			var sh: Node = e.get_node_or_null("ShieldComponent")
			if st2:
				line += " | %s hp=%d/%d sh=%d/%d%s" % [String(st2.get("actor_id")), int(st2.get("hp")), int(st2.call("max_hp")), int(sh.get("current_shield")) if sh else -1, int(sh.call("max_total")) if sh else -1, " BROKEN" if sh and bool(sh.get("is_broken")) else ""]
	var boss: Node = battle.get("boss")
	if boss != null:
		line += " | boss phase=%d sealed=%s adds=%d" % [int(boss.get("phase_index")), str(boss.call("is_sealed")), (boss.get("adds_alive") as Array).size()]
		# directors that count rebuilds (the 999 Shard Doll) show how far the split lesson has gone
		var director: Variant = boss.get("director")
		if director != null and "rebuilds" in director:
			line += " rebuilds=%d" % int(director.get("rebuilds"))
	print(line)
