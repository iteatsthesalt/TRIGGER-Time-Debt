## The test suite. Loaded at runtime by run_tests.gd so autoload singletons resolve.
extends Node

var root: Node
var _done: bool = false
var exit_code: int = 0

var _passed: int = 0
var _failed: int = 0
var _current: String = ""
var _nodes: Array[Node] = []


func run() -> void:
	var tests: Array[Callable] = [
		test_tags_known_and_unique_per_element,
		test_stat_curves_match_table,
		test_shave_law_basic,
		test_duplicate_tags_count_once,
		test_lv3_bonus_once_only_if_matched,
		test_shave_never_below_zero_and_break_immediate,
		test_keyed_plates_fall_in_order,
		test_belief_plates,
		test_break_timing_lock_rebuild_resume,
		test_hold_extends_lock,
		test_damage_state_multipliers,
		test_damage_broken_def_and_crit,
		test_falloff_and_perfect_frame,
		test_astral_displacement,
		test_positioner_counts_every_battler,
		test_positioner_line_stops_at_blocker,
		test_positioner_cross_split_delta,
		test_boost_bank_caps_and_pool,
		test_boost_power_and_scale_tables,
		test_crono_ceiling_and_floor,
		test_crono_crack_states,
		test_sera_thresholds_and_phase,
		test_sera_overflow_to_crono,
		test_status_durations_and_turns,
		test_coordinator_sync_hold_freezes_time,
		test_coordinator_gate_grants_bp_and_attack_breaks,
		test_coordinator_tech_costs_and_strain,
		test_coordinator_rewind_restores_turn_start,
		test_coordinator_hairline_rewind_tax,
		test_coordinator_phase_out_two_turns_and_synergy,
		test_coordinator_guard_parry_and_ens_ring,
		test_coordinator_enemy_wind_up_and_break_cancels,
		test_coordinator_victory_rewards_and_spare,
		test_coordinator_defeat_costs_integrity,
		test_coordinator_prometheus_core,
		test_coordinator_oil_blight_drains_pool,
		test_coordinator_borrowed_future_duplicates,
		test_coordinator_dual_tech_from_ready_pool,
		test_coordinator_broken_body_is_cover,
		test_coordinator_statue_and_killed_while_broken,
		test_data_registry_loads_and_validates,
		test_possibility_engine_flags_affinity_beckons,
		test_save_roundtrip,
		test_story_runner_inline_script,
		test_prologue_scripts_reachable,
	]
	for t in tests:
		_current = t.get_method()
		var before: int = _passed + _failed
		await t.call()
		check(_passed + _failed > before, "ran no checks; it crashed before its first check")
		_cleanup()
	print("\n%d passed, %d failed" % [_passed, _failed])
	exit_code = 1 if _failed > 0 else 0
	_done = true


# ---------------------------------------------------------------- fixtures

func check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL [%s]: %s" % [_current, msg])


func check_eq(a: Variant, b: Variant, msg: String) -> void:
	check(a == b, "%s (got %s, want %s)" % [msg, str(a), str(b)])


func check_near(a: float, b: float, tol: float, msg: String) -> void:
	check(absf(a - b) <= tol, "%s (got %s, want %s)" % [msg, str(a), str(b)])


func _cleanup() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _track(n: Node) -> Node:
	_nodes.append(n)
	return n


func _party_member(id: StringName, level: int, pos: Vector3) -> Node3D:
	var body := Node3D.new()
	body.name = String(id)
	var st := CombatantStats.new()
	st.name = "CombatantStats"
	st.apply_party_curve(id, level)
	st.weapon_tags = [&"SWORD"]
	st.weapon_hits = 2
	if id == &"sera":
		st.weapon_tags = [&"PIERCING"]
	body.add_child(st)
	var sc := StatusComponent.new()
	sc.name = "StatusComponent"
	body.add_child(sc)
	if id == &"crono":
		var td := TimeDebtComponent.new()
		td.name = "TimeDebtComponent"
		body.add_child(td)
	if id == &"sera":
		var sol := SolidityComponent.new()
		sol.name = "SolidityComponent"
		body.add_child(sol)
	root.add_child(body)
	body.global_position = pos
	st.reset_vitals()
	_track(body)
	return body


func _enemy(id: StringName, level: int, pos: Vector3, shield: int, weak: Array, opts: Dictionary = {}) -> Node3D:
	var body := Node3D.new()
	body.name = String(id)
	var st := CombatantStats.new()
	st.name = "CombatantStats"
	st.actor_id = id
	st.apply_enemy_curve(level, String(opts.get("kind", "regular")))
	if opts.has("hp"):
		st.base_max_hp = int(opts["hp"])
	st.weapon_tags = CombatTags.to_names(opts.get("weapon_tags", [&"BLUNT"]))
	st.tags = CombatTags.to_names(opts.get("tags", []))
	body.add_child(st)
	var sh := ShieldComponent.new()
	sh.name = "ShieldComponent"
	sh.max_shield = shield
	sh.weaknesses = CombatTags.to_names(weak)
	if opts.has("keyed"):
		var kp: Array[Dictionary] = []
		for k in opts["keyed"]:
			kp.append(k)
		sh.keyed_plates = kp
	if opts.has("belief"):
		sh.belief_number = int(opts["belief"])
	if opts.has("resists"):
		sh.resists = CombatTags.to_names(opts["resists"])
	body.add_child(sh)
	var sc := StatusComponent.new()
	sc.name = "StatusComponent"
	body.add_child(sc)
	root.add_child(body)
	body.global_position = pos
	st.reset_vitals()
	sh.reset_shields()
	_track(body)
	return body


func _tech(d: Dictionary) -> TechDef:
	return TechDef.from_dict(d)


func _coord(seed_v: int = 7) -> BattleCoordinator:
	var c := BattleCoordinator.new()
	c.auto_tick = false
	c.rng_seed = seed_v
	c.fixed_variance = 1.0
	root.add_child(c)
	_track(c)
	return c


func _lib() -> Dictionary:
	var lib: Dictionary = {}
	for d in [
		{"id": "time_slice", "name": "Time Slice", "tier": "single", "actors": ["crono"], "tags": ["ASTRAL", "SWORD", "TIME_DEBT"], "shape": "SINGLE", "hits": 1, "power": 1.6, "uses": "ASTRAL", "costs": {"crono": {"strain_pct": 1}}},
		{"id": "astral_slash", "name": "Astral Slash", "tier": "single", "actors": ["crono"], "tags": ["ASTRAL", "SWORD", "TIME_DEBT"], "shape": "CONE", "radius": 2.8, "length": 5.5, "aoe_scale": 1.1, "hits": 1, "power": 1.4, "uses": "ASTRAL", "costs": {"crono": {"strain_pct": 2}}},
		{"id": "rewind", "name": "Rewind", "tier": "single", "actors": ["sera"], "tags": ["TACHYON", "PROBABILITY"], "shape": "SINGLE", "target": "any", "effect": "rewind", "costs": {"sera": {"solidity_pct": 5}}},
		{"id": "hold", "name": "HOLD", "tier": "single", "actors": ["sera"], "tags": ["TACHYON"], "shape": "SINGLE", "effect": "hold", "costs": {"sera": {"solidity_pct": 5}}},
		{"id": "borrowed_future", "name": "Borrowed Future", "tier": "single", "actors": ["sera"], "tags": ["TACHYON", "PROBABILITY"], "shape": "PARTY", "target": "party", "effect": "borrowed_future", "costs": {"sera": {"solidity_pct": 10}}},
		{"id": "tachyon_needle", "name": "Tachyon Needle", "tier": "single", "actors": ["sera"], "tags": ["TACHYON", "PIERCING", "PROBABILITY"], "shape": "LINE_PIERCE", "length": 12.0, "width": 0.8, "hits": 3, "power": 0.9, "uses": "ELEMENTAL", "effect": "tachyon_needle", "costs": {"sera": {"mp": 6}}},
		{"id": "eclipse_x_strike", "name": "Eclipse X-Strike", "tier": "dual", "actors": ["crono", "krona"], "tags": ["ASTRAL", "RUIN", "CROSS"], "shape": "CROSS", "radius": 1.0, "length": 4.0, "aoe_scale": 1.3, "hits": 2, "power": 1.0, "uses": "BEST", "effect": "eclipse_x_strike", "costs": {"crono": {"strain_pct": 3}, "krona": {"mp": 8}}},
		{"id": "teppo_ash_cut", "name": "Teppo Ash-Cut", "tier": "single", "actors": ["krona"], "tags": ["RUIN", "ENTROPY", "INK"], "shape": "CONE", "radius": 3.0, "length": 3.0, "hits": 1, "power": 1.2, "uses": "PHYSICAL", "costs": {"krona": {"mp": 5}}},
	]:
		var t := TechDef.from_dict(d)
		lib[t.id] = t
	return lib


func _start(c: BattleCoordinator, party: Array, enemies: Array, cfg: Dictionary = {}) -> void:
	var config: Dictionary = {"techs": _lib(), "advantage": "normal"}
	for k in cfg.keys():
		config[k] = cfg[k]
	c.start_battle(party, enemies, Vector3.ZERO, config)


func _advance_until_window(c: BattleCoordinator, max_s: float = 30.0) -> Node:
	var t: float = 0.0
	while c.state != BattleCoordinator.State.COMMAND_WAIT and t < max_s and c.state != BattleCoordinator.State.IDLE:
		c.advance(1.0 / 60.0)
		t += 1.0 / 60.0
	return c.active_actor


func _advance_until_actor(c: BattleCoordinator, id: StringName, max_s: float = 60.0) -> Node:
	var t: float = 0.0
	while t < max_s and c.state != BattleCoordinator.State.IDLE:
		var a: Node = _advance_until_window(c, max_s - t)
		if a == null:
			return null
		if CombatantStats.of(a).actor_id == id:
			return a
		c.cmd_guard(a)
		t += 0.5
	return null


# ---------------------------------------------------------------- tags, curves

func test_tags_known_and_unique_per_element() -> void:
	check(CombatTags.is_known(&"ASTRAL") and not CombatTags.is_known(&"BANANA"), "tag registry knows elements")
	var seen: Dictionary = {}
	for tag in CombatTags.ELEMENT_OF.keys():
		check(not seen.has(tag), "element tag %s belongs to one element" % tag)
		seen[tag] = true
	check_eq(CombatTags.count_elements([&"ASTRAL", &"SWORD", &"RUIN", &"FERRO"]), 3, "three elements counted for PRISMATIC")
	check_eq(CombatTags.short(&"TIME_DEBT"), "TDB", "short labels")


func test_stat_curves_match_table() -> void:
	check_eq(StatCurves.party_hp(1, "tank"), 120, "tank HP at Lv1")
	check_eq(StatCurves.party_hp(20, "caster"), 385, "caster HP at Lv20")
	check_eq(StatCurves.party_hp(99, "balanced"), 2770, "balanced HP at Lv99")
	check_near(StatCurves.party_spd(1, &"crono"), 100.0, 0.01, "Crono Spd 100 at Lv1")
	check_near(StatCurves.party_spd(99, &"sera"), 177.0, 0.01, "Sera Spd 165+12 at Lv99")
	check_eq(StatCurves.enemy_hp(20, "boss"), 45000, "R-66Y: 2,250 × 20 = 45,000")
	check_eq(StatCurves.enemy_hp(12, "regular"), 330, "regular HP 30 + 25 L")
	check_eq(CombatConstants.xp_to_next(1), 20, "XP to Lv2")
	var st := CombatantStats.new()
	_track(st)
	st.apply_party_curve(&"crono", 12)
	check_near(st.p_atk, 84.0, 0.01, "Crono P.Atk 12 + 6 × 12 = 84")
	check_near(st.e_atk, 78.0, 0.01, "Crono E.Atk 6 + 6 × 12 = 78")


# ---------------------------------------------------------------- shields

func test_shave_law_basic() -> void:
	var e := _enemy(&"mite", 12, Vector3.ZERO, 2, ["ASTRAL", "FERRO"])
	var sh := ShieldComponent.of(e)
	var p: Dictionary = sh.preview_action([&"ASTRAL", &"SWORD", &"TIME_DEBT"], 1, 0)
	check_eq(int(p["shave"]), 1, "1 match × 1 hit shaves 1")
	check(not bool(p["breaks"]), "does not Break at 1 of 2")
	var p3: Dictionary = sh.preview_action([&"ASTRAL", &"SWORD"], 1, 1)
	check_eq(int(p3["shave"]), 2, "Lv3 bonus makes it 2")
	check(bool(p3["breaks"]), "and Breaks")
	# Non-weak hit gets state 1.0 and shaves nothing (acceptance 1).
	var r: Dictionary = sh.apply_strike([&"SWORD"], 1, e)
	check_eq(int(r["shaved"]), 0, "non-matching strike shaves nothing even with a bonus")
	check(not bool(r["hit_weakness"]), "and is not a weakness hit")
	# 8-hit hz_static on a 3-plate HZ-weak enemy: 1 × 8 = 8, gone after the third tick.
	var drone := _enemy(&"drone", 59, Vector3(2, 0, 0), 3, ["HZ", "NULL"])
	var dsh := ShieldComponent.of(drone)
	var ticks: int = 0
	for i in 8:
		var rr: Dictionary = dsh.apply_strike([&"HZ", &"SIGNAL", &"WHITE_NOISE"], 0, e)
		ticks += 1
		if rr["caused_break"]:
			break
	check_eq(ticks, 3, "3 plates gone after the third tick")


func test_duplicate_tags_count_once() -> void:
	var e := _enemy(&"x", 5, Vector3.ZERO, 6, ["FIRE", "SWORD"])
	var sh := ShieldComponent.of(e)
	var r: Dictionary = sh.apply_strike([&"FIRE", &"FIRE", &"FIRE", &"SWORD"], 0, e)
	check_eq(int(r["shaved"]), 2, "duplicate tags count once per strike")


func test_lv3_bonus_once_only_if_matched() -> void:
	var e := _enemy(&"x", 5, Vector3.ZERO, 10, ["SWORD"])
	var sh := ShieldComponent.of(e)
	var bonus_left: int = 1
	var total: int = 0
	for i in 3:
		var r: Dictionary = sh.apply_strike([&"SWORD"], bonus_left, e)
		if r["matched"]:
			bonus_left = 0
		total += int(r["shaved"])
	check_eq(total, 4, "3 hits × 1 match + 1 bonus once = 4")
	var p: Dictionary = sh.preview_action([&"SWORD"], 3, 1)
	check_eq(int(p["shave"]), 4, "preview of a new action: 3 hits + the bonus once again")
	var e2 := _enemy(&"y", 5, Vector3(1, 0, 0), 10, ["FIRE"])
	var p2: Dictionary = ShieldComponent.of(e2).preview_action([&"SWORD"], 3, 1)
	check_eq(int(p2["shave"]), 0, "bonus never applies without a match")


func test_shave_never_below_zero_and_break_immediate() -> void:
	var e := _enemy(&"x", 5, Vector3.ZERO, 2, ["SWORD", "FIRE"])
	var sh := ShieldComponent.of(e)
	var r: Dictionary = sh.apply_strike([&"SWORD", &"FIRE"], 1, e)
	check_eq(int(r["shaved"]), 2, "excess shave is lost")
	check_eq(sh.current_shield, 0, "shield never below 0")
	check(sh.is_broken and bool(r["caused_break"]), "Breaks immediately on the hit")
	var r2: Dictionary = sh.apply_strike([&"SWORD"], 0, e)
	check_eq(int(r2["shaved"]), 0, "later strikes see a Broken target")
	check(bool(r2["hit_weakness"]), "but still read as weakness hits")


func test_keyed_plates_fall_in_order() -> void:
	var e := _enemy(&"spoon", 2, Vector3.ZERO, 0, ["FIRE", "SWORD"], {"keyed": [
		{"material": &"ICE", "key": &"FIRE", "weight": 1}, {"material": &"INK", "key": &"SWORD", "weight": 1}]})
	var sh := ShieldComponent.of(e)
	check_eq(sh.max_total(), 2, "keyed total is the sum of weights")
	var r: Dictionary = sh.apply_strike([&"SWORD"], 0, e)
	check_eq(int(r["shaved"]), 0, "the ink plate cannot fall before the ice plate")
	var r2: Dictionary = sh.apply_strike([&"FIRE"], 0, e)
	check_eq(int(r2["shaved"]), 1, "fire removes the ice plate")
	check_eq(sh.current_key(), &"SWORD", "next key is SWORD")
	var r3: Dictionary = sh.apply_strike([&"SWORD"], 0, e)
	check(bool(r3["caused_break"]), "sword removes the ink plate and Breaks")
	check_eq(sh.break_signature, [&"SWORD"], "Break Signature records the last plate's tags")


func test_belief_plates() -> void:
	var e := _enemy(&"doll", 4, Vector3.ZERO, 10, ["SWORD", "FIRE"], {"belief": 999})
	var sh := ShieldComponent.of(e)
	check_eq(sh.display_number(), 999, "shows 999")
	var r: Dictionary = sh.apply_strike([&"ICE"], 0, e)
	check(bool(r["chipped_belief"]) and sh.current_shield == 10, "wrong tags chip the fake number only")
	check_eq(sh.display_number(), 998, "the shown number drops")
	for i in 10:
		sh.apply_strike([&"SWORD"], 0, e)
	check(sh.is_broken, "ten real plates Break it")


func test_break_timing_lock_rebuild_resume() -> void:
	var e := _enemy(&"x", 5, Vector3.ZERO, 1, ["SWORD"])
	var sh := ShieldComponent.of(e)
	sh.apply_strike([&"SWORD"], 0, e)
	check(sh.is_broken, "broken")
	sh.tick(2.9)
	check(sh.is_broken and sh.rebuild_pct == 0.0, "no rebuild before 3.0 s")
	sh.tick(0.1 + 1.0)
	check_near(sh.rebuild_pct, 18.0, 0.01, "then 18% per second")
	var ended: bool = false
	var t: float = 0.0
	while not ended and t < 20.0:
		ended = sh.tick(0.1)
		t += 0.1
	check(ended and not sh.is_broken, "Break ends at 100%")
	check_near(t + 4.0, 8.6, 0.25, "about 8.6 s from Break to recovery")
	check_eq(sh.current_shield, 1, "shield restored to max")
	check_near(sh.resume_left, 0.4, 0.001, "0.4 s resume blend")
	check(not sh.can_act(), "cannot act during the blend")
	sh.tick_resume(0.4)
	check(sh.can_act(), "acts after the blend")


func test_hold_extends_lock() -> void:
	var e := _enemy(&"x", 5, Vector3.ZERO, 1, ["SWORD"])
	var sh := ShieldComponent.of(e)
	sh.apply_strike([&"SWORD"], 0, e)
	sh.extend_lock(CombatConstants.SERA_HOLD_BREAK_EXTENSION_S)
	check_near(sh.lock_left, 5.5, 0.001, "HOLD adds exactly 2.5 s per 5%")
	sh.tick(5.4)
	check_eq(sh.rebuild_pct, 0.0, "no rebuild yet")
	sh.tick(0.2)
	check(sh.rebuild_pct > 0.0, "rebuild starts after the extended lock")


# ---------------------------------------------------------------- damage

func test_damage_state_multipliers() -> void:
	check_near(DamagePipeline.state_multiplier(false, 0), 1.0, 0.0001, "normal 1.0")
	check_near(DamagePipeline.state_multiplier(false, 3), 1.3, 0.0001, "Lv3 1.3")
	check_near(DamagePipeline.state_multiplier(true, 0), 2.0, 0.0001, "weak 2.0")
	check_near(DamagePipeline.state_multiplier(true, 3), 2.6, 0.0001, "weak Lv3 2.6")
	# Worked example 2 (§6.5): Crono Lv12 Astral Slash Lv3 on a Slag-Mite ≈ 676 before displacement.
	var r: Dictionary = DamagePipeline.compute_hit({"atk": 81.0, "def": 48.0, "base": 1.4, "party_synergy": 1.10, "boost_level": 3, "weakness": true, "variance": 1.0})
	check_near(float(r["damage"]), 676.0, 2.0, "worked example 2 ≈ 676")
	# Worked example 1: plain hit ≈ 52.
	var r1: Dictionary = DamagePipeline.compute_hit({"atk": 84.0, "def": 50.0, "base": 1.0, "party_synergy": 1.10, "variance": 1.0})
	check_near(float(r1["damage"]), 52.0, 1.0, "worked example 1 ≈ 52")


func test_damage_broken_def_and_crit() -> void:
	# Worked example 3: Solar Railgun rail hit into Broken R-66Y ≈ 1,441.
	var r: Dictionary = DamagePipeline.compute_hit({"atk": 129.0, "def": 55.0, "base": 1.2, "synergy": 1.6, "party_synergy": 1.10, "boost_level": 2, "weakness": true, "broken": true, "variance": 1.0})
	check_near(float(r["damage"]), 1441.0, 5.0, "worked example 3 ≈ 1,441 per rail")
	check(bool(r["crit"]), "every hit on a Broken target is a critical")
	var r2: Dictionary = DamagePipeline.compute_hit({"atk": 100.0, "def": 0.0, "base": 1.0, "broken": true, "variance": 1.0})
	check_near(float(r2["damage"]), 80.0 * 1.5, 0.5, "no separate Break multiplier: only ×1.5")


func test_falloff_and_perfect_frame() -> void:
	check_near(DamagePipeline.falloff(0, 0), 1.0, 0.0001, "nearest 1.0")
	check_near(DamagePipeline.falloff(1, 0), 0.75, 0.0001, "second 0.75")
	check_near(DamagePipeline.falloff(3, 0), 0.25, 0.0001, "fourth 0.25")
	check_near(DamagePipeline.falloff(1, 3), 1.0, 0.0001, "Lv3 starts falloff one later")
	var r: Dictionary = DamagePipeline.compute_hit({"atk": 100.0, "def": 0.0, "perfect": true, "variance": 1.0})
	check_near(float(r["damage"]), 80.0 * 1.15, 0.5, "perfect frame 1.15")
	var h: int = DamagePipeline.compute_heal(100.0, 0.9, 0)
	check_eq(h, 81, "heal = E.Atk × base × 0.9")


func test_astral_displacement() -> void:
	var r: Dictionary = DamagePipeline.compute_hit({"atk": 50.0, "def": 0.0, "astral": true, "target_hp": 1000, "variance": 1.0})
	check_eq(int(r["displacement"]), 10, "+1% of current HP")
	check_near(float(r["gauge_push"]), 5.0, 0.001, "and gauge −5")
	var rb: Dictionary = DamagePipeline.compute_hit({"atk": 50.0, "def": 0.0, "astral": true, "target_hp": 10000, "is_boss": true, "variance": 1.0})
	check_eq(int(rb["displacement"]), 25, "0.25% against bosses")


# ---------------------------------------------------------------- geometry

func test_positioner_counts_every_battler() -> void:
	var cands: Array = []
	for i in 4:
		cands.append({"node": "e%d" % i, "pos": Vector3(float(i) * 1.5, 0.0, 0.0), "radius": 0.5})
	var hits: Array = TacticalPositioner.targets_in_shape({"shape": TechDef.Shape.LINE_PIERCE, "length": 8.0, "width": 1.2, "scale": 1.0}, Vector3(-2, 0, 0), Vector3(1, 0, 0), cands)
	check_eq(hits.size(), 4, "a line counts every battler along it, not only the first")
	var circle: Array = TacticalPositioner.targets_in_shape({"shape": TechDef.Shape.CIRCLE, "radius": 2.0, "scale": 1.0}, Vector3.ZERO, Vector3(1.5, 0, 0), cands)
	check_eq(circle.size(), 3, "circle radius 2 around 1.5 catches three")
	var scaled: Array = TacticalPositioner.targets_in_shape({"shape": TechDef.Shape.CIRCLE, "radius": 2.0, "scale": 1.75}, Vector3.ZERO, Vector3(1.5, 0, 0), cands)
	check_eq(scaled.size(), 4, "Lv3 scale 1.75 catches all four")
	var aura: Array = TacticalPositioner.targets_in_shape({"shape": TechDef.Shape.SELF_AURA, "radius": 4.0, "inner_radius": 1.0, "scale": 1.0}, Vector3.ZERO, Vector3.ZERO, cands)
	check_eq(aura.size(), 3, "aura ring counts those between inner and outer (the caster's own spot is safe)")
	var cone: Array = TacticalPositioner.targets_in_shape({"shape": TechDef.Shape.CONE, "radius": 2.8, "length": 5.5, "scale": 1.0}, Vector3(-1, 0, 0), Vector3(1, 0, 0), cands)
	check_eq(cone.size(), 4, "cone covers the line of four")
	check_eq(int(hits[0]["rank"]), 0, "nearest ranks first")


func test_positioner_line_stops_at_blocker() -> void:
	var cands: Array = [
		{"node": "a", "pos": Vector3(2, 0, 0), "radius": 0.5},
		{"node": "b", "pos": Vector3(4, 0, 0), "radius": 0.5},
		{"node": "c", "pos": Vector3(6, 0, 0), "radius": 0.5},
	]
	var blockers: Array = [{"pos": Vector3(4, 0, 0), "radius": 0.56}]
	var hits: Array = TacticalPositioner.targets_in_shape({"shape": TechDef.Shape.LINE_PIERCE, "length": 10.0, "width": 1.2, "scale": 1.0}, Vector3.ZERO, Vector3(1, 0, 0), cands, blockers)
	var names: Array = hits.map(func(h: Dictionary) -> String: return String(h["node"]))
	check(names.has("a") and names.has("b") and not names.has("c"), "a Break-locked body is hit and blocks what is behind it")


func test_positioner_cross_split_delta() -> void:
	var cands: Array = [
		{"node": "centre", "pos": Vector3(0, 0, 0), "radius": 0.5},
		{"node": "arm", "pos": Vector3(0, 0, 1.5), "radius": 0.5},
		{"node": "far", "pos": Vector3(3, 0, 3), "radius": 0.5},
	]
	var cross: Array = TacticalPositioner.targets_in_shape({"shape": TechDef.Shape.CROSS, "radius": 1.0, "length": 4.0, "width": 1.2, "scale": 1.0}, Vector3(-5, 0, 0), Vector3.ZERO, cands)
	check_eq(cross.size(), 2, "cross hits centre and arm, not far")
	var centre_hit: Dictionary = cross.filter(func(h: Dictionary) -> bool: return h["node"] == "centre")[0]
	check(bool(centre_hit["at_crossing"]), "the crossing point is flagged")
	var split: Array = TacticalPositioner.targets_in_shape({"shape": TechDef.Shape.SPLIT_CONE, "radius": 6.0, "length": 8.0, "width": 1.2, "beams": 7, "scale": 1.0}, Vector3(0, 0, -6), Vector3(0, 0, 0), cands)
	var centre_beams: Dictionary = split.filter(func(h: Dictionary) -> bool: return h["node"] == "centre")[0]
	check(int(centre_beams["hits"]) >= 1, "split cone beams hit the centre")
	var delta: Array = TacticalPositioner.targets_in_shape({"shape": TechDef.Shape.DELTA, "width": 1.2, "scale": 1.0}, Vector3(-3, 0, -3), Vector3(3, 0, 3), cands, [], {"second_origin": Vector3(3, 0, -3), "third_origin": Vector3(-3, 0, 3)})
	check(delta.size() >= 2, "delta covers the triangle interior")


# ---------------------------------------------------------------- boost

func test_boost_bank_caps_and_pool() -> void:
	var b := BoostBank.new()
	b.begin_battle()
	check_eq(b.bp, 1, "start at 1 BP")
	for i in 10:
		b.add(1, true)
	check_eq(b.bp, 5, "never exceeds MAX_BP 5")
	check(not b.can_spend(4), "spend cap 3")
	check(b.spend(3), "spends 3")
	check_eq(b.bp, 2, "pool is shared")
	b.gain_locked = true
	b.add(1, true)
	check_eq(b.bp, 2, "the Ringmaster's lock stops gate BP")
	b.gain_locked = false
	b.max_bp = 6
	b.max_spend = 4
	for i in 10:
		b.add(1)
	check_eq(b.bp, 6, "upgraded cap 6")
	check(b.can_spend(4), "upgraded spend 4")
	b.bp = 0
	b.charge_or_owe(1)
	check_eq(b.owed, 1, "the core owes a BP when the pool is empty")
	b.add(2)
	check_eq(b.bp, 1, "the debt is paid first")


func test_boost_power_and_scale_tables() -> void:
	check_eq(CombatConstants.BOOST_POWER, [1.0, 1.9, 2.8, 3.7, 4.5], "power table")
	check_eq(CombatConstants.BOOST_SCALE, [1.0, 1.25, 1.5, 1.75, 2.0], "scale table")
	var t := _tech({"id": "t", "actors": ["crono"], "tags": ["ASTRAL"], "shape": "CIRCLE", "radius": 2.0, "aoe_scale": 1.1})
	check_near(t.shape_scale(3), 1.75 * 1.1, 0.0001, "shape scale multiplies the tech's own AoE scale")


# ---------------------------------------------------------------- Crono and Sera

func test_crono_ceiling_and_floor() -> void:
	var crono := _party_member(&"crono", 12, Vector3.ZERO)
	var st := CombatantStats.of(crono)
	var td := TimeDebtComponent.of(crono)
	var base: int = st.base_max_hp
	check_eq(st.max_hp(), base, "full integrity: ceiling is base")
	td.integrity = 60.0
	check_eq(st.max_hp(), roundi(float(base) * 0.8), "integrity 60 → ×0.8")
	td.pay_battle_strain(0.5)
	check_near(float(st.max_hp()) / float(base), 0.8 * 0.5, 0.01, "strain lowers the ceiling for the battle")
	td.pay_battle_strain(0.9)
	check_eq(st.max_hp(), roundi(float(base) * 0.10), "floor at 10% of base")
	td.add_ruin(5)
	check_eq(td.ruin_stacks, 3, "Ruin caps at 3 stacks")
	td.battle_strain = 0.0
	td.integrity = 100.0
	check_near(td.max_hp_factor(), 1.0 - 0.45, 0.001, "three stacks = −45%")
	td.strain_this_battle = 0.45
	td.integrity = 100.0
	td.end_battle()
	check_near(td.integrity, 98.0, 0.001, "interest: −1 per full 20% of strain")
	check_near(td.battle_strain, 0.0, 0.001, "strain clears at battle end")


func test_crono_crack_states() -> void:
	var td := TimeDebtComponent.new()
	_track(td)
	td.integrity = 100.0
	check_eq(td.crack_state(1.0), TimeDebtComponent.CrackState.PRISTINE, "pristine")
	check_eq(td.crack_state(0.5), TimeDebtComponent.CrackState.HAIRLINE, "hairline by HP")
	td.integrity = 20.0
	check_eq(td.crack_state(1.0), TimeDebtComponent.CrackState.GALAXY, "galaxy by integrity even at full HP")
	td.integrity = 0.0
	check_eq(td.crack_state(1.0), TimeDebtComponent.CrackState.FLATLINE, "flatline")
	td.integrity = 100.0
	td.reinforced_jumps = 3
	td.on_gate_jump()
	check_near(td.integrity, 99.8, 0.0001, "Reinforced halves the collarbone")
	td.reinforced_jumps = 0
	td.on_gate_jump()
	check_near(td.integrity, 99.4, 0.0001, "0.4 per jump otherwise")


func test_sera_thresholds_and_phase() -> void:
	var sera := _party_member(&"sera", 5, Vector3.ZERO)
	var sol := SolidityComponent.of(sera)
	sol.debt = 10.0
	sol.begin_battle()
	check_near(sol.solidity, 90.0, 0.001, "battle solidity = 100 − Debt")
	var r: Dictionary = sol.spend(5.0)
	check_eq((r["crossed"] as Array).size(), 0, "no threshold at 85")
	sol.spend(5.0)
	check(sol.thresholds_crossed.has(80.0), "80 crossed")
	check_eq(sol.ghost_layers(), 3, "three ghosts at 80")
	sol.spend(20.0)
	check(sol.thresholds_crossed.has(60.0) and sol.token_duplicate_available, "60: token duplicate")
	sol.spend(20.0)
	check(sol.is_phased() and sol.phased_turns_left == 2, "40: Causal Collapse for two turns")
	check_eq(sol.last_phase_kind, "forced", "forced without a long hold")
	sol.on_phased_turn()
	sol.on_phased_turn()
	check(not sol.is_phased(), "back after two turns")
	sol.spend(20.0)
	check(sol.thresholds_crossed.has(20.0), "20 crossed")
	sol.spend(30.0)
	check_eq(sol.solidity, 0.0, "cannot go below 0")
	var r2: Dictionary = sol.spend(5.0)
	check_near(float(r2["overflow"]), 5.0, 0.001, "at 0 the cost overflows")
	sol.end_battle()
	check_near(sol.debt, 10.0 + 4.0, 0.001, "+1 Debt interest per full 20% spent (90 → 4)")


func test_sera_overflow_to_crono() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var sera := _party_member(&"sera", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 3, ["SWORD"])
	_start(c, [crono, sera], [e])
	var sol := SolidityComponent.of(sera)
	sol.set_solidity(0.0)
	var td := TimeDebtComponent.of(crono)
	c.spend_solidity(sera, 10.0)
	check_near(td.battle_strain, 0.10, 0.001, "Crono pays Sera's overflow 1:1 as Battle Strain")


func test_status_durations_and_turns() -> void:
	var sc := StatusComponent.new()
	_track(sc)
	sc.add(&"mercury_slow", 4.0)
	sc.add(&"mercury_slow", 4.0)
	sc.add(&"mercury_slow", 4.0)
	check_eq(sc.stacks(&"mercury_slow"), 2, "Mercury SLOW stacks to 2 at most")
	check_near(sc.gauge_multiplier(), 0.5, 0.001, "halves the gauge")
	check_near(sc.movement_multiplier(), 0.5, 0.001, "and movement")
	check_near(sc.hitch_seconds(), 0.5, 0.001, "second stack hitches 0.5 s")
	sc.tick(4.1)
	check(not sc.has(&"mercury_slow"), "expires on battle time")
	sc.add(&"displaced", -1.0, 2)
	sc.on_turn_taken()
	check(sc.has(&"displaced"), "turn statuses last the bearer's own actions")
	sc.on_turn_taken()
	check(not sc.has(&"displaced"), "gone after two turns")
	sc.add(&"grief", -1.0, -1, 3)
	var ticks: Array[int] = []
	sc.periodic.connect(func(id: StringName, stacks: int) -> void: if id == &"grief": ticks.append(stacks))
	sc.tick(10.0)
	check_eq(ticks.size(), 1, "Grief ticks every 10 s")
	check_eq(ticks[0], 3, "with its stack count (max 3)")


# ---------------------------------------------------------------- coordinator

func test_coordinator_sync_hold_freezes_time() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 5, Vector3(-3, 0, 0))
	var e := _enemy(&"mote", 1, Vector3(3, 0, 0), 1, ["WIND"])
	_start(c, [crono], [e])
	var a: Node = _advance_until_window(c)
	check(a == crono, "Crono reaches the gate")
	check_eq(c.state, BattleCoordinator.State.COMMAND_WAIT, "window open")
	check_near(c.get_gauge(crono), 99.0, 0.001, "parked at 99.0")
	var bt: float = c.battle_time
	var eg: float = c.get_gauge(e)
	for i in 120:
		c.advance(1.0 / 60.0)
	check_near(c.battle_time, bt, 0.0001, "battle time does not advance during Sync Hold")
	check_near(c.get_gauge(e), eg, 0.0001, "every other gauge freezes")
	# Sync Hold command parks him; the enemy keeps filling.
	c.cmd_sync_hold(crono)
	for i in 60:
		c.advance(1.0 / 60.0)
	check(c.battle_time > bt, "time resumes with a parked ally")
	check(c.ready_pool.has(crono), "he is in the Ready Pool")
	check(c.request_command(crono) or c.state == BattleCoordinator.State.COMMAND_WAIT, "he can be woken")


func test_coordinator_gate_grants_bp_and_attack_breaks() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 5, Vector3(-3, 0, 0))
	var e := _enemy(&"shard", 1, Vector3(3, 0, 0), 2, ["SWORD", "FIRE"], {"hp": 600})
	_start(c, [crono], [e])
	_advance_until_window(c)
	check_eq(c.bank.bp, 2, "+1 BP at the gate (start 1)")
	var r: Dictionary = c.cmd_attack(crono, e, 0)
	check(bool(r["ok"]), "attack accepted")
	var sh := ShieldComponent.of(e)
	check(sh.is_broken, "2 sword hits shave 2 plates: Break")
	check_eq(c.get_gauge(e), 0.0, "its gauge is 0")
	check_eq(c.get_gauge(crono), 0.0, "his gauge reset")
	var g0: float = c.get_gauge(e)
	for i in 30:
		c.advance(1.0 / 60.0)
	check_eq(c.get_gauge(e), g0, "and frozen while Broken")
	check(CombatantStats.of(e).hp < 600, "damage landed")


func test_coordinator_tech_costs_and_strain() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 12, Vector3(-3, 0, 0))
	var e := _enemy(&"mite", 12, Vector3(1, 0, 0), 2, ["ASTRAL", "FERRO"], {"hp": 100000})
	_start(c, [crono], [e])
	_advance_until_window(c)
	c.bank.bp = 5
	var st := CombatantStats.of(crono)
	var td := TimeDebtComponent.of(crono)
	var mp_before: int = st.mp
	var r: Dictionary = c.cmd_tech(crono, &"astral_slash", e, Vector3.ZERO, 3)
	check(bool(r["ok"]), "Astral Slash at Lv3 accepted")
	check_eq(st.mp, mp_before, "ASTRAL never spends MP")
	check_near(td.battle_strain, 0.02, 0.0001, "costs 2% of base max HP as Battle Strain")
	check(ShieldComponent.of(e).is_broken, "1 match + Lv3 bonus = 2: Break")
	check_eq(c.bank.bp, 2, "3 BP spent from the shared pool")
	var dmg: int = int(r["info"]["damage"][e])
	check(dmg >= 600, "Lv3 weakness hit lands big (got %d)" % dmg)


func test_coordinator_rewind_restores_turn_start() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var sera := _party_member(&"sera", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 3, ["FIRE"])
	_start(c, [crono, sera], [e])
	var a: Node = _advance_until_actor(c, &"crono")
	check(a == crono, "Crono's turn")
	var hp0: int = CombatantStats.of(crono).hp
	c.cmd_guard(crono)
	CombatantStats.of(crono).apply_damage(50, true)
	var s: Node = _advance_until_actor(c, &"sera")
	check(s == sera, "Sera's turn")
	var sol := SolidityComponent.of(sera)
	var before: float = sol.solidity
	var r: Dictionary = c.cmd_tech(sera, &"rewind", crono, Vector3.ZERO, 0)
	check(bool(r["ok"]), "Rewind accepted")
	check_near(before - sol.solidity, 5.0, 0.001, "Rewind always charges 5% solidity")
	check_eq(CombatantStats.of(crono).hp, hp0, "HP restored to his last turn start")


func test_coordinator_hairline_rewind_tax() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var sera := _party_member(&"sera", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 3, ["FIRE"])
	TimeDebtComponent.of(crono).integrity = 50.0
	CombatantStats.of(crono).reset_vitals()
	_start(c, [crono, sera], [e])
	var s: Node = _advance_until_actor(c, &"sera")
	check(s == sera, "Sera's turn")
	var st := CombatantStats.of(crono)
	st.hp = 3
	c.cmd_tech(sera, &"rewind", e, Vector3.ZERO, 0)
	check(st.hp >= 1, "the slip tax cannot KO him")
	st.hp = st.max_hp()
	var s2: Node = _advance_until_actor(c, &"sera")
	if s2 == sera:
		var hp1: int = st.hp
		c.cmd_tech(sera, &"rewind", e, Vector3.ZERO, 0)
		check_eq(hp1 - st.hp, roundi(float(st.max_hp()) * 0.05), "hairline Crono pays 5% max HP per Rewind")


func test_coordinator_phase_out_two_turns_and_synergy() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var sera := _party_member(&"sera", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 30, ["FIRE"], {"hp": 100000})
	_start(c, [crono, sera], [e])
	check_near(c.party_synergy(), 1.10, 0.001, "1.10 with Sera")
	var sol := SolidityComponent.of(sera)
	sol.set_solidity(42.0)
	var s: Node = _advance_until_actor(c, &"sera")
	check(s == sera, "Sera's turn")
	var phased_signal: Array = []
	c.sera_phase_changed.connect(func(p: bool) -> void: phased_signal.append(p))
	c.cmd_tech(sera, &"rewind", e, Vector3.ZERO, 0)
	check(sol.is_phased(), "crossing 40 phases her out")
	check_near(c.party_synergy(), 0.85, 0.001, "synergy 0.85 while phased")
	check(not phased_signal.is_empty() and phased_signal[0] == true, "signal emitted")
	check(not c.targetable_party().has(sera), "untargetable while phased")
	# Advance: her gauge fills twice; she gets no window in between.
	var windows_for_sera: int = 0
	var t: float = 0.0
	while sol.is_phased() and t < 40.0:
		var a: Node = _advance_until_window(c, 40.0 - t)
		if a == null:
			break
		if a == sera:
			windows_for_sera += 1
		c.cmd_guard(a)
		t += 0.5
	check_eq(windows_for_sera, 0, "no window for exactly 2 of her turns")
	check(not sol.is_phased(), "she returns")
	check_near(c.party_synergy(), 1.10, 0.001, "synergy back to 1.10")


func test_coordinator_guard_parry_and_ens_ring() -> void:
	var c := _coord(11)
	var crono := _party_member(&"crono", 5, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 5, Vector3(3, 0, 0), 2, ["FIRE"], {"hp": 500})
	_start(c, [crono], [e], {"advantage": "preemptive"})
	_advance_until_window(c)
	c.cmd_guard(crono)
	check_near(c.get_gauge(crono), 20.0, 0.001, "Guard: next gauge starts at 20")
	c.arm_parry(crono)
	var results: Array = []
	c.parry_result.connect(func(_a: Node, perfect: bool) -> void: results.append(perfect))
	var hp0: int = CombatantStats.of(crono).hp
	var t: float = 0.0
	while results.is_empty() and t < 10.0:
		c.advance(1.0 / 60.0)
		t += 1.0 / 60.0
		if c.state == BattleCoordinator.State.COMMAND_WAIT:
			c.cmd_guard(crono)
			c.arm_parry(crono)
	check(not results.is_empty(), "a parry resolved")
	if not results.is_empty() and results[0]:
		check_eq(CombatantStats.of(crono).hp, hp0, "a perfect parry negates the hit")
		check(c.ens_rings.has(crono), "and leaves an Ens ring")
		check(TimeDebtComponent.of(crono).debt_null_left > 0.0, "Crono's debt costs are nulled for 5 s")


func test_coordinator_enemy_wind_up_and_break_cancels() -> void:
	var c := _coord(3)
	var crono := _party_member(&"crono", 5, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 5, Vector3(3, 0, 0), 2, ["SWORD"], {"hp": 500})
	var def := EnemyDef.from_dict({"key": "x", "level": 5, "actions": [{"id": "slam", "tags": ["BLUNT"], "shape": "CIRCLE", "radius": 2.0, "power": 1.5, "wind_up_s": 2.0, "target": "weakest"}]})
	_start(c, [crono], [e], {"advantage": "ambush", "enemy_defs": {&"x": def}})
	var telegraphs: Array = []
	c.telegraph_started.connect(func(en: Node, _a: Dictionary) -> void: telegraphs.append(en))
	var t: float = 0.0
	while telegraphs.is_empty() and t < 10.0:
		c.advance(1.0 / 60.0)
		t += 1.0 / 60.0
		if c.state == BattleCoordinator.State.COMMAND_WAIT:
			break
	check(not telegraphs.is_empty(), "the enemy starts a wind-up")
	check(c.wind_ups.has(e), "wind-up is running on battle time")
	var a: Node = _advance_until_window(c, 5.0)
	if a == crono and c.wind_ups.has(e):
		c.cmd_attack(crono, e, 0)
		check(ShieldComponent.of(e).is_broken, "sword hits Break it")
		check(not c.wind_ups.has(e), "a Break cancels the wind-up")


func test_coordinator_victory_rewards_and_spare() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 3, Vector3(-3, 0, 0))
	var bench := _party_member(&"krona", 6, Vector3(-9, 0, 0))
	var e := _enemy(&"x", 3, Vector3(3, 0, 0), 1, ["SWORD"], {"hp": 20})
	_start(c, [crono], [e], {"bench": [bench]})
	var ended: Array = []
	c.battle_ended.connect(func(v: bool, s: Dictionary) -> void: ended.append([v, s]))
	_advance_until_window(c)
	var st := CombatantStats.of(e)
	st.hp = 4
	c.cmd_attack(crono, e, 0)
	if not ended.is_empty():
		check(ended[0][0] == true, "victory ends the battle")
		var xp: Dictionary = ended[0][1]["xp"]
		check(int(xp[&"crono"]["xp"]) == st.xp_reward, "active member gets full XP")
		check(int(xp[&"krona"]["xp"]) == roundi(float(st.xp_reward) * 0.75), "bench gets 75%")
	else:
		check(false, "battle should have ended")
	# Spare: Broken and at or below 25% HP.
	var c2 := _coord()
	var crono2 := _party_member(&"crono", 3, Vector3(-3, 0, 0))
	var e2 := _enemy(&"y", 3, Vector3(3, 0, 0), 1, ["SWORD"], {"hp": 1000})
	_start(c2, [crono2], [e2])
	_advance_until_window(c2)
	check(not c2.can_spare(e2), "cannot spare an unbroken enemy")
	c2.cmd_attack(crono2, e2, 0)
	CombatantStats.of(e2).hp = 200
	var a2: Node = _advance_until_window(c2)
	check(c2.can_spare(e2), "Broken and ≤25%: spareable")
	var sp: Dictionary = c2.cmd_spare(a2, e2)
	check(bool(sp["ok"]) and c2.state == BattleCoordinator.State.IDLE, "sparing the last enemy ends the battle")
	check_eq(int(c2.last_summary["spared"]), 1, "recorded as spared")


func test_coordinator_defeat_costs_integrity() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 1, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 40, Vector3(3, 0, 0), 9, ["ICE"], {"kind": "elite"})
	_start(c, [crono], [e], {"advantage": "ambush"})
	var ended: Array = []
	c.battle_ended.connect(func(v: bool, s: Dictionary) -> void: ended.append([v, s]))
	var t: float = 0.0
	while ended.is_empty() and t < 60.0:
		c.advance(1.0 / 60.0)
		t += 1.0 / 60.0
		if c.state == BattleCoordinator.State.COMMAND_WAIT:
			c.cmd_guard(crono)
	check(not ended.is_empty() and ended[0][0] == false, "a Lv40 elite defeats a Lv1 Crono")
	check_near(TimeDebtComponent.of(crono).integrity, 95.0, 0.001, "defeat: integrity −5, no Game Over")


func test_coordinator_prometheus_core() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 5, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 5, Vector3(3, 0, 0), 2, ["ICE"], {"hp": 500})
	_start(c, [crono], [e], {"prometheus": true})
	var st := CombatantStats.of(crono)
	c.bank.bp = 2
	st.apply_damage(99999, true)
	check(st.is_alive(), "the Core revives once")
	check_near(st.hp_ratio(), 0.2, 0.02, "at 20% HP")
	check_eq(c.bank.bp, 1, "and costs 1 BP")
	st.apply_damage(99999, true)
	check(not st.is_alive(), "only once per battle")
	var c2 := _coord()
	var crono2 := _party_member(&"crono", 5, Vector3(-3, 0, 0))
	var e2 := _enemy(&"y", 5, Vector3(3, 0, 0), 2, ["ICE"], {"hp": 500})
	_start(c2, [crono2], [e2], {"prometheus": true})
	TimeDebtComponent.of(crono2).add_ruin(2)
	CombatantStats.of(crono2).apply_damage(99999, true)
	check(not CombatantStats.of(crono2).is_alive(), "blocked at Ruin 2+")


func test_coordinator_oil_blight_drains_pool() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 5, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 5, Vector3(3, 0, 0), 2, ["ICE"], {"hp": 5000})
	_start(c, [crono], [e])
	c.bank.bp = 4
	c.set_oil_blight(true)
	check(c.bank.ultimates_blocked, "Ultimates blocked under Oil-Blight")
	var t: float = 0.0
	while t < 15.5:
		c.advance(0.1)
		t += 0.1
		if c.state == BattleCoordinator.State.COMMAND_WAIT:
			c.cmd_guard(crono)
	check(c.bank.bp <= 3 + 1, "Oil-Blight drains the shared pool (−1 per 15 s)")


func test_coordinator_borrowed_future_duplicates() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var sera := _party_member(&"sera", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 20, ["SWORD"], {"hp": 100000})
	_start(c, [crono, sera], [e])
	var a: Node = _advance_until_actor(c, &"crono")
	c.cmd_attack(a, e, 0)
	var hp_after_first: int = CombatantStats.of(e).hp
	var dealt_first: int = CombatantStats.of(e).base_max_hp - hp_after_first
	var s: Node = _advance_until_actor(c, &"sera")
	var g_before: float = c.get_gauge(crono)
	var r: Dictionary = c.cmd_tech(s, &"borrowed_future", null, Vector3.ZERO, 0)
	check(bool(r["ok"]), "Borrowed Future accepted")
	check(r["info"]["duplicate"] == crono, "the ally nearest a full gauge is duplicated")
	var dealt_second: int = hp_after_first - CombatantStats.of(e).hp
	check(dealt_second > 0 and absi(dealt_second - dealt_first) <= maxi(2, dealt_first / 10), "the Token Duplicate copies the ability (%d vs %d)" % [dealt_first, dealt_second])
	check(c.get_gauge(crono) <= g_before, "gauges pushed back 30%")


func test_coordinator_dual_tech_from_ready_pool() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var krona := _party_member(&"krona", 10, Vector3(-3, 0, 1))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 6, ["ASTRAL", "RUIN"], {"hp": 100000})
	_start(c, [crono, krona], [e])
	var first: Node = _advance_until_window(c)
	var av: Array[TechDef] = c.available_techs(first)
	var has_dual: bool = false
	for t in av:
		if t.id == &"eclipse_x_strike":
			has_dual = true
	check(not has_dual, "Dual not offered until the partner is in the Ready Pool")
	c.cmd_sync_hold(first)
	var second: Node = _advance_until_window(c)
	check(second != first and second != null, "the partner reaches the gate")
	var av2: Array[TechDef] = c.available_techs(second)
	var dual: TechDef = null
	for t in av2:
		if t.id == &"eclipse_x_strike":
			dual = t
	check(dual != null, "Dual offered with both at the gate")
	if dual != null:
		var partners: Array = c.partners_for(dual, second)
		check_eq(partners.size(), 1, "one partner found")
		var r: Dictionary = c.cmd_tech(second, &"eclipse_x_strike", e, c.position_of(e), 0, partners)
		check(bool(r["ok"]), "Dual accepted: %s" % str(r.get("error", "")))
		check_eq(c.get_gauge(crono), 0.0, "both gauges reset")
		check_eq(c.get_gauge(krona), 0.0, "both gauges reset (2)")
		check(c.ready_pool.is_empty(), "Ready Pool emptied")


func test_coordinator_broken_body_is_cover() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-4, 0, 0))
	var sera := _party_member(&"sera", 10, Vector3(-4, 0, 1))
	var near := _enemy(&"near", 10, Vector3(0, 0, 0), 1, ["SWORD"], {"hp": 100000})
	var far := _enemy(&"far", 10, Vector3(4, 0, 0), 1, ["PIERCING"], {"hp": 100000})
	_start(c, [crono, sera], [near, far])
	var a: Node = _advance_until_actor(c, &"crono")
	c.cmd_attack(a, near, 0)
	check(ShieldComponent.of(near).is_broken, "near one Broken")
	var s: Node = _advance_until_actor(c, &"sera")
	var r: Dictionary = c.cmd_tech(s, &"tachyon_needle", null, Vector3(4, 0, 0), 0)
	check(bool(r["ok"]), "needle fired: %s" % str(r.get("error", "")))
	var targets: Array = r["info"]["targets"]
	check(targets.has(near) and not targets.has(far), "the Broken body blocks the line behind it")


func test_coordinator_statue_and_killed_while_broken() -> void:
	var e := _enemy(&"x", 5, Vector3.ZERO, 1, ["SWORD"], {"hp": 10})
	var sh := ShieldComponent.of(e)
	sh.apply_strike([&"SWORD"], 0, e)
	check(sh.is_broken, "broken")
	check_near(CombatConstants.BROKEN_STATUE_S, 8.0, 0.001, "statue lasts 8 s")
	check_near(CombatConstants.BREAK_HULL_INFLATION, 0.12, 0.001, "hull +12%")


# ---------------------------------------------------------------- data, flags, saves, story

func test_data_registry_loads_and_validates() -> void:
	check(Data.loaded, "Data autoload loaded")
	check(Data.errors.is_empty(), "no data validation errors: %s" % "; ".join(Data.errors))
	check(Data.techs.size() >= 20, "techs loaded (%d)" % Data.techs.size())
	check(Data.enemies.size() >= 10, "enemies loaded (%d)" % Data.enemies.size())
	check(Data.tech(&"astral_slash") != null, "astral_slash present")
	check(Data.enemy(&"dust_mote_cluster") != null, "E23 present by key")
	check(Data.characters.has(&"crono") and Data.characters.has(&"sera"), "character kits present")
	check(Data.dialogue.has(&"prologue_breakfast"), "prologue script present")
	check(Data.flags.size() >= 20, "flag definitions present (%d)" % Data.flags.size())


func test_possibility_engine_flags_affinity_beckons() -> void:
	var l0: int = Flags.light
	var b0: int = Flags.beckons
	Flags.set_flag(&"Test_Flag", &"Mercy", {"light": 30})
	check_eq(Flags.light, l0 + 30, "mercy writes +30 Light")
	check_eq(Flags.beckons, b0 + 30, "and 30 Beckons")
	Flags.set_flag(&"Test_Flag", &"Mercy", {"light": 30})
	check_eq(Flags.light, l0 + 30, "setting the same state twice writes nothing")
	check(Flags.register_amber_rift(&"test_rift"), "rift registered")
	check(not Flags.register_amber_rift(&"test_rift"), "once per source")
	var p0: int = Flags.prismatic
	Flags.add_lean(0, "P")
	check_eq(Flags.prismatic, p0 + 1, "lean +1")
	for i in 10:
		Flags.add_lean(0, "P")
	check_eq(Flags.prismatic, p0 + 5, "capped at +5 per universe")
	Flags.flags.erase(&"Test_Flag")
	Flags.amber_rifts.erase(&"test_rift")
	Flags.light = l0
	Flags.beckons = b0
	Flags.prismatic = p0
	Flags.leans.erase(0)


func test_save_roundtrip() -> void:
	Game.crono_integrity = 61.5
	Game.sera_debt = 15.0
	Game.add_item(&"tonic", 2)
	Flags.set_flag(&"Save_Test", &"Yes", {})
	check(Saves.save(9), "saved slot 9")
	Game.crono_integrity = 100.0
	Flags.flags.erase(&"Save_Test")
	check(Saves.load(9), "loaded slot 9")
	check_near(Game.crono_integrity, 61.5, 0.001, "integrity restored")
	check(Flags.has(&"Save_Test"), "flags restored")
	Saves.delete(9)
	Flags.flags.erase(&"Save_Test")
	Game.new_game()


func test_story_runner_inline_script() -> void:
	Story.auto_advance_s = 0.01
	Story.auto_choice = 1
	Story.skip_waits = true
	var seen: Array = []
	var cb := func(who: String, text: String) -> void: seen.append([who, text])
	Story.line_shown.connect(cb)
	await Story.run(&"test_inline", [
		{"say": "Burn. Old burn.", "who": "crono"},
		{"choice": [{"text": "[Nod]", "goto": "nod"}, {"text": "[Look Away]", "set": {"flag": "Story_Test", "state": "Away", "affinity": {"dark": 1}}, "goto": "away"}], "who": "crono"},
		{"label": "nod"}, {"say": "nodded", "who": "narrator"}, {"end": true},
		{"label": "away"}, {"say": "looked away", "who": "narrator"}, {"end": true},
	])
	Story.line_shown.disconnect(cb)
	check_eq(seen.size(), 2, "two lines shown")
	check(seen.size() == 2 and seen[1][1] == "looked away", "choice 1 branched to 'away'")
	check(Flags.is_state(&"Story_Test", &"Away"), "choice side effect set the flag")
	Flags.flags.erase(&"Story_Test")
	Flags.dark = maxi(0, Flags.dark - 1)
	Story.auto_advance_s = -1.0
	Story.auto_choice = -1
	Story.skip_waits = false


func test_prologue_scripts_reachable() -> void:
	for id in [&"prologue_breakfast", &"prologue_courtyard"]:
		var s: Array = Data.dialogue_script(id)
		check(not s.is_empty(), "script %s exists" % id)
		var labels: Dictionary = {}
		for cmd in s:
			if cmd.has("label"):
				labels[String(cmd["label"])] = true
		for cmd in s:
			for key in ["goto", "then", "else"]:
				if cmd.has(key) and String(cmd[key]) != "" and not labels.has(String(cmd[key])):
					check(false, "%s: missing label %s" % [id, cmd[key]])
			if cmd.has("choice"):
				for o in cmd["choice"]:
					if o.has("goto") and not labels.has(String(o["goto"])):
						check(false, "%s: missing label %s" % [id, o["goto"]])
