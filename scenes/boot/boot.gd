## Boot: decide where to go. Autoloads are already up. Tests and captures may pass --scene=<id>.
extends Node

func _ready() -> void:
	var target: StringName = &"title"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			target = StringName(arg.trim_prefix("--scene="))
		elif arg.begins_with("--location="):
			target = StringName(arg.trim_prefix("--location="))
	await get_tree().process_frame
	if Router.has_location(target):
		Router.go(target, &"start", 0.0)
	else:
		push_warning("Boot: location %s missing; staying on boot" % target)
