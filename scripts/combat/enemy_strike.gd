## One enemy action's strikes on one battler (Combat Laws Bible §3.5, §6, §12; DECISIONS "Enemy evasion
## rolls"): evasion against untelegraphed hits, the Ens Parry, damage through the pipeline, Ward and Glass Ward,
## the zero-fail HP floor, then the action's status. What its maker was under when it chose the action
## (EnemyBrain) applies here: Probability Lock rolls evasion, damage variance and the status chance twice and
## keeps the worse for the attacker; Refracted splits 20% of the damage away.
class_name EnemyStrike
extends RefCounted


## Resolve `shape_hits` × the action's hits on `t`, each scaled by `scale` (a hit Bekkler's Guilt turned onto Crono
## lands at 75%, TauntBook). Returns the HP removed.
static func resolve(c: BattleCoordinator, e: Node, t: Node, action: Dictionary, shape_hits: int, rank: int, scale: float = 1.0) -> int:
	var est := CombatantStats.of(e)
	var tst := CombatantStats.of(t)
	var tags: Array = action.get("tags", [])
	var hits: int = maxi(1, int(action.get("hits", 1))) * maxi(1, shape_hits)
	var total: int = 0
	var telegraphed: bool = float(action.get("wind_up_s", 0.0)) > 0.0
	var locked: bool = bool(action.get("probability_lock", false))
	var keep: float = 1.0 - CombatConstants.REFRACTED_SPLIT if bool(action.get("refracted", false)) else 1.0
	var redirect: StringName = EnemyEffects.redirect(e)  # Ruin Elastic's decoy, Masque Feint's undermask
	if redirect == &"decoyed":
		c.strike_resolved.emit(e, t, {"damage": 0, "decoy": true, "tags": tags})
		return 0
	if fire_proof(t, tags):  # Balloon Escape (§11): the inflated body squashes out of every [FIRE] hit
		c.strike_resolved.emit(e, t, {"damage": 0, "evaded": true, "immune": true, "tags": tags})
		return 0
	for i in hits:
		if not tst.is_alive():
			break
		# Evasion: LUK × 0.05% + Trauma Silence + status, against non-telegraphed hits only.
		if not telegraphed:
			var evade: float = tst.luk * 0.0005 + evasion_bonus(t)
			if _roll(c, locked, false) < evade:
				c.strike_resolved.emit(e, t, {"damage": 0, "evaded": true, "tags": tags})
				continue
		# Ens Parry: a perfect parry negates the hit and leaves an Ens ring.
		if tst.is_guarding and c.parry_armed.has(t):
			c.parry_armed.erase(t)
			c.ens_rings[t] = {"left": CombatConstants.ENS_RING_DEBT_NULL_S, "shave": 1}
			var td := TimeDebtComponent.of(t)
			if td != null:
				td.debt_null_left = CombatConstants.ENS_RING_DEBT_NULL_S
			c.parry_result.emit(t, true)
			c.strike_resolved.emit(e, t, {"damage": 0, "parried": true, "tags": tags})
			continue
		var uses: int = int(TechDef.USES_NAMES.get(String(action.get("uses", "BEST")), TechDef.Uses.BEST))
		var tsc := StatusComponent.of(t)
		var pair: Dictionary = DamagePipeline.pick_stats(uses, est, tst, (tsc.def_multiplier(false) if tsc != null else 1.0))
		var variance: float = c._variance()
		if locked:
			variance = minf(variance, c._variance())
		var ctx := {
			"atk": pair["atk"], "def": pair["def"], "base": float(action.get("power", 1.0)),
			"falloff_rank": rank, "variance": variance,
			"vulnerable": tst.is_vulnerable_to(tags), "resist": (CombatConstants.RESIST_MULT if tst.is_resistant_to(tags) else 1.0),
			"taken_mult": (tsc.damage_taken_multiplier() if tsc != null else 1.0) * keep * scale,
		}
		var shielded: bool = tst.null_shield or (tsc != null and tsc.has(&"null_shield"))  # Omega Triple: for the fight
		if shielded or tst.true_null:
			ctx["taken_mult"] = float(ctx["taken_mult"]) * (0.8 if shielded else 1.0)
		var r: Dictionary = DamagePipeline.compute_hit(ctx)
		var dmg: int = int(r["damage"])
		if redirect == &"mirrored":
			c.strike_resolved.emit(e, e, {"damage": est.apply_damage(dmg, true), "reflected": true, "tags": tags})
			continue
		# Marle's Ward and Glass Ward halve the hit. (The Mycelia net's 15% share, §12.5, is not modelled yet.)
		if tsc != null and tsc.has(&"ward"):
			dmg = roundi(float(dmg) * 0.5)
			tsc.remove(&"ward")
		if tsc != null and tsc.has(&"glass_ward"):
			dmg = roundi(float(dmg) * 0.5)
			tsc.remove_stacks(&"glass_ward", 1)
		var vulnerable_breaks_guard: bool = bool(ctx["vulnerable"])
		if c.party_hp_floor > 0 and c.party.has(t):
			# zero-fail fights (the 999 Shard Doll): nobody here can be knocked out
			dmg = mini(dmg, maxi(0, tst.hp - c.party_hp_floor))
		var dealt: int = tst.apply_damage(dmg, vulnerable_breaks_guard)
		total += dealt
		apply_status(c, action, t, float(r["raw"]))
		c.strike_resolved.emit(e, t, {"damage": dealt, "tags": tags, "crit": r["crit"]})
		c._after_damage(t)
	return total


## The action's status on a landed hit: the target's resistance (LUK × 0.1%, max 30%), then the action's chance.
## A DoT keeps 15% of the hit's raw damage (`raw`, §6.4's term before power, crit or variance) as its tick (§6.3).
static func apply_status(c: BattleCoordinator, action: Dictionary, t: Node, raw: float) -> void:
	var sid := StringName(String(action.get("status", "")))
	if sid == &"" or StatusComponent.of(t) == null:
		return
	var st := CombatantStats.of(t)
	var resist_chance: float = minf(0.30, st.luk * 0.001)
	if c.rng.randf() < resist_chance:
		return
	if _roll(c, bool(action.get("probability_lock", false)), true) > float(action.get("status_chance", 1.0)):
		return
	var extra: Dictionary = {}
	if StatusRules.DOTS.has(sid):
		extra["tick"] = StatusRules.dot_tick(raw)
	StatusRules.apply(c, t, sid, float(action.get("status_seconds", -1.0)), int(action.get("status_turns", -1)), 1, extra)


## `t` is inflated by Balloon Escape (its `balloon` status, 2 s) and the action is [FIRE].
static func fire_proof(t: Node, tags: Array) -> bool:
	var sc := StatusComponent.of(t)
	return sc != null and sc.has(&"balloon") and CombatTags.to_names(tags).has(&"FIRE")


static func evasion_bonus(t: Node) -> float:
	var st := CombatantStats.of(t)
	var bonus: float = 0.0
	if st.actor_id == &"crono":
		bonus += 0.10
		if st.hp_ratio() < 0.5:
			bonus += 0.10
	var sc := StatusComponent.of(t)
	if sc != null:
		bonus += sc.evasion_bonus()
	return bonus


## One roll; under Probability Lock two, keeping the worse for the attacker (`high_is_worse`: the higher).
static func _roll(c: BattleCoordinator, locked: bool, high_is_worse: bool) -> float:
	var r: float = c.rng.randf()
	if locked:
		var r2: float = c.rng.randf()
		r = maxf(r, r2) if high_is_worse else minf(r, r2)
	return r
