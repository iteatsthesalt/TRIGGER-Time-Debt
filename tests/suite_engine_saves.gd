## The Possibility Engine and the save files (the engine_saves audit cluster): codex leans across a save, the
## Amber Rift paid once by any route, flag permanence, the cycle reset's single owner and New Game+'s bias, the
## endings table, settings in their own file, atomic and corrupt slots, the probes' scratch directory, the
## porcelain_stress RTPC, the Atrium Siege at integrity 0 and the Router leaving a held black to its location.
## The runner suspends Saves, so every file here lands in user://scratch, never in the player's saves.
extends "res://tests/suite_base.gd"

const ARENA := "res://scenes/test/arena.tscn"

var _flags_snap: Dictionary = {}


func _snap() -> void:
	_flags_snap = Flags.to_save().duplicate(true)


func _restore() -> void:
	Flags.from_save(_flags_snap)


func _fast_story() -> void:
	Story.auto_advance_s = 0.01
	Story.auto_choice = 0
	Story.skip_waits = true


func _slow_story() -> void:
	Story.auto_advance_s = -1.0
	Story.auto_choice = -1
	Story.skip_waits = false


# ---------------------------------------------------------------- codex leans across a save (CORE-3, GAP2-3)

func test_leans_keep_int_keys_and_their_cap_across_a_save() -> void:
	_snap()
	check(Saves.suspended, "the test runner keeps Saves in the scratch directory")
	Flags.leans.clear()
	var p0: int = Flags.prismatic
	var b0: int = Flags.beckons
	for i in 5:
		Flags.add_lean(1, "P")
	check_eq(Flags.prismatic, p0 + 5, "five Prismatic leans in U1")
	check_eq(Flags.beckons, b0, "a lean is earned in battle and grants no Beckons (Combat Laws 7.7, CORE-22)")
	var parsed: Variant = JSON.parse_string(JSON.stringify(Flags.to_save()))
	Flags.from_save(parsed)
	check(Flags.leans.has(1) and not Flags.leans.has("1"), "after a JSON round trip the universe key is the int again")
	Flags.add_lean(1, "P")
	check_eq(Flags.prismatic, p0 + 5, "the +5 cap still holds after the load (Combat Laws 15.9)")
	check_eq(Flags.leans.keys().size(), 1, "one record per universe, not \"1\" beside 1")
	check(Saves.save(9), "saved slot 9")
	Flags.leans.clear()
	check(Saves.load(9), "loaded slot 9")
	check_eq(int(Flags.leans.get(1, {}).get("P", 0)), 5, "the disk round trip restores the lean under the int key")
	Flags.add_lean(1, "P")
	check_eq(int(Flags.leans[1]["P"]), 5, "and the cap holds there too")
	Flags.add_counter(&"t_engine_counter", 2)
	var counters_out: Dictionary = Flags.to_save()["counters"]
	Flags.add_counter(&"t_engine_counter", 1)
	check_eq(int(counters_out["t_engine_counter"]), 2, "to_save hands out a copy, so a snapshot does not move with play")
	Saves.delete(9)
	_restore()
	Game.new_game()


# ---------------------------------------------------------------- Amber Rifts paid once (CORE-6, STORY-6, STORY-7)

func test_the_bowl_still_whole_pays_fifteen_by_either_route() -> void:
	_snap()
	var p0: int = Flags.prismatic
	var b0: int = Flags.beckons
	Flags.set_flag(&"The_Bowl_Still_Whole", &"set")
	check_eq(Flags.prismatic, p0 + 15, "the breakfast route: the rift's +15 Prismatic (Story Bible 9.3)")
	check_eq(Flags.beckons, b0 + 15, "and 15 Beckons")
	check(Flags.amber_rifts.has(&"The_Bowl_Still_Whole"), "the rift is registered under the flag")
	_restore()
	p0 = Flags.prismatic
	b0 = Flags.beckons
	Flags.set_flag(&"The_Bowl_Still_Whole", &"set", {"prismatic": 15, "light": 5})
	check_eq(Flags.prismatic, p0 + 15, "an override's Prismatic is not paid on top of the rift (the Cradle route)")
	check_eq(Flags.beckons, b0 + 20, "its other affinity is (+5 Light, 20 Beckons in all)")
	_restore()


func test_goyama_both_pays_one_rift_with_its_dialogue() -> void:
	_snap()
	_fast_story()
	var p0: int = Flags.prismatic
	await Story.run(&"t_goyama_both", [{"set_flag": "Goyama:Both"}, {"rift": "Amber_Rift_U1_Goyama"}, {"end": true}])
	check(Flags.is_state(&"Goyama", &"Both"), "sealed with a vial kept")
	check_eq(Flags.prismatic, p0 + 15, "Goyama Both is +15 Prismatic (Story Bible 9.3), not the state's and the rift's")
	check_eq(Flags.amber_rifts.count(&"Amber_Rift_U1_Goyama"), 1, "the flag and the dialogue name one rift source")
	_slow_story()
	_restore()


# ---------------------------------------------------------------- flag permanence (CORE-20)

func test_a_defined_flag_keeps_its_first_state_this_cycle() -> void:
	_snap()
	var l0: int = Flags.light
	var d0: int = Flags.dark
	Flags.set_flag(&"Prologue_Fall", &"Teach_Her_To_Land")
	Flags.set_flag(&"Prologue_Fall", &"Hold_The_Copy_Together")
	check(Flags.is_state(&"Prologue_Fall", &"Teach_Her_To_Land"), "the second state is refused (Story Bible 9.2)")
	check_eq(Flags.light, l0 + 30, "the first state's Light stands")
	check_eq(Flags.dark, d0, "and the refused state writes no Dark")
	Flags.set_flag(&"Seed_of_Doan", &"Grown")
	Flags.set_flag(&"Seed_of_Doan", &"Ash")
	check(Flags.is_state(&"Seed_of_Doan", &"Ash"), "a mutable flag may move on (the Seed burned for fuel)")
	Flags.set_flag(&"t_script_local", &"a")
	Flags.set_flag(&"t_script_local", &"b")
	check(Flags.is_state(&"t_script_local", &"b"), "a script-local flag (no definition) is free")
	_restore()


# ---------------------------------------------------------------- the cycle reset and New Game+ (CORE-4, CORE-17)

func test_new_game_owns_the_cycle_reset_and_new_game_plus_biases() -> void:
	_snap()
	Game.new_game()
	check_eq(Flags.cycle, 1, "a first run is cycle 1")
	check_eq(Flags.bias, &"", "with no bias")
	var title_src: String = (load("res://scripts/ui/title.gd") as GDScript).source_code
	check(not title_src.contains("reset_cycle"), "the title's New Game leaves the reset to Game.new_game")
	for probe in ["prologue_probe", "ch1_probe"]:
		var src: String = (load("res://tools/build/%s.gd" % probe) as GDScript).source_code
		check(not src.contains("reset_cycle"), "%s does not reset the cycle a second time" % probe)
	Flags.light = 20
	Flags.dark = 55
	Flags.prismatic = 30
	Game.new_game_plus = true
	Game.new_game()
	check_eq(Flags.cycle, 2, "New Game+ is the next cycle")
	check_eq(Flags.bias, &"dark", "biased toward the finished cycle's dominant affinity (15.10)")
	check_eq(Flags.dark, 10, "+10 Dark to start")
	check_near(Game.sera_debt, 5.0, 0.001, "Sera remembers the loop: 5 permanent Debt")
	Game.new_game_plus = false
	Game.new_game()
	check_near(Game.sera_permanent_baseline, 0.0, 0.001, "a fresh New Game drops the loop's baseline again")
	check_eq(Flags.cycle, 1, "and is cycle 1")
	_restore()


# ---------------------------------------------------------------- the endings table (CORE-5)

func test_every_ending_tests_defined_flags_and_each_predicate_holds() -> void:
	check_eq(Data.endings.size(), 8, "eight endings (Story Bible 7.1)")
	var table_errors: Array[String] = EndingRules.validation_errors(Data.endings, Data.flags)
	check(table_errors.is_empty(), "every flag an ending tests is defined: %s" % ", ".join(table_errors))
	check(not EndingRules.validation_errors([{"id": 9, "flags": ["Seed_of_Doan_Grown"]}], Data.flags).is_empty(),
		"a Flag_State spelling is rejected (it names no flag)")
	_snap()
	for e in Data.endings:
		var row: Dictionary = e
		_meet(row)
		check(Flags.qualifying_endings().has(int(row["id"])), "ending %d (%s) qualifies when its row holds" % [int(row["id"]), row["name"]])
		var flags_list: Array = row.get("flags", [])
		if not flags_list.is_empty():
			Flags.flags.erase(StringName(FlagRef.split(String(flags_list[0]))[0]))
			check(not EndingRules.qualifies(row), "ending %d fails without %s" % [int(row["id"]), flags_list[0]])
	_meet(Data.endings[4])
	Flags.flags[&"Bekkler_Confessed"] = &"set"
	check(not Flags.qualifying_endings().has(5), "Porcelain Silence needs Bekkler_Confessed never set")
	_meet(Data.endings[2])
	Flags.amber_rifts.resize(2)
	check(not Flags.qualifying_endings().has(3), "Vaelos Child needs three Amber Rifts")
	_restore()


## Put the engine in exactly the state an ending row asks for.
func _meet(row: Dictionary) -> void:
	Flags.flags.clear()
	Flags.counters.clear()
	Flags.amber_rifts.clear()
	for a in EndingRules.AFFINITIES:
		var v: int = int(row.get(a + "_min", row.get(a + "_max", 0)))
		Flags.set(a, v)
	for r in row.get("flags", []):
		var p: PackedStringArray = FlagRef.split(String(r))
		var st: String = p[1] if p[1] != "" else String((Data.flag_def(StringName(p[0]))["states"] as Array)[0]["id"])
		Flags.flags[StringName(p[0])] = StringName(st)
	var cs: Dictionary = row.get("counters", {})
	for c in cs.keys():
		Flags.counters[StringName(String(c))] = int(cs[c])
	for i in int(row.get("rifts", 0)):
		Flags.amber_rifts.append(StringName("t_rift_%d" % i))


# ---------------------------------------------------------------- settings outside the slots (CORE-7, GAP2-8)

func test_settings_live_in_their_own_file_and_survive_continue() -> void:
	var before: Dictionary = Game.settings.duplicate()
	DirAccess.remove_absolute(Saves.settings_path())
	Game.set_setting("reduced_flicker", false)
	check(Saves.save(9), "a checkpoint with reduced flicker off")
	check(not (Saves.peek(9)["game"] as Dictionary).has("settings"), "the slot carries no settings")
	Game.set_setting("reduced_flicker", true)
	check_eq(Saves.read_settings().get("reduced_flicker"), true, "set_setting writes the settings file")
	check(Saves.load(9), "Continue")
	check_eq(Game.settings["reduced_flicker"], true, "the option chosen on the title survives Continue")
	# a version 1 save carried the settings: adopted once while no settings file exists, sanely
	var legacy: Dictionary = Saves.peek(9)
	legacy["version"] = 1
	(legacy["game"] as Dictionary)["settings"] = {"reduced_flicker": false, "flow_speed": 4.0, "music": 0.5, "bogus": 1}
	check(Saves.write_atomic(Saves.slot_path(8), JSON.stringify(legacy)), "a hand-written version 1 slot")
	DirAccess.remove_absolute(Saves.settings_path())
	Game.settings["flow_speed"] = 1.0
	check(Saves.load(8), "it loads")
	check_eq(Game.settings["reduced_flicker"], false, "its options come over when there is no settings file")
	check_near(float(Game.settings["music"]), 0.5, 0.001, "volumes too")
	check_near(float(Game.settings["flow_speed"]), 1.0, 0.001, "a probe's x4 battle flow is not adopted")
	check(not Game.settings.has("bogus"), "an unknown key is not adopted")
	check(FileAccess.file_exists(Saves.settings_path()), "and the settings file now exists")
	Game.set_setting("reduced_flicker", true)
	check(Saves.load(8), "loading it again")
	check_eq(Game.settings["reduced_flicker"], true, "the file wins once it exists")
	Saves.delete(8)
	Saves.delete(9)
	Game.reset_settings()
	check_eq(Game.settings, Game.DEFAULT_SETTINGS, "reset_settings puts every option back (the runner starts there)")
	Game.settings = before
	Saves.write_settings(before)
	Game.settings_changed.emit()
	Game.new_game()


# ---------------------------------------------------------------- slots: atomic, corrupt, newer, slot 0 (CORE-16, GAP2-7)

func test_a_corrupt_or_newer_slot_reads_as_no_save() -> void:
	Game.new_game()
	check(Saves.save(8), "saved slot 8")
	check(not FileAccess.file_exists(Saves.slot_path(8) + ".tmp"), "the write went through a temporary file, renamed")
	check_eq(Saves.status(8), Saves.LOADABLE, "a fresh save is loadable")
	check_eq(int(Saves.peek(8).get("version", 0)), Saves.VERSION, "stamped with this build's version")
	var f := FileAccess.open(Saves.slot_path(8), FileAccess.WRITE)
	f.store_string("{\"game\": {\"chapter\": 3,")
	f.close()
	check_eq(Saves.status(8), Saves.CORRUPT, "a truncated file is corrupt")
	check(Saves.peek(8).is_empty() and not Saves.load(8), "and neither peeks nor loads")
	check(Saves.write_atomic(Saves.slot_path(8), JSON.stringify({"version": 1, "chapter": 2})), "a foreign object")
	check_eq(Saves.status(8), Saves.CORRUPT, "with no game or flags it is not a save")
	check(Saves.write_atomic(Saves.slot_path(8), JSON.stringify({"version": Saves.VERSION + 1, "game": {}, "flags": {}})), "a later build's save")
	check_eq(Saves.status(8), Saves.NEWER, "is refused as newer, not parsed as this format")
	check(not Saves.load(8), "and does not load")
	Saves.delete(8)
	check(Saves.save(7), "saved slot 7")
	DirAccess.rename_absolute(Saves.slot_path(7), Saves.slot_path(7) + ".tmp")
	check_eq(Saves.status(7), Saves.LOADABLE, "a rename cut after the old slot went still finds the new save")
	Saves.delete(7)
	check(not Saves.exists(7), "delete removes the temporary file too")
	var rows: Array[Dictionary] = Saves.summaries()
	check_eq(rows.size(), Saves.SLOTS + 1, "summaries list the autosave and every manual slot")
	check(int(rows[0]["slot"]) == 0 and bool(rows[0]["autosave"]), "slot 0, the autosave, first")


func test_the_title_hides_continue_for_a_corrupt_autosave() -> void:
	var router_scene: Node = Router.current_scene
	var had_zero: bool = Saves.exists(0)
	var f := FileAccess.open(Saves.slot_path(0), FileAccess.WRITE)
	f.store_string("not json")
	f.close()
	var title: Node = _track(load("res://scripts/ui/title.gd").new())
	root.add_child(title)
	check(not _menu_text(title).contains("Continue"), "a corrupt autosave shows no Continue row (got %s)" % _menu_text(title))
	Game.new_game()
	check(Saves.save(0), "a real autosave")
	title.call("_build_menu")
	check(_menu_text(title).contains("Continue"), "a loadable one does")
	var opts: Dictionary = Game.settings.duplicate()
	Game.settings["flow_speed"] = 1.0
	var paces: Array[float] = []
	for i in 3:
		title.call("_toggle_options")
		paces.append(float(Game.settings["flow_speed"]))
	check_eq(paces, [1.25, 0.75, 1.0] as Array[float], "Options steps battle flow through 1.25x, 0.75x, 1.0x (Combat Laws 3.7)")
	Game.settings = opts
	Saves.write_settings(opts)
	Router.current_scene = router_scene
	Audio.stop_music(0.0)
	if not had_zero:
		Saves.delete(0)


func _menu_text(title: Node) -> String:
	var texts: PackedStringArray = []
	for l in title.get("items"):
		texts.append((l as Label).text)
	return " | ".join(texts)


func test_suspended_saves_and_settings_stay_in_the_scratch_directory() -> void:
	check(Saves.slot_path(0).begins_with(Saves.SCRATCH_DIR), "a suspended slot is a scratch file")
	check(Saves.settings_path().begins_with(Saves.SCRATCH_DIR), "and so are the settings")
	Saves.suspended = false
	check_eq(Saves.slot_path(0), "user://saves/slot_00.json", "the player's autosave")
	check_eq(Saves.settings_path(), "user://settings.cfg", "the player's settings file")
	Saves.suspended = true
	for probe in ["prologue_probe", "ch1_probe", "battle_probe"]:
		var src: String = (load("res://tools/build/%s.gd" % probe) as GDScript).source_code
		check(src.contains("get_node(\"Saves\").set(\"suspended\", true)"), "%s suspends Saves before playing" % probe)


# ---------------------------------------------------------------- porcelain_stress (CORE-21)

func test_porcelain_stress_follows_integrity() -> void:
	var before: float = Game.crono_integrity
	Game.set_integrity(40.0)
	check_near(Audio.get_rtpc("porcelain_stress"), 60.0, 0.001, "integrity 40 is porcelain stress 60")
	Game.set_integrity(100.0)
	check_near(Audio.get_rtpc("porcelain_stress"), 0.0, 0.001, "a whole Crono is stress 0")
	Game.set_integrity(before)


# ---------------------------------------------------------------- the Atrium Siege (CORE-14, GAP3-1)

func test_integrity_zero_runs_the_siege_and_reglazes_to_twenty() -> void:
	_snap()
	Game.new_game()
	var sieges: int = Flags.counter(AtriumSiege.COUNTER)
	Game.set_integrity(0.0)
	check_near(Audio.get_rtpc("porcelain_stress"), 100.0, 0.001, "the flatline is porcelain stress 100 (16.3)")
	check(AtriumSiege.owed(), "a siege is owed at integrity 0")
	check(AtriumSiege.destination().is_empty(), "before any Atrium checkpoint the party stays where it is")
	await AtriumSiege.begin_if_owed(get_tree())
	check_eq(Flags.counter(AtriumSiege.COUNTER), sieges + 1, "the cycle records Atrium_Siege +1 (Ending 5 needs it)")
	check_near(Game.crono_integrity, 20.0, 0.001, "Sera reglazes Crono to 20")
	check(not AtriumSiege.owed() and not AtriumSiege.running(), "and the siege is over")
	Game.location = &"atrium"
	Game.spawn_point = &"arrival"
	check(Saves.save(9), "a save in the Atrium")
	check_eq(Game.atrium_spawn, &"arrival", "is the Atrium checkpoint a siege returns to")
	check_eq(AtriumSiege.destination(), [&"atrium", &"arrival"], "the siege jumps there")
	Game.location = &"guardia_kitchen"
	Game.spawn_point = &"start"
	check(Saves.save(9), "a save elsewhere")
	check(Saves.load(9), "and back")
	check_eq(Game.atrium_spawn, &"arrival", "keeps the last Atrium checkpoint, across the save too")
	Saves.delete(9)
	_restore()
	Game.new_game()


func test_a_field_defeat_at_five_percent_starts_the_siege() -> void:
	_snap()
	Game.new_game()
	Game.set_party([&"crono"] as Array[StringName])
	var loc: Location = (load(ARENA) as PackedScene).instantiate()
	root.add_child(loc)
	_track(loc)
	loc.place_party(&"start")
	await get_tree().process_frame
	Game.set_integrity(5.0)
	var sieges: int = Flags.counter(AtriumSiege.COUNTER)
	var z: EncounterZone = loc.zones[0]
	z.active = false
	loc._on_zone_triggered(z, "normal")
	loc.battle.coordinator.auto_tick = false
	(loc.get_actor(&"crono") as CombatActor).stats.apply_damage(999999, true)
	loc.battle.coordinator.force_end(false)
	Engine.time_scale = 4.0
	var t: float = 0.0
	while (loc.battle != null or AtriumSiege.running() or Flags.counter(AtriumSiege.COUNTER) == sieges) and t < 10.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	Engine.time_scale = 1.0
	check_eq(Flags.counter(AtriumSiege.COUNTER), sieges + 1, "the defeat's -5 reached 0 and the siege ran (check 25)")
	check_near(Game.crono_integrity, 20.0, 0.001, "Crono stands reglazed at 20")
	_restore()
	Game.new_game()


# ---------------------------------------------------------------- the Router and a held black (CORE-8)

func test_the_router_leaves_a_held_black_to_its_location() -> void:
	var src: String = (load("res://scripts/autoload/scene_router.gd") as GDScript).source_code
	check(src.contains("next.get(\"holds_black\") == true"), "Router.go skips its fade-in when the location holds black")
	var loc := Location.new()
	check(not loc.holds_black, "a location does not hold black by default")
	loc.free()
	var kitchen: String = (load("res://scripts/locations/guardia_kitchen.gd") as GDScript).source_code
	var at: int = kitchen.find("func _opening")
	check(at >= 0 and kitchen.find("holds_black = true", at) < kitchen.find("await", at), "the kitchen claims the black before its first await")
