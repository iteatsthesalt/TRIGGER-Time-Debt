## The resolution pipeline (audit cluster "pipeline"): turn statuses a caster gives itself, the Boosted Attack,
## NULL's true damage, HOLD, per-caster cooldowns, Sera's TACHYON turns, every residual and floor field, the
## Divinity Field, Lv3 fields, the Break that ends a telegraph, preview parity on fields and on damage, the Dual's
## best caster, the cap upgrades and the hooks that used to be dead.
extends "res://tests/suite_base.gd"


## `_lib()` plus the data techs `ids` and hand-built `extra` techs.
func _with(ids: Array, extra: Array = []) -> Dictionary:
	var lib: Dictionary = _lib()
	for id in ids:
		lib[StringName(String(id))] = Data.techs[StringName(String(id))]
	for d in extra:
		var t := TechDef.from_dict(d)
		lib[t.id] = t
	return lib


func _sturdy(u: Node) -> void:
	var st := CombatantStats.of(u)
	st.base_max_hp = 100000
	st.hp = 100000


# ---------------------------------------------------------------- COMBAT-3: turn statuses a caster gives itself

func test_prism_guard_lasts_until_his_next_turn() -> void:
	var c := _coord()
	var vesper := _party_member(&"vesper", 40, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 40, Vector3(3, 0, 0), 4, ["BLUNT"], {"hp": 100000})
	_start(c, [vesper], [e], {"techs": _with(["prism_guard"])})
	check(c._ko_callables.has(vesper), "_init_unit hooks a party member's KO")
	check(CombatantStats.of(vesper).defeated.is_connected(c._ko_callables.get(vesper, Callable())),
		"its defeated signal reaches _on_unit_defeated")
	_sturdy(vesper)
	check(_advance_until_actor(c, &"vesper") == vesper, "Vesper's window opens")
	var r: Dictionary = c.cmd_tech(vesper, &"prism_guard", null, c.position_of(vesper), 0)
	check(bool(r.get("ok", false)), "Prism Guard is cast")
	var sc := StatusComponent.of(vesper)
	check(sc.has(&"prism_guard"), "the cast's own turn does not consume it (§10.6)")
	check_near(sc.damage_taken_multiplier(), 0.6, 0.0001, "-40% damage taken while it holds")
	var hit := {"tags": ["BLUNT"], "power": 1.0, "hits": 1, "wind_up_s": 1.0}
	var guarded: int = EnemyStrike.resolve(c, e, vesper, hit, 1, 0)
	sc.remove(&"prism_guard")
	var open: int = EnemyStrike.resolve(c, e, vesper, hit, 1, 0)
	check_near(float(guarded), float(open) * 0.6, 1.0, "an enemy hit between his turns lands at 60%")
	sc.add(&"prism_guard", -1.0, 1)  # as the next cast would leave it, outside an action
	check(_advance_until_actor(c, &"vesper") == vesper, "his next window")
	check(sc.has(&"prism_guard"), "still up when his next turn comes")
	c.cmd_guard(vesper)
	check(not sc.has(&"prism_guard"), "and it ends with that turn")


func test_rooted_and_fragile_count_the_casters_next_turns() -> void:
	var c := _coord()
	var xyloph := _party_member(&"xyloph", 25, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 25, Vector3(1, 0, 0), 4, ["ICE"], {"hp": 100000})
	_start(c, [xyloph], [e], {"techs": _with(["photosynthetic_burst"])})
	_sturdy(xyloph)
	check(_advance_until_actor(c, &"xyloph") == xyloph, "Xyloph's window opens")
	var r: Dictionary = c.cmd_tech(xyloph, &"photosynthetic_burst", e, c.position_of(e), 0)
	check(bool(r.get("ok", false)), "Photosynthetic Burst is cast")
	var sc := StatusComponent.of(xyloph)
	check(sc.has(&"rooted"), "Rooted (1 turn) survives the cast that gave it (§11.6)")
	check_near(sc.damage_taken_multiplier(), 1.0 - CombatConstants.PHOTOSYNTHETIC_DR, 0.0001, "+70% damage reduction meanwhile")
	_advance_until_actor(c, &"xyloph")
	c.cmd_guard(xyloph)
	check(not sc.has(&"rooted"), "and is gone after her next action")
	# Fractured Lens: Vesper to 1 HP and Fragile for 2 of his turns (§11.7).
	var c2 := _coord()
	var vesper := _party_member(&"vesper", 40, Vector3(-3, 0, 0))
	var e2 := _enemy(&"y", 40, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 100000})
	_start(c2, [vesper], [e2], {"techs": _with(["fractured_lens"])})
	c2.party_hp_floor = 1  # nothing takes him below the 1 HP he paid
	_advance_until_actor(c2, &"vesper")
	check(bool(c2.cmd_tech(vesper, &"fractured_lens", null, c2.position_of(vesper), 0).get("ok", false)), "Fractured Lens is cast")
	var sc2 := StatusComponent.of(vesper)
	check_eq(CombatantStats.of(vesper).hp, 1, "he pays down to 1 HP")
	check(sc2.has(&"fragile"), "Fragile is on after the cast")
	_advance_until_actor(c2, &"vesper")
	c2.cmd_guard(vesper)
	check(sc2.has(&"fragile"), "one of his turns later it is still on")
	_advance_until_actor(c2, &"vesper")
	c2.cmd_guard(vesper)
	check(not sc2.has(&"fragile"), "two of his turns later it is gone")


func test_a_status_landing_on_a_parked_ally_counts_its_next_action() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var krona := _party_member(&"krona", 10, Vector3(-3, 0, 2))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 100000})
	_start(c, [crono, krona], [e])
	_sturdy(crono)
	_sturdy(krona)
	var first: Node = _advance_until_window(c)
	check(SyncHoldRules.can_hold(c, first), "the first ally may park")
	c.cmd_sync_hold(first)
	var sc := StatusComponent.of(first)
	sc.add(&"displaced", -1.0, 1)  # an enemy's debuff while it waits
	var second: Node = _advance_until_window(c)
	check(second != null and second != first, "the partner's window opens")
	c.cmd_guard(second)
	check(c.active_actor == first, "the parked ally gets the floor back")
	c.cmd_guard(first)
	check(not sc.has(&"displaced"), "a 1-turn debuff given while parked ends with its next action")


# ---------------------------------------------------------------- COMBAT-5: the Boosted Attack

func test_boosted_attack_scales_power_and_shape_only() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 8, ["ICE"], {"hp": 100000})
	_start(c, [crono], [e], {"max_bp": 6, "max_spend": 4})
	_sturdy(crono)
	_advance_until_window(c)
	c.bank.bp = 4
	var r: Dictionary = c.cmd_attack(crono, e, 4)
	check(bool(r.get("ok", false)), "a Boost Lv4 Attack is accepted")
	var sc := StatusComponent.of(e)
	check(not sc.has(&"displaced") and sc.ids().is_empty(), "it adds no Lv2 debuff (§4.2, §7.2)")
	check(c.fields.fields.is_empty(), "and leaves no residual field")
	_advance_until_window(c)
	c.bank.bp = 2
	c.cmd_tech(crono, &"time_slice", e, c.position_of(e), 2)
	check(sc.has(&"displaced"), "a technique at Lv2 does add its element's debuff")


# ---------------------------------------------------------------- COMBAT-13: NULL is true damage

func test_null_true_damage_runs_the_whole_pipeline_without_defence() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 20, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 20, Vector3(3, 0, 0), 3, ["FIRE"], {"hp": 100000, "resists": ["NULL"]})
	var null_cut := {"id": "null_cut", "name": "Null Cut", "tier": "single", "actors": ["crono"], "tags": ["NULL"], "shape": "SINGLE", "hits": 1, "power": 1.0, "uses": "PHYSICAL", "costs": {}}
	_start(c, [crono], [e], {"techs": _with([], [null_cut])})
	_sturdy(crono)
	_advance_until_window(c)
	var a := CombatantStats.of(crono)
	var ctx := {"atk": a.p_atk, "def": 0.0, "base": 1.0, "party_synergy": PartyHit.party_synergy(c), "home_canvas": PartyHit.home_canvas(c, crono), "variance": 1.0}
	var want: int = int(DamagePipeline.compute_hit(ctx)["damage"])
	var r: Dictionary = c.cmd_tech(crono, &"null_cut", e, c.position_of(e), 0)
	check_eq(int(r["info"]["damage"][e]), want, "NULL ignores DEF and the resistance and keeps canvas and synergy (§6.3)")
	_advance_until_window(c)
	ShieldComponent.of(e).force_break(crono)
	ctx["broken"] = true
	var r2: Dictionary = c.cmd_tech(crono, &"null_cut", e, c.position_of(e), 0)
	check_eq(int(r2["info"]["damage"][e]), int(DamagePipeline.compute_hit(ctx)["damage"]), "every hit on a Broken target is critical, NULL's too")
	# A natural NULL weakness shaves but does not multiply; a weakness NULL created does.
	var c2 := _coord()
	var crono2 := _party_member(&"crono", 20, Vector3(-3, 0, 0))
	var weak := _enemy(&"w", 20, Vector3(3, 0, 0), 6, ["NULL"], {"hp": 100000})
	_start(c2, [crono2], [weak], {"techs": _with([], [null_cut])})
	_sturdy(crono2)
	_advance_until_window(c2)
	var ctx2 := {"atk": CombatantStats.of(crono2).p_atk, "def": 0.0, "base": 1.0, "party_synergy": PartyHit.party_synergy(c2), "home_canvas": PartyHit.home_canvas(c2, crono2), "variance": 1.0}
	var r3: Dictionary = c2.cmd_tech(crono2, &"null_cut", weak, c2.position_of(weak), 0)
	check_eq(int(r3["info"]["shave"][weak]), 1, "the NULL match still shaves")
	check_eq(int(r3["info"]["damage"][weak]), int(DamagePipeline.compute_hit(ctx2)["damage"]), "but no weakness multiplier (§6.3)")
	_advance_until_window(c2)
	StatusComponent.of(weak).add(&"nulled_weakness", -1.0, -1, 1, {"tag": &"NULL"})
	ctx2["weakness"] = true
	var r4: Dictionary = c2.cmd_tech(crono2, &"null_cut", weak, c2.position_of(weak), 0)
	check_eq(int(r4["info"]["damage"][weak]), int(DamagePipeline.compute_hit(ctx2)["damage"]), "a weakness NULL created multiplies (§9.3)")


# ---------------------------------------------------------------- COMBAT-15: Sera's TACHYON turns

func test_any_tachyon_technique_skips_seras_solidity_regen() -> void:
	var c := _coord()
	var sera := _party_member(&"sera", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 6, ["ICE"], {"hp": 100000})
	var probe := {"id": "tachyon_probe", "name": "Tachyon Probe", "tier": "single", "actors": ["sera"], "tags": ["TACHYON", "PIERCING"], "shape": "SINGLE", "hits": 1, "power": 0.5, "uses": "ELEMENTAL", "costs": {"sera": {"mp": 1}}}
	_start(c, [sera], [e], {"techs": _with([], [probe])})
	_sturdy(sera)
	var sol := SolidityComponent.of(sera)
	_advance_until_window(c)
	TechCosts.spend_solidity(c, sera, 20.0)
	var before: float = sol.solidity
	check(bool(c.cmd_tech(sera, &"tachyon_probe", e, c.position_of(e), 0).get("ok", false)), "a TACHYON tech with no special effect")
	check_near(sol.solidity, before, 0.001, "gives back no solidity that turn (§10.2)")
	_advance_until_window(c)
	c.cmd_guard(sera)
	check_near(sol.solidity, before + CombatConstants.SERA_TURN_REGEN, 0.001, "a turn without TACHYON gives back 2")


# ---------------------------------------------------------------- COMBAT-16: HOLD

func test_hold_needs_a_broken_target_and_takes_steps() -> void:
	var c := _coord()
	var sera := _party_member(&"sera", 10, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 6, ["ICE"], {"hp": 100000})
	_start(c, [sera], [e], {"techs": _with(["hold"])})
	_sturdy(sera)
	var sol := SolidityComponent.of(sera)
	_advance_until_window(c)
	var s0: float = sol.solidity
	var r: Dictionary = c.cmd_tech(sera, &"hold", e, c.position_of(e), 0)
	check(not bool(r.get("ok", true)) and String(r.get("error", "")).contains("Broken"), "HOLD on an unbroken enemy is refused and says why")
	check_near(sol.solidity, s0, 0.001, "nothing is paid")
	check(c.state == BattleCoordinator.State.COMMAND_WAIT and c.active_actor == sera, "and her turn is still hers")
	var sh := ShieldComponent.of(e)
	sh.force_break(sera)
	var lock0: float = sh.lock_left
	var r2: Dictionary = c.cmd_tech(sera, &"hold", e, c.position_of(e), 0, [], {"steps": 2})
	check(bool(r2.get("ok", false)), "HOLD on the Broken enemy")
	check_near(sh.lock_left, lock0 + 2.0 * CombatConstants.SERA_HOLD_BREAK_EXTENSION_S, 0.001, "two steps: +2.5 s each (§10.2)")
	check_near(sol.solidity, s0 - 2.0 * CombatConstants.SERA_HOLD_STEP, 0.001, "for 5% solidity each")
	check(Data.techs[&"hold"].requires_broken, "the data says HOLD needs a Broken target")


# ---------------------------------------------------------------- COMBAT-22: cooldowns belong to the caster

func test_cooldowns_count_the_casters_own_turns() -> void:
	var c := _coord()
	var cassia := _party_member(&"cassia", 15, Vector3(-3, 0, 0))
	var crono := _party_member(&"crono", 15, Vector3(-3, 0, 2))
	var e := _enemy(&"x", 15, Vector3(1, 0, 0), 6, ["ICE"], {"hp": 100000})
	_start(c, [cassia, crono], [e], {"techs": _with(["mercury_pulse"])})
	_sturdy(cassia)
	_sturdy(crono)
	check(_advance_until_actor(c, &"cassia") == cassia, "Cassia-09's window")
	var pulse: TechDef = c.tech_library[&"mercury_pulse"]
	check(bool(c.cmd_tech(cassia, &"mercury_pulse", null, c.position_of(cassia), 0).get("ok", false)), "Mercury Pulse is cast")
	check_eq(c.cooldowns.left(cassia, pulse.id), 2, "the cast itself does not count down its cooldown")
	c.finish_turn(crono, 0.0)
	c.finish_turn(crono, 0.0)
	check_eq(c.cooldowns.left(cassia, pulse.id), 2, "another ally's turns do not recharge it")
	check_eq(c.cooldowns.left(crono, pulse.id), 0, "and it is not his to wait for")
	c.finish_turn(cassia, 0.0)
	check_eq(c.cooldowns.left(cassia, pulse.id), 1, "one of her own turns")
	check(not c.available_techs(cassia).has(pulse), "still recharging")
	var pool: Dictionary = c.fields.add(&"amber_pool", c.position_of(cassia), 2.0, 6.0, 0)
	check(c.available_techs(cassia).has(pulse), "standing in an amber pool recharges it at once (§7.4)")
	FieldEffects.tick(c, 0.1)
	c.fields.fields.erase(pool)
	check_eq(c.cooldowns.left(cassia, pulse.id), 0, "and the pool's tick clears it for good")
	c.cooldowns.start(cassia, pulse)
	c.finish_turn(cassia, 0.0)
	c.finish_turn(cassia, 0.0)
	check_eq(c.cooldowns.left(cassia, pulse.id), 0, "two of her turns and it is back")


# ---------------------------------------------------------------- COMBAT-18: residual and floor fields

func test_ghost_ring_static_field_and_confetti_pit() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var sera := _party_member(&"sera", 10, Vector3(-3, 0, 3))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 8, ["ICE"], {"hp": 100000})
	_start(c, [crono, sera], [e])
	_sturdy(crono)
	var out_c: float = c.gauge_fill(crono, 1.0)
	var out_s: float = c.gauge_fill(sera, 1.0)
	c.fields.add(&"ghost_ring", c.position_of(crono), 1.5, 6.0, 0)
	c.fields.add(&"ghost_ring", c.position_of(sera), 1.5, 6.0, 0)
	check_near(c.gauge_fill(crono, 1.0), out_c * FieldEffects.GHOST_RING_FILL, 0.0001, "a ghost ring fills an ally's gauge 1.15x (§7.4)")
	check_near(c.gauge_fill(sera, 1.0), out_s, 0.0001, "but not Sera's: she never touches the floor (§10.2)")
	StatusComponent.of(e).add(&"untargetable", 10.0)
	check(not c.targetable_enemies().has(e), "an untargetable enemy is not offered")
	c.fields.add(&"static_field", c.position_of(e), 1.5, 6.0, 0)
	check(c.targetable_enemies().has(e), "inside a static field it cannot be untargetable (§7.4)")
	StatusComponent.of(e).remove(&"untargetable")
	c.fields.add(&"confetti_pit", c.position_of(e), 1.5, 6.0, 0)
	var a: Node = _advance_until_window(c)
	var bp0: int = c.bank.bp
	c.cmd_attack(a, e, 0)
	check_eq(c.bank.bp, bp0 + 1, "an enemy hit in a confetti pit drops 1 BP")
	var a2: Node = _advance_until_window(c)
	var bp1: int = c.bank.bp
	c.cmd_attack(a2, e, 0)
	check_eq(c.bank.bp, bp1, "once per enemy")


func test_caustic_floor_and_white_blank_change_the_tags_preview_and_hit_alike() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-4, 0, 0))
	var e := _enemy(&"x", 10, Vector3(4, 0, 0), 8, ["VITREOUS"], {"hp": 100000})
	_start(c, [crono], [e])
	_sturdy(crono)
	_advance_until_window(c)
	check_eq(int(c.preview(crono, null, e, c.position_of(e), 0)[e]["shave"]), 0, "a sword strike does not match [VITREOUS]")
	c.fields.add(&"caustic_floor", Vector3(0, 0, 0), 1.0, 6.0, 0)
	var p: Dictionary = c.preview(crono, null, e, c.position_of(e), 0)
	check_eq(int(p[e]["shave"]), 2, "passing over a caustic floor the two strikes gain [VITREOUS] (§7.4)")
	var r: Dictionary = c.cmd_attack(crono, e, 0)
	check_eq(int(r["info"]["shave"][e]), int(p[e]["shave"]), "and the hit shaves what the plate said")
	var c2 := _coord()
	var crono2 := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e2 := _enemy(&"y", 10, Vector3(3, 0, 0), 8, ["SWORD"], {"hp": 100000})
	_start(c2, [crono2], [e2])
	_sturdy(crono2)
	_advance_until_window(c2)
	c2.fields.blank(c2.position_of(e2), 1.5, 8.0)
	check_eq(int(c2.preview(crono2, null, e2, c2.position_of(e2), 0)[e2]["shave"]), 2, "the Canvas Clash blank is terrain: tags still land")
	var lv4 := c2.fields.add(&"white_blank", c2.position_of(e2), 1.5, 6.0, 0)
	lv4["strips_tags"] = true
	var p2: Dictionary = c2.preview(crono2, null, e2, c2.position_of(e2), 0)
	check_eq(int(p2[e2]["shave"]), 0, "a NULL Lv4 white blank erases every tag: no shave (§7.4)")
	var r2: Dictionary = c2.cmd_attack(crono2, e2, 0)
	check_eq(int(r2["info"]["shave"][e2]), 0, "the hit agrees")


func test_mercury_pool_spore_mat_golden_patch_and_free_cast() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 12, Vector3(-3, 0, 0))
	var sera := _party_member(&"sera", 12, Vector3(-3, 0, 3))
	var e := _enemy(&"x", 12, Vector3(3, 0, 0), 8, ["ICE"], {"hp": 100000})
	var ferro := {"id": "ferro_probe", "name": "Ferro Probe", "tier": "single", "actors": ["crono"], "tags": ["FERRO"], "shape": "SINGLE", "hits": 1, "power": 1.0, "uses": "PHYSICAL", "costs": {}}
	_start(c, [crono, sera], [e], {"techs": _with([], [ferro])})
	_sturdy(crono)
	_sturdy(sera)
	_advance_until_actor(c, &"crono")
	var plain: int = int(c.cmd_tech(crono, &"ferro_probe", e, c.position_of(e), 0)["info"]["damage"][e])
	var pool := c.fields.add(&"mercury_pool", c.position_of(e), 1.5, 6.0, 0)
	_advance_until_actor(c, &"crono")
	var pooled: int = int(c.cmd_tech(crono, &"ferro_probe", e, c.position_of(e), 0)["info"]["damage"][e])
	check_near(float(pooled), float(plain) * (1.0 + FieldEffects.MERCURY_POOL_BONUS), 1.0, "the next FERRO hit in a mercury pool +20% (§11.5)")
	check(not c.fields.fields.has(pool), "and the pool is spent")
	# Floor fields never touch Sera, for good or ill (§10.2, §12.1).
	var cs := CombatantStats.of(crono)
	var ss := CombatantStats.of(sera)
	cs.hp = 50000
	ss.hp = 50000
	c.fields.add(&"spore_mat", c.position_of(crono), 1.0, -1.0, 0)
	c.fields.add(&"spore_mat", c.position_of(sera), 1.0, -1.0, 0)
	FieldEffects.tick(c, 2.0)
	check(cs.hp > 50000, "a spore mat heals an ally inside")
	check_eq(ss.hp, 50000, "but not Sera")
	cs.max_mp = 20  # Crono pays with his ceiling; give him a pool to read the patch by
	cs.mp = 0
	ss.mp = 0
	c.fields.add(&"golden_patch", c.position_of(crono), 1.0, -1.0, 0)
	c.fields.add(&"golden_patch", c.position_of(sera), 1.0, -1.0, 0)
	FieldEffects.tick(c, 5.0)
	check_eq(cs.mp, 2, "a golden patch gives 2 MP per 5 s")
	check_eq(ss.mp, 0, "never to Sera")
	# Crono's first cast from inside a puddle or patch costs no Battle Strain, once per field.
	var td := TimeDebtComponent.of(crono)
	_advance_until_actor(c, &"crono")
	var strain0: float = td.battle_strain
	c.cmd_tech(crono, &"time_slice", e, c.position_of(e), 0)
	check_near(td.battle_strain, strain0, 0.00001, "the first cast from the patch is free (§9.6)")
	_advance_until_actor(c, &"crono")
	c.cmd_tech(crono, &"time_slice", e, c.position_of(e), 0)
	check(td.battle_strain > strain0, "the second pays")


func test_divinity_field_owner_cap_and_thaw() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 20, Vector3(-3, 0, 0))
	var krona := _party_member(&"krona", 20, Vector3(-3, 0, 2))
	var e := _enemy(&"x", 20, Vector3(3, 0, 0), 4, ["SWORD"], {"hp": 100000})
	var e2 := _enemy(&"y", 20, Vector3(3, 0, 3), 4, ["SWORD"], {"hp": 100000})
	_start(c, [crono, krona], [e, e2])
	var theirs := c.fields.add(&"divinity_field", c.arena_center, 40.0, -1.0, 1)
	for i in 6:
		FieldEffects.tick(c, CombatConstants.DIVINITY_PERIOD_S)
	var cap: int = roundi(CombatConstants.DIVINITY_CAP / FieldEffects.DIVINITY_PLATE_HP)
	check_eq(ShieldComponent.of(e).temp_plates, cap, "the owners' plates stop at 20% of max HP as temporary shield (4 plates)")
	check_eq(CombatantStats.of(crono).temp_shield, 0, "the enemies' field gives the party nothing")
	ShieldComponent.of(e).force_break(crono)
	check(not StatusComponent.of(e).has(&"silence"), "an owner that Breaks in its own field is not silenced")
	c.fields.fields.erase(theirs)
	c.fields.add(&"divinity_field", c.arena_center, 40.0, -1.0, 0)
	ShieldComponent.of(e2).force_break(crono)
	check(StatusComponent.of(e2).has(&"silence"), "a foe that Breaks in the party's field is silenced (§12.5)")
	var ks := CombatantStats.of(krona)
	FieldEffects.tick(c, CombatConstants.DIVINITY_PERIOD_S)
	check_eq(ks.temp_shield, roundi(float(ks.max_hp()) * FieldEffects.DIVINITY_PLATE_HP), "an ally's plate is 5% of max HP")
	for i in 8:
		FieldEffects.tick(c, CombatConstants.DIVINITY_PERIOD_S)
	check_eq(ks.temp_shield, roundi(float(ks.max_hp()) * CombatConstants.DIVINITY_CAP), "capped at 20% of max HP")
	RuinRules.add(krona, 1)
	check_eq(RuinRules.stacks(krona), 1, "Krona carries a Ruin stack")
	for i in 14:
		FieldEffects.tick(c, CombatConstants.DIVINITY_THAW_PERIOD_S)
	check_eq(RuinRules.stacks(krona), 1, "1% per 8 s: 14 ticks are not a whole stack")
	FieldEffects.tick(c, CombatConstants.DIVINITY_THAW_PERIOD_S)
	check_eq(RuinRules.stacks(krona), 0, "the 15th thaws it (15% per stack)")


# ---------------------------------------------------------------- DATA-18: Lv3 fields

func test_lv3_fields_and_lv4_residuals() -> void:
	var slash: TechDef = Data.techs[&"astral_slash"]
	check_eq(slash.lv3_field, &"watercolour_puddle", "Astral Slash's own row: Lv3 leaves a puddle (§11.2)")
	check_eq(ResidualFields.kind_for(slash, 2), &"", "nothing at Lv2")
	check_eq(ResidualFields.kind_for(slash, 3), &"watercolour_puddle", "the puddle at Lv3")
	check_eq(ResidualFields.kind_for(slash, 4), &"watercolour_puddle", "and at Lv4")
	check_eq(ResidualFields.kind_for(Data.techs[&"ferro_graviton"], 3), &"mercury_pool", "Ferro Graviton: a mercury pool")
	check_eq(ResidualFields.kind_for(Data.techs[&"prism_refraction"], 3), &"caustic_floor", "Prism Refraction: a caustic floor")
	var slice: TechDef = Data.techs[&"time_slice"]
	check_eq(ResidualFields.kind_for(slice, 3), &"", "a technique without its own Lv3 field leaves none at Lv3")
	check_eq(ResidualFields.kind_for(slice, 4), &"watercolour_puddle", "at Lv4 its element's default (§7.4)")
	check_eq(ResidualFields.kind_for(null, 4), &"", "an Attack never leaves one")
	var unknown: Array = []
	for id in Data.techs.keys():
		var t: TechDef = Data.techs[id]
		for f in [t.lv3_field, t.lv4_field, t.recharge_field]:
			if f != &"" and not BattleFields.KINDS.has(f):
				unknown.append("%s:%s" % [id, f])
	check_eq(unknown, [], "every field a technique names is a known kind")
	var bad := TechDef.from_dict({"id": "bad", "tier": "single", "actors": ["crono"], "tags": ["ASTRAL"], "lv4_field": "banana_field", "steps": 0})
	var errs: String = " ".join(bad.validation_errors())
	check(errs.contains("unknown field kind banana_field"), "an unknown field kind is a validation error")
	check(errs.contains("steps must be >= 1"), "and so is a stepless step count")
	var c := _coord()
	var crono := _party_member(&"crono", 12, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 12, Vector3(1, 0, 0), 8, ["ICE"], {"hp": 100000})
	_start(c, [crono], [e], {"techs": _with(["astral_slash"])})
	_sturdy(crono)
	_advance_until_window(c)
	c.bank.bp = 3
	c.cmd_tech(crono, &"astral_slash", e, c.position_of(e), 3)
	var kinds: Array = c.fields.fields.map(func(f: Dictionary) -> StringName: return f["kind"])
	check(kinds.has(&"watercolour_puddle"), "a Boost Lv3 Astral Slash leaves its puddle")


# ---------------------------------------------------------------- BATTLE-3: a Break ends the telegraph

func test_break_during_a_wind_up_ends_its_telegraph() -> void:
	var c := _coord(3)
	var crono := _party_member(&"crono", 5, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 5, Vector3(3, 0, 0), 2, ["SWORD"], {"hp": 5000})
	var def := EnemyDef.from_dict({"key": "x", "level": 5, "actions": [{"id": "slam", "tags": ["BLUNT"], "shape": "CIRCLE", "radius": 2.0, "power": 1.5, "wind_up_s": 4.0, "target": "weakest"}]})
	_start(c, [crono], [e], {"advantage": "ambush", "enemy_defs": {&"x": def}})
	_sturdy(crono)
	var ended: Array = []
	c.telegraph_ended.connect(func(en: Node) -> void: ended.append(en))
	var t: float = 0.0
	while not c.wind_ups.has(e) and t < 10.0:
		c.advance(1.0 / 60.0)
		t += 1.0 / 60.0
		if c.state == BattleCoordinator.State.COMMAND_WAIT:
			c.cmd_guard(c.active_actor)
	check(c.wind_ups.has(e), "the enemy winds up")
	ShieldComponent.of(e).force_break(crono)
	check(not c.wind_ups.has(e), "a Break cancels the wind-up (§3.5)")
	check_eq(ended, [e], "and ends its telegraph, so the decal is freed")


# ---------------------------------------------------------------- COMBAT-14: preview parity on a puddle

func test_preview_counts_the_watercolour_puddle() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 8, Vector3(-3, 0, 0))
	var e := _enemy(&"x", 8, Vector3(3, 0, 0), 6, ["ASTRAL"], {"hp": 100000})
	_start(c, [crono], [e])
	_sturdy(crono)
	_advance_until_window(c)
	c.fields.add(&"watercolour_puddle", c.position_of(e), 1.5, 6.0, 0)
	var slice: TechDef = c.tech_library[&"time_slice"]
	var p: Dictionary = c.preview(crono, slice, e, c.position_of(e), 0)
	check_eq(int(p[e]["shave"]), 2, "1 ASTRAL match + 1 for the puddle (§7.4)")
	var r: Dictionary = c.cmd_tech(crono, &"time_slice", e, c.position_of(e), 0)
	check_eq(int(r["info"]["shave"][e]), int(p[e]["shave"]), "the hit shaves what the plate said (§18.7 #23)")


# ---------------------------------------------------------------- the preview's damage is the hit's (§4.5, #23)

## A fresh battle with Crono's window open on one body that is weak to nothing (so no plate falls mid-action);
## `height` lifts him onto a ledge.
func _aim_at(height: float = 0.0) -> Array:
	var c := _coord()
	var crono := _party_member(&"crono", 30, Vector3(-1.0, height, 0))
	var e := _enemy(&"x", 30, Vector3(1.0, 0, 0), 4, ["ICE"], {"hp": 900000})
	_start(c, [crono], [e])
	_sturdy(crono)
	_advance_until_actor(c, &"crono")
	return [c, crono, e]


func test_preview_damage_reads_the_targets_statuses_the_crack_and_the_ledge() -> void:
	var plain: Array = _aim_at()
	var pc: BattleCoordinator = plain[0]
	var base: int = int(pc.preview(plain[1], null, plain[2], Vector3.ZERO, 0)[plain[2]]["damage"])
	check_eq(int(pc.cmd_attack(plain[1], plain[2])["info"]["damage"][plain[2]]), base, "a plain Attack deals what the aim line says")
	var cases: Array = [
		{"label": "Fragile", "id": &"fragile", "x": 1.5},
		{"label": "Marked", "id": &"marked", "x": 1.25},
		{"label": "Prism Guard", "id": &"prism_guard", "x": 0.6},
		{"label": "Corroded DEF", "id": &"corroded", "data": {"def": true}},
		{"label": "a 1-stack crack on a 2-hit Attack", "id": &"exposed", "stacks": 1},
		{"label": "a 3-stack crack", "id": &"exposed", "stacks": 3},
		{"label": "the ledge", "height": 1.5, "x": 1.0 + CombatConstants.LEDGE_BONUS},
	]
	for k in cases:
		var b: Array = _aim_at(float(k.get("height", 0.0)))
		var c: BattleCoordinator = b[0]
		var e: Node = b[2]
		var sc := StatusComponent.of(e)
		if k.has("id"):
			sc.add(k["id"], -1.0, -1, int(k.get("stacks", 1)), k.get("data", {}))
		var stacks_before: int = sc.stacks(&"exposed")
		var rng_before: int = c.rng.state
		var said: int = int(c.preview(b[1], null, e, Vector3.ZERO, 0)[e]["damage"])
		check(c.rng.state == rng_before and sc.stacks(&"exposed") == stacks_before, "%s: the preview draws nothing and spends nothing" % k["label"])
		check(said != base, "%s: the preview reads it (%d against %d plain)" % [k["label"], said, base])
		if k.has("x"):
			check_near(float(said) / float(base), float(k["x"]), 0.01, "%s: x%.2f" % [k["label"], float(k["x"])])
		check_eq(int(c.cmd_attack(b[1], e)["info"]["damage"][e]), said, "%s: the Attack deals what the aim line said" % k["label"])
	var so: Array = _aim_at()
	ShieldComponent.of(so[2]).shield_only = true
	check_eq(int((so[0] as BattleCoordinator).preview(so[1], null, so[2], Vector3.ZERO, 0)[so[2]]["damage"]), 0, "a shield-only body: the aim line promises no HP damage before its Break")
	check_eq(int((so[0] as BattleCoordinator).cmd_attack(so[1], so[2])["info"]["damage"][so[2]]), 0, "and the Attack deals none")


func test_preview_damage_reads_a_duals_synergy_best_caster_and_guaranteed_crit() -> void:
	var pair := {"id": "pair_cut", "name": "Pair Cut", "tier": "dual", "actors": ["crono", "krona"], "tags": ["SWORD"], "shape": "SINGLE", "hits": 2, "power": 1.0, "uses": "BEST", "costs": {}}
	var c := _coord()
	var crono := _party_member(&"crono", 30, Vector3(-1.0, 0, 0))
	var krona := _party_member(&"krona", 60, Vector3(-1.0, 0, 1.0))
	var xyloph := _party_member(&"xyloph", 60, Vector3(-1.0, 0, -1.0))
	var e := _enemy(&"x", 30, Vector3(1.0, 0, 0), 4, ["ICE"], {"hp": 900000})
	_start(c, [crono, krona, xyloph], [e], {"techs": _with(["triangulation"], [pair]), "max_bp": 9})
	for u in [crono, krona, xyloph]:
		_sturdy(u)
		CombatantStats.of(u).mp = 999
	for id in [&"pair_cut", &"triangulation"]:
		var partner: Node = krona if id == &"pair_cut" else xyloph
		c.open_window(partner, false)  # the partner waits in the Ready Pool
		c.open_window(crono, false)
		var tech: TechDef = c.tech_library[id]
		var solo: int = PartyHit.estimate(c, PartyHit.action_keys(c, tech, 0, [crono]), crono, CombatantStats.of(crono), e, Array(tech.tags), tech.hit_count, 0)
		var said: int = int(c.preview(crono, tech, e, c.position_of(e), 0, [partner])[e]["damage"])
		check(said > solo, "%s: the preview reads the partner (%d against Crono alone %d)" % [id, said, solo])
		var r: Dictionary = c.cmd_tech(crono, id, e, c.position_of(e), 0, [partner])
		check(bool(r.get("ok", false)), "%s casts: %s" % [id, str(r.get("error", ""))])
		check_eq(int(r["info"]["damage"].get(e, -1)), said, "%s: the Dual deals what the aim line said" % id)
	var tri: TechDef = c.tech_library[&"triangulation"]
	var keys: Dictionary = PartyHit.action_keys(c, tri, 0, [crono, xyloph])
	check(bool(keys["guaranteed_crit"]), "the preview's Triangulation carries its guaranteed crit")
	check_near(float(PartyHit.action_keys(c, c.tech_library[&"pair_cut"], 0, [crono, krona])["synergy"]), c.tech_library[&"pair_cut"].synergy_base() * CombatConstants.SYNERGY_CRONO_KRONA, 0.0001, "and Crono + Krona's pair synergy")


# ---------------------------------------------------------------- COMBAT-19: the Dual's stat

func test_dual_uses_the_best_stat_for_its_uses() -> void:
	var a := CombatantStats.new()
	var b := CombatantStats.new()
	_track(a)
	_track(b)
	a.p_atk = 100.0
	a.e_atk = 10.0
	b.p_atk = 50.0
	b.e_atk = 80.0
	var ua := Node.new()
	var ub := Node.new()
	_track(ua)
	_track(ub)
	a.name = "CombatantStats"
	b.name = "CombatantStats"
	ua.add_child(a)
	ub.add_child(b)
	check(PartyHit.best_caster([ua, ub], TechDef.Uses.ELEMENTAL, a) == b, "an ELEMENTAL Dual reads the higher E.Atk (§8.7)")
	check(PartyHit.best_caster([ua, ub], TechDef.Uses.PHYSICAL, a) == a, "a PHYSICAL one the higher P.Atk")
	check(PartyHit.best_caster([ua, ub], TechDef.Uses.ASTRAL, a) == b, "an ASTRAL one the higher average")
	check(PartyHit.best_caster([ua, ub], TechDef.Uses.BEST, a) == a, "BEST the highest stat of all")


# ---------------------------------------------------------------- COMBAT-23: cap upgrades and live hooks

func test_cap_upgrades_follow_the_flags() -> void:
	var keep: Array = [Game.max_bp, Game.max_spend, Game.parry_frames, Game.hold_upgraded]
	Game.parry_frames = CombatConstants.ENS_PARRY_FRAMES_BASE
	Game.hold_upgraded = false
	var got: Array[String] = CapUpgrades.apply(Game, {&"Krona_Joined": &"set", &"Central_Eye": &"Broken"})
	check_eq(Game.parry_frames, CombatConstants.ENS_PARRY_FRAMES_TAUGHT, "Krona teaches Ens Parry: 6 frames (§15.7)")
	check(Game.hold_upgraded, "Central_Eye Broken: HOLD +0.5 s per step")
	check_eq(got.size(), 2, "two upgrades applied")
	CapUpgrades.apply(Game, {&"Goyama": &"Repainted"})
	check_eq(Game.parry_frames, CombatConstants.ENS_PARRY_FRAMES_DOJO, "the Goyama dojo: +2 more")
	CapUpgrades.apply(Game, {&"Krona_Joined": &"set"})
	check_eq(Game.parry_frames, CombatConstants.ENS_PARRY_FRAMES_DOJO, "an upgrade is never taken back")
	check(CapUpgrades.apply(Game, {&"Goyama": &"Incinerated"}).is_empty(), "a state that earns nothing changes nothing")
	var fake := {"states": [{"id": "Restored", "upgrade": "max_bp"}]}
	CapUpgrades.apply(Game, {&"Memory_Shards": &"Restored"}, func(_id: StringName) -> Dictionary: return fake)
	check_eq(Game.max_bp, CombatConstants.MAX_BP_UPGRADED, "a flag that names max_bp raises the Boost cap to 6")
	Game.parry_frames = CombatConstants.ENS_PARRY_FRAMES_BASE
	Game.hold_upgraded = false
	Flags.flags[&"Central_Eye"] = &"Broken"
	Flags.flag_set.emit(&"Central_Eye", &"Broken")
	check(Game.hold_upgraded, "Game applies the upgrades whenever a flag is set")
	Flags.flags.erase(&"Central_Eye")
	Game.max_bp = keep[0]
	Game.max_spend = keep[1]
	Game.parry_frames = keep[2]
	Game.hold_upgraded = keep[3]


func test_dead_hooks_now_fire() -> void:
	var c := _coord()
	var crono := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var sera := _party_member(&"sera", 10, Vector3(-3, 0, 3))
	var e := _enemy(&"x", 10, Vector3(3, 0, 0), 8, ["ICE"], {"hp": 100000})
	var sure := {"id": "sure_cut", "name": "Sure Cut", "tier": "single", "actors": ["crono"], "tags": ["SWORD"], "shape": "SINGLE", "hits": 1, "power": 1.0, "uses": "PHYSICAL", "guaranteed_crit": true, "costs": {}}
	_start(c, [crono, sera], [e], {"techs": _with([], [sure])})
	_sturdy(crono)
	TechCosts.spend_solidity(c, sera, 10.0)
	check_near(float(sera.get_meta("last_solidity_cost", 0.0)), 10.0, 0.001, "spend_solidity records the last cost for Time Debt Seal")
	check(Data.techs[&"triangulation"].guaranteed_crit, "Triangulation's guaranteed crit is data (§6.2)")
	_advance_until_actor(c, &"crono")
	var crits: Array = []
	c.strike_resolved.connect(func(_a: Node, _t: Node, info: Dictionary) -> void: crits.append(bool(info.get("crit", false))))
	c.cmd_tech(crono, &"sure_cut", e, c.position_of(e), 0)
	check_eq(crits, [true], "a guaranteed-crit technique crits an unbroken target")
	# Height (§8.8): +10% from a ledge downward, −10% upward.
	(crono as Node3D).global_position = Vector3(-3, 2, 0)
	check_near(PartyHit.ledge(c, crono, e), CombatConstants.LEDGE_BONUS, 0.0001, "attacking from a ledge downward")
	check_near(PartyHit.ledge(c, e, crono), -CombatConstants.LEDGE_BONUS, 0.0001, "and upward")
	(crono as Node3D).global_position = Vector3(-3, 0.3, 0)
	check_near(PartyHit.ledge(c, crono, e), 0.0, 0.0001, "a small step is flat ground")
	# Krona's gourd: once per enemy action against her (DECISIONS).
	var c2 := _coord()
	var krona := _party_member(&"krona", 10, Vector3(-3, 0, 0))
	var e2 := _enemy(&"y", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 100000})
	_start(c2, [krona], [e2])
	var ks := CombatantStats.of(krona)
	ks.hp = 1
	c2.enemy_action_serial = 1
	EnemyTurn.after_damage(c2, krona)
	var after_one: int = ks.hp
	check(after_one > 1, "below 25% she sips")
	ks.hp = 1
	EnemyTurn.after_damage(c2, krona)
	check_eq(ks.hp, 1, "a second hit of the same enemy action: no second sip")
	c2.enemy_action_serial = 2
	EnemyTurn.after_damage(c2, krona)
	check(ks.hp > 1, "the next enemy action: she may sip again")
	# Grief: under 50% MP no Boost over 1 (float half, an odd max MP).
	var c3 := _coord()
	var crono3 := _party_member(&"crono", 10, Vector3(-3, 0, 0))
	var e3 := _enemy(&"z", 10, Vector3(3, 0, 0), 4, ["ICE"], {"hp": 100000})
	_start(c3, [crono3], [e3])
	_advance_until_window(c3)
	var st3 := CombatantStats.of(crono3)
	st3.max_mp = 31
	st3.mp = 15
	StatusComponent.of(crono3).add(&"grief", -1.0, -1)
	c3.bank.bp = 3
	var r: Dictionary = c3.cmd_tech(crono3, &"time_slice", e3, c3.position_of(e3), 2)
	check(not bool(r.get("ok", true)) and String(r.get("error", "")).contains("Grief"), "15 of 31 MP is under half: Grief refuses Boost 2")


# ---------------------------------------------------------------- DATA-19: the signature

func test_signature_keeps_casters_and_effect() -> void:
	var base := {"id": "a", "tier": "single", "actors": ["xyloph"], "tags": ["MYCELIA", "LIFE"], "shape": "CIRCLE", "radius": 4.0}
	var same := base.duplicate()
	same["id"] = "b"
	var other := base.duplicate()
	other["id"] = "c"
	other["effect"] = "photosynthetic_burst"
	check_eq(TechDef.from_dict(base).signature(), TechDef.from_dict(same).signature(), "same casters, tags, shape and size collide")
	check(TechDef.from_dict(base).signature() != TechDef.from_dict(other).signature(), "a different effect tells them apart (DECISIONS)")
	var collisions: int = 0
	for e in Data.errors:
		if e.contains("share tags"):
			collisions += 1
	check_eq(collisions, 0, "no two shipped techs collide")
