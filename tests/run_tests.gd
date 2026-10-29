## Headless test runner:
##   godot --headless --path . --import
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits 0 when everything passes, 1 otherwise. The suite itself lives in tests/suite_core.gd and is
## loaded at runtime so the autoload singletons (Data, Flags, Game...) resolve at compile time.
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var suite_script: GDScript = load("res://tests/suite_core.gd")
	if suite_script == null:
		printerr("cannot load tests/suite_core.gd")
		quit(1)
		return
	var suite: Node = suite_script.new()
	suite.root = root
	root.add_child(suite)
	await suite.run()
	quit(suite.exit_code)
