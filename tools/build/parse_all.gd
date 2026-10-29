## Loads every GDScript in the project (autoloads present) so compile errors surface.
##   godot --headless --path . --script res://tools/build/parse_all.gd
extends SceneTree

var _bad: int = 0


func _initialize() -> void:
	for dir in ["res://scripts", "res://scenes", "res://tests", "res://tools"]:
		_walk(dir)
	print("PARSE_ALL: %d scripts failed" % _bad)
	quit(1 if _bad > 0 else 0)


func _walk(dir: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	da.list_dir_begin()
	var name: String = da.get_next()
	while name != "":
		var full: String = dir.path_join(name)
		if da.current_is_dir():
			if not name.begins_with("."):
				_walk(full)
		elif name.ends_with(".gd"):
			var s: Script = load(full) as Script
			if s == null or not s.can_instantiate() and not (s as GDScript).is_tool() and s.get_instance_base_type() == &"":
				printerr("PARSE FAIL: %s" % full)
				_bad += 1
			elif s is GDScript and not (s as GDScript).is_abstract() and (s as GDScript).get_base_script() == null and s.get_instance_base_type() == &"":
				printerr("PARSE FAIL (no base): %s" % full)
				_bad += 1
		name = da.get_next()
	da.list_dir_end()
