## The damage pipeline (Combat Laws Bible §6). Pure functions; the coordinator feeds a context.
class_name DamagePipeline
extends RefCounted

## ctx keys (all optional except atk/def):
##   atk, def: floats (def already halved by the caller when the target is Broken)
##   base, synergy, party_synergy, home_canvas, boost_level, in_field (bool, dampens Boost ×0.9)
##   weakness (bool), broken (bool), crit (bool), perfect (bool), falloff_rank (int, 0 = nearest)
##   resist: 1.0 normal, 0.5 resisted, 0.0 immune, -1.0 absorbed
##   ledge: +0.1 / -0.1 / 0, vulnerable (bool, ×1.5 on allies), taken_mult (status multiplier)
##   variance: float in [0.95, 1.05] (pass 1.0 for deterministic tests)
##   astral (bool), target_hp (int), is_boss (bool), flicker_bonus (bool)
## Returns {damage, mult, crit, absorbed, displacement, gauge_push}.
static func compute_hit(ctx: Dictionary) -> Dictionary:
	var atk: float = float(ctx.get("atk", 0.0))
	var def: float = float(ctx.get("def", 0.0))
	var raw: float = maxf(1.0, 0.8 * (atk - def * 0.5))
	var boost_level: int = clampi(int(ctx.get("boost_level", 0)), 0, 4)
	var boost: float = CombatConstants.BOOST_POWER[boost_level]
	if bool(ctx.get("in_field", false)) and boost_level > 0:
		boost *= CombatConstants.BOOST_FIELD_DAMPEN
	var mult: float = float(ctx.get("base", 1.0)) * float(ctx.get("synergy", 1.0)) \
		* float(ctx.get("party_synergy", 1.0)) * float(ctx.get("home_canvas", 1.0)) * boost
	mult *= state_multiplier(bool(ctx.get("weakness", false)), boost_level)
	var crit: bool = bool(ctx.get("crit", false)) or bool(ctx.get("broken", false))
	if crit:
		mult *= CombatConstants.CRIT_MULT
	if bool(ctx.get("perfect", false)):
		mult *= CombatConstants.PERFECT_FRAME_MULT
	mult *= falloff(int(ctx.get("falloff_rank", 0)), boost_level)
	mult *= 1.0 + float(ctx.get("ledge", 0.0))
	if bool(ctx.get("flicker_bonus", false)):
		mult *= 1.0 + CombatConstants.SERA_FLICKER_BONUS
	if bool(ctx.get("vulnerable", false)):
		mult *= 1.5
	mult *= float(ctx.get("taken_mult", 1.0))
	var resist: float = float(ctx.get("resist", 1.0))
	var absorbed: bool = resist < 0.0
	var dmg: float = raw * mult * absf(resist) * float(ctx.get("variance", 1.0))
	var displacement: int = 0
	var gauge_push: float = 0.0
	if bool(ctx.get("astral", false)) and not absorbed and resist > 0.0:
		var pct: float = 0.0025 if bool(ctx.get("is_boss", false)) else 0.01
		displacement = roundi(float(int(ctx.get("target_hp", 0))) * pct)
		gauge_push = 5.0
	return {
		"damage": maxi(0, roundi(dmg)) + displacement,
		"mult": mult,
		"crit": crit,
		"absorbed": absorbed,
		"displacement": displacement,
		"gauge_push": gauge_push,
	}


static func state_multiplier(weakness: bool, boost_level: int) -> float:
	if weakness:
		return CombatConstants.STATE_WEAK_LV3 if boost_level >= 3 else CombatConstants.STATE_WEAK
	return CombatConstants.STATE_LV3 if boost_level >= 3 else CombatConstants.STATE_NORMAL


## Area falloff by target rank (nearest first); at Lv3+ it starts one target later. Never reduces shave.
static func falloff(rank: int, boost_level: int) -> float:
	var r: int = rank
	if boost_level >= 3:
		r -= 1
	if r <= 0:
		return 1.0
	return CombatConstants.AOE_FALLOFF[mini(r, CombatConstants.AOE_FALLOFF.size() - 1)]


## Healing (§6.3): heal = E.Atk × base × boost × 0.9, boosted like attacks; Corroded targets receive half.
static func compute_heal(e_atk: float, base: float, boost_level: int, healing_mult: float = 1.0) -> int:
	var boost: float = CombatConstants.BOOST_POWER[clampi(boost_level, 0, 4)]
	return maxi(1, roundi(e_atk * base * boost * 0.9 * healing_mult))


## The attack/defence pair a technique uses (§6.1). Returns {atk, def}.
static func pick_stats(uses: int, attacker: CombatantStats, target: CombatantStats, def_mult: float = 1.0) -> Dictionary:
	var atk: float
	var def: float
	match uses:
		TechDef.Uses.PHYSICAL:
			atk = attacker.p_atk
			def = target.p_def if target else 0.0
		TechDef.Uses.ELEMENTAL:
			atk = attacker.e_atk
			def = target.e_def if target else 0.0
		TechDef.Uses.ASTRAL:
			atk = (attacker.p_atk + attacker.e_atk) * 0.5
			def = (target.p_def + target.e_def) * 0.5 if target else 0.0
		_:
			if attacker.p_atk >= attacker.e_atk:
				atk = attacker.p_atk
				def = target.p_def if target else 0.0
			else:
				atk = attacker.e_atk
				def = target.e_def if target else 0.0
	return {"atk": atk, "def": def * def_mult}


## Resist factor for a hit against a shield's lists: 1.0 / 0.5 / 0.0 / -1.0.
static func resist_factor(hit_tags: Array, shield: ShieldComponent, target_stats: CombatantStats) -> float:
	if shield != null:
		for raw in hit_tags:
			var t: StringName = StringName(String(raw))
			if shield.absorbs.has(t):
				return -1.0
		for raw2 in hit_tags:
			var t2: StringName = StringName(String(raw2))
			if shield.immune.has(t2):
				return 0.0
		for raw3 in hit_tags:
			var t3: StringName = StringName(String(raw3))
			if shield.resists.has(t3):
				return CombatConstants.RESIST_MULT
	if target_stats != null and target_stats.is_resistant_to(hit_tags):
		return CombatConstants.RESIST_MULT
	return 1.0
