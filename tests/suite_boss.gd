## Bosses (Combat Laws Bible §14): BossDef's phase windows and gates, BossController's phase changes (a Break
## plays out first, one window at a time, zero-width gated phases, sealed phases hold), the Possibility Branch,
## the final Break and the yield paying XP and drops, the adds as authored (counts, triggers, overrides, respawns),
## the break line, parry attribution, and the Cradle, Shard Doll and Krona directors. Scene tests build the test
## arena; test bosses are written into Data.bosses for the test and removed after it.
extends "res://tests/suite_base.gd"

const ARENA := "res://scenes/test/arena.tscn"

var _test_bosses: Array[StringName] = []


func _cleanup() -> void:
	for id in _test_bosses:
		Data.bosses.erase(id)
	_test_bosses.clear()
	Story.auto_advance_s = -1.0
	Story.auto_choice = -1
	Story.skip_waits = false
	super._cleanup()


func _phase(id: String, hp_from: float, hp_to: float, shield: int, extra: Dictionary = {}) -> Dictionary:
	var p: Dictionary = {
		"id": id, "name": id.capitalize(), "hp_from": hp_from, "hp_to": hp_to, "tags": ["BLUNT"],
		"shield": {"shield": shield, "weak": ["SWORD"]},
		"actions": [{"id": "tap", "name": "Tap", "tags": ["BLUNT"], "shape": "SINGLE", "power": 0.1, "hits": 1, "target": "random", "weight": 1}],
	}
	p.merge(extra, true)
	return p


func _boss(id: String, phases: Array, extra: Dictionary = {}) -> StringName:
	var d: Dictionary = {
		"id": id, "name": id.capitalize(), "universe": 0, "level": 3, "hp": 4000, "kind": "boss", "size": 1.5,
		"body_radius": 0.6, "tags": ["BLUNT"], "adds": [], "branches": [], "drops": [], "phases": phases,
	}
	d.merge(extra, true)
	Data.bosses[StringName(id)] = d
	_test_bosses.append(StringName(id))
	return StringName(id)


func _arena() -> Location:
	Game.new_game()
	Game.set_party([&"crono"])
	var loc: Location = (load(ARENA) as PackedScene).instantiate()
	root.add_child(loc)
	_track(loc)
	loc.place_party(&"start")
	await get_tree().process_frame
	return loc


## A story battle against `boss_id` in the arena, the clock driven by hand.
func _fight(loc: Location, boss_id: StringName) -> BattleScene:
	loc._on_story_battle(&"", {"boss_id": String(boss_id), "boss": true, "at": "boss", "center": "center"})
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


## Advance battle time (by hand) until the boss is no longer Broken.
func _play_out_break(c: BattleCoordinator, boss: Node, max_s: float = 30.0) -> void:
	var t: float = 0.0
	while ShieldComponent.of(boss).is_broken and t < max_s:
		if c.state == BattleCoordinator.State.COMMAND_WAIT:
			c.cmd_guard(c.active_actor)
		c.advance(1.0 / 30.0)
		t += 1.0 / 30.0


func _set_ratio(boss: Node, ratio: float) -> void:
	var st := CombatantStats.of(boss)
	st.hp = maxi(1, roundi(float(st.max_hp()) * ratio))


func _wait_transition(ctrl: BossController, max_s: float = 10.0) -> void:
	var t: float = 0.0
	while ctrl.transitioning and t < max_s:
		await get_tree().create_timer(0.02).timeout
		t += 0.02


# ---------------------------------------------------------------- BossDef

## BATTLE-8 / DATA-4: windows are walked one at a time, a zero-width gated phase is entered and holds, the next
## phase's window by branch; BATTLE-24: an unknown gate is an error and director gates are listed.
func test_phase_windows_walk_one_at_a_time_and_enter_gated_phases() -> void:
	var cradle := BossDef.from_dict(Data.bosses[&"atrium_cradle"])
	check_eq(cradle.next_phase(0, 0.2), 1, "one action from 70% to 20% leaves phase 1 for the Dollhouse Seal, not past it")
	check_eq(cradle.next_phase(1, 0.2), 2, "and the Seal for the Fracture only on the next step")
	check_eq(cradle.phase_for_ratio(0.2), 2, "the walk ends in the window that holds the ratio")
	var r66y := BossDef.from_dict(Data.bosses[&"r66y"])
	check_eq(r66y.phase_for_ratio(0.49), 1, "R-66Y at 49% stands in the zero-width Possibility Branch")
	check_eq(r66y.next_phase(1, 0.2), -1, "a gated phase is never left by HP")
	check_eq(r66y.next_phase(1, 0.49, true), 2, "answered (Salvage by default), Heart Expose begins at 50%")
	r66y.holds = func(pair: String) -> bool: return pair == "R66Y=Rewound"
	check_eq(r66y.next_phase(1, 0.45, true), -1, "after the Mercy Rewind Heart Expose waits for 40%")
	check_eq(r66y.next_phase(1, 0.39, true), 2, "and begins below it")
	check_eq(r66y.phase_def(2).shield, 8, "the Rewound heart carries 8 plates (shield_by_branch)")
	r66y.holds = Callable()
	check_eq(r66y.phase_def(2).shield, 12, "the Salvaged one 12")
	var ledger := BossDef.from_dict(Data.bosses[&"chrono_ledger"])
	check_eq(ledger.phase_for_ratio(0.24), 2, "a Boost Lv4 from 51% to 24% stops at Sera's Borrowed Future gate")
	check_near(BossDef.from_dict(Data.bosses[&"krona_duel"]).ends_at(), 0.5, 0.0001, "the Krona duel's last window ends at 50%")
	check_eq(cradle.ends_at(), 0.0, "a last window that ends at 0 is a kill")
	check_eq(BossDef.from_dict(Data.bosses[&"shard_doll_999"]).ends_at(), 0.0, "a gated last phase ends on its gate")
	var bad := BossDef.from_dict({"id": "bad", "phases": [{"id": "p", "advance_on": "brake", "shield": {"shield": 1}}]})
	check(Array(bad.validation_errors()).any(func(e: String) -> bool: return e.contains("unknown advance_on brake")), "a misspelt gate is a validation error")
	check(Array(BossDef.from_dict(Data.bosses[&"cyrus"]).director_gates()).has("threads_cut"), "a director-only gate is listed")


## DATA-12: the file's kind reaches the phase EnemyDef (the Ash Ringmaster is a mini-boss: its curve, its XP).
func test_kind_follows_the_file() -> void:
	var ring := BossDef.from_dict(Data.bosses[&"ash_ringmaster"])
	check_eq(ring.phase_def(0).kind, "miniboss", "the Ash Ringmaster's phase def is a mini-boss")
	var a: CombatActor = BossController.create_boss_actor(ring)
	_track(a)
	check_eq(a.stats.xp_reward, CombatConstants.xp_for_enemy(44, "miniboss"), "and pays mini-boss XP")
	check_near(a.stats.p_def, StatCurves.enemy_pdef(44, "miniboss"), 0.001, "with mini-boss defence")
	check_eq(BossDef.from_dict(Data.bosses[&"atrium_cradle"]).phase_def(0).kind, "boss", "a boss file stays a boss")


## DATA-3: authored counts are placed (the cap is the largest authored count), triggered rows wait, the add row's
## overrides apply to the codex enemy. STORY-4 / GAP4-8: the Chapter 2 phase scripts are named, the Daimyo drops nothing.
func test_boss_add_rows_as_authored() -> void:
	var kami := BossAdds.new(BossDef.from_dict(Data.bosses[&"kami_ori"]))
	check_eq(kami.cap(), 6, "Kami-Ori's six arms are not capped at three")
	check_eq(kami.rows_for_phase(0).size(), 1, "the Offering places its arms")
	check_eq(BossAdds.new(BossDef.from_dict(Data.bosses[&"r66y"])).cap(), 4, "R-66Y's four umbilicals")
	check_eq(BossAdds.new(BossDef.from_dict(Data.bosses[&"atrium_cradle"])).cap(), 2, "a file's max_adds still wins (the Cradle's two Shardlings)")
	var goyama := BossAdds.new(BossDef.from_dict(Data.bosses[&"goyama_ashen_daimyo"]))
	check(goyama.rows_for_phase(0).is_empty(), "the Daimyo's Ashigaru wait for a surrender order")
	check_eq(goyama.rows_for_trigger(0, "surrender_order").size(), 1, "and come on it")
	var cyrus := BossAdds.new(BossDef.from_dict(Data.bosses[&"cyrus"]))
	check_eq(cyrus.def_for_row(0).shield, 4, "Cyrus's strongman dummy fights at the authored 4 plates, not its codex 8")
	check_eq(cyrus.def_for_row(0).key, &"strongman_dummy", "and keeps its codex key")
	check_eq(BossAdds.new(BossDef.from_dict(Data.bosses[&"ash_loom_marionette"])).def_for_row(1).level, 43, "a level override applies")
	check_near(BossAdds.hp_step("every_20pct_hp_lost"), 0.2, 0.0001, "every_20pct_hp_lost is a 20% step")
	var krona := BossDef.from_dict(Data.bosses[&"krona_duel"])
	check_eq(String(krona.phase(1).get("script", "")), "ch2_duel_mid", "She Ate the Star plays ch2_duel_mid")
	var daimyo := BossDef.from_dict(Data.bosses[&"goyama_ashen_daimyo"])
	for i in [1, 2, 3]:
		var sid: String = String(daimyo.phase(i).get("script", ""))
		check(sid == "ch2_daimyo_phase%d" % (i + 1) and Data.dialogue.has(StringName(sid)), "Daimyo phase %d plays %s" % [i + 1, sid])
	check(daimyo.drops.is_empty(), "the Daimyo drops nothing: the scene hands out the Tooth and the vault the pigment")


# ---------------------------------------------------------------- phase changes

## BATTLE-2 (§14.1): the Break that opens a "break" gate plays out on the old plates (the rest of the action sees a
## Broken boss); the next phase's shield appears when the boss recovers.
func test_a_phase_due_on_the_bosss_break_waits_for_the_break_to_play_out() -> void:
	var id := _boss("test_breaker", [
		_phase("one", 1.0, 1.0, 1, {"advance_on": "break"}),
		_phase("two", 1.0, 0.0, 5),
	], {"hp": 100000})
	var loc: Location = await _arena()
	var scene: BattleScene = _fight(loc, id)
	var c: BattleCoordinator = scene.coordinator
	var ctrl: BossController = scene.boss
	var boss: Node = ctrl.actor
	var crono: Node = c.unit_by_id(&"crono")
	CombatantStats.of(crono).weapon_hits = 3
	CombatantStats.of(crono).weapon_tags = [&"SWORD"]
	check(_window_for(c, crono), "Crono gets a window")
	var hits: Array = []
	c.strike_resolved.connect(func(_a: Node, _t: Node, info: Dictionary) -> void: hits.append(info))
	c.cmd_attack(crono, boss, 0)
	check_eq(hits.size(), 3, "three sword strikes resolved")
	check(bool(hits[0].get("break", false)), "the first strike Breaks phase one")
	check(bool(hits[1].get("crit", false)) and bool(hits[2].get("crit", false)), "the strikes after it land on a Broken boss (criticals)")
	check_eq(int(hits[1].get("shave", -1)), 0, "and shave no new plate")
	check_eq(ctrl.phase_index, 0, "the phase has not changed during the Break")
	check(ShieldComponent.of(boss).is_broken and ShieldComponent.of(boss).max_shield == 1, "the old plates stay down")
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 0, "nor while the Break is still playing")
	_play_out_break(c, boss)
	check(not ShieldComponent.of(boss).is_broken, "the Break played out")
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 1, "phase two began when the boss recovered")
	check_eq(ShieldComponent.of(boss).max_shield, 5, "with its own plates")
	check(await _end(loc, true), "the battle ends")


## BATTLE-8: one action across two windows still plays every phase in order; a sealed phase holds until paid.
func test_every_window_is_entered_in_order_and_a_seal_holds() -> void:
	var id := _boss("test_windows", [
		_phase("a", 1.0, 0.66, 2), _phase("b", 0.66, 0.33, 2, {"sealed": true}), _phase("c", 0.33, 0.0, 2),
	])
	var loc: Location = await _arena()
	var scene: BattleScene = _fight(loc, id)
	var ctrl: BossController = scene.boss
	var seen: Array[int] = []
	ctrl.phase_changed.connect(func(i: int, _p: Dictionary) -> void: seen.append(i))
	_set_ratio(ctrl.actor, 0.2)
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 1, "70% to 20% in one blow enters the sealed phase first")
	check(ctrl.is_sealed(), "and it is sealed")
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 1, "the sealed phase holds its window until the seal is paid")
	ctrl.set_sealed(false)
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 2, "then the next window opens")
	check_eq(seen, [1, 2] as Array[int], "each phase was entered, in order")
	check(await _end(loc, true), "the battle ends")


## BATTLE-5: a fight ended by the final Break pays the boss's XP and drops, after the action resolves.
func test_final_break_pays_xp_and_drops_after_the_action() -> void:
	var id := _boss("test_final", [_phase("only", 1.0, 1.0, 1, {"advance_on": "break"})], {"xp": 60, "drops": ["test_relic_zz"], "hp": 100000})
	var loc: Location = await _arena()
	var scene: BattleScene = _fight(loc, id)
	var c: BattleCoordinator = scene.coordinator
	var boss: Node = scene.boss.actor
	var crono: Node = c.unit_by_id(&"crono")
	CombatantStats.of(crono).weapon_hits = 2
	CombatantStats.of(crono).weapon_tags = [&"SWORD"]
	check(_window_for(c, crono), "Crono gets a window")
	var order: Array[String] = []
	c.strike_resolved.connect(func(a: Node, _t: Node, _i: Dictionary) -> void:
		if a == crono:
			order.append("hit"))
	c.battle_ended.connect(func(_v: bool, _s: Dictionary) -> void: order.append("end"))
	c.cmd_attack(crono, boss, 0)
	check(scene.boss.ended, "the last phase's Break ends the fight")
	check(Game.relics.has(&"test_relic_zz"), "and gives the boss's drops")
	check(CombatantStats.of(boss).is_alive(), "the boss is left standing")
	await get_tree().process_frame
	check_eq(order, ["hit", "hit", "end"] as Array[String], "the battle ends once the action has resolved")
	check(bool(c.last_summary.get("victory", false)) and String(c.last_summary.get("reason", "")) == "final_break", "a victory by final Break")
	var xp: Dictionary = c.last_summary.get("xp", {})
	check_eq(int(xp.get(&"crono", {}).get("xp", 0)), 60, "Crono is paid the boss's 60 XP")
	check(await _end(loc, true), "the scene closes")


# ---------------------------------------------------------------- gates and branches

## BATTLE-24: "arm_broken" opens when one of the boss's adds Breaks, "adds_defeated" when every add is down.
func test_generic_gates_open_on_their_adds() -> void:
	var id := _boss("test_gates", [
		_phase("arms", 1.0, 1.0, 3, {"advance_on": "arm_broken"}),
		_phase("wave", 1.0, 1.0, 3, {"advance_on": "adds_defeated"}),
		_phase("body", 1.0, 0.0, 3),
	], {"adds": [{"key": "porcelain_shardling", "count": 2, "phase": "arms"}, {"key": "moss_mouse", "count": 2, "phase": "wave"}]})
	var loc: Location = await _arena()
	var scene: BattleScene = _fight(loc, id)
	var ctrl: BossController = scene.boss
	check_eq(ctrl.adds_alive.size(), 2, "the arms phase places its two adds")
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 0, "nothing opens the gate yet")
	var arm: Node = ctrl.adds_alive[0]
	ShieldComponent.of(arm).force_break(null, [&"SWORD"])
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 1, "one arm Broken opens the arm_broken gate")
	var wave: Array = ctrl.adds_alive.filter(func(a: Node) -> bool: return CombatantStats.of(a).actor_id == &"moss_mouse")
	check_eq(wave.size(), 2, "the wave phase places its adds")
	for a in ctrl.adds_alive.duplicate():
		CombatantStats.of(a).apply_damage(999999, true)
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 2, "every add down opens the adds_defeated gate")
	check(await _end(loc, true), "the battle ends")


## BATTLE-24: a director gate on the last phase (the mercy and lullaby endings) ends the fight when it opens, with XP.
func test_a_gated_last_phase_ends_the_fight_when_its_gate_opens() -> void:
	var id := _boss("test_last_gate", [_phase("fight", 1.0, 0.5, 2), _phase("mercy", 0.5, 0.0, 0, {"advance_on": "scripted"})], {"xp": 30})
	var loc: Location = await _arena()
	var scene: BattleScene = _fight(loc, id)
	var c: BattleCoordinator = scene.coordinator
	var ctrl: BossController = scene.boss
	_set_ratio(ctrl.actor, 0.4)
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 1, "the mercy phase begins")
	_set_ratio(ctrl.actor, 0.01)
	ctrl.check_advance()
	check(not ctrl.ended, "HP alone never ends a gated phase")
	ctrl.open_gate()
	ctrl.check_advance()
	check(ctrl.ended, "its director opening the gate ends the fight")
	await get_tree().process_frame
	check_eq(String(c.last_summary.get("reason", "")), "scripted", "with the gate as the reason")
	check_eq(int(c.last_summary.get("xp", {}).get(&"crono", {}).get("xp", 0)), 30, "and the boss's XP")
	check(await _end(loc, true), "the scene closes")


## DATA-4 / BATTLE-23: R-66Y at 49% enters the zero-width Possibility Branch: the clock freezes (State.BRANCH),
## the question is asked, the flag is written at once, and Heart Expose begins at the window the branch sets.
func test_possibility_branch_freezes_asks_and_writes_the_flag() -> void:
	var loc: Location = await _arena()
	Story.auto_advance_s = 0.01
	Story.auto_choice = 0
	Story.skip_waits = true
	var scene: BattleScene = _fight(loc, &"r66y")
	var c: BattleCoordinator = scene.coordinator
	var ctrl: BossController = scene.boss
	c.advance(0.001)
	check_eq(c.state, BattleCoordinator.State.TICK, "the clock is running")
	var states: Array[int] = []
	c.possibility_branch.connect(func(_id: StringName, _o: Array) -> void: states.append(c.state))
	_set_ratio(ctrl.actor, 0.49)
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 1, "R-66Y enters the Possibility Branch")
	await _wait_transition(ctrl)
	check_eq(states, [BattleCoordinator.State.BRANCH] as Array[int], "the timeline froze in State.BRANCH for the question")
	check(c.state != BattleCoordinator.State.BRANCH, "and runs again after the answer")
	check_eq(ctrl.branch_choice, "mercy", "the first option (Lullaby Rewind) was chosen")
	check(Flags.is_state(&"R66Y", &"Rewound"), "its flag is written at once")
	_set_ratio(ctrl.actor, 0.45)
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 1, "after the Mercy Rewind the heart waits for 40%")
	_set_ratio(ctrl.actor, 0.39)
	ctrl.check_advance()
	check_eq(ctrl.phase_index, 2, "Heart Expose begins below 40%")
	check_eq(ShieldComponent.of(ctrl.actor).max_shield, 8, "with the Rewound 8 plates")
	check(await _end(loc, true), "the battle ends")
	Game.new_game()


## DATA-2: the Krona duel ends at 50% (the boss yields, paying its XP); the overcharge in ch2_duel_mid Breaks
## her outright and ends it at once.
func test_krona_duel_yields_at_half_or_on_the_overcharge() -> void:
	for pick in [1, 0]:
		var loc: Location = await _arena()
		Story.auto_advance_s = 0.01
		Story.auto_choice = pick
		Story.skip_waits = true
		var scene: BattleScene = _fight(loc, &"krona_duel")
		var c: BattleCoordinator = scene.coordinator
		var ctrl: BossController = scene.boss
		_set_ratio(ctrl.actor, 0.49)
		ctrl.check_advance()
		check_eq(ctrl.phase_index, 1, "49%% enters She Ate the Star first (choice %d)" % pick)
		await _wait_transition(ctrl)
		ctrl.check_advance()
		check(ctrl.ended, "the duel is over (choice %d)" % pick)
		await get_tree().process_frame
		var why: String = String(c.last_summary.get("reason", ""))
		check(bool(c.last_summary.get("victory", false)), "as a victory (choice %d)" % pick)
		check_eq(why, "yield" if pick == 1 else "overcharge", "Hold lets it run to 50%; the overcharge ends it")
		check(int(c.last_summary.get("xp", {}).get(&"crono", {}).get("xp", 0)) > 0, "Krona's XP is paid (choice %d)" % pick)
		check(await _end(loc, true), "the scene closes")
		_cleanup()


# ---------------------------------------------------------------- adds in a fight

## DATA-3: triggered rows spawn on their trigger, every_<N>pct_hp_lost rows on each N% lost, respawn_s rows come
## back after their delay; the cap is the largest authored count.
func test_adds_spawn_on_triggers_hp_loss_and_respawn() -> void:
	var id := _boss("test_adds", [_phase("p", 1.0, 0.0, 3)], {"adds": [
		{"key": "porcelain_shardling", "count": 5, "phase": "p"},
		{"key": "moss_mouse", "count": 1, "phase": "p", "trigger": "surrender_order", "shield": 7, "level": 9},
		{"key": "ashen_ashigaru", "count": 1, "phase": "p", "trigger": "every_20pct_hp_lost", "respawn_s": 2.0},
	]})
	var loc: Location = await _arena()
	var scene: BattleScene = _fight(loc, id)
	var c: BattleCoordinator = scene.coordinator
	var ctrl: BossController = scene.boss
	var count := func(key: StringName) -> int:
		return c.living_enemies().filter(func(e: Node) -> bool: return CombatantStats.of(e).actor_id == key).size()
	check_eq(count.call(&"porcelain_shardling"), 5, "an authored five are placed (cap = the largest count)")
	check_eq(count.call(&"moss_mouse"), 0, "a triggered row waits")
	check_eq(ctrl.spawn_triggered("surrender_order"), 1, "and comes on its trigger")
	var mouse: Node = c.living_enemies().filter(func(e: Node) -> bool: return CombatantStats.of(e).actor_id == &"moss_mouse")[0]
	check_eq(ShieldComponent.of(mouse).max_shield, 7, "with the row's shield override")
	check_eq(CombatantStats.of(mouse).level, 9, "and its level override")
	c.advance(0.001)
	_set_ratio(ctrl.actor, 0.79)
	ctrl._process(0.0)
	check_eq(count.call(&"ashen_ashigaru"), 1, "20% lost brings one Ashigaru")
	ctrl._process(0.0)
	check_eq(count.call(&"ashen_ashigaru"), 1, "once per step")
	var ashi: Node = c.living_enemies().filter(func(e: Node) -> bool: return CombatantStats.of(e).actor_id == &"ashen_ashigaru")[0]
	CombatantStats.of(ashi).apply_damage(999999, true)
	check_eq(count.call(&"ashen_ashigaru"), 0, "the Ashigaru falls")
	c.battle_time += 1.0
	ctrl._process(0.0)
	check_eq(count.call(&"ashen_ashigaru"), 0, "not back before its respawn_s")
	c.battle_time += 1.5
	ctrl._process(0.0)
	check_eq(count.call(&"ashen_ashigaru"), 1, "back after it")
	check(await _end(loc, true), "the battle ends")


# ---------------------------------------------------------------- directors and presentation

## BATTLE-15: the first Break shows Sera's bestiary break line, never the file's design note; once per fight.
func test_break_shows_the_break_line_not_the_design_note() -> void:
	var loc: Location = await _arena()
	var scene: BattleScene = _fight(loc, &"goyama_ashen_daimyo")
	var ctrl: BossController = scene.boss
	var line: String = String(Data.bestiary(&"goyama_ashen_daimyo").get("break_line", ""))
	check(line != "", "the Daimyo has a break line")
	ShieldComponent.of(ctrl.actor).force_break(null, [&"VITREOUS"])
	var shown: String = scene.hud.message_label.text
	check_eq(shown, "Sera: %s" % line, "the Break shows Sera's line")
	check(not shown.contains("Sets Daimyo_Phase1"), "not the design note")
	ShieldComponent.of(ctrl.actor).reset_shields()
	scene.hud.show_message("-")
	ShieldComponent.of(ctrl.actor).force_break(null, [&"VITREOUS"])
	check_eq(scene.hud.message_label.text, "-", "the line is said once per fight")
	check(await _end(loc, true), "the battle ends")


## BATTLE-10: a perfect parry opens the Prismatic window only when it is the Cradle's own Crack-Slide; the action is
## forgotten once it has resolved. BATTLE-13: the gold leaf runs on battle time and returns to the home canvas, also
## on a loss. BATTLE-14: the widening crack is paid by Crono's component and mirrored into Game.
func test_cradle_director_parry_gold_leaf_and_crack() -> void:
	var loc: Location = await _arena()
	var scene: BattleScene = _fight(loc, &"atrium_cradle")
	var c: BattleCoordinator = scene.coordinator
	var ctrl: BossController = scene.boss
	var crono: Node = c.unit_by_id(&"crono")
	var td := TimeDebtComponent.of(crono)
	var before: float = td.integrity
	ctrl.director.on_break(ctrl, [&"SWORD"] as Array[StringName])
	check_near(td.integrity, before - 3.0, 0.001, "the blade Break costs Crono 3 integrity")
	check_near(Game.crono_integrity, td.integrity, 0.001, "and Game mirrors the component")
	var spawned: Array[CombatActor] = ctrl._spawn_row(0)
	check_eq(spawned.size(), 2, "two Shardlings stand beside the Cradle")
	ctrl.phase_index = 2
	ctrl._on_enemy_action(ctrl.actor, {"id": "crack_slide"})
	c.strike_resolved.emit(spawned[0], crono, {"parried": true})
	check(not ctrl.window_open(&"prismatic"), "a Shardling's parried hit opens nothing, whatever the Cradle last chose")
	c.strike_resolved.emit(ctrl.actor, crono, {"parried": true})
	check(ctrl.window_open(&"prismatic"), "a perfect parry on the Cradle's Crack-Slide opens the Prismatic window")
	ctrl.window_until = 0.0
	ctrl._on_action({"kind": "enemy", "attacker": ctrl.actor})
	check(ctrl.last_enemy_action.is_empty(), "the boss's action is forgotten once it has resolved")
	c.strike_resolved.emit(ctrl.actor, crono, {"parried": true})
	check(not ctrl.window_open(&"prismatic"), "so a later parry is not credited to a stale Crack-Slide")
	var home: int = Universe.target
	ctrl.director.on_break(ctrl, [&"DARK"] as Array[StringName])
	check_eq(Universe.current, 7, "a phase-3 Break swaps to U7 gold leaf")
	c.battle_time += 2.9
	ctrl.director.on_tick(ctrl, 0.0)
	check_eq(Universe.target, 7, "still gold leaf at 2.9 battle seconds")
	c.battle_time += 0.2
	ctrl.director.on_tick(ctrl, 0.0)
	check_eq(Universe.target, home, "back to the home canvas after 3")
	ctrl.director.on_break(ctrl, [&"DARK"] as Array[StringName])
	check(await _end(loc, false), "a loss inside the gold leaf")
	check_eq(Universe.target, home, "still puts the canvas back")
	Universe.set_universe(home, true)


## BATTLE-20: the split dolls fold back into the Shard Doll: no statue, no XP, out of the fight.
func test_fold_add_leaves_without_a_kills_rewards() -> void:
	var id := _boss("test_fold", [_phase("p", 1.0, 0.0, 3)], {"adds": [{"key": "porcelain_shardling", "count": 2, "phase": "p"}]})
	var loc: Location = await _arena()
	var scene: BattleScene = _fight(loc, id)
	var c: BattleCoordinator = scene.coordinator
	var ctrl: BossController = scene.boss
	var doll: CombatActor = ctrl.adds_alive[0]
	ShieldComponent.of(doll).force_break(null, [&"SWORD"])
	ShieldComponent.of(doll).extend_lock(1.0e6)
	c.undamageable.append(doll)
	ctrl.fold_add(doll)
	check(not CombatantStats.of(doll).is_alive() and not c.living_enemies().has(doll), "the folded doll is out of the fight")
	check(not doll.statue, "it stands no gold statue")
	check(not c.undamageable.has(doll), "its seal is lifted")
	check_eq(CombatantStats.of(doll).xp_reward, 0, "and it pays no XP")
	check(await _end(loc, true), "the battle ends")
