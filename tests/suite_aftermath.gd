## What a battle leaves on the field (BattleAftermath, EncounterZone.settle, WithdrawRules, BattleRoster's
## write-back, Game's guest rows): revive on a win, Withdraw as its own outcome, spared and Broken enemies,
## story-battle bodies, the Game ledger between battles, cast collision and engagement advantage by facing.
## The field tests build the test arena (scenes/test/arena.tscn) and run real BattleScenes to their end.
extends "res://tests/suite_base.gd"

const ARENA := "res://scenes/test/arena.tscn"


func _arena(ids: Array[StringName]) -> Location:
	Game.new_game()
	Game.set_party(ids)
	var loc: Location = (load(ARENA) as PackedScene).instantiate()
	root.add_child(loc)
	_track(loc)
	loc.place_party(&"start")
	await get_tree().process_frame
	return loc


## Start the arena zone's fight as a contact would; the clock is driven by hand.
func _zone_battle(loc: Location) -> EncounterZone:
	var z: EncounterZone = loc.zones[0]
	z.active = false
	loc._on_zone_triggered(z, "normal")
	loc.battle.coordinator.auto_tick = false
	return z


## Wait (real time, sped up) until the Location has run its end-of-battle hand-off.
func _await_finished(loc: Location, max_s: float = 8.0) -> bool:
	Engine.time_scale = 4.0
	var t: float = 0.0
	while loc.battle != null and t < max_s:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	await get_tree().process_frame
	Engine.time_scale = 1.0
	return loc.battle == null


func _end(loc: Location, victory: bool) -> bool:
	loc.battle.coordinator.force_end(victory)
	return await _await_finished(loc)


func _actor(loc: Location, id: StringName) -> CombatActor:
	return loc.get_actor(id) as CombatActor


func _boss_bodies(loc: Location) -> int:
	var n: int = 0
	for c in loc.get_children():
		if c is CombatActor and c.has_meta("boss_id") and not c.is_queued_for_deletion():
			n += 1
	return n


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


# ---------------------------------------------------------------- the party after a battle

## GAP1-1: a member KO'd in a won battle stands up at 1 HP, visible, opaque and free to walk, and the roster
## row agrees with the body.
func test_won_battle_revives_the_fallen_at_one_hp() -> void:
	var loc: Location = await _arena([&"crono", &"sera"])
	_zone_battle(loc)
	var sera: CombatActor = _actor(loc, &"sera")
	sera.stats.apply_damage(999999, true)
	check(not sera.stats.is_alive(), "Sera is KO'd in the fight")
	await get_tree().create_timer(0.1).timeout
	check(await _end(loc, true), "the battle hands back to the field")
	await get_tree().create_timer(0.3).timeout  # die()'s fade is killed: nothing hides her again
	check(sera.stats.is_alive(), "Sera stands again after the win")
	check_eq(sera.stats.hp, 1, "at 1 HP")
	check(sera.visible, "visible")
	check_near(sera.sprite.transparency, 0.0, 0.001, "opaque (die() faded the mesh transparency)")
	check(not sera.frozen, "free to walk")
	check_near(float(Game.roster[&"sera"]["hp_ratio"]), sera.stats.hp_ratio(), 0.0001, "the roster records what the body has")
	Game.new_game()


## GAP1-9: after a lost story battle the roster records the 50% the bodies stand up with, not 30%.
func test_story_defeat_writes_back_what_the_party_stands_with() -> void:
	var loc: Location = await _arena([&"crono", &"sera"])
	loc._on_story_battle(&"kitchen_spoons", {"advantage": "normal"})
	loc.battle.coordinator.auto_tick = false
	var sera: CombatActor = _actor(loc, &"sera")
	sera.stats.apply_damage(999999, true)
	check(await _end(loc, false), "the story battle ends")
	check_near(sera.stats.hp_ratio(), 0.5, 0.02, "a scripted loss stands the fallen up at half")
	check_near(float(Game.roster[&"sera"]["hp_ratio"]), sera.stats.hp_ratio(), 0.0001, "and the roster says the same")
	Game.new_game()


## GAP1-3 / STORY-3: Story writes Game between battles (the Cradle's lost branch adds Debt, the Prologue
## sets Crono's integrity); the next battle's write-back keeps those writes.
func test_story_debt_and_integrity_survive_the_next_battle() -> void:
	var loc: Location = await _arena([&"crono", &"sera"])
	_zone_battle(loc)
	check(await _end(loc, true), "first battle ends")
	var debt_before: float = Game.sera_debt
	await Story.run(&"t_aftermath_ledger", [{"debt": 5}, {"set_integrity": 40}, {"end": true}])
	check_near(_actor(loc, &"sera").solidity.debt, debt_before + 5.0, 0.001, "Sera's body follows the story's Debt at once")
	check_near(_actor(loc, &"crono").time_debt.integrity, 40.0, 0.001, "Crono's body follows the story's integrity")
	check_eq(loc.zones[0].enemies.size(), 3, "a force-ended win leaves the arena's foes standing for a second fight")
	_zone_battle(loc)
	check(await _end(loc, true), "second battle ends")
	check(Game.sera_debt >= debt_before + 5.0 - 0.001, "the +5 Debt survived the write-back (got %.2f, before %.2f)" % [Game.sera_debt, debt_before])
	check_near(Game.crono_integrity, 40.0, 0.001, "the integrity the story set survived the write-back")
	Game.new_game()


## STORY-3 (refix): during a battle Game follows the bodies, so a Story write mid-fight (a phase script's
## `integrity: -2`) starts from the live value: the fight's own charges survive it and the write-back keeps both.
func test_story_write_mid_battle_keeps_the_fights_own_charges() -> void:
	var loc: Location = await _arena([&"crono", &"sera"])
	_zone_battle(loc)
	var crono: CombatActor = _actor(loc, &"crono")
	var sera: CombatActor = _actor(loc, &"sera")
	var start: float = Game.crono_integrity
	var debt0: float = Game.sera_debt
	crono.time_debt.pay_integrity(4.0)  # an in-battle charge, as a tech's integrity cost pays it
	sera.solidity.add_debt(2.0)
	check_near(Game.crono_integrity, start - 4.0, 0.001, "Game follows Crono's body at once")
	check_near(Game.sera_debt, debt0 + 2.0, 0.001, "and Sera's")
	await Story.run(&"t_aftermath_mid", [{"integrity": -2}, {"debt": 1}, {"end": true}])
	check_near(crono.time_debt.integrity, start - 6.0, 0.001, "the story's -2 lands on top of the fight's -4")
	check_near(sera.solidity.debt, debt0 + 3.0, 0.001, "the story's +1 Debt on top of the fight's +2")
	check(await _end(loc, true), "the battle ends")
	check_near(Game.crono_integrity, start - 6.0, 0.001, "the write-back keeps both charges")
	check_near(Game.sera_debt, debt0 + 3.0, 0.001, "and both Debts")
	check(not crono.time_debt.integrity_changed.is_connected(Game.set_integrity), "Game stops following the body at the write-back")
	Game.new_game()


## STORY-3 (refix): the Cradle's blade Break charges Crono 3 integrity once under the Game-to-body listener (the
## component pays, Game mirrors it), and the write-back keeps exactly 3, not 6.
func test_cradle_blade_break_costs_three_at_the_write_back() -> void:
	var loc: Location = await _arena([&"crono", &"sera"])
	var before: float = Game.crono_integrity
	loc._on_story_battle(&"", {"boss_id": "atrium_cradle", "boss": true, "at": "boss", "center": "center"})
	loc.battle.coordinator.auto_tick = false
	var ctrl: BossController = loc.battle.boss
	check_eq(ctrl.phase_index, 0, "the Cradle's first phase")
	ctrl.director.on_break(ctrl, [&"SWORD"] as Array[StringName])
	check_near(Game.crono_integrity, before - 3.0, 0.001, "Game shows the 3 at once")
	check_near(_actor(loc, &"crono").time_debt.integrity, before - 3.0, 0.001, "and so does his body")
	check(await _end(loc, true), "the fight is won")
	check_near(Game.crono_integrity, before - 3.0, 0.001, "the write-back keeps exactly 3")
	Game.new_game()


# ---------------------------------------------------------------- withdraw

## BATTLE-6 / COMBAT-2 / GAP1-2: Withdraw falls back toward the nearest edge over the ally's turns and
## succeeds at the edge with no enemy above 80; the outcome is not a defeat (no integrity).
func test_withdraw_falls_back_then_leaves_without_integrity() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 5, Vector3(0, 0, 4.5))
	var e := _enemy(&"mote", 3, Vector3(0, 0, -4), 2, [&"SWORD"])
	_start(c, [crono], [e])
	var before: float = TimeDebtComponent.of(crono).integrity
	check(WithdrawRules.offered(c), "offered in a field fight")
	check(_window_for(c, crono), "Crono gets a window")
	c.gauges[e] = 0.0
	var r1: Dictionary = c.cmd_withdraw(crono)
	check(bool(r1.get("ok", false)) and not bool(r1.get("withdrew", true)), "the first try is a fall-back, not a withdraw")
	check_near(crono.global_position.z, 10.5, 0.01, "moved 6 m (his move range) toward the near edge")
	check(c.state != BattleCoordinator.State.IDLE, "the battle goes on")
	check(_window_for(c, crono), "Crono's next window")
	c.gauges[e] = 0.0
	var r2: Dictionary = c.cmd_withdraw(crono)
	check(bool(r2.get("withdrew", false)), "within 2 m of the edge the withdraw succeeds")
	check_near(crono.global_position.z, 13.0, 0.01, "he stopped 1 m inside the edge")
	check_eq(String(c.last_summary.get("reason", "")), "withdraw", "the summary names the outcome")
	check_near(float(c.last_summary.get("integrity_lost", -1.0)), 0.0, 0.0001, "no integrity lost")
	check_near(TimeDebtComponent.of(crono).integrity, before, 0.0001, "Crono's integrity is untouched")
	check(c.last_summary.get("withdraw_at", null) is Vector3, "the withdraw point travels with the summary")
	check_eq(BattleAftermath.outcome(false, c.last_summary), BattleAftermath.WITHDRAW, "the aftermath reads it as a withdraw")


func test_withdraw_at_the_edge_fails_while_an_enemy_is_above_80() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 5, Vector3(0, 0, 13.0))
	var e := _enemy(&"mote", 3, Vector3(0, 0, -4), 2, [&"SWORD"])
	_start(c, [crono], [e])
	check(_window_for(c, crono), "Crono gets a window")
	c.gauges[e] = 85.0
	var r: Dictionary = c.cmd_withdraw(crono)
	check(bool(r.get("ok", false)) and not bool(r.get("withdrew", true)) and bool(r.get("reached_edge", false)), "at the edge, but an enemy above 80 stops it")
	check(c.state != BattleCoordinator.State.IDLE and c.active_actor != crono, "the attempt cost the turn")


func test_withdraw_is_refused_in_boss_and_story_battles() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 5, Vector3(0, 0, 13.0))
	var e := _enemy(&"mote", 3, Vector3(0, 0, -4), 2, [&"SWORD"])
	_start(c, [crono], [e], {"story": true})
	check(not WithdrawRules.offered(c), "a story battle offers no Withdraw")
	check(_window_for(c, crono), "Crono gets a window")
	check(not bool(c.cmd_withdraw(crono).get("ok", true)), "and the command is refused")
	var c2 := _coord(9)
	var crono2 := _party_member(&"crono", 5, Vector3(0, 0, 13.0))
	var e2 := _enemy(&"mote", 3, Vector3(0, 0, -4), 2, [&"SWORD"])
	_start(c2, [crono2], [e2], {"boss": true})
	check(not WithdrawRules.offered(c2), "a boss fight offers no Withdraw (§4.2)")


## GAP1-2 / GAP1-5 in the field: a withdraw runs no defeat flow (the party stays where it fell back, the
## integrity is kept) and the zone's enemies stand at full strength, un-Broken, back on their routes.
func test_field_withdraw_keeps_the_party_and_resets_the_zone() -> void:
	var loc: Location = await _arena([&"crono"])
	var z: EncounterZone = _zone_battle(loc)
	var c: BattleCoordinator = loc.battle.coordinator
	c.party_hp_floor = 1  # nobody falls while the turns go by
	var crono: CombatActor = _actor(loc, &"crono")
	var integrity: float = Game.crono_integrity
	var mote: CombatActor = z.enemies[0]
	mote.shield.force_break(crono)
	mote.stats.hp = maxi(1, mote.stats.max_hp() / 3)
	var withdrew: bool = false
	for i in 4:
		if not _window_for(c, crono):
			break
		for e in c.enemies:
			c.gauges[e] = 0.0
		if bool(c.cmd_withdraw(crono).get("withdrew", false)):
			withdrew = true
			break
	check(withdrew, "Crono withdraws within a few turns")
	check(await _await_finished(loc), "the battle hands back to the field")
	check_near(Game.crono_integrity, integrity, 0.0001, "a withdraw costs no integrity")
	check(crono.global_position.distance_to(loc.get_marker(&"start")) > 1.0, "no defeat jump to the spawn marker")
	check(z.enemies.has(mote) and is_instance_valid(mote), "the Broken mote is still in the zone")
	check_eq(mote.stats.hp, mote.stats.max_hp(), "back at full strength")
	check(not mote.shield.is_broken and not mote.frozen, "un-Broken and free to wander")
	check(not mote.break_hull.visible, "its Break hull is down")
	check(z.active, "the zone is armed again")
	Game.new_game()


# ---------------------------------------------------------------- enemies after a battle

## GAP1-4: a spared enemy leaves the zone alive (Combat Laws 4.2) instead of standing there invisible.
func test_spared_enemy_leaves_the_zone() -> void:
	var loc: Location = await _arena([&"crono"])
	var z: EncounterZone = _zone_battle(loc)
	var c: BattleCoordinator = loc.battle.coordinator
	var crono: CombatActor = _actor(loc, &"crono")
	var spared: CombatActor = z.enemies[0]
	spared.shield.force_break(crono)
	spared.stats.hp = 1
	check(_window_for(c, crono), "Crono gets a window")
	check(bool(c.cmd_spare(crono, spared).get("ok", false)), "the Broken, low enemy is spared")
	for e in c.enemies:
		if e != spared:
			CombatantStats.of(e).apply_damage(999999, true)
	check(await _end(loc, true), "the battle hands back to the field")
	check(not is_instance_valid(spared) or spared.is_queued_for_deletion(), "the spared enemy's body is gone")
	check(z.enemies.all(func(e: CombatActor) -> bool: return is_instance_valid(e) and e != spared), "and it is no longer the zone's")
	check(not z.active, "nothing is left to fight here")
	Game.new_game()


## GAP1-5 and Combat Laws 16.1: a field defeat resets the zone (the fallen and the Broken stand again at
## full strength) and stands the party up at the 30% floor at the spawn marker.
func test_field_defeat_resets_enemies_and_floors_the_party() -> void:
	var loc: Location = await _arena([&"crono"])
	var z: EncounterZone = _zone_battle(loc)
	var crono: CombatActor = _actor(loc, &"crono")
	var broken: CombatActor = z.enemies[0]
	var killed: CombatActor = z.enemies[1]
	broken.shield.force_break(crono)
	broken.stats.hp = maxi(1, broken.stats.max_hp() / 2)
	killed.stats.apply_damage(999999, true)
	crono.stats.apply_damage(999999, true)
	check(await _end(loc, false), "the lost battle hands back to the field")
	check_eq(z.enemies.size(), 3, "the jump back keeps every foe of the encounter")
	for e in [broken, killed]:
		check(is_instance_valid(e) and e.stats.hp == e.stats.max_hp(), "%s at full strength" % e.name)
		check(e.visible and not e.frozen and not e.shield.is_broken, "%s standing, un-Broken" % e.name)
		check_near(e.sprite.transparency, 0.0, 0.001, "%s opaque" % e.name)
	check(crono.stats.is_alive() and crono.stats.hp_ratio() >= 0.29, "Crono stands at the defeat floor")
	check(crono.global_position.distance_to(loc.get_marker(&"start")) < 0.5, "Sera's jump puts the party at the spawn")
	Game.new_game()


## Combat Laws 16.5 and DECISIONS "Ruin is battle-scoped": a zone enemy that took Ruin stacks comes back after a
## defeat or a withdraw at its whole ceiling, not refilled to the Ruin-lowered one (BattleAftermath.restore_enemy).
func test_a_ruined_zone_enemy_comes_back_at_its_whole_ceiling() -> void:
	for outcome in [BattleAftermath.DEFEAT, BattleAftermath.WITHDRAW]:
		var loc: Location = await _arena([&"crono"])
		var z: EncounterZone = _zone_battle(loc)
		var c: BattleCoordinator = loc.battle.coordinator
		var ruined: CombatActor = z.enemies[0]
		var base: int = ruined.stats.base_max_hp
		check(StatusRules.apply(c, ruined, &"ruin", -1.0, -1, 3), "%s: Ruin lands on the enemy" % outcome)
		check(ruined.stats.max_hp() < base, "%s: three stacks lower its ceiling" % outcome)
		ruined.stats.hp = maxi(1, ruined.stats.max_hp() / 2)
		if outcome == BattleAftermath.DEFEAT:
			_actor(loc, &"crono").stats.apply_damage(999999, true)
			check(await _end(loc, false), "the lost battle hands back to the field")
		else:
			c._finish(false, "withdraw")
			check(await _await_finished(loc), "the withdraw hands back to the field")
		check(z.enemies.has(ruined) and is_instance_valid(ruined), "%s: the Ruined enemy stays in the zone" % outcome)
		check(not ruined.statuses.has(&"ruin"), "%s: its Ruin is gone" % outcome)
		check_eq(ruined.stats.max_hp(), base, "%s: its ceiling is whole again" % outcome)
		check_eq(ruined.stats.hp, base, "%s: and it stands at full strength under it" % outcome)
	Game.new_game()


## GAP1-6 / BATTLE-18: story-battle bodies (the boss and its adds) are freed after the battle, so a retry
## spawns one boss, not a second on top of the first.
func test_story_battle_bodies_are_freed_and_a_retry_does_not_stack() -> void:
	var loc: Location = await _arena([&"crono", &"sera"])
	var cmd: Dictionary = {"boss_id": "atrium_cradle", "boss": true, "at": "boss", "center": "center"}
	loc._on_story_battle(&"", cmd)
	loc.battle.coordinator.auto_tick = false
	var fought: Array = loc.battle.enemies.duplicate()
	check_eq(_boss_bodies(loc), 1, "one Cradle on the first attempt")
	check(await _end(loc, false), "the first attempt is lost")
	await get_tree().process_frame
	for e in fought:
		check(not is_instance_valid(e), "%s was freed after the battle" % ("a body" if not is_instance_valid(e) else e.name))
	loc._on_story_battle(&"", cmd)
	loc.battle.coordinator.auto_tick = false
	check_eq(_boss_bodies(loc), 1, "the retry spawns one Cradle, not two")
	check(await _end(loc, true), "the retry is won")
	await get_tree().process_frame
	check_eq(_boss_bodies(loc), 0, "no Cradle body is left after the win")
	Game.new_game()


## BATTLE-18: a fallen add leaves the boss's adds_alive on the next summon; the living stay tracked.
func test_dead_adds_are_pruned_on_the_next_summon() -> void:
	var loc: Location = await _arena([&"crono", &"sera"])
	loc._on_story_battle(&"", {"boss_id": "atrium_cradle", "boss": true, "at": "boss", "center": "center"})
	loc.battle.coordinator.auto_tick = false
	var ctrl: BossController = loc.battle.boss
	var first: Array[CombatActor] = ctrl._spawn_row(0)
	check_eq(ctrl.adds_alive.size(), 2, "two Shardlings are tracked")
	first[0].stats.apply_damage(999999, true)
	var again: Array[CombatActor] = ctrl._spawn_row(0, 1)
	check(not ctrl.adds_alive.has(first[0]), "the fallen Shardling is pruned")
	check(ctrl.adds_alive.has(first[1]), "the living one is kept")
	check_eq(ctrl.adds_alive.size(), 1 + again.size(), "beside whatever the summon brought")
	check(await _end(loc, true), "the battle ends")
	Game.new_game()


## restore_body() undoes on_break() whole: the NavigationAgent's avoidance comes back as the Break found it and the
## Break hull is neither shown nor detectable (it is terrain only while Broken or a statue).
func test_restore_body_hands_back_avoidance_and_drops_the_hull() -> void:
	var e := CombatActor.create_enemy(Data.enemy(&"ashen_spoon"))
	root.add_child(e)
	_track(e)
	check(not e.break_hull.monitorable and not e.break_hull.visible, "an unbroken body's hull is down")
	e.nav.avoidance_enabled = true
	e.on_break()
	check(not e.nav.avoidance_enabled and e.break_hull.monitorable and e.break_hull.visible, "Broken: avoidance off, the hull up")
	e.restore_body()
	check(e.nav.avoidance_enabled, "restored: avoidance on again, as the Break found it")
	check(not e.break_hull.monitorable and not e.break_hull.visible, "and the hull down")
	e.nav.avoidance_enabled = false
	e.on_break()
	e.on_recover()
	check(not e.nav.avoidance_enabled and not e.break_hull.monitorable, "a body that had no avoidance gets none from a recovery")


## GAP1-10: a story battle asked for during a battle spawns nothing and releases the script that waits on it.
func test_story_battle_during_a_battle_is_skipped() -> void:
	var loc: Location = await _arena([&"crono"])
	_zone_battle(loc)
	var before: int = loc.get_child_count()
	var asked: Array = []
	var done: Array = []
	var on_request := func(id: StringName, _cmd: Dictionary) -> void: asked.append(id)
	var on_done := func(id: StringName) -> void: done.append(id)
	Story.battle_requested.connect(on_request)
	Story.script_finished.connect(on_done)
	Story.run(&"t_aftermath_busy", [{"battle": "kitchen_spoons", "boss_id": "atrium_cradle"}, {"end": true}])
	await get_tree().process_frame
	await get_tree().process_frame
	Story.battle_requested.disconnect(on_request)
	Story.script_finished.disconnect(on_done)
	check_eq(asked, [&"kitchen_spoons"], "the script asked for its battle (and waits on it)")
	check_eq(loc.get_child_count(), before, "no bodies spawned beside the running fight")
	check(done.has(&"t_aftermath_busy") and not Story._battle_waiting and not Story.is_running(), "the waiting script is released and runs to its end")
	check_eq(String(Story.battle_result.get("reason", "")), "busy", "with a 'busy' result (neither won nor lost)")
	check(await _end(loc, true), "the running battle still ends normally")
	Game.new_game()


# ---------------------------------------------------------------- reserves, guests, cast

## GAP4-1: a reserve swapped into the party writes its XP, level and HP back like any reserve.
func test_swapped_in_reserve_is_written_back() -> void:
	Game.new_game()
	Game.recruit(&"krona")
	var ids: Array[StringName] = [&"crono"]
	Game.set_party(ids)
	var host := Node3D.new()
	root.add_child(host)
	_track(host)
	var crono := CombatActor.create_party_member(&"crono")
	host.add_child(crono)
	var r := BattleRoster.new()
	r.build(host, [crono], Vector3.ZERO)
	var krona: CombatActor = null
	for b in r.bench:
		if b.actor_id == &"krona":
			krona = b
	check(krona != null, "Krona sits on the bench")
	# a Swap: Krona leaves the bench for the party (BattleRoster.perform's bookkeeping)
	r.bench.erase(krona)
	r.bench.append(crono)
	krona.stats.xp += 500
	krona.stats.level += 2
	krona.stats.hp = maxi(1, roundi(float(krona.stats.max_hp()) * 0.2))
	var lv: int = krona.stats.level
	r.finish(0.0)
	check_eq(int(Game.roster[&"krona"]["level"]), lv, "the swapped-in reserve's level is kept")
	check_eq(int(Game.roster[&"krona"]["xp"]), krona.stats.xp, "and its XP")
	check_near(float(Game.roster[&"krona"]["hp_ratio"]), krona.stats.hp_ratio(), 0.0001, "and its HP")
	check(krona.is_queued_for_deletion(), "and it leaves with the battle")
	Game.new_game()


## GAP4-1 through the real Swap (BattleRoster.perform): the reserve that came in writes back what it ended with.
func test_swap_through_perform_writes_the_incoming_reserve_back() -> void:
	var loc: Location = await _arena([&"crono"])
	Game.recruit(&"krona")
	_zone_battle(loc)
	var scene: BattleScene = loc.battle
	var c: BattleCoordinator = scene.coordinator
	c.party_hp_floor = 1
	var crono: CombatActor = _actor(loc, &"crono")
	var benched: Array = scene.roster.bench.filter(func(b: CombatActor) -> bool: return b.actor_id == &"krona")
	check_eq(benched.size(), 1, "Krona sits on the bench")
	check(_window_for(c, crono), "Crono gets a window")
	var krona: CombatActor = benched[0] if not benched.is_empty() else null
	check(bool(scene.roster.perform(scene, crono, {"incoming": krona}).get("ok", false)), "the Swap goes through")
	check(c.party.has(krona) and scene.roster.bench.has(crono) and not scene.roster.bench.has(krona), "Krona is on the plane, Crono on the bench")
	var xp0: int = int(Game.roster[&"krona"]["xp"])
	var lv0: int = int(Game.roster[&"krona"]["level"])
	krona.stats.xp += 500
	krona.stats.hp = maxi(1, roundi(float(krona.stats.max_hp()) * 0.2))
	var seen: Dictionary = {}
	loc.battle_finished.connect(func(_v: bool) -> void: seen.merge({"xp": krona.stats.xp, "level": krona.stats.level, "hp": krona.stats.hp_ratio()}), CONNECT_ONE_SHOT)
	check(await _end(loc, true), "the battle ends")
	check(int(Game.roster[&"krona"]["level"]) > lv0 or int(Game.roster[&"krona"]["xp"]) > xp0, "the roster row moved on from before the fight")
	check_eq(int(Game.roster[&"krona"]["xp"]), int(seen.get("xp", -1)), "the roster keeps the swapped-in reserve's XP")
	check_eq(int(Game.roster[&"krona"]["level"]), int(seen.get("level", -1)), "and its level")
	check_near(float(Game.roster[&"krona"]["hp_ratio"]), float(seen.get("hp", -1.0)), 0.0001, "and its HP")
	Game.new_game()


## STORY-2 / GAP1-9: guest Marle gets a roster row (her join level, her chapter-0 Light Bolt and Ward) the
## moment she is in the party, never joins the bench, and keeps her XP.
func test_guest_marle_has_a_roster_row_and_her_techs() -> void:
	Game.new_game()
	var ids: Array[StringName] = [&"crono", &"marle", &"sera"]
	Game.set_party(ids)
	check(Game.roster.has(&"marle"), "Marle has a roster row")
	check(Game.knows_tech(&"marle", &"light_bolt") and Game.knows_tech(&"marle", &"ward"), "she knows Light Bolt and Ward")
	check(not Game.recruited.has(&"marle"), "a guest is not recruited")
	check((Game.roster[&"crono"]["known_techs"] as Array).is_empty(), "recruited members learn nothing from the guest rule (the Prologue teaches Crono in story)")
	var marle := CombatActor.create_party_member(&"marle")
	root.add_child(marle)
	_track(marle)
	marle.stats.xp = 120
	BattleAftermath.write_back(marle, 0.0)
	check_eq(int(Game.roster[&"marle"]["xp"]), 120, "her XP persists")
	var alone: Array[StringName] = [&"crono"]
	Game.set_party(alone)
	check(not Game.bench_ids().has(&"marle"), "a guest never sits on the bench")
	Game.new_game()


## STORY-2: every keyed plate of the Cradle's first phase has someone in the Prologue party who can shave it.
func test_cradle_phase_one_plates_have_a_caster_in_the_prologue_party() -> void:
	Game.new_game()
	var ids: Array[StringName] = [&"crono", &"marle", &"sera"]
	Game.set_party(ids)
	var cradle: Dictionary = Data.bosses[&"atrium_cradle"]
	var keys: Array = []
	for plate in cradle["phases"][0]["shield"]["keyed_plates"]:
		keys.append(StringName(String(plate["key"])))
	for key in keys:
		var found: bool = false
		for id in ids:
			if CombatTags.to_names(Data.character(id).get("weapon", {}).get("tags", [])).has(key):
				found = true
			for tid in Game.roster[id]["known_techs"]:
				var t: TechDef = Data.techs.get(StringName(String(tid)), null)
				if t != null and t.tags.has(key):
					found = true
		check(found, "a %s plate has a caster" % String(key))
	Game.new_game()


## WORLD-3: a cast member stands on the NPC layer (1), solid to the leader, once it is in the tree.
func test_add_cast_lands_on_the_npc_layer() -> void:
	var loc: Location = await _arena([&"crono"])
	var marle: CombatActor = loc.add_cast(&"marle", Vector3(3, 0, 3))
	check_eq(marle.collision_layer, 1, "cast actors are solid to the leader (mask 1)")
	Game.new_game()


# ---------------------------------------------------------------- engagement

## WORLD-7: Combat Laws 2.3 by facing. Enemy at the origin; +Z is south.
func test_engagement_advantage_follows_facing() -> void:
	var e := Vector3.ZERO
	var behind := Vector3(0, 0, -1)  # north of an enemy that faces south
	check_eq(EncounterZone.advantage_for(e, &"s", behind, &"s"), "preemptive", "the leader walks up behind an enemy facing away")
	check_eq(EncounterZone.advantage_for(e, &"n", behind, &"s"), "normal", "face to face")
	check_eq(EncounterZone.advantage_for(e, &"n", behind, &"n"), "ambush", "the enemy walks into the leader's back")
	check_eq(EncounterZone.advantage_for(e, &"s", behind, &"n"), "normal", "back to back: nobody touched anyone from behind")
	check_eq(EncounterZone.advantage_for(e, &"n", behind, &"s", true), "preemptive", "an asleep or stunned enemy")
	check_eq(EncounterZone.advantage_for(e, &"e", Vector3(-1, 0, 0), &"e"), "preemptive", "works on the other axis")


## WORLD-7: contact reaches a big enemy's body, and after a battle the zone re-arms only once the leader
## has stepped away.
func test_contact_uses_body_radius_and_rearms_on_separation() -> void:
	var z := EncounterZone.new()
	z.encounter_id = &"no_such_encounter_for_tests"
	root.add_child(z)
	_track(z)
	var big := CombatActor.create_enemy(Data.enemy(&"ashen_spoon"))
	root.add_child(big)
	_track(big)
	big.stats.body_radius = 1.2
	big.global_position = Vector3.ZERO
	z.enemies.append(big)
	var leader := CombatActor.create_party_member(&"crono")
	root.add_child(leader)
	_track(leader)
	leader.global_position = Vector3(0, 0, 1.6)
	var fired: Array = []
	z.triggered.connect(func(_zone: EncounterZone, adv: String) -> void: fired.append(adv))
	check(z.check_contact(leader), "1.6 m from a 1.2 m body is contact")
	check_eq(fired.size(), 1, "one trigger")
	z.settle(BattleAftermath.WITHDRAW)
	check(not z.check_contact(leader), "still touching right after the battle: no new fight")
	leader.global_position = Vector3(0, 0, 4.0)
	check(not z.check_contact(leader), "stepping away re-arms the zone")
	leader.global_position = Vector3(0, 0, 1.6)
	check(z.check_contact(leader), "touching again starts the next fight")
	check_eq(fired.size(), 2, "two triggers in all")
