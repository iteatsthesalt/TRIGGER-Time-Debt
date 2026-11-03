## Headless test runner:
##   godot --headless --path . --import
##   godot --headless --path . --script res://tests/run_tests.gd [-- --suites=<dir>]
## Exits 0 when everything passes, 1 otherwise. Every tests/suite_*.gd (extending tests/suite_base.gd) is loaded
## at runtime, in name order, so the autoload singletons (Data, Flags, Game...) resolve at compile time. A suite
## that does not load or parse is a failed suite (the rest still run), and every SCRIPT ERROR is counted
## (tests/script_error_log.gd): the test it stopped fails by name, and any error at all fails the run.
## --suites=<dir> runs the suite_*.gd of another folder (tools/build/test_tools.py runs the runner on its fixtures).
extends SceneTree

var _errors: Logger


func _initialize() -> void:
	_errors = (load("res://tests/script_error_log.gd") as GDScript).new()
	OS.add_logger(_errors)
	_run.call_deferred()


func _run() -> void:
	root.get_node("Saves").set("suspended", true)  # tests save and set options: never in the player's files
	root.get_node("Game").call("reset_settings")  # and run on the default options, not the player's
	var passed: int = 0
	var failed: int = 0
	var suites: Array[String] = []
	var dir: String = "res://tests"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suites="):
			dir = arg.trim_prefix("--suites=")
	var da := DirAccess.open(dir)
	if da != null:
		for f in da.get_files():
			if f.begins_with("suite_") and f.ends_with(".gd") and f != "suite_base.gd":
				suites.append(dir.path_join(f))
	suites.sort()
	if suites.is_empty():
		printerr("no suite_*.gd found in %s" % dir)
		quit(1)
		return
	for path in suites:
		var suite_script: GDScript = load(path)
		if suite_script == null or not suite_script.can_instantiate():
			printerr("FAIL cannot load %s (it does not parse: see the SCRIPT ERROR above)" % path)
			failed += 1
			continue
		var suite: Node = suite_script.new()
		suite.root = root
		suite.set("error_log", _errors)
		root.add_child(suite)
		await suite.run()
		passed += int(suite.passed())
		failed += int(suite.failed())
		suite.queue_free()
	await _silence()
	var errors: int = _errors.call("count")
	print("\n%d passed, %d failed (%d suites)" % [passed, failed, suites.size()])
	if errors > 0:
		printerr("FAIL %d SCRIPT ERROR(s) during the run; the first: %s" % [errors, String(_errors.call("first"))])
	OS.remove_logger(_errors)
	quit(1 if failed > 0 or errors > 0 else 0)


## Stop every player still sounding (the music loops, a sting, the last sfx) and give the AudioServer's mix thread
## real time to let go of their playbacks (it drops a stopped or freed player's playback on its next mix, not on a
## frame), so the exit's leak report is about the tests (tools/check.sh fails on one), not about whichever sound
## happened to be playing when the last suite ended.
func _silence() -> void:
	for p in root.find_children("*", "AudioStreamPlayer", true, false):
		(p as AudioStreamPlayer).stop()
	for p in root.find_children("*", "AudioStreamPlayer2D", true, false):
		(p as AudioStreamPlayer2D).stop()
	for p in root.find_children("*", "AudioStreamPlayer3D", true, false):
		(p as AudioStreamPlayer3D).stop()
	await create_timer(0.5, true, false, true).timeout
