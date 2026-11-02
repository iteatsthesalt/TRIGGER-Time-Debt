## The shipped locations (the kitchen, the Atrium) and their save points: the Fair call commits nothing until Leene
## Square can be reached, every autosave resumes at the marker it was made at (never the loft after the time skip),
## a lost field fight jumps back to where it began, one Marle and one Crono, autosaves between the hub's opening and
## the Fair that do not end the day, no save pollution, the Seed of Doan's one state, the Cradle's trigger behind
## the tutorial fights, the lab echoes its caption names, a dry Rewind that costs nothing and cues that have sounds.
## The scenes are the real ones (scenes/u0), built headless; story runs fast and is restored after each test.
extends "res://tests/suite_base.gd"

const ATRIUM := "res://scenes/u0/atrium_horologe.tscn"
const KITCHEN := "res://scenes/u0/guardia_kitchen.tscn"
const ARENA := "res://scenes/test/arena.tscn"
const SQUARE := &"leene_square"
const CP_FREE := &"ch1_hub_free"
const HUB_PARTY: Array[StringName] = [&"sera", &"crono"]


func _fast_story() -> void:
	Story.auto_advance_s = 0.01
	Story.auto_choice = 0
	Story.skip_waits = true


func _slow_story() -> void:
	Story.auto_advance_s = -1.0
	Story.auto_choice = -1
	Story.skip_waits = false
	get_tree().current_scene = null


## The Atrium at a checkpoint, with a party and flags, its opening run; the party stands at `start`.
func _atrium(cp: StringName, party: Array[StringName], flags: Dictionary = {}) -> Location:
	Game.new_game()
	Game.set_chapter(1)
	Game.location = &"atrium"
	Game.spawn_point = &"loft_bed"  # where the time skip's Router.go left it
	Game.checkpoint = cp
	Game.set_party(party)
	for f in flags.keys():
		Flags.set_flag(f, flags[f])
	_fast_story()
	var loc: Location = (load(ATRIUM) as PackedScene).instantiate()
	root.add_child(loc)
	_track(loc)
	get_tree().current_scene = loc  # Story's `call` lands on the current scene
	check(await _idle(), "the Atrium's opening for %s ran to its end" % cp)
	if cp == CP_FREE:
		loc.place_party(&"start")
	return loc


func _idle(max_s: float = 12.0) -> bool:
	var t: float = 0.0
	while (Story.is_running() or Router.transitioning) and t < max_s:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	return not Story.is_running() and not Router.transitioning


## Leene Square made unbuilt (its registry row points at no scene) or built (a stand-in); `restore` puts it back.
func _square(path: String) -> Variant:
	var before: Variant = Router.locations.get(SQUARE, null)
	Router.locations[SQUARE] = path
	return before


func _restore_square(before: Variant) -> void:
	if before == null:
		Router.locations.erase(SQUARE)
	else:
		Router.locations[SQUARE] = before


func _slot_game() -> Dictionary:
	return (Saves.peek(0) as Dictionary).get("game", {})


func _expect_slot(what: String, cp: StringName, spawn: StringName) -> void:
	var g: Dictionary = _slot_game()
	check_eq(StringName(String(g.get("checkpoint", ""))), cp, "%s: the autosave's checkpoint" % what)
	check_eq(StringName(String(g.get("spawn_point", ""))), spawn, "%s: the marker a Continue resumes at" % what)


## Bodies of `id` in the scene: field party members plus a cast actor.
func _bodies(loc: Location, id: StringName) -> int:
	var n: int = loc.party_actors.filter(func(a: CombatActor) -> bool: return a.actor_id == id).size()
	return n + (1 if loc.npc_actors.has(id) and loc.npc_actors[id] is CombatActor else 0)


# ---------------------------------------------------------------- the Fair (GAP2-1, STORY-22)

func test_the_fair_call_commits_nothing_while_leene_square_is_unbuilt() -> void:
	var before: Variant = _square("res://scenes/u0/__no_such_square.tscn")
	var loc: Location = await _atrium(CP_FREE, HUB_PARTY)
	var where: StringName = Router.current_location
	await Story.run(&"ch1_fair_call")
	check(not Flags.has(&"Ch1_Fair_Left"), "no departure is recorded")
	check_eq(Game.active_party, HUB_PARTY, "Game keeps the hub party")
	check_eq(loc.party_actors.size(), 2, "and the field agrees with it")
	check(not Router.transitioning and Router.current_location == where, "no transition was started")
	check(Story.box.caption_label.text.contains("not built yet"), "the call says why (got %s)" % Story.box.caption_label.text)
	_slow_story()
	_restore_square(before)
	Game.new_game()


func test_leaving_for_the_fair_commits_when_the_square_can_be_reached() -> void:
	var before: Variant = _square(ARENA)  # a built stand-in for the square
	var loc: Location = await _atrium(CP_FREE, HUB_PARTY)
	var router_scene: Node = Router.current_scene
	var router_loc: StringName = Router.current_location
	Router.current_scene = loc
	loc.leave_for_fair()
	check(Flags.has(&"Ch1_Fair_Left"), "the departure is recorded")
	check_eq(Game.active_party, [&"crono"] as Array[StringName], "Crono goes alone")
	check(Router.transitioning, "and the Router is taking him")
	Engine.time_scale = 4.0
	check(await _idle(), "the transition ends")
	Engine.time_scale = 1.0
	check_eq(Router.current_location, SQUARE, "he arrives in the square")
	check(not is_instance_valid(loc) or loc.is_queued_for_deletion(), "the hub scene is gone")
	var arrived: Node = Router.current_scene
	if is_instance_valid(arrived) and arrived != loc:
		arrived.free()
	Router.current_scene = router_scene
	Router.current_location = router_loc
	_slow_story()
	_restore_square(before)
	Game.new_game()


# ---------------------------------------------------------------- spawn points (GAP2-4, STORY-15)

func test_a_hub_save_resumes_at_its_marker_not_the_loft() -> void:
	var loc: Location = await _atrium(CP_FREE, HUB_PARTY)
	check(loc.autosave_at(&"ramp_bottom"), "the hub autosave is written")
	_expect_slot("the hub's opening", CP_FREE, &"ramp_bottom")
	loc.autosave_at(&"no_such_marker")
	check_eq(Game.spawn_point, &"ramp_bottom", "an unknown marker keeps the last spawn")
	Game.new_game()
	check(Saves.load(0), "Continue loads the autosave")
	var router_scene: Node = Router.current_scene
	var router_loc: StringName = Router.current_location
	Router.current_scene = loc
	check(await Router.go(Game.location, Game.spawn_point, 0.0), "Continue lands in the Atrium (title.gd's route)")
	var hub := Router.current_scene as Location
	check(hub != null and hub != loc, "a fresh Atrium is up")
	var leader: CombatActor = hub.party_actors[0]
	check(leader.global_position.distance_to(hub.get_marker(&"ramp_bottom")) < 0.5, "the party resumes at the ramp's foot (at %s)" % str(leader.global_position))
	check(leader.global_position.y < 1.0, "on the floor, not up in the loft")
	hub.free()
	Router.current_scene = router_scene
	Router.current_location = router_loc
	_slow_story()
	Game.new_game()


func test_a_field_defeat_returns_to_where_the_battle_began() -> void:
	Game.new_game()
	Game.set_party([&"crono"] as Array[StringName])
	var loc: Location = (load(ARENA) as PackedScene).instantiate()
	root.add_child(loc)
	_track(loc)
	var crono := loc.get_actor(&"crono") as CombatActor
	var from := Vector3(9.0, 0.05, 3.0)
	loc.place_party(from)  # the Vector3 form, before any physics frame can touch the arena's zone
	await get_tree().physics_frame
	var z: EncounterZone = loc.zones[0]
	z.active = false
	loc._on_zone_triggered(z, "normal")
	loc.battle.coordinator.auto_tick = false
	crono.global_position = Vector3(-3.0, 0.05, -2.0)  # the plane moved him
	crono.stats.apply_damage(999999, true)
	loc.battle.coordinator.force_end(false)
	Engine.time_scale = 4.0
	var t: float = 0.0
	while loc.battle != null and t < 8.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	Engine.time_scale = 1.0
	check(loc.battle == null, "the lost battle hands back to the field")
	var flat := Vector2(crono.global_position.x - from.x, crono.global_position.z - from.z)
	check(flat.length() < 0.5, "Sera jumps the party back to where the fight began (at %s)" % str(crono.global_position))
	check(crono.global_position.distance_to(loc.get_marker(&"start")) > 3.0, "not to the room's spawn marker")
	Game.new_game()


func test_every_hub_autosave_carries_its_marker() -> void:
	var before: Variant = _square("res://scenes/u0/__no_such_square.tscn")
	var loc: Location = await _atrium(CP_FREE, HUB_PARTY, {&"Atrium_Dummy": &"Spared"})
	Saves.delete(0)
	Engine.time_scale = 4.0
	await Story.run(&"atrium_robo")  # rest and save: the day ends
	Engine.time_scale = 1.0
	_expect_slot("Robo's rest", &"ch1_night", &"dais")
	loc.set("midnight_done", true)
	Saves.delete(0)
	var light: int = Flags.light
	await loc.call("_use_hearth", null)
	_expect_slot("the hearth", &"ch1_fair_ready", &"hearth")
	check(Flags.is_state(&"Crono_Confession", &"Told"), "the confession was made")
	# STORY-13: the price lives in data/flags; the dialogue no longer overrides it
	check_eq(Flags.light, light + 10, "Told pays Light +10 from its flag data")
	for o in (Data.dialogue_script(&"ch1_hearth").filter(func(c: Dictionary) -> bool: return c.has("choice"))[0] as Dictionary)["choice"]:
		check(not (o["set"] as Dictionary).has("affinity"), "%s carries no affinity override" % o["set"]["state"])
	check(not Flags.has(&"Ch1_Fair_Left"), "the unbuilt Fair left the hub as it was")
	_slow_story()
	_restore_square(before)
	Game.new_game()


func test_the_kitchen_saves_where_its_beats_happen() -> void:
	Game.new_game()
	Game.location = &"guardia_kitchen"
	Game.checkpoint = &"prologue_breakfast_done"
	Game.set_party([&"crono", &"marle", &"sera"] as Array[StringName])
	_fast_story()
	var k: Location = (load(KITCHEN) as PackedScene).instantiate()
	root.add_child(k)
	_track(k)
	get_tree().current_scene = k
	await get_tree().process_frame
	Saves.delete(0)
	k.call("open_gate")
	_expect_slot("the Fracture Gate", &"prologue_gate_open", &"gate")
	_slow_story()
	Game.new_game()


# ---------------------------------------------------------------- one Marle, one Crono (GAP2-5, STORY-16)

func test_one_marle_and_one_crono_in_the_atrium() -> void:
	var loc: Location = await _atrium(CP_FREE, [&"crono", &"marle", &"sera"] as Array[StringName])
	check_eq(_bodies(loc, &"marle"), 1, "Marle walked in with the party: no second Marle at the hearth")
	loc.free()
	loc = await _atrium(CP_FREE, HUB_PARTY)
	check_eq(_bodies(loc, &"marle"), 1, "with Marle out of the party she stands at the hearth")
	check(loc.npc_actors.has(&"marle"), "as cast")
	loc.free()
	# a debug boot into the loft with Crono in the party (README: --checkpoint with --party)
	loc = await _atrium(&"ch1_loft", [&"crono", &"sera"] as Array[StringName])
	check_eq(Game.active_party, [&"sera"] as Array[StringName], "the loft beats are Sera's alone")
	check_eq(_bodies(loc, &"crono"), 1, "one Crono: the one asleep in the chair")
	check(loc.get_actor(&"crono") == loc.npc_actors.get(&"crono"), "and the walking body is Sera")
	_slow_story()
	Game.new_game()


# ---------------------------------------------------------------- autosaves that do not end the day (GAP2-6)

func test_the_hub_autosaves_without_ending_the_day() -> void:
	var loc: Location = await _atrium(CP_FREE, HUB_PARTY, {&"Atrium_Dummy": &"Spared"})
	Saves.delete(0)
	loc.call("_after_dummy")
	_expect_slot("the dummy's result", CP_FREE, &"dummy_center")
	Saves.delete(0)
	await loc.call("_talk_glenn", null)
	check(Flags.is_state(&"Glenn_Duals", &"Granted"), "Glenn read a Spared record")
	_expect_slot("Glenn's honour check", CP_FREE, &"dummy_center")
	Saves.delete(0)
	var light: int = Flags.light
	await loc.call("_use_seed", null)
	check_eq(SeedOfDoan.waters(), 1, "the Seed was watered")
	check_eq(Flags.light, light + 5, "one water pays Light +5 (Story Bible 9.3)")
	_expect_slot("the Seed's first water", CP_FREE, &"seed")
	check_eq(Game.checkpoint, CP_FREE, "none of them moved the story on")
	_slow_story()
	Game.new_game()


# ---------------------------------------------------------------- save pollution (GAP2-9, STORY-23)

func test_no_save_pollution() -> void:
	Game.new_game()
	Game.location = &"guardia_kitchen"
	Game.checkpoint = &"prologue_cradle_done"
	Game.set_party([&"crono", &"marle", &"sera"] as Array[StringName])
	var k: Location = (load(KITCHEN) as PackedScene).instantiate()
	root.add_child(k)
	_track(k)
	await get_tree().process_frame
	check(not Flags.counters.has(&"__noop"), "a Continue from the Cradle writes no stand-in counter")
	check(not FileAccess.get_file_as_string("res://scripts/locations/guardia_kitchen.gd").contains("__noop"), "and the kitchen has none left")
	var where: StringName = Router.current_location
	Router.current_location = &"title"
	var t0: float = Game.play_time
	for i in 4:
		await get_tree().process_frame
	check_near(Game.play_time, t0, 0.00001, "the play clock stands still on the title")
	Router.current_location = &"atrium"
	for i in 4:
		await get_tree().process_frame
	check(Game.play_time > t0, "and runs in a location")
	Router.current_location = where
	Game.new_game()


# ---------------------------------------------------------------- the Seed of Doan (STORY-14)

func test_the_seed_of_doan_has_one_state() -> void:
	Game.new_game()
	var light: int = Flags.light
	check(SeedOfDoan.can_water() and not SeedOfDoan.grown(), "a fresh Seed takes water")
	for i in SeedOfDoan.WATERS_TO_GROW:
		SeedOfDoan.water()
	check(Flags.is_state(&"Seed_of_Doan", &"Grown"), "the third water grows it: Seed_of_Doan is Grown")
	check_eq(Flags.light, light + 15, "Light +5 per water, the third paid by the flag's own data")
	check_eq(SeedOfDoan.water(), SeedOfDoan.WATERS_TO_GROW, "a grown Seed takes no more water")
	check_eq(Flags.light, light + 15, "and pays nothing more")
	check(Flags.holds("Seed_of_Doan:Grown"), "the spelling the endings and Promise Across Rust read holds")
	var stray: Array[String] = []
	for path in _json_files("res://data"):
		if FileAccess.get_file_as_string(path).contains("Seed_of_Doan_Grown"):
			stray.append(path)
	check(stray.is_empty(), "no data file spells the grown Seed another way (%s)" % str(stray))
	Game.new_game()


func _json_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if f.ends_with(".json"):
			out.append(dir.path_join(f))
	for d in da.get_directories():
		out.append_array(_json_files(dir.path_join(d)))
	return out


# ---------------------------------------------------------------- the Cradle's trigger (STORY-18)

func test_the_cradle_waits_at_the_pantry_behind_the_tutorial_fights() -> void:
	Game.new_game()
	Game.location = &"guardia_kitchen"
	Game.checkpoint = &"prologue_gate_open"
	Game.set_party([&"crono", &"marle", &"sera"] as Array[StringName])
	var k: Location = (load(KITCHEN) as PackedScene).instantiate()
	root.add_child(k)
	_track(k)
	await get_tree().process_frame
	var trig: Area3D = k.get("cradle_trigger")
	var box := (trig.get_child(0) as CollisionShape3D).shape as BoxShape3D
	var aabb := AABB(trig.global_position - box.size * 0.5, box.size).grow(0.35)  # the leader's capsule
	check(aabb.has_point((k.get_marker(&"cradle") as Vector3) + Vector3(0.0, 1.0, 0.0)), "the trigger is the pantry mouth where the Cradle waits")
	var gate: Vector3 = k.get_marker(&"gate")
	for id in [&"kitchen_shardlings", &"kitchen_spoons"]:
		var found: Array = k.zones.filter(func(z: EncounterZone) -> bool: return z.encounter_id == id)
		check_eq(found.size(), 1, "%s is in the hall" % id)
		var z: EncounterZone = found[0]
		var c: Vector3 = z.global_position
		var nearest := Vector3(clampf(c.x, aabb.position.x, aabb.end.x), c.y, clampf(c.z, aabb.position.z, aabb.end.z))
		check(Vector2(c.x - nearest.x, c.z - nearest.z).length() > z.radius * 0.7 + EncounterZone.MIN_CONTACT, "%s can be fought without waking the Cradle" % id)
		var crosses: bool = false
		for i in 41:
			var p: Vector3 = gate.lerp(c, float(i) / 40.0)
			crosses = crosses or aabb.has_point(Vector3(p.x, 1.0, p.z))
		check(not crosses, "the walk from the gate to %s never enters the trigger" % id)
	Game.new_game()


# ---------------------------------------------------------------- the lab's echoes (STORY-24)

func test_the_lab_spawns_every_echo_its_caption_names() -> void:
	var loc: Location = await _atrium(CP_FREE, HUB_PARTY, {&"Atrium_Dummy": &"Spared"})
	var ids: Array[String] = []
	for z in loc.zones:
		ids.append(String(z.encounter_id))
	ids.sort()
	var lab: Array[String] = []
	for k in Data.encounters.keys():
		if String(k).begins_with("atrium_lab_"):
			lab.append(String(k))
	lab.sort()
	check_eq(ids, lab, "every atrium_lab_* encounter has its zone, none ships dead")
	var caption: String = ""
	for c in Data.dialogue_script(&"ch1_dummy_sequence"):
		if (c as Dictionary).has("caption") and String(c["caption"]).begins_with("[Memory echoes"):
			caption = String(c["caption"])
	for word in ["Moss-Mice", "Bekkler Fragment", "Ashen Echo", "Ferro-Drone"]:
		check(caption.contains(word), "the caption names the %s the lab spawns" % word)
	var centre: Vector3 = loc.get_marker(&"dummy_center")
	for z in loc.zones:
		var gap: float = Vector2(z.global_position.x - centre.x, z.global_position.z - centre.z).length() - z.radius * 0.7
		check(gap > EncounterZone.MIN_CONTACT + 0.5, "%s stands clear of where the dummy fight leaves the party" % z.encounter_id)
	_slow_story()
	Game.new_game()


# ---------------------------------------------------------------- a dry Rewind (STORY-17)

func test_a_dry_rewind_in_the_hub_is_free() -> void:
	var loc: Location = await _atrium(CP_FREE, HUB_PARTY)
	Game.set_debt(10.0)
	Engine.time_scale = 4.0
	loc.call("_on_rewind")  # runs to its 2 s hold; the line is up at once
	check_eq(loc.prompt_label.text, "Nothing here to rewind.", "the hub says there is nothing to rewind")
	check_near(Game.sera_debt, 10.0, 0.001, "nothing rewound, nothing charged")
	await get_tree().create_timer(2.2).timeout
	Engine.time_scale = 1.0
	check_near(Game.sera_debt, 10.0, 0.001, "and nothing charged after the hold either")
	_slow_story()
	Game.new_game()


# ---------------------------------------------------------------- cues (STORY-21)

func test_every_location_cue_has_a_sound() -> void:
	var sources: Array[String] = [
		"res://scripts/locations/atrium_horologe.gd", "res://scripts/locations/guardia_kitchen.gd",
		"res://scripts/locations/guardia_courtyard.gd", "res://scripts/locations/atrium_gate_ring.gd",
		"res://scripts/world/location.gd", "res://scripts/world/seed_of_doan.gd",
		"res://data/dialogue/prologue.json", "res://data/dialogue/chapter1.json",
	]
	var re := RegEx.create_from_string("(?:play_sfx\\(|\"sfx\":\\s*)\"([a-z0-9_/]+)\"")
	var seen: int = 0
	for path in sources:
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			seen += 1
			check(Audio._find_sfx(m.get_string(1)) != null, "%s (%s) plays a file under audio/sfx" % [m.get_string(1), path.get_file()])
	check(seen > 20, "the cues were found (%d)" % seen)
