## Field and combat actors (CombatActor, StatueTimers, ScriptedWalk, FieldNPC, PlayerController, PartyFollow,
## EncounterZone's wander, Location's universe and field Rewind): the 8 s Broken-kill statue counts battle time
## and shatters, a revived ally is visible again, a hit that breaks keeps the break pose, a focus release is
## never swallowed, an awaited walk always resolves, gravity lands once per tick, a Location reads its
## universe after build(), the field Rewind shows on Sera, and the body's look follows the rules (a phased Sera
## stays a ghost whatever redraws her; a Story ledger command and a reserve spawn wear the Debt at once).
extends "res://tests/suite_base.gd"

const ARENA := "res://scenes/test/arena.tscn"
const DT := 1.0 / 60.0


func _arena(ids: Array[StringName]) -> Location:
	Game.new_game()
	Game.set_party(ids)
	var loc: Location = (load(ARENA) as PackedScene).instantiate()
	root.add_child(loc)
	_track(loc)
	loc.place_party(&"start")
	await get_tree().process_frame
	return loc


## The arena zone's fight (two Ashen Spoons and a Dust Mote Cluster), the clock driven by hand.
func _zone_battle(loc: Location) -> BattleScene:
	var z: EncounterZone = loc.zones[0]
	z.active = false
	loc._on_zone_triggered(z, "normal")
	loc.battle.coordinator.auto_tick = false
	return loc.battle


func _end(loc: Location, victory: bool) -> bool:
	loc.battle.coordinator.force_end(victory)
	Engine.time_scale = 4.0
	var t: float = 0.0
	while loc.battle != null and t < 8.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	await get_tree().process_frame
	Engine.time_scale = 1.0
	return loc.battle == null


## Run `seconds` of battle time, guarding every window that opens.
func _run_battle_time(c: BattleCoordinator, seconds: float) -> void:
	var t0: float = c.battle_time
	var guard: int = 0
	while c.battle_time - t0 < seconds and guard < 200000:
		guard += 1
		if c.state == BattleCoordinator.State.COMMAND_WAIT and c.active_actor != null:
			c.cmd_guard(c.active_actor)
		elif c.state == BattleCoordinator.State.TICK:
			c.advance(DT)
		else:
			return


## Real seconds, sped up 4x.
func _wait(seconds: float) -> void:
	Engine.time_scale = 4.0
	await get_tree().create_timer(seconds).timeout
	Engine.time_scale = 1.0


func _tough(a: Node) -> void:
	var st := CombatantStats.of(a)
	st.base_max_hp = 99999
	st.hp = 99999


# ---------------------------------------------------------------- the Broken-kill statue

## BATTLE-4 / GAP1-8 (Combat Laws §5.4, §18.7 check 9): a body killed while Broken stands 8 s of battle time
## as LINE_PIERCE cover and then shatters; its Break never "recovers" on the corpse, while a living Broken
## enemy beside it still recovers after the usual 8.6 s.
func test_statue_counts_battle_time_and_shatters() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 30, Vector3(0, 0, 4))
	_tough(crono)
	var dead := _enemy(&"statue_me", 1, Vector3(-2, 0, 0), 2, [])
	var alive := _enemy(&"stays", 1, Vector3(2, 0, 0), 2, [])
	_start(c, [crono], [dead, alive])
	var recovered: Array = []
	var shattered: Array = []
	c.unit_recovered.connect(func(u: Node) -> void: recovered.append(u))
	c.statues.shattered.connect(func(u: Node) -> void: shattered.append(u))
	ShieldComponent.of(dead).force_break(crono)
	ShieldComponent.of(alive).force_break(crono)
	CombatantStats.of(dead).apply_damage(999999, true)
	check(c.statues.standing(dead), "killed while Broken: a statue")
	check_near(c.statues.time_left(dead), CombatConstants.BROKEN_STATUE_S, 0.001, "for 8 s")
	check(not c.statues.standing(alive), "the living Broken enemy is no statue")
	check_eq(CastReach.blockers(c).size(), 2, "the statue and the Broken body are both LINE_PIERCE cover")
	_run_battle_time(c, 7.9)
	check(c.statues.standing(dead), "still standing at 7.9 s")
	check_eq(CastReach.blockers(c).size(), 2, "still cover at 7.9 s")
	check(shattered.is_empty(), "nothing shattered yet")
	_run_battle_time(c, 0.9)
	check(not c.statues.standing(dead), "gone after 8 s")
	check_eq(shattered, [dead], "it shattered once")
	check(not recovered.has(dead), "the corpse's Break never ended (no unit_recovered)")
	check(ShieldComponent.of(dead).is_broken, "its shield stays where it died")
	check(recovered.has(alive), "the living Broken enemy recovered after its 8.6 s")
	check_eq(CastReach.blockers(c).size(), 0, "no cover left: the statue shattered and the other stands again")
	# a body killed while not Broken is no statue
	var c2 := _coord()
	var crono2 := _party_member(&"crono", 30, Vector3(0, 0, 4))
	var plain := _enemy(&"plain", 1, Vector3(-2, 0, 0), 2, [])
	var other := _enemy(&"other", 1, Vector3(2, 0, 0), 2, [])
	_start(c2, [crono2], [plain, other])
	CombatantStats.of(plain).apply_damage(999999, true)
	check(not c2.statues.standing(plain), "a kill that was not Broken leaves no statue")


## The same on the field: the body turns gold and frozen, never takes on_recover's white idle, and is hidden
## once its 8 s of battle time are up; the shatter plays where it stood.
func test_a_broken_kill_in_the_arena_shatters_after_eight_seconds() -> void:
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	_tough(crono)
	var e: CombatActor = c.enemies[0] as CombatActor
	e.shield.force_break(crono)
	e.stats.apply_damage(999999, true)
	check(e.statue and e.frozen and e.visible, "a gold statue stands where it died")
	check(e.break_hull.visible, "keeping the inflated hull")
	var gold: Color = e.sprite.material.get_shader_parameter("tint")
	check(gold != Color.WHITE, "gold-tinted")
	_run_battle_time(c, 7.9)
	check(e.visible and e.statue, "still a statue at 7.9 s")
	check_eq(e.sprite.material.get_shader_parameter("tint"), gold, "never tinted back by on_recover")
	_run_battle_time(c, 0.9)
	check(not e.visible and not e.statue, "shattered and gone after 8 s")
	check(not e.break_hull.visible, "its hull is down")
	check(await _end(loc, true), "the battle still ends")
	Game.new_game()


# ---------------------------------------------------------------- revive, the break pose, the HUD

## BATTLE-7 / GAP1-7: an ally the Prometheus Core stands up inside the KO is not faded out by die()'s pending
## tween, and an ally revived after the fade is visible and opaque again.
func test_a_revived_ally_is_visible_and_opaque() -> void:
	var loc: Location = await _arena([&"crono", &"sera"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	var sera: CombatActor = loc.get_actor(&"sera") as CombatActor
	c.prometheus_available = true
	crono.stats.apply_damage(999999, true)
	check(crono.stats.is_alive(), "the Prometheus Core stood Crono up")
	await _wait(1.8)
	check(crono.visible, "and he is still visible after die()'s 1.4 s")
	check_near(crono.sprite.transparency, 0.0, 0.001, "and opaque")
	check(not crono.frozen, "and free to act")
	sera.stats.apply_damage(999999, true)
	check(not sera.stats.is_alive(), "Sera falls (the Core is spent)")
	await _wait(1.8)
	check(not sera.visible, "her body faded out")
	sera.stats.revive(0.3)
	c.unit_revived.emit(sera)
	check(sera.visible, "a revive brings her back into view")
	check_near(sera.sprite.transparency, 0.0, 0.001, "opaque")
	check_near(float(sera.sprite.material.get_shader_parameter("opacity")), 1.0, 0.001, "at full opacity")
	check(not sera.frozen, "and free to act")
	check(await _end(loc, true), "the battle still ends")
	Game.new_game()


## BATTLE-22 (Combat Laws §5.4 "locked mid-step"): the hit that breaks a target does not override its break
## pose with hurt -> idle; an unbroken target still flinches. The battle-time readout is debug-only.
func test_a_hit_that_breaks_keeps_the_break_pose() -> void:
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	var broken: CombatActor = c.enemies[0] as CombatActor
	var flinch: CombatActor = c.enemies[1] as CombatActor
	for e in [broken, flinch]:
		e.sprite.anims[&"break"] = {"col": 0, "count": 1, "loop": false}
		e.sprite.anims[&"hurt"] = {"col": 0, "count": 2, "loop": false}
	broken.shield.force_break(crono)
	check_eq(broken.sprite.anim, &"break", "the Break plays the break pose")
	scene._on_strike(crono, broken, {"damage": 4, "break": true})
	check_eq(broken.sprite.anim, &"break", "the breaking hit keeps it")
	scene._on_strike(crono, flinch, {"damage": 4})
	check_eq(flinch.sprite.anim, &"hurt", "an unbroken target flinches")
	check(not scene.hud._flow_time_label.visible, "no battle-time readout outside debug mode")
	check(await _end(loc, true), "the battle still ends")
	Game.new_game()


# ---------------------------------------------------------------- focus

func _focus_event(pressed: bool) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = &"focus"
	ev.pressed = pressed
	return ev


## WORLD-4: a focus release while a battle or a cutscene holds the controls drops the 0.4x focus walk at once;
## the visuals let go when the controls come back, so a cutscene's lens is never cut.
func test_a_focus_release_is_never_swallowed() -> void:
	var loc: Location = await _arena([&"crono"])
	var ctrl: PlayerController = loc.controller
	var seen: Array = []
	ctrl.focus_changed.connect(func(on: bool) -> void: seen.append(on))
	ctrl._unhandled_input(_focus_event(true))
	check(ctrl.focusing and loc.rig.truth, "holding focus leans the camera in")
	ctrl.enabled = false  # a battle starts
	ctrl._unhandled_input(_focus_event(false))
	check(not ctrl.focusing, "the release counts while the controls are held")
	check_eq(seen, [true], "the visuals wait for the controls")
	check(loc.rig.truth, "so the lens is not cut meanwhile")
	ctrl.enabled = true  # the battle is over
	ctrl._physics_process(DT)
	check_eq(seen, [true, false], "the release reaches the location once the controls are back")
	check(not loc.rig.truth, "and the camera lets go")
	ctrl._physics_process(DT)
	check_eq(seen.size(), 2, "only once")
	ctrl._unhandled_input(_focus_event(true))
	ctrl._unhandled_input(_focus_event(false))
	check_eq(seen, [true, false, true, false], "with the controls free a release is immediate")
	Game.new_game()


# ---------------------------------------------------------------- walks

## WORLD-8: ScriptedWalk resolves on arrival, on a stall and on a creep past its time budget.
func test_scripted_walk_watchdog() -> void:
	var w := ScriptedWalk.new(Vector3.ZERO, Vector3(3, 0, 0), 3.0, 0.12)
	var v: Vector3 = w.step(Vector3.ZERO, DT)
	check_near(v.length(), 3.0, 0.001, "walks at its speed")
	check(not w.done(), "under way")
	w.step(Vector3(2.95, 0, 0), DT)
	check_eq(w.result, ScriptedWalk.ARRIVED, "arrives within its radius")
	var stuck := ScriptedWalk.new(Vector3.ZERO, Vector3(3, 0, 0), 3.0, 0.12)
	var t: float = 0.0
	while not stuck.done() and t < 5.0:
		stuck.step(Vector3(1.0, 0, 0), DT)
		t += DT
	check_eq(stuck.result, ScriptedWalk.STALLED, "no headway ends the walk")
	check_near(t, ScriptedWalk.STALL_S, 0.05, "after STALL_S")
	var creep := ScriptedWalk.new(Vector3.ZERO, Vector3(3, 0, 0), 3.0, 0.12)
	var x: float = 0.0
	t = 0.0
	while not creep.done() and t < 10.0:
		x += 0.002  # 0.12 m/s of headway: progress, but far slower than the 3 m/s the walk was budgeted for
		creep.step(Vector3(x, 0, 0), DT)
		t += DT
	check_eq(creep.result, ScriptedWalk.TIMEOUT, "a creep past distance/speed + grace is called off")
	check_near(t, 1.0 + ScriptedWalk.GRACE_S, 0.05, "at distance / speed + GRACE_S")


## WORLD-8: a CombatActor walking into a crate and a frozen FieldNPC both resolve their awaited walk.
func test_awaited_walks_always_resolve() -> void:
	var loc: Location = await _arena([&"crono"])
	for z in loc.zones:
		z.active = false
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	crono.global_position = Vector3(-10.0, 0.0, -9.0)  # Crate0 stands at (-10, 0.4, -12)
	crono.reset_physics_interpolation()
	var ended: Array = []
	crono.arrived.connect(func() -> void: ended.append(crono.global_position))
	crono.walk_to(Vector3(-10.0, 0.0, -15.0), 3.6)
	check(crono.is_walking(), "Crono walks toward the crate")
	var frames: int = 0
	while crono.is_walking() and frames < 600:
		await get_tree().physics_frame
		frames += 1
	check(not crono.is_walking() and ended.size() == 1, "the blocked walk resolved (%d physics frames)" % frames)
	check(crono.global_position.z > -12.0, "where he stood, short of the crate")
	var npc := FieldNPC.make(&"test_npc", "marle")
	loc.add_child(npc)
	npc.global_position = Vector3(6.0, 0.0, 6.0)
	npc.frozen = true
	var done: Array = []
	var waiter := func() -> void:
		await npc.walk_to(Vector3(9.0, 0.0, 6.0))
		done.append(true)
	waiter.call()
	frames = 0
	while done.is_empty() and frames < 300:
		await get_tree().physics_frame
		frames += 1
	check_eq(done, [true], "a frozen NPC's awaited walk resolves")
	check(npc.global_position.distance_to(Vector3(6.0, 0.0, 6.0)) < 0.01, "where it stands")
	Game.new_game()


# ---------------------------------------------------------------- gravity

## WORLD-18: a mover (PlayerController, PartyFollow) and the body's own tick never both apply gravity in one
## tick; a body nobody moves still falls on its own.
func test_gravity_lands_once_per_tick() -> void:
	Game.new_game()
	var leader := CombatActor.create_party_member(&"crono")
	root.add_child(leader)
	_track(leader)
	leader.global_position = Vector3(0, 50, 0)
	var ctrl := PlayerController.new()
	root.add_child(ctrl)
	_track(ctrl)
	ctrl.attach(leader)
	ctrl._physics_process(DT)
	leader._physics_process(DT)
	check_near(leader.velocity.y, -CombatActor.GRAVITY * DT, 0.0001, "the leader falls by one tick of gravity")
	var follower := CombatActor.create_party_member(&"sera")
	root.add_child(follower)
	_track(follower)
	follower.global_position = Vector3(2, 50, 0)
	var follow := PartyFollow.new()
	root.add_child(follow)
	_track(follow)
	follow.set_party(leader, [follower])
	follow._physics_process(DT)
	follower._physics_process(DT)
	check_near(follower.velocity.y, -CombatActor.GRAVITY * DT, 0.0001, "so does a follower")
	var zone := EncounterZone.new()
	zone.encounter_id = &"kitchen_motes"
	root.add_child(zone)
	_track(zone)
	zone.spawn(root)
	check(not zone.enemies.is_empty(), "the zone spawned its wanderers")
	var wanderer: CombatActor = zone.enemies[0]
	for e in zone.enemies:
		_track(e)
	wanderer.global_position = Vector3(4, 50, 0)
	zone._physics_process(DT)
	wanderer._physics_process(DT)
	check_near(wanderer.velocity.y, -CombatActor.GRAVITY * DT, 0.0001, "and a zone's wanderer")
	var loose := CombatActor.create_party_member(&"crono")
	root.add_child(loose)
	_track(loose)
	loose.global_position = Vector3(-2, 50, 0)
	loose._physics_process(DT)
	check_near(loose.velocity.y, -CombatActor.GRAVITY * DT, 0.0001, "a body nobody moves falls on its own")
	check(ctrl.process_physics_priority < 0 and follow.process_physics_priority < 0 and zone.process_physics_priority < 0, "movers tick before the bodies")
	Game.new_game()


# ---------------------------------------------------------------- the location

## WORLD-5: a Location subclass that sets universe_id in build() (as README tells it to) boots in that
## universe: canvas, environment and light agree.
func test_location_reads_universe_id_after_build() -> void:
	Game.new_game()
	var script := GDScript.new()
	script.source_code = "extends Location\n\nfunc build() -> void:\n\tlocation_id = &\"u4_test\"\n\tuniverse_id = 4\n"
	check_eq(script.reload(), OK, "a U4 test location compiles")
	var loc: Location = script.new()
	root.add_child(loc)
	_track(loc)
	await get_tree().process_frame
	check_eq(Universe.current, 4, "Universe follows the universe_id build() set")
	var want: Environment = HD2DWorld.make_environment(4)
	check_eq(loc.world.environment.background_color, want.background_color, "the U4 background")
	check_eq(loc.world.environment.ambient_light_color, want.ambient_light_color, "the U4 ambient")
	check(loc.key_light != null and loc.key_light.light_color.b > loc.key_light.light_color.r, "the cool U4 key light")
	Universe.set_universe(0, true)
	Game.new_game()


## WORLD-10: the field Rewind puts its +5 Debt on Sera's body: the crack shows and spreads (the hairline
## state, which the shader draws) and she thins; the look survives a battle.
func test_field_rewind_shows_on_sera() -> void:
	var loc: Location = await _arena([&"crono", &"sera"])
	var sera: CombatActor = loc.get_actor(&"sera") as CombatActor
	var mat: ShaderMaterial = sera.sprite.material
	check_eq(int(mat.get_shader_parameter("porcelain_state")), 1, "no Debt: pristine")
	check_near(float(mat.get_shader_parameter("opacity")), 1.0, 0.001, "and solid")
	check(loc.field_rewind(sera, loc.get_actor(&"crono")), "the Rewind plays")
	check_near(Game.sera_debt, 5.0, 0.001, "+5 Debt")
	check_eq(int(mat.get_shader_parameter("porcelain_state")), 2, "the crack shows (hairline, drawn by the shader)")
	var first: float = float(mat.get_shader_parameter("crack_amount"))
	check_near(first, 0.25, 0.001, "at 0.2 + Debt/100")
	check_near(float(mat.get_shader_parameter("opacity")), 1.0 - 5.0 * CombatActor.DEBT_OPACITY_PER_POINT, 0.001, "she thins")
	loc.field_rewind(sera, null)
	check(float(mat.get_shader_parameter("crack_amount")) > first, "a second Rewind spreads it")
	_zone_battle(loc)
	check(await _end(loc, true), "a battle")
	check_eq(int(mat.get_shader_parameter("porcelain_state")), 2, "the crack is still there after it")
	check_near(float(mat.get_shader_parameter("opacity")), 1.0 - 10.0 * CombatActor.DEBT_OPACITY_PER_POINT, 0.001, "and so is the translucency")
	Game.new_game()


# ---------------------------------------------------------------- the body's look follows the rules (RA-1, RA-4)

## Advance the battle clock, guarding every window, until `cond` holds or `max_s` of battle time pass.
func _run_until(c: BattleCoordinator, cond: Callable, max_s: float) -> bool:
	var t0: float = c.battle_time
	while not bool(cond.call()) and c.battle_time - t0 < max_s:
		var before: float = c.battle_time
		_run_battle_time(c, DT)
		if is_equal_approx(c.battle_time, before) and not (c.state == BattleCoordinator.State.COMMAND_WAIT):
			break  # the clock stopped (the battle ended)
	return bool(cond.call())


func _tint(a: CombatActor) -> Color:
	return a.sprite.material.get_shader_parameter("tint")


## RA-1 (Combat Laws §10.2): while Sera is phased (untargetable) every redraw keeps her the gold ghost at 18 %,
## a DoT tick on the coordinator's clock and a revive inside the phase included; when the phase passes she is
## back at her Debt's thinness, untinted, and the battle's end leaves her at her Debt (with its interest).
func test_a_phased_sera_stays_a_ghost_whatever_redraws_her() -> void:
	var loc: Location = await _arena([&"crono", &"sera"])
	Game.set_debt(20.0)
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	var sera: CombatActor = loc.get_actor(&"sera") as CombatActor
	_tough(crono)
	var debt_op: float = 1.0 - 20.0 * CombatActor.DEBT_OPACITY_PER_POINT
	check_near(sera.sprite.opacity, debt_op, 0.0001, "she starts the fight at her Debt's 0.9")
	check(StatusRules.apply(c, sera, &"ink_dot", 4.0, -1, 1, {"tick": 3}), "a Kanji Stroke inks her")
	TechCosts.spend_solidity(c, sera, sera.solidity.solidity - 15.0)
	check(sera.solidity.is_phased(), "a Rewind past 20 phases her out")
	check_near(sera.sprite.opacity, CombatActor.PHASED_OPACITY, 0.0001, "a ghost at 18 %")
	check_eq(_tint(sera), CombatActor.PHASED_TINT, "in gold")
	var ticks: Array = []
	c.strike_resolved.connect(func(_a: Node, t: Node, info: Dictionary) -> void:
		if t == sera and bool(info.get("dot", false)):
			ticks.append({"phased": sera.solidity.is_phased(), "opacity": sera.sprite.opacity, "tint": _tint(sera)}))
	check(_run_until(c, func() -> bool: return not ticks.is_empty(), 3.0), "the ink ticks on the battle clock")
	if not ticks.is_empty():
		check(bool(ticks[0]["phased"]), "while she is still phased")
		check_near(float(ticks[0]["opacity"]), CombatActor.PHASED_OPACITY, 0.0001, "and the tick's hurt redraw keeps her a ghost")
		check_eq(ticks[0]["tint"], CombatActor.PHASED_TINT, "gold, not back in the fight")
	sera.stats.apply_damage(999999, true)
	check(not sera.stats.is_alive() and sera.solidity.is_phased(), "a KO inside the phase leaves the phase running")
	sera.stats.revive(0.3)
	c.unit_revived.emit(sera)
	_tough(sera)
	check(sera.visible, "revived, she is in view")
	check_near(sera.sprite.opacity, CombatActor.PHASED_OPACITY, 0.0001, "and still the phased ghost, as the rules have her")
	check_eq(_tint(sera), CombatActor.PHASED_TINT, "gold")
	check(_run_until(c, func() -> bool: return not sera.solidity.is_phased(), 30.0), "her phased turns pass")
	check_near(sera.sprite.opacity, debt_op, 0.0001, "un-phased: her Debt's 0.9, not fully solid")
	check_eq(_tint(sera), Color.WHITE, "untinted")
	check(await _end(loc, true), "the battle ends")
	check_near(Game.sera_debt, 23.0, 0.001, "+3 Debt interest on the 65 % she spent")
	check_near(sera.sprite.opacity, 1.0 - 23.0 * CombatActor.DEBT_OPACITY_PER_POINT, 0.0001, "and she stands at it")
	Game.new_game()


## RA-4: a Story `debt` or `integrity` command in the field redraws the bodies at once (Sera thins and her crack
## spreads, Crono's crack state follows his integrity), the cast included, and the fight after starts at it.
func test_a_story_ledger_command_redraws_the_field_bodies() -> void:
	var loc: Location = await _arena([&"crono", &"sera"])
	var sera: CombatActor = loc.get_actor(&"sera") as CombatActor
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	var cast: CombatActor = loc.add_cast(&"crono", Vector3(3, 0, 6))  # a cast body standing in the scene
	check_near(sera.sprite.opacity, 1.0, 0.0001, "no Debt: solid")
	check_eq(int(crono.sprite.material.get_shader_parameter("porcelain_state")), 1, "full integrity: Crono pristine")
	await Story.run(&"t_ledger", [{"debt": 25}, {"integrity": -50}, {"end": true}])
	check_near(Game.sera_debt, 25.0, 0.001, "+25 Debt")
	check_near(sera.sprite.opacity, 1.0 - 25.0 * CombatActor.DEBT_OPACITY_PER_POINT, 0.0001, "she thins at once")
	check_near(float(sera.sprite.material.get_shader_parameter("crack_amount")), 0.45, 0.001, "and the crack spreads to 0.2 + Debt/100")
	check_eq(int(crono.sprite.material.get_shader_parameter("porcelain_state")), 2, "integrity 50: Crono shows the hairline crack")
	check_near(cast.time_debt.integrity, 50.0, 0.001, "the cast takes the ledger up too")
	check_eq(int(cast.sprite.material.get_shader_parameter("porcelain_state")), 2, "and wears it")
	var scene: BattleScene = _zone_battle(loc)
	check_near(sera.sprite.opacity, 1.0 - 25.0 * CombatActor.DEBT_OPACITY_PER_POINT, 0.0001, "the fight starts at her Debt")
	check(scene.coordinator.party.has(sera), "with her in it")
	check(await _end(loc, true), "the battle ends")
	Game.new_game()


## RA-4: a reserve is spawned wearing its ledger: Sera hovering at 30 Debt stands at 0.85 through the fade pass
## with her crack showing, not solid and pristine until her first hit.
func test_a_reserve_sera_spawns_at_her_debt() -> void:
	var loc: Location = await _arena([&"crono"])
	Game.recruit(&"sera")
	Game.sera_in_story = "hover"
	Game.set_debt(30.0)
	var scene: BattleScene = _zone_battle(loc)
	var hover: CombatActor = scene.roster.hover
	check(hover != null and hover.actor_id == &"sera", "Sera hovers on the Turn Bar")
	if hover != null:
		check_near(hover.sprite.opacity, 0.85, 0.0001, "at her Debt's 0.85")
		check(hover.sprite.is_faded(), "through the fade pass")
		check_eq(int(hover.sprite.material.get_shader_parameter("porcelain_state")), 2, "her crack showing")
	var benched := CombatActor.create_party_member(&"sera")
	_track(benched)
	check_near(benched.sprite.opacity, 0.85, 0.0001, "any spawn of her wears it (create_party_member)")
	check(await _end(loc, true), "the battle ends")
	Game.new_game()
