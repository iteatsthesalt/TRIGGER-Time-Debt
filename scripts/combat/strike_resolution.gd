## A party action's resolution on the plane (Combat Laws Bible §4.6, §5.4, §6.4, §7.2, §7.4, §9.6): what its
## shape catches, each strike through the shield and the damage pipeline, the Boost Lv2 debuff, the canvas clash and
## the residual fields it leaves; and a support technique's heals. BattleCoordinator.cmd_attack / cmd_tech, the
## bespoke handlers (TechEffects._merge_damage) and Borrowed Future's duplicate run it.
class_name StrikeResolution
extends RefCounted


## Resolve a damaging party action (cmd_attack, cmd_tech, a handler's strike, a duplicate). Returns its info.
static func resolve(c: BattleCoordinator, action: Dictionary) -> Dictionary:
	var attacker: Node = action["attacker"]
	var tech: TechDef = action.get("tech", null)
	var boost: int = int(action.get("boost", 0))
	var tags: Array = action["tags"]
	var casters: Array = action.get("casters", [attacker])
	var shape: Dictionary = action["shape"]
	var aim: Vector3 = action["aim"]
	var extra: Dictionary = CastReach.extra_origins(c, casters)
	var found: Array
	if int(shape["shape"]) == TechDef.Shape.SINGLE:
		var primary: Node = action.get("primary", null)
		found = [{"node": primary, "hits": 1, "rank": 0}] if primary != null else []
	else:
		found = TacticalPositioner.targets_in_shape(shape, c.position_of(attacker), aim, CastReach.enemy_bodies(c), CastReach.blockers(c), extra)
	var info := {"kind": action["kind"], "attacker": attacker, "casters": casters, "tech": tech, "boost": boost, "targets": [], "damage": {}, "raw": {}, "shave": {}, "breaks": [], "tags": tags}
	var a_stats := CombatantStats.of(attacker)
	var best_caster: CombatantStats = PartyHit.best_caster(casters, int(action.get("uses", TechDef.Uses.BEST)), a_stats)  # §8.7
	var perfect: bool = bool(c.perfect_frame_pending.get(attacker, false))
	c.perfect_frame_pending.erase(attacker)
	var hits_per: int = int(action.get("hits", 1))
	var flicker: bool = PartyHit.flicker(attacker)
	var filter: Callable = action.get("target_filter", Callable())
	var a_sc := StatusComponent.of(attacker)
	var push_per_hit: float = float(action.get("gauge_push_per_hit", 0.0))
	var bonus_if_status: Dictionary = action.get("bonus_if_status", {})
	for h in found:
		var t: Node = h["node"]
		if t == null or not c.alive(t):
			continue
		if filter.is_valid() and not bool(filter.call(t)):
			continue
		info["targets"].append(t)
		var tst := CombatantStats.of(t)
		var sh := ShieldComponent.of(t)
		var t_tags: Array = FieldEffects.hit_tags(c, attacker, t, tags)  # caustic floor, white blank (§7.4)
		var penalty: int = ShaveBonus.penalty(attacker, t_tags, tech)
		var total: int = 0
		var shaved: int = 0
		var bonus_left: int = ShaveBonus.against(c, attacker, tech, boost, t, t_tags, bonus_if_status)
		var n_hits: int = hits_per * maxi(1, int(h["hits"]))
		for i in n_hits:
			if not tst.is_alive():
				break
			if not StatusRules.hit_lands(c, a_sc):  # BLIND and its kin (§12.2): a miss shaves nothing
				c.strike_resolved.emit(attacker, t, {"damage": 0, "evaded": true, "missed": true, "tags": t_tags})
				continue
			var res := {"shaved": 0, "hit_weakness": false, "caused_break": false, "matched": false}
			var was_broken: bool = sh != null and sh.is_broken
			if sh != null:
				res = sh.apply_strike(t_tags, bonus_left, attacker, a_stats.actor_id, penalty)
				shaved += int(res["shaved"])
				if res["matched"]:
					bonus_left = 0
				if res["caused_break"]:
					info["breaks"].append(t)
					c.last_break_signature = sh.break_signature
			# §6.4 / §5.4: damage is applied before the shave, so the strike that lands the Break is
			# resolved against the unbroken target (full DEF, no crit); the strikes after it see it Broken.
			var broken_now: bool = sh != null and sh.is_broken
			if sh != null and sh.shield_only and not was_broken:
				c.strike_resolved.emit(attacker, t, {"damage": 0, "shield_only": true, "shave": res["shaved"], "tags": t_tags})
				continue
			var ctx: Dictionary = PartyHit.context(c, action, attacker, best_caster, t, t_tags, res, was_broken, int(h["rank"]), perfect, flicker)
			ctx["taken_mult"] = float(ctx["taken_mult"]) * FieldEffects.on_party_strike(c, t, t_tags)  # confetti, mercury pool
			var r: Dictionary = DamagePipeline.compute_hit(ctx)
			info["raw"][t] = float(r["raw"])  # one hit's raw damage on it: a DoT's tick base (§6.3, EffectSteps)
			var dmg: int = int(r["damage"])
			var dealt: int
			if bool(r["absorbed"]):
				dealt = -tst.heal(dmg)
			elif c.undamageable.has(t):
				dealt = 0
			else:
				dealt = tst.apply_damage(dmg, true)
			total += maxi(0, dealt)
			if float(r["gauge_push"]) > 0.0 and not broken_now:
				c.gauges[t] = maxf(0.0, float(c.gauges.get(t, 0.0)) - float(r["gauge_push"]))
			if push_per_hit > 0.0 and not broken_now:
				c.gauges[t] = maxf(0.0, float(c.gauges.get(t, 0.0)) - push_per_hit)
			if t_tags.has(CombatTags.TACHYON) and c.rng.randf() < 0.25 and not broken_now:
				c.gauges[t] = maxf(0.0, float(c.gauges.get(t, 0.0)) - 10.0)
			if t_tags.has(CombatTags.HZ) and c.wind_ups.has(t) and c.rng.randf() < 0.15:
				c.end_wind_up(t)
			c.strike_resolved.emit(attacker, t, {"damage": dealt, "shave": res["shaved"], "weakness": res["hit_weakness"], "break": res["caused_break"], "crit": r["crit"], "tags": t_tags, "absorbed": r["absorbed"], "sealed": not bool(r["absorbed"]) and c.undamageable.has(t)})
		info["damage"][t] = total
		info["shave"][t] = shaved
		# Boost Lv2 adds the technique's debuff (§7.2); a plain Attack scales power and shape only (§4.2), and a
		# white blank erases the hit's tags and with them its debuff (§7.4).
		if boost >= 2 and tech != null and tst.is_alive() and (tags.is_empty() or not t_tags.is_empty()):
			StatusRules.lv2_debuff(c, tech, tags, t)
	c.ens_rings.erase(attacker)
	StrikeResolution._canvas_clash(c, tags, aim, shape, attacker)
	ResidualFields.leave(c, action, found)  # after the clash, so a NULL blank does not erase its own residual
	if c.token_duplicate_active != attacker:
		c.last_actions[attacker] = action.duplicate()
	c.action_executed.emit(info)
	return info


## Resolve a support technique: its heals and Boost Lv2 status on the allies it reaches. Returns its info.
static func support(c: BattleCoordinator, action: Dictionary) -> Dictionary:
	var attacker: Node = action["attacker"]
	var tech: TechDef = action["tech"]
	var boost: int = int(action.get("boost", 0))
	var casters: Array = action.get("casters", [attacker])
	var a_stats := CombatantStats.of(attacker)
	var targets: Array = []
	match tech.target:
		"self":
			targets = [attacker]
		"party":
			targets = c.party.filter(func(u: Node) -> bool: return c.alive(u))
		"ally":
			if action.get("primary", null) != null:
				targets = [action["primary"]]
		_:
			var shape: Dictionary = action["shape"]
			if int(shape["shape"]) == TechDef.Shape.SELF_AURA or int(shape["shape"]) == TechDef.Shape.CIRCLE:
				for h in TacticalPositioner.targets_in_shape(shape, c.position_of(attacker), action["aim"], CastReach.party_bodies(c, true)):
					targets.append(h["node"])
			elif action.get("primary", null) != null:
				targets = [action["primary"]]
	var info := {"kind": "support", "attacker": attacker, "casters": casters, "tech": tech, "boost": boost, "targets": targets, "heal": {}}
	for t in targets:
		var tst := CombatantStats.of(t)
		if tst == null:
			continue
		if tech.heal > 0.0:
			var tsc := StatusComponent.of(t)
			var mult: float = tsc.healing_multiplier() if tsc != null else 1.0  # Corroded, Concerned (§12.3)
			var amt: int = DamagePipeline.compute_heal(a_stats.e_atk, tech.heal, boost, mult)
			var healed: int = 0
			if tst.is_alive():
				healed = tst.heal(amt)
			info["heal"][t] = healed
			c.heal_resolved.emit(attacker, t, healed)
		if tech.lv2_debuff != &"" and boost >= 2:
			var tsc2 := StatusComponent.of(t)
			if tsc2 != null:
				tsc2.add(tech.lv2_debuff, -1.0, 2)
	c.action_executed.emit(info)
	return info


## Elemental Canvas Clash: ASTRAL burns ink pools to golden watercolour; RUIN turns paper to ash (§9.6).
static func _canvas_clash(c: BattleCoordinator, tags: Array, aim: Vector3, shape: Dictionary, attacker: Node) -> void:
	var radius: float = float(shape.get("radius", 1.5)) * float(shape.get("scale", 1.0))
	if int(shape["shape"]) == TechDef.Shape.SINGLE:
		radius = 1.5
	var center: Vector3 = aim
	if int(shape["shape"]) == TechDef.Shape.SELF_AURA:
		center = c.position_of(attacker)
	if tags.has(CombatTags.ASTRAL):
		var n: int = c.fields.convert(&"ink_pool", &"golden_patch", center, radius, -1.0)
		if n > 0:
			c.battle_message.emit("Astral light burns the ink to gold.")
		c.fields.convert(&"vhs_fog", &"cleared", center, 3.0, 10.0)
	if tags.has(CombatTags.RUIN):
		c.fields.convert(&"paper", &"ash_field", center, radius, -1.0)
	if tags.has(CombatTags.MYCELIA):
		c.fields.convert(&"ash_field", &"spore_mat", center, radius, -1.0)
		c.fields.convert(&"oil", &"spore_mat", center, radius, -1.0)
	if tags.has(CombatTags.NULL):
		c.fields.blank(center, radius, 8.0)
