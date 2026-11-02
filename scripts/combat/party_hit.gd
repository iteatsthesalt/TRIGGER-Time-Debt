## One party strike's damage context for DamagePipeline.compute_hit (Combat Laws Bible §6.2, §6.3, §6.4, §8.7,
## §8.8), built by the coordinator's resolution for every strike. NULL is true damage (§6.3): DEF and
## resistances (resist, immunity, absorb) are ignored and no weakness multiplies it unless NULL itself created
## that weakness (`nulled_weakness`); every other term (synergy, party synergy, home canvas, Boost, the Broken
## crit, guaranteed crits, perfect frame, falloff, height, taken_mult, flicker, variance) applies as to any hit.
class_name PartyHit
extends RefCounted

## A height difference under this many metres is flat ground for the ledge term.
const LEDGE_STEP_M := 1.0


## The caster whose stat the technique uses: the best relevant attack stat among its actors (§8.7), read for
## the technique's `uses` (PHYSICAL P.Atk, ELEMENTAL E.Atk, ASTRAL the average, BEST the higher).
static func best_caster(casters: Array, uses: int, fallback: CombatantStats) -> CombatantStats:
	var best: CombatantStats = fallback
	var best_atk: float = float(DamagePipeline.pick_stats(uses, fallback, null)["atk"])
	for c in casters:
		var cs := CombatantStats.of(c)
		if cs == null:
			continue
		var atk: float = float(DamagePipeline.pick_stats(uses, cs, null)["atk"])
		if atk > best_atk:
			best = cs
			best_atk = atk
	return best


## Height (§8.8): attacking from a ledge downward +10%, upward −10%.
static func ledge(c: BattleCoordinator, attacker: Node, target: Node) -> float:
	var dy: float = c.position_of(attacker).y - c.position_of(target).y
	if dy >= LEDGE_STEP_M:
		return CombatConstants.LEDGE_BONUS
	if dy <= -LEDGE_STEP_M:
		return -CombatConstants.LEDGE_BONUS
	return 0.0


## The context for one strike of `action` by `attacker` (stats from `best`) on `t` with this strike's `tags`.
## `res`: the shield's answer for this strike (hit_weakness); `was_broken`: the target before this strike
## (§6.4: the breaking strike lands at pre-Break DEF); `rank`: the target's falloff rank.
static func context(c: BattleCoordinator, action: Dictionary, attacker: Node, best: CombatantStats, t: Node, tags: Array, res: Dictionary, was_broken: bool, rank: int, perfect: bool, flicker: bool) -> Dictionary:
	var tst := CombatantStats.of(t)
	var sh := ShieldComponent.of(t)
	var tsc := StatusComponent.of(t)
	var def_mult: float = (CombatConstants.BREAK_DEF_MULT if was_broken else 1.0) * (tsc.def_multiplier(c._is_metal(t)) if tsc != null else 1.0)
	var pair: Dictionary = DamagePipeline.pick_stats(int(action.get("uses", TechDef.Uses.BEST)), best, tst, def_mult)
	var ctx := {
		"atk": pair["atk"], "def": pair["def"], "base": float(action.get("base", 1.0)),
		"synergy": float(action.get("synergy", 1.0)),
		"party_synergy": c.party_synergy(), "home_canvas": c._home_canvas(attacker),
		"boost_level": int(action.get("boost", 0)), "in_field": c._in_divinity_or_tether(attacker),
		"weakness": bool(res.get("hit_weakness", false)), "broken": was_broken,
		"crit": bool(action.get("guaranteed_crit", false)) or c._oil_drinker_crit(attacker, t),
		"perfect": perfect, "falloff_rank": rank, "variance": c._variance(),
		"resist": DamagePipeline.resist_factor(tags, sh, tst),
		"ledge": ledge(c, attacker, t),
		"taken_mult": (tsc.damage_taken_multiplier() if tsc != null else 1.0),
		"astral": tags.has(CombatTags.ASTRAL), "target_hp": tst.hp, "is_boss": tst.kind == "boss",
		"flicker_bonus": flicker,
	}
	if tsc != null and tsc.has(&"nulled") and tags.has(CombatTags.ASTRAL) and c._crono_galaxy(attacker):
		ctx["base"] = float(ctx["base"]) * 1.5
	null_rule(ctx, tags, tsc)
	return ctx


## NULL's true damage (§6.3) on a built context: no DEF, no resistance of any kind, and a weakness multiplier
## only when NULL created the weakness. The preview's estimate applies it too.
static func null_rule(ctx: Dictionary, tags: Array, tsc: StatusComponent) -> void:
	if not tags.has(CombatTags.NULL):
		return
	ctx["def"] = 0.0
	ctx["resist"] = 1.0
	ctx["weakness"] = bool(ctx.get("weakness", false)) and tsc != null and tsc.has(&"nulled_weakness")
