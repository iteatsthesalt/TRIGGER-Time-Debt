## The plate preview (Combat Laws Bible §4.6, §18.7 #23): per target, the shave and damage an action would do, with
## what it reaches decided by CastReach exactly as the resolution decides it.
class_name ActionPreview
extends RefCounted


## Preview the shave and damage of an action per target (§4.6); what it reaches is CastReach's, as in the resolution.
static func of(c: BattleCoordinator, actor: Node, tech: TechDef, target: Node, aim: Vector3, boost: int, partners: Array = []) -> Dictionary:
	var st := CombatantStats.of(actor)
	if not CastReach.strikes(tech):
		return {}
	if tech == null:
		partners = []  # an Attack is the actor's alone (cmd_attack), whatever Dual was picked and backed out of
	var tags: Array = Array(tech.tags) if tech != null else Array(st.weapon_tags)
	var hits: int = CastReach.hits(c, tech, actor, boost, partners) if tech != null else maxi(1, st.weapon_hits)
	var shape: Dictionary = {"shape": TechDef.Shape.SINGLE, "scale": CombatConstants.BOOST_SCALE[boost]}
	if tech != null:
		shape = {"shape": tech.shape, "radius": CastReach.radius(tech), "length": tech.length, "width": tech.width, "inner_radius": tech.inner_radius, "beams": CastReach.beams(c, tech, actor, boost, partners), "scale": tech.shape_scale(boost)}
	var aim_point: Vector3 = c.position_of(target) if target != null else aim
	var found: Array = CastReach.caught(c, tech, TacticalPositioner.targets_in_shape(shape, c.position_of(actor), aim_point, CastReach.enemy_bodies(c), CastReach.blockers(c), CastReach.extra_origins(c, [actor] + partners)))
	var bonus_if_status: Dictionary = TechEffects.bonus_if_status(tech)
	var casters: Array = [actor]
	for pa in partners:
		if pa != actor and not casters.has(pa):
			casters.append(pa)
	var keys: Dictionary = PartyHit.action_keys(c, tech, boost, casters)  # the damage keys cmd_tech builds
	var best: CombatantStats = PartyHit.best_caster(casters, int(keys["uses"]), st)
	var out: Dictionary = {}
	for h in found:
		var e: Node = h["node"]
		var sh := ShieldComponent.of(e)
		var t_tags: Array = FieldEffects.hit_tags(c, actor, e, tags)  # caustic floor, white blank (§7.4)
		var p: Dictionary = {"shave": 0, "breaks": false, "already_broken": false, "after": 0}
		if sh != null:
			p = sh.preview_action(t_tags, hits * int(h["hits"]), ShaveBonus.against(c, actor, tech, boost, e, t_tags, bonus_if_status), st.actor_id, ShaveBonus.penalty(actor, t_tags, tech))
		p["hits"] = hits * int(h["hits"])
		p["sealed"] = c.undamageable.has(e)  # a sealed body takes no HP damage; the plates still shave
		p["damage"] = 0 if p["sealed"] else PartyHit.estimate(c, keys, actor, best, e, t_tags, hits * int(h["hits"]), int(h["rank"]))
		out[e] = p
	CastReach.after_plates(c, tech, actor, out, aim_point, boost)  # shave_any, auto_break, a crossing plate
	return out
