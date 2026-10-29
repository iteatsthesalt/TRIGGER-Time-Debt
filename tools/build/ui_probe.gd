## Prints the dialogue box's tree state while a line is showing (debugging invisible UI).
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
	if f == 90:
		var S: Node = root.get_node("Story")
		var box: Control = S.get("box")
		var layer: CanvasLayer = S.get("layer")
		print("story running=%s box.visible=%s box.rect=%s panel.visible=%s panel.rect=%s layer.layer=%d layer.visible=%s layer.viewport=%s box.inside=%s text='%s' modulate=%s" % [
			str(S.call("is_running")), str(box.visible), str(box.get_global_rect()), str(box.get("panel").visible), str(box.get("panel").get_global_rect()),
			layer.layer, str(layer.visible), str(layer.get_viewport()), str(box.is_inside_tree()), String(box.get("text_label").text), str(box.modulate)])
		print("root size=%s content_scale=%s mode=%d" % [str(root.size), str(root.content_scale_size), root.content_scale_mode])
		var fade: ColorRect = root.get_node("Router").get("fade")
		print("fade alpha=%.2f layer=%d" % [fade.color.a, fade.get_parent().layer])
	return f >= 100
