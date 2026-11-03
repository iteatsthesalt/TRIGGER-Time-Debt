## The battle scene and its HUD (BattleScene, BattleDeck, BattleHUD, SwapRules, EnemySpawner, SealPayment,
## AutoBattler): targeting only ever offers what the coordinator accepts, a refused or deck-closing command
## never strands an open window, a Swap (KO'd or not) is the window's action, seals show on the preview, the
## strike and the plate, one summon rule with one cap, the plates follow the camera while aiming, and the
## autobattle exercises effect techs. The scene tests build the test arena and drive the clock by hand.
extends "res://tests/suite_base.gd"

const ARENA := "res://scenes/test/arena.tscn"
const KITCHEN := "res://scenes/u0/guardia_kitchen.tscn"
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


## preview-partners-after-cancelled-dual: a Dual picked and backed out of leaves no partner on the Attack that
## follows: the aim's numbers are the actor's own, the ones cmd_attack then deals (the coordinator's preview reads
## no partner for an Attack either).
func test_an_attack_after_a_cancelled_dual_previews_the_actors_own_hit() -> void:
	var loc: Location = await _arena([&"crono", &"marle"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	var crono: CombatActor = loc.get_actor(&"crono") as CombatActor
	var marle: CombatActor = loc.get_actor(&"marle") as CombatActor
	marle.stats.p_atk = crono.stats.p_atk * 3.0  # a partner who would hit far harder than Crono
	c.fixed_variance = 1.0
	check(_window_for(c, crono), "Crono's window")
	var target: Node = c.targetable_enemies()[0]
	ShieldComponent.of(target).weaknesses.clear()  # no Break mid-Attack: the preview does not forecast one
	var own: int = int(c.preview(crono, null, target, c.position_of(target), 0)[target]["damage"])
	check_eq(int(c.preview(crono, null, target, c.position_of(target), 0, [marle])[target]["damage"]), own, "an Attack's preview takes no partner")
	scene.partners = [marle]  # what a Dual picked from the deck leaves when it is backed out of
	scene._on_deck_command("attack", {})
	check(scene.partners.is_empty(), "Attack clears the cancelled Dual's partner")
	scene.target_index = scene.target_list.find(target)
	scene._refresh_preview()
	var shown: Dictionary = c.preview(scene.actor, scene.current_tech, target, c.position_of(target), scene.boost, scene.partners)
	check_eq(int(shown[target]["damage"]), own, "the aim reads Crono's own hit")
	var hp0: int = CombatantStats.of(target).hp
	scene._confirm_target()
	check_eq(hp0 - CombatantStats.of(target).hp, own, "and that is what the Attack deals")
	check(await _end(loc, true), "the battle ends")
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


## COMBAT-21: both swaps end the turn through finish_turn; hover Sera cannot swap (she is on no party slot); a
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
	c2.move_unit(s2, Vector3(-3, 0, 0))
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


## Code health F6: summoned adds face the party's side as BattleScene faces every enemy it opens with (party_side,
## which PartyPlacement turns where the floor needs it), not the plane's +Z, and stand on the room's ground.
func test_summoned_adds_face_the_party_side_and_stand_on_the_ground() -> void:
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	check(c.ground != null, "a Location battle has its ground")
	scene.party_side = Vector3(1, 0, 0)  # a fan PartyPlacement turned by 90 degrees
	var n0: int = c.enemies.size()
	c.request_summon(&"moss_mouse", 3, c.enemies[0])
	var adds: Array = c.enemies.slice(n0)
	check_eq(adds.size(), 3, "three adds join")
	var turned: int = 0
	for a in adds:
		var add := a as CombatActor
		check(c.ground.stand_at(add.global_position) != null, "%s stands on the room's floor" % add.name)
		var faced: StringName = add.sprite.facing
		add.face_toward(add.global_position + Vector3(0, 0, 4))
		var plane_z: StringName = add.sprite.facing
		add.face_toward(scene.center + scene.party_side * 4.0)
		check_eq(faced, add.sprite.facing, "%s faces the party's side" % add.name)
		if plane_z != faced:
			turned += 1
	check(turned > 0, "which is not the plane's +Z for at least one of them")
	check(await _end(loc, true), "the zone battle ends")
	Game.new_game()


## Combat Laws 15.3: a scaled regular summoner's adds fight at the rank its encounter gives the same kind (the
## Filament Guardian's Atom-Eaters beside the encounter's own), and a summoner nothing scaled calls its adds at
## their authored level, as a boss's are.
func test_a_scaled_summoners_adds_fight_at_its_encounters_rank() -> void:
	var loc: Location = await _arena([&"crono"])
	loc._on_story_battle(&"gallery_filament_guardian", {})
	var scene: BattleScene = loc.battle
	var c: BattleCoordinator = scene.coordinator
	c.auto_tick = false
	var atom: EnemyDef = Data.enemy(&"atom_eater")
	var guardian: Node = c.enemies.filter(func(e: Node) -> bool: return CombatantStats.of(e).actor_id == &"lavic_filament_guardian")[0]
	var rows: Array = c.enemies.filter(func(e: Node) -> bool: return CombatantStats.of(e).actor_id == &"atom_eater")
	var row_level: int = CombatantStats.of(rows[0]).level
	check(row_level != atom.level, "the encounter's Atom-Eaters are scaled off their authored Lv %d (to %d)" % [atom.level, row_level])
	var n0: int = c.enemies.size()
	c.request_summon(&"atom_eater", 1, guardian)
	check_eq(c.enemies.size() - n0, 1, "the guardian calls one Atom-Eater beside the two standing")
	var called: CombatActor = c.enemies[-1]
	check_eq(called.stats.level, row_level, "the called Atom-Eater fights at the encounter's rank, not its authored level")
	check_eq(called.has_meta(&"time_shear"), (rows[0] as Node).has_meta(&"time_shear"), "and shares its Time Shear")
	check_eq(called.stats.xp_reward, CombatantStats.of(rows[0]).xp_reward, "and pays the XP of that rank")
	var plain: CombatActor = CombatActor.create_enemy(Data.enemy(&"lavic_filament_guardian"), -1, "_plain")
	_track(plain)
	var authored: CombatActor = EffectiveRank.create_summoned(atom, plain, "_auth")
	_track(authored)
	check_eq(authored.stats.level, atom.level, "a summoner nothing scaled (a boss's add) calls at the authored level")
	check(await _end(loc, true), "the battle ends")
	Game.new_game()


# ---------------------------------------------------------------- telegraphs

## Combat Laws 3.5: an enemy killed (not Broken) mid wind-up takes its telegraph with it; the decal does not stay
## painted on the plane as a threat that will never land while its allies fight on.
func test_an_enemy_killed_mid_wind_up_takes_its_telegraph_with_it() -> void:
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	c.party_hp_floor = 1
	var spoon: Node = null
	var t: float = 0.0
	while spoon == null and t < 60.0:
		if c.state == BattleCoordinator.State.COMMAND_WAIT:
			c.cmd_guard(c.active_actor)
			continue
		c.advance(1.0 / 30.0)
		t += 1.0 / 30.0
		for e in c.wind_ups.keys():
			if CombatantStats.of(e).actor_id == &"ashen_spoon":
				spoon = e
	check(spoon != null, "a Spoon winds up its Ink Stir (its one action)")
	check(scene.telegraphs.has(spoon), "its cone is painted on the plane")
	var decal: Node = scene.telegraphs.get(spoon, null)
	check(not ShieldComponent.of(spoon).is_broken, "it is not Broken")
	CombatantStats.of(spoon).apply_damage(999999, true)
	check(not CombatantStats.of(spoon).is_alive(), "a hit kills it mid wind-up")
	check(not c.wind_ups.has(spoon), "its wind-up ends with it")
	check(not scene.telegraphs.has(spoon), "and its telegraph goes")
	await get_tree().process_frame
	check(not is_instance_valid(decal), "the decal is freed")
	check(c.living_enemies().size() >= 2 and c.state != BattleCoordinator.State.IDLE, "while its allies fight on")
	check(await _end(loc, true), "the battle ends")
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


# ---------------------------------------------------------------- a story battle has the player

## Press and release `action` through the root viewport, as a key does (Viewport.push_input, _unhandled_input).
func _tap(action: String) -> void:
	for on: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = on
		root.push_input(ev)
		await get_tree().process_frame


func _wait(cond: Callable, max_s: float) -> bool:
	var t: float = 0.0
	while not bool(cond.call()) and t < max_s:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	return bool(cond.call())


## story-battle-input-dead: the Cradle, started as the Prologue starts it (the pantry trigger runs
## prologue_cradle_sequence, whose `battle` command waits on the fight), takes real key presses: the deck cursor
## moves, Attack opens the aim and confirm strikes; a deck closed on an open window comes back by itself; the win
## runs the script on to its checkpoint.
func test_the_cradle_story_battle_takes_the_players_input() -> void:
	Game.new_game()
	Game.location = &"guardia_kitchen"
	Game.checkpoint = &"prologue_gate_open"
	Game.set_party([&"crono", &"marle", &"sera"] as Array[StringName])
	Story.auto_advance_s = 0.01
	Story.auto_choice = 0
	Story.skip_waits = true
	var k: Location = (load(KITCHEN) as PackedScene).instantiate()
	root.add_child(k)
	_track(k)
	get_tree().current_scene = k
	await _wait(func() -> bool: return not Story.is_running() and not Router.transitioning, 12.0)
	Engine.time_scale = 4.0
	k.call("_on_cradle_trigger", k.party_actors[0])
	check(await _wait(func() -> bool: return k.battle != null, 30.0), "the pantry trigger starts the Cradle")
	var scene: BattleScene = k.battle
	if scene == null:
		Engine.time_scale = 1.0
		_story_defaults()
		return
	var c: BattleCoordinator = scene.coordinator
	var open := func() -> bool: return c.state == BattleCoordinator.State.COMMAND_WAIT and not scene.input_blocked and scene.hud.deck_open and scene.mode == BattleScene.Mode.DECK
	check(await _wait(open, 40.0), "a party window opens with its deck up")
	Engine.time_scale = 1.0
	check(Story.is_running() and Story.current_id == &"prologue_cradle_sequence", "the Cradle's script is running, waiting on the fight")
	check(not scene.auto and not Story.blocks_battle_input(), "and the fight has the player's input")
	var first: Node = c.active_actor
	check_eq(String(scene.hud.deck_items[0].get("cmd", "")), "attack", "the deck opens on Attack")
	await _tap("move_down")
	check_eq(scene.hud.deck_index, 1, "a real move_down moves the cursor")
	await _tap("move_up")
	check_eq(scene.hud.deck_index, 0, "and move_up brings it back")
	scene.mode = BattleScene.Mode.NONE
	scene.hud.close_deck()
	await get_tree().process_frame
	check(scene.mode == BattleScene.Mode.DECK and scene.hud.deck_open, "a deck closed on an open window comes back by itself")
	await _tap("confirm")
	check_eq(scene.mode, BattleScene.Mode.TARGET, "confirm on Attack opens the aim")
	await _tap("confirm")
	check(c.state != BattleCoordinator.State.COMMAND_WAIT or c.active_actor != first, "confirm strikes, and the window is over")
	c.force_end(true)
	Engine.time_scale = 4.0
	check(await _wait(func() -> bool: return not Story.is_running(), 30.0), "the win releases the script")
	Engine.time_scale = 1.0
	check_eq(Game.checkpoint, &"prologue_cradle_done", "which runs on to its checkpoint")
	_story_defaults()
	Game.new_game()


# ---------------------------------------------------------------- the parry key

## Run the clock (one frame a step) with Crono guarding every window he gets, until `done` holds or `max_s` passes.
func _guarding_until(c: BattleCoordinator, done: Callable, max_s: float) -> bool:
	var t: float = 0.0
	while not bool(done.call()) and t < max_s and c.state != BattleCoordinator.State.IDLE:
		if c.state == BattleCoordinator.State.COMMAND_WAIT:
			c.cmd_guard(c.active_actor)
			continue
		c.advance(1.0 / 60.0)
		t += 1.0 / 60.0
	return bool(done.call())


## H1 (Combat Laws §4.2; DECISIONS "Ens Parry is 'armed'"): the parry key, pressed for real (Viewport.push_input
## through BattleScene._unhandled_input), is the Ens Parry. With nobody guarding it arms nothing. Crono guarding, a
## press as a telegraphed hit is about to land arms his window and the hit is a perfect parry: no damage, an Ens
## ring, his Debt costs nulled. A press is spent: a second one at once arms nothing, one after
## ENS_PARRY_RECOVER_S arms again and does not reopen a window already open. Against U1 ink enemies a press with no
## hit due throws the ink blot when its window closes.
func test_the_parry_key_parries_a_hit_on_a_guarding_ally() -> void:
	var loc: Location = await _arena([&"crono"])
	var scene: BattleScene = _zone_battle(loc)
	var c: BattleCoordinator = scene.coordinator
	c.party_hp_floor = 1
	var crono: Node = c.unit_by_id(&"crono")
	var st := CombatantStats.of(crono)
	# one foe, one telegraphed single-target strike: every hit on Crono is a wind-up he can read
	var jab := EnemyDef.from_dict({"key": "jab_foe", "level": 2, "actions": [{"id": "jab", "name": "Jab", "tags": ["BLUNT"],
		"shape": "SINGLE", "power": 1.0, "hits": 1, "wind_up_s": 1.0, "target": "nearest"}]})
	var foe: Node = c.living_enemies()[0]
	for e in c.living_enemies():
		if e != foe:
			CombatantStats.of(e).apply_damage(999999, true)
	c.enemy_defs[CombatantStats.of(foe).actor_id] = jab
	var window: float = float(c.parry_frames) / 60.0
	var results: Array = []
	c.parry_result.connect(func(_a: Node, perfect: bool) -> void: results.append(perfect))
	check(c.state == BattleCoordinator.State.TICK and not st.is_guarding, "the fight opens on the clock, Crono not guarding")
	await _tap("parry")
	check(c.parry_armed.is_empty(), "the parry key arms nobody while nobody guards")
	var landing := func() -> bool:
		return st.is_guarding and c.wind_ups.has(foe) and float(c.wind_ups[foe]["left"]) <= window * 0.5
	check(_guarding_until(c, landing, 60.0), "Crono guards as the jab is half a window from landing")
	var hp: int = st.hp
	await _tap("parry")
	check(c.parry_armed.has(crono), "a real parry press arms his window")
	check(_guarding_until(c, func() -> bool: return not results.is_empty(), 1.0), "the jab lands")
	check_eq(results, [true], "inside the window: a perfect parry")
	check_eq(st.hp, hp, "which negates the hit")
	check(c.ens_rings.has(crono), "and leaves an Ens ring")
	check(TimeDebtComponent.of(crono).debt_null_left > 0.0, "Crono's Debt costs are nulled")
	await _tap("parry")
	check(not c.parry_armed.has(crono), "a press is spent: another at once arms nothing")
	# from `since`, the press has recovered, Crono guards, and no hit is due inside a window
	var recovered := func(since: float) -> bool:
		return st.is_guarding and c.battle_time >= since + CombatConstants.ENS_PARRY_RECOVER_S \
			and (not c.wind_ups.has(foe) or float(c.wind_ups[foe]["left"]) > window + 0.1)
	check(_guarding_until(c, recovered.bind(c.battle_time), 10.0), "the press recovers while Crono guards and no hit is due")
	results.clear()
	await _tap("parry")
	check(c.parry_armed.has(crono), "after ENS_PARRY_RECOVER_S a press arms again")
	c.advance(1.0 / 60.0)
	var left: float = float(c.parry_armed.get(crono, 0.0))
	await _tap("parry")
	check_near(float(c.parry_armed.get(crono, -1.0)), left, 0.0001, "a press while armed does not reopen the window")
	check(_guarding_until(c, func() -> bool: return not results.is_empty(), 1.0), "the window closes unmet")
	check_eq(results, [false], "a press with no hit due is no parry")
	check(not StatusComponent.of(crono).has(&"ink_blot"), "outside U1 it costs nothing")
	c.universe = 1  # U1 ink enemies
	check(_guarding_until(c, recovered.bind(c.battle_time), 10.0), "recovered again, no hit due")
	results.clear()
	await _tap("parry")
	check(c.parry_armed.has(crono), "armed against ink")
	check(_guarding_until(c, func() -> bool: return not results.is_empty(), 1.0), "the window closes unmet")
	check(StatusComponent.of(crono).has(&"ink_blot"), "against U1 ink enemies a mistimed press throws the ink blot")
	check(await _end(loc, true), "the battle ends")
	Game.new_game()


func _story_defaults() -> void:
	Story.auto_advance_s = -1.0
	Story.auto_choice = -1
	Story.skip_waits = false
	get_tree().current_scene = null
