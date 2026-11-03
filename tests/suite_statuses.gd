## Statuses, shields and the enemy brain (Combat Laws Bible §5.7, §6.3, §7.3, §7.5, §9.3, §12; acceptance §18.7
## #18, #20, #21, #22, #23): Ruin's ceiling and cap, the four Lv2 debuffs and their readers, the periodic ticks,
## party accuracy and the shave penalties, the three special shield rules, Jammed enemies, NULL's strip expiring,
## the cleanse keep-list, the boss status rules and Glenn's steals; Silence and Knock-Static on enemies.
extends "res://tests/suite_base.gd"

const ARENA := "res://scenes/test/arena.tscn"

var _test_bosses: Array[StringName] = []


func _cleanup() -> void:
	for id in _test_bosses:
		Data.bosses.erase(id)
	_test_bosses.clear()
	super._cleanup()


func _def(key: String, actions: Array, extra: Dictionary = {}) -> EnemyDef:
	var d: Dictionary = {"key": key, "level": 5, "actions": actions}
	d.merge(extra, true)
	return EnemyDef.from_dict(d)


## One telegraphed action (no evasion roll) that targets `rule`.
func _strike(id: String, rule: String, extra: Dictionary = {}) -> Dictionary:
	var a: Dictionary = {"id": id, "tags": ["BLUNT"], "shape": "SINGLE", "power": 0.01, "hits": 1, "wind_up_s": 0.5, "target": rule}
	a.merge(extra, true)
	return a


## The enemy chooses and the action lands at once.
func _act(c: BattleCoordinator, e: Node) -> Dictionary:
	var def: EnemyDef = c.enemy_defs.get(CombatantStats.of(e).actor_id, null)
	var action: Dictionary = EnemyBrain.choose(c, e, def, c.rng)
	c._execute_enemy_action(e, action)
	return action


## Advance battle time, guarding every party window.
func _run(c: BattleCoordinator, seconds: float, step: float = 1.0 / 30.0) -> void:
	var t: float = 0.0
	while t < seconds and c.state != BattleCoordinator.State.IDLE:
		if c.state == BattleCoordinator.State.COMMAND_WAIT:
			c.cmd_guard(c.active_actor)
			continue
		c.advance(step)
		t += step


func _tough_party(u: Node) -> void:
	var st := CombatantStats.of(u)
	st.base_max_hp = 99999
	st.hp = 99999


func _shield(e: Node, cfg: Dictionary) -> ShieldComponent:
	var sh := ShieldComponent.of(e)
	sh.configure(cfg)
	return sh


# ---------------------------------------------------------------- Ruin (COMBAT-4, GAP3-9)

func test_enemy_ruin_lowers_the_ceiling_and_clears_when_the_battle_ends() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var krona := _party_member(&"krona", 10, Vector3(-3, 0, 2))
	var e := _enemy(&"conduit", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000})
	var e2 := _enemy(&"conduit_b", 10, Vector3(3, 0, 2), 4, ["ICE"], {"hp": 50000})
	_start(c, [crono, krona], [e, e2], {"enemy_defs": {
		&"conduit": _def("conduit", [_strike("void_channel", "crono", {"status": "ruin"})]),
		&"conduit_b": _def("conduit_b", [_strike("void_channel", "krona", {"status": "ruin"})]),
	}})
	CombatantStats.of(crono).luk = 0.0
	CombatantStats.of(krona).luk = 0.0
	var st := CombatantStats.of(crono)
	var td := TimeDebtComponent.of(crono)
	var base: int = st.base_max_hp
	_act(c, e)
	check_eq(td.ruin_stacks, 1, "an enemy's Ruin reaches Crono's TimeDebtComponent")
	check_eq(st.max_hp(), roundi(float(base) * 0.85), "one stack lowers the ceiling 15%")
	check_eq(StatusComponent.of(crono).stacks(&"ruin"), 1, "and the status entry mirrors it")
	for i in 3:
		_act(c, e)
	check_eq(td.ruin_stacks, 3, "four applications stop at 3 stacks (#18)")
	check_eq(st.max_hp(), roundi(float(base) * 0.55), "−45% at most outside Porcelain Silence")
	check(st.hp <= st.max_hp(), "HP is clamped to the lowered ceiling")
	check(RuinRules.blocks_prometheus(crono), "Ruin 2+ blocks the Prometheus Core (#21)")
	var kst := CombatantStats.of(krona)
	var kbase: int = kst.base_max_hp
	_act(c, e2)
	_act(c, e2)
	check_eq(RuinRules.stacks(krona), 2, "another ally carries Ruin in her StatusComponent")
	check_eq(kst.max_hp(), roundi(float(kbase) * 0.70), "and her ceiling drops too")
	c.force_end(true)
	check_eq(td.ruin_stacks, 0, "Ruin clears when the battle ends (battle-scoped)")
	check_eq(st.max_hp(), base, "Crono's ceiling is whole again")
	check(not StatusComponent.of(krona).has(&"ruin"), "Krona's stacks are gone")
	check_eq(kst.max_hp(), kbase, "and her ceiling with them")


func test_porcelain_silence_lifts_the_ruin_cap_to_ten() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var krona := _party_member(&"krona", 10, Vector3(-3, 0, 2))
	var e := _enemy(&"reflection", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000})
	e.set_meta("boss_id", "cronos_reflection")
	_start(c, [crono, krona], [e])
	check_eq(RuinRules.battle_cap(c.enemies), CombatConstants.RUIN_STACK_CAP_SILENCE, "the Reflection's Ruin scaling hazard lifts the cap")
	RuinRules.add(crono, 12)
	check_eq(RuinRules.stacks(crono), 10, "Crono takes 10 stacks")
	check_eq(CombatantStats.of(crono).max_hp(), roundi(float(CombatantStats.of(crono).base_max_hp) * CombatConstants.CRONO_CEILING_FLOOR), "the 10% floor still holds")
	RuinRules.add(krona, 12)
	check_eq(RuinRules.stacks(krona), 10, "so does every ally")
	c.force_end(true)
	check_eq(TimeDebtComponent.of(crono).ruin_cap, CombatConstants.RUIN_STACK_CAP, "the cap does not leak past the fight")
	var c2 := _coord()
	var e2 := _enemy(&"plain", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000})
	_start(c2, [crono, krona], [e2])
	RuinRules.add(krona, 12)
	check_eq(RuinRules.stacks(krona), CombatConstants.RUIN_STACK_CAP, "a normal battle caps at 3")


func test_mercury_slow_halves_the_move() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(5, 0, 5), 4, ["ICE"], {"hp": 50000})
	_start(c, [crono], [e])
	StatusComponent.of(e).add(&"time_stop", 60.0)
	check(_advance_until_window(c) == crono, "Crono gets a window")
	StatusComponent.of(crono).add(&"mercury_slow", 30.0)
	var from: Vector3 = c.position_of(crono)
	var r: Dictionary = c.cmd_move(crono, from + Vector3(0, 0, 9))
	check(bool(r.get("ok", false)), "the move is accepted")
	check_near(c.position_of(crono).distance_to(from), CombatantStats.of(crono).move_range * 0.5, 0.01, "Mercury SLOW halves the battle move (#20)")
	check_near(StatusRules.move_range(crono), 3.0, 0.01, "move range 6 m -> 3 m")


# ---------------------------------------------------------------- Jammed and HP windows (COMBAT-6)

func test_a_jammed_enemy_whose_actions_all_wind_up_attacks_plainly() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"crow", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000, "weapon_tags": ["PIERCING"]})
	var def := _def("crow", [
		{"id": "vhs_dive", "tags": ["VOLT"], "shape": "SINGLE", "power": 1.0, "wind_up_s": 1.5, "target": "weakest"},
		{"id": "omen", "tags": ["DARK"], "shape": "CIRCLE", "radius": 2.0, "power": 1.0, "wind_up_s": 2.0, "target": "weakest"},
	])
	_start(c, [crono], [e], {"enemy_defs": {&"crow": def}})
	var free_pick: Dictionary = EnemyBrain.choose(c, e, def, c.rng)
	check(float(free_pick["wind_up_s"]) > 0.0, "unjammed, it winds up")
	StatusComponent.of(e).add(&"jammed", -1.0, 2)
	for i in 6:
		var a: Dictionary = EnemyBrain.choose(c, e, def, c.rng)
		check_eq(String(a["id"]), "attack", "Jammed: a plain Attack instead of a wind-up")
		check_near(float(a["wind_up_s"]), 0.0, 0.0001, "with no wind-up")
	check(Array(EnemyBrain.choose(c, e, def, c.rng)["tags"]).has(&"PIERCING"), "with its weapon tags")
	c.gauges[e] = 100.0
	c._begin_enemy_turn(e)
	check(not c.wind_ups.has(e), "the coordinator starts no telegraph for a Jammed body")


func test_a_silenced_enemy_makes_a_plain_attack() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"choir", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000, "weapon_tags": ["PIERCING"]})
	var def := _def("choir", [
		{"id": "spell_nova", "tags": ["LIGHT"], "shape": "CIRCLE", "radius": 2.0, "power": 0.01, "wind_up_s": 1.5, "target": "weakest"},
		{"id": "hex", "tags": ["DARK"], "shape": "SINGLE", "power": 0.01, "target": "weakest"},
	])
	_start(c, [crono], [e], {"enemy_defs": {&"choir": def}})
	_tough_party(crono)
	c.fields.add(&"divinity_field", c.arena_center, 40.0, -1.0, 0)  # the party's field
	ShieldComponent.of(e).force_break(crono)
	check(StatusComponent.of(e).has(&"silence"), "a foe that Breaks in the party's Divinity Field is silenced 15 s (§12.5)")
	var chosen: Array[String] = []
	c.enemy_action_started.connect(func(_u: Node, a: Dictionary) -> void: chosen.append(String(a["id"])))
	var t: float = 0.0
	while ShieldComponent.of(e).is_broken and t < 12.0:
		_run(c, 0.5)
		t += 0.5
	check(not ShieldComponent.of(e).is_broken and StatusComponent.of(e).has(&"silence"), "it recovers from the Break still silenced")
	for i in 3:
		c.gauges[e] = CombatConstants.GAUGE_MAX - 0.1  # its next turns, inside the 15 s
		_run(c, 0.5)
	check(chosen.size() >= 3 and StatusComponent.of(e).has(&"silence"), "it acts three times while silenced (%d)" % chosen.size())
	check_eq(chosen.filter(func(id: String) -> bool: return id != "attack").size(), 0, "Silenced, its techniques are sealed: every action a plain Attack (§12)")
	check(Array(EnemyBrain.choose(c, e, def, c.rng)["tags"]).has(&"PIERCING"), "with its weapon tags")
	StatusComponent.of(e).remove(&"silence")
	var named: bool = false
	for i in 8:
		named = named or String(EnemyBrain.choose(c, e, def, c.rng)["id"]) != "attack"
	check(named, "the silence over, its techniques come back")


## Knock-Static hitches every action of its 2 turns (§12.2), so it is read when the action is chosen; Magnetized and
## Gramophone's hitched hitch the next action only ('next action' is turns 2: DECISIONS "Readings chosen").
func test_knock_static_hitches_two_actions_a_boss_one() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var grunt := _enemy(&"grunt", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000})
	var boss := _enemy(&"big", 10, Vector3(3, 0, 3), 4, ["ICE"], {"hp": 50000, "kind": "boss"})
	var metal := _enemy(&"bell", 10, Vector3(3, 0, -3), 4, ["ICE"], {"hp": 50000})
	_start(c, [crono], [grunt, boss, metal])
	_tough_party(crono)
	var hitches := func(e: Node, turns: int) -> Array:
		var out: Array = []
		for i in turns:
			c.gauges[e] = CombatConstants.GAUGE_MAX
			c._begin_enemy_turn(e)  # the brain chooses, the turn counts its statuses down, the wind-up starts
			out.append(float(c.wind_ups[e]["total"]) if c.wind_ups.has(e) else 0.0)
			if c.wind_ups.has(e):
				c._execute_enemy_action(e, c.wind_ups[e]["action"])
				c.wind_ups.erase(e)
		return out
	StatusRules.apply(c, grunt, &"knock_static", -1.0, 2)
	check_eq(str(hitches.call(grunt, 3)), str([0.5, 0.5, 0.0]), "a 2-turn Knock-Static hitches the enemy's next two actions 0.5 s")
	StatusRules.apply(c, boss, &"knock_static", -1.0, 2)
	check_eq(str(hitches.call(boss, 2)), str([0.5, 0.0]), "a boss takes half: one hitched action, not none (§12.1)")
	for id in [&"magnetized", &"hitched"]:
		StatusComponent.of(metal).add(id, -1.0, 2)
		check_eq(str(hitches.call(metal, 2)), str([0.5, 0.0]), "%s at 2 turns hitches its next action only" % id)


func test_hp_windows_hold_when_the_cadence_rules_everything_out() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"golem", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000})
	var def := _def("golem", [
		{"id": "low", "tags": ["BLUNT"], "shape": "SINGLE", "power": 1.0, "max_hp_ratio": 0.5, "every_n_turns": 3, "weight": 5},
		{"id": "high", "tags": ["BLUNT"], "shape": "SINGLE", "power": 1.0, "min_hp_ratio": 0.5, "every_n_turns": 3},
	])
	_start(c, [crono], [e], {"enemy_defs": {&"golem": def}})
	for i in 8:
		check_eq(String(EnemyBrain.choose(c, e, def, c.rng)["id"]), "high", "off-cadence at full HP it keeps to its HP window")


# ---------------------------------------------------------------- shield rules (COMBAT-8, DATA-7)

func test_break_immune_until_a_ferro_ally_is_in_the_party() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"choir", 10, Vector3(3, 0, 0), 2, ["SWORD"], {"hp": 50000})
	var sh := _shield(e, {"shield": 2, "weak": ["SWORD"], "break_condition": "ferro_in_party"})
	_start(c, [crono], [e])
	check(not sh.break_allowed, "a break condition makes the plates Break-immune")
	check(not bool(sh.preview_action([&"SWORD"], 2, 0)["breaks"]), "the preview promises no Break without FERRO")
	sh.apply_strike([&"SWORD"], 0, crono)
	var r: Dictionary = sh.apply_strike([&"SWORD"], 0, crono)
	check_eq(sh.current_shield, 0, "the plates go to 0")
	check(not sh.is_broken and not bool(r["caused_break"]), "but the Break waits")
	sh.tick(0.5)
	check(not sh.is_broken, "and keeps waiting while no FERRO ally stands")
	var cassia := _party_member(&"cassia", 10, Vector3(-3, 0, 3))
	c.party.append(cassia)
	sh.tick(0.1)
	check(sh.is_broken, "a FERRO ally in the party lets the waiting Break land")
	check(c.is_broken(e), "the coordinator sees it Broken")
	c.force_end(true)
	var c2 := _coord()
	var e2 := _enemy(&"choir2", 10, Vector3(3, 0, 0), 2, ["SWORD"], {"hp": 50000})
	var sh2 := _shield(e2, {"shield": 2, "weak": ["SWORD"], "break_condition": "ferro_in_party"})
	_start(c2, [crono, cassia], [e2])
	check(bool(sh2.preview_action([&"SWORD"], 2, 0)["breaks"]), "with Cassia-09 along the preview shows the Break")
	sh2.apply_strike([&"SWORD"], 0, crono)
	check(bool(sh2.apply_strike([&"SWORD"], 0, crono)["caused_break"]), "and the strike Breaks at once")


func test_a_released_condition_breaks_and_is_rearmed_next_battle() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"chest", 10, Vector3(3, 0, 0), 1, ["SWORD"], {"hp": 50000})
	var sh := _shield(e, {"shield": 1, "weak": ["SWORD"], "break_condition": "springs_cut"})
	_start(c, [crono], [e])
	sh.apply_strike([&"SWORD"], 0, crono)
	check(sh.pending_break and not sh.is_broken, "springs uncut: the Break waits at 0")
	BreakConditions.release(e, crono)
	check(sh.is_broken, "cutting the springs releases the waiting Break")
	c.force_end(true)
	sh.reset_shields()
	var c2 := _coord()
	_start(c2, [crono], [e])
	check(not sh.can_break_now(), "the next battle starts Break-immune again")


func test_shared_plates_are_one_count_across_the_choir() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var bodies: Array = []
	for i in 3:
		var b := _enemy(StringName("choir_%d" % i), 10, Vector3(3, 0, i * 2), 6, ["SWORD"], {"hp": 50000})
		_shield(b, {"shield": 6, "weak": ["SWORD"], "shared_group": "laugh_track_choir"})
		bodies.append(b)
	_start(c, [crono], bodies)
	var a := ShieldComponent.of(bodies[0])
	var b1 := ShieldComponent.of(bodies[1])
	var b2 := ShieldComponent.of(bodies[2])
	check(b1.shared_owner == a and b2.shared_owner == a, "the first body holds the group's count")
	b1.apply_strike([&"SWORD"], 0, crono)
	check_eq(a.current_shield, 5, "a shave on any body lowers the one count")
	check_eq(b2.current_shield, 5, "and every body shows it")
	check(bool(b2.preview_action([&"SWORD"], 5, 0)["breaks"]), "the preview reads the shared count")
	for i in 5:
		b2.apply_strike([&"SWORD"], 0, crono)
	check(a.is_broken and b1.is_broken and b2.is_broken, "the whole choir Breaks together")
	check(c.is_broken(bodies[1]), "each body is Broken for the coordinator")
	b1.extend_lock(2.5)
	check_near(a.lock_left, b2.lock_left, 0.0001, "a lock extension on one body locks them all")
	CombatantStats.of(bodies[0]).apply_damage(999999, true)
	_run(c, 20.0)
	check(not b1.is_broken and not a.is_broken, "with the holder down, a living member runs the count's recovery")
	b1.apply_strike([&"SWORD"], 0, crono)
	check_eq(b2.current_shield, a.current_shield, "the rebuilt count is still shared")
	check_eq(a.current_shield, 5, "and shaved by any body")
	c.force_end(true)
	check(b1.shared_owner == null, "the battle's end unlinks the plates")


func test_refills_once_holds_the_phase_through_its_first_break() -> void:
	var sh := ShieldComponent.new()
	_track(sh)
	sh.configure({"shield": 2, "weak": ["SWORD"], "refill_once": true})
	check(sh.consume_refill(), "the first Break of the phase is the refill")
	check(not sh.consume_refill(), "only once")
	sh.configure({"shield": 2, "weak": ["SWORD"], "refill_once": true})
	check(sh.consume_refill(), "a new phase refills once again")
	var id := StringName("test_refill_boss")
	var tap: Dictionary = {"id": "tap", "name": "Tap", "tags": ["BLUNT"], "shape": "SINGLE", "power": 0.01, "hits": 1, "target": "random", "weight": 1}
	Data.bosses[id] = {
		"id": String(id), "name": "Refill", "universe": 0, "level": 3, "hp": 100000, "kind": "boss", "size": 1.5,
		"body_radius": 0.6, "tags": ["BLUNT"], "adds": [], "branches": [], "drops": [], "phases": [
			{"id": "arm", "name": "Arm", "hp_from": 1.0, "hp_to": 1.0, "advance_on": "break", "tags": ["BLUNT"],
				"shield": {"shield": 1, "weak": ["SWORD"], "refill_once": true}, "actions": [tap]},
			{"id": "two", "name": "Two", "hp_from": 1.0, "hp_to": 0.0, "tags": ["BLUNT"], "shield": {"shield": 5, "weak": ["SWORD"]}, "actions": [tap]},
		],
	}
	_test_bosses.append(id)
	Game.new_game()
	Game.set_party([&"crono"])
	var loc: Location = (load(ARENA) as PackedScene).instantiate()
	root.add_child(loc)
	_track(loc)
	loc.place_party(&"start")
	await get_tree().process_frame
	loc._on_story_battle(&"", {"boss_id": String(id), "boss": true, "at": "boss", "center": "center"})
	var scene: BattleScene = loc.battle
	var c: BattleCoordinator = scene.coordinator
	c.auto_tick = false
	var ctrl: BossController = scene.boss
	var boss: Node = ctrl.actor
	var crono: Node = c.unit_by_id(&"crono")
	CombatantStats.of(crono).weapon_hits = 1
	CombatantStats.of(crono).weapon_tags = [&"SWORD"]
	check(_advance_until_actor(c, &"crono") == crono, "Crono gets a window")
	c.cmd_attack(crono, boss, 0)
	check(ShieldComponent.of(boss).is_broken, "the first Break")
	check(not ctrl.gate_open, "refills once: the phase's gate stays shut")
	_play_out(c, boss)
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 0, "the plates rebuild and the phase goes on")
	check(_advance_until_actor(c, &"crono") == crono, "Crono's next window")
	c.cmd_attack(crono, boss, 0)
	check(ctrl.gate_open, "the second Break opens the gate")
	_play_out(c, boss)
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 1, "and the next phase begins")
	c.force_end(true)


func _play_out(c: BattleCoordinator, boss: Node) -> void:
	var t: float = 0.0
	while ShieldComponent.of(boss).is_broken and t < 30.0:
		if c.state == BattleCoordinator.State.COMMAND_WAIT:
			c.cmd_guard(c.active_actor)
		c.advance(1.0 / 30.0)
		t += 1.0 / 30.0


# ---------------------------------------------------------------- Lv2 debuffs (COMBAT-9)

## One telegraphed hit of power 1 from a fresh enemy on a fresh Crono; `extra` is merged into the chosen action.
func _hit_crono(extra: Dictionary, variance: float, seed_v: int = 7) -> int:
	var c := _coord(seed_v)
	c.fixed_variance = variance
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"brute", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000})
	var def := _def("brute", [_strike("slam", "crono", {"power": 1.0})])
	_start(c, [crono], [e], {"enemy_defs": {&"brute": def}})
	var action: Dictionary = EnemyBrain.choose(c, e, def, c.rng)
	action.merge(extra, true)
	c.rng.seed = 4242
	var before: int = CombatantStats.of(crono).hp
	c._execute_enemy_action(e, action)
	var dealt: int = before - CombatantStats.of(crono).hp
	c.force_end(true)
	return dealt


func test_probability_lock_rolls_twice_and_keeps_the_worse() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000})
	var def := _def("x", [_strike("slam", "crono")])
	_start(c, [crono], [e], {"enemy_defs": {&"x": def}})
	StatusRules.lv2_debuff(c, null, [&"TACHYON"], e)
	check(StatusComponent.of(e).has(&"probability_lock"), "TACHYON Lv2 applies Probability Lock")
	var a: Dictionary = EnemyBrain.choose(c, e, def, c.rng)
	check(bool(a["probability_lock"]), "its next action carries the lock")
	check(not StatusComponent.of(e).has(&"probability_lock"), "and the lock is spent on it")
	check(not bool(EnemyBrain.choose(c, e, def, c.rng)["probability_lock"]), "the action after it rolls once")
	var ref := RandomNumberGenerator.new()
	ref.seed = 99
	var r1: float = ref.randf()
	var r2: float = ref.randf()
	c.rng.seed = 99
	check_near(EnemyStrike._roll(c, true, false), minf(r1, r2), 0.000001, "evasion keeps the lower roll (more likely to miss)")
	c.rng.seed = 99
	check_near(EnemyStrike._roll(c, true, true), maxf(r1, r2), 0.000001, "the status chance keeps the higher (less likely to land)")
	ref.seed = 4242
	var v1: float = ref.randf_range(CombatConstants.VARIANCE_MIN, CombatConstants.VARIANCE_MAX)
	var v2: float = ref.randf_range(CombatConstants.VARIANCE_MIN, CombatConstants.VARIANCE_MAX)
	check_eq(_hit_crono({"probability_lock": true}, 0.0), _hit_crono({}, minf(v1, v2)), "damage variance keeps the lower of two rolls")


func test_refracted_splits_a_fifth_of_the_damage_away() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000})
	var def := _def("x", [_strike("slam", "crono")])
	_start(c, [crono], [e], {"enemy_defs": {&"x": def}})
	StatusRules.lv2_debuff(c, null, [&"VITREOUS"], e)
	check(bool(EnemyBrain.choose(c, e, def, c.rng)["refracted"]), "VITREOUS Lv2: the action is Refracted")
	var full: int = _hit_crono({}, 1.0)
	var refracted: int = _hit_crono({"refracted": true}, 1.0)
	check(full > 10, "the plain hit does real damage")
	check_near(float(refracted), float(full) * 0.8, 1.0, "Refracted keeps 80% of it")


func test_guilty_turns_half_its_attacks_on_its_own_allies() -> void:
	var c := _coord(11)
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"liar", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000})
	var mate := _enemy(&"mate", 10, Vector3(4, 0, 2), 4, ["ICE"], {"hp": 50000})
	var def := _def("liar", [_strike("slam", "crono", {"power": 1.0})])
	_start(c, [crono], [e, mate], {"enemy_defs": {&"liar": def}})
	StatusRules.lv2_debuff(c, null, [&"GUILE"], e)
	check(StatusComponent.of(e).has(&"guilty"), "GUILE Lv2 applies GUILTY")
	var turned: int = 0
	for i in 60:
		var a: Dictionary = EnemyBrain.choose(c, e, def, c.rng)
		if bool(a["turned"]):
			turned += 1
			check(a["targets"][0] == mate, "a turned attack aims at one of its own allies")
	check(turned > 15 and turned < 45, "about half its attacks turn (%d of 60)" % turned)
	var action: Dictionary = {}
	while not bool(action.get("turned", false)):
		action = EnemyBrain.choose(c, e, def, c.rng)
	var mate_hp: int = CombatantStats.of(mate).hp
	var crono_hp: int = CombatantStats.of(crono).hp
	c._execute_enemy_action(e, action)
	check(CombatantStats.of(mate).hp < mate_hp, "the turned attack hurts its ally")
	check_eq(CombatantStats.of(crono).hp, crono_hp, "and not the party")


func test_stripped_takes_one_resistance_for_two_turns() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000, "resists": ["FIRE", "VOLT"]})
	_start(c, [crono], [e])
	var sh := ShieldComponent.of(e)
	StatusRules.lv2_debuff(c, null, [&"NULL"], e)
	check(StatusComponent.of(e).has(&"stripped"), "NULL Lv2 applies Stripped")
	check(not sh.resists.has(&"FIRE") and sh.resists.has(&"VOLT"), "it loses one resistance")
	check_near(DamagePipeline.resist_factor([&"FIRE"], sh, CombatantStats.of(e)), 1.0, 0.0001, "FIRE now lands in full")
	StatusRules.lv2_debuff(c, null, [&"NULL"], e)
	check(sh.resists.has(&"VOLT"), "a second strip while Stripped takes nothing more")
	var sc := StatusComponent.of(e)
	sc.on_turn_taken()
	sc.on_turn_taken()
	check(not sc.has(&"stripped"), "two of its turns later Stripped ends")
	check(sh.resists.has(&"FIRE"), "and the resistance comes back")


# ---------------------------------------------------------------- periodic ticks (COMBAT-10)

func test_periodic_statuses_tick_on_battle_time() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var krona := _party_member(&"krona", 10, Vector3(-3, 0, 2))
	var e := _enemy(&"eel", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000})
	var def := _def("eel", [_strike("oil_fire", "crono", {"power": 1.0, "status": "oil_dot", "status_seconds": 6})])
	_start(c, [crono, krona], [e], {"enemy_defs": {&"eel": def}})
	StatusComponent.of(e).add(&"time_stop", 120.0)
	CombatantStats.of(crono).luk = 0.0
	var kst := CombatantStats.of(krona)
	StatusComponent.of(krona).add(&"grief", -1.0, -1, 2)
	var kmp: int = kst.mp
	var cst := CombatantStats.of(crono)
	cst.max_mp = 20  # Crono's kit spends no MP; give him some to lose
	cst.mp = 20
	StatusComponent.of(crono).add(&"laugh_track_drain", 30.0)
	var cmp: int = cst.mp
	_run(c, 10.05)
	check_eq(kst.mp, kmp - 2 * CombatConstants.GRIEF_MP, "Grief: −2 MP per stack per 10 s of battle time")
	check_eq(cst.mp, cmp - CombatConstants.LAUGH_TRACK_MP, "Laugh Track Drain: −1 MP per 8 s")
	_act(c, e)
	var tick: int = int(StatusComponent.of(crono).data(&"oil_dot").get("tick", 0))
	check(tick >= 1, "an oil DoT keeps a tick from the hit that applied it")
	var hp: int = cst.hp
	_run(c, 2.05)
	check_eq(cst.hp, hp - tick, "and deals it every 2 s")
	StatusComponent.of(crono).add(&"regen", 10.0, -1, 1, {"tick": 7})
	cst.hp = cst.max_hp() - 50
	var hp2: int = cst.hp
	_run(c, 2.05)
	check_eq(cst.hp, hp2 + 7 - tick, "regen heals its tick (the oil still burns)")
	c.force_end(true)
	check(not StatusComponent.of(crono).has_meta(StatusTicks.META), "the ticks are released when the battle ends")


## Combat Laws 4.2 Spare ("removed from the fight alive"): a spared enemy's burn ticks no more, so it never dies
## of it, stands no statue (LINE_PIERCE cover) and fires no KO; an enemy still in the fight keeps burning.
func test_a_spared_enemy_takes_no_more_ticks() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	_tough_party(crono)
	var e := _enemy(&"spoon", 10, Vector3(3, 0, 0), 2, ["SWORD"], {"hp": 80})
	var e2 := _enemy(&"spoon_b", 10, Vector3(3, 0, 2), 2, ["SWORD"], {"hp": 50000})
	_start(c, [crono], [e, e2])
	check(_advance_until_actor(c, &"crono") == crono, "Crono gets a window")
	ShieldComponent.of(e).force_break(crono)
	var st := CombatantStats.of(e)
	st.hp = 16
	for u in [e, e2]:
		check(StatusRules.apply(c, u, &"burn", 10.5, -1, 1, {"tick": 4}), "a 10.5 s burn ticking 4 lands")
	var ticks: Array[Node] = []
	c.strike_resolved.connect(func(_a: Node, t: Node, info: Dictionary) -> void:
		if bool(info.get("dot", false)):
			ticks.append(t))
	var koed: Array[Node] = []
	c.unit_koed.connect(func(u: Node) -> void: koed.append(u))
	check(bool(c.cmd_spare(crono, e).get("ok", false)), "the Broken enemy at 20% is spared")
	var hp2: int = CombatantStats.of(e2).hp
	_run(c, 11.0)
	check_eq(st.hp, 16, "the spared enemy loses no HP to its burn")
	check(st.is_alive() and not koed.has(e) and not c.ko_order.has(e), "it does not die of it, and no KO fires")
	check(not c.statues.standing(e), "it stands no statue")
	check(not ticks.has(e), "no DoT strike lands on it")
	check(ticks.has(e2) and CombatantStats.of(e2).hp < hp2, "the enemy still fighting keeps burning")
	check(c.state != BattleCoordinator.State.IDLE, "and the battle goes on")
	c.force_end(true)


# ---------------------------------------------------------------- accuracy and shave penalties (COMBAT-11)

func test_blind_party_hits_miss_about_thirty_percent() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 4, ["SWORD"], {"hp": 50000})
	_start(c, [crono], [e])
	var sc := StatusComponent.of(crono)
	var state_before: int = c.rng.state
	check(StatusRules.hit_lands(c, sc), "full accuracy always lands")
	check_eq(c.rng.state, state_before, "and draws nothing, so unaffected battles are unchanged")
	sc.add(&"blind", 10.0)
	var lands: int = 0
	for i in 2000:
		if StatusRules.hit_lands(c, sc):
			lands += 1
	check_near(float(lands) / 2000.0, 0.70, 0.04, "BLIND: −30% accuracy")
	sc.remove(&"blind")
	sc.add(&"white_noise_blind", 10.0)
	check(_advance_until_window(c) == crono, "Crono gets a window")
	var strikes: Array = []
	c.strike_resolved.connect(func(_a: Node, _t: Node, info: Dictionary) -> void: strikes.append(info))
	var before: int = ShieldComponent.of(e).current_shield
	c.cmd_attack(crono, e, 0)
	check(not strikes.is_empty() and strikes.all(func(s: Dictionary) -> bool: return bool(s.get("missed", false))), "White-Noise BLIND: every strike misses")
	check_eq(ShieldComponent.of(e).current_shield, before, "and a miss shaves nothing")


func test_blind_ranged_hits_and_sticky_ash_lose_a_shave_in_preview_and_hit() -> void:
	var c := _coord()
	var gunner := _party_member(&"krona", 10, Vector3(-3, 0, 0))
	CombatantStats.of(gunner).weapon_tags = [&"GUN", &"FIRE"]
	CombatantStats.of(gunner).weapon_hits = 1
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 6, ["GUN", "FIRE"], {"hp": 50000})
	_start(c, [gunner], [e])
	check_eq(int(c.preview(gunner, null, e, Vector3.ZERO, 0)[e]["shave"]), 2, "GUN + FIRE shave 2")
	StatusComponent.of(gunner).add(&"blind", 10.0)
	check_eq(ShaveBonus.penalty(gunner, [&"GUN", &"FIRE"]), 1, "BLIND: a ranged hit loses 1 shave")
	check_eq(int(c.preview(gunner, null, e, Vector3.ZERO, 0)[e]["shave"]), 1, "and the preview shows it")
	var sh := ShieldComponent.of(e)
	var r: Dictionary = sh.apply_strike([&"GUN", &"FIRE"], 0, gunner, &"krona", ShaveBonus.penalty(gunner, [&"GUN", &"FIRE"]))
	check_eq(int(r["shaved"]), 1, "the strike shaves what the preview promised (#23)")
	check_eq(ShaveBonus.penalty(gunner, [&"SWORD"]), 0, "melee keeps its shave")
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 3))
	StatusComponent.of(crono).add(&"sticky_ash", -1.0)
	check_eq(ShaveBonus.penalty(crono, [&"ASTRAL", &"SWORD"]), 1, "Sticky Ash: Crono's ASTRAL hits shave 1 less")
	check_eq(ShaveBonus.penalty(gunner, [&"ASTRAL"]), 0, "only Crono's")


func test_ash_inhale_slows_and_blinds() -> void:
	var sc := StatusComponent.new()
	_track(sc)
	sc.add(&"ash_inhale", 8.0)
	check_near(sc.gauge_multiplier(), CombatConstants.MERCURY_SLOW, 0.0001, "Ash Inhale is a SLOW stack: gauge 0.5×")
	check_near(sc.movement_multiplier(), 0.5, 0.0001, "and movement 0.5×")
	check_near(sc.accuracy_mod(), -0.20, 0.0001, "and BLIND 20%")


# ---------------------------------------------------------------- NULL's strip expires (COMBAT-17)

func test_null_strip_gives_the_plates_back_after_two_turns() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var bare := _enemy(&"bare", 10, Vector3(3, 0, 0), 4, [], {"hp": 50000})
	var armoured := _enemy(&"armoured", 10, Vector3(3.5, 0, 1), 4, ["SWORD"], {"hp": 50000, "resists": ["FIRE"]})
	_start(c, [crono], [bare, armoured], {"techs": Data.techs})
	var tech: TechDef = Data.techs[&"null_crono"]
	var action: Dictionary = {"attacker": crono, "primary": null, "boost": 0, "aim": Vector3(3.2, 0, 0.5), "casters": [crono]}
	TechEffects.apply(c, tech, action)
	var sh1 := ShieldComponent.of(bare)
	var sh2 := ShieldComponent.of(armoured)
	check_eq(sh1.weaknesses.size(), 1, "a weaknessless body gets one created weakness")
	var fake: StringName = sh1.weaknesses[0] if not sh1.weaknesses.is_empty() else &""
	check(sh2.resists.is_empty(), "a body with weaknesses loses its resistances")
	var sc1 := StatusComponent.of(bare)
	var sc2 := StatusComponent.of(armoured)
	sc1.on_turn_taken()
	check(sh1.weaknesses.has(fake), "the created weakness holds through its first turn")
	sc1.on_turn_taken()
	check(sh1.weaknesses.is_empty() and not sh1.is_revealed(fake), "and is gone after two (§9.3)")
	sc2.on_turn_taken()
	sc2.on_turn_taken()
	check_eq(sh2.resists, [&"FIRE"] as Array[StringName], "the resistance comes back after two turns")
	TechEffects.apply(c, tech, action)
	sh2.configure({"shield": 4, "weak": ["SWORD"], "resist": ["ICE"]})
	sc2.on_turn_taken()
	sc2.on_turn_taken()
	check_eq(sh2.resists, [&"ICE"] as Array[StringName], "a phase change in between keeps the new plates as they are")


# ---------------------------------------------------------------- the cleanse keep-list (COMBAT-20)

func test_cleanse_keeps_concerned_and_ruin() -> void:
	var sc := StatusComponent.new()
	_track(sc)
	for id in [&"concerned_target", &"ruin", &"ward", &"blind", &"grief", &"corroded"]:
		sc.add(id, -1.0, -1)
	sc.cleanse()
	check(sc.has(&"concerned_target"), "Concerned outlasts the battle's cleanse (until camp, §12.3)")
	check(sc.has(&"ruin") and sc.has(&"ward"), "Ruin only thaws; Ward is a buff")
	check(not sc.has(&"blind") and not sc.has(&"grief") and not sc.has(&"corroded"), "the debuffs go")
	check(not StatusComponent.CLEANSE_KEEPS.has(&"ens_ring") and not StatusComponent.CLEANSE_KEEPS.has(&"concerned"), "no names that are never applied")


# ---------------------------------------------------------------- boss status rules (COMBAT-12)

func test_bosses_halve_the_slows_and_shrug_off_confusion() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var boss := _enemy(&"big", 10, Vector3(3, 0, 0), 4, ["SWORD"], {"hp": 50000, "kind": "boss"})
	var boss2 := _enemy(&"big2", 10, Vector3(3, 0, 3), 4, ["SWORD"], {"hp": 50000, "kind": "boss"})
	var grunt := _enemy(&"grunt", 10, Vector3(3, 0, -3), 4, ["SWORD"], {"hp": 50000})
	_start(c, [crono], [boss, boss2, grunt], {"enemy_defs": {&"big2": _def("big2", [], {"behaviour": {"takes_statuses": ["guilty"]}})}})
	var sc := StatusComponent.of(boss)
	StatusRules.apply(c, boss, &"slow", 6.0)
	check_near(float(sc.statuses[&"slow"]["seconds"]), 3.0, 0.0001, "a boss takes half the SLOW")
	StatusRules.apply(c, boss, &"chrono_lag", 6.0)
	check_near(float(sc.statuses[&"chrono_lag"]["seconds"]), 3.0, 0.0001, "and half the Chrono Lag")
	StatusRules.apply(c, boss, &"knock_static", -1.0, 2)
	check_eq(int(sc.statuses[&"knock_static"]["turns"]), 1, "and half the Knock-Static turns")
	for id in [&"guilty", &"time_stop", &"confuse"]:
		check(not StatusRules.apply(c, boss, id, 3.0, 2) and not sc.has(id), "a boss is immune to %s" % id)
	StatusRules.lv2_debuff(c, null, [&"GUILE"], boss)
	check(not sc.has(&"guilty"), "GUILE Lv2 does not make a boss GUILTY")
	check(StatusRules.apply(c, boss2, &"guilty", -1.0, 2), "unless its entry says it takes GUILTY")
	StatusRules.apply(c, grunt, &"slow", 6.0)
	check_near(float(StatusComponent.of(grunt).statuses[&"slow"]["seconds"]), 6.0, 0.0001, "a regular enemy takes it all")
	check(StatusRules.apply(c, grunt, &"guilty", -1.0, 2), "and can be made GUILTY")


# ---------------------------------------------------------------- Glenn's steals (GAP3-2, #22)

func test_glenn_steals_from_the_counter_then_the_laugh_and_the_ringmaster_gives_all() -> void:
	var c := _coord()
	var glenn := _party_member(&"glenn", 44, Vector3(-3, 0, 0))
	var e := _enemy(&"thief", 44, Vector3(3, 0, 0), 4, ["SWORD"], {"hp": 50000})
	var ring := _enemy(&"ring", 44, Vector3(3, 0, 3), 9, ["SWORD"], {"hp": 50000})
	_start(c, [glenn], [e, ring], {"enemy_defs": {&"ring": _def("ring", [], {"behaviour": {"steal_all_when_broken": true}})}, "max_bp": 9})
	c.bank.bp = 0
	e.set_meta("stolen_bp", 1)
	check_eq(TechEffects._steal_from(c, glenn, e, 3), 1, "a counter of 1 gives 1 at Lv3: no laugh BP while it held any")
	check_eq(int(e.get_meta("stolen_bp")), 0, "the counter is empty")
	check_eq(TechEffects._steal_from(c, glenn, e, 3), 1, "an empty counter gives 1 BP from the laugh")
	e.set_meta("stolen_bp", 10)
	check_eq(TechEffects._steal_from(c, glenn, e, 4), 3, "never more than 3 BP per steal")
	check_eq(TechEffects._steal_from(c, glenn, e, 2), 2, "2 BP at Lv2")
	check_eq(TechEffects._steal_from(c, glenn, e, 0), 1, "1 BP at Lv0")
	check_eq(c.bank.bp, 8, "every stolen BP lands in the pool once")
	c.bank.bp = 0
	ring.set_meta("stolen_bp", 7)
	check_eq(TechEffects._steal_from(c, glenn, ring, 3), 3, "the Ringmaster standing: the usual cap")
	ShieldComponent.of(ring).force_break(glenn)
	check_eq(TechEffects._steal_from(c, glenn, ring, 0), 4, "Broken, he gives up his whole counter in one steal")
	check_eq(int(ring.get_meta("stolen_bp")), 0, "the counter is emptied")
	ring.set_meta("stolen_bp", 20)
	TechEffects._steal_from(c, glenn, ring, 0)
	check(c.bank.bp <= c.bank.effective_cap(), "the pool's cap still applies")
	var bdef: BossDef = BossDef.from_dict(Data.bosses.get(&"ash_ringmaster", {}))
	check(bool(bdef.phase_def(0).behaviour.get("steal_all_when_broken", false)), "the Ash Ringmaster's data carries the exception")
