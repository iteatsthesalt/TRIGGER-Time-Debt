## Technique and enemy effect ids (audit cluster "effects": COMBAT-7, DATA-16): every `effect` the data names is a
## bespoke handler, a row of data/effects/effects.json or an explicit flavour / pending listing, and every enemy
## action effect is an EnemyEffects arm; then each row's rule is checked as Combat Laws §11 words it, Chapter 3
## (Cassia-09's kit) first, and the enemy effects the Chapter 2 Daimyo and the U2-U7 codex use.
extends "res://tests/suite_base.gd"

var _flags_before: Dictionary = {}

## The 58 technique effect ids the audit (COMBAT-7) found with no handler.
const AUDIT_UNHANDLED: Array[String] = [
	"triangulation", "hz_static", "hz_white_noise", "graviton_whiteout", "mycelia_time_lapse", "chrono_prism",
	"honest_stage", "spore_rail", "lily_lancets", "rewind_reel", "time_mines", "prometheus_overload", "solar_railgun",
	"the_last_joke", "rose_window", "washi_hollow_rebirth", "family_porcelain", "kintsugi_mend", "carnival_of_souls",
	"iron_maiden_scroll", "fractured_lens", "guilt_halo", "mercy_leap", "gramophone_resonance", "ferro_graviton",
	"gatling_arm", "solar_winds", "refraction_needle", "prismlight_salvo", "ash_graveyard", "bloom_crown",
	"masque_feint", "ruin_elastic", "tachyon_static", "anachronism_glass", "solar_railgun_static", "ferro_null",
	"empress_cannon", "origami_requiem", "porcelain_promise_child", "guile_elastic", "prop_hammer",
	"gold_leaf_severance", "56k_prayer", "red_bike_ghost", "akira_in_utero", "ashtear_paradox",
	"first_light_that_never_was", "chrono_laugh", "omega_triple", "first_light_child", "promise_across_rust",
	"porcelain_memory", "null_spoon_hold", "vitreous_prism", "prism_refraction", "baptistery", "reptite_crown",
]


# ---------------------------------------------------------------- fixtures

## The action cmd_tech builds for `tech_id` (TechEffects.apply is called with it directly).
func _action(c: BattleCoordinator, actor: Node, tech_id: StringName, aim: Vector3, primary: Node = null, boost: int = 0, casters: Array = []) -> Dictionary:
	var tech: TechDef = Data.techs[tech_id]
	var who: Array = casters if not casters.is_empty() else [actor]
	var action := {
		"kind": "tech", "attacker": actor, "casters": who, "tags": Array(tech.tags),
		"shape": {"shape": tech.shape, "radius": tech.radius, "length": tech.length, "width": tech.width,
			"inner_radius": tech.inner_radius, "beams": tech.beams, "scale": tech.shape_scale(boost)},
		"hits": tech.hit_count, "aim": c.position_of(primary) if primary != null else aim, "primary": primary, "steps": 1,
	}
	action.merge(PartyHit.action_keys(c, tech, boost, who))  # base, stat, synergy × pair synergy, crit: cmd_tech's
	return action


func _cast(c: BattleCoordinator, actor: Node, tech_id: StringName, aim: Vector3, primary: Node = null, boost: int = 0, casters: Array = []) -> Dictionary:
	return TechEffects.apply(c, Data.techs[tech_id], _action(c, actor, tech_id, aim, primary, boost, casters))


func _battle(party: Array, enemies: Array) -> BattleCoordinator:
	var c := _coord()
	_start(c, party, enemies, {"techs": Data.techs})
	return c


func _sturdy(u: Node) -> void:
	var st := CombatantStats.of(u)
	st.base_max_hp = 100000
	st.hp = 100000


func _keep_flags() -> void:
	_flags_before = Flags.to_save()


func _restore_flags() -> void:
	Flags.from_save(_flags_before)


# ---------------------------------------------------------------- coverage (the lint's twin)

func test_every_effect_id_in_data_has_a_handler_or_a_listing() -> void:
	var unknown: PackedStringArray = []
	for id in Data.techs.keys():
		var eff: StringName = (Data.techs[id] as TechDef).effect
		if eff != &"" and not EffectTable.known(eff):
			unknown.append("%s:%s" % [id, eff])
	check(unknown.is_empty(), "every technique effect is a handler, a row, flavour or pending (unknown: %s)" % ", ".join(unknown))
	var bad: PackedStringArray = []
	for k in Data.enemies.keys():
		for a in (Data.enemies[k] as EnemyDef).actions:
			if not EnemyEffects.known(String(a.get("effect", ""))):
				bad.append("%s:%s" % [k, a["effect"]])
	for b in Data.bosses.keys():
		for ph in Data.bosses[b].get("phases", []):
			for a2 in ph.get("actions", []):
				if not EnemyEffects.known(String(a2.get("effect", ""))):
					bad.append("%s:%s" % [b, a2["effect"]])
	check(bad.is_empty(), "every enemy and boss action effect has an arm or a pending listing (unknown: %s)" % ", ".join(bad))
	var fx_errors: PackedStringArray = []
	for e in Data.errors:
		if "effect" in e:
			fx_errors.append(e)
	check(fx_errors.is_empty(), "Data reports no effect problems (%s)" % "; ".join(fx_errors))
	for eff in EffectTable.rows().keys():
		check(TechEffects.handles(StringName(eff)), "the row %s is run by TechEffects" % eff)
		check(EffectTable.row_errors(eff, EffectTable.row(StringName(eff))).is_empty(), "the row %s uses only known ops and conditions" % eff)
	var missing: PackedStringArray = []
	for eff in AUDIT_UNHANDLED:
		if not EffectTable.has_row(StringName(eff)) and not (Data.effects.get("flavour", {}) as Dictionary).has(eff):
			missing.append(eff)
	check(missing.is_empty(), "the 58 effect ids the audit found unhandled are rows or flavour now (missing: %s)" % ", ".join(missing))
	check(EffectTable.has_row(&"gramophone_resonance") and not EffectTable.has_row(&"rewind"), "rows and bespoke handlers stay apart")


func test_every_status_the_data_names_has_a_reader() -> void:
	# A status a reader never asks about lands and does nothing (DATA-16): the same rule as lint_data.py.
	var src: String = ""
	for path in _gd_files("res://scripts"):
		src += FileAccess.get_file_as_string(path) + "\n"
	var rx := RegEx.create_from_string("(?:\\bhas|\\bstacks|\\bdata)\\(&\"([a-z_0-9]+)\"")
	var read: Dictionary = {}
	for m in rx.search_all(src):
		read[m.get_string(1)] = true
	for id in StatusComponent.PERIODS.keys() + StatusComponent.MAX_STACKS.keys():
		read[String(id)] = true
	var pending: Dictionary = Data.effects.get("status_pending", {})
	var named: Dictionary = {}
	for k in Data.enemies.keys():
		for a in (Data.enemies[k] as EnemyDef).actions:
			if String(a.get("status", "")) != "":
				named[String(a["status"])] = "enemy %s" % k
	for eff in EffectTable.rows().keys():
		for op in EffectTable.row(StringName(eff)).get("after", []):
			if String(op.get("op", "")) == "status":
				named[String(op["id"])] = "effect %s" % eff
	var unread: PackedStringArray = []
	for sid in named.keys():
		if not read.has(sid) and not pending.has(sid):
			unread.append("%s (%s)" % [sid, named[sid]])
	check(unread.is_empty(), "every status the data names has a reader or a pending listing (%s)" % ", ".join(unread))
	check(pending.has("confuse") and not read.has("confuse"), "Confuse is listed as pending until something reads it")


func _gd_files(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in da.get_directories():
		out.append_array(_gd_files(dir.path_join(d)))
	return out


func test_an_unknown_effect_id_is_an_error() -> void:
	var typo := TechDef.from_dict({"id": "typo", "actors": ["crono"], "tags": ["ASTRAL"], "effect": "astral_feild"})
	var errs: PackedStringArray = EffectTable.validation_errors({&"typo": typo}, Data.effects)
	check(errs.size() == 1 and "astral_feild" in errs[0], "a technique effect with no handler and no listing is reported (%s)" % str(errs))
	var row_errs: PackedStringArray = EffectTable.row_errors("x", {"after": [{"op": "heel"}], "mult": [{"x": 2.0, "if": {"shiny": true}}], "requires": {"moon": 1}})
	check_eq(row_errs.size(), 3, "an unknown op, condition and requirement are each reported")
	var both: PackedStringArray = EffectTable.validation_errors({}, {"techs": {"rewind": {}}, "flavour": {}})
	check(both.size() == 1 and "bespoke" in both[0], "a row for an id with a bespoke handler is reported")
	check(not EnemyEffects.known("clok"), "an unknown enemy effect is not known")
	check(EnemyEffects.known("summon:ashen_ashigaru") and EnemyEffects.known("steal_bp") and EnemyEffects.known(""), "summons, the steal and no effect are")


func test_every_row_resolves_on_a_battle_plane() -> void:
	# Smoke: each row's technique, cast by its actors on two shielded enemies, returns an action summary.
	var seen: Dictionary = {}
	for id in Data.techs.keys():
		var tech: TechDef = Data.techs[id]
		if not EffectTable.has_row(tech.effect) or seen.has(tech.effect):
			continue
		seen[tech.effect] = true
		var party: Array = []
		var x: float = -3.0
		for aid in tech.actors:
			party.append(_party_member(aid, 40, Vector3(x, 0, 0)))
			x -= 0.5
		var e1 := _enemy(&"e1", 40, Vector3(2, 0, 0), 4, ["FERRO", "VITREOUS"], {"hp": 50000})
		var e2 := _enemy(&"e2", 40, Vector3(2.5, 0, 0.5), 4, ["ICE"], {"hp": 50000})
		var c := _battle(party, [e1, e2])
		var primary: Node = party[0] if tech.target in ["ally", "self"] else (e1 if tech.target in ["enemy", "any"] else null)
		var info: Dictionary = _cast(c, party[0], id, Vector3(2, 0, 0), primary, 3, party)
		check(info.has("targets") and String(info.get("effect", "")) == String(tech.effect), "%s resolves (%s)" % [tech.effect, id])
		_cleanup()
	check_eq(seen.size(), EffectTable.rows().size(), "every row was cast")


# ---------------------------------------------------------------- Chapter 3: Cassia-09

func test_gramophone_resonance_rattles_metal() -> void:
	var cassia := _party_member(&"cassia", 20, Vector3(-1, 0, 0))
	var metal := _enemy(&"drone", 20, Vector3(1, 0, 0), 4, ["ICE"], {"hp": 50000, "tags": ["FERRO"]})
	var flesh := _enemy(&"beast", 20, Vector3(1.2, 0, 0.6), 4, ["ICE"], {"hp": 50000})
	var c := _battle([cassia], [metal, flesh])
	var tech: TechDef = Data.techs[&"gramophone_resonance"]
	check_near(EffectTable.damage_mult(c, tech, 0, metal), 1.25, 0.0001, "+25% vs metal (§11.5)")
	check_near(EffectTable.damage_mult(c, tech, 0, flesh), 1.0, 0.0001, "nothing extra vs flesh")
	var info: Dictionary = _cast(c, cassia, &"gramophone_resonance", Vector3(1, 0, 0))
	check((info["targets"] as Array).has(metal), "the cone reaches the drone")
	check(StatusComponent.of(metal).has(&"hitched") and not StatusComponent.of(flesh).has(&"hitched"), "only metal hitches")
	check_near(StatusComponent.of(metal).hitch_seconds(), 0.5, 0.0001, "its next action starts 0.5 s late")
	var pv: Dictionary = c.preview(cassia, tech, metal, Vector3.ZERO, 0)
	check(int(pv.get(metal, {}).get("damage", 0)) > 0, "the preview estimates the rattled hit too")


func test_ferro_graviton_magnetizes_and_pulls_in() -> void:
	var cassia := _party_member(&"cassia", 20, Vector3(-4, 0, 0))
	var e := _enemy(&"e", 20, Vector3(1.5, 0, 0), 4, ["ICE"], {"hp": 50000})
	var c := _battle([cassia], [e])
	_cast(c, cassia, &"ferro_graviton", Vector3(0, 0, 0))
	check(StatusComponent.of(e).has(&"magnetized"), "Magnetizes (§11.5)")
	check_near(c.position_of(e).x, 0.5, 0.01, "pulled 1.0 m toward the centre (it stops half a metre short)")


func test_prometheus_overload_once_shutdown_and_burn() -> void:
	_keep_flags()
	Flags.flags.erase(&"Lucca_Consent")
	Flags.flags.erase(&"Prometheus_Core")
	var cassia := _party_member(&"cassia", 30, Vector3(-1, 0, 0))
	var crono := _party_member(&"crono", 30, Vector3(-2, 0, 0))
	var e := _enemy(&"e", 30, Vector3(1, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([cassia, crono], [e])
	_sturdy(crono)
	var tech: TechDef = Data.techs[&"prometheus_overload"]
	check(EffectTable.requirements_met(c, cassia, tech), "available before it is used")
	check_near(EffectTable.damage_mult(c, tech, 1, e), 1.6, 0.0001, "Boost bonus +60%")
	var info: Dictionary = _cast(c, cassia, &"prometheus_overload", Vector3(1, 0, 0))
	check(int(info["damage"].get(e, 0)) > 0, "the nova lands")
	check(not EffectTable.requirements_met(c, cassia, tech), "once per battle (§11.5)")
	var esc := StatusComponent.of(e)
	check(esc.has(&"burn") and int(esc.data(&"burn").get("tick", 0)) > 0, "10 burn ticks of 15% of the hit")
	check(StatusComponent.of(cassia).has(&"shutdown") and StatusComponent.of(cassia).gauge_multiplier() == 0.0, "Cassia-09 shuts down: her gauge does not fill")
	check(CombatantStats.of(crono).hp < 100000, "an ally within 2 m takes 10% max HP")
	check(Flags.is_state(&"Prometheus_Core", &"Burned"), "without Lucca's consent the Core is burned selfishly")
	c._finish(true, "test")
	check(EffectTable.requirements_met(c, cassia, tech), "a new battle may use it again")
	_restore_flags()


func test_solar_railgun_burns_and_leaves_the_venn_residual_on_a_break() -> void:
	var crono := _party_member(&"crono", 20, Vector3(-3, 0, 0))
	var cassia := _party_member(&"cassia", 20, Vector3(-3.5, 0, 0.5))
	var e := _enemy(&"e", 20, Vector3(2, 0, 0), 2, ["ASTRAL"], {"hp": 50000})
	var c := _battle([crono, cassia], [e])
	var info: Dictionary = _cast(c, crono, &"solar_railgun", Vector3(2, 0, 0), null, 0, [crono, cassia])
	check((info["breaks"] as Array).has(e), "the rail breaks it")
	check(StatusComponent.of(e).has(&"burn"), "and burns once (15% of raw)")
	check(c.fields.has_kind_at(&"watercolour_puddle", Vector3(2, 0, 0)) and c.fields.has_kind_at(&"amber_pool", Vector3(2, 0, 0)), "a Break leaves watercolour + amber")


func test_time_mines_blow_when_an_enemy_comes_back_to_its_spot() -> void:
	var sera := _party_member(&"sera", 20, Vector3(-3, 0, 0))
	var cassia := _party_member(&"cassia", 20, Vector3(-3.5, 0, 0.5))
	var e := _enemy(&"e", 20, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000})
	var c := _battle([sera, cassia], [e])
	var hp0: int = CombatantStats.of(e).hp
	_cast(c, sera, &"time_mines", Vector3(3, 0, 0), null, 0, [sera, cassia])
	check(c.fields.has_kind_at(&"time_mine", Vector3(3, 0, 0)), "a mine at its ghost position")
	FieldEffects.tick(c, 0.1)
	check_eq(CombatantStats.of(e).hp, hp0, "standing on its spot never set it off")
	c._set_position(e, Vector3(6, 0, 0))
	FieldEffects.tick(c, 0.1)
	c._set_position(e, Vector3(3, 0, 0))
	FieldEffects.tick(c, 0.1)
	check(CombatantStats.of(e).hp < hp0, "coming back to the spot detonates the mine (§11.12)")
	check(not c.fields.has_kind_at(&"time_mine", Vector3(3, 0, 0)), "and the mine is spent")


func test_ferro_null_shaves_eight_on_any_target_and_adds_dark() -> void:
	_keep_flags()
	var dark0: int = Flags.dark
	var cassia := _party_member(&"cassia", 30, Vector3(-3, 0, 0))
	var crono := _party_member(&"crono", 30, Vector3(-3.5, 0, 0.5))
	var e := _enemy(&"e", 30, Vector3(2, 0, 0), 12, ["ICE"], {"hp": 50000})
	var c := _battle([cassia, crono], [e])
	_cast(c, cassia, &"ferro_null", Vector3(2, 0, 0), null, 0, [cassia, crono])
	check_eq(ShieldComponent.of(e).current_shield, 4, "8 shaved on a target weak to neither tag (§11.12)")
	check_eq(Flags.dark - dark0, 8, "+8 Dark")
	_restore_flags()


func test_empress_cannon_dark_is_capped_per_universe() -> void:
	_keep_flags()
	var dark0: int = Flags.dark
	var krona := _party_member(&"krona", 30, Vector3(-3, 0, 0))
	var cassia := _party_member(&"cassia", 30, Vector3(-3.5, 0, 0.5))
	var e := _enemy(&"e", 30, Vector3(2, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([krona, cassia], [e])
	c.universe = 7
	Flags.counters.erase(&"empress_cannon_dark_u7")
	for i in 7:
		_cast(c, krona, &"empress_cannon", Vector3(2, 0, 0), null, 0, [krona, cassia])
	check_eq(Flags.dark - dark0, 10, "+2 Dark per use, at most +10 in one universe (§11.12)")
	_restore_flags()


func test_ashtear_paradox_galaxy_bonus_and_lucca_schematic() -> void:
	var crono := _party_member(&"crono", 30, Vector3(-3, 0, 0))
	var cassia := _party_member(&"cassia", 30, Vector3(-3.5, 0, 0.5))
	var krona := _party_member(&"krona", 30, Vector3(-3.5, 0, -0.5))
	var e := _enemy(&"e", 30, Vector3(1, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([crono, cassia, krona], [e])
	var tech: TechDef = Data.techs[&"ashtear_paradox"]
	check_near(EffectTable.damage_mult(c, tech, 0, e), 1.0, 0.0001, "no bonus with Crono whole")
	var cst := CombatantStats.of(crono)
	cst.hp = roundi(float(cst.base_max_hp) * 0.2)
	check(c._crono_galaxy(crono), "Crono in his galaxy state")
	check_near(EffectTable.damage_mult(c, tech, 0, e), 1.5, 0.0001, "+50% while his galaxy is open")
	var action: Dictionary = _action(c, crono, &"ashtear_paradox", Vector3(1, 0, 0), null, 0, [crono, cassia, krona])
	action["synergy"] = 3.0
	TechEffects.apply(c, tech, action)
	check_eq(TimeDebtComponent.of(crono).reinforced_jumps, 3, "high synergy: Lucca's schematic, Reinforced for 3 jumps")


# ---------------------------------------------------------------- Chapter 4-5: Xyloph, Vesper

func test_triangulation_and_time_lapse_extend_the_break() -> void:
	var crono := _party_member(&"crono", 30, Vector3(-3, 0, 0))
	var xyloph := _party_member(&"xyloph", 30, Vector3(-3.5, 0, 0.5))
	var e := _enemy(&"e", 30, Vector3(2, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([crono, xyloph], [e])
	var sh := ShieldComponent.of(e)
	sh.force_break(crono)
	var lock0: float = sh.lock_left
	_cast(c, crono, &"triangulation", Vector3(2, 0, 0), null, 0, [crono, xyloph])
	check_near(sh.lock_left - lock0, 1.2, 0.0001, "Triangulation: +1.2 s Break (§5.4)")
	var xy2 := _party_member(&"xyloph", 30, Vector3(10, 0, 0))
	var sera := _party_member(&"sera", 30, Vector3(10, 0, -1))
	var e2 := _enemy(&"e2", 30, Vector3(10, 0, 1.5), 6, ["MYCELIA"], {"hp": 500000})
	var c2 := _battle([xy2, sera], [e2])
	SolidityComponent.of(sera).solidity = 80.0
	var info: Dictionary = _cast(c2, xy2, &"mycelia_time_lapse", c2.position_of(xy2), null, 0, [xy2, sera])
	check((info["targets"] as Array).has(e2), "the aura reaches it")
	check_eq(ShieldComponent.of(e2).current_shield, 6, "Time Lapse shaves nothing (§11.12)")
	check(int(info["damage"].get(e2, 0)) > 0, "but still deals its damage")
	check_near(SolidityComponent.of(sera).solidity, 85.0, 0.0001, "Sera's 5% solidity is refunded")
	check(StatusComponent.of(e2).has(&"time_lapse"), "spore ticks run fast on it")
	check_near(ShieldComponent.of(e2)._lock_extension_pending, 1.5, 0.0001, "and its next Break lasts +1.5 s")
	var pv: Dictionary = c2.preview(xy2, Data.techs[&"mycelia_time_lapse"], null, c2.position_of(xy2), 0)
	check_eq(int(pv.get(e2, {}).get("shave", -1)), 0, "the plate preview agrees: no shave")


func test_time_lapse_speeds_periodic_ticks() -> void:
	var sc := StatusComponent.new()
	_track(sc)
	var ticks: Array = []
	sc.periodic.connect(func(id: StringName, _n: int) -> void: ticks.append(id))
	sc.add(&"burn", 5.0, -1, 1, {"tick": 3})
	sc.add(&"time_lapse", 6.0)
	sc.tick(1.0)
	check_eq(ticks.size(), 3, "a 1 s burn ticks three times in one second under Time Lapse")


func test_reptite_crown_canopy_grows_sunlight() -> void:
	var xyloph := _party_member(&"xyloph", 40, Vector3(-3, 0, 0))
	var e := _enemy(&"e", 40, Vector3(1, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([xyloph], [e])
	c.universe = 3
	check_near(EffectTable.damage_mult(c, Data.techs[&"reptite_crown"], 0, e), 1.5, 0.0001, "+50% under the Lavos moon (U3)")
	_cast(c, xyloph, &"reptite_crown", Vector3(1, 0, 0))
	for i in 11:
		FieldEffects.tick(c, 1.0)
	check_eq(int(xyloph.get_meta("sunlight", 0)), 2, "+1 Sunlight Stack every 5 s (§11.6)")
	check_near(EffectTable.damage_mult(c, Data.techs[&"solar_winds"], 0, e), 1.35, 0.0001, "Solar Winds +35% with Sunlight Stacks")


func test_lily_lancets_plus_two_in_the_plate_colour_and_preview_parity() -> void:
	var vesper := _party_member(&"vesper", 30, Vector3(-3, 0, 0))
	var e := _enemy(&"e", 30, Vector3(2, 0, 0), 12, ["VITREOUS"], {"hp": 500000})
	var c := _battle([vesper], [e])
	var tech: TechDef = Data.techs[&"lily_lancets"]
	check_eq(EffectTable.shave_bonus(c, tech, 0, e), 0, "an unrevealed plate gives no colour bonus")
	ShieldComponent.of(e).reveal_all()
	check_eq(EffectTable.shave_bonus(c, tech, 0, e), 2, "+2 when it lands in the colour the plate shows (§5.3)")
	var pv: Dictionary = c.preview(vesper, tech, null, Vector3(2, 0, 0), 0)
	var info: Dictionary = _cast(c, vesper, &"lily_lancets", Vector3(2, 0, 0))
	check_eq(int(info["shave"].get(e, -1)), int(pv.get(e, {}).get("shave", -2)), "the preview shows the shave the lancets do")
	check_eq(int(info["shave"].get(e, 0)), 5, "3 lancets + 2")


func test_ash_graveyard_turns_ash_into_a_healing_caustic_floor() -> void:
	var krona := _party_member(&"krona", 35, Vector3(1, 0, 0))
	var vesper := _party_member(&"vesper", 35, Vector3(-3, 0, 0))
	var e := _enemy(&"e", 35, Vector3(2, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([krona, vesper], [e])
	c.fields.add(&"ash_field", Vector3(1, 0, 0), 2.0, -1.0, 0)
	_cast(c, krona, &"ash_graveyard", Vector3(1.5, 0, 0), null, 0, [krona, vesper])
	check(c.fields.has_kind_at(&"caustic_floor", Vector3(1, 0, 0)) and not c.fields.has_kind_at(&"ash_field", Vector3(1, 0, 0)), "the Ash becomes stained glass (§11.12)")
	var st := CombatantStats.of(krona)
	st.hp = roundi(float(st.max_hp()) * 0.5)
	var hp0: int = st.hp
	FieldEffects.tick(c, 2.1)
	check_eq(st.hp - hp0, roundi(float(st.max_hp()) * 0.03), "allies on it heal 3% per 2 s")


func test_rose_window_makes_party_hits_vitreous() -> void:
	var vesper := _party_member(&"vesper", 40, Vector3(-3, 0, 0))
	var crono := _party_member(&"crono", 40, Vector3(-3, 0, 1))
	var e := _enemy(&"e", 40, Vector3(2, 0, 0), 4, ["VITREOUS"], {"hp": 500000})
	var c := _battle([vesper, crono], [e])
	_cast(c, vesper, &"rose_window", c.position_of(vesper), null, 3)
	check(StatusComponent.of(crono).has(&"rose_window"), "the party is under the Rose for 8 s")
	check(FieldEffects.hit_tags(c, crono, e, [&"SWORD"]).has(&"VITREOUS"), "Crono's sword hit is VITREOUS (§11.7)")
	check(FieldEffects.hit_tags(c, crono, e, [&"SWORD"]).has(&"SWORD"), "and keeps its other tags")


func test_anachronism_glass_wards_allies_inside() -> void:
	var vesper := _party_member(&"vesper", 50, Vector3(0, 0, 0))
	var static_u := _party_member(&"static", 50, Vector3(0.5, 0, 0))
	var far := _party_member(&"crono", 50, Vector3(-20, 0, 0))
	var e := _enemy(&"e", 50, Vector3(1, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([vesper, static_u, far], [e])
	_cast(c, vesper, &"anachronism_glass", Vector3(0, 0, 0), null, 0, [vesper, static_u])
	check_eq(StatusComponent.of(static_u).stacks(&"glass_ward"), 2, "Glass Ward: the next 2 hits halved (§11.12)")
	check(not StatusComponent.of(far).has(&"glass_ward"), "not for an ally outside the circle")


# ---------------------------------------------------------------- Chapter 6-7: Glenn, Static

func test_ruin_elastic_decoy_draws_the_next_action() -> void:
	var krona := _party_member(&"krona", 40, Vector3(-2, 0, 0))
	var glenn := _party_member(&"glenn", 40, Vector3(-2.5, 0, 0.5))
	var e := _enemy(&"e", 40, Vector3(2, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([krona, glenn], [e])
	_cast(c, krona, &"ruin_elastic", Vector3.ZERO, e, 0, [krona, glenn])
	check(StatusComponent.of(e).has(&"decoyed"), "the elastic decoy is out")
	var hit := {"tags": ["BLUNT"], "power": 1.0, "hits": 1, "wind_up_s": 1.0}
	check_eq(EnemyStrike.resolve(c, e, krona, hit, 1, 0), 0, "its next action lands on the decoy (§11.12)")


func test_masque_feint_reflects_the_stored_attack() -> void:
	var glenn := _party_member(&"glenn", 40, Vector3(-2, 0, 0))
	var vesper := _party_member(&"vesper", 40, Vector3(-2.5, 0, 0.5))
	var e := _enemy(&"e", 40, Vector3(2, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([glenn, vesper], [e])
	StatusComponent.of(e).add(&"haste", 10.0)
	_cast(c, glenn, &"masque_feint", Vector3.ZERO, e, 0, [glenn, vesper])
	check(not StatusComponent.of(e).has(&"haste") and StatusComponent.of(glenn).has(&"haste"), "steals one buff")
	var hp_e: int = CombatantStats.of(e).hp
	var hp_g: int = CombatantStats.of(glenn).hp
	var hit := {"tags": ["BLUNT"], "power": 1.0, "hits": 1, "wind_up_s": 1.0}
	EnemyStrike.resolve(c, e, glenn, hit, 1, 0)
	check_eq(CombatantStats.of(glenn).hp, hp_g, "the undermask takes Glenn's hit")
	check(CombatantStats.of(e).hp < hp_e, "and reflects it onto its maker")


func test_carnival_of_souls_overcap_lasts_until_the_next_ally_turn_ends() -> void:
	var glenn := _party_member(&"glenn", 50, Vector3(-2, 0, 0))
	var vesper := _party_member(&"vesper", 50, Vector3(-2.5, 0, 0.5))
	var cassia := _party_member(&"cassia", 50, Vector3(-2.5, 0, -0.5))
	var e := _enemy(&"e", 50, Vector3(1, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([glenn, vesper, cassia], [e])
	c.bank.bp = c.bank.max_bp - 1
	_cast(c, glenn, &"carnival_of_souls", c.position_of(glenn), null, 0, [glenn, vesper, cassia])
	check_eq(c.bank.bp, c.bank.max_bp + 1, "+3 BP, one over the cap (§11.13)")
	for i in 3:
		c.bank.clamp_overflow()  # the three casters' own turn ends
	check_eq(c.bank.bp, c.bank.max_bp + 1, "it survives the casters' turn ends")
	c.bank.clamp_overflow()  # the next ally's
	check_eq(c.bank.bp, c.bank.max_bp, "and is clamped when the next ally's turn ends")


func test_chrono_laugh_splits_a_shared_shield_and_breaks_the_smallest() -> void:
	var crono := _party_member(&"crono", 40, Vector3(0, 0, 0))
	var sera := _party_member(&"sera", 40, Vector3(-0.5, 0, 0))
	var glenn := _party_member(&"glenn", 40, Vector3(0, 0, -0.5))
	var a := _enemy(&"a", 40, Vector3(2, 0, 0), 9, ["FIRE"], {"hp": 500000})
	var b := _enemy(&"b", 40, Vector3(2, 0, 1), 9, ["FIRE"], {"hp": 500000})
	ShieldComponent.of(a).shared_group = &"choir"
	ShieldComponent.of(b).shared_group = &"choir"
	var c := _battle([crono, sera, glenn], [a, b])
	check(ShieldComponent.of(b).shared_owner != null, "the two share one plate count")
	var info: Dictionary = _cast(c, crono, &"chrono_laugh", Vector3(0, 0, 0), null, 0, [crono, sera, glenn])
	check(ShieldComponent.of(a).shared_owner == null and ShieldComponent.of(b).shared_owner == null, "the shared shield is split into individual shields")
	check_eq((info["breaks"] as Array).size(), 1, "the smallest Breaks at once (§11.13)")


func test_hz_white_noise_hides_the_second_weakness_for_a_turn() -> void:
	var stat := _party_member(&"static", 55, Vector3(-2, 0, 0))
	var e := _enemy(&"e", 55, Vector3(1, 0, 0), 12, ["ICE", "FIRE"], {"hp": 500000})
	var c := _battle([stat], [e])
	var sh := ShieldComponent.of(e)
	sh.reveal_all()
	_cast(c, stat, &"hz_white_noise", Vector3(1, 0, 0), null, 3)
	check(not sh.is_revealed(&"FIRE") and sh.is_revealed(&"ICE"), "the second weakness reads [?] again (§11.9)")
	var sc := StatusComponent.of(e)
	sc.on_turn_taken()
	sc.on_turn_taken()
	check(sh.is_revealed(&"FIRE"), "and shows again after its turn")


func test_akira_in_utero_gives_every_enemy_hz_for_ten_seconds() -> void:
	var stat := _party_member(&"static", 60, Vector3(-2, 0, 0))
	var e := _enemy(&"e", 60, Vector3(1, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([stat], [e])
	_cast(c, stat, &"akira_in_utero", Vector3.ZERO)
	var sh := ShieldComponent.of(e)
	check(sh.weaknesses.has(&"HZ") and sh.hits_weakness([&"HZ"]), "[HZ] is a real weakness (§11.9)")
	StatusComponent.of(e).tick(10.5)
	check(not sh.weaknesses.has(&"HZ"), "for 10 s")


func test_graviton_whiteout_stops_the_rebuild() -> void:
	var cassia := _party_member(&"cassia", 55, Vector3(-2, 0, 0))
	var stat := _party_member(&"static", 55, Vector3(-2.5, 0, 0.5))
	var e := _enemy(&"e", 55, Vector3(1, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([cassia, stat], [e])
	var sh := ShieldComponent.of(e)
	sh.force_break(cassia)
	var lock0: float = sh.lock_left
	_cast(c, cassia, &"graviton_whiteout", Vector3(1, 0, 0), null, 0, [cassia, stat])
	check_near(sh.lock_left - lock0, 5.0, 0.0001, "no rebuild for 5 s (§5.4)")


func test_56k_prayer_grows_with_each_debuff() -> void:
	var stat := _party_member(&"static", 55, Vector3(-2, 0, 0))
	var e := _enemy(&"e", 55, Vector3(1, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([stat], [e])
	var tech: TechDef = Data.techs[&"56k_prayer"]
	var sc := StatusComponent.of(e)
	sc.add(&"blind", 10.0)
	sc.add(&"magnetized", -1.0, 2)
	sc.add(&"haste", 10.0)
	check_near(EffectTable.damage_mult(c, tech, 0, e), 1.30, 0.0001, "+15% per debuff (two), a buff does not count (§11.9)")


func test_chrono_prism_needs_crono_at_sixty_percent() -> void:
	var vesper := _party_member(&"vesper", 40, Vector3(-2, 0, 0))
	var crono := _party_member(&"crono", 40, Vector3(-2.5, 0, 0.5))
	var e := _enemy(&"e", 40, Vector3(1, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([vesper, crono], [e])
	var tech: TechDef = Data.techs[&"chrono_prism"]
	check(not EffectTable.requirements_met(c, vesper, tech), "refused while Crono is above 60% (§11.12)")
	var cst := CombatantStats.of(crono)
	cst.hp = roundi(float(cst.base_max_hp) * 0.5)
	check(EffectTable.requirements_met(c, vesper, tech), "offered at or below 60%")
	check(c._actor_knows(vesper, tech), "the coordinator's knows-check offers it then")
	cst.hp = cst.base_max_hp
	check(not c._actor_knows(vesper, tech), "the coordinator's knows-check refuses it too")


func test_the_last_joke_cracks_vaelos_for_three_hits() -> void:
	var glenn := _party_member(&"glenn", 70, Vector3(-2, 0, 0))
	var vaelos := _enemy(&"vaelos", 75, Vector3(1, 0, 0), 4, ["ICE"], {"hp": 900000, "kind": "boss"})
	var c := _battle([glenn], [vaelos])
	var tech: TechDef = Data.techs[&"the_last_joke"]
	check(EffectTable.requirements_met(c, glenn, tech), "offered against Vaelos")
	_cast(c, glenn, &"the_last_joke", Vector3.ZERO, vaelos)
	var sc := StatusComponent.of(vaelos)
	check_eq(sc.stacks(&"exposed"), 3, "his next 3 received hits ignore DEF (§11.8)")
	var ctx := {"def": 500.0, "resist": 1.0}
	EffectTable.adjust_hit(ctx, sc)
	check(float(ctx["def"]) == 0.0 and sc.stacks(&"exposed") == 2, "one hit spends one")
	var glenn2 := _party_member(&"glenn", 70, Vector3(-2, 0, 2))
	var c2 := _battle([glenn2], [_enemy(&"crow", 10, Vector3(1, 0, 2), 4, ["ICE"])])
	check(not EffectTable.requirements_met(c2, glenn2, tech), "never offered without him")


func test_gold_leaf_severance_needs_stacks_and_makes_a_true_null_pocket() -> void:
	var omega := _party_member(&"omega", 70, Vector3(-2, 0, 0))
	var e := _enemy(&"e", 70, Vector3(1, 0, 0), 4, ["NULL"], {"hp": 900000})
	var c := _battle([omega], [e])
	var tech: TechDef = Data.techs[&"gold_leaf_severance"]
	check(not EffectTable.requirements_met(c, omega, tech), "no Gold Leaf stacks, no pocket (§11.10)")
	StatusComponent.of(omega).add(&"gold_leaf", -1.0, -1, 4)
	check(EffectTable.requirements_met(c, omega, tech), "3 stacks or more: offered")
	_cast(c, omega, &"gold_leaf_severance", Vector3.ZERO)
	check(not StatusComponent.of(omega).has(&"gold_leaf"), "the stacks are spent")
	var ctx := {"def": 400.0, "resist": 0.5, "weakness": true}
	EffectTable.adjust_hit(ctx, StatusComponent.of(e))
	check(float(ctx["def"]) == 0.0 and float(ctx["resist"]) == 1.0 and not bool(ctx["weakness"]), "inside the pocket every party hit is true damage")


func test_omega_triple_gives_the_party_null_shield() -> void:
	var crono := _party_member(&"crono", 60, Vector3(-2, 0, 0))
	var e := _enemy(&"e", 60, Vector3(1, 0, 0), 4, ["ICE"], {"hp": 500000})
	var c := _battle([crono], [e])
	var hit := {"tags": ["BLUNT"], "power": 1.0, "hits": 1, "wind_up_s": 1.0}
	_sturdy(crono)
	var open: int = EnemyStrike.resolve(c, e, crono, hit, 1, 0)
	_sturdy(crono)
	StatusComponent.of(crono).add(&"null_shield")
	var shielded: int = EnemyStrike.resolve(c, e, crono, hit, 1, 0)
	check_near(float(shielded), float(open) * 0.8, 1.0, "NULL SHIELD: 20% less damage (§12.4)")


# ---------------------------------------------------------------- enemy effects

func test_daimyo_oil_flood_is_an_enemy_ash_field() -> void:
	var crono := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var daimyo := _enemy(&"goyama_ashen_daimyo", 12, Vector3(2, 0, 0), 8, ["ASTRAL"], {"hp": 50000, "kind": "boss"})
	var ally_e := _enemy(&"ashigaru", 10, Vector3(3, 0, 0), 2, ["ASTRAL"], {"hp": 5000})
	var c := _battle([crono], [daimyo, ally_e])
	var flood: Dictionary = {}
	for ph in Data.bosses[&"goyama_ashen_daimyo"]["phases"]:
		for a in ph.get("actions", []):
			if a.get("effect", "") == "spawn_ash_field":
				flood = a
	check(not flood.is_empty(), "the Daimyo's phase 3 floods the arena with oil (data)")
	EnemyEffects.apply(c, daimyo, flood, [{"node": crono, "hits": 1, "rank": 0}])
	FieldEffects.tick(c, 2.1)
	check(StatusComponent.of(crono).has(&"ash_field"), "the party stands in his Ash: 0.5x movement")
	check(not StatusComponent.of(ally_e).has(&"ash_field"), "his own side does not")
	check_near(StatusRules.move_range(crono), CombatantStats.of(crono).move_range * 0.5, 0.001, "cmd_move reads it")


func test_steal_bp_is_the_coordinators_bp_steal() -> void:
	var crono := _party_member(&"crono", 10, Vector3(-2, 0, 0))
	var e := _enemy(&"x", 12, Vector3(2, 0, 0), 4, ["ASTRAL"], {"hp": 50000})
	var c := _battle([crono], [e])
	c.bank.bp = 3
	var drain := {"id": "drain", "tags": ["OIL"], "shape": "SINGLE", "power": 0.0, "hits": 1, "effect": "steal_bp", "bp_steal": 1, "targets": [crono]}
	c._execute_enemy_action(e, drain)
	check_eq(c.bank.bp, 2, "1 BP leaves the pool")
	check_eq(int(e.get_meta("stolen_bp", 0)), 1, "into its visible counter (§7.5)")


func test_cloak_and_the_lucca_lens() -> void:
	var cassia := _party_member(&"cassia", 25, Vector3(-2, 0, 0))
	var raptor := _enemy(&"porcelain_raptor", 25, Vector3(1, 0, 0), 4, ["FERRO"], {"hp": 50000})
	var c := _battle([cassia], [raptor])
	EnemyEffects.apply(c, raptor, {"effect": "cloak", "self_target": true}, [])
	check(not c.targetable_enemies().has(raptor), "a cloaked Raptor cannot be targeted (§13.5)")
	c.fields.add(&"static_field", Vector3(1, 0, 0), 2.0, 6.0, 0)
	check(c.targetable_enemies().has(raptor), "nothing is untargetable inside a static field")
	c.fields.clear()
	_cast(c, cassia, &"mercury_pulse", c.position_of(cassia))
	check(c.targetable_enemies().has(raptor), "a Mercury Pulse lights it up")


func test_oil_pool_slows_and_blights_the_party_inside() -> void:
	var crono := _party_member(&"crono", 15, Vector3(1, 0, 0))
	var leaker := _enemy(&"mercury_leaker", 15, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000})
	var c := _battle([crono], [leaker])
	EnemyEffects.apply(c, leaker, {"effect": "oil_pool", "radius": 3.0, "aim": Vector3(1, 0, 0)}, [])
	FieldEffects.tick(c, 0.1)
	check(StatusComponent.of(crono).has(&"mercury_slow"), "Mercury SLOW to anyone standing in it")
	check(c.oil_blight, "and Oil-Blight on the pool")


func test_split_on_half_sheds_its_fawns_once() -> void:
	var crono := _party_member(&"crono", 60, Vector3(-2, 0, 0))
	var vb := _enemy(&"vertebray", 63, Vector3(2, 0, 0), 12, ["MYCELIA"], {"hp": 50000})
	var c := _battle([crono], [vb])
	var asked: Array = []
	c.summon_requested.connect(func(key: StringName, n: int, _near: Node) -> void: asked.append([key, n]))
	var shed := {"effect": "split_on_half"}
	EnemyEffects.apply(c, vb, shed, [])
	EnemyEffects.apply(c, vb, shed, [])
	check_eq(asked.size(), 1, "split_on_half fires once (§13.9)")
	check(not asked.is_empty() and asked[0][0] == &"vertebray_fawn" and asked[0][1] == 2, "two Vertebray Fawns")


func test_drift_fast_skids_after_acting_unless_broken() -> void:
	var crono := _party_member(&"crono", 15, Vector3(-3, 0, 0))
	var bros := _enemy(&"bike_bros", 15, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 50000})
	var c := _battle([crono], [bros])
	EnemyEffects.apply(c, bros, {"effect": "drift_fast"}, [{"node": crono, "hits": 1, "rank": 0}])
	check_near(c.position_of(bros).distance_to(Vector3(3, 0, 0)), EnemyEffects.DRIFT_M, 0.01, "it skids sideways (§5.5)")
	var before: Vector3 = c.position_of(bros)
	ShieldComponent.of(bros).force_break(crono)
	EnemyEffects.apply(c, bros, {"effect": "drift_fast"}, [{"node": crono, "hits": 1, "rank": 0}])
	check(c.position_of(bros) == before, "a Break pins it for the line-up")
