## Runs one effect-table row (data/effects/effects.json; EffectTable) for a technique: the `pre` ops change the
## action, the action resolves (damage, support or nothing), then the `after` ops run in order, each on the set
## its `on` names and only where its `if` holds. The everyday ops live here; the ones that move bodies, plates,
## fields and story state live in EffectOps. TechEffects.apply calls this for every effect without a handler.
class_name EffectSteps
extends RefCounted


static func apply(c: BattleCoordinator, tech: TechDef, action: Dictionary) -> Dictionary:
	var r: Dictionary = EffectTable.row(tech.effect)
	var actor: Node = action["attacker"]
	var ctx := {"c": c, "tech": tech, "action": action, "boost": int(action.get("boost", 0)), "attacker": actor,
		"casters": action.get("casters", [actor]), "info": {}}
	for op in r.get("pre", []):
		if EffectTable.holds(op.get("if", {}), ctx):
			_pre(c, op, action, actor)
	var info: Dictionary = _resolve(c, tech, action, resolve_mode(tech))
	ctx["info"] = info
	if bool(r.get("requires", {}).get("once_per_battle", false)):
		EffectTable.mark_used(c, tech.effect)
	for op in r.get("after", []):
		run(c, op, ctx)
	return info


## How the row of `tech` resolves its action: "damage", "support" or "none" (the row's `resolve`, else by its kind).
static func resolve_mode(tech: TechDef) -> String:
	return String(EffectTable.row(tech.effect).get("resolve", _default_resolve(tech)))


static func _default_resolve(tech: TechDef) -> String:
	if tech.is_attack and tech.base_per_hit > 0.0:
		return "damage"
	if tech.heal > 0.0 or tech.target in ["ally", "self", "party"]:
		return "support"
	return "none"


static func _resolve(c: BattleCoordinator, tech: TechDef, action: Dictionary, how: String) -> Dictionary:
	var actor: Node = action["attacker"]
	var info := {"kind": "effect", "effect": tech.effect, "attacker": actor, "casters": action.get("casters", [actor]), "tech": tech,
		"boost": int(action.get("boost", 0)), "targets": [], "damage": {}, "raw": {}, "shave": {}, "breaks": [], "heal": {}}
	match how:
		"damage":
			var dmg: Dictionary = c._resolve_action(action)
			for k in ["targets", "damage", "raw", "shave", "breaks"]:
				info[k] = dmg[k]
		"support":
			var sup: Dictionary = c._resolve_support(action)
			info["targets"] = sup["targets"]
			info["heal"] = sup["heal"]
		_:
			var p: Node = action.get("primary", null)
			if p != null:
				info["targets"] = [p]
	return info


## Action changes before it resolves: more hits (Prism Refraction's 9 at Lv3), stacks spent as beams.
static func _pre(_c: BattleCoordinator, op: Dictionary, action: Dictionary, actor: Node) -> void:
	match String(op["op"]):
		"hits":
			action["hits"] = int(op.get("n", action.get("hits", 1)))
		"spend_stacks":
			var sc := StatusComponent.of(actor)
			var sid := StringName(String(op.get("status", "")))
			var n: int = sc.stacks(sid) if sc != null else 0
			if n > 0:
				sc.remove(sid)
				action["shape"]["beams"] = int(action["shape"].get("beams", 0)) + n * int(op.get("beams_per", 1))
				action["hits"] = int(action.get("hits", 1)) + n * int(op.get("hits_per", 0))


## Run one `after` op.
static func run(c: BattleCoordinator, op: Dictionary, ctx: Dictionary) -> void:
	var name: String = String(op.get("op", ""))
	var on: Array = units(c, String(op.get("on", "hit")), op, ctx)
	var cond: Dictionary = op.get("if", {})
	var each: Array = on.filter(func(u: Node) -> bool: return EffectTable.holds(cond, ctx, u))
	if not _per_unit(name) and not EffectTable.holds(cond, ctx, null if on.is_empty() else on[0]):
		return
	match name:
		"status":
			for u in each:
				_status(c, op, ctx, u)
		"heal":
			for u in each:
				heal_pct(c, ctx["attacker"], u, float(op.get("pct", 0.0)))
		"heal_dealt":
			var dealt: int = 0
			for t in ctx["info"].get("damage", {}).keys():
				dealt += maxi(0, int(ctx["info"]["damage"][t]))
			var allies: Array = units(c, "party", op, ctx)
			for u in allies:  # what it deals is shared out across the living party (DECISIONS "Effect table")
				var st := CombatantStats.of(u)
				c.heal_resolved.emit(ctx["attacker"], u, st.heal(roundi(float(dealt) * float(op.get("x", 1.0)) / float(allies.size()))))
		"gauge":
			for u in each:
				var g: float = float(op["set"]) if op.has("set") else c.get_gauge(u) + float(op.get("add", 0.0))
				c.set_gauge(u, g)
		"lock":
			for u in each:
				var sh := ShieldComponent.of(u)
				if sh != null:
					sh.extend_lock(float(op.get("s", 0.0)))
		"delay_rebuild":
			for u in each:
				var sh2 := ShieldComponent.of(u)
				if sh2 != null:
					sh2.delay_rebuild(float(op.get("s", 0.0)))
		"cleanse":
			for u in each:
				var sc := StatusComponent.of(u)
				if sc == null:
					continue
				if op.has("ids"):
					for id in op["ids"]:
						sc.remove(StringName(String(id)))
				else:
					sc.cleanse()
		"purge_buff":
			for u in each:
				for i in int(op.get("n", 1)):
					purge_buff(StatusComponent.of(u))
		"steal":
			# Glenn's steal (§7.5: the counter first, then the laugh) sized by the op: `by_boost` per Boost level,
			# else `n` (1). The size picks the lowest steal level that takes that many, and it is the whole action's:
			# one steal per Glenn action (§7.5, #22), taken from the units of `on` in order until it is filled (Guilt
			# Halo's Breaks); only the Ash Ringmaster's Break gives more (its whole counter).
			var table: Array = op.get("by_boost", [])
			var want: int = int(table[clampi(int(ctx["boost"]), 0, table.size() - 1)]) if not table.is_empty() else int(op.get("n", 1))
			var level: int = 0
			while level < CombatConstants.GLENN_STEAL.size() - 1 and CombatConstants.GLENN_STEAL[level] < want:
				level += 1
			var left: int = CombatConstants.GLENN_STEAL[level]
			for u in each:
				if left <= 0:
					break
				left -= TechEffects._steal_from(c, _caster(c, ctx, &"glenn"), u, level, left)
		"bp":
			var n2: int = int(op.get("n", 0))
			if n2 < 0:
				c.bank.drain(-n2)
			else:
				if int(op.get("overcap", 0)) > 0:
					c.bank.overflow_allowance = maxi(c.bank.overflow_allowance, int(op["overcap"]))
					c.bank.overflow_turns = (ctx["casters"] as Array).size() + 1  # survives the casters' own turn ends
				c.bank.add(n2)
		"solidity":
			var sera: Node = c.unit_by_id(&"sera")
			var sol := SolidityComponent.of(sera)
			if sol != null:
				sol.restore(float(op.get("restore", 0.0)))
		"strain":
			for u in (each if op.has("on") else [c.unit_by_id(&"crono")]):
				var td := TimeDebtComponent.of(u)
				if td != null:
					td.restore_battle_strain(float(op.get("restore", 0.0)))
		"thaw_ruin":
			for u in each:
				RuinRules.thaw(u, int(op.get("stacks", 1)))
		"spend_stacks":
			var sc2 := StatusComponent.of(ctx["attacker"])
			if sc2 != null:
				sc2.remove_stacks(StringName(String(op.get("status", ""))), int(op.get("max", 99)))
		_:
			EffectOps.run(c, name, op, ctx, each)


## Ops whose `if` is read for every unit of `on` (they act on those that pass); every other op acts once for the
## whole action, and its `if` is read against the first unit of `on`.
static func _per_unit(name: String) -> bool:
	return name in ["status", "heal", "gauge", "lock", "delay_rebuild", "cleanse", "purge_buff", "steal", "thaw_ruin",
		"hide_weakness", "grant_weakness", "strip_resists", "steal_buff", "shave_any", "plates", "pull", "rift_after", "whiteout"]


## The set an op works on.
static func units(c: BattleCoordinator, on: String, op: Dictionary, ctx: Dictionary) -> Array:
	var info: Dictionary = ctx["info"]
	var action: Dictionary = ctx["action"]
	match on:
		"hit":
			return (info.get("targets", []) as Array).filter(func(u: Node) -> bool: return is_instance_valid(u))
		"broke":
			return (info.get("breaks", []) as Array).duplicate()
		"target":
			var p: Node = action.get("primary", null)
			return [p] if p != null else (info.get("targets", []) as Array).slice(0, 1)
		"self":
			return [ctx["attacker"]]
		"casters":
			return (ctx["casters"] as Array).duplicate()
		"crono", "sera":
			var u: Node = c.unit_by_id(StringName(on))
			return [u] if u != null else []
		"party":
			return c.party.filter(func(u: Node) -> bool: return c._alive(u))
		"enemies":
			return c.living_enemies()
		"vaelos":
			return c.living_enemies().filter(func(e: Node) -> bool: return EffectTable.id_matches(CombatantStats.of(e).actor_id, ["vaelos", "empress_vaelos"]))
		"allies_in", "enemies_in":
			var tech: TechDef = ctx["tech"]
			var radius: float = float(op.get("radius", tech.radius * float(action["shape"].get("scale", 1.0)) * float(op.get("aoe", 1.0))))
			var center: Vector3 = action["aim"]
			var pool: Array = c.party if on == "allies_in" else c.enemies
			return pool.filter(func(u: Node) -> bool: return c._alive(u) and c.position_of(u).distance_to(center) <= radius)
	push_warning("EffectSteps: unknown set %s" % on)
	return []


## A `status` op; with `dot` its tick is that fraction of one hit's raw damage on the body (§6.3): the raw of the
## action's last strike that landed on it, else (a body it caught but did not strike) the best caster's against it.
static func _status(c: BattleCoordinator, op: Dictionary, ctx: Dictionary, u: Node) -> void:
	var extra: Dictionary = {}
	if op.has("dot"):
		var raws: Dictionary = ctx["info"].get("raw", {})
		extra["tick"] = StatusRules.dot_tick(float(raws[u]) if raws.has(u) else _raw(c, ctx, u), float(op["dot"]))
	StatusRules.apply(c, u, StringName(String(op.get("id", ""))), float(op.get("s", -1.0)), int(op.get("turns", -1)), int(op.get("stacks", 1)), extra)


## §6.4's raw term of the cast's best caster (for its `uses`) against `u`, at `u`'s DEF as it stands.
static func _raw(c: BattleCoordinator, ctx: Dictionary, u: Node) -> float:
	var uses: int = int(ctx["action"].get("uses", TechDef.Uses.BEST))
	var best: CombatantStats = PartyHit.best_caster(ctx["casters"], uses, CombatantStats.of(ctx["attacker"]))
	var tsc := StatusComponent.of(u)
	var pair: Dictionary = DamagePipeline.pick_stats(uses, best, CombatantStats.of(u), tsc.def_multiplier(c._is_metal(u)) if tsc != null else 1.0)
	return maxf(1.0, 0.8 * (float(pair["atk"]) - float(pair["def"]) * 0.5))


static func heal_pct(c: BattleCoordinator, source: Node, u: Node, pct: float) -> void:
	var st := CombatantStats.of(u)
	if st == null or not st.is_alive():
		return
	var sc := StatusComponent.of(u)
	var mult: float = sc.healing_multiplier() if sc != null else 1.0
	c.heal_resolved.emit(source, u, st.heal(roundi(float(st.max_hp()) * pct * mult)))


## Remove one buff (Ruin Purge, Eclipse X-Strike, Masque Feint). Returns the id removed, or &"".
static func purge_buff(sc: StatusComponent) -> StringName:
	if sc == null:
		return &""
	for id in EffectTable.BUFFS:
		if sc.has(id):
			sc.remove(id)
			return id
	return &""


static func _caster(c: BattleCoordinator, ctx: Dictionary, id: StringName) -> Node:
	for u in ctx["casters"]:
		if CombatantStats.of(u).actor_id == id:
			return u
	var found: Node = c.unit_by_id(id)
	return found if found != null else ctx["attacker"]
