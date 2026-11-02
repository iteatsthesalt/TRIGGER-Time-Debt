## What a technique's cast reaches, read by the resolution and by the plate preview alike, so the plate shows the
## shave the hit then does for every technique and shape (Combat Laws Bible §4.6, §18.7 #23): whether the cast
## strikes enemies at all, the extra origins a multi-caster shape takes from the partners (DELTA's corners), and
## the filter a technique applies to the bodies its shape caught (Overclocked Short-Circuit arcs through metal).
class_name CastReach
extends RefCounted


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
