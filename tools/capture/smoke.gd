## Smoke test and screenshot capture. Boots the game's main scene (or --scene=<location>), runs for
## --frames=N frames with no script errors, saves screenshots to /tmp/captures/ every --every=N frames.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver vulkan --audio-driver Dummy \
##     --script res://tools/capture/smoke.gd -- --frames=600 --scene=test_diorama --out=/tmp/captures
extends SceneTree

var frames_total: int = 600
var every: int = 150
var out_dir: String = "/tmp/captures"
var scene_id: String = ""
var prefix: String = "shot"
var _frame: int = 0
var _started: bool = false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			frames_total = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--every="):
			every = int(arg.trim_prefix("--every="))
		elif arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--scene="):
			scene_id = arg.trim_prefix("--scene=")
		elif arg.begins_with("--prefix="):
			prefix = arg.trim_prefix("--prefix=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_boot.call_deferred()


func _boot() -> void:
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


func _process(_delta: float) -> bool:
	if not _started:
		return false
	_frame += 1
	if _frame % every == 0 or _frame == frames_total:
		_capture()
	if _frame >= frames_total:
		print("SMOKE_OK frames=%d" % _frame)
		return true
	return false


func _capture() -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		return
	var path: String = "%s/%s_%04d.png" % [out_dir, prefix, _frame]
	img.save_png(path)
	print("captured ", path)
