## Special technique behaviours that bend the rules (Combat Laws Bible §11): Rewind, HOLD,
## Borrowed Future, Fall Break, taunts, the gourd, field makers. Standard damage techs never come here.
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

const DEFAULT_LV2 := {
	&"ASTRAL": &"displaced", &"TACHYON": &"probability_lock", &"RUIN": &"corroded", &"FERRO": &"magnetized",
	&"MYCELIA": &"spore_tag", &"VITREOUS": &"refracted", &"GUILE": &"guilty", &"HZ": &"jammed", &"NULL": &"stripped",
}


static func handles(effect: StringName) -> bool:
	return HANDLED.has(effect)


static func default_lv2(element: StringName) -> StringName:
	return DEFAULT_LV2.get(element, &"")


static func apply(c: BattleCoordinator, tech: TechDef, action: Dictionary) -> Dictionary:
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
			c.add_taunt(actor, 1, 1.0)
			actor.set_meta("guilt_redirect", 2)
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
			c.add_taunt(actor, 2, 0.6)
			actor.set_meta("shogun_command_pending", true)
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
			action["bonus_if_status"] = {&"magnetized": 1}
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
			var radius2: float = tech.radius * tech.shape_scale(boost) + (1.0 if actor.get_meta("centaur", true) else 0.0)
			for e in c.living_enemies():
				if c.position_of(e).distance_to(c.position_of(actor)) <= radius2:
					var sh2 := ShieldComponent.of(e)
					if sh2 != null:
						sh2.reveal_all()
					var sc5 := StatusComponent.of(e)
					if sc5 != null:
						sc5.add(&"mercury_slow", 4.0)
						sc5.add(&"magnetized", -1.0, 2)
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
						sc7.cleanse()
						sc7.add(&"nulled", -1.0, 2)
					if sh4 != null:
						if sh4.weaknesses.is_empty():
							var fake: StringName = _fake_weakness(c, u)
							sh4.weaknesses.append(fake)
							sh4.revealed[fake] = true
							if sc7 != null:
								sc7.add(&"nulled_weakness", -1.0, 2, 1, {"tag": fake})
						else:
							sh4.resists.clear()
							sh4.absorbs.clear()
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
				var sc10 := StatusComponent.of(t)
				if sc10 != null:
					sc10.add(&"guilty", -1.0, 2)
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
			# Arcs through metal only: non-metal targets are skipped.
			info = _merge_damage(c, info, action, func(t: Node) -> bool: return c._is_metal(t))
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
				if c.wind_ups.has(t):
					c.wind_ups.erase(t)
					c.telegraph_ended.emit(t)
				c.set_gauge(t, 0.0)
			actor.set_meta("used_tachyon_this_turn", true)
	return info


static func _merge_damage(c: BattleCoordinator, info: Dictionary, action: Dictionary, filter: Callable = Callable()) -> Dictionary:
	if filter.is_valid():
		action["target_filter"] = filter
	var dmg: Dictionary = c._resolve_action(action)
	info["targets"] = dmg["targets"]
	info["damage"] = dmg["damage"]
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


static func _steal_from(c: BattleCoordinator, glenn: Node, target: Node, boost: int) -> int:
	var n: int = CombatConstants.GLENN_STEAL[clampi(boost, 0, 4)]
	var taken: int = 0
	if target != null and target.has_meta("stolen_bp"):
		var held: int = int(target.get_meta("stolen_bp", 0))
		var from_counter: int = mini(held, n)
		target.set_meta("stolen_bp", held - from_counter)
		taken += from_counter
		n -= from_counter
	if n > 0 and target != null:
		taken += 1
		target.set_meta("stolen_from", true)
	if taken > 0:
		c.bank.add(taken)
	glenn.set_meta("stole_this_battle", true)
	return taken


## Enemy actions with a named effect.
static func apply_enemy_effect(c: BattleCoordinator, enemy: Node, action: Dictionary, hit_list: Array) -> void:
	match String(action.get("effect", "")):
		"bell_slow":
			for u in c.party:
				var sc := StatusComponent.of(u)
				if sc != null:
					sc.add(&"slow", 6.0)
		"repaint":
			if not enemy.get_meta("repainted", false):
				enemy.set_meta("repainted", true)
				var sh := ShieldComponent.of(enemy)
				if sh != null and not sh.is_broken:
					sh.current_shield = mini(sh.max_total(), sh.current_shield + 1)
					sh.shield_changed.emit(sh.current_shield, sh.max_total())
		"heal_ally_plates":
			for e in c.living_enemies():
				if e != enemy:
					var sh2 := ShieldComponent.of(e)
					if sh2 != null and not sh2.is_broken:
						sh2.current_shield = mini(sh2.max_total(), sh2.current_shield + int(action.get("plates", 2)))
						sh2.shield_changed.emit(sh2.current_shield, sh2.max_total())
					break
		"oil_blight":
			c.set_oil_blight(true)
		"time_stop":
			for h in hit_list:
				var sc2 := StatusComponent.of(h["node"])
				if sc2 != null:
					sc2.add(&"time_stop", 3.0)
		"grief":
			for h in hit_list:
				var sc3 := StatusComponent.of(h["node"])
				if sc3 != null:
					sc3.add(&"grief", -1.0, -1)
		"fog":
			var f: Dictionary = c.fields.add(&"vhs_fog", action.get("aim", c.arena_center), 4.0, 20.0, 1)
			c.field_added.emit(f)
			for h in hit_list:
				var sc4 := StatusComponent.of(h["node"])
				if sc4 != null:
					sc4.add(&"blind", 10.0)
