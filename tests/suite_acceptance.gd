## Combat Laws Bible §18.7 acceptance checks the fixtures can reach, as behaviour (audit cluster "tests_acceptance"):
## #5 a Break stops the body, its gauge and its navigation; #7 the rebuild's timing and the body's 0.4 s resume; #8
## HOLD's lock and its charge; #9 the statue's 8 s and its 112% hull; #13 Boost power, shape, the Lv2 debuff and the
## Lv4 field; #14 Rewind's HP, gauge and position; #20 Mercury SLOW; #22 Glenn's steal through the command; #23 every
## technique's plate preview against the plates its cast leaves. Then a boss's HP-window phase change through an
## attack (and one that waits for the Break), a refused technique in the battle scene, and EnemyDef's data rules.
## #25 lives in suite_engine_saves (the defeat's -5 and the siege) and suite_core (no Game Over).
extends "res://tests/suite_base.gd"

const ARENA := "res://scenes/test/arena.tscn"
const DT := 1.0 / 60.0

var _test_bosses: Array[StringName] = []


func _cleanup() -> void:
	for id in _test_bosses:
		Data.bosses.erase(id)
	_test_bosses.clear()
	Engine.time_scale = 1.0
	super._cleanup()


# ---------------------------------------------------------------- fixtures

func _arena(ids: Array[StringName], learn: Dictionary = {}) -> Location:
	Game.new_game()
	Game.set_party(ids)
	for who in learn.keys():
		Game.learn_tech(who, learn[who])
	var loc: Location = (load(ARENA) as PackedScene).instantiate()
	root.add_child(loc)
	_track(loc)
	loc.place_party(&"start")
	await get_tree().process_frame
	return loc


## The arena zone's fight, the clock driven by hand.
func _zone_battle(loc: Location) -> BattleScene:
	var z: EncounterZone = loc.zones[0]
	z.active = false
	loc._on_zone_triggered(z, "normal")
	loc.battle.coordinator.auto_tick = false
	return loc.battle


func _end(loc: Location, victory: bool) -> bool:
	if loc.battle != null:
		loc.battle.coordinator.force_end(victory)
	Engine.time_scale = 4.0
	var t: float = 0.0
	while loc.battle != null and t < 8.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	await get_tree().process_frame
	Engine.time_scale = 1.0
	return loc.battle == null


## Guard every other window until `actor` has the floor.
func _window_for(c: BattleCoordinator, actor: Node, max_s: float = 60.0) -> bool:
	var t: float = 0.0
	while t < max_s and c.state != BattleCoordinator.State.IDLE:
		var a: Node = _advance_until_window(c, max_s - t)
		if a == null:
			return false
		if a == actor:
			return true
		c.cmd_guard(a)
		t += 0.5
	return false


## Run `seconds` of battle time, guarding every window that opens.
func _run_battle_time(c: BattleCoordinator, seconds: float) -> void:
	var t0: float = c.battle_time
	var guard: int = 0
	while c.battle_time - t0 < seconds - 0.0001 and guard < 200000:
		guard += 1
		if c.state == BattleCoordinator.State.COMMAND_WAIT and c.active_actor != null:
			c.cmd_guard(c.active_actor)
		elif c.state == BattleCoordinator.State.TICK:
			c.advance(DT)
		else:
			return


func _tough(a: Node) -> void:
	var st := CombatantStats.of(a)
	st.base_max_hp = 99999
	st.hp = 99999


func _phase(id: String, hp_from: float, hp_to: float, shield: int, weak: Array) -> Dictionary:
	return {
		"id": id, "name": id.capitalize(), "hp_from": hp_from, "hp_to": hp_to, "tags": ["BLUNT"],
		"shield": {"shield": shield, "weak": weak},
		"actions": [{"id": "tap", "name": "Tap", "tags": ["BLUNT"], "shape": "SINGLE", "power": 0.1, "hits": 1, "target": "random", "weight": 1}],
	}


func _boss(id: String, phases: Array) -> StringName:
	Data.bosses[StringName(id)] = {
		"id": id, "name": id.capitalize(), "universe": 0, "level": 3, "hp": 20000, "kind": "boss", "size": 1.5,
		"body_radius": 0.6, "tags": ["BLUNT"], "adds": [], "branches": [], "drops": [], "phases": phases,
	}
	_test_bosses.append(StringName(id))
	return StringName(id)


func _boss_fight(loc: Location, boss_id: StringName) -> BattleScene:
	loc._on_story_battle(&"", {"boss_id": String(boss_id), "boss": true, "at": "boss", "center": "center"})
	loc.battle.coordinator.auto_tick = false
	return loc.battle


func _hull_radius(a: CombatActor) -> float:
	return ((a.break_hull.get_child(0) as CollisionShape3D).shape as CylinderShape3D).radius


# ---------------------------------------------------------------- #5, #7, #9: the Break on the body

## #5: at shield 0 the target Breaks at once: it cannot act, its gauge is 0 and frozen, its body stops (velocity
## zero, avoidance off, no headway over physics frames), and the strikes after it in the same action see it Broken.
func test_check_5_a_break_stops_the_body_its_gauge_and_its_navigation() -> void:
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	_tough(crono)
	crono.stats.weapon_tags = [&"SWORD"]
	crono.stats.weapon_hits = 3
	var e: CombatActor = c.enemies[0] as CombatActor
	e.shield.configure({"shield": 1, "weak": ["SWORD"]})
	e.nav.avoidance_enabled = true  # as if it were walking with avoidance on
	e.velocity = Vector3(1.5, 0.0, 0.0)
	check(_window_for(c, crono), "Crono gets a window")
	var strikes: Array = []
	c.strike_resolved.connect(func(_a: Node, t: Node, info: Dictionary) -> void:
		if t == e:
			strikes.append(info))
	c.cmd_attack(crono, e, 0)
	check_eq(strikes.size(), 3, "three strikes resolved on it")
	check(bool(strikes[0].get("break", false)), "the first strike takes the last plate and Breaks it")
	check(bool(strikes[1].get("crit", false)) and bool(strikes[2].get("crit", false)), "the later strikes of the same action see it Broken (criticals)")
	check(e.shield.is_broken and not e.shield.can_act(), "Broken: it cannot act")
	check_eq(c.get_gauge(e), 0.0, "its gauge is 0")
	check(e.frozen and e.velocity == Vector3.ZERO, "its body is frozen with zero velocity")
	check(not e.nav.avoidance_enabled, "and its NavigationAgent's avoidance is off")
	var acted: Array = []
	c.enemy_action_started.connect(func(en: Node, _a: Dictionary) -> void: acted.append(en))
	var at: Vector3 = e.global_position
	_run_battle_time(c, 2.0)
	for i in 4:
		await get_tree().physics_frame
	check_eq(c.get_gauge(e), 0.0, "its gauge stays frozen at 0 for the Break")
	check(not acted.has(e), "and it takes no action")
	check(e.velocity == Vector3.ZERO and e.global_position.distance_to(at) < 0.001, "the frozen body makes no headway")
	check(await _end(loc, true), "the battle ends")
	Game.new_game()


## #7: the rebuild cannot begin before 3.0 s of battle time (a window held open does not count), then fills at 18%
## of max per second; the Break ends only at 100% (about 8.56 s), and the body stays still for the 0.4 s blend.
func test_check_7_rebuild_waits_three_seconds_and_the_body_resumes_after_the_blend() -> void:
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	_tough(crono)
	var e: CombatActor = c.enemies[0] as CombatActor
	check(_window_for(c, crono), "Crono gets a window")
	e.shield.force_break(crono)
	var t0: float = c.battle_time
	var recovered_at: Array = []
	c.unit_recovered.connect(func(u: Node) -> void:
		if u == e:
			recovered_at.append(c.battle_time))
	for i in 120:
		c.advance(DT)  # the window is open: battle time stands still (§3.4)
	check_eq(c.battle_time, t0, "no battle time passes while Crono's window is open")
	check_near(e.shield.lock_left, CombatConstants.BREAK_LOCK_S, 0.001, "so the lock has not moved")
	c.cmd_guard(crono)
	_run_battle_time(c, 2.9)
	check(e.shield.is_broken and e.shield.rebuild_pct == 0.0, "no rebuild before 3.0 s of battle time")
	_run_battle_time(c, 1.1)
	check_near(e.shield.rebuild_pct, CombatConstants.SHIELD_REBUILD_PCT_PER_S, 0.6, "then 18% of max per second")
	_run_battle_time(c, 4.4)
	check(e.shield.is_broken and recovered_at.is_empty(), "still Broken short of 100%")
	_run_battle_time(c, 0.3)
	check_eq(recovered_at.size(), 1, "the Break ends once the bar is full")
	check_near(float(recovered_at[0]) - t0, CombatConstants.BREAK_LOCK_S + 100.0 / CombatConstants.SHIELD_REBUILD_PCT_PER_S, 0.04, "3.0 s + 100/18 s of battle time after the Break")
	check(not e.frozen and not e.break_hull.visible, "the body is unfrozen and its hull is down")
	check_eq(e.shield.current_shield, e.shield.max_total(), "with its plates back")
	# the 0.4 s blend: no gauge, no action, then the clock takes it again
	var g_rec: float = c.get_gauge(e)
	check_near(e.shield.resume_left, CombatConstants.BREAK_RESUME_BLEND_S - (c.battle_time - float(recovered_at[0])), 0.02, "the 0.4 s resume blend runs")
	check(not e.shield.can_act(), "it cannot act during the blend")
	_run_battle_time(c, 0.2)
	check_eq(c.get_gauge(e), g_rec, "its gauge does not fill during the blend")
	_run_battle_time(c, 0.4)
	check(e.shield.can_act() and c.get_gauge(e) > g_rec, "after it the gauge fills again")
	check(await _end(loc, true), "the battle ends")
	Game.new_game()


## #9: a target killed while Broken stays 8 s of battle time as a statue with the 112% hull, and the cover the
## coordinator gives LINE_PIERCE is the same 112% hull.
func test_check_9_a_broken_kill_stands_eight_seconds_with_the_112_percent_hull() -> void:
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	_tough(crono)
	var e: CombatActor = c.enemies[0] as CombatActor
	var r_body: float = e.stats.body_radius
	check_near(_hull_radius(e), r_body * (1.0 + CombatConstants.BREAK_HULL_INFLATION), 0.0001, "the Break hull is 112% of the body radius")
	e.shield.force_break(crono)
	e.stats.apply_damage(999999, true)
	check(e.statue and e.visible and e.break_hull.visible, "killed while Broken: a statue with its hull up")
	var cover: Array = c._blockers().filter(func(b: Dictionary) -> bool: return (b["pos"] as Vector3).distance_to(c.position_of(e)) < 0.001)
	check_eq(cover.size(), 1, "the statue is LINE_PIERCE cover")
	check(not cover.is_empty() and absf(float(cover[0]["radius"]) - _hull_radius(e)) < 0.0001, "with the same 112% hull as the body's")
	_run_battle_time(c, 7.9)
	check(e.statue and e.visible, "still standing at 7.9 s")
	_run_battle_time(c, 0.2)
	check(not e.statue and not e.visible, "gone at 8 s")
	check(await _end(loc, true), "the battle ends")
	Game.new_game()


# ---------------------------------------------------------------- #8 HOLD, #13 Boost, #14 Rewind, #20 SLOW, #22 steal

## #8: HOLD adds exactly 2.5 s of lock per 5% solidity and charges it: the Break ends 2.5 s of battle time later.
func test_check_8_hold_adds_two_and_a_half_seconds_per_five_percent_and_charges_it() -> void:
	var c := _coord()
	var sera := _party_member(&"sera", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 100000})
	_start(c, [sera], [e])
	_tough(sera)
	check(_advance_until_window(c) == sera, "Sera's window")
	var sh := ShieldComponent.of(e)
	sh.force_break(sera)
	var t0: float = c.battle_time
	var sol := SolidityComponent.of(sera)
	var s0: float = sol.solidity
	var r: Dictionary = c.cmd_tech(sera, &"hold", e, c.position_of(e), 0)
	check(bool(r.get("ok", false)), "HOLD on the Broken enemy")
	check_near(sh.lock_left, CombatConstants.BREAK_LOCK_S + CombatConstants.SERA_HOLD_BREAK_EXTENSION_S, 0.0001, "exactly +2.5 s of lock")
	check_near(s0 - sol.solidity, CombatConstants.SERA_HOLD_STEP, 0.0001, "for exactly 5% solidity (no regen on a TACHYON turn)")
	var at: Array = []
	c.unit_recovered.connect(func(u: Node) -> void: at.append(c.battle_time))
	_run_battle_time(c, 12.0)
	check_eq(at.size(), 1, "the Break ends once")
	check(not at.is_empty() and absf(float(at[0]) - t0 - (3.0 + 2.5 + 100.0 / 18.0)) < 0.04, "3.0 + 2.5 + 100/18 s after the Break (got %s)" % str(float(at[0]) - t0 if not at.is_empty() else -1.0))


## #13: Boost power follows 100/190/280/370/450% and shape scale 1.00/1.25/1.50/1.75/2.00; a technique at Lv2 adds
## its element's debuff, at Lv4 it leaves its residual field for 6 s; Lv1 adds neither.
func test_check_13_boost_scales_power_and_shape_lv2_debuffs_lv4_leaves_a_field() -> void:
	check_eq(str(CombatConstants.BOOST_POWER), str([1.0, 1.9, 2.8, 3.7, 4.5]), "the power table")
	check_eq(str(CombatConstants.BOOST_SCALE), str([1.0, 1.25, 1.5, 1.75, 2.0]), "the shape table")
	var c := _coord()
	var crono := _party_member(&"crono", 60, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 5, Vector3(0, 0, 0), 30, ["ICE"], {"hp": 1000000})
	var far := _enemy(&"far", 5, Vector3(4.2, 0, 0), 30, ["ICE"], {"hp": 1000000})
	_start(c, [crono], [e, far], {"max_bp": 9, "max_spend": 4})
	_tough(crono)
	check(_advance_until_window(c) == crono, "Crono's window")
	# a plain Attack (no ASTRAL displacement on top) against a non-weak body
	var d0: float = float(c.preview(crono, null, e, c.position_of(e), 0)[e]["damage"])
	for b in [1, 2]:
		var d: float = float(c.preview(crono, null, e, c.position_of(e), b)[e]["damage"])
		check_near(d / d0, CombatConstants.BOOST_POWER[b], 0.01, "Lv%d hits for %d%% (non-weak, so no Lv3 state)" % [b, roundi(CombatConstants.BOOST_POWER[b] * 100.0)])
	var d3: float = float(c.preview(crono, null, e, c.position_of(e), 3)[e]["damage"])
	var d4: float = float(c.preview(crono, null, e, c.position_of(e), 4)[e]["damage"])
	check_near(d3 / d0, CombatConstants.BOOST_POWER[3] * CombatConstants.STATE_LV3, 0.01, "Lv3: 280% with the 1.3 Lv3 state")
	check_near(d4 / d0, CombatConstants.BOOST_POWER[4] * CombatConstants.STATE_LV3, 0.01, "Lv4: 370% with it")
	var slash: TechDef = c.tech_library[&"astral_slash"]
	check(not c.preview(crono, slash, e, c.position_of(e), 0).has(far), "Astral Slash's cone (6.05 m) stops short of the far enemy at Lv0")
	check(c.preview(crono, slash, e, c.position_of(e), 2).has(far), "and reaches it at Lv2 (x1.5)")
	c.bank.bp = 1
	c.cmd_tech(crono, &"time_slice", e, c.position_of(e), 1)
	check(StatusComponent.of(e).ids().is_empty() and c.fields.fields.is_empty(), "Lv1: no debuff, no field")
	check(_advance_until_window(c) == crono, "Crono's next window")
	c.bank.bp = 2
	c.cmd_tech(crono, &"time_slice", e, c.position_of(e), 2)
	check(StatusComponent.of(e).has(TechEffects.default_lv2(&"ASTRAL")), "Lv2 adds the ASTRAL debuff (Displaced)")
	check(c.fields.fields.is_empty(), "and no field")
	check(_advance_until_window(c) == crono, "and his next window")
	c.bank.bp = 4
	c.cmd_tech(crono, &"time_slice", e, c.position_of(e), 4)
	var kinds: Array = c.fields.fields.map(func(f: Dictionary) -> StringName: return f["kind"])
	check_eq(str(kinds), str([BattleFields.default_field_for(&"ASTRAL")]), "Lv4 leaves the ASTRAL residual field (watercolour puddle)")
	check(not c.fields.fields.is_empty() and (c.fields.fields[0]["center"] as Vector3).distance_to(c.position_of(e)) < 0.001, "under the target")
	_run_battle_time(c, CombatConstants.RESIDUAL_FIELD_S + 0.1)
	check(c.fields.fields.filter(func(f: Dictionary) -> bool: return f["kind"] == BattleFields.default_field_for(&"ASTRAL")).is_empty(), "and it lasts 6 s of battle time")


## #14 (GAP3-6): Rewind always charges 5% solidity and restores HP, gauge and position to the target's last turn
## start, and drops what it gained since. The turn start is the moment its turn began (DECISIONS "Rewind's turn
## start": the window, the gauge at the gate), so a Rewound ally's turn comes round again; a parked ally is still at
## the gate and keeps its place in the Ready Pool.
func test_check_14_rewind_restores_hp_gauge_and_position_to_the_turn_start() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var sera := _party_member(&"sera", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 3, ["FIRE"], {"hp": 100000})
	_start(c, [crono, sera], [e])
	var sc := StatusComponent.of(crono)
	sc.add(&"ward", -1.0, -1)  # held at his turn start
	check(_advance_until_actor(c, &"crono") == crono, "Crono's turn")
	var hp0: int = CombatantStats.of(crono).hp
	var pos0: Vector3 = c.position_of(crono)
	var snap: Dictionary = c.turn_snapshots.get(crono, {})
	check_near(float(snap.get("gauge", -1.0)), CombatConstants.SYNC_HOLD, 0.001, "his turn start is recorded with the gauge at the gate")
	check(bool(c.cmd_move(crono, pos0 + Vector3(-2, 0, 2)).get("ok", false)), "he moves")
	c.cmd_guard(crono)
	CombatantStats.of(crono).apply_damage(50, true)
	sc.add(&"displaced", -1.0, 2)  # gained after his turn start
	check(_advance_until_actor(c, &"sera") == sera, "Sera's turn")
	check(c.get_gauge(crono) < CombatConstants.SYNC_HOLD and c.position_of(crono).distance_to(pos0) > 1.0, "he has moved and his gauge is mid-way")
	var sol := SolidityComponent.of(sera)
	var s0: float = sol.solidity
	check(bool(c.cmd_tech(sera, &"rewind", crono, Vector3.ZERO, 0).get("ok", false)), "Rewind on Crono")
	check_near(s0 - sol.solidity, CombatConstants.SERA_REWIND_COST, 0.001, "5% solidity")
	check_eq(CombatantStats.of(crono).hp, hp0, "HP back to his turn start")
	check(c.position_of(crono).distance_to(pos0) < 0.001 and crono.global_position.distance_to(pos0) < 0.001, "position back to his turn start")
	check_near(c.get_gauge(crono), float(snap["gauge"]), 0.001, "gauge back to his turn start")
	check(sc.has(&"ward") and not sc.has(&"displaced"), "what he gained since is gone, what he had stays")
	check(_advance_until_window(c, 0.1) == crono, "his turn comes round again at once")
	# a parked ally is already at the gate
	c.cmd_sync_hold(crono)
	check(c.ready_pool.has(crono), "Crono parks at 99")
	check(_advance_until_window(c) == sera, "Sera relieves him")
	CombatantStats.of(crono).apply_damage(40, true)
	c.cmd_tech(sera, &"rewind", crono, Vector3.ZERO, 0)
	check(c.ready_pool.has(crono), "the parked ally keeps his place in the Ready Pool")
	check_near(c.get_gauge(crono), CombatConstants.SYNC_HOLD, 0.001, "and his gauge at the gate, which is his turn start")
	check_eq(CombatantStats.of(crono).hp, int(c.turn_snapshots[crono]["hp"]), "his HP is still restored")


## #20: Mercury SLOW halves gauge fill and movement and stacks to 2 at most (a second stack never slows further).
func test_check_20_mercury_slow_halves_gauge_and_move_and_stacks_to_two() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(5, 0, 5), 4, ["ICE"], {"hp": 50000})
	_start(c, [crono], [e])
	StatusComponent.of(e).add(&"time_stop", 60.0)
	check_eq(c.state, BattleCoordinator.State.TICK, "the clock runs")
	var f0: float = c._fill(crono, 0.1)
	var sc := StatusComponent.of(crono)
	sc.add(&"mercury_slow", 30.0)
	check_near(c._fill(crono, 0.1), f0 * 0.5, 0.0001, "one stack halves the gauge fill")
	sc.add(&"mercury_slow", 30.0)
	sc.add(&"mercury_slow", 30.0)
	check_eq(sc.stacks(&"mercury_slow"), CombatConstants.MERCURY_MAX_STACKS, "three applications stack to 2")
	check_near(c._fill(crono, 0.1), f0 * 0.5, 0.0001, "and two stacks still halve it, no more")
	var g0: float = c.get_gauge(crono)
	c.advance(DT)
	check_near(c.get_gauge(crono) - g0, c._fill(crono, DT), 0.0001, "the timeline fills his gauge at that rate")
	check(_advance_until_window(c) == crono, "Crono's window")
	var from: Vector3 = c.position_of(crono)
	c.cmd_move(crono, from + Vector3(0, 0, 9))
	check_near(c.position_of(crono).distance_to(from), CombatantStats.of(crono).move_range * 0.5, 0.01, "and his battle move")


## #22: through the command, one steal takes at most 3 BP from the enemy's counter, and the pool gains exactly what
## the counter loses (no BP is duplicated).
func test_check_22_one_steal_takes_at_most_three_bp_and_duplicates_none() -> void:
	var c := _coord()
	var glenn := _party_member(&"glenn", 44, Vector3(-3, 0, 0))
	var e := _enemy(&"thief", 44, Vector3(3, 0, 0), 9, ["ICE"], {"hp": 500000})
	_start(c, [glenn], [e], {"techs": Data.techs, "max_bp": 9, "max_spend": 4})
	_tough(glenn)
	check(_advance_until_window(c) == glenn, "Glenn's window")
	c.bank.bp = 6
	e.set_meta("stolen_bp", 10)
	var r: Dictionary = c.cmd_tech(glenn, &"sleight_of_arm", e, c.position_of(e), 4)
	check(bool(r.get("ok", false)), "Sleight of Arm at Boost Lv4: %s" % str(r.get("error", "")))
	check_eq(int(r["info"].get("stolen", -1)), 3, "it takes 3 BP, not 4")
	check_eq(int(e.get_meta("stolen_bp")), 7, "the counter loses 3")
	check_eq(c.bank.bp, 6 - 4 + 3, "the pool paid the Boost and gained exactly those 3")


# ---------------------------------------------------------------- #23: every technique's plate preview

## The plate preview of every technique cast by its first actor set, aimed at the first of three bodies weak to all
## its tags (or to nothing), against the plates the cast leaves. Returns {cast, multi, shapes, mismatched, lines}.
func _preview_parity(boost: int, weak: bool) -> Dictionary:
	var out := {"cast": 0, "multi": 0, "shapes": {}, "mismatched": [], "lines": []}
	var ids: Array = Data.techs.keys()
	ids.sort()
	for id in ids:
		var t: TechDef = Data.techs[id]
		if not (t.target in ["enemy", "point", "any"]) or t.requires_broken:
			continue
		var c := _coord()
		var party: Array = []
		for aid in t.actor_sets()[0]:
			var u := _party_member(StringName(aid), 60, Vector3(-1.2, 0, float(party.size()) * 0.9))
			_tough(u)
			party.append(u)
		if CombatantStats.of(party[0]).actor_id == &"crono":
			CombatantStats.of(party[0]).hp = 40000  # under 60%: the Crono-hurt rows are castable
		var bodies: Array = []
		for p in [Vector3(0.8, 0, 0), Vector3(1.6, 0, 0.5), Vector3(1.4, 0, -0.6)]:
			bodies.append(_enemy(&"body", 40, p, 40, Array(t.tags) if weak else [], {"hp": 9000000}))
		_start(c, party, bodies, {"techs": Data.techs, "max_bp": 9})
		for b in bodies:
			StatusComponent.of(b).add(&"time_stop", 600.0)
		for i in range(1, party.size()):
			c._open_window(party[i], false)  # partners wait in the Ready Pool
		c._open_window(party[0], false)
		c.bank.bp = 9
		for u in party:
			CombatantStats.of(u).mp = 9999
		var partners: Array = party.slice(1)
		var p: Dictionary = c.preview(party[0], t, bodies[0], c.position_of(bodies[0]), boost, partners)
		var before: Dictionary = {}
		for b in bodies:
			before[b] = ShieldComponent.of(b).current_shield
		var r: Dictionary = c.cmd_tech(party[0], id, bodies[0], c.position_of(bodies[0]), boost, partners)
		if bool(r.get("ok", false)):
			out["cast"] = int(out["cast"]) + 1
			out["shapes"][t.shape] = true
			if p.size() >= 2:
				out["multi"] = int(out["multi"]) + 1
			for b in bodies:
				var sh := ShieldComponent.of(b)
				var want: int = int(p[b]["after"]) if p.has(b) else int(before[b])
				var breaks: bool = bool(p[b]["breaks"]) if p.has(b) else false
				if want != sh.current_shield or breaks != sh.is_broken:
					if not (out["mismatched"] as Array).has(String(id)):
						out["mismatched"].append(String(id))
					out["lines"].append("%s: plate said %d%s, cast left %d%s" % [id, want, " BREAK" if breaks else "", sh.current_shield, " BREAK" if sh.is_broken else ""])
		for n in party + bodies + [c]:
			n.free()
	return out


## #23: the shield preview equals the shave the hit then does, for every technique and shape: every technique in
## data/techs aimed at enemies, cast by its actors (partners from the Ready Pool) at three bodies weak to its tags
## and at three weak to nothing, at Boost Lv0 and Lv3; at least 60 casts catch two or more bodies, every enemy
## shape is cast, and the plates after the cast are the plates the preview showed (its after-effects included).
func test_check_23_every_technique_previews_the_plates_its_cast_leaves() -> void:
	var snap: Dictionary = Flags.to_save().duplicate(true)
	for boost in [0, 3]:
		for weak in [true, false]:
			var r: Dictionary = _preview_parity(boost, weak)
			var tag: String = "Boost Lv%d, bodies %s" % [boost, "weak to its tags" if weak else "weak to nothing"]
			check(int(r["cast"]) >= 85, "%s: %d techniques cast" % [tag, int(r["cast"])])
			check(int(r["multi"]) >= 60, "%s: %d casts caught two or more bodies" % [tag, int(r["multi"])])
			var shapes: Array = (r["shapes"] as Dictionary).keys()
			shapes.sort()
			check_eq(str(shapes), str([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11]), "%s: every enemy shape was cast (all but PARTY)" % tag)
			check_eq(str(r["mismatched"]), "[]", "%s: every plate preview equals what the cast leaves (%s)" % [tag, "; ".join(PackedStringArray(r["lines"]))])
	Flags.from_save(snap)
	Game.new_game()


## CastReach.strikes reads TechEffects.STRIKING for the bespoke handlers: it must name exactly the handlers whose
## code resolves hits (_merge_damage), so a new striking handler cannot silently lose its preview.
func test_striking_handlers_are_the_ones_that_resolve_hits() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/combat/tech_effects.gd")
	var body: String = src.substr(src.find("\tmatch tech.effect:"), src.find("\nstatic func", src.find("\tmatch tech.effect:")) - src.find("\tmatch tech.effect:"))
	var head := RegEx.create_from_string("(?m)^\\t\\t(&\"[a-z_0-9]+\"(?:, &\"[a-z_0-9]+\")*):$")
	var striking: Array[String] = []
	var arms: Array[RegExMatch] = head.search_all(body)
	for i in arms.size():
		var stop: int = arms[i + 1].get_start() if i + 1 < arms.size() else body.length()
		var block: String = body.substr(arms[i].get_end(), stop - arms[i].get_end())
		if block.contains("_merge_damage("):
			for n in arms[i].get_string(1).split(", "):
				striking.append(n.trim_prefix("&\"").trim_suffix("\""))
	striking.sort()
	var listed: Array[String] = []
	for n in TechEffects.STRIKING:
		listed.append(String(n))
	listed.sort()
	check(arms.size() >= 30, "the handler arms were read (%d)" % arms.size())
	check_eq(",".join(listed), ",".join(striking), "TechEffects.STRIKING names exactly the handlers that resolve hits")
	check(not CastReach.strikes(Data.techs[&"rewind"]) and not CastReach.strikes(Data.techs[&"miura_fold"]), "Rewind and Miura Fold strike nothing")
	check(CastReach.strikes(Data.techs[&"tachyon_needle"]) and CastReach.strikes(null), "the Needle and a plain Attack do")


# ---------------------------------------------------------------- boss phases and the battle scene

## A two-phase test boss split at 50% (phase one: `plates` weak to SWORD; phase two: 5 weak to FIRE), Crono at his
## window with a one-strike `weapon`, and the boss at one HP above the window. Returns the scene.
func _window_fight(id: String, plates: int, weapon: StringName) -> BattleScene:
	var bid := _boss(id, [_phase("one", 1.0, 0.5, plates, ["SWORD"]), _phase("two", 0.5, 0.0, 5, ["FIRE"])])
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _boss_fight(loc, bid)
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	_tough(crono)
	crono.stats.weapon_tags = [weapon]
	crono.stats.weapon_hits = 1
	check(_window_for(scene.coordinator, crono), "Crono gets a window")
	var st := CombatantStats.of(scene.boss.actor)
	st.hp = st.max_hp() / 2 + 1
	return scene


func _await_phase(ctrl: BossController, i: int) -> void:
	for n in 30:
		await get_tree().process_frame
		if not ctrl.transitioning and ctrl.phase_index == i:
			return


## BATTLE-21: an attack that takes the boss past its HP window changes the phase once the action has resolved, to
## the next phase's plates and weakness.
func test_an_attack_across_an_hp_window_changes_the_phase_after_the_action() -> void:
	var scene: BattleScene = await _window_fight("acc_window", 3, &"ICE")
	var c: BattleCoordinator = scene.coordinator
	var ctrl: BossController = scene.boss
	var crono: Node = c.unit_by_id(&"crono")
	var order: Array[String] = []
	c.strike_resolved.connect(func(a: Node, _t: Node, _i: Dictionary) -> void:
		if a == crono:
			order.append("hit"))
	ctrl.phase_changed.connect(func(i: int, _p: Dictionary) -> void: order.append("phase %d" % i))
	c.cmd_attack(crono, ctrl.actor, 0)
	check(ctrl.actor.stats.hp_ratio() < 0.5, "the attack takes it past 50%")
	await _await_phase(ctrl, 1)
	check_eq(ctrl.phase_index, 1, "the next phase begins")
	check_eq(",".join(order), "hit,phase 1", "after the action resolved")
	check(ctrl.actor.shield.max_shield == 5 and ctrl.actor.shield.weaknesses.has(&"FIRE"), "with its own plates and weakness")
	check(await _end(scene.get_parent() as Location, true), "the battle ends")
	Game.new_game()


## BATTLE-21 / BATTLE-2: the same window crossed by the strike that Breaks the boss waits for the Break to play out
## on the old plates (§14.1); the next phase begins when the boss recovers.
func test_a_window_crossed_by_the_breaking_strike_waits_for_the_break() -> void:
	var scene: BattleScene = await _window_fight("acc_window_break", 1, &"SWORD")
	var c: BattleCoordinator = scene.coordinator
	var ctrl: BossController = scene.boss
	c.cmd_attack(c.unit_by_id(&"crono"), ctrl.actor, 0)
	check(ctrl.actor.shield.is_broken and ctrl.actor.stats.hp_ratio() < 0.5, "one strike Breaks it and crosses the window")
	for i in 10:
		await get_tree().process_frame
	check_eq(ctrl.phase_index, 0, "the phase waits while the Break plays out")
	check_eq(ctrl.actor.shield.max_shield, 1, "on the old plates")
	_run_battle_time(c, 9.0)
	check(not ctrl.actor.shield.is_broken, "the Break played out")
	await _await_phase(ctrl, 1)
	check_eq(ctrl.phase_index, 1, "phase two begins when the boss recovers")
	check_eq(ctrl.actor.shield.max_shield, 5, "with its own plates")
	check(await _end(scene.get_parent() as Location, true), "the battle ends")
	Game.new_game()


## BATTLE-21 / BATTLE-1: a single-target technique confirmed on an enemy that turned untargetable is refused before
## anything is paid; the window stays Crono's and his deck comes back.
func test_a_refused_technique_reopens_the_deck_and_costs_nothing() -> void:
	var loc: Location = await _arena([&"crono"], {&"crono": &"time_slice"})
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	_tough(crono)
	var hidden: Node = c.enemies[0]
	check(_window_for(c, crono), "Crono's window")
	var slice: TechDef = Data.techs[&"time_slice"]
	check(c.available_techs(crono).has(slice), "he knows Time Slice")
	scene._on_deck_command("tech", {"tech": slice})
	check_eq(scene.mode, BattleScene.Mode.TARGET, "the technique opens the aim")
	StatusComponent.of(hidden).add(&"untargetable", -1.0, -1)
	scene.target_list = [hidden]  # it turned untargetable while he aimed
	scene.target_index = 0
	var strain0: float = crono.time_debt.battle_strain
	var bp0: int = c.bank.bp
	scene._confirm_target()
	check(c.state == BattleCoordinator.State.COMMAND_WAIT and c.active_actor == crono, "the refused technique leaves Crono's window open")
	check_eq(scene.mode, BattleScene.Mode.DECK, "his deck is back up")
	check(scene.hud.deck_open, "visibly")
	check_near(crono.time_debt.battle_strain, strain0, 0.0001, "no Battle Strain was paid")
	check_eq(c.bank.bp, bp0, "and no BP")
	check(await _end(loc, true), "the battle ends")
	Game.new_game()


# ---------------------------------------------------------------- DATA-22: EnemyDef's data rules

## EnemyDef's defaults, its metal rule, the plate config it hands the shield and the mistakes it refuses.
func test_enemy_defs_default_merge_and_refuse_mistakes() -> void:
	var bare := EnemyDef.from_dict({"key": "bare"})
	check(bare.level == 1 and bare.kind == "regular" and bare.shield == 1 and bare.body_radius == 0.5 and bare.fps == 60.0, "defaults: Lv1 regular, 1 plate, 0.5 m, 60 fps")
	check(bare.validation_errors().is_empty(), "a bare enemy validates")
	check(EnemyDef.from_dict({"key": "m", "tags": ["FERRO"]}).is_metal and EnemyDef.from_dict({"key": "g", "tags": ["GUN"]}).is_metal, "FERRO and GUN bodies are metal")
	check(not EnemyDef.from_dict({"key": "f", "tags": ["FERRO"], "is_metal": false}).is_metal, "unless the row says otherwise")
	var keyed := EnemyDef.from_dict({"key": "k", "shield": 3, "weak": ["SWORD"], "keyed_plates": [{"key": "SWORD", "weight": 2}, {"key": "FIRE"}], "plate_rules": {"regenerating": true}})
	var cfg: Dictionary = keyed.shield_config()
	check(cfg["weak"] == keyed.weak and (cfg["keyed_plates"] as Array).size() == 2, "the shield config carries the weaknesses and keyed plates")
	check(bool(cfg.get("regenerating", false)), "plate_rules merge into it")
	check(keyed.validation_errors().is_empty(), "keyed weights 2 + 1 = shield 3 validates")
	var errs: String = " | ".join(EnemyDef.from_dict({"tags": ["BANANA"], "shield": -1, "actions": [{"id": "a", "tags": ["NOPE"]}]}).validation_errors())
	check(errs.contains("enemy without key"), "a row without a key is refused")
	check(errs.contains("unknown tag BANANA") and errs.contains("action a has unknown tag NOPE"), "unknown tags on the body and its actions are refused")
	check(errs.contains("negative shield"), "a negative shield is refused")
	var heavy: String = " ".join(EnemyDef.from_dict({"key": "h", "shield": 2, "keyed_plates": [{"key": "SWORD", "weight": 3}]}).validation_errors())
	check(heavy.contains("shield 2 but its keyed plates weigh 3"), "keyed plates that disagree with the shield are refused")
	var shipped: PackedStringArray = []
	for err in Data.errors:
		if err.contains("keyed plates weigh"):
			shipped.append(err)
	check(shipped.is_empty(), "and no shipped enemy disagrees (%s)" % " | ".join(shipped))
