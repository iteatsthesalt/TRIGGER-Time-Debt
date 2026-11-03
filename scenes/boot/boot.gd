## Boot: decide where to go. Autoloads are already up. Tests and captures may pass (the complete list):
##   --scene=<id> / --location=<id>   start in a location instead of the title
##   --spawn=<marker>                  the marker to stand on (default "start")
##   --checkpoint=<id>                 set Game.checkpoint first (a scene's state machine reads it)
##   --party=a,b,c                     set the active party (a guest such as Marle gets her roster row)
##   --level=<n>                       set every roster member's level, the party's guests included
##   --chapter=<n>                     set the chapter; a start into a location learns that chapter's kit
##                                     (without --chapter: chapter 0, the Prologue kit). BootArgs applies the
##                                     three in this order, whatever their order here
##   --integrity=<n>                   set Crono's integrity
##   --flag=Name:State                 set a flag (repeatable)
##   --say=<text>                      show one narrator line once the scene is up (capture/debug)
##   --save                            let a debug start write the player's own saves and settings: without it any
##                                     argument above but --say (and a --scene of the title) keeps them in the
##                                     scratch directory (BootArgs.suspends_saves, Saves.suspended)
## Battle arguments are read elsewhere: --autobattle by BattleScene (scripts/battle/battle_scene.gd) and the test
## arena, --boss=<id> and --boss_hp=<n> by the test arena (scenes/test/arena.gd).
extends Node

func _ready() -> void:
	if BootArgs.suspends_saves(OS.get_cmdline_user_args()):
		Saves.suspended = true  # a made-up state never overwrites the player's autosave
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
		elif arg.begins_with("--integrity="):
			Game.set_integrity(float(arg.trim_prefix("--integrity=")))
		elif arg.begins_with("--flag="):
			var parts: PackedStringArray = arg.trim_prefix("--flag=").split(":")
			Flags.set_flag(StringName(parts[0]), StringName(parts[1]) if parts.size() > 1 else &"set")
	# --party, --level and --chapter (the kit the probes fight with)
	BootArgs.apply(OS.get_cmdline_user_args(), target != &"title")
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
