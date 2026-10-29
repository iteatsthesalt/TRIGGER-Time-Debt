## Headless test runner:
##   godot --headless --path . --import
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits 0 when everything passes, 1 otherwise.
extends SceneTree

const DT := CombatTypes.DamageType

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _initialize() -> void:
	# Root isn't inside the tree yet during _initialize; run on the first frame.
	_run.call_deferred()


func _run() -> void:
	var tests: Array[Callable] = [
		test_shield_per_strike_and_break_multiplier,
		test_shield_duplicate_tags_count_once,
		test_boost_allocation_and_lock,
		test_tech_damage_typed_arrays,
		test_aoe_circle_scales_with_boost,
		test_aoe_line_and_cone,
		test_aoe_zero_direction_does_not_crash,
		test_coop_list_excludes_partner_singles,
		test_start_without_camera_does_not_hang,
		test_sync_hold_deadlock_fixed,
		test_doc_walkthrough,
		test_break_recovery_priority_and_restore,
		test_victory_ends_combat,
		test_sample_tech_resources_valid,
		test_shave_cap_and_preview_match,
		test_sandbox_uses_decided_shave_cap,
		test_truce_pier_asset_imports,
		test_camera_rig_follows_and_clamps,
		test_camera_rig_frames_combat,
		test_rejected_commands_change_nothing,
		test_placeholder_sheets_cover_every_frame,
		test_actor_sprite_frames_and_facing,
		test_party_follow_trails_the_leader,
		test_party_follow_pauses_for_combat,
		test_encounter_zone_markers,
		test_coordinator_uses_party_anchors,
		test_enemy_wander_drifts_between_points,
		test_enemy_wander_respects_break_and_gate,
		test_battle_presentation_popups_and_flash,
		test_xp_curve_and_level_growth,
		test_victory_screen_pays_out_and_defeat_returns,
		test_defend_halves_damage_and_recovers_bp,
		test_defend_clears_on_defenders_own_next_turn,
		test_defend_rejected_outside_actors_turn,
		test_haste_and_slow_gauge_multipliers,
	]
	for t in tests:
		_current = t.get_method()
		var before := _passed + _failed
		t.call()
		# A test that crashes (e.g. a class failed to compile) logs a SCRIPT ERROR and
		# returns early; make sure it can never look like a pass.
		check(_passed + _failed > before, "ran no checks; it crashed before its first check (see SCRIPT ERROR above)")
		_cleanup()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- fixtures

func _make_actor(id: StringName, team: CombatTypes.Team, pos: Vector3, opts: Dictionary = {}) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.name = String(id)
	var st := CombatantStats.new()
	st.name = "CombatantStats"
	st.actor_id = id
	st.team = team
	st.max_hp = opts.get("hp", 9999)
	st.max_mp = opts.get("mp", 50)
	st.speed = opts.get("speed", 25.0)
	st.physical_attack = opts.get("patk", 50.0)
	st.elemental_attack = opts.get("eatk", 50.0)
	st.physical_defense = opts.get("pdef", 20.0)
	st.elemental_defense = opts.get("edef", 20.0)
	st.weapon_type = opts.get("weapon", DT.SWORD)
	body.add_child(st)
	if team == CombatTypes.Team.PARTY:
		var bc := BoostComponent.new()
		bc.name = "BoostComponent"
		body.add_child(bc)
	else:
		var sh := ShieldComponent.new()
		sh.name = "ShieldComponent"
		sh.max_shields = opts.get("shields", 2)
		var w: Array[CombatTypes.DamageType] = []
		for x in opts.get("weak", []):
			w.append(x)
		sh.weaknesses = w
		body.add_child(sh)
	var nav := NavigationAgent3D.new()
	nav.name = "NavigationAgent3D"
	body.add_child(nav)
	body.set_script(CombatActor)
	body.position = pos
	root.add_child(body)
	return body


func _tech(id: StringName, tier: int, actors: Array, tags: Array, shape: int, opts: Dictionary = {}) -> TechResource:
	var t := TechResource.new()
	t.tech_id = id
	t.display_name = String(id)
	t.tier = tier
	var ids: Array[StringName] = []
	for a in actors:
		ids.append(a)
	t.required_actor_ids = ids
	var tg: Array[CombatTypes.DamageType] = []
	for x in tags:
		tg.append(x)
	t.damage_tags = tg
	t.shape_type = shape
	t.base_multiplier = opts.get("mult", 1.0)
	t.synergy_multiplier = opts.get("synergy", 1.0)
	t.hit_count = opts.get("hits", 1)
	t.uses_elemental_attack = opts.get("elemental", true)
	t.base_radius_or_width = opts.get("radius", 2.5)
	t.base_length = opts.get("length", 6.0)
	t.mp_cost_per_actor = opts.get("mp", 0)
	return t


func _fire_whirl() -> TechResource:
	return _tech(&"fire_whirl", TechResource.TechTier.DUAL, [&"crono", &"lucca"], [DT.SWORD, DT.FIRE],
		TechResource.SpatialShape.CIRCLE_AROUND_TARGET, {"mult": 1.65, "synergy": 1.25, "hits": 2, "mp": 4})


func _coordinator(techs: Array) -> HybridBattleCoordinator:
	var c := HybridBattleCoordinator.new()
	c.auto_tick = false
	c.rng_seed = 1
	var list: Array[TechResource] = []
	for t in techs:
		list.append(t)
	c.all_known_techs = list
	root.add_child(c)
	return c


func _nodes(arr: Array) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for a in arr:
		out.append(a)
	return out


func _cleanup() -> void:
	for child in root.get_children():
		root.remove_child(child)
		child.free()


func check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		push_error("FAIL [%s] %s" % [_current, msg])
		print("FAIL [%s] %s" % [_current, msg])


# ---------------------------------------------------------------- tests

func test_shield_per_strike_and_break_multiplier() -> void:
	var imp := _make_actor(&"imp", CombatTypes.Team.ENEMY, Vector3.ZERO, {"shields": 2, "weak": [DT.SWORD, DT.FIRE]})
	var sh: ShieldComponent = imp.get_node("ShieldComponent")
	var r1 := sh.evaluate_strike([DT.SWORD, DT.FIRE], 0, null)
	check(r1["shields_shaved"] == 2 and r1["caused_break"], "dual-tag strike shaves 2 and breaks a 2-shield imp")
	check(is_equal_approx(r1["damage_multiplier"], 1.3), "breaking strike deals weakness 1.3x")
	var r2 := sh.evaluate_strike([DT.SWORD, DT.FIRE], 0, null)
	check(is_equal_approx(r2["damage_multiplier"], 2.0), "next strike on broken target deals 2.0x")
	check(sh.is_revealed(DT.FIRE) and sh.is_revealed(DT.SWORD), "both weaknesses revealed")
	sh.recover_from_break()
	check(sh.current_shields == 2 and not sh.is_broken, "recovery restores full shields")


func test_shield_duplicate_tags_count_once() -> void:
	var e := _make_actor(&"e", CombatTypes.Team.ENEMY, Vector3.ZERO, {"shields": 5, "weak": [DT.FIRE]})
	var sh: ShieldComponent = e.get_node("ShieldComponent")
	var r := sh.evaluate_strike([DT.FIRE, DT.FIRE], 0, null)
	check(r["shields_shaved"] == 1, "duplicate FIRE tags shave 1, not 2")
	var r2 := sh.evaluate_strike([DT.ICE], 1, null)
	check(r2["shields_shaved"] == 0, "bonus shave needs a weakness hit")


func test_boost_allocation_and_lock() -> void:
	var a := BoostComponent.new()
	var b := BoostComponent.new()
	a.current_bp = 2
	b.current_bp = 2
	var parts: Array[BoostComponent] = [a, b]
	var plan := BoostComponent.allocate_coop_boost(parts, 2)
	check(plan["allocation"][a] == 1 and plan["allocation"][b] == 1, "2 BP split 1/1 like the walkthrough")
	var plan3 := BoostComponent.allocate_coop_boost(parts, 5)
	check(plan3["effective_boost_level"] == 3, "pooled boost capped at 3")
	a.commit_spend(1)
	a.on_turn_start()
	check(a.current_bp == 1, "no BP gain on the turn after boosting")
	a.on_turn_start()
	check(a.current_bp == 2, "BP gain resumes the following turn")
	a.free()
	b.free()


func test_tech_damage_typed_arrays() -> void:
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3.ZERO, {"eatk": 30.0})
	var lucca := _make_actor(&"lucca", CombatTypes.Team.PARTY, Vector3.ZERO, {"eatk": 60.0})
	var ogre := _make_actor(&"ogre", CombatTypes.Team.ENEMY, Vector3.ZERO, {"edef": 20.0})
	var casters: Array[CombatantStats] = [CombatantStats.of(crono), CombatantStats.of(lucca)]
	var dmg := _fire_whirl().calculate_strike_damage(casters, CombatantStats.of(ogre), 2, 1.3)
	# 0.8*(90-10)=64 → ×1.65×1.25×2.8×1.3 = 480.48
	check(dmg == 480, "Fire Whirl Lv2 weakness strike = 480 (got %d)" % dmg)


func test_aoe_circle_scales_with_boost() -> void:
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3(-4, 0, 0))
	var ogre := _make_actor(&"ogre", CombatTypes.Team.ENEMY, Vector3(3, 0, 0))
	var imp := _make_actor(&"imp", CombatTypes.Team.ENEMY, Vector3(3, 0, 3.3))
	var cands := _nodes([ogre, imp])
	var t := _fire_whirl()
	check(TacticalPositioner3D.get_targets_in_tech_aoe(t, crono, ogre, 0, cands).size() == 1, "unboosted ring misses imp at 3.3m")
	check(TacticalPositioner3D.get_targets_in_tech_aoe(t, crono, ogre, 2, cands).size() == 2, "Lv2 ring (3.75m) catches imp")


func test_aoe_line_and_cone() -> void:
	var caster := _make_actor(&"c", CombatTypes.Team.PARTY, Vector3.ZERO)
	var tgt := _make_actor(&"t", CombatTypes.Team.ENEMY, Vector3(0, 0, -3))
	var behind := _make_actor(&"b", CombatTypes.Team.ENEMY, Vector3(0, 0, -5.5))
	var side := _make_actor(&"s", CombatTypes.Team.ENEMY, Vector3(2, 0, -3))
	var cands := _nodes([tgt, behind, side])
	var line := _tech(&"slash", 0, [&"c"], [DT.SWORD], TechResource.SpatialShape.LINE_PIERCE)
	var hits := TacticalPositioner3D.get_targets_in_tech_aoe(line, caster, tgt, 0, cands)
	check(hits.has(tgt) and hits.has(behind) and not hits.has(side), "line pierces target + one behind, not side")
	hits = TacticalPositioner3D.get_targets_in_tech_aoe(line, caster, tgt, 3, cands)
	check(hits.has(side), "MAX boost widens line to catch side enemy")

	var cone := _tech(&"cleave", 0, [&"c"], [DT.AXE], TechResource.SpatialShape.CLEAVE_CONE, {"length": 5.0})
	var wide := _make_actor(&"w", CombatTypes.Team.ENEMY, Vector3(3, 0, -3))
	var narrow := _make_actor(&"n", CombatTypes.Team.ENEMY, Vector3(1, 0, -3))
	hits = TacticalPositioner3D.get_targets_in_tech_aoe(cone, caster, tgt, 0, _nodes([tgt, wide, narrow]))
	check(hits.has(narrow) and not hits.has(wide), "cone (70°) hits 18° offset, misses 45° offset")


func test_aoe_zero_direction_does_not_crash() -> void:
	var caster := _make_actor(&"c", CombatTypes.Team.PARTY, Vector3.ZERO)
	var on_top := _make_actor(&"t", CombatTypes.Team.ENEMY, Vector3(0, 1, 0))
	var line := _tech(&"slash", 0, [&"c"], [DT.SWORD], TechResource.SpatialShape.LINE_PIERCE)
	var hits := TacticalPositioner3D.get_targets_in_tech_aoe(line, caster, on_top, 0, _nodes([on_top]))
	check(hits.size() == 1, "target directly above caster still resolves")


func test_coop_list_excludes_partner_singles() -> void:
	var cyclone := _tech(&"cyclone", 0, [&"crono"], [DT.SWORD], TechResource.SpatialShape.CIRCLE_AROUND_TARGET)
	var flame := _tech(&"flame_toss", 0, [&"lucca"], [DT.FIRE], TechResource.SpatialShape.LINE_PIERCE)
	var fw := _fire_whirl()
	var c := _coordinator([cyclone, flame, fw])
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3(-4, 0, 0))
	var lucca := _make_actor(&"lucca", CombatTypes.Team.PARTY, Vector3(-4, 0, 2))
	c.ready_pool = _nodes([crono, lucca])
	var list := c.get_available_techs(crono)
	check(list.has(cyclone) and list.has(fw) and not list.has(flame), "Crono sees Cyclone + Fire Whirl, not Lucca's Flame Toss")


func test_start_without_camera_does_not_hang() -> void:
	var c := _coordinator([])
	var a := _make_actor(&"a", CombatTypes.Team.PARTY, Vector3.ZERO)
	var e := _make_actor(&"e", CombatTypes.Team.ENEMY, Vector3(3, 0, 0))
	c.start_encounter(_nodes([a]), _nodes([e]), Vector3.ZERO)
	check(c.state == CombatTypes.BattleState.TIMELINE_TICK, "encounter reaches TIMELINE_TICK with no camera")


func test_sync_hold_deadlock_fixed() -> void:
	var c := _coordinator([_fire_whirl()])
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3(-4, 0, 0))
	var lucca := _make_actor(&"lucca", CombatTypes.Team.PARTY, Vector3(-4, 0, 2))
	var ogre := _make_actor(&"ogre", CombatTypes.Team.ENEMY, Vector3(3, 0, 0), {"shields": 6})
	c.start_encounter(_nodes([crono, lucca]), _nodes([ogre]), Vector3.ZERO)
	for u in [crono, lucca, ogre]:
		c.set_gauge(u, 0.0)
	c.set_gauge(crono, 100.0)
	c.advance_timeline(0.0)
	check(c.active_actor == crono, "Crono prompted")
	c.command_sync_hold(crono)
	c.set_gauge(lucca, 100.0)
	c.advance_timeline(0.0)
	check(c.active_actor == lucca, "Lucca prompted while Crono holds")
	var r := c.execute_basic_attack(lucca, ogre, 0)
	check(r["ok"], "Lucca acts solo")
	check(c.active_actor == crono and c.state == CombatTypes.BattleState.COMMAND_WAIT, "held Crono is re-prompted (no deadlock)")
	check(crono.get_node("BoostComponent").current_bp == 2, "re-prompt does not grant extra BP")


func test_doc_walkthrough() -> void:
	var c := _coordinator([_fire_whirl()])
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3(-4, 0, 0), {"eatk": 30.0, "patk": 60.0})
	var lucca := _make_actor(&"lucca", CombatTypes.Team.PARTY, Vector3(-4, 0, 2), {"eatk": 60.0, "weapon": DT.BOW})
	var frog := _make_actor(&"frog", CombatTypes.Team.PARTY, Vector3(-4, 0, -2), {"patk": 55.0})
	var ogre := _make_actor(&"ogre", CombatTypes.Team.ENEMY, Vector3(3, 0, 0), {"shields": 6, "weak": [DT.SWORD, DT.FIRE, DT.ICE]})
	var imp1 := _make_actor(&"imp1", CombatTypes.Team.ENEMY, Vector3(3, 0, 3.3), {"shields": 2, "weak": [DT.SWORD, DT.FIRE]})
	var imp2 := _make_actor(&"imp2", CombatTypes.Team.ENEMY, Vector3(3, 0, -3.3), {"shields": 2, "weak": [DT.SWORD, DT.FIRE]})
	c.start_encounter(_nodes([crono, lucca, frog]), _nodes([ogre, imp1, imp2]), Vector3.ZERO)
	for u in [crono, lucca, frog, ogre, imp1, imp2]:
		c.set_gauge(u, 0.0)

	# Turn 1 — Crono reaches the gate (1 + 1 = 2 BP) and holds.
	c.set_gauge(crono, 100.0)
	c.advance_timeline(0.0)
	check(crono.get_node("BoostComponent").current_bp == 2, "Crono at gate with 2 BP")
	c.command_sync_hold(crono)

	# Turn 2 — Lucca arrives, Fire Whirl at Lv2 (1 BP each).
	c.set_gauge(lucca, 100.0)
	c.advance_timeline(0.0)
	var r := c.execute_tech(c.all_known_techs[0], lucca, ogre, 2)
	check(r["ok"], "Fire Whirl executes")
	check(r["targets"].size() == 3, "Lv2 ring catches Ogre + both Imps")
	var ogre_sh: ShieldComponent = ogre.get_node("ShieldComponent")
	check(ogre_sh.current_shields == 2, "Ogre 6 → 2 shields (got %d)" % ogre_sh.current_shields)
	check(imp1.get_node("ShieldComponent").is_broken and imp2.get_node("ShieldComponent").is_broken, "both Imps broken")
	check(imp1.frozen and c.get_gauge(imp1) < 0.0, "broken Imp frozen and pushed back on timeline")
	check(crono.get_node("BoostComponent").current_bp == 1 and lucca.get_node("BoostComponent").current_bp == 1, "BP drawn 1/1")
	check(r["damage"][imp1] == 480 + 739, "Imp takes 1.3x then 2.0x strike (got %d)" % r["damage"][imp1])
	check(CombatantStats.of(crono).mp == 46 and CombatantStats.of(lucca).mp == 46, "MP spent by both casters")

	# Turn 3 — Frog (2 BP, doc said 3 — see audit) spends 1 BP for 2 sword strikes.
	c.set_gauge(frog, 100.0)
	c.advance_timeline(0.0)
	check(frog.get_node("BoostComponent").current_bp == 2, "Frog arrives with 2 BP")
	var r2 := c.execute_basic_attack(frog, ogre, 1)
	check(r2["ok"] and ogre_sh.is_broken, "Frog's boosted attack breaks the Ogre")


func test_break_recovery_priority_and_restore() -> void:
	var c := _coordinator([])
	var ally := _make_actor(&"a", CombatTypes.Team.PARTY, Vector3.ZERO, {"speed": 0.0})
	var ogre := _make_actor(&"ogre", CombatTypes.Team.ENEMY, Vector3(3, 0, 0), {"shields": 1, "weak": [DT.SWORD]})
	c.start_encounter(_nodes([ally]), _nodes([ogre]), Vector3.ZERO)
	var recovered: Array = []
	c.enemy_recovered.connect(func(e): recovered.append(e))
	var sh: ShieldComponent = ogre.get_node("ShieldComponent")
	sh.evaluate_strike([DT.SWORD], 0, ally)
	check(sh.is_broken and is_equal_approx(c.get_gauge(ogre), -100.0), "break pushes gauge to -100")
	c.set_gauge(ally, 150.0)
	c.set_gauge(ogre, 100.0)
	c.advance_timeline(0.0)
	check(recovered.has(ogre), "recovering broken enemy acts before an ally further along")
	check(not sh.is_broken and sh.current_shields == 1, "shields restored on recovery")
	check(not ogre.frozen, "enemy unfrozen on recovery")


func test_victory_ends_combat() -> void:
	var c := _coordinator([])
	var ally := _make_actor(&"a", CombatTypes.Team.PARTY, Vector3.ZERO, {"patk": 500.0})
	var weak := _make_actor(&"w", CombatTypes.Team.ENEMY, Vector3(2, 0, 0), {"hp": 10})
	var ended: Array = []
	var locks: Array = []
	c.combat_ended.connect(func(v): ended.append(v))
	c.exploration_lock_changed.connect(func(l): locks.append(l))
	c.start_encounter(_nodes([ally]), _nodes([weak]), Vector3.ZERO)
	c.set_gauge(ally, 100.0)
	c.set_gauge(weak, 0.0)
	c.advance_timeline(0.0)
	c.execute_basic_attack(ally, weak, 0)
	check(ended == [true], "combat_ended(true) emitted")
	check(locks == [true, false], "exploration locked then unlocked")
	check(c.state == CombatTypes.BattleState.EXPLORATION, "back to exploration")


func test_sample_tech_resources_valid() -> void:
	var dir := DirAccess.open("res://data/techs")
	check(dir != null, "data/techs exists")
	if dir == null:
		return
	var count := 0
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var t := load("res://data/techs/" + f) as TechResource
		check(t != null, "%s loads as TechResource" % f)
		if t:
			count += 1
			var errs := t.get_validation_errors()
			check(errs.is_empty(), "%s valid: %s" % [f, ", ".join(errs)])
	check(count >= 3, "at least 3 sample techs")


func test_shave_cap_and_preview_match() -> void:
	# Uncapped: MAX-boost Fire Whirl vs SWORD+FIRE boss strips (2+1) + 2 = 5 (the source-review "double dip").
	var boss := _make_actor(&"boss", CombatTypes.Team.ENEMY, Vector3.ZERO, {"shields": 8, "weak": [DT.SWORD, DT.FIRE]})
	var sh: ShieldComponent = boss.get_node("ShieldComponent")
	var pv := sh.preview_action([DT.SWORD, DT.FIRE], 2, 1)
	sh.evaluate_strike([DT.SWORD, DT.FIRE], 1, null)
	sh.evaluate_strike([DT.SWORD, DT.FIRE], 0, null)
	check(pv["shave"] == 5 and sh.current_shields == 3, "uncapped MAX Fire Whirl strips 5; preview agrees")

	# Capped through the coordinator at 3 per action.
	var c := _coordinator([_fire_whirl()])
	c.max_shield_shave_per_action = 3
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3(-3, 0, 0))
	var lucca := _make_actor(&"lucca", CombatTypes.Team.PARTY, Vector3(-3, 0, 1))
	var b2 := _make_actor(&"b2", CombatTypes.Team.ENEMY, Vector3(2, 0, 0), {"shields": 8, "weak": [DT.SWORD, DT.FIRE]})
	c.start_encounter(_nodes([crono, lucca]), _nodes([b2]), Vector3.ZERO)
	for u in [crono, lucca, b2]:
		c.set_gauge(u, 0.0)
	crono.get_node("BoostComponent").current_bp = 3
	c.set_gauge(crono, 100.0)
	c.advance_timeline(0.0)
	c.command_sync_hold(crono)
	c.set_gauge(lucca, 100.0)
	c.advance_timeline(0.0)
	var sh2: ShieldComponent = b2.get_node("ShieldComponent")
	var pv2 := sh2.preview_action([DT.SWORD, DT.FIRE], 2, 1, 3)
	var r := c.execute_tech(c.all_known_techs[0], lucca, b2, 3)
	check(r["ok"] and r["boost_level"] == 3, "MAX boost Fire Whirl executes")
	check(sh2.current_shields == 5 and pv2["shave"] == 3, "cap 3 leaves 5/8; preview agrees (got %d)" % sh2.current_shields)


func test_sandbox_uses_decided_shave_cap() -> void:
	# DECISIONS.md fixes the cap at 3; the generated sandbox must ship with it.
	var scene := load("res://scenes/combat_sandbox.tscn") as PackedScene
	check(scene != null, "sandbox scene loads")
	if scene == null:
		return
	var root := scene.instantiate()
	var coord := root.find_child("HybridBattleCoordinator", true, false) as HybridBattleCoordinator
	check(coord != null and coord.max_shield_shave_per_action == 3, "sandbox coordinator caps shave at 3")
	root.free()


func test_truce_pier_asset_imports() -> void:
	# Built by tools/blender/build_truce_pier.py; "-col" objects become static bodies on import.
	var scene := load("res://assets/models/truce_pier.glb") as PackedScene
	check(scene != null, "truce_pier.glb imports as a scene")
	if scene == null:
		return
	var root := scene.instantiate()
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	var bodies := root.find_children("*", "StaticBody3D", true, false)
	check(meshes.size() >= 8, "pier has its meshes (got %d)" % meshes.size())
	check(bodies.size() >= 4, "deck, shore and boathouse are walkable (got %d bodies)" % bodies.size())
	var deck := root.find_child("PierDeck*", true, false) as MeshInstance3D
	check(deck != null and deck.get_aabb().size.z > 10.0, "pier deck runs out over the water")
	root.free()


func _camera_rig(target: Node3D, coord: HybridBattleCoordinator = null) -> HD2DCameraRig:
	var rig := HD2DCameraRig.new()
	rig.auto_follow = false
	rig.target = target
	rig.coordinator = coord
	var cam := Camera3D.new()
	cam.attributes = CameraAttributesPractical.new()
	rig.add_child(cam)
	root.add_child(rig)
	return rig


func test_camera_rig_follows_and_clamps() -> void:
	var leader := Node3D.new()
	root.add_child(leader)
	var rig := _camera_rig(leader)
	check(rig.camera != null and rig.focus.is_equal_approx(Vector3.ZERO), "rig snaps to the leader on ready")
	var want: Vector3 = rig.camera_offset()
	check(rig.camera.global_position.is_equal_approx(want), "camera sits up and back at the set pitch")
	check(is_equal_approx(rig.camera.global_rotation_degrees.x, -rig.pitch_degrees), "camera tilts down by pitch")

	# Smooth, frame-rate independent follow: one 1 s step == sixty 1/60 s steps.
	leader.global_position = Vector3(4, 0, 0)
	rig.step(1.0 / 60.0)
	check(rig.focus.x > 0.0 and rig.focus.x < 4.0, "follow eases toward the leader, not a jump")
	var rig2 := _camera_rig(leader)
	rig2.focus = Vector3.ZERO
	rig.focus = Vector3.ZERO
	rig.step(1.0)
	for i in 60:
		rig2.step(1.0 / 60.0)
	check(absf(rig.focus.x - rig2.focus.x) < 0.01, "follow is frame-rate independent (%.3f vs %.3f)" % [rig.focus.x, rig2.focus.x])

	# Map bounds hold the focus at the edge.
	rig.map_bounds = Rect2(-5, -5, 10, 10)
	leader.global_position = Vector3(30, 0, -30)
	rig.snap()
	check(rig.focus.is_equal_approx(Vector3(5, 0, -5)), "focus clamps to map bounds")

	# DOF band brackets the focus distance.
	var attrs := rig.camera.attributes as CameraAttributesPractical
	check(attrs.dof_blur_near_enabled and attrs.dof_blur_far_enabled, "near and far blur enabled")
	check(attrs.dof_blur_near_distance < rig.distance and attrs.dof_blur_far_distance > rig.distance,
			"focus distance sits inside the sharp band")


func test_camera_rig_frames_combat() -> void:
	var c := _coordinator([_fire_whirl()])
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3(-6, 0, 0))
	var imp := _make_actor(&"imp", CombatTypes.Team.ENEMY, Vector3(6, 0, 0))
	var rig := _camera_rig(crono, c)
	var arena := Vector3(1, 0, 2)
	c.start_encounter(_nodes([crono]), _nodes([imp]), arena)
	check(rig.desired_focus().is_equal_approx(arena), "rig frames the arena once combat starts")
	c.combat_ended.emit(true)
	check(rig.desired_focus().is_equal_approx(crono.global_position), "rig returns to the leader after combat")

	var scene := load("res://scenes/combat_sandbox.tscn") as PackedScene
	var sb := scene.instantiate()
	var srig := sb.find_child("HD2DCameraRig", true, false) as HD2DCameraRig
	check(srig != null and srig.target != null and srig.coordinator != null, "sandbox rig has a target and coordinator")
	sb.free()


func test_rejected_commands_change_nothing() -> void:
	var c := _coordinator([_fire_whirl()])
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3(-3, 0, 0), {"mp": 2})
	var lucca := _make_actor(&"lucca", CombatTypes.Team.PARTY, Vector3(-3, 0, 1))
	var e := _make_actor(&"e", CombatTypes.Team.ENEMY, Vector3(2, 0, 0))
	c.start_encounter(_nodes([crono, lucca]), _nodes([e]), Vector3.ZERO)
	for u in [crono, lucca, e]:
		c.set_gauge(u, 0.0)
	c.set_gauge(crono, 100.0)
	c.advance_timeline(0.0)
	var r1 := c.execute_tech(c.all_known_techs[0], crono, e, 0)
	check(not r1["ok"], "Dual Tech refused while partner not ready")
	c.command_sync_hold(crono)
	c.set_gauge(lucca, 100.0)
	c.advance_timeline(0.0)
	var bp_before: int = lucca.get_node("BoostComponent").current_bp
	var r2 := c.execute_tech(c.all_known_techs[0], lucca, e, 2)
	check(not r2["ok"] and r2["error"].contains("MP"), "refused: Crono lacks MP")
	var unchanged: bool = lucca.get_node("BoostComponent").current_bp == bp_before and CombatantStats.of(lucca).mp == 50
	check(unchanged, "no BP/MP spent on refusal")
	check(c.state == CombatTypes.BattleState.COMMAND_WAIT and c.active_actor == lucca, "still Lucca's turn")
	var r3 := c.execute_basic_attack(lucca, e, 9)
	check(not r3["ok"], "boost above BP refused")


func test_placeholder_sheets_cover_every_frame() -> void:
	# Built by tools/sprites/make_placeholders.gd; every frame cell must hold a drawing.
	var cast: Array = load("res://tools/sprites/make_placeholders.gd").get_script_constant_map()["CAST"]
	var fs := ActorSprite.FRAME_SIZE
	for d in cast:
		var path := "res://assets/sprites/placeholders/%s.png" % d[0]
		var tex := load(path) as Texture2D
		check(tex != null, "%s imports" % path)
		if tex == null:
			continue
		var img := tex.get_image()
		check(img.get_size() == Vector2i(fs.x * ActorSprite.SHEET_COLUMNS, fs.y * 4), "%s is 9x4 frames" % d[0])
		var empty := 0
		for row in 4:
			for col in ActorSprite.SHEET_COLUMNS:
				if not img.get_region(Rect2i(col * fs.x, row * fs.y, fs.x, fs.y)).get_used_rect().has_area():
					empty += 1
		check(empty == 0, "%s has no empty frames (%d empty)" % [d[0], empty])
		var walk0 := img.get_region(Rect2i(2 * fs.x, 0, fs.x, fs.y)).get_data()
		var walk1 := img.get_region(Rect2i(3 * fs.x, 0, fs.x, fs.y)).get_data()
		check(walk0 != walk1, "%s walk frames differ" % d[0])


func test_actor_sprite_frames_and_facing() -> void:
	var spr := ActorSprite.new()
	spr.sheet = load("res://assets/sprites/placeholders/crono.png")
	root.add_child(spr)
	var frames := spr.sprite_frames
	check(frames != null and frames.get_animation_names().size() == 12, "3 actions x 4 directions")
	check(frames.get_frame_count(&"walk_left") == 4 and frames.get_frame_count(&"attack_up") == 3, "frame counts per action")
	check(not frames.get_animation_loop(&"attack_down") and frames.get_animation_loop(&"walk_down"), "attack plays once")
	check(spr.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "nearest filtering")
	check(spr.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Y billboard")
	check(spr.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "alpha scissor")
	spr.update_from_velocity(Vector3(-3, 0, 0.5))
	check(spr.animation == &"walk_left", "walking left (got %s)" % spr.animation)
	spr.update_from_velocity(Vector3(0, 0, -2))
	check(spr.animation == &"walk_up", "walking away from camera = up")
	spr.update_from_velocity(Vector3.ZERO)
	check(spr.animation == &"idle_up", "stopping keeps the facing")
	spr.play_attack()
	spr.update_from_velocity(Vector3(1, 0, 0))
	check(spr.animation == &"attack_up", "attack is not cut off by movement")

	var scene := load("res://scenes/combat_sandbox.tscn") as PackedScene
	var sb := scene.instantiate()
	var ids := ["crono", "lucca", "frog", "ogre", "imp_a", "imp_b"]
	var with_sprites := 0
	for id in ids:
		var s := sb.find_child(id, true, false).get_node_or_null("ActorSprite") as ActorSprite
		if s and s.sprite_frames:
			with_sprites += 1
	check(with_sprites == ids.size(), "every sandbox actor has a sprite (%d/%d)" % [with_sprites, ids.size()])
	sb.free()


func _party_follow(coord: HybridBattleCoordinator = null) -> Dictionary:
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3(0, 0, 0))
	var lucca := _make_actor(&"lucca", CombatTypes.Team.PARTY, Vector3(-1, 0, 0))
	var frog := _make_actor(&"frog", CombatTypes.Team.PARTY, Vector3(-2, 0, 0))
	crono.add_to_group(&"party_leader")
	var pf := PartyFollow.new()
	pf.auto_follow = false
	pf.coordinator = coord
	root.add_child(pf)
	pf.reform()
	return {"pf": pf, "crono": crono, "lucca": lucca, "frog": frog}


func test_party_follow_trails_the_leader() -> void:
	var t := _party_follow()
	var pf: PartyFollow = t["pf"]
	check(pf.followers() == _nodes([t["lucca"], t["frog"]]), "followers are the non-leader members, in order")

	# Leader walks east 4 m, then turns north 4 m: followers aim at points on that path, not straight at him.
	for i in 21:
		t["crono"].global_position = Vector3(i * 0.2, 0, 0)
		pf.step()
	for i in range(1, 21):
		t["crono"].global_position = Vector3(4, 0, -i * 0.2)
		pf.step()
	var first := pf.point_behind(pf.spacing)
	var second := pf.point_behind(2.0 * pf.spacing)
	check(first.is_equal_approx(Vector3(4, 0, -4 + pf.spacing)), "first follower spot is 1 spacing back along the path (got %s)" % first)
	check(second.is_equal_approx(Vector3(4, 0, -4 + 2.0 * pf.spacing)), "second follower is 2 spacings back (got %s)" % second)
	check(t["lucca"].get("_target").is_equal_approx(first), "lucca was ordered to her trail spot")
	check(pf.trail.size() <= int(ceil(3.0 * pf.spacing / pf.sample_step)) + 2, "trail is trimmed (%d points)" % pf.trail.size())

	# Around the corner: 5 m back along the path is on the eastbound leg, not a diagonal shortcut.
	pf.spacing = 5.0
	check(pf.point_behind(5.0).is_equal_approx(Vector3(3, 0, 0)), "trail point follows the corner, not the diagonal")


func test_party_follow_pauses_for_combat() -> void:
	var c := _coordinator([_fire_whirl()])
	var t := _party_follow(c)
	var pf: PartyFollow = t["pf"]
	var imp := _make_actor(&"imp", CombatTypes.Team.ENEMY, Vector3(6, 0, 0))
	c.start_encounter(_nodes([t["crono"], t["lucca"], t["frog"]]), _nodes([imp]), Vector3(3, 0, 0))
	check(pf.locked, "follow pauses when combat locks exploration")
	var anchor: Vector3 = t["lucca"].get("_target")
	t["crono"].global_position = Vector3(10, 0, 10)
	pf.step()
	check(t["lucca"].get("_target") == anchor, "battle anchor orders are not overridden mid-combat")

	t["lucca"].global_position = Vector3(1, 0, 1)
	t["frog"].global_position = Vector3(1, 0, -1)
	c.exploration_lock_changed.emit(false)
	check(not pf.locked, "follow resumes after combat")
	check(pf.trail.size() == 3 and pf.trail[1] == Vector3(1, 0, 1), "trail re-forms from where everyone stands")

	var sb := (load("res://scenes/combat_sandbox.tscn") as PackedScene).instantiate()
	var spf := sb.find_child("PartyFollow", true, false) as PartyFollow
	check(spf != null and spf.coordinator != null, "sandbox party has a follow node wired to the coordinator")
	sb.free()


func test_encounter_zone_markers() -> void:
	var zone := EncounterZone.new()
	zone.position = Vector3(10, 0, 0)
	var group := Node3D.new()
	group.name = "EnemyGroup"
	zone.add_child(group)
	root.add_child(zone)
	check(zone.camera_point() == Vector3(10, 0, 0) and zone.party_points().is_empty(), "no markers: zone centre, no anchors")

	var cam := Marker3D.new()
	cam.name = "CameraPoint"
	cam.position = Vector3(-1, 0, 0)
	zone.add_child(cam)
	var holder := Node3D.new()
	holder.name = "PartyAnchors"
	zone.add_child(holder)
	for p in [Vector3(-3, 0, 0), Vector3(-4, 0, 2), Vector3(-4, 0, -2)]:
		var m := Marker3D.new()
		m.position = p
		holder.add_child(m)
	check(zone.camera_point() == Vector3(9, 0, 0), "camera point is the marker, in world space")
	var pts := zone.party_points()
	check(pts.size() == 3 and pts[0] == Vector3(7, 0, 0) and pts[2] == Vector3(6, 0, -2), "party anchors in order, world space")

	# Leader goes first even when it isn't first in the scene.
	var lucca := _make_actor(&"lucca", CombatTypes.Team.PARTY, Vector3.ZERO)
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3.ZERO)
	crono.add_to_group(&"party_leader")
	check(zone._party() == _nodes([crono, lucca]), "leader takes anchor 0")

	var sb := (load("res://scenes/combat_sandbox.tscn") as PackedScene).instantiate()
	var sz := sb.find_child("EncounterZone_01", true, false)
	check(sz.get_node_or_null("CameraPoint") != null and sz.get_node("PartyAnchors").get_child_count() == 3
			and sz.get_node("WanderNodes").get_child_count() >= 3, "sandbox zone has camera, 3 party anchors and wander nodes")
	sb.free()


func test_coordinator_uses_party_anchors() -> void:
	var c := _coordinator([_fire_whirl()])
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3(-9, 0, 0))
	var lucca := _make_actor(&"lucca", CombatTypes.Team.PARTY, Vector3(-9, 0, 1))
	var frog := _make_actor(&"frog", CombatTypes.Team.PARTY, Vector3(-9, 0, -1))
	var imp := _make_actor(&"imp", CombatTypes.Team.ENEMY, Vector3(3, 0, 0))
	var anchors: Array[Vector3] = [Vector3(-2, 0, 0), Vector3(-3, 0, 2)]
	var wander: Array[Vector3] = [Vector3(3, 0, 1), Vector3(3, 0, -1)]
	c.start_encounter(_nodes([crono, lucca, frog]), _nodes([imp]), Vector3.ZERO, anchors, wander)
	check(crono.get("_target") == anchors[0] and lucca.get("_target") == anchors[1], "members go to their anchors")
	var fallback: Vector3 = frog.get("_target")
	check(fallback.distance_to(Vector3.ZERO) > c.party_anchor_radius - 0.01 and fallback.x < 0.0,
			"a member without an anchor falls back to the near-side fan (got %s)" % fallback)
	check(c.arena_wander_points == wander, "wander points are kept for the battle")


func _wander_battle() -> Dictionary:
	var c := _coordinator([_fire_whirl()])
	var w := EnemyWander.new()
	w.coordinator = c
	root.add_child(w)
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3(-4, 0, 0))
	# Both start nearest point 0, so they have to share out the points.
	var a := _make_actor(&"imp_a", CombatTypes.Team.ENEMY, Vector3(0, 0, -0.5), {"shields": 2, "weak": [DT.SWORD]})
	var b := _make_actor(&"imp_b", CombatTypes.Team.ENEMY, Vector3(0, 0, 0.5), {"shields": 2, "weak": [DT.SWORD]})
	var points: Array[Vector3] = [Vector3(2, 0, 0), Vector3(4, 0, 0), Vector3(2, 0, 3)]
	c.start_encounter(_nodes([crono]), _nodes([a, b]), Vector3.ZERO, [], points)
	return {"c": c, "w": w, "crono": crono, "a": a, "b": b, "points": points}


func test_enemy_wander_drifts_between_points() -> void:
	var t := _wander_battle()
	var w: EnemyWander = t["w"]
	var a: Node3D = t["a"]
	var b: Node3D = t["b"]
	var start_b := b.global_position
	w.drift(a, 0.5)
	w.drift(b, 0.5)
	check(w.claims[a] == 0 and w.claims[b] == 2, "second enemy takes the nearest free point (%s, %s)" % [w.claims[a], w.claims[b]])
	check(is_equal_approx(b.global_position.distance_to(start_b), w.drift_speed * 0.5), "drift moves at drift_speed")
	var p2: Vector3 = t["points"][2]
	check(b.global_position.distance_to(p2) < start_b.distance_to(p2), "drift heads toward the claimed point")

	# a walks to point 0, then moves on to the only point still free (1), never b's, and keeps circling.
	var visited: Array[int] = []
	for i in 400:
		var before: int = w.claims[a]
		w.drift(a, 0.05)
		if w.claims[a] != before:
			visited.append(w.claims[a])
	check(visited.size() >= 2 and visited[0] == 1 and visited[1] == 0, "enemy circles the free points 0 -> 1 -> 0 (got %s)" % [visited])
	check(not visited.has(2), "it never takes the point another enemy holds")
	check(is_equal_approx(a.global_position.y, 0.0), "drift stays on the ground")


func test_enemy_wander_respects_break_and_gate() -> void:
	var t := _wander_battle()
	var c: HybridBattleCoordinator = t["c"]
	var a: Node3D = t["a"]
	var b: Node3D = t["b"]
	for u in [t["crono"], a, b]:
		c.set_gauge(u, 0.0)
	var pa := a.global_position
	c.advance_timeline(0.2)
	check(a.global_position != pa, "timeline tick drifts enemies")

	# Broken enemies don't drift.
	a.get_node("ShieldComponent").evaluate_strike([DT.SWORD], 0, t["crono"])
	a.get_node("ShieldComponent").evaluate_strike([DT.SWORD], 0, t["crono"])
	var frozen_at := a.global_position
	c.advance_timeline(0.2)
	check(a.global_position == frozen_at, "a broken enemy stays put")

	# Someone at the Action Gate pauses all drift.
	c.set_gauge(t["crono"], 100.0)
	c.advance_timeline(0.0)
	var held_b := b.global_position
	c.advance_timeline(0.2)
	check(b.global_position == held_b, "drift pauses while the party chooses")

	var sb := (load("res://scenes/combat_sandbox.tscn") as PackedScene).instantiate()
	var sw := sb.find_child("EnemyWander", true, false) as EnemyWander
	check(sw != null and sw.coordinator != null, "sandbox has enemy wander wired to the coordinator")
	sb.free()


func test_battle_presentation_popups_and_flash() -> void:
	var c := _coordinator([_fire_whirl()])
	var bp := BattlePresentation.new()
	bp.coordinator = c
	root.add_child(bp)
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3(-3, 0, 0))
	var imp := _make_actor(&"imp", CombatTypes.Team.ENEMY, Vector3(2, 0, 1))
	for a in [crono, imp]:
		var spr := ActorSprite.new()
		spr.sheet = load("res://assets/sprites/placeholders/imp.png")
		a.add_child(spr)
		a.sprite = spr

	c.strike_resolved.emit(crono, imp, 120, {"hit_weakness": true, "shields_shaved": 2, "damage_multiplier": 1.0})
	var texts := bp.popups().map(func(l): return l.text)
	check(texts.has("120") and texts.has("-2 SHIELD"), "damage number and shield crack pop up (got %s)" % [texts])
	var dmg: Label3D = bp.popups()[0]
	check(dmg.global_position.distance_to(imp.global_position + Vector3(0, bp.popup_height, 0)) < 0.01, "popup starts above the target")
	check(dmg.modulate.is_equal_approx(BattlePresentation.COLOR_WEAK), "weakness hits use the weakness colour")
	check(crono.sprite.action == &"attack", "attacker plays its swing")

	c.strike_resolved.emit(crono, imp, 30, {"hit_weakness": false, "shields_shaved": 0})
	check(bp.popups().size() == 3, "a plain hit adds only its number")

	c.enemy_broken.emit(imp, crono)
	check(bp.popups().map(func(l): return l.text).has("BREAK!"), "BREAK! pops up")
	check(imp.sprite.modulate.r > 1.5, "broken enemy flashes bright")
	check(c.state == CombatTypes.BattleState.EXPLORATION, "presentation never changes combat state")

	var sb := (load("res://scenes/combat_sandbox.tscn") as PackedScene).instantiate()
	var sbp := sb.find_child("BattlePresentation", true, false) as BattlePresentation
	check(sbp != null and sbp.coordinator != null, "sandbox has battle presentation wired to the coordinator")
	sb.free()


func test_xp_curve_and_level_growth() -> void:
	check(CombatantStats.xp_to_next(1) == 20 and CombatantStats.xp_to_next(2) == 60 and CombatantStats.xp_to_next(3) == 120,
			"XP curve 20 / 60 / 120")
	var st := CombatantStats.new()
	st.max_hp = 100
	root.add_child(st)
	check(st.gain_xp(19) == 0 and st.level == 1 and st.xp == 19, "19 XP is not a level")
	check(st.gain_xp(1) == 1 and st.level == 2 and st.xp == 0, "20 XP reaches Lv 2 with nothing left over")
	check(st.max_hp == 108 and st.hp == 108 and st.physical_attack == 42.0, "level-up grows HP 8% and attack +2, topping HP up")
	check(st.gain_xp(60 + 120 + 5) == 2 and st.level == 4 and st.xp == 5, "one big payout can give several levels")
	check(st.gain_xp(-50) == 0 and st.xp == 5, "negative XP is ignored")


func test_victory_screen_pays_out_and_defeat_returns() -> void:
	var c := _coordinator([_fire_whirl()])
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3(-3, 0, 0))
	var lucca := _make_actor(&"lucca", CombatTypes.Team.PARTY, Vector3(-3, 0, 1))
	var frog := _make_actor(&"frog", CombatTypes.Team.PARTY, Vector3(-3, 0, -1))
	var ogre := _make_actor(&"ogre", CombatTypes.Team.ENEMY, Vector3(2, 0, 0))
	var imp := _make_actor(&"imp", CombatTypes.Team.ENEMY, Vector3(2, 0, 2))
	CombatantStats.of(ogre).xp_reward = 30
	CombatantStats.of(ogre).gold_reward = 60
	CombatantStats.of(imp).xp_reward = 8
	CombatantStats.of(imp).gold_reward = 15
	var vs := VictoryScreen.new()
	vs.coordinator = c
	vs.handle_defeat = false
	root.add_child(vs)
	var got: Array = []
	vs.rewards_granted.connect(func(r): got.append(r))

	c.start_encounter(_nodes([crono, lucca, frog]), _nodes([ogre, imp]), Vector3.ZERO)
	CombatantStats.of(frog).apply_damage(99999)
	for e in [ogre, imp]:
		CombatantStats.of(e).apply_damage(99999)
	c.combat_ended.emit(true)
	var r := vs.last_rewards
	check(vs.visible and got.size() == 1 and r == got[0], "victory shows the panel and reports the rewards")
	check(r.xp == 38 and r.gold == 75, "XP and gold total the defeated enemies (got %d XP %d G)" % [r.xp, r.gold])
	check(CombatantStats.of(crono).level == 2 and CombatantStats.of(crono).xp == 18, "each standing member gets the full 38 XP")
	check(r.level_ups.get(&"lucca", 0) == 1 and not r.new_levels.has(&"frog"), "a downed member gets no XP")
	check(vs.lines.has("38 XP   75 G") and "
".join(vs.lines).contains("Crono reached Lv 2!"), "panel lists the payout and level-ups")
	vs.close()
	check(not vs.visible, "confirming closes the panel")

	vs.title_scene = "res://scenes/does_not_exist.tscn"
	check(vs.defeat_destination() == "", "no title screen yet: defeat reloads the scene")
	vs.title_scene = "res://scenes/combat_sandbox.tscn"
	check(vs.defeat_destination() == "res://scenes/combat_sandbox.tscn", "defeat goes to the title scene once it exists")
	c.combat_ended.emit(false)
	check(not vs.visible and got.size() == 1, "defeat pays nothing")

	var sb := (load("res://scenes/combat_sandbox.tscn") as PackedScene).instantiate()
	var svs := sb.find_child("VictoryScreen", true, false) as VictoryScreen
	var sogre := CombatantStats.of(sb.find_child("ogre", true, false))
	check(svs != null and svs.coordinator != null and sogre.xp_reward == 30, "sandbox has a victory screen and enemy rewards")
	sb.free()
func test_defend_halves_damage_and_recovers_bp() -> void:
	var c := _coordinator([])
	var ally := _make_actor(&"a", CombatTypes.Team.PARTY, Vector3.ZERO, {"pdef": 20.0})
	var enemy := _make_actor(&"e", CombatTypes.Team.ENEMY, Vector3(2, 0, 0), {"patk": 100.0})
	c.start_encounter(_nodes([ally]), _nodes([enemy]), Vector3.ZERO)
	for u in [ally, enemy]:
		c.set_gauge(u, 0.0)

	c.set_gauge(ally, 100.0)
	c.advance_timeline(0.0)
	var boost: BoostComponent = ally.get_node("BoostComponent")
	var bp_before: int = boost.current_bp
	var r := c.execute_defend(ally)
	check(r["ok"], "Defend executes")
	check(CombatantStats.of(ally).is_defending, "ally is marked defending")
	check(boost.current_bp == bp_before + 1, "Defend recovers 1 BP (got %d, was %d)" % [boost.current_bp, bp_before])
	check(CombatantStats.of(ally).mp == CombatantStats.of(ally).max_mp, "Defend costs no MP")
	check(c.state == CombatTypes.BattleState.TIMELINE_TICK, "Defend ends the actor's turn")

	c.set_gauge(enemy, 100.0)
	c.advance_timeline(0.0)
	# 0.8*(100-10) = 72, halved by Defend.
	check(CombatantStats.of(ally).hp == CombatantStats.of(ally).max_hp - 36,
			"defended ally takes half damage (got %d)" % CombatantStats.of(ally).hp)


func test_defend_clears_on_defenders_own_next_turn() -> void:
	var c := _coordinator([])
	var ally := _make_actor(&"a", CombatTypes.Team.PARTY, Vector3.ZERO)
	var enemy := _make_actor(&"e", CombatTypes.Team.ENEMY, Vector3(2, 0, 0))
	c.start_encounter(_nodes([ally]), _nodes([enemy]), Vector3.ZERO)
	for u in [ally, enemy]:
		c.set_gauge(u, 0.0)

	c.set_gauge(ally, 100.0)
	c.advance_timeline(0.0)
	c.execute_defend(ally)

	c.set_gauge(enemy, 100.0)
	c.advance_timeline(0.0)
	check(CombatantStats.of(ally).is_defending, "still defending after the enemy's turn, not its own")

	c.set_gauge(ally, 100.0)
	c.advance_timeline(0.0)
	check(not CombatantStats.of(ally).is_defending, "Defend clears when the defender's own turn comes back")
	check(c.state == CombatTypes.BattleState.COMMAND_WAIT and c.active_actor == ally, "ally prompted for its turn")


func test_defend_rejected_outside_actors_turn() -> void:
	var c := _coordinator([])
	var crono := _make_actor(&"crono", CombatTypes.Team.PARTY, Vector3(-3, 0, 0))
	var lucca := _make_actor(&"lucca", CombatTypes.Team.PARTY, Vector3(-3, 0, 1))
	var e := _make_actor(&"e", CombatTypes.Team.ENEMY, Vector3(2, 0, 0))
	c.start_encounter(_nodes([crono, lucca]), _nodes([e]), Vector3.ZERO)
	for u in [crono, lucca, e]:
		c.set_gauge(u, 0.0)

	var r0 := c.execute_defend(crono)
	check(not r0["ok"], "Defend refused before anyone is prompted")

	c.set_gauge(crono, 100.0)
	c.advance_timeline(0.0)
	var lucca_bp_before: int = lucca.get_node("BoostComponent").current_bp
	var r1 := c.execute_defend(lucca)
	check(not r1["ok"], "Defend refused for a unit that isn't the active actor")
	check(not CombatantStats.of(lucca).is_defending, "no flag set on refusal")
	check(lucca.get_node("BoostComponent").current_bp == lucca_bp_before, "no BP granted on refusal")
	check(c.state == CombatTypes.BattleState.COMMAND_WAIT and c.active_actor == crono, "still Crono's turn")


func test_haste_and_slow_gauge_multipliers() -> void:
	var c := _coordinator([])
	var a := _make_actor(&"a", CombatTypes.Team.PARTY, Vector3.ZERO, {"speed": 10.0})
	var b := _make_actor(&"b", CombatTypes.Team.PARTY, Vector3.ZERO, {"speed": 10.0})
	var e := _make_actor(&"e", CombatTypes.Team.ENEMY, Vector3(2, 0, 0), {"speed": 0.0})
	c.start_encounter(_nodes([a, b]), _nodes([e]), Vector3.ZERO)
	for u in [a, b, e]:
		c.set_gauge(u, 0.0)

	c.apply_haste(a)
	c.apply_slow(b)
	check(is_equal_approx(c.get_gauge_multiplier(a), HybridBattleCoordinator.HASTE_MULTIPLIER), "Haste sets 1.5x")
	check(is_equal_approx(c.get_gauge_multiplier(b), HybridBattleCoordinator.SLOW_MULTIPLIER), "Slow sets 0.5x")

	c.advance_timeline(1.0)
	check(is_equal_approx(c.get_gauge(a), 15.0), "hasted ally's gauge fills at 1.5x speed (got %f)" % c.get_gauge(a))
	check(is_equal_approx(c.get_gauge(b), 5.0), "slowed ally's gauge fills at 0.5x speed (got %f)" % c.get_gauge(b))

	c.clear_gauge_multiplier(a)
	check(is_equal_approx(c.get_gauge_multiplier(a), 1.0), "clearing the multiplier restores normal speed")
