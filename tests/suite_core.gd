## The core test suite. Loaded at runtime by run_tests.gd so autoload singletons resolve; helpers and
## fixtures live in tests/suite_base.gd. Keep the explicit list: it pins the order the fixtures rely on.
extends "res://tests/suite_base.gd"


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
		test_shard_doll_split_holds_breaks_for_the_director,
		test_damage_state_multipliers,
		test_damage_broken_def_and_crit,
		test_breaking_strike_uses_pre_break_defence,
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
		test_coordinator_sync_hold_without_partner_is_reprompted,
		test_coordinator_preview_equals_resolution,
		test_battle_roster_bench_and_hover,
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
		test_text_layer_loads_and_covers,
		test_possibility_engine_flags_affinity_beckons,
		test_save_roundtrip,
		test_story_runner_inline_script,
		test_prologue_scripts_reachable,
		test_boss_defs_validate_and_phase_windows,
		test_coordinator_add_enemy_and_undamageable,
		test_sprite_library_tiers_and_variants,
		test_props_data_sheets_and_fallback,
		test_prop_footprints_posts_and_boxes,
		test_audio_stings_resolve,
		test_camera_rig_restores_scene_pitch,
	]
	await run_list(tests)



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


func test_shard_doll_split_holds_breaks_for_the_director() -> void:
	# The 999 Shard Doll's split lesson: a broken doll waits for the director's window instead of
	# rebuilding on its own lock, so the rebuild count and the "stay broken" escape can both happen.
	var doll := _enemy(&"shard_doll_split", 1, Vector3.ZERO, 8, ["ASTRAL"])
	var sh := ShieldComponent.of(doll)
	var director: RefCounted = load("res://scripts/battle/bosses/shard_doll_999.gd").new()
	var ctrl := BossController.new()
	_track(ctrl)
	ctrl.coordinator = BattleCoordinator.new()
	_track(ctrl.coordinator)
	ctrl.phase_index = 2
	for i in 8:
		sh.apply_strike([&"ASTRAL"], 0, doll)
	check(sh.is_broken, "eight matching hits break a doll")
	director.on_add_break(ctrl, doll)
	sh.tick(100.0)
	check(sh.is_broken, "a held Break never ends on its own")
	check(director.break_times.has(doll), "the director remembers when the doll broke")
	sh.reset_shields()
	check(not sh.is_broken and sh.current_shield == 8, "the director's rebuild restores every plate")


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


## §6.4 / §5.4: damage is applied before the shave, so the strike that lands the Break is resolved
## against the unbroken target (full DEF, no crit) and the strikes after it see it Broken.
func test_breaking_strike_uses_pre_break_defence() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 12, Vector3(-3, 0, 0))
	var e := _enemy(&"mite", 12, Vector3(1, 0, 0), 1, ["SWORD", "FIRE"], {"hp": 100000})
	_start(c, [crono], [e])
	_advance_until_window(c)
	var a := CombatantStats.of(crono)
	var t := CombatantStats.of(e)
	var ctx := {"atk": a.p_atk, "def": t.p_def, "base": 1.0, "party_synergy": c.party_synergy(), "home_canvas": c._home_canvas(crono), "weakness": true, "variance": 1.0}
	var first: int = int(DamagePipeline.compute_hit(ctx)["damage"])
	ctx["def"] = t.p_def * CombatConstants.BREAK_DEF_MULT
	ctx["broken"] = true
	var second: int = int(DamagePipeline.compute_hit(ctx)["damage"])
	var hits: Array = []
	c.strike_resolved.connect(func(_a: Node, _t: Node, info: Dictionary) -> void: hits.append(info))
	c.cmd_attack(crono, e, 0)
	check_eq(hits.size(), 2, "two sword strikes resolved")
	if hits.size() == 2:
		check(bool(hits[0]["break"]) and not bool(hits[0]["crit"]), "the first strike Breaks and is not a critical")
		check_eq(int(hits[0]["damage"]), first, "it is resolved against the unbroken DEF")
		check(bool(hits[1]["crit"]), "the next strike sees a Broken target")
		check_eq(int(hits[1]["damage"]), second, "DEF halved and ×1.5")
		check(second > first, "so the reward follows the Break, it does not precede it")
	# Worked example 2 at the coordinator: Astral Slash Lv3 Breaks a 2-plate ASTRAL-weak target in one
	# strike and deals the bible's unbroken number (plus displacement), not ×1.5 of it.
	var c2 := _coord()
	var crono2 := _party_member(&"crono", 12, Vector3(-3, 0, 0))
	var mite := _enemy(&"mite", 12, Vector3(1, 0, 0), 2, ["ASTRAL", "FERRO"], {"hp": 100000})
	_start(c2, [crono2], [mite])
	_advance_until_window(c2)
	c2.bank.bp = 5
	var a2 := CombatantStats.of(crono2)
	var t2 := CombatantStats.of(mite)
	var ex2 := {"atk": (a2.p_atk + a2.e_atk) * 0.5, "def": (t2.p_def + t2.e_def) * 0.5, "base": 1.4, "party_synergy": c2.party_synergy(), "home_canvas": c2._home_canvas(crono2), "boost_level": 3, "weakness": true, "astral": true, "target_hp": t2.hp, "variance": 1.0}
	var want: int = int(DamagePipeline.compute_hit(ex2)["damage"])
	var r: Dictionary = c2.cmd_tech(crono2, &"astral_slash", mite, Vector3.ZERO, 3)
	check(ShieldComponent.of(mite).is_broken, "1 match + Lv3 bonus Breaks")
	check_eq(int(r["info"]["damage"][mite]), want, "the breaking strike deals the unbroken number (worked example 2)")


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


## §3.4 presumes a later window: a lone ally (the Prologue party), every ally parked, or a partner KO'd
## while one ally waits must not leave the timeline running with nobody able to act (SyncHoldRules).
func test_coordinator_sync_hold_without_partner_is_reprompted() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 5, Vector3(-3, 0, 0))
	var e := _enemy(&"mote", 1, Vector3(3, 0, 0), 3, ["WIND"], {"hp": 100000})
	_start(c, [crono], [e])
	_advance_until_window(c)
	check(not SyncHoldRules.can_hold(c, crono), "the deck does not offer Sync Hold to a lone ally")
	c.cmd_sync_hold(crono)
	var bp: int = c.bank.bp
	var a: Node = _advance_until_window(c, 5.0)
	check(a == crono and c.state == BattleCoordinator.State.COMMAND_WAIT, "a parked ally nobody can relieve is re-prompted")
	check_eq(c.bank.bp, bp, "with no second gate BP")
	check(c.ready_pool.has(crono), "still parked at 99 until he acts")
	# With a living partner the hold is offered; if that partner falls while he waits, he is woken.
	var c2 := _coord()
	var crono2 := _party_member(&"crono", 5, Vector3(-3, 0, 0))
	var sera := _party_member(&"sera", 5, Vector3(-3, 0, 1))
	var e2 := _enemy(&"mote", 1, Vector3(3, 0, 0), 3, ["WIND"], {"hp": 100000})
	_start(c2, [crono2, sera], [e2])
	var first: Node = _advance_until_window(c2)
	check(SyncHoldRules.can_hold(c2, first), "offered while a partner can still arrive")
	c2.cmd_sync_hold(first)
	var other: Node = sera if first == crono2 else crono2
	CombatantStats.of(other).apply_damage(100000, true)
	var again: Node = _advance_until_window(c2, 5.0)
	check(again == first, "the partner's KO re-prompts the parked ally")
	# Both parked: the first in the pool gets the floor back.
	var c3 := _coord()
	var crono3 := _party_member(&"crono", 5, Vector3(-3, 0, 0))
	var sera3 := _party_member(&"sera", 5, Vector3(-3, 0, 1))
	var e3 := _enemy(&"mote", 1, Vector3(3, 0, 0), 3, ["WIND"], {"hp": 100000})
	_start(c3, [crono3, sera3], [e3])
	var one: Node = _advance_until_window(c3)
	c3.cmd_sync_hold(one)
	var two: Node = _advance_until_window(c3)
	check(two != one, "the partner arrives with the first parked")
	check(not SyncHoldRules.can_hold(c3, two), "the last unparked ally may not park too")
	c3.cmd_sync_hold(two)
	var woke: Node = _advance_until_window(c3, 5.0)
	check(woke == one, "with every ally parked the first parked is re-prompted")


## §18.7 #23: the Shield Plate preview equals the shave the hit then does, including an armed Ens ring,
## a technique's bonus against a status and the watercolour puddle (ShaveBonus is read by both).
func test_coordinator_preview_equals_resolution() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 5, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 5, Vector3(3, 0, 0), 6, ["SWORD"], {"hp": 100000})
	_start(c, [crono], [e])
	_advance_until_window(c)
	c.ens_rings[crono] = {"left": 5.0, "shave": 1}
	var p: Dictionary = c.preview(crono, null, e, c.position_of(e), 0)
	check_eq(int(p[e]["shave"]), 3, "the preview counts the Ens ring: 2 sword strikes + 1")
	var r: Dictionary = c.cmd_attack(crono, e, 0)
	check_eq(int(r["info"]["shave"][e]), int(p[e]["shave"]), "the hit shaves exactly what the plate said")
	check(not c.ens_rings.has(crono), "the ring is spent by the action")
	# Tachyon Needle vs a MAGNETIZED target: +1 in the plate and in the hit.
	var c2 := _coord()
	var sera := _party_member(&"sera", 10, Vector3(-3, 0, 0))
	var m := _enemy(&"m", 10, Vector3(3, 0, 0), 8, ["PIERCING"], {"hp": 100000})
	_start(c2, [sera], [m])
	_advance_until_window(c2)
	StatusComponent.of(m).add(&"magnetized", 10.0)
	var needle: TechDef = c2.tech_library[&"tachyon_needle"]
	var p2: Dictionary = c2.preview(sera, needle, m, c2.position_of(m), 0)
	check_eq(int(p2[m]["shave"]), 4, "3 piercing strikes + 1 against MAGNETIZED")
	var r2: Dictionary = c2.cmd_tech(sera, &"tachyon_needle", m, c2.position_of(m), 0)
	check_eq(int(r2["info"]["shave"][m]), int(p2[m]["shave"]), "the needle shaves what the plate said")


## The bench and Hover Support come from the roster (§3.1, §3.6, §4.2): BattleRoster.plan is the rule,
## fed a fake roster here; the coordinator's Swap, swap-KO'd and hover paths run on what it returns.
func test_battle_roster_bench_and_hover() -> void:
	var p: Dictionary = BattleRoster.plan([&"crono", &"sera", &"krona"], [&"crono"], "with")
	check(p["bench"].has(&"sera") and p["bench"].has(&"krona") and not p["hover"], "with: everyone recruited and not active is on the bench")
	var p2: Dictionary = BattleRoster.plan([&"crono", &"sera", &"krona"], [&"crono"], "hover_support")
	check(bool(p2["hover"]) and not p2["bench"].has(&"sera") and p2["bench"].has(&"krona"), "hover_support: Sera hovers, Krona waits")
	var p3: Dictionary = BattleRoster.plan([&"crono", &"sera"], [&"crono"], "absent")
	check(p3["bench"].is_empty() and not p3["hover"], "absent: she is nowhere")
	var p4: Dictionary = BattleRoster.plan([&"crono", &"sera"], [&"sera", &"crono"], "hover")
	check(p4["bench"].is_empty() and not p4["hover"], "an active Sera never hovers")
	check_eq(Game.bench_ids().size(), BattleRoster.plan(Game.recruited, Game.active_party, Game.sera_in_story)["bench"].size(), "Game.bench_ids agrees with the plan")
	# Swap from the bench, with Sera hovering.
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var krona := _party_member(&"krona", 10, Vector3(-9, 0, 0))
	var sera := _party_member(&"sera", 10, Vector3(-9, 0, 2))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 30, ["FIRE"], {"hp": 100000})
	_start(c, [crono], [e], {"bench": [krona], "hover_sera": sera})
	check_near(c.party_synergy(), 1.10, 0.001, "1.10 with Sera hovering (§6.2)")
	var a: Node = _advance_until_actor(c, &"crono")
	check(a == crono, "Crono's window")
	var bp: int = c.bank.bp
	var r: Dictionary = c.cmd_swap(crono, krona)
	check(bool(r["ok"]) and c.party.has(krona) and not c.party.has(crono) and c.bench.has(crono), "Swap: the bench member takes his spot")
	check_near(c.get_gauge(krona), CombatConstants.SWAP_GAUGE, 0.001, "and arrives with gauge 50")
	check_eq(c.bank.bp, bp + 1, "the first Swap pays +1 BP")
	var hover_turns: int = 0
	for i in 3:
		var w: Node = _advance_until_window(c)
		if w == sera:
			hover_turns += 1
		c.cmd_guard(w)
	check(hover_turns > 0, "hover Sera reaches the gate from the Turn Bar")
	# Swap a KO'd ally out from within 3 m.
	var c2 := _coord()
	var crono2 := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var sera2 := _party_member(&"sera", 10, Vector3(-3, 0, 0))
	var krona2 := _party_member(&"krona", 10, Vector3(-9, 0, 0))
	var e2 := _enemy(&"x", 10, Vector3(3, 0, 0), 30, ["FIRE"], {"hp": 100000})
	_start(c2, [crono2, sera2], [e2], {"bench": [krona2]})
	CombatantStats.of(sera2).apply_damage(100000, true)
	var a2: Node = _advance_until_actor(c2, &"crono")
	var r2: Dictionary = c2.cmd_swap_koed(a2, sera2, krona2)
	check(bool(r2["ok"]) and c2.party.has(krona2) and c2.bench.has(sera2), "a KO'd ally is swapped out by an ally within 3 m")


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


func test_text_layer_loads_and_covers() -> void:
	for kind in [&"bestiary", &"techs", &"items", &"ambient", &"codex"]:
		check(Data.text.has(kind), "text layer kind %s loaded" % kind)
	check(Data.text_gaps.is_empty(), "every enemy, boss, tech, item and flag state has prose; missing: %s" % ", ".join(Data.text_gaps.slice(0, 12)))
	var b: Dictionary = Data.bestiary(&"dust_mote_cluster")
	check(b.has("name") and b.has("entry") and b.has("weak_hint") and b.has("break_line"), "a bestiary entry has name, entry, weak_hint and break_line")
	check(not Data.bestiary(&"atrium_cradle").is_empty(), "bosses are in the bestiary under their id")
	check(Data.bestiary(&"no_such_thing").is_empty(), "an unknown key reads as empty, not null")
	var t: Dictionary = Data.tech_text(&"astral_slash")
	check(not String(t.get("description", "")).is_empty() and not String(t.get("flavor", "")).is_empty(), "a tech has a description and a flavor line")
	var digits := RegEx.create_from_string("[0-9]")
	var numbered: int = 0
	for id in (Data.text[&"techs"] as Dictionary).keys():
		if digits.search(String((Data.text[&"techs"][id] as Dictionary).get("description", ""))) != null:
			numbered += 1
	check_eq(numbered, 0, "tech descriptions carry no numbers (the brief's rule)")
	check_eq(Data.ambient_lines(&"guardia_kitchen").size(), 12, "twelve ambient lines for the kitchen")
	check_eq(Data.ambient_lines(&"atrium").size(), 12, "the Atrium's lines are keyed by its Router id (atrium), not the scene name")
	check(Data.ambient_lines(&"nowhere_at_all").is_empty(), "no lines for an unknown location")
	check(not Data.codex_page(&"Prologue_Fall", &"Teach_Her_To_Land").is_empty(), "a codex page per flag state")
	check(Data.codex_page(&"Prologue_Fall", &"Not_A_State").is_empty(), "no page for an unknown state")
	check(not Data.codex_title(&"Prologue_Fall").is_empty(), "codex pages have a title")
	check(not String(Data.item_text(&"epoch_gauntlet").get("found", "")).is_empty(), "dialogue-granted key items have text too")
	var open: Array[String] = []
	for id in (Data.text[&"items"] as Dictionary).keys():
		if String((Data.text[&"items"][id] as Dictionary).get("found", "")) == "Acquisition source not yet recorded.":
			open.append(String(id))
	open.sort()
	check_eq(",".join(open), "cobalt_wash,mid_tonic,revive", "exactly the three acquisition sources Nich still owes (TRI-79) are open")


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


func test_boss_defs_validate_and_phase_windows() -> void:
	check(Data.bosses.size() >= 31, "31 bosses loaded (got %d)" % Data.bosses.size())
	var problems: int = 0
	for id in Data.bosses.keys():
		var b: BossDef = BossDef.from_dict(Data.bosses[id])
		var errs: PackedStringArray = b.validation_errors()
		if not errs.is_empty():
			problems += 1
			print("    boss %s: %s" % [id, ", ".join(errs)])
		for i in b.phase_count():
			var pdef: EnemyDef = b.phase_def(i)
			check(pdef.hp_override == b.hp and pdef.kind == "boss", "%s phase %d carries the boss HP pool" % [id, i])
	check_eq(problems, 0, "every boss file validates")
	var cradle: BossDef = BossDef.from_dict(Data.bosses[&"atrium_cradle"])
	check_eq(cradle.phase_count(), 3, "the Cradle has three phases")
	check_eq(cradle.phase_for_ratio(1.0), 0, "full HP is phase 1")
	check_eq(cradle.phase_for_ratio(0.5), 1, "50% is the Dollhouse Seal")
	check_eq(cradle.phase_for_ratio(0.1), 2, "10% is the Atrium Fracture")
	check_eq(cradle.phase_def(0).keyed_plates.size(), 4, "phase 1 has four keyed plates")
	check(cradle.phase_def(1).weak.has(&"TACHYON") and cradle.phase_def(1).weak.has(&"LIGHT"), "phase 2 weak to TACHYON and LIGHT")
	var actor: CombatActor = BossController.create_boss_actor(cradle)
	_track(actor)
	check_eq(actor.stats.max_hp(), cradle.hp, "boss actor carries the HP pool from the file")
	check(actor.has_meta("boss_id"), "boss actor is tagged for the battle scene")


func test_coordinator_add_enemy_and_undamageable() -> void:
	var c := _coord(11)
	var crono := _party_member(&"crono", 10, Vector3(0, 0, 3))
	var e1 := _enemy(&"e1", 5, Vector3(0, 0, -2), 1, [])
	_start(c, [crono], [e1])
	var u: Node = _advance_until_actor(c, &"crono")
	check(u != null, "crono gets a window")
	var e2 := _enemy(&"e2", 5, Vector3(2, 0, -2), 1, [])
	c.add_enemy(e2, null)
	check(c.enemies.has(e2) and c.gauges.has(e2), "a mid-battle enemy joins with a gauge")
	c.undamageable.append(e2)
	var hp_before: int = CombatantStats.of(e2).hp
	c.cmd_attack(u, e2, 0)
	check_eq(CombatantStats.of(e2).hp, hp_before, "a sealed enemy takes no HP damage")
	c.undamageable.clear()
	var u2: Node = _advance_until_actor(c, &"crono")
	if u2 != null:
		c.cmd_attack(u2, e2, 0)
		check(CombatantStats.of(e2).hp < hp_before, "and takes damage once the seal lifts")
	c.paused = true
	var t0: float = c.battle_time
	c.advance(1.0)
	check_eq(c.battle_time, t0, "a paused coordinator does not advance")
	c.paused = false


func test_sprite_library_tiers_and_variants() -> void:
	# Crono has a field sheet and an action sheet; Sera has only field. A missing tier or variant falls back.
	var r: Dictionary = SpriteLibrary.resolve("crono", &"field")
	check(not r.is_empty() and r["sheet"].ends_with("crono_field.png"), "crono field resolves to crono_field.png")
	var a: Dictionary = SpriteLibrary.resolve("crono", &"action")
	check(not a.is_empty() and a["tier"] == &"action" and a["sheet"].ends_with("crono_action.png"), "crono action tier resolves")
	var m: Dictionary = SpriteLibrary.resolve("crono", &"map")
	check(not m.is_empty() and m["tier"] == &"field", "a missing map tier falls back to field")
	var v: Dictionary = SpriteLibrary.resolve("crono", &"field", &"u1")
	check(not v.is_empty() and v["variant"] == &"" and v["tier"] == &"field", "a missing variant falls back to the base sheet")
	check(SpriteLibrary.has_tier("crono", &"action") and not SpriteLibrary.has_tier("sera", &"action"), "has_tier reports real tiers only")
	var sprite := ActorSprite.new()
	root.add_child(sprite)
	SpriteLibrary.apply(sprite, "crono", 60.0)
	check(sprite.loaded_tier == &"field" and sprite.anims.has(&"walk") and sprite.rows == 8, "field sheet: eight rows, walk present")
	sprite.set_facing(&"nw")
	sprite.play(&"walk")
	var swapped: bool = sprite.set_tier(&"action")
	check(swapped and sprite.loaded_tier == &"action" and sprite.facing == &"nw", "swapping to the action tier keeps the facing")
	check(sprite.anim == &"idle", "an animation the new tier lacks falls back to idle")
	check(sprite.set_tier(&"field") and sprite.loaded_tier == &"field", "and back to field")
	check(not sprite.set_tier(&"map") and sprite.loaded_tier == &"field", "a missing tier reports false and shows field")
	check(absf(sprite.pixel_size * 95.0 - 1.78) < 0.01, "height mapping: 95 drawn px stand 1.78 m")
	sprite.queue_free()


func test_props_data_sheets_and_fallback() -> void:
	# data/props declares every prop (a billboard with a height in metres); each delivered one has its sheet,
	# frames json and normal sheet under assets/props/u<n>/<key>/; SpriteLibrary resolves and loads them;
	# add_prop falls back to a labelled box for a pending or unknown key instead of breaking the scene.
	check(Data.props.size() >= 40, "props loaded from data/props (%d)" % Data.props.size())
	var delivered: int = 0
	for key in Data.props.keys():
		var e: Dictionary = Data.props[key]
		if bool(e.get("pending", false)):
			continue
		delivered += 1
		var r: Dictionary = SpriteLibrary.resolve_prop(String(key), int(e["universe"]))
		check(not r.is_empty(), "%s has a sheet under assets/props/u%d" % [key, int(e["universe"])])
		if r.is_empty():
			continue
		check(FileAccess.file_exists("%s/%s_frames.json" % [r["dir"], key]), "%s has a frames json" % key)
		check(ResourceLoader.exists("%s/%s_n.png" % [r["dir"], key]), "%s has a normal sheet" % key)
		var meta: Dictionary = SpriteLibrary.frames_meta(r)
		check(int(meta.get("height_px", 0)) > 0 and int(meta.get("width_px", 0)) > 0 and int(meta.get("cell", 0)) % 32 == 0, "%s frames json carries height_px, width_px and a 32-multiple cell" % key)
		check(absf(float(meta.get("height_m", 0.0)) - float(e["height_m"])) < 0.001, "%s sheet height matches data/props" % key)
	check(delivered >= 40, "at least forty props delivered (%d)" % delivered)
	var hearth: Dictionary = SpriteLibrary.resolve_prop("prp_u0_hearth")
	check(hearth.get("sheet", "") == "res://assets/props/u0/prp_u0_hearth/prp_u0_hearth.png", "the hearth resolves without a universe hint")
	check(SpriteLibrary.resolve_prop("prp_u0_hearth", 1).is_empty(), "a wrong universe hint finds nothing")
	var sprite := ActorSprite.new()
	root.add_child(sprite)
	_track(sprite)
	check(SpriteLibrary.apply_prop(sprite, "prp_u0_hearth"), "apply_prop loads the hearth")
	check(sprite.rows == 1 and sprite.anims.has(&"idle") and int(sprite.anims[&"idle"]["count"]) == 5 and sprite.anims.has(&"still"), "one rotation row; idle is the five-frame ember loop, still is the drawn rotation")
	check(absf(sprite.pixel_size * 103.0 - 1.9) < 0.01, "103 drawn px stand 1.9 m")
	check(not SpriteLibrary.apply_prop(sprite, "prp_u0_nothing_here"), "apply_prop reports a missing prop")
	var p: PropBillboard = PropBillboard.make(&"prp_u0_hearth")
	root.add_child(p)
	_track(p)
	check(not p.placeholder and p.sprite != null and p.body != null, "a delivered solid prop gets its sprite and a collision body")
	check(p.footprint.x > 1.5 and p.footprint.x < 1.9 and absf(p.footprint.y - 1.9) < 0.001, "the collision box is sized from the drawn width (%s)" % str(p.footprint))
	var loose: PropBillboard = PropBillboard.make(&"prp_u0_bekkler_doll")
	root.add_child(loose)
	_track(loose)
	check(loose.body == null and absf(loose.y_offset - 0.9) < 0.001, "a prop declared not solid has no body; its y_offset comes from data")
	var pending: PropBillboard = PropBillboard.make(&"prp_u0_klein_journal")
	root.add_child(pending)
	_track(pending)
	check(pending.placeholder and pending.get_node_or_null("Placeholder") != null and pending.get_node_or_null("Label") != null, "a pending prop stands in as a labelled box")
	var unknown: PropBillboard = PropBillboard.make(&"prp_u0_not_a_prop")
	root.add_child(unknown)
	_track(unknown)
	check(unknown.placeholder and unknown.body != null and absf(unknown.footprint.y - 1.0) < 0.001, "an unknown key falls back to a 1 m labelled box with collision")


## A prop's collision follows its data footprint: "posts" frames a walkable opening, a list of boxes
## draws a gate as posts plus grille, and both forms validate (Data and lint).
func test_prop_footprints_posts_and_boxes() -> void:
	var arch: PropBillboard = PropBillboard.make(&"prp_u0_brass_gate_arch")
	root.add_child(arch)
	_track(arch)
	check(arch.body != null and arch.body.get_child_count() == 2, "the gate arch's collision is its two posts")
	if arch.body != null and arch.body.get_child_count() == 2:
		var l: CollisionShape3D = arch.body.get_child(0)
		var r: CollisionShape3D = arch.body.get_child(1)
		var w: float = (l.shape as BoxShape3D).size.x
		check(w < arch.footprint.x * 0.3 and absf(l.position.x) > 1.0, "posts are narrow and stand at the drawn ends (%s wide at x %.2f)" % [str(w), l.position.x])
		check((r.position.x - w * 0.5) - (l.position.x + w * 0.5) > 1.5, "the opening between them is wider than a party member")
	var gate: PropBillboard = PropBillboard.make(&"prp_u0_portcullis")
	root.add_child(gate)
	_track(gate)
	check(gate.body != null and gate.body.get_child_count() == 3, "the portcullis is two posts and the grille")
	var hearth: PropBillboard = PropBillboard.make(&"prp_u0_hearth")
	root.add_child(hearth)
	_track(hearth)
	check(hearth.body != null and hearth.body.get_child_count() == 1 and absf((hearth.body.get_child(0).shape as BoxShape3D).size.x - hearth.footprint.x) < 0.001, "a plain prop keeps its one measured box")
	check(Data._footprint_ok([1.0, 0.5]) and Data._footprint_ok("posts") and Data._footprint_ok([[0.5, 0.8, -1.0], [0.5, 0.8]]), "the three footprint forms validate")
	check(not Data._footprint_ok("box") and not Data._footprint_ok([1.0]) and not Data._footprint_ok([[1.0]]) and not Data._footprint_ok([]), "and malformed ones do not")


## The victory and defeat stings live under audio/music (mus_stings_<id>.ogg) and resolve there.
func test_audio_stings_resolve() -> void:
	for id in ["victory", "defeat", "overcap"]:
		check(Audio.find_sting(id) != null, "sting %s resolves under audio/music" % id)
	check(Audio.find_sting("nothing") == null, "an unknown sting is null, not a crash")
	check(Audio._find_sfx("music/stings/victory") == null, "the old sfx path never resolved; the scene uses play_sting")


## After a battle the rig returns to the scene's exported pitch (the Atrium's 34°), not a literal 30°;
## the rig's and Location's defaults are the same 30°.
func test_camera_rig_restores_scene_pitch() -> void:
	check_near(HD2DCameraRig.new().pitch_degrees, 30.0, 0.001, "rig default 30°")
	var loc := Location.new()
	check_near(loc.camera_pitch, 30.0, 0.001, "Location default 30°")
	loc.free()
	var rig := HD2DCameraRig.new()
	rig.auto_follow = false
	rig.pitch_degrees = 34.0
	root.add_child(rig)
	_track(rig)
	rig.enter_battle(Vector3.ZERO)
	for i in 300:
		rig.step(1.0 / 60.0)
	check_near(rig.pitch_degrees, CombatConstants.TACTICAL_PITCH_DEG, 0.5, "35° in battle")
	rig.exit_battle()
	for i in 300:
		rig.step(1.0 / 60.0)
	check_near(rig.pitch_degrees, 34.0, 0.5, "back to the scene's own pitch after the battle")
	rig.set_explore_pitch(22.0)
	for i in 300:
		rig.step(1.0 / 60.0)
	check_near(rig.pitch_degrees, 22.0, 0.5, "set_explore_pitch retargets it")
