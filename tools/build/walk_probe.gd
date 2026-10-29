extends SceneTree
var f := 0
var started := false
func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/boot/boot.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	current_scene = node
	started = true
func _process(_d: float) -> bool:
	if not started: return false
	f += 1
	if f % 60 == 0:
		var R: Node = root.get_node("Router")
		var loc: Node = R.get("current_scene")
		if loc and loc.get("party_actors") != null and loc.get("party_actors").size() > 0:
			var l: Node3D = loc.get("party_actors")[0]
			print("f%d leader=%s walk=%s frozen=%s story=%s battle=%s cradle=%s" % [f, str(l.global_position), str(l.get("_walk_target")), str(l.get("frozen")), str(root.get_node("Story").call("is_running")), str(loc.get("battle") != null), str(loc.get("_cradle_started"))])
	return f >= 600
