## Special technique behaviours that bend the rules (Combat Laws Bible §11): Rewind, HOLD,
## Borrowed Future, Fall Break, taunts, the gourd, field makers. Standard damage techs never come here.
## HANDLED are the bespoke handlers below; every other effect id is a row of data/effects/effects.json that
## EffectSteps runs, or is listed there as flavour or pending (EffectTable.validation_errors, lint_data.py).
## Enemy action effects are EnemyEffects.
class_name TechEffects
extends RefCounted

const HANDLED: Array[StringName] = [
	&"rewind", &"hold", &"borrowed_future", &"fall_break", &"time_debt_seal", &"bekkler_guilt",
	&"astral_field", &"shoguns_command", &"oil_drinker", &"ruin_purge", &"eclipse_x_strike",
	&"tachyon_needle", &"ward", &"porcelain_promise", &"hover_rewind_hp", &"hover_fast_forward",
	&"mercury_pulse", &"wire_loom_mend", &"sound_ring", &"reinforced_guard", &"fake_family_photo",
	&"null_strip", &"divinity_field", &"core_lattice", &"prism_guard", &"sleight_of_arm",
	&"swap_face", &"honest_laugh", &"balloon_escape", &"tune", &"lotus_reverse", &"miura_fold",
	&"time_debt_paid", &"crimson_seppuku", &"cobalt_nodachi", &"overclocked_short_circuit",
	&"mycelia_tether", &"photosynthetic_burst", &"guile_feint", &"omega_annihilation",
]
## The handlers above whose cast strikes the enemies its shape caught (each resolves through _merge_damage); the
## rest strike nothing, so their plate preview is empty (CastReach.strikes; suite_acceptance pins the two lists).
const STRIKING: Array[StringName] = [
	&"astral_field", &"cobalt_nodachi", &"crimson_seppuku", &"eclipse_x_strike", &"guile_feint", &"mercury_pulse",
	&"mycelia_tether", &"omega_annihilation", &"overclocked_short_circuit", &"photosynthetic_burst",
	&"porcelain_promise", &"ruin_purge", &"sleight_of_arm", &"sound_ring", &"swap_face", &"tachyon_needle",
]

const DEFAULT_LV2 := {
	&"ASTRAL": &"displaced", &"TACHYON": &"probability_lock", &"RUIN": &"corroded", &"FERRO": &"magnetized",
	&"MYCELIA": &"spore_tag", &"VITREOUS": &"refracted", &"GUILE": &"guilty", &"HZ": &"jammed", &"NULL": &"stripped",
}


static func handles(effect: StringName) -> bool:
	return HANDLED.has(effect) or EffectTable.has_row(effect)


static func default_lv2(element: StringName) -> StringName:
	return DEFAULT_LV2.get(element, &"")


## The extra shave a technique gets against a status its target carries (status -> bonus). The
## resolution reads it when the action is built and the preview reads it while aiming, so the plate
## shows the same shave the hit then does (§18.7 #23).
static func bonus_if_status(tech: TechDef) -> Dictionary:
	if tech != null and tech.effect == &"tachyon_needle":
		return {&"magnetized": 1}
	return {}


static func apply(c: BattleCoordinator, tech: TechDef, action: Dictionary) -> Dictionary:
	if not HANDLED.has(tech.effect):
		return EffectSteps.apply(c, tech, action)  # a row of the effect table
	var actor: Node = action["attacker"]
	var target: Node = action.get("primary", null)
	var boost: int = int(action.get("boost", 0))
	var info := {"kind": "effect", "effect": tech.effect, "attacker": actor, "casters": action.get("casters", [actor]), "tech": tech, "boost": boost, "targets": [], "damage": {}, "shave": {}, "breaks": []}
	match tech.effect:
		&"rewind":
			if target == null:
				target = actor
			actor.set_meta("used_tachyon_this_turn", true)
			var ok: bool = c.rewind_unit(target)
			c.crono_pays_for_slip()
			info["targets"] = [target]
			info["rewound"] = ok
			c.truth_moment.emit(&"rewind")
		&"hold":
			if target != null and c.is_broken(target):
				actor.set_meta("used_tachyon_this_turn", true)
				var steps: int = maxi(1, int(action.get("steps", 1)))
				var sol := SolidityComponent.of(actor)
				var per: float = sol.hold_step_seconds if sol != null else CombatConstants.SERA_HOLD_BREAK_EXTENSION_S
				for i in range(1, steps):
					c.spend_solidity(actor, CombatConstants.SERA_HOLD_STEP)
				ShieldComponent.of(target).extend_lock(per * steps)
				info["targets"] = [target]
				info["extended"] = per * steps
		&"borrowed_future":
			actor.set_meta("used_tachyon_this_turn", true)
			info["duplicate"] = c.borrowed_future(actor)
			c.truth_moment.emit(&"borrowed_future")
		&"fall_break":
			if target == null:
				target = actor
			target.set_meta("fall_break", true)
			info["targets"] = [target]
		&"time_debt_seal":
			var sera: Node = c.unit_by_id(&"sera")
			if sera != null:
				var sol2 := SolidityComponent.of(sera)
				if sol2 != null:
					if sol2.is_phased() and not actor.get_meta("seal_used", false):
						sol2.phased_turns_left = 0
						sol2.phased_in.emit()
						c.sera_phase_changed.emit(false)
						actor.set_meta("seal_used", true)
					else:
						sol2.restore(float(sera.get_meta("last_solidity_cost", CombatConstants.SERA_REWIND_COST)))
				info["targets"] = [sera]
		&"bekkler_guilt":
			# until his next turn, hits on allies in the ring land on him at 75%, +1 BP each (max 2)
			c.add_taunt(actor, 1, 0.0, {"ring": tech.radius * tech.shape_scale(boost), "taken": CombatConstants.GUILT_TAKEN, "bp": CombatConstants.GUILT_BP_MAX})
			info["targets"] = [actor]
		&"astral_field":
			var f: Dictionary = c.fields.add(&"astral_field", c.position_of(actor), 4.0 * float(action["shape"].get("scale", 1.0)), 10.0, 0)
			c.field_added.emit(f)
			c.fields.convert(&"vhs_fog", &"cleared", c.position_of(actor), 4.0, 10.0)
			for u in c.party:
				var sc := StatusComponent.of(u)
				if sc != null and c.position_of(u).distance_to(c.position_of(actor)) <= 4.0:
					sc.remove(&"grief")
					sc.remove(&"blind")
					sc.add(&"astral_field", 10.0)
			info["targets"] = c.party.duplicate()
			info = _merge_damage(c, info, action)
		&"shoguns_command":
			# 60% of the attacks for 2 of her turns; standing at the end, every ally's next hit ignores DEF
			c.add_taunt(actor, 2, CombatConstants.SHOGUN_TAUNT, {"payoff": &"ruin_infused"})
			info["targets"] = [actor]
		&"oil_drinker":
			for u in c.party:
				var st := CombatantStats.of(u)
				if st.is_alive():
					var healed: int = st.heal(roundi(float(st.max_hp()) * 0.10))
					c.heal_resolved.emit(actor, u, healed)
			actor.set_meta("corruption", float(actor.get_meta("corruption", 0.0)) + 5.0)
			info["targets"] = c.party.duplicate()
		&"ruin_purge":
			info = _merge_damage(c, info, action)
			var radius: float = tech.radius * tech.shape_scale(boost)
			var f2: Dictionary = c.fields.add(&"ash_field", action["aim"], radius, -1.0, 0)
			c.field_added.emit(f2)
			var purge_n: int = 2 if boost >= 3 else 1
			for t in info["targets"]:
				var sc2 := StatusComponent.of(t)
				if sc2 != null:
					for i in purge_n:
						_purge_one_buff(sc2)
		&"eclipse_x_strike":
			info = _merge_damage(c, info, action)
			for t in info["targets"]:
				if c.position_of(t).distance_to(action["aim"]) <= tech.radius:
					var sh := ShieldComponent.of(t)
					var sc3 := StatusComponent.of(t)
					if sc3 != null:
						_purge_one_buff(sc3)
					if sh != null and not sh.is_broken and sh.current_shield > 0:
						sh.apply_strike([sh.weaknesses[0] if not sh.weaknesses.is_empty() else &"SWORD"], 0, actor, &"")
		&"tachyon_needle":
			actor.set_meta("used_tachyon_this_turn", true)
			action["gauge_push_per_hit"] = 13.0 if boost >= 3 else 8.0
			action["bonus_if_status"] = bonus_if_status(tech)
			info = _merge_damage(c, info, action)
		&"ward":
			if target == null:
				target = actor
			var tst := CombatantStats.of(target)
			var ast := CombatantStats.of(actor)
			var amt: int = DamagePipeline.compute_heal(ast.e_atk, tech.heal, boost)
			var healed2: int = tst.heal(amt)
			c.heal_resolved.emit(actor, target, healed2)
			var sc4 := StatusComponent.of(target)
			if sc4 != null:
				sc4.add(&"ward", -1.0, -1)
			info["targets"] = [target]
		&"porcelain_promise":
			info = _merge_damage(c, info, action)
			var crono: Node = c.unit_by_id(&"crono")
			if crono != null:
				crono.set_meta("next_astral_free", true)
		&"hover_rewind_hp":
			if target != null:
				c.rewind_unit(target, true)
				actor.set_meta("used_tachyon_this_turn", true)
				info["targets"] = [target]
		&"hover_fast_forward":
			if target != null:
				c.set_gauge(target, c.get_gauge(target) + 25.0)
				actor.set_meta("used_tachyon_this_turn", true)
				info["targets"] = [target]
		&"mercury_pulse":
			# the cast's own circle (CastReach.radius: +1.0 as Centaur), cloaked bodies included
			var reach: Array = []
			for en in c.living_enemies():
				reach.append({"node": en, "pos": c.position_of(en), "radius": CombatantStats.of(en).body_radius})
			for h in TacticalPositioner.targets_in_shape(action["shape"], c.position_of(actor), action["aim"], reach):
				var e: Node = h["node"]
				var sh2 := ShieldComponent.of(e)
				if sh2 != null:
					sh2.reveal_all()
				var sc5 := StatusComponent.of(e)
				if sc5 != null:
					sc5.remove(&"cloaked")  # the Lucca Lens lights a cloaked body up (§13.5 Porcelain Raptor)
				StatusRules.apply(c, e, &"mercury_slow", 4.0)  # a boss's halved (DECISIONS "Boss status rules")
				StatusRules.apply(c, e, &"magnetized", -1.0, 2)
			info = _merge_damage(c, info, action)
		&"wire_loom_mend":
			if target == null:
				target = actor
			var tst2 := CombatantStats.of(target)
			var ast2 := CombatantStats.of(actor)
			var td := TimeDebtComponent.of(target)
			if td != null:
				td.restore_battle_strain(0.10)
				if not target.get_meta("loom_mended", false):
					td.repair_integrity(0.6)
					target.set_meta("loom_mended", true)
			var healed3: int = tst2.heal(DamagePipeline.compute_heal(ast2.e_atk, tech.heal, boost))
			c.heal_resolved.emit(actor, target, healed3)
			var sc6 := StatusComponent.of(target)
			if sc6 != null:
				for id in [&"scanlines", &"ink_bleed", &"blind"]:
					sc6.remove(id)
			info["targets"] = [target]
		&"sound_ring":
			info = _merge_damage(c, info, action)
			var f3: Dictionary = c.fields.add(&"sound_ring", c.position_of(actor), tech.radius * tech.shape_scale(boost), 4.0, 0)
			c.field_added.emit(f3)
			for e in c.living_enemies():
				var sh3 := ShieldComponent.of(e)
				if sh3 != null and sh3.break_condition == &"ferro_in_party":
					sh3.break_allowed = true
					sh3.try_release_pending_break(actor)
		&"reinforced_guard":
			var crono2: Node = c.unit_by_id(&"crono")
			if crono2 != null:
				var td2 := TimeDebtComponent.of(crono2)
				if td2 != null:
					td2.reinforced_jumps = 3
					td2.reinforced_factor = CombatConstants.REINFORCED_REDUCTION
			info["targets"] = [actor]
		&"fake_family_photo":
			var crono3: Node = c.unit_by_id(&"crono")
			if crono3 != null:
				var st3 := CombatantStats.of(crono3)
				var td3 := TimeDebtComponent.of(crono3)
				if td3 != null:
					td3.restore_battle_strain(0.20)
				st3.heal(maxi(0, roundi(float(st3.max_hp()) * 0.6) - st3.hp))
				c.heal_resolved.emit(actor, crono3, 0)
				info["targets"] = [crono3]
		&"null_strip":
			var radius3: float = tech.radius * tech.shape_scale(boost)
			var center: Vector3 = action["aim"]
			for u in c.living_enemies() + c.party:
				if c.position_of(u).distance_to(center) <= radius3:
					var sc7 := StatusComponent.of(u)
					var sh4 := ShieldComponent.of(u)
					var st4 := CombatantStats.of(u)
					if st4 != null and st4.true_null:
						continue
					if sc7 != null:
						# 2 turns (§11.10, §9.3): the status's undo gives the plates back (StatusRules).
						sc7.cleanse()
						var undo: Callable = Callable()
						if sh4 != null and sh4.weaknesses.is_empty():
							StatusRules.create_weakness(sh4, sc7, _fake_weakness(c, u), 2)
						elif sh4 != null:
							undo = StatusRules.strip_resists(sh4)
						sc7.add(&"nulled", -1.0, 2, 1, {"undo": undo} if undo.is_valid() else {})
					info["targets"].append(u)
			c.fields.blank(center, radius3, 8.0)
		&"divinity_field":
			var f4: Dictionary = c.fields.add(&"divinity_field", c.arena_center, 40.0, -1.0, 0)
			c.field_added.emit(f4)
			info["targets"] = c.party.duplicate()
		&"core_lattice":
			var crono4: Node = c.unit_by_id(&"crono")
			if crono4 != null:
				var sc8 := StatusComponent.of(crono4)
				if sc8 != null:
					sc8.add(&"core_lattice", -1.0, 3)
				info["targets"] = [crono4]
		&"prism_guard":
			var sc9 := StatusComponent.of(actor)
			if sc9 != null:
				sc9.add(&"prism_guard", -1.0, 1)
			info["targets"] = [actor]
		&"sleight_of_arm", &"guile_feint":
			info = _merge_damage(c, info, action)
			var stolen: int = _steal_from(c, actor, target, boost)
			info["stolen"] = stolen
		&"swap_face":
			info = _merge_damage(c, info, action)
			for t in info["targets"]:
				StatusRules.apply(c, t, &"guilty", -1.0, 2)
		&"honest_laugh":
			if target == null:
				target = actor
			c.bank.add(2)
			target.set_meta("honest_hit", true)
			info["targets"] = [target]
		&"balloon_escape":
			var sc11 := StatusComponent.of(actor)
			if sc11 != null:
				sc11.add(&"balloon", 2.0)
			actor.set_meta("theft_immune_once", true)
			info["targets"] = [actor]
		&"tune":
			actor.set_meta("tuning", String(action.get("mode", "NOISE")))
			var sc12 := StatusComponent.of(actor)
			if sc12 != null:
				sc12.remove(&"white_noise_blind")
			info["targets"] = [actor]
		&"lotus_reverse":
			if target != null:
				var tst3 := CombatantStats.of(target)
				if not tst3.is_alive():
					tst3.revive(0.3)
					c.unit_revived.emit(target)
				var sc13 := StatusComponent.of(target)
				if sc13 != null:
					sc13.cleanse()
				info["targets"] = [target]
		&"miura_fold":
			var living: Array = c.living_enemies()
			if living.size() >= 2:
				living[0].set_meta("fold_partner", living[1])
				living[1].set_meta("fold_partner", living[0])
				info["targets"] = [living[0], living[1]]
		&"time_debt_paid":
			for u in c.party:
				var st5 := CombatantStats.of(u)
				if st5.is_alive():
					st5.heal(roundi(float(st5.max_hp()) * 0.4))
				var td4 := TimeDebtComponent.of(u)
				if td4 != null:
					td4.camp_strain = 0.0
			info["targets"] = c.party.duplicate()
		&"crimson_seppuku":
			info = _merge_damage(c, info, action)
			for t in info["targets"]:
				var sc14 := StatusComponent.of(t)
				if sc14 != null:
					sc14.add(&"corroded", -1.0, 3)
				var f5: Dictionary = c.fields.add(&"ash_field", c.position_of(t), 1.5, -1.0, 0)
				c.field_added.emit(f5)
			actor.set_meta("corruption", float(actor.get_meta("corruption", 0.0)) + 10.0)
			var kst := CombatantStats.of(actor)
			kst.heal(roundi(float(kst.max_hp()) * 0.2))
		&"cobalt_nodachi":
			info = _merge_damage(c, info, action)
			for f6 in c.fields.fields.duplicate():
				if f6["kind"] == &"ash_field" and c.position_of(actor).distance_to(f6["center"]) <= tech.length:
					c.fields.fields.erase(f6)
		&"overclocked_short_circuit":
			info = _merge_damage(c, info, action, CastReach.target_filter(c, tech))  # arcs through metal only
		&"mycelia_tether":
			var nodes: Array = actor.get_meta("tether_nodes", [])
			for u in c.party:
				if nodes.size() >= 3:
					break
				if u != actor and not nodes.has(u):
					nodes.append(u)
					var sc15 := StatusComponent.of(u)
					if sc15 != null:
						sc15.add(&"tethered", -1.0, -1)
			actor.set_meta("tether_nodes", nodes)
			info = _merge_damage(c, info, action)
		&"photosynthetic_burst":
			info = _merge_damage(c, info, action)
			var refunds: int = 0
			for t in info["targets"]:
				var sc16 := StatusComponent.of(t)
				if sc16 != null and sc16.has(&"spore_tag"):
					refunds += sc16.stacks(&"spore_tag")
					sc16.remove(&"spore_tag")
			refunds += int(actor.get_meta("sunlight", 0))
			actor.set_meta("sunlight", 0)
			for u in c.party:
				var sc17 := StatusComponent.of(u)
				if sc17 != null and sc17.has(&"tethered"):
					var st6 := CombatantStats.of(u)
					st6.heal(roundi(float(st6.max_hp()) * 0.04 * refunds))
					st6.restore_mp(2 * refunds)
			var sc18 := StatusComponent.of(actor)
			if sc18 != null:
				sc18.add(&"rooted", -1.0, 1)
		&"omega_annihilation":
			info = _merge_damage(c, info, action)
			for t in info["targets"]:
				c.end_wind_up(t)
				c.set_gauge(t, 0.0)
			actor.set_meta("used_tachyon_this_turn", true)
	return info


static func _merge_damage(c: BattleCoordinator, info: Dictionary, action: Dictionary, filter: Callable = Callable()) -> Dictionary:
	if filter.is_valid():
		action["target_filter"] = filter
	var dmg: Dictionary = c._resolve_action(action)
	info["targets"] = dmg["targets"]
	info["damage"] = dmg["damage"]
	info["raw"] = dmg["raw"]
	info["shave"] = dmg["shave"]
	info["breaks"] = dmg["breaks"]
	return info


static func _purge_one_buff(sc: StatusComponent) -> void:
	for id in [&"haste", &"regen", &"ward", &"glass_ward", &"prism_guard", &"divinity", &"repainted", &"rage"]:
		if sc.has(id):
			sc.remove(id)
			return


const FAKE_POOL: Array[StringName] = [
	&"SWORD", &"ASTRAL", &"FERRO", &"RUIN", &"FIRE", &"ICE", &"VOLT", &"WIND", &"LIGHT", &"DARK",
	&"TACHYON", &"MYCELIA", &"VITREOUS", &"GUILE", &"HZ", &"BLUNT", &"PIERCING", &"GUN", &"BOW", &"WATER",
	&"INK", &"SOUND", &"SPORE", &"PRISM", &"TRICK", &"SIGNAL", &"MAGNETIC", &"ENTROPY", &"LIFE", &"REFRACT",
	&"SMOKE", &"RUBBER", &"SAURIA", &"DIVINE", &"AURA", &"NOISE", &"CARRION", &"RESONANCE", &"PROBABILITY",
	&"ASH", &"TIME_DEBT", &"BP_STEAL",
]


static func _fake_weakness(c: BattleCoordinator, _u: Node) -> StringName:
	return FAKE_POOL[c.rng.randi_range(0, FAKE_POOL.size() - 1)]


## Glenn's steal (§7.5, acceptance §18.7 #22): from the enemy's stolen-BP counter first (1 BP at Lv0-1, 2 at
## Lv2, 3 at Lv3+); only when the counter is empty, 1 BP from its "laugh". A Broken enemy whose behaviour says
## `steal_all_when_broken` (the Ash Ringmaster) gives up its whole counter. The pool's cap still applies.
## `limit`: what is left of this action's steal (EffectSteps' multi-body steal), when it is less than the level's.
static func _steal_from(c: BattleCoordinator, glenn: Node, target: Node, boost: int, limit: int = 99) -> int:
	var n: int = mini(CombatConstants.GLENN_STEAL[clampi(boost, 0, 4)], limit)
	var taken: int = 0
	var held: int = int(target.get_meta("stolen_bp", 0)) if target != null else 0
	if held > 0:
		var def: EnemyDef = c.enemy_defs.get(CombatantStats.of(target).actor_id, null)
		if def != null and bool(def.behaviour.get("steal_all_when_broken", false)) and c.is_broken(target):
			n = held
		taken = mini(held, n)
		target.set_meta("stolen_bp", held - taken)
	elif target != null and n > 0:
		taken = 1
		target.set_meta("stolen_from", true)
	if taken > 0:
		c.bank.add(taken)
	glenn.set_meta("stole_this_battle", true)
	return taken

