## Boot: decide where to go. Autoloads are already up. Tests and captures may pass:
##   --scene=<id> / --location=<id>   start in a location instead of the title
##   --checkpoint=<id>                 set Game.checkpoint first (a scene's state machine reads it)
##   --party=a,b,c                     set the active party
##   --chapter=<n>  --integrity=<n>    set chapter / Crono's integrity
##   --flag=Name:State                 set a flag (repeatable)
extends Node

func _ready() -> void:
	var target: StringName = &"title"
	var spawn: StringName = &"start"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			target = StringName(arg.trim_prefix("--scene="))
		elif arg.begins_with("--location="):
			target = StringName(arg.trim_prefix("--location="))
		elif arg.begins_with("--spawn="):
			spawn = StringName(arg.trim_prefix("--spawn="))
		elif arg.begins_with("--checkpoint="):
			Game.checkpoint = StringName(arg.trim_prefix("--checkpoint="))
		elif arg.begins_with("--party="):
			var ids: Array[StringName] = []
			for p in arg.trim_prefix("--party=").split(","):
				ids.append(StringName(p))
			Game.set_party(ids)
		elif arg.begins_with("--chapter="):
			Game.chapter = int(arg.trim_prefix("--chapter="))
		elif arg.begins_with("--integrity="):
			Game.set_integrity(float(arg.trim_prefix("--integrity=")))
		elif arg.begins_with("--level="):
			for id in Game.roster.keys():
				Game.roster[id]["level"] = int(arg.trim_prefix("--level="))
		elif arg.begins_with("--flag="):
			var parts: PackedStringArray = arg.trim_prefix("--flag=").split(":")
			Flags.set_flag(StringName(parts[0]), StringName(parts[1]) if parts.size() > 1 else &"set")
	await get_tree().process_frame
	if Router.has_location(target):
		Router.go(target, spawn, 0.0)
	else:
		push_warning("Boot: location %s missing; staying on boot" % target)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--say="):
			# capture/debug: show a dialogue line once the scene is up
			await get_tree().create_timer(0.6).timeout
			Story.run(&"__say", [{"say": arg.trim_prefix("--say="), "who": "narrator"}, {"end": true}])
