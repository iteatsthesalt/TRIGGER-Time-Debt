## Which techniques an ally may use now (Combat Laws Bible §4.3, §8): the kit (the coordinator's knows_tech), the
## recharge, a row's requirements, a pending effect, the Ready Pool for a Dual or Triple (no TRUE NULL ally joins
## one), and the partners who would join.
class_name TechAvailability
extends RefCounted


## The techniques `actor` may use now: those it takes part in and knows, whose actors are all in the Ready Pool.
static func available(c: BattleCoordinator, actor: Node) -> Array[TechDef]:
	var out: Array[TechDef] = []
	var st := CombatantStats.of(actor)
	if st == null:
		return out
	var sc := StatusComponent.of(actor)
	if sc != null and not sc.can_cast_techs():
		return out
	var ready_ids: Array[StringName] = []
	for u in c.ready_pool:
		if c.alive(u):
			ready_ids.append(CombatantStats.of(u).actor_id)
	if not ready_ids.has(st.actor_id):
		ready_ids.append(st.actor_id)
	for id in c.tech_library.keys():
		var t: TechDef = c.tech_library[id]
		if not t.involves(st.actor_id):
			continue
		if not TechAvailability.knows(c, actor, t):
			continue
		if TechAvailability._set_ready(c, t, ready_ids):
			out.append(t)
	return out


## One of `t`'s actor sets is all ready (`ready_ids`), and no TRUE NULL ally of a Dual or Triple is in it.
static func _set_ready(c: BattleCoordinator, t: TechDef, ready_ids: Array[StringName]) -> bool:
	for s in t.actor_sets():
		var ok: bool = true
		for req in (s as Array):
			if not ready_ids.has(req):
				ok = false
				break
		if ok:
			# TRUE NULL allies cannot take part in Duals/Triples.
			if t.is_coop():
				for req2 in (s as Array):
					var u: Node = c.party_unit(req2)
					if u != null and CombatantStats.of(u).true_null:
						return false
			return true
	return false


## `actor` may use `t` at all now: not recharging (unless it stands in the recharge field), not an ultimate under
## an Oil-Blight, its row's requirements met, not pending, and in its kit (the coordinator's knows_tech).
static func knows(c: BattleCoordinator, actor: Node, t: TechDef) -> bool:
	if c.cooldowns.left(actor, t.id) > 0 and not (t.recharge_field != &"" and FieldEffects.stands_in(c, actor, t.recharge_field)):
		return false
	if (t.tier == TechDef.Tier.ULTIMATE and c.bank.ultimates_blocked) or not EffectTable.requirements_met(c, actor, t):
		return false
	if EffectTable.is_pending(t.effect):
		return false  # nothing runs it yet (data/effects/effects.json `pending`)
	if c.knows_tech.is_valid():
		return bool(c.knows_tech.call(actor, t))
	return true


## The Ready Pool allies who would join `actor` in `t` (the first actor set they complete), or [].
static func partners_for(c: BattleCoordinator, t: TechDef, actor: Node) -> Array:
	var out: Array = []
	var my_id: StringName = CombatantStats.of(actor).actor_id
	for s in t.actor_sets():
		if not (s as Array).has(my_id):
			continue
		var found: Array = []
		var ok: bool = true
		for req in (s as Array):
			if req == my_id:
				continue
			var u: Node = null
			for r in c.ready_pool:
				if CombatantStats.of(r).actor_id == req and c.alive(r):
					u = r
					break
			if u == null:
				ok = false
				break
			found.append(u)
		if ok:
			return found
	return out
