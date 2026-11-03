## Progression and the data readers (the "progression" audit cluster): one flag spelling (FlagRef, Flags.holds),
## kit unlocks of every kind (KitUnlocks: level after a level-up, flag and affinity on a change, drop, story),
## recruit and save guards, the item catalogue and its kinds (Game.grant), drops and codex leans at victory
## (RewardResolver), battle items (ItemUse), Effective Rank Level (EffectiveRank), the universe tables read from
## data, keyed plate counts and the data validation twins of lint_data.py.
extends "res://tests/suite_base.gd"


func _cleanup() -> void:
	Game.new_game()
	super._cleanup()


# ---------------------------------------------------------------- one flag spelling (DATA-6)

func test_flag_references_have_one_spelling() -> void:
	check_eq(FlagRef.split("R66Y:Rewound"), PackedStringArray(["R66Y", "Rewound"]), "Name:State splits")
	check_eq(FlagRef.split("The_Bowl_Still_Whole"), PackedStringArray(["The_Bowl_Still_Whole", ""]), "a bare name has no state")
	check_eq(FlagRef.error("R66Y:Rewound", Data.flags), "", "a defined flag and state is fine")
	check_eq(FlagRef.error("The_Bowl_Still_Whole", Data.flags), "", "a defined flag alone is fine")
	check(FlagRef.error("R66Y_Rewound", Data.flags).contains("names no flag"), "the old Flag_State spelling names nothing")
	check(FlagRef.error("R66Y=Rewound", Data.flags).contains("not Name or Name:State"), "the old boss Flag=State spelling is rejected")
	check(FlagRef.error("R66Y:Exploded", Data.flags).contains("has no state"), "an unknown state is rejected")
	Game.new_game()
	check(not Flags.holds("R66Y:Rewound") and not Flags.holds("R66Y"), "nothing holds on a fresh cycle")
	Flags.set_flag(&"R66Y", &"Rewound")
	check(Flags.holds("R66Y:Rewound") and Flags.holds("R66Y"), "Name:State and Name hold once set")
	check(not Flags.holds("R66Y:Salvaged"), "the other state does not")
	check(not Flags.holds("R66Y=Rewound"), "the retired spelling never holds")
	check(BossController.holds("R66Y:Rewound"), "boss branch tables read the same spelling")


func test_every_flag_reference_in_the_data_resolves() -> void:
	var bad: Array[String] = []
	for tid in Data.techs.keys():
		var t: TechDef = Data.techs[tid]
		for f in t.requires_flags:
			if FlagRef.error(String(f), Data.flags) != "":
				bad.append("%s requires %s" % [tid, f])
		if t.unlock.has("flag") and FlagRef.error(String(t.unlock["flag"]), Data.flags) != "":
			bad.append("%s unlock %s" % [tid, t.unlock["flag"]])
	for id in Data.characters.keys():
		for pair in KitUnlocks.entries(Data.characters[id]):
			var u: Dictionary = pair[1]
			if u.has("flag") and FlagRef.error(String(u["flag"]), Data.flags) != "":
				bad.append("%s kit %s" % [id, u["flag"]])
	for bid in Data.bosses.keys():
		for r in Data.boss_flag_refs(Data.bosses[bid]):
			if FlagRef.error(r, Data.flags) != "":
				bad.append("%s %s" % [bid, r])
	check(bad.is_empty(), "every kit, tech and boss flag reference names a defined flag and state: %s" % ", ".join(bad))
	check(Data.boss_flag_refs(Data.bosses[&"r66y"]).has("R66Y:Rewound"), "R-66Y's branch tables are read as references")
	check(Data.boss_flag_refs(Data.bosses[&"empress_vaelos"]).has("Goyama:Incinerated"), "and so are action `requires`")
	check(Data.errors.is_empty(), "Data validates kits, tags, flag references and boss files cleanly: %s" % "; ".join(Data.errors))


## DATA-6: Promise Across Rust waited on flags named R66Y_Rewound / Arris_Dome_Sleeping that could never be set.
func test_promise_across_rust_flags_can_hold() -> void:
	Game.new_game()
	var t: TechDef = Data.techs[&"promise_across_rust"]
	var all_hold := func() -> bool:
		for f in t.requires_flags:
			if not Flags.holds(String(f)):
				return false
		return true
	check(not all_hold.call(), "Promise Across Rust waits on its flags")
	Flags.set_flag(&"Arris_Dome", &"Sleeping")
	Flags.set_flag(&"R66Y", &"Rewound")
	check(all_hold.call(), "and is offered once the Mercy road set them (%s)" % str(t.requires_flags))


# ---------------------------------------------------------------- kit unlocks (DATA-5, GAP4-4, CORE-12)

func test_level_unlocks_arrive_on_level_up() -> void:
	Game.new_game()
	Game.recruit(&"krona")
	check(Game.knows_tech(&"krona", &"teppo_ash_cut"), "Krona joins with her on_join kit")
	check(not Game.knows_tech(&"krona", &"crimson_seppuku"), "Crimson Seppuku waits for Lv 18 (joined at 6)")
	Game.set_level(&"krona", 17)
	check(not Game.knows_tech(&"krona", &"crimson_seppuku"), "not at 17")
	Game.set_level(&"krona", 18)
	check(Game.knows_tech(&"krona", &"crimson_seppuku"), "Crimson Seppuku arrives at Lv 18 (§15.8)")
	var crono := CombatActor.create_party_member(&"crono")
	root.add_child(crono)
	_track(crono)
	crono.stats.level = 35
	BattleAftermath.write_back(crono, 0.0)
	check_eq(Game.level_of(&"crono"), 35, "the write-back records the level")
	check(Game.knows_tech(&"crono", &"luminaire"), "and Luminaire arrives with Lv 35 through the battle write-back")
	check(not Game.knows_tech(&"crono", &"unborrowed_time"), "Unborrowed Time still waits for 78")
	Game.recruit(&"static", 60)
	check(Game.knows_tech(&"static", &"hz_white_noise") and Game.knows_tech(&"static", &"akira_in_utero"), "a recruit above a level gate learns it at once")


func test_flag_and_affinity_unlocks_arrive_when_set() -> void:
	Game.new_game()
	Game.recruit(&"cassia")
	check(not Game.knows_tech(&"crono", &"null_erasure"), "Null Erasure waits for Dark 40")
	Flags.add_affinity(0, 39 - Flags.dark, 0)
	check(Flags.dark == 39 and not Game.knows_tech(&"crono", &"null_erasure"), "not at Dark 39")
	Flags.add_affinity(0, 1, 0)
	check(Game.knows_tech(&"crono", &"null_erasure") and Game.knows_tech(&"cassia", &"ferro_null"), "Dark 40 unlocks Null Erasure and Ferro Null (dark_min)")
	check(not Game.knows_tech(&"cassia", &"gatling_arm"), "Gatling Arm waits for the Salvage")
	Flags.set_flag(&"R66Y", &"Salvaged")
	check(Game.knows_tech(&"cassia", &"gatling_arm") and Game.knows_tech(&"cassia", &"empress_cannon"), "R66Y:Salvaged unlocks Gatling Arm and Empress Cannon")
	check(not Game.knows_tech(&"cassia", &"reinforced_guard"), "the Mercy-road Dual stays locked")


func test_prologue_still_teaches_the_chapter_zero_kit() -> void:
	Game.new_game()
	check((Game.roster[&"crono"]["known_techs"] as Array).is_empty(), "New Game: Crono's deck is empty until the Prologue teaches him")
	Flags.set_flag(&"Prologue_Fall", &"Teach_Her_To_Land")
	Flags.add_affinity(5, 0, 0)
	check(not Game.knows_tech(&"crono", &"astral_smear_dash"), "a flag or affinity event re-checks only flag-gated entries, not chapter 0")
	Flags.set_flag(&"The_Bowl_Still_Whole", &"set")
	check(Game.knows_tech(&"crono", &"bekkler_guilt"), "The Bowl Still Whole grants Bekkler's Guilt by itself now")
	Game.set_chapter(1)
	check(Game.knows_tech(&"crono", &"astral_smear_dash") and Game.knows_tech(&"crono", &"time_slice"), "the chapter step still catches the chapter entries")
	Game.learn_tech(&"crono", &"time_slice")
	var n: int = 0
	for tid in Game.roster[&"crono"]["known_techs"]:
		if String(tid) == "time_slice":
			n += 1
	check_eq(n, 1, "learning is idempotent")


func test_drop_and_story_unlocks() -> void:
	Game.new_game()
	Game.recruit(&"glenn")
	check(not Game.knows_tech(&"glenn", &"prop_hammer"), "the Prop Hammer waits for a Strongman Dummy's drop")
	Game.note_drop(&"strongman_dummy")
	check(Game.knows_tech(&"glenn", &"prop_hammer"), "and arrives with it (kit `drop`)")
	check(Game.looted.has(&"strongman_dummy"), "the drop is recorded for the cycle")
	Game.recruit(&"sera")
	Game.set_level(&"sera", 99)
	Game.set_chapter(20)
	check(not Game.knows_tech(&"sera", &"atropos_ribbon"), "a `story` unlock never arrives by itself (the True Ending script teaches it)")
	var marle: Array[StringName] = [&"crono", &"marle"]
	Game.set_party(marle)
	check(Game.knows_tech(&"marle", &"porcelain_promise"), "Porcelain Promise opens after Act I (chapter 2), for the guest too")


func test_kit_unlock_validation_catches_mistakes() -> void:
	var kit: Dictionary = {"id": "test_kit", "techs": [
		{"id": "a", "unlock": {"flag": "R66Y_Salvaged"}}, {"id": "b", "unlock": {"flagg": 1}},
		{"id": "c", "unlock": {"drop": "dust_mote_cluster"}}, {"id": "d", "unlock": {"level": "high"}},
		{"id": "e", "unlock": {"flag": "R66Y:Salvaged", "chapter": 3}}, {"id": "f", "unlock": {"drop": "strongman_dummy"}},
	]}
	var errs: PackedStringArray = KitUnlocks.validation_errors(kit, Data.flags, Data.enemies)
	var text: String = "\n".join(errs)
	check(text.contains("tech a") and text.contains("names no flag"), "an undefined flag spelling is an error")
	check(text.contains("tech b") and text.contains("unknown kind flagg"), "an unknown kind is an error")
	check(text.contains("tech c") and text.contains("drops anything"), "a drop from an enemy that drops nothing is an error")
	check(text.contains("tech d") and text.contains("must be a number"), "a non-numeric level is an error")
	check(not text.contains("tech e") and not text.contains("tech f"), "well-formed unlocks pass")
	check_eq(errs.size(), 4, "exactly the four mistakes")


func test_recruit_and_saves_guard_missing_rows() -> void:
	Game.new_game()
	Game.roster.erase(&"glenn")
	Game.recruit(&"glenn")
	check(Game.roster.has(&"glenn") and Game.recruited.has(&"glenn"), "recruiting an actor with no roster row gives it one")
	check_eq(Game.level_of(&"glenn"), 43, "at its join level")
	var before: int = Game.recruited.size()
	Game.recruit(&"nobody_at_all")
	check_eq(Game.recruited.size(), before, "an id with no kit and no row is ignored, not a crash")
	Game.note_drop(&"porcelain_shardling")
	var save: Dictionary = Game.to_save()
	(save["roster"] as Dictionary).erase("krona")
	Game.new_game()
	Game.from_save(save)
	check(Game.roster.has(&"krona"), "a save written before an actor existed still gives the roster every actor")
	check(Game.looted.has(&"porcelain_shardling"), "the looted list survives a save")
	Game.recruit(&"krona")
	check(Game.recruited.has(&"krona"), "and recruiting it works")


# ---------------------------------------------------------------- items and drops (DATA-10, GAP4-5, DATA-8)

func test_every_referenced_item_is_in_the_catalogue() -> void:
	var missing: Array[String] = []
	for bid in Data.bosses.keys():
		for d in RewardResolver.normalize(Data.bosses[bid].get("drops", [])):
			if not Data.items.has(StringName(String(d["item"]))):
				missing.append("%s drops %s" % [bid, d["item"]])
	for k in Data.enemies.keys():
		for d in RewardResolver.normalize((Data.enemies[k] as EnemyDef).drops):
			if not Data.items.has(StringName(String(d["item"]))):
				missing.append("%s drops %s" % [k, d["item"]])
	for sid in Data.dialogue.keys():
		for cmd in Data.dialogue[sid]:
			if not (cmd is Dictionary):
				continue
			for verb in ["give_item", "key_item", "relic"]:
				if (cmd as Dictionary).has(verb) and not Data.items.has(StringName(String(cmd[verb]))):
					missing.append("%s %s %s" % [sid, verb, cmd[verb]])
	check(missing.is_empty(), "every drop and dialogue grant is a catalogue item: %s" % ", ".join(missing))
	for id in Data.items.keys():
		check(Game.ITEM_KINDS.has(StringName(String(Data.items[id].get("kind", "consumable")))), "item %s has a known kind" % id)


func test_grant_routes_by_kind() -> void:
	Game.new_game()
	check_eq(Game.grant(&"tonic", 2), &"consumable", "a Tonic is a consumable")
	check_eq(int(Game.inventory.get("tonic", 0)), 5, "into the bag (3 + 2)")
	check_eq(Game.grant(&"grief_filter"), &"relic", "the Grief Filter is a relic (Combat Laws 11.14)")
	check(Game.relics.has(&"grief_filter") and not Game.inventory.has("grief_filter"), "into relics, not the bag")
	check_eq(Game.grant(&"prop_hammer"), &"key", "the Prop Hammer is a key item")
	check(Game.key_items.has(&"prop_hammer"), "into key items")
	Game.grant(&"kirie_scales", 13)
	check_eq(Flags.counter(&"kirie_scales"), 13, "Kirie Scales count toward Ending 8's hundred")
	check_eq(Game.grant(&"no_such_item_zz", 1, &"key"), &"key", "an id the catalogue lacks goes by the caller's verb")
	check(Game.key_items.has(&"no_such_item_zz"), "and is not lost")


func test_victory_awards_drops_and_the_signature_lean() -> void:
	Game.new_game()
	Game.recruit(&"glenn")
	var c := _coord()
	var crono := _party_member(&"crono", 40, Vector3(-3, 0, 0))
	CombatantStats.of(crono).weapon_tags = [&"FIRE"]
	var dummy := _enemy(&"strongman_dummy", 3, Vector3(3, 0, 0), 1, ["FIRE"], {"hp": 1000})
	_start(c, [crono], [dummy], {"universe": 5, "enemy_defs": {&"strongman_dummy": Data.enemy(&"strongman_dummy")}})
	check_eq(Data.enemy(&"strongman_dummy").lean, "D", "the Strongman Dummy leans Dark (§13.7 E57)")
	_advance_until_window(c)
	CombatantStats.of(dummy).hp = 1
	c.cmd_attack(crono, dummy, 0)
	check(c.state == BattleCoordinator.State.IDLE and bool(c.last_summary.get("victory", false)), "the kill ends the battle in a victory")
	var drops: Array = c.last_summary.get("drops", [])
	check(drops.size() == 1 and String(drops[0]["item"]) == "prop_hammer" and drops[0]["kind"] == &"key", "the Prop Hammer drops, as a key item (%s)" % str(drops))
	check(Game.key_items.has(&"prop_hammer"), "and is given")
	check(Game.knows_tech(&"glenn", &"prop_hammer"), "Glenn learns the Prop Hammer from the drop")
	check_eq(int(Flags.leans.get(5, {}).get("D", 0)), 1, "a [FIRE] finish incinerates a Dark-lean enemy: +1 Dark lean in U5")
	check_eq(c.last_summary.get("leans", []), [{"key": "strongman_dummy", "lean": "D"}], "the summary lists the lean")


func test_leans_follow_the_codex_signature() -> void:
	Game.new_game()
	var c := _coord()
	var crono := _party_member(&"crono", 3, Vector3(-3, 0, 0))
	var keys: Array[StringName] = [&"dust_mote_cluster", &"vaelos_echo", &"gato_ruin", &"ferro_drone_09", &"debtling", &"moss_mouse"]
	var defs: Dictionary = {}
	var foes: Array = []
	for key in keys:
		defs[key] = Data.enemy(key)
		foes.append(_enemy(key, 3, Vector3(3, 0, foes.size()), 1, ["SWORD"], {"hp": 1000}))
	_start(c, [crono], foes, {"universe": 0, "enemy_defs": defs})
	var leans: Array[String] = []
	for key in keys:
		leans.append(Data.enemy(key).lean)
	check_eq(leans, ["L", "P", "D", "D", "P", "L"] as Array[String], "the codex leans this test reads (§13.2)")
	c.spared.append(foes[0])  # a Light-lean mote spared: its signature
	c.spared.append(foes[1])  # a Paradox-lean echo spared: not its signature
	foes[2].set_meta(RewardResolver.META_KO, {"broken": true, "tags": [&"RUIN"], "tier": TechDef.Tier.SINGLE})  # salvaged
	foes[3].set_meta(RewardResolver.META_KO, {"broken": false, "tags": [&"RUIN"], "tier": TechDef.Tier.SINGLE})  # a plain kill
	foes[4].set_meta(RewardResolver.META_KO, {"broken": false, "tags": [&"SWORD"], "tier": TechDef.Tier.DUAL})  # a Dual finish
	foes[5].set_meta(RewardResolver.META_KO, {"broken": false, "tags": [&"FIRE"], "tier": TechDef.Tier.SINGLE})  # burned
	for i in [2, 3, 4, 5]:
		CombatantStats.of(foes[i]).hp = 0
	check_eq(RewardResolver.resolution(c, foes[1]), "L", "a spare names Light")
	check_eq(RewardResolver.resolution(c, foes[2]), "D", "a Broken body finished by [RUIN] is salvaged")
	check_eq(RewardResolver.resolution(c, foes[3]), "", "an unbroken body killed by [RUIN] is just killed")
	check_eq(RewardResolver.resolution(c, foes[4]), "P", "a Dual finish is a paradox")
	check_eq(RewardResolver.resolution(c, foes[5]), "D", "a [FIRE] finish incinerates")
	var fed: Array[String] = []
	for l in RewardResolver.award_leans(c):
		fed.append("%s:%s" % [l["key"], l["lean"]])
	check_eq(fed, ["dust_mote_cluster:L", "gato_ruin:D", "debtling:P"] as Array[String], "only the signature resolutions feed their leans")
	check_eq(Flags.leans.get(0, {}), {"L": 1, "D": 1, "P": 1}, "+1 each in U0; the spared Paradox echo and the burned Light mouse feed nothing")


## DATA-8: the battle scene no longer pays +1 Light on every spare; the resolver pays the signature lean once.
func test_a_spare_in_the_battle_scene_pays_one_light_lean() -> void:
	Game.new_game()
	var solo: Array[StringName] = [&"crono"]
	Game.set_party(solo)
	var loc: Location = (load("res://scenes/test/arena.tscn") as PackedScene).instantiate()
	root.add_child(loc)
	_track(loc)
	loc.place_party(&"start")
	await get_tree().process_frame
	loc._on_story_battle(&"kitchen_motes", {})
	var c: BattleCoordinator = loc.battle.coordinator
	c.auto_tick = false
	check_eq(c.enemies.size(), 3, "three Light-lean dust motes")
	var crono: Node = c.unit_by_id(&"crono")
	var spares: int = 0
	while c.state != BattleCoordinator.State.IDLE and spares < 6:
		var a: Node = _advance_until_window(c)
		if a == null:
			break
		var left: Array = c.enemies.filter(func(e: Node) -> bool: return c.alive(e) and not c.spared.has(e))
		var t: Node = left[0]
		if not c.is_broken(t):
			ShieldComponent.of(t).force_break(crono)
		CombatantStats.of(t).hp = 1
		c.cmd_spare(a, t)
		spares += 1
	check(bool(c.last_summary.get("victory", false)) and spares == 3, "sparing every mote wins the battle (%d spares)" % spares)
	check_eq(int(Flags.leans.get(0, {}).get("L", 0)), 3, "one Light lean per spared mote, paid once at victory")


# ---------------------------------------------------------------- battle items (GAP4-5)

func test_items_repair_and_refuse_when_useless() -> void:
	Game.new_game()
	check(ItemUse.usable_in_battle(Data.items[&"time_atom"]), "a Time Atom is a battle consumable")
	check(not ItemUse.usable_in_battle(Data.items[&"tungsten_scrap"]) and not ItemUse.usable_in_battle(Data.items[&"prop_hammer"]), "materials and key items are not")
	var c := _coord()
	var crono := _party_member(&"crono", 5, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 3, Vector3(3, 0, 0), 2, ["ICE"], {"hp": 9999})
	_start(c, [crono], [e])
	TimeDebtComponent.of(crono).integrity = 90.0
	_advance_until_window(c)
	Game.inventory["revive"] = 1
	var r: Dictionary = BattleDeck.use_item(c, crono, Data.items[&"revive"], crono)
	check(not bool(r["ok"]), "a Revive on a standing ally is refused")
	check_eq(int(Game.inventory.get("revive", 0)), 1, "and stays in the bag")
	Game.inventory["time_atom"] = 1
	var r2: Dictionary = BattleDeck.use_item(c, crono, Data.items[&"time_atom"], crono)
	check(bool(r2["ok"]), "a Time Atom is used")
	check_near(TimeDebtComponent.of(crono).integrity, 90.5, 0.0001, "and repairs +0.5 integrity (§13.10)")
	check_eq(int(Game.inventory.get("time_atom", 0)), 0, "and is taken from the bag")
	Game.inventory.clear()
	Game.inventory["tungsten_scrap"] = 3
	check_eq(BattleDeck.item_items().size(), 1, "a bag of materials offers only Back")


# ---------------------------------------------------------------- Effective Rank Level (DATA-9)

func test_effective_rank_level_scales_regular_encounters() -> void:
	Game.new_game()
	var mote: EnemyDef = Data.enemy(&"dust_mote_cluster")
	var drone: EnemyDef = Data.enemy(&"ferro_drone_09")
	check_eq(EffectiveRank.level_for(mote, 1.0), mote.level, "a party at U0's floor meets the authored level")
	check_eq(EffectiveRank.level_for(drone, 1.0), drone.level, "and the codex spread survives")
	check_eq(EffectiveRank.level_for(mote, 12.0), mote.level + 11, "Atrium echoes rescale to a returning party (§13.2)")
	var ashigaru: EnemyDef = Data.enemy(&"ashen_ashigaru")
	check_eq(EffectiveRank.level_for(ashigaru, 5.0), 6, "U1 at the band floor: party 5 + bias 1")
	check_eq(EffectiveRank.level_for(ashigaru, 1.0), 3, "an under-levelled party meets nothing below band minimum - 2")
	var mite: EnemyDef = Data.enemy(&"slag_mite")
	check_eq(EffectiveRank.level_for(mite, 12.0), 15, "U2's +3 readability bias")
	check_eq(EffectiveRank.level_for(mite, 12.0, 2), 17, "plus the zone's hazard offset")
	check_eq(EffectiveRank.hazard(3, 1), 1, "U3's hazard is the zone's")
	Flags.set_flag(&"Azar", &"Predator")
	check_eq(EffectiveRank.hazard(3, 1), 4, "until Azar:Predator raises it to +4 (universes.json hazard_by_flag)")
	var boss: EnemyDef = BossDef.from_dict(Data.bosses[&"r66y"]).phase_def(0)
	check_eq(EffectiveRank.level_for(boss, 60.0), boss.level, "bosses keep their fixed level (§15.1)")
	check(EffectiveRank.time_shear(0, 10.0) and not EffectiveRank.time_shear(0, 9.0), "Time Shear past band maximum + 5")
	check_eq(EffectiveRank.spawn_level(mote, {"key": "dust_mote_cluster", "level": 7}, {}), 7, "an encounter row's own level wins")
	Game.roster[&"crono"]["level"] = 12
	var a: CombatActor = EffectiveRank.create(mote, "dust_mote_cluster", {}, "_t")
	root.add_child(a)
	_track(a)
	check_eq(a.stats.level, 12, "an encounter spawned for a Lv 12 Crono is Lv 12")
	check(a.has_meta(&"time_shear"), "and under Time Shear in U0 (party 12 > band maximum 4 + 5)")
	var plain: CombatActor = CombatActor.create_enemy(mote, 12, "_p")
	root.add_child(plain)
	_track(plain)
	check_near(a.stats.spd, plain.stats.spd * EffectiveRank.TIME_SHEAR_SPD, 0.001, "Time Shear: +15% speed")
	Game.roster[&"crono"]["level"] = 1
	var calm: CombatActor = EffectiveRank.create(mote, "dust_mote_cluster", {}, "_v")
	root.add_child(calm)
	_track(calm)
	check(not calm.has_meta(&"time_shear") and calm.stats.level == mote.level, "a party inside the band meets the authored level, no Time Shear")


# ---------------------------------------------------------------- universes and the grade table (CORE-18, WORLD-11/14, GAP4-7)

func test_universe_tables_come_from_data() -> void:
	for u in 10:
		var row: Dictionary = Data.universe(u)
		check_near(Universe.fps_of(u), float(row["fps"]), 0.0001, "U%d fps from universes.json" % u)
		check_eq(Universe.name_of(u), String(row["name"]), "U%d name from universes.json" % u)
		check_near(float(CanvasStackEffect.GRADES[u][15]), float(row["fps"]), 0.0001, "the compositor's fps column agrees for U%d" % u)
		var g: Array = CanvasStackEffect.GRADES[u]
		check_eq(CanvasStackEffect.paper_of(u), Color(float(g[1]), float(g[2]), float(g[3])), "U%d paper read from the one grade table" % u)
	check(not ("leaks" in Universe), "Universe.leaks is gone (HD2DWorld.set_leak is the hub leak)")
	check(not Universe.has_method("grade") and not Universe.has_method("is_blending"), "the duplicate grade table and dead members are gone")


func test_location_music_defaults_from_its_universe() -> void:
	Game.new_game()
	var loc: Location = (load("res://scenes/test/arena.tscn") as PackedScene).instantiate()
	root.add_child(loc)
	_track(loc)
	check_eq(loc.field_music, &"", "the test arena names no field track")
	check_eq(loc.field_track(), StringName(String(Data.universe(0)["music_field"])), "so it plays U0's music_field")
	# STORY-12: an NPC's own Talk callback never depends on the location having ambient lines
	check(Data.ambient_lines(loc.location_id).is_empty(), "the arena has no ambient chatter")
	var talked: Array = []
	var npc: FieldNPC = loc.add_npc(&"test_talker", "glenn_marshall", Vector3(2, 0, 2), "s", 60.0, &"", "Talk", 0.0, func(_by: Node) -> void: talked.append(true))
	var it: Interactable = npc.get_node_or_null("Talk")
	check(it != null, "an NPC given a talk callback has a Talk anyway")
	it.callback.call(null)
	check_eq(talked.size(), 1, "and it runs the callback")
	check(loc.add_npc(&"test_mute", "glenn_marshall", Vector3(3, 0, 2)).get_node_or_null("Talk") == null, "without one (and no chatter) it has none")


# ---------------------------------------------------------------- data checks (DATA-13, DATA-15, DATA-17, DATA-23, STORY-12)

func test_keyed_plates_match_the_shield() -> void:
	var bad := EnemyDef.from_dict({"key": "keyed_bad", "shield": 6, "keyed_plates": [{"key": "ASTRAL", "weight": 2}, {"key": "LIGHT", "weight": 3}]})
	check(Array(bad.validation_errors()).any(func(e: String) -> bool: return e.contains("keyed plates weigh 5")), "a keyed shield that disagrees with its weights is an error")
	var ring := TechDef.from_dict({"id": "radius_missing", "tier": "single", "actors": ["crono"], "tags": ["FIRE"], "shape": "CIRCLE", "hits": 1})
	check(Array(ring.validation_errors()).any(func(e: String) -> bool: return e.contains("needs a radius")), "a CIRCLE with no radius is an error (the 1.0 default hid it, DATA-17)")
	var child := BossDef.from_dict(Data.bosses[&"vaelos_child_lullaby"])
	check(child.validation_errors().is_empty(), "the Vaelos Child's phases now agree with their keyed plates")
	check_eq(child.phase_def(0).shield, 5, "Tantrum plays the 5 its keys weigh")


func test_glenn_stores_his_verdict_on_the_defined_flag() -> void:
	var seen: Array[String] = []
	for sid in [&"ch1_glenn_honour", &"ch1_glenn_after"]:
		for cmd in Data.dialogue_script(sid):
			if cmd is Dictionary and (cmd as Dictionary).has("set_flag"):
				seen.append(String(cmd["set_flag"]))
			if cmd is Dictionary and (cmd as Dictionary).has("if") and cmd["if"] is Dictionary and (cmd["if"] as Dictionary).has("flag"):
				seen.append(String(cmd["if"]["flag"]))
	check(seen.has("Glenn_Duals:Granted") and seen.has("Glenn_Duals:Refused"), "Glenn's offer and refusal write Glenn_Duals (%s)" % str(seen))
	for f in seen:
		if f.begins_with("Glenn_Duals"):
			check_eq(FlagRef.error(f, Data.flags), "", "%s is a defined state" % f)
	check(not seen.has("Glenn_Duals_Refused") and not seen.has("Glenn_Duals_Offered"), "the ad-hoc ids are gone")


func test_dialogue_boss_ids_and_kit_tags_resolve() -> void:
	var bad: Array[String] = []
	for sid in Data.dialogue.keys():
		for cmd in Data.dialogue[sid]:
			if cmd is Dictionary and String((cmd as Dictionary).get("boss_id", "")) != "" and not Data.bosses.has(StringName(String(cmd["boss_id"]))):
				bad.append("%s boss_id %s" % [sid, cmd["boss_id"]])
	for id in Data.characters.keys():
		var kit: Dictionary = Data.characters[id]
		for tg in Array(kit.get("weapon", {}).get("tags", [])) + Array(kit.get("vulnerable", [])) + Array(kit.get("resistant", [])):
			if not CombatTags.is_known(StringName(String(tg))):
				bad.append("%s tag %s" % [id, tg])
	check(bad.is_empty(), "dialogue boss ids and kit tags resolve: %s" % ", ".join(bad))


func test_weaver_stand_in_resolves_through_its_art_alias() -> void:
	var weaver := BossDef.from_dict(Data.bosses[&"porcelain_weaver"]).phase_def(0)
	check_eq(weaver.art, &"weaver", "the Porcelain Weaver names its delivered folder")
	check(ResourceLoader.exists("res://assets/bosses/weaver/weaver_painted.png"), "and the painting is there to find")
	var sprite := ActorSprite.new()
	root.add_child(sprite)
	_track(sprite)
	SpriteLibrary.apply_enemy(sprite, weaver)
	var tex: Variant = (sprite.material as ShaderMaterial).get_shader_parameter("sheet")
	check(tex is Texture2D and (tex as Texture2D).resource_path.ends_with("weaver_painted.png"), "SpriteLibrary draws the painting, not the placeholder")
