## The battle scene and its HUD (BattleScene, BattleDeck, BattleHUD, SwapRules, EnemySpawner, SealPayment,
## AutoBattler): targeting only ever offers what the coordinator accepts, a refused or deck-closing command
## never strands an open window, a Swap (KO'd or not) is the window's action, seals show on the preview, the
## strike and the plate, one summon rule with one cap, the plates follow the camera while aiming, and the
## autobattle exercises effect techs. The scene tests build the test arena and drive the clock by hand.
extends "res://tests/suite_base.gd"

const ARENA := "res://scenes/test/arena.tscn"
const CRADLE := {"boss_id": "atrium_cradle", "boss": true, "at": "boss", "center": "center"}


func _arena(ids: Array[StringName], recruits: Array[StringName] = []) -> Location:
	Game.new_game()
	for r in recruits:
		Game.recruit(r)
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


func _cradle_battle(loc: Location) -> BattleScene:
	loc._on_story_battle(&"", CRADLE)
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


func _deck_cmds(hud: BattleHUD) -> Array:
	return hud.deck_items.map(func(it: Dictionary) -> String: return String(it.get("cmd", "")))


# ---------------------------------------------------------------- targeting and refused commands

## BATTLE-1: Attack never offers an untargetable enemy; a confirm the coordinator refuses keeps the window and
## reopens the deck; a window left with no deck gets it back on the next frame.
func test_attack_targets_only_targetable_enemies_and_a_refusal_reopens_the_deck() -> void:
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	var hidden: Node = c.enemies[0]
	StatusComponent.of(hidden).add(&"untargetable", -1.0, -1)
	check_eq(c.targetable_enemies().size(), c.living_enemies().size() - 1, "targetable_enemies drops the untargetable one")
	check(not c.targetable_enemies().has(hidden), "and it is that one")
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	check(_window_for(c, crono), "Crono's window opens")
	check_eq(scene.mode, BattleScene.Mode.DECK, "with his deck up")
	scene._on_deck_command("attack", {})
	check_eq(scene.mode, BattleScene.Mode.TARGET, "Attack opens the aim")
	check(not scene.target_list.is_empty() and not scene.target_list.has(hidden), "the untargetable enemy is never offered")
	# a target that turned untargetable while the player aimed: the coordinator refuses the strike
	scene.target_list = [hidden]
	scene.target_index = 0
	scene._confirm_target()
	check_eq(c.state, BattleCoordinator.State.COMMAND_WAIT, "the refused attack leaves the window open")
	check(c.active_actor == crono, "for Crono")
	check_eq(scene.mode, BattleScene.Mode.DECK, "and his deck is back up")
	check(scene.hud.deck_open, "visibly")
	# any path that closes the deck on an open window: the next frame brings it back
	scene.mode = BattleScene.Mode.NONE
	scene.hud.close_deck()
	scene._process(1.0 / 60.0)
	check_eq(scene.mode, BattleScene.Mode.DECK, "a closed deck on an open window comes back by itself")
	check(scene.hud.deck_open, "and shows")
	# an accepted attack closes it and the clock runs again
	var target: Node = c.targetable_enemies()[0]
	scene._on_deck_command("attack", {})
	scene.target_index = scene.target_list.find(target)
	scene._confirm_target()
	check(c.state != BattleCoordinator.State.COMMAND_WAIT or c.active_actor != crono, "an accepted attack ends Crono's window")
	check(await _end(loc, true), "the battle still ends")
	Game.new_game()


## BATTLE-1: the deck's enemy lists all come from targetable_enemies(), and a refused item costs nothing.
func test_battle_deck_lists_and_items_follow_the_coordinator() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var a := _enemy(&"a", 5, Vector3(3, 0, 0), 2, ["SWORD"], {"hp": 100000})
	var b := _enemy(&"b", 5, Vector3(3, 0, 2), 2, ["SWORD"], {"hp": 100000})
	_start(c, [crono], [a, b])
	StatusComponent.of(b).add(&"untargetable", -1.0, -1)
	check_eq(BattleDeck.targets(c, "attack"), [a], "Attack aims only at the targetable")
	check_eq(BattleDeck.targets(c, "enemy"), [a], "and so does an enemy tech")
	# b Broken and low but untargetable: not offered to Spare either
	for i in 2:
		ShieldComponent.of(b).apply_strike([&"SWORD"], 0, crono)
	CombatantStats.of(b).hp = 1
	check(c.can_spare(b), "b could be spared")
	check(not BattleDeck.targets(c, "spare").has(b), "but an untargetable body is never a Spare target")
	check(BattleDeck.targets(c, "item").has(crono), "items aim at the party")
	Game.inventory["tonic"] = 1
	var r: Dictionary = BattleDeck.use_item(c, crono, Data.items[&"tonic"], crono)
	check(not bool(r["ok"]), "an item outside the actor's window is refused")
	check_eq(int(Game.inventory.get("tonic", 0)), 1, "and the Tonic stays in the bag")
	_advance_until_window(c)
	var r2: Dictionary = BattleDeck.use_item(c, crono, Data.items[&"tonic"], crono)
	check(bool(r2["ok"]), "on his window it is used")
	check_eq(int(Game.inventory.get("tonic", 0)), 0, "and only then taken from the bag")
	Game.new_game()


# ---------------------------------------------------------------- swap

## GAP4-2 / COMBAT-21: a KO'd ally's swap is the swapper's action (its turn ends, the clock runs again) and never
## leaves a closed deck on an open window.
func test_ko_swap_from_the_deck_ends_the_turn() -> void:
	var ids: Array[StringName] = [&"crono", &"sera"]
	var loc: Location = await _arena(ids, [&"krona"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	var sera: CombatActor = loc.get_actor(&"sera") as CombatActor
	var krona: CombatActor = null
	for r in scene.roster.bench:
		if r.actor_id == &"krona":
			krona = r
	check(krona != null, "Krona waits on the bench")
	sera.stats.apply_damage(100000, true)
	check(_window_for(c, crono), "Crono's window opens")
	sera.global_position = crono.global_position + Vector3(1.0, 0.0, 0.0)
	var turns: int = c.turns_taken(crono)
	scene._on_deck_command("swap", {})
	check_eq(scene.mode, BattleScene.Mode.SWAP, "Swap opens its sub-deck")
	var ko_item: Dictionary = {}
	for it in scene.hud.deck_items:
		if (it.get("payload", {}) as Dictionary).has("koed"):
			ko_item = it
	check(not ko_item.is_empty(), "with Krona in for the fallen Sera")
	scene._on_deck_command("swap_in", ko_item.get("payload", {}))
	check(c.party.has(krona) and c.bench.has(sera), "Krona takes Sera's place")
	check_eq(c.turns_taken(crono), turns + 1, "the KO swap is Crono's action for the window")
	check(c.active_actor != crono, "his window is closed")
	check_eq(c.state, BattleCoordinator.State.TICK, "and the clock runs again")
	check_eq(scene.mode, BattleScene.Mode.NONE, "with the deck put away")
	check(_advance_until_window(c) != null, "the next window opens")
	check(await _end(loc, true), "the battle still ends")
	Game.new_game()


## COMBAT-21: both swaps end the turn through _finish_turn; hover Sera cannot swap (she is on no party slot); a
## KO'd reserve cannot come in; one move per window.
func test_swap_rules_and_one_move_per_window() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var krona := _party_member(&"krona", 10, Vector3(-9, 0, 0))
	var sera := _party_member(&"sera", 10, Vector3(-9, 0, 2))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 30, ["FIRE"], {"hp": 100000})
	_start(c, [crono], [e], {"bench": [krona], "hover_sera": sera})
	var w: Node = _advance_until_window(c)
	for i in 8:
		if w == null or w == sera:
			break
		c.cmd_guard(w)
		w = _advance_until_window(c)
	check(w == sera, "hover Sera reaches her window")
	var r: Dictionary = c.cmd_swap(sera, krona)
	check(not bool(r["ok"]), "hover Sera cannot swap: she holds no party slot")
	check(c.party[0] == crono and c.bench.has(krona), "and nobody moved")
	c.cmd_guard(sera)
	check(_advance_until_actor(c, &"crono") == crono, "Crono's window")
	var first: Dictionary = c.cmd_move(crono, c.position_of(crono) + Vector3(1, 0, 0))
	var second: Dictionary = c.cmd_move(crono, c.position_of(crono) + Vector3(1, 0, 0))
	check(bool(first["ok"]) and not bool(second["ok"]), "one move per window (§4.1)")
	var turns: int = c.turns_taken(crono)
	CombatantStats.of(krona).apply_damage(100000, true)
	check(not bool(c.cmd_swap(crono, krona)["ok"]), "a KO'd reserve cannot be swapped in")
	CombatantStats.of(krona).revive(1.0)
	var r2: Dictionary = c.cmd_swap(crono, krona)
	check(bool(r2["ok"]) and c.party.has(krona) and c.bench.has(crono), "the Swap trades him for Krona")
	check_eq(c.turns_taken(crono), turns + 1, "and it was his action (his turn is counted)")
	check(c.state != BattleCoordinator.State.COMMAND_WAIT or c.active_actor != crono, "his window is closed")
	# the KO swap from too far is refused
	var c2 := _coord()
	var a2 := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var s2 := _party_member(&"sera", 10, Vector3(-8, 0, 0))
	var k2 := _party_member(&"krona", 10, Vector3(-9, 0, 0))
	var e2 := _enemy(&"x", 10, Vector3(3, 0, 0), 30, ["FIRE"], {"hp": 100000})
	_start(c2, [a2, s2], [e2], {"bench": [k2]})
	CombatantStats.of(s2).apply_damage(100000, true)
	check(_advance_until_actor(c2, &"crono") == a2, "Crono's window")
	check(not bool(c2.cmd_swap_koed(a2, s2, k2)["ok"]), "a KO'd ally 6 m away is out of reach (3 m)")
	c2._set_position(s2, Vector3(-3, 0, 0))
	var r3: Dictionary = c2.cmd_swap_koed(a2, s2, k2)
	check(bool(r3["ok"]) and c2.party.has(k2), "from within 3 m it works")
	check(c2.active_actor != a2 and c2.state != BattleCoordinator.State.COMMAND_WAIT, "and ends Crono's window")


# ---------------------------------------------------------------- seals

## BATTLE-9: a sealed body previews 0 damage and SEALED, the strike says so, and its plate carries [SEALED].
func test_seals_show_on_the_preview_the_strike_and_the_plate() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var e := _enemy(&"doll", 5, Vector3(1, 0, 0), 4, ["SWORD"], {"hp": 100000})
	_start(c, [crono], [e])
	c.undamageable.append(e)
	_advance_until_window(c)
	var pv: Dictionary = c.preview(crono, null, e, c.position_of(e), 0)
	check(bool(pv[e]["sealed"]), "the preview marks the seal")
	check_eq(int(pv[e]["damage"]), 0, "and promises no HP damage")
	check(int(pv[e]["shave"]) > 0, "while the plates still shave")
	check(BattleDeck.preview_text(null, e, pv, 0).contains("SEALED"), "the aim line names the seal")
	var seen: Array = []
	c.strike_resolved.connect(func(_a: Node, _t: Node, info: Dictionary) -> void: seen.append(info))
	c.cmd_attack(crono, e, 0)
	check(not seen.is_empty() and bool(seen[0].get("sealed", false)) and int(seen[0]["damage"]) == 0, "the strike reports the seal")
	# the plate in a real scene
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _zone_battle(loc)
	var foe: Node = scene.coordinator.enemies[0]
	scene.coordinator.undamageable.append(foe)
	scene.hud.update_plates({}, false, null)
	var l1: Label = scene.hud.plates[foe].get_meta("l1")
	check(l1.text.begins_with("[SEALED]"), "the plate reads [SEALED] (got %s)" % l1.text)
	scene.coordinator.undamageable.clear()
	scene.hud.update_plates({}, false, null)
	check(not l1.text.contains("SEALED"), "and drops it when the seal lifts")
	check(await _end(loc, true), "the battle ends")
	Game.new_game()


## BATTLE-12: the deck label and the floating number name one unit (integrity), paying charges exactly that and
## lifts the seal, and it is a free action: the window and the deck stay.
func test_pay_time_debt_charges_what_it_says() -> void:
	check(SealPayment.label(100.0).contains("%d%% integrity" % roundi(SealPayment.INTEGRITY_COST)), "the deck label names integrity")
	check(SealPayment.number_text().contains("%d%% integrity" % roundi(SealPayment.INTEGRITY_COST)), "and so does the number")
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _cradle_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	check(scene.boss != null, "the Cradle has its controller")
	check(_window_for(c, crono), "Crono's window opens")
	scene.boss.set_sealed(true)
	scene._open_main_deck()
	check(_deck_cmds(scene.hud).has("pay_debt"), "a sealed boss puts Pay Time Debt on his deck")
	var before: float = Game.crono_integrity
	scene._on_deck_command("pay_debt", {})
	check_near(Game.crono_integrity, before - SealPayment.INTEGRITY_COST, 0.001, "it charges exactly the integrity it names")
	check(not scene.boss.is_sealed(), "and lifts the seal")
	check(c.state == BattleCoordinator.State.COMMAND_WAIT and c.active_actor == crono, "a free action: the window stays")
	check(scene.mode == BattleScene.Mode.DECK and scene.hud.deck_open and not _deck_cmds(scene.hud).has("pay_debt"), "the deck reopens without it")
	check(await _end(loc, true), "the battle ends")
	Game.new_game()


# ---------------------------------------------------------------- summons

## BATTLE-16: one summon rule: a regular enemy's summon is capped by its own max_adds (default 3) in a zone fight,
## a boss's by its file, and a regular enemy summoning beside a boss keeps its own cap.
func test_one_summon_rule_with_the_summoners_own_cap() -> void:
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	var caster: Node = c.enemies[0]
	var n0: int = c.enemies.size()
	c.request_summon(&"moss_mouse", 5, caster)
	check_eq(c.enemies.size() - n0, EnemySpawner.DEFAULT_MAX_ADDS, "a regular summoner brings at most 3")
	c.request_summon(&"moss_mouse", 5, caster)
	check_eq(c.enemies.size() - n0, EnemySpawner.DEFAULT_MAX_ADDS, "and none while three stand")
	check(scene.hud.plates.has(c.enemies[-1]) and scene.enemies.has(c.enemies[-1]), "the newcomers get a plate and join the scene")
	check(await _end(loc, true), "the zone battle ends")
	var loc2: Location = await _arena([&"crono"])
	var boss_scene: BattleScene = _cradle_battle(loc2)
	var c2: BattleCoordinator = boss_scene.coordinator
	var cradle: Node = boss_scene.boss.actor
	var cap: int = EnemySpawner.max_adds_of(boss_scene.boss.def.raw)
	var adds0: int = boss_scene.boss.adds_alive.size()
	var m0: int = c2.enemies.size()
	c2.request_summon(&"porcelain_shardling", 5, cradle)
	var standing: int = c2.living_enemies().filter(func(e: Node) -> bool: return CombatantStats.of(e).actor_id == &"porcelain_shardling").size()
	check_eq(standing, cap, "the Cradle's summon fills to its file's max_adds (%d), placed once" % cap)
	check_eq(boss_scene.boss.adds_alive.size() - adds0, c2.enemies.size() - m0, "every one of them is the boss's add")
	var shardling: Node = c2.enemies[-1]
	var m1: int = c2.enemies.size()
	c2.request_summon(&"moss_mouse", 5, shardling)
	check_eq(c2.enemies.size() - m1, EnemySpawner.cap_of(shardling), "a regular enemy beside the boss summons under its own cap")
	check_eq(boss_scene.boss.adds_alive.size() - adds0, m1 - m0, "and those are not the boss's adds")
	check(await _end(loc2, true), "the boss battle ends")
	Game.new_game()


# ---------------------------------------------------------------- plates

## BATTLE-19: the wind-up tint stays between cyan and orange and pulses by sin(TIME × 6); the plates are
## re-projected every frame while the player aims.
func test_plate_tint_and_plates_follow_the_camera_while_aiming() -> void:
	for i in 11:
		var p: float = float(i) / 10.0
		for ts in [0.0, 0.26, 0.52, 1.3]:
			var col: Color = BattleHUD.telegraph_tint(p, ts)
			var lo: Color = BattleHUD.CYAN.lerp(BattleHUD.ORANGE, p) * 0.7
			var hi: Color = BattleHUD.CYAN.lerp(BattleHUD.ORANGE, p)
			check(col.r >= lo.r - 0.001 and col.r <= hi.r + 0.001 and col.b >= lo.b - 0.001 and col.b <= hi.b + 0.001, "tint at %.1f stays on the cyan-orange ramp" % p)
	check(BattleHUD.telegraph_tint(1.4, 0.0).is_equal_approx(BattleHUD.telegraph_tint(1.0, 0.0)), "past the end of a wind-up it clamps to orange")
	check(not BattleHUD.telegraph_tint(0.5, 0.0).is_equal_approx(BattleHUD.telegraph_tint(0.5, PI / 12.0)), "and it pulses with time")
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	check(_window_for(c, loc.get_actor(&"crono")), "Crono's window opens")
	scene._on_deck_command("attack", {})
	check_eq(scene.mode, BattleScene.Mode.TARGET, "aiming")
	var foe: Node = scene._current_target()
	var plate: Control = scene.hud.plates[foe]
	scene._process(0.0)
	var before: Vector2 = plate.position
	var cam: Camera3D = scene.hud.camera
	cam.global_position += Vector3(1.5, 0.0, 0.0)
	scene._process(0.0)
	check(plate.position.distance_to(before) > 1.0, "the plate follows the camera while aiming (moved %.1f px)" % plate.position.distance_to(before))
	check((plate.get_meta("l1") as Label).text.begins_with("◆"), "and still marks the target")
	cam.global_position -= Vector3(1.5, 0.0, 0.0)
	check(await _end(loc, true), "the battle ends")
	Game.new_game()


## BATTLE-17: the HUD declares no signal nothing emits.
func test_hud_has_no_dead_signals() -> void:
	var hud := BattleHUD.new()
	for sig in ["target_changed", "boost_changed", "cancelled"]:
		check(not hud.has_signal(sig), "BattleHUD.%s is gone" % sig)
	check(hud.has_signal("command_chosen"), "command_chosen stays")
	hud.free()


## BATTLE-11: the victory and defeat stings resolve to real files.
func test_battle_stings_resolve() -> void:
	check(Audio.find_sting("victory") != null, "the victory sting has a file")
	check(Audio.find_sting("defeat") != null, "the defeat sting has a file")


# ---------------------------------------------------------------- the autobattle

## GAP3-4: the autobattle's effect picks: Tachyon Needle on an unbroken enemy, HOLD on a Broken one, Rewind on an
## ally who lost a fifth of their HP since their turn began; casting goes through TechEffects (HOLD extends the
## lock) and every decision is tallied for the probe's AUTOBATTLE line.
func test_autobattle_casts_effect_techs() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var sera := _party_member(&"sera", 10, Vector3(-3, 0, 2))
	var e := _enemy(&"shard", 5, Vector3(3, 0, 0), 2, ["SWORD"], {"hp": 100000})
	_start(c, [crono, sera], [e])
	check(_advance_until_actor(c, &"sera") == sera, "Sera's window")
	# nobody has lost HP since their turn began, so Rewind has no target yet
	for u in c.party:
		c.turn_snapshots[u] = {"hp": CombatantStats.of(u).hp, "gauge": 0.0, "pos": c.position_of(u), "statuses": []}
	check(AutoBattler.effect_target(c, "rewindable", []) == null, "no Rewind target while nobody is down on their turn start")
	var pick: Dictionary = AutoBattler.pick_effect(c, sera, c.targetable_enemies())
	check(not pick.is_empty() and (pick["tech"] as TechDef).id == &"tachyon_needle" and pick["target"] == e, "Tachyon Needle on the unbroken enemy")
	for i in 2:
		ShieldComponent.of(e).apply_strike([&"SWORD"], 0, crono)
	check(c.is_broken(e), "the enemy is Broken")
	pick = AutoBattler.pick_effect(c, sera, c.targetable_enemies())
	check(not pick.is_empty() and (pick["tech"] as TechDef).id == &"hold" and pick["target"] == e, "HOLD once it is Broken")
	var st := CombatantStats.of(crono)
	var full: int = st.hp
	st.hp = maxi(1, roundi(float(st.max_hp()) * 0.4))
	c.turn_snapshots[crono]["hp"] = st.max_hp()
	check(AutoBattler.effect_target(c, "rewindable", []) == crono, "Rewind finds the ally who lost a fifth of his HP since his turn began")
	st.hp = full
	c.turn_snapshots[crono]["hp"] = full
	AutoBattler.tally.clear()
	var lock: float = ShieldComponent.of(e).lock_left
	check(AutoBattler._cast_effect(c, sera, c.targetable_enemies()), "the cast is accepted")
	check(ShieldComponent.of(e).lock_left > lock, "HOLD ran through TechEffects and extended the lock")
	check_eq(int(AutoBattler.tally.get("tech:hold", 0)), 1, "and the tally counts it")
	AutoBattler.report(true)
	check(AutoBattler.tally.is_empty(), "report() prints and clears the tally")
