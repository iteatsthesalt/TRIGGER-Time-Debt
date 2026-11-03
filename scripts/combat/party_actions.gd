## The two party commands that strike or cast (Combat Laws Bible §4.2, §7.2, §8, §10.2): Attack and a technique,
## from the refusals (not this actor's turn, the target, BP, what the cast needs) through the costs and the Boost to
## the resolution (StrikeResolution, or a handler: TechEffects) and the end of the turn. BattleCoordinator.cmd_attack
## and cmd_tech are their entry points.
class_name PartyActions
extends RefCounted

## The cast choices cmd_tech copies into the action (HOLD's "steps", Tune's "mode").
const ACTION_OPTIONS: Array[String] = ["steps", "mode"]


## Attack: the weapon's hits on `target`, the shape and power scaled by `boost` (§4.2: no debuff).
static func attack(c: BattleCoordinator, actor: Node, target: Node, boost: int) -> Dictionary:
	if not c.is_turn(actor):
		return c.fail("not this actor's turn")
	if not c.enemies.has(target) or not c.alive(target) or c.untargetable(target):
		return c.fail("invalid target")
	if not c.bank.can_spend(boost):
		return c.fail("not enough BP")
	var st := CombatantStats.of(actor)
	c.state = BattleCoordinator.State.EXECUTING
	c.bank.spend(boost)
	if boost > 0:
		c.boost_used.emit(actor, boost)
	var action := {
		"kind": "attack", "attacker": actor, "casters": [actor], "tags": Array(st.weapon_tags),
		"shape": {"shape": TechDef.Shape.SINGLE, "scale": CombatConstants.BOOST_SCALE[boost]},
		"hits": maxi(1, st.weapon_hits), "aim": c.position_of(target), "primary": target,
	}
	action.merge(PartyHit.action_keys(c, null, boost, [actor]))  # base 1.0, P.Atk, no synergy (the preview's too)
	var info: Dictionary = StrikeResolution.resolve(c, action)
	c.finish_turn(actor, 0.0)
	c.after_party_action(info)
	return {"ok": true, "info": info}


## A technique. partners: the Ready Pool allies joining a Dual/Triple (besides the actor). options: the cast's
## choices, copied into the action (ACTION_OPTIONS).
static func tech(c: BattleCoordinator, actor: Node, tech_id: StringName, target: Node, aim: Vector3, boost: int, partners: Array, options: Dictionary) -> Dictionary:
	if not c.is_turn(actor):
		return c.fail("not this actor's turn")
	var t: TechDef = c.tech_library.get(tech_id, null)
	if t == null:
		return c.fail("unknown tech %s" % tech_id)
	var casters: Array = [actor]
	for p in partners:
		if p != actor and not casters.has(p):
			casters.append(p)
	var check: Dictionary = TechCosts.can_cast(c, actor, t, casters, boost)
	if not check["ok"]:
		return check
	if t.target == "enemy" and t.shape == TechDef.Shape.SINGLE and (target == null or not c.enemies.has(target) or not c.alive(target) or c.untargetable(target)):
		return c.fail("invalid target")
	if t.target == "ally" and (target == null or not (c.party.has(target) or target == c.hover_sera or c.bench.has(target))):
		return c.fail("invalid ally target")
	if t.requires_broken and (target == null or not c.is_broken(target)):
		return c.fail("%s needs a Broken target" % t.display_name)  # refused before anything is paid (§10.2)
	c.state = BattleCoordinator.State.EXECUTING
	# Pay costs, then Boost.
	for caster in casters:
		var csc := StatusComponent.of(caster)
		if csc != null:
			csc.begin_action()  # a partner's turn is this action too
		TechCosts.pay(c, caster, t)
		if t.tags.has(CombatTags.TACHYON):
			caster.set_meta("used_tachyon_this_turn", true)  # no +2 solidity on a TACHYON turn (§10.2)
	c.bank.spend(boost)
	if boost > 0:
		c.boost_used.emit(actor, boost)
	var aim_point: Vector3 = aim
	if target != null:
		aim_point = c.position_of(target)
	elif t.shape == TechDef.Shape.SELF_AURA or t.target == "self":
		aim_point = c.position_of(actor)
	var action := {
		"kind": "tech", "attacker": actor, "casters": casters, "tags": Array(t.tags),
		"shape": {"shape": t.shape, "radius": CastReach.radius(t), "length": t.length, "width": t.width,
			"inner_radius": t.inner_radius, "beams": t.beams, "scale": t.shape_scale(boost)},
		"hits": t.hit_count, "aim": aim_point, "primary": target, "steps": maxi(1, t.steps),
	}
	action.merge(PartyHit.action_keys(c, t, boost, casters))  # base, stat, synergy × pair synergy, crit
	for k in ACTION_OPTIONS:
		if options.has(k):
			action[k] = options[k]
	var info: Dictionary
	if t.effect != &"" and TechEffects.handles(t.effect):
		info = TechEffects.apply(c, t, action)
	elif t.heal > 0.0 or t.target in ["ally", "self", "party"]:
		info = StrikeResolution.support(c, action)
	else:
		info = StrikeResolution.resolve(c, action)
	for caster in casters:
		c.finish_turn(caster, 0.0)
		c.cooldowns.start(caster, t)  # counted from each caster's next action on
	c.after_party_action(info)
	return {"ok": true, "info": info}
