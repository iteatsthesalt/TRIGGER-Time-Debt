## Story runner, Router and gate-jump tests: the "Name:State" flag form, coroutine `call`s, sibling keys on
## verbs, all-hidden choices, Router.go's verdict, the gate toll and per-run script variables.
extends "res://tests/suite_base.gd"

const SCENE_SRC := """
extends Node3D
var log: Array = []
var markers: Dictionary = {}
var party_actors: Array = []
var actors: Dictionary = {}
func slow() -> void:
	log.append("start")
	await get_tree().process_frame
	await get_tree().process_frame
	log.append("end")
func quick() -> int:
	log.append("quick")
	return 1
func get_actor(id: StringName) -> Node:
	return actors.get(id, null)
func get_marker(name: StringName) -> Variant:
	if markers.has(name):
		return (markers[name] as Node3D).global_position
	return null
"""

const ACTOR_SRC := """
extends Node3D
var faced_toward: Variant = null
var faced_dir: String = ""
func face(dir: String) -> void:
	faced_dir = dir
func face_toward(p: Vector3) -> void:
	faced_toward = p
"""


func _fast_story() -> void:
	Story.auto_advance_s = 0.01
	Story.auto_choice = 0
	Story.skip_waits = true


func _slow_story() -> void:
	Story.auto_advance_s = -1.0
	Story.auto_choice = -1
	Story.skip_waits = false


func _make(src: String, name: String) -> Node3D:
	var gs := GDScript.new()
	gs.source_code = src
	gs.reload()
	var n: Node3D = gs.new()
	n.name = name
	return n


## A stub location as the tree's current scene; the caller restores it with _unstage.
func _stage() -> Node3D:
	var scene: Node3D = _make(SCENE_SRC, "StubScene")
	root.add_child(scene)
	_track(scene)
	get_tree().current_scene = scene
	return scene


func _unstage() -> void:
	get_tree().current_scene = null


# ---------------------------------------------------------------- flags

func test_set_flag_name_colon_state_form() -> void:
	_fast_story()
	await Story.run(&"t_colon", [
		{"set_flag": "Story_Test_Colon:Sealed"},
		{"set_flag": "Story_Test_Override:Kept", "state": "Taken"},
		{"if": {"flag": "Story_Test_Colon:Sealed"}, "then": "yes", "else": "no"},
		{"label": "no"}, {"set_flag": "Story_Test_Branch:No"}, {"end": true},
		{"label": "yes"}, {"set_flag": "Story_Test_Branch:Yes"}, {"end": true},
	])
	check(Flags.is_state(&"Story_Test_Colon", &"Sealed"), "'Name:State' splits into the flag and its state")
	check(not Flags.has(&"Story_Test_Colon:Sealed"), "no literal 'Name:State' key is written")
	check(Flags.is_state(&"Story_Test_Override", &"Taken"), "an explicit state wins over the colon")
	check(Flags.is_state(&"Story_Test_Branch", &"Yes"), "a condition reads the colon form too")
	check(Story._test({"not_flag": "Story_Test_Colon:Kept"}), "not_flag with a state is true for another state")
	check(not Story._test({"not_flag": "Story_Test_Colon:Sealed"}), "not_flag with the held state is false")
	for f in [&"Story_Test_Colon", &"Story_Test_Override", &"Story_Test_Branch"]:
		Flags.flags.erase(f)
	_slow_story()


func test_chapter2_goyama_resolution_reads_colon_flags() -> void:
	var snap: Dictionary = Flags.to_save().duplicate(true)
	_fast_story()
	var light_before: int = Flags.light
	await Story.run(&"t_gourd", [{"set_flag": "The_Gourd:Sealed"}, {"counter": "house_saved", "add": 3}, {"end": true}])
	check(Flags.is_state(&"The_Gourd", &"Sealed"), "the Gourd choice lands on the real flag")
	check(Flags.light >= light_before + 30, "the flag definition's Light affinity is written (got %d from %d)" % [Flags.light, light_before])
	await Story.run(&"ch2_goyama_flag_resolve")
	check(Flags.is_state(&"Goyama", &"Repainted"), "the castle-gate resolution repaints Goyama after a sealed vein")
	Flags.from_save(snap)
	_slow_story()


# ---------------------------------------------------------------- call, choice, siblings

func test_call_waits_for_a_coroutine_method() -> void:
	var scene: Node3D = _stage()
	_fast_story()
	var cb := func(_who: String, _text: String) -> void: scene.log.append("line")
	Story.line_shown.connect(cb)
	await Story.run(&"t_call", [{"call": "slow"}, {"call": "quick"}, {"say": "after", "who": "narrator"}, {"end": true}])
	Story.line_shown.disconnect(cb)
	check_eq(scene.log, ["start", "end", "quick", "line"], "the line waits for the coroutine; a plain method returns at once")
	_unstage()
	_slow_story()


func test_choice_with_every_option_hidden_skips_instead_of_hanging() -> void:
	_fast_story()
	var seen: Array = []
	var cb := func(_who: String, text: String) -> void: seen.append(text)
	Story.line_shown.connect(cb)
	Story.run(&"t_hidden", [
		{"choice": [{"text": "Glenn", "if": {"flag": "Story_Test_Never"}}, {"text": "Krona", "if": {"recruited": "nobody_here"}}], "who": "crono"},
		{"say": "after", "who": "narrator"},
		{"end": true},
	])
	var frames: int = 0
	while Story.is_running() and frames < 300:
		await get_tree().process_frame
		frames += 1
	Story.line_shown.disconnect(cb)
	check(not Story.is_running(), "the script finished (frames waited: %d)" % frames)
	check_eq(seen, ["after"], "the line after the empty choice was shown")
	_slow_story()


func test_sibling_keys_apply_on_say_caption_goto_if_end_and_wait() -> void:
	_fast_story()
	Router.fade.color.a = 1.0
	var seen: Array = []
	var cb := func(_who: String, text: String) -> void: seen.append(text)
	Story.line_shown.connect(cb)
	await Story.run(&"t_sib", [
		{"fade": "in", "s": 0.0, "wait": 0.0},
		{"say": "x", "who": "narrator", "counter": "story_test_sib", "add": 2},
		{"caption": "c", "give_item": "story_test_item"},
		{"goto": "on", "set_flag": "Story_Test_Sib:On"},
		{"say": "skipped", "who": "narrator"},
		{"label": "on"},
		{"if": {"flag": "Story_Test_Sib:On"}, "then": "fin", "key_item": "story_test_key"},
		{"say": "skipped too", "who": "narrator"},
		{"label": "fin"},
		{"end": true, "set_flag": "Story_Test_End", "state": "Yes"},
	])
	Story.line_shown.disconnect(cb)
	check_near(Router.fade.color.a, 0.0, 0.001, "{fade in, wait} fades before it waits")
	check_eq(seen, ["x"], "goto and if still jump after their side effects")
	check_eq(Flags.counter(&"story_test_sib"), 2, "a counter on a say line")
	check_eq(int(Game.inventory.get("story_test_item", 0)), 1, "give_item on a caption")
	check(Flags.is_state(&"Story_Test_Sib", &"On"), "set_flag on a goto")
	check(Game.key_items.has(&"story_test_key"), "key_item on an if")
	check(Flags.is_state(&"Story_Test_End", &"Yes"), "set_flag with a state key on an end")
	Flags.flags.erase(&"Story_Test_Sib")
	Flags.flags.erase(&"Story_Test_End")
	Flags.counters.erase(&"story_test_sib")
	Game.inventory.erase("story_test_item")
	Game.key_items.erase(&"story_test_key")
	_slow_story()


func test_stop_music_fade_and_move_wait_keys_stay_with_their_command() -> void:
	_fast_story()
	Router.fade.color.a = 0.37
	Audio.current_track = &"story_test_track"
	await Story.run(&"t_keys", [
		{"stop_music": true, "fade": 0.0},
		{"move": "nobody", "to": "nowhere", "wait": false},
		{"music": "stop", "fade": 0.0},
		{"end": true},
	])
	check_near(Router.fade.color.a, 0.37, 0.001, "stop_music's numeric fade is not a screen fade")
	check(String(Audio.current_track) != "stop", "music: stop stops the music instead of playing a track called stop")
	_slow_story()


func test_face_to_show_at_and_camera_focus_on_a_marker() -> void:
	var scene: Node3D = _stage()
	var krona: Node3D = _make(ACTOR_SRC, "krona")
	var crono: Node3D = _make(ACTOR_SRC, "crono")
	scene.add_child(krona)
	scene.add_child(crono)
	crono.global_position = Vector3(3, 0, 0)
	krona.visible = false
	scene.actors[&"krona"] = krona
	scene.actors[&"crono"] = crono
	var spot := Node3D.new()
	spot.name = "spot"
	scene.add_child(spot)
	spot.global_position = Vector3(5, 0, -2)
	scene.markers[&"spot"] = spot
	var focused: Array = []
	var cb := func(_mode: String, focus: Node) -> void: focused.append(focus)
	Story.camera_requested.connect(cb)
	_fast_story()
	await Story.run(&"t_face", [
		{"show": "krona", "at": "spot"},
		{"face": "krona", "to": "crono"},
		{"face": "crono", "dir": "n"},
		{"camera": "truth", "focus": "spot"},
		{"camera": "truth", "focus": "crono"},
		{"end": true},
	])
	Story.camera_requested.disconnect(cb)
	check(krona.visible, "show makes the actor visible")
	check(krona.global_position.is_equal_approx(Vector3(5, 0, -2)), "show ... at places the actor on the marker first")
	check(krona.faced_toward is Vector3 and (krona.faced_toward as Vector3).is_equal_approx(crono.global_position), "face ... to turns toward the other actor")
	check_eq(crono.faced_dir, "n", "face ... dir still works")
	check(focused.size() == 2 and focused[0] == spot and focused[1] == crono, "camera focus resolves a marker node or an actor")
	_unstage()
	_slow_story()


# ---------------------------------------------------------------- router and gates

func test_router_go_reports_refusals_and_story_records_them() -> void:
	var ok: bool = await Router.go(&"story_test_no_such_place")
	check(not ok, "an unknown location is refused")
	Router.transitioning = true
	var ok2: bool = await Router.go(&"title")
	check(not ok2, "a second transition is refused while one runs")
	Router.transitioning = false
	check(Router.has_location(&"guardia_kitchen"), "a built location is known")
	check(not Router.has_location(&"leene_square"), "an unbuilt registry entry is not a location yet")
	_fast_story()
	var seen: Array = []
	var cb := func(_who: String, text: String) -> void: seen.append(text)
	Story.line_shown.connect(cb)
	Story.last_refused_go = &""
	await Story.run(&"t_go", [{"go": "story_test_no_such_place"}, {"say": "unreached", "who": "narrator"}, {"end": true}])
	check_eq(String(Story.last_refused_go), "story_test_no_such_place", "the Story records the refused go")
	check_eq(seen, [], "a refused go still ends the script by default")
	await Story.run(&"t_go2", [{"go": "story_test_no_such_place", "end_after": false}, {"say": "reached", "who": "narrator"}, {"end": true}])
	check_eq(seen, ["reached"], "end_after false continues after the go")
	Story.line_shown.disconnect(cb)
	Story.last_refused_go = &""
	_slow_story()


func test_gate_jump_charges_the_first_traversal_only() -> void:
	var snap: Dictionary = Flags.to_save().duplicate(true)
	Game.set_integrity(100.0)
	Game.set_debt(0.0)
	check(GateJump.charge(0, 1, null), "the first jump through gate U1 costs")
	check_near(Game.crono_integrity, 99.6, 0.0001, "Crono pays the 0.4 collarbone")
	check_near(Game.sera_debt, 5.0, 0.0001, "Sera takes +5 Translucency Debt")
	check(not GateJump.charge(1, 0, null), "returning to the Atrium hub is free")
	check(not GateJump.charge(0, 1, null), "going back through an opened gate is free")
	check(not GateJump.charge(1, 1, null), "staying in a universe is not a jump")
	check(GateJump.charge(1, 2, null), "a new gate along the thread costs again")
	check_near(Game.crono_integrity, 99.2, 0.0001, "two gates, two collarbone payments")
	check_near(Game.sera_debt, 10.0, 0.0001, "two gates, ten debt")
	check(GateJump.is_opened(2) and not GateJump.is_opened(3), "opened gates are remembered")
	Flags.from_save(snap)
	Game.new_game()


func test_gate_jump_goes_through_the_live_components() -> void:
	var snap: Dictionary = Flags.to_save().duplicate(true)
	var scene: Node3D = _stage()
	var crono: Node3D = _party_member(&"crono", 5, Vector3.ZERO)
	var sera: Node3D = _party_member(&"sera", 5, Vector3(1, 0, 0))
	scene.party_actors = [crono, sera]
	var td: TimeDebtComponent = TimeDebtComponent.of(crono)
	var sol: SolidityComponent = SolidityComponent.of(sera)
	Game.set_integrity(80.0)
	Game.set_debt(10.0)
	td.integrity = 80.0
	sol.debt = 10.0
	td.reinforced_jumps = 1
	check(GateJump.charge(0, 4, scene), "the jump costs")
	check_near(td.integrity, 79.8, 0.0001, "Reinforced halves the collarbone on the component")
	check_near(Game.crono_integrity, 79.8, 0.0001, "Game mirrors the halved cost")
	check_near(sol.debt, 15.0, 0.0001, "Sera's component takes the +5")
	check_near(Game.sera_debt, 15.0, 0.0001, "Game mirrors her debt")
	_unstage()
	Flags.from_save(snap)
	Game.new_game()


func test_story_universe_command_charges_only_with_jump() -> void:
	var snap: Dictionary = Flags.to_save().duplicate(true)
	_fast_story()
	Game.set_integrity(100.0)
	Game.set_debt(0.0)
	await Story.run(&"t_dream", [{"universe": 7, "instant": true}, {"universe": 0, "instant": true}, {"end": true}])
	check_near(Game.crono_integrity, 100.0, 0.0001, "a canvas swap (the nightmare) is not a gate jump")
	check_near(Game.sera_debt, 0.0, 0.0001, "no debt for a canvas swap")
	await Story.run(&"t_leap", [{"universe": 3, "instant": true, "jump": true}, {"end": true}])
	check_eq(Universe.current, 3, "the canvas changed")
	check_near(Game.crono_integrity, 99.6, 0.0001, "universe ... jump charges Crono")
	check_near(Game.sera_debt, 5.0, 0.0001, "universe ... jump charges Sera")
	await Story.run(&"t_leap2", [{"universe": 0, "instant": true, "jump": true}, {"universe": 3, "instant": true, "jump": true}, {"end": true}])
	check_near(Game.sera_debt, 5.0, 0.0001, "hub and back through the open gate are free")
	Universe.set_universe(0, true)
	Flags.from_save(snap)
	Game.new_game()
	_slow_story()


# ---------------------------------------------------------------- vars and history

func test_story_vars_save_with_the_run_and_reset_on_new_game() -> void:
	_fast_story()
	await Story.run(&"t_var", [{"var": "story_test_var", "value": 3}, {"end": true}])
	check(Story._test({"var": "story_test_var", "value": 3}), "a var is readable by a condition")
	check(Saves.save(9), "saved slot 9")
	Story.reset()
	check(not Story._test({"var": "story_test_var", "value": 3}), "reset clears vars")
	check(Saves.load(9), "loaded slot 9")
	check(Story._test({"var": "story_test_var", "value": 3}), "vars come back with the save")
	Saves.delete(9)
	Game.new_game()
	check(not Story._test({"var": "story_test_var", "value": 3}), "a new game clears vars")
	_slow_story()


func test_history_keeps_the_last_lines_only() -> void:
	Story.reset()
	for i in Story.HISTORY_MAX + 5:
		Story._push_history("narrator", str(i))
	check_eq(Story.history().size(), Story.HISTORY_MAX, "history is bounded")
	check_eq(String(Story.history()[0]["text"]), "5", "the oldest lines fall off first")
	Story.reset()
	check_eq(Story.history().size(), 0, "reset empties the history")
