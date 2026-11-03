## What a technique's cast reaches, read by the resolution and by the plate preview alike, so the plate shows the
## shave the hit then does for every technique and shape (Combat Laws Bible §4.6, §18.7 #23): whether the cast
## strikes enemies at all, the extra origins a multi-caster shape takes from the partners (DELTA's corners), and
## the filter a technique applies to the bodies its shape caught (Overclocked Short-Circuit arcs through metal), its
## row's pre ops (more hits, stacks as beams) and the plates its after-effects take beyond the hits.
class_name CastReach
extends RefCounted

## Cassia-09's Gramophone Centaur reaches this much further with Mercury Pulse (§10: "radius +1.0 as Centaur").
const CENTAUR_PULSE_BONUS_M := 1.0


## True when a cast of `tech` resolves hits on enemies (a plain Attack, `tech` null, always does). False for
## support and heals, an effect row whose resolve is "none" or "support" (Time Mines, Rewind Reel), and the
## bespoke handlers that strike nothing (Rewind, Miura Fold, the NULL strips, Fake Family Photo).
static func strikes(tech: TechDef) -> bool:
	if tech == null:
		return true
	if tech.effect != &"" and TechEffects.handles(tech.effect):
		if TechEffects.HANDLED.has(tech.effect):
			return TechEffects.STRIKING.has(tech.effect)
		return EffectSteps.resolve_mode(tech) == "damage"
	return not (tech.heal > 0.0 or tech.target in ["ally", "self", "party"])  # cmd_tech's support path


## The radius a cast of `tech` reaches before its shape scale: the technique's own, plus a form's (Cassia-09's
## Gramophone Centaur, her default form, adds CENTAUR_PULSE_BONUS_M to Mercury Pulse; the Bipedal Porcelain of
## R66Y Salvaged adds nothing, §10). The resolution, the plate preview, the statuses the pulse lays and the aim
## outline all read it, so what is slowed is what is struck.
static func radius(tech: TechDef) -> float:
	if tech.effect == &"mercury_pulse" and not Flags.is_state(&"R66Y", &"Salvaged"):
		return tech.radius + CENTAUR_PULSE_BONUS_M
	return tech.radius


## The second and third origins a shape takes from the casters after the first (a Dual's or Triple's partners).
static func extra_origins(c: BattleCoordinator, casters: Array) -> Dictionary:
	var extra: Dictionary = {}
	if casters.size() >= 2:
		extra["second_origin"] = c.position_of(casters[1])
	if casters.size() >= 3:
		extra["third_origin"] = c.position_of(casters[2])
	return extra


## The filter a cast of `tech` applies to the bodies its shape caught: a body it returns false for is not struck
## (and the preview leaves its plate alone). An invalid Callable when every caught body is struck.
static func target_filter(c: BattleCoordinator, tech: TechDef) -> Callable:
	if tech != null and tech.effect == &"overclocked_short_circuit":
		return func(t: Node) -> bool: return c._is_metal(t)  # arcs through metal only (§11)
	return Callable()


## The hits of `found` (TacticalPositioner.targets_in_shape) a cast of `tech` strikes, its target filter applied.
static func caught(c: BattleCoordinator, tech: TechDef, found: Array) -> Array:
	var filter: Callable = target_filter(c, tech)
	if not filter.is_valid():
		return found
	return found.filter(func(h: Dictionary) -> bool: return bool(filter.call(h["node"])))


## The plates a cast's own after-effects take beyond its hits, applied to the plate preview `out` (body -> plate):
## a row's shave_any tops each body it hit up to `n` plates, its auto_break Breaks the smallest shield it hit
## (EffectOps), and Eclipse X-Strike's crossing erases one more plate within its radius of the aim (§11).
static func after_plates(c: BattleCoordinator, tech: TechDef, actor: Node, out: Dictionary, aim: Vector3, boost: int) -> void:
	if tech == null or out.is_empty():
		return
	var open: Array = out.keys().filter(func(e: Node) -> bool: return ShieldComponent.of(e) != null and not bool(out[e]["breaks"]) and not bool(out[e]["already_broken"]))
	if tech.effect == &"eclipse_x_strike":
		for e in open:
			var sh := ShieldComponent.of(e)
			if c.position_of(e).distance_to(aim) <= tech.radius and int(out[e]["after"]) > 0:
				var tag: StringName = sh.weaknesses[0] if not sh.weaknesses.is_empty() else &"SWORD"  # as the handler strikes
				_take(out[e], mini(1, int(sh.preview_action([tag], 1, 0)["shave"])), sh)
		return
	if TechEffects.HANDLED.has(tech.effect) or not EffectTable.has_row(tech.effect):
		return
	var broke: Array = out.keys().filter(func(e: Node) -> bool: return bool(out[e]["breaks"]))
	var ctx := {"c": c, "tech": tech, "action": {}, "boost": boost, "attacker": actor, "casters": [actor], "info": {"breaks": broke}}
	for op in EffectTable.row(tech.effect).get("after", []):
		if String(op.get("on", "hit")) != "hit":
			continue
		var each: Array = open.filter(func(e: Node) -> bool: return not bool(out[e]["breaks"]) and EffectTable.holds(op.get("if", {}), ctx, e))
		match String(op.get("op", "")):
			"shave_any":
				for e in each:
					_take(out[e], maxi(0, int(op["n"]) - int(out[e]["shave"])), ShieldComponent.of(e))
			"auto_break":
				if String(op.get("pick", "smallest")) != "smallest" or each.is_empty():
					continue  # "zero" picks bodies already at 0, which the plates show as Broken when they can be
				var best: Node = each[0]
				for e in each:
					if int(out[e]["after"]) < int(out[best]["after"]):
						best = e
				if ShieldComponent.of(best).can_break_now():
					_take(out[best], int(out[best]["after"]), ShieldComponent.of(best))


static func _take(p: Dictionary, n: int, sh: ShieldComponent) -> void:
	if n <= 0:
		return
	var take: int = mini(n, int(p["after"]))
	p["shave"] = int(p["shave"]) + take
	p["after"] = int(p["after"]) - take
	p["breaks"] = int(p["after"]) <= 0 and sh.can_break_now()


## The hits per body a cast of `tech` resolves: its count as its effect row's `pre` ops leave it (Prism
## Refraction's 9 at Lv3, stacks spent as hits), read without spending anything (EffectSteps._pre spends them).
static func hits(c: BattleCoordinator, tech: TechDef, actor: Node, boost: int, partners: Array = []) -> int:
	return int(_pre(c, tech, actor, boost, partners)["hits"])


## The beams a cast of `tech` fires: the technique's own plus the stacks its row's `pre` ops spend as beams.
static func beams(c: BattleCoordinator, tech: TechDef, actor: Node, boost: int, partners: Array = []) -> int:
	return int(_pre(c, tech, actor, boost, partners)["beams"])


static func _pre(c: BattleCoordinator, tech: TechDef, actor: Node, boost: int, partners: Array) -> Dictionary:
	var out := {"hits": tech.hit_count, "beams": tech.beams}
	if TechEffects.HANDLED.has(tech.effect) or not EffectTable.has_row(tech.effect):
		return out
	var ctx := {"c": c, "tech": tech, "action": {}, "boost": boost, "attacker": actor, "casters": [actor] + partners, "info": {}}
	for op in EffectTable.row(tech.effect).get("pre", []):
		if not EffectTable.holds(op.get("if", {}), ctx):
			continue
		match String(op["op"]):
			"hits":
				out["hits"] = int(op.get("n", out["hits"]))
			"spend_stacks":
				var sc := StatusComponent.of(actor)
				var n: int = sc.stacks(StringName(String(op.get("status", "")))) if sc != null else 0
				out["beams"] = int(out["beams"]) + n * int(op.get("beams_per", 1))
				out["hits"] = int(out["hits"]) + n * int(op.get("hits_per", 0))
	return out
