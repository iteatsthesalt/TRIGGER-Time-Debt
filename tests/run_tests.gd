## Headless test runner:
##   godot --headless --path . --import
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits 0 when everything passes, 1 otherwise. Every tests/suite_*.gd (extending tests/suite_base.gd) is loaded
## at runtime, in name order, so the autoload singletons (Data, Flags, Game...) resolve at compile time.
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var passed: int = 0
	var failed: int = 0
	var suites: Array[String] = []
	var da := DirAccess.open("res://tests")
	if da != null:
		for f in da.get_files():
			if f.begins_with("suite_") and f.ends_with(".gd") and f != "suite_base.gd":
				suites.append("res://tests/" + f)
	suites.sort()
	if suites.is_empty():
		printerr("no tests/suite_*.gd found")
		quit(1)
		return
	for path in suites:
		var suite_script: GDScript = load(path)
		if suite_script == null:
			printerr("cannot load %s" % path)
			failed += 1
			continue
		var suite: Node = suite_script.new()
		suite.root = root
		root.add_child(suite)
		await suite.run()
		passed += int(suite.passed())
		failed += int(suite.failed())
		suite.queue_free()
	print("\n%d passed, %d failed (%d suites)" % [passed, failed, suites.size()])
	quit(1 if failed > 0 else 0)
