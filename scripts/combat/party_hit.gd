## One party strike's damage context for DamagePipeline.compute_hit (Combat Laws Bible §6.2, §6.3, §6.4, §8.7,
## §8.8). `terms` builds every term that only reads the battle; the resolution's `context` adds the strike's own
## draws and spends (the oil-drinker crit, the variance roll, one Exposed stack), and the preview's `estimate` sums
## `terms` over the strikes it aims (variance 1.0, no chance crit), so the aim line reads what the hit deals before
## its rolls (§4.5, §4.6). NULL is true damage (§6.3): DEF and resistances (resist, immunity, absorb) are ignored
## and no weakness multiplies it unless NULL itself created that weakness (`nulled_weakness`); every other term
## (synergy, party synergy, home canvas, Boost, the Broken crit, guaranteed crits, perfect frame, falloff, height,
## taken_mult, flicker, variance) applies as to any hit.
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


## The damage keys of a party action, as `terms` reads them (cmd_attack, cmd_tech and the preview build them here):
## a technique's base, stat, synergy (its own × the casters' pair synergy, §6.2) and guaranteed crit; an Attack's 1.0.
static func action_keys(c: BattleCoordinator, tech: TechDef, boost: int, casters: Array) -> Dictionary:
	if tech == null:
		return {"tech": null, "base": 1.0, "uses": TechDef.Uses.PHYSICAL, "boost": boost, "synergy": 1.0}
	return {"tech": tech, "base": tech.base_per_hit, "uses": tech.uses, "boost": boost,
		"synergy": tech.synergy_base() * c._pair_synergy(casters), "guaranteed_crit": tech.guaranteed_crit}


## Sera's Quantum Flicker (§6.2, §10.2): her strikes deal +20% while three ghost layers or more show.
static func flicker(attacker: Node) -> bool:
	var st := CombatantStats.of(attacker)
	if st == null or st.actor_id != &"sera":
		return false
	var sol := SolidityComponent.of(attacker)
	return sol != null and sol.ghost_layers() >= 3


## Every term of one strike of `action` by `attacker` (stats from `best`) on `t` with this strike's `tags` that only
## reads the battle. `weak`: the strike hits a weakness (the shield's answer); `was_broken`: the target before this
## strike (§6.4: the breaking strike lands at pre-Break DEF); `rank`: the target's falloff rank; `ahead`: strikes of
## this action on `t` before this one that have not landed (the preview's later hits; 0 in the resolution).
static func terms(c: BattleCoordinator, action: Dictionary, attacker: Node, best: CombatantStats, t: Node, tags: Array, weak: bool, was_broken: bool, rank: int, perfect: bool, flick: bool, ahead: int = 0) -> Dictionary:
	var tst := CombatantStats.of(t)
	var sh := ShieldComponent.of(t)
	var tsc := StatusComponent.of(t)
	var def_mult: float = (CombatConstants.BREAK_DEF_MULT if was_broken else 1.0) * (tsc.def_multiplier(c._is_metal(t)) if tsc != null else 1.0)
	var pair: Dictionary = DamagePipeline.pick_stats(int(action.get("uses", TechDef.Uses.BEST)), best, tst, def_mult)
	var ctx := {
		"atk": pair["atk"], "def": pair["def"],
		"base": float(action.get("base", 1.0)) * EffectTable.damage_mult(c, action.get("tech", null), int(action.get("boost", 0)), t),
		"synergy": float(action.get("synergy", 1.0)),
		"party_synergy": c.party_synergy(), "home_canvas": c._home_canvas(attacker),
		"boost_level": int(action.get("boost", 0)), "in_field": c._in_divinity_or_tether(attacker),
		"weakness": weak, "broken": was_broken,
		"crit": bool(action.get("guaranteed_crit", false)),
		"perfect": perfect, "falloff_rank": rank, "variance": 1.0,
		"resist": DamagePipeline.resist_factor(tags, sh, tst),
		"ledge": ledge(c, attacker, t),
		"taken_mult": (tsc.damage_taken_multiplier() if tsc != null else 1.0),
		"astral": tags.has(CombatTags.ASTRAL), "target_hp": tst.hp, "is_boss": tst.kind == "boss",
		"flicker_bonus": flick,
	}
	if tsc != null and tsc.has(&"nulled") and tags.has(CombatTags.ASTRAL) and c._crono_galaxy(attacker):
		ctx["base"] = float(ctx["base"]) * 1.5
	null_rule(ctx, tags, tsc)
	EffectTable.adjust_hit(ctx, tsc, false, ahead)  # The Last Joke's crack, the Gold Leaf washi pocket
	return ctx


## The context for one strike as it lands (the resolution): `terms`, then its draws from the battle RNG (the
## oil-drinker crit, then the variance roll) and its spend (one Exposed stack). `res`: the shield's answer.
static func context(c: BattleCoordinator, action: Dictionary, attacker: Node, best: CombatantStats, t: Node, tags: Array, res: Dictionary, was_broken: bool, rank: int, perfect: bool, flick: bool) -> Dictionary:
	var ctx := terms(c, action, attacker, best, t, tags, bool(res.get("hit_weakness", false)), was_broken, rank, perfect, flick)
	if not bool(ctx["crit"]):
		ctx["crit"] = c._oil_drinker_crit(attacker, t)
	ctx["variance"] = c._variance()
	EffectTable.spend_hit(StatusComponent.of(t))
	return ctx


## The preview's damage on `t` (§4.6): `terms` for each of its `hits` against the target as it stands (variance
## 1.0, no chance crit, nothing spent; a shield-only body takes none until it is Broken, as in the resolution). A
## field's per-strike bonus (the mercury pool) and a Break landing mid-action are not forecast (DECISIONS "The
## preview's damage").
static func estimate(c: BattleCoordinator, action: Dictionary, attacker: Node, best: CombatantStats, t: Node, tags: Array, hits: int, rank: int) -> int:
	var sh := ShieldComponent.of(t)
	var broken: bool = sh != null and sh.is_broken
	if sh != null and sh.shield_only and not broken:
		return 0
	var weak: bool = sh != null and sh.hits_weakness(tags)
	var perfect: bool = bool(c._perfect_frame_pending.get(attacker, false))
	var flick: bool = flicker(attacker)
	var total: int = 0
	for i in hits:
		total += int(DamagePipeline.compute_hit(terms(c, action, attacker, best, t, tags, weak, broken, rank, perfect, flick, i))["damage"])
	return total


## NULL's true damage (§6.3) on a built context: no DEF, no resistance of any kind, and a weakness multiplier
## only when NULL created the weakness (`terms`: the resolution and the preview alike).
static func null_rule(ctx: Dictionary, tags: Array, tsc: StatusComponent) -> void:
	if not tags.has(CombatTags.NULL):
		return
	ctx["def"] = 0.0
	ctx["resist"] = 1.0
	ctx["weakness"] = bool(ctx.get("weakness", false)) and tsc != null and tsc.has(&"nulled_weakness")
