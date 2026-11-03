## Smoke test and screenshot capture. Boots the game's main scene (or --scene=<location>), runs for
## --frames=N frames with no script errors, saves screenshots to /tmp/captures/ every --every=N frames. Saves are
## suspended (user://scratch), so a capture that reaches an autosave never writes the player's slot.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan --audio-driver Dummy \
##     --script res://tools/capture/smoke.gd -- --frames=600 --scene=test_diorama --out=/tmp/captures
## --capture_after=<signal>:<seconds> also saves <prefix>_<signal>.png that many seconds after the loaded
## Location emits <signal> (battle_started: the shot shows the fight however fast the host draws frames, where a
## fixed frame lands on the walk on a GPU and on the empty field after the win under xvfb). The run is not over at
## --frames until that shot is taken, and fails (SMOKE_FAIL, exit 1) if it is not by --max_frames (10 x --frames).
extends SceneTree

var frames_total: int = 600
var every: int = 150
var out_dir: String = "/tmp/captures"
var scene_id: String = ""
var prefix: String = "shot"
var after_signal: StringName = &""
var after_s: float = 0.0
var max_frames: int = 0
var _frame: int = 0
var _started: bool = false
## Seconds since `after_signal` fired (-1: not yet), and whether its shot is saved.
var _after_t: float = -1.0
var _after_done: bool = false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			frames_total = maxi(1, int(arg.trim_prefix("--frames=")))
		elif arg.begins_with("--every="):
			every = maxi(1, int(arg.trim_prefix("--every=")))
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scene="):
			scene_id = arg.trim_prefix("--scene=")
		elif arg.begins_with("--prefix="):
			prefix = arg.trim_prefix("--prefix=")
		elif arg.begins_with("--capture_after="):
			var parts: PackedStringArray = arg.trim_prefix("--capture_after=").split(":")
			after_signal = StringName(parts[0])
			after_s = maxf(0.0, float(parts[1])) if parts.size() > 1 else 0.0
		elif arg.begins_with("--max_frames="):
			max_frames = maxi(1, int(arg.trim_prefix("--max_frames=")))
	if max_frames <= 0:
		max_frames = frames_total * 10
	DirAccess.make_dir_recursive_absolute(out_dir)
	_boot.call_deferred()


func _boot() -> void:
	# a capture plays real scenes, which autosave: keep it out of the player's slots and settings (Saves)
	root.get_node("Saves").set("suspended", true)
	if after_signal != &"" and root.has_node("Router"):
		root.get_node("Router").connect("location_loaded", _on_location_loaded)
	var packed: PackedScene = load("res://scenes/boot/boot.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	current_scene = node
	_started = true
	if scene_id != "":
		await process_frame
		if root.has_node("Router"):
			var router: Node = root.get_node("Router")
			if router.call("has_location", StringName(scene_id)):
				router.call("go", StringName(scene_id), &"start", 0.0)


## Watch every Location that loads for `after_signal`; the first emission starts the clock.
func _on_location_loaded(_id: StringName, node: Node) -> void:
	if not node.has_signal(after_signal):
		return
	var argc: int = 0
	for s in node.get_signal_list():
		if StringName(s["name"]) == after_signal:
			argc = (s["args"] as Array).size()
	var cb: Callable = _on_after_signal.unbind(argc) if argc > 0 else _on_after_signal
	if not node.is_connected(after_signal, cb):
		node.connect(after_signal, cb)


func _on_after_signal() -> void:
	if _after_t < 0.0:
		_after_t = 0.0
		print("SMOKE %s at frame %d" % [after_signal, _frame])


func _process(delta: float) -> bool:
	if not _started:
		return false
	_frame += 1
	if _frame % every == 0 or _frame == frames_total:
		_capture("%s_%04d" % [prefix, _frame])
	if _after_t >= 0.0 and not _after_done:
		_after_t += delta
		if _after_t >= after_s:
			_after_done = true
			_capture("%s_%s" % [prefix, after_signal])
	var waiting: bool = after_signal != &"" and not _after_done
	if _frame >= frames_total and not waiting:
		print("SMOKE_OK frames=%d" % _frame)
		return true
	if _frame >= max_frames:
		print("SMOKE_FAIL %s %s by frame %d" % [after_signal, "never fired" if _after_t < 0.0 else "shot not taken", _frame])
		quit(1)
		return true
	return false


func _capture(name: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		return
	var path: String = "%s/%s.png" % [out_dir, name]
	img.save_png(path)
	print("captured ", path)
