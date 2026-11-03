## The technique effect table (data/effects/effects.json; DECISIONS "Effect table"): a row describes an `effect`
## as data (conditions, damage and shave modifiers, ops after the hit) so most techniques need no code of their
## own. This class reads the rows Data loaded, validates them against the techniques, answers the questions the
## pipeline asks before a hit (availability, damage multiplier, shave bonus, no-shave) and evaluates conditions.
## EffectSteps runs a row's ops; TechEffects keeps the bespoke handlers; EnemyEffects the enemy action effects.
class_name EffectTable
extends RefCounted

## Every op a row may use (EffectSteps / EffectOps); `pre` ops change the action before it resolves.
const OPS: Array[String] = [
	"status", "heal", "heal_dealt", "field", "convert_field", "bp", "gauge", "lock", "delay_rebuild", "whiteout",
	"hide_weakness", "grant_weakness", "strip_resists", "purge_buff", "steal_buff", "steal", "cleanse", "strain",
	"integrity", "reinforced", "affinity", "flag", "solidity", "shutdown", "hurt_allies", "pull", "leap", "plates",
	"unshare", "auto_break", "shave_any", "sever_tethers", "spend_stacks", "rift_after", "mines", "rewind_enemies",
	"thaw_ruin",
]
const PRE_OPS: Array[String] = ["hits", "spend_stacks"]
## Every condition key (`if` of an op, a `mult` or a `shave` entry).
const CONDITIONS: Array[String] = [
	"any", "min_boost", "caster", "target_metal", "target_boss", "target_tag", "target_ids", "target_status",
	"target_weak_all", "matches_revealed", "broke", "target_broken", "caster_hp_below", "crono_cracked",
	"crono_galaxy", "tuned", "sunlight", "allies_status", "flag", "flag_not", "universe", "universe_not", "light_min",
	"synergy_min",
]
## Every availability key (`requires`).
const REQUIRES: Array[String] = ["once_per_battle", "crono_hp_max", "enemy_ids", "caster_stacks", "bp_min", "light_min", "flag", "flag_not"]
## Statuses that are buffs (purged, stolen; not counted as debuffs).
const BUFFS: Array[StringName] = [
	&"haste", &"regen", &"ward", &"glass_ward", &"prism_guard", &"divinity", &"repainted", &"rage", &"ruin_infused",
	&"phase_evasion", &"light_stack", &"core_lattice", &"rose_window", &"null_shield", &"astral_field", &"balloon",
]
## Statuses that are debuffs (§12.2): 56k Prayer's +15% counts these on its target.
const DEBUFFS: Array[StringName] = [
	&"blind", &"ink_blot", &"white_noise_blind", &"mercury_slow", &"grief", &"ruin", &"corroded", &"magnetized",
	&"displaced", &"probability_lock", &"spore_tag", &"refracted", &"guilty", &"jammed", &"stripped", &"confuse",
	&"time_stop", &"chrono_lag", &"knock_static", &"silence", &"fragile", &"sticky_ash", &"ash_inhale", &"slow",
	&"burn", &"bleed", &"oil_dot", &"ink_dot", &"hitched", &"scrambled", &"decoyed", &"mirrored", &"exposed",
	&"time_lapse", &"nulled",
]
const META_USED := &"effects_used"


static func rows() -> Dictionary:
	return Data.effects.get("techs", {})


static func row(effect: StringName) -> Dictionary:
	return rows().get(String(effect), {})


static func has_row(effect: StringName) -> bool:
	return effect != &"" and rows().has(String(effect))


## True when `effect` is accounted for: a bespoke handler, a row, or listed as flavour or pending.
static func known(effect: StringName) -> bool:
	return TechEffects.HANDLED.has(effect) or has_row(effect) or Data.effects.get("flavour", {}).has(String(effect)) \
		or is_pending(effect)


## The effect is listed as pending: nothing runs it yet, so its technique is never offered (BattleCoordinator's
## knows-check) and strikes nothing (CastReach.strikes), instead of resolving as a plain strike or heal.
static func is_pending(effect: StringName) -> bool:
	return effect != &"" and Data.effects.get("pending", {}).has(String(effect))


## Problems in the table and in the techniques' effect ids (Data.load_all appends them; lint_data.py mirrors it).
static func validation_errors(techs: Dictionary, table: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var t_rows: Dictionary = table.get("techs", {})
	var listed: Dictionary = {}
	for group in ["flavour", "pending"]:
		for id in (table.get(group, {}) as Dictionary).keys():
			listed[id] = group
	for id in (table.get("pending", {}) as Dictionary).keys():
		if TechEffects.HANDLED.has(StringName(id)):
			errors.append("effects: %s has a bespoke handler and is listed as pending (its waiting clauses go under handler_unbuilt)" % id)
	for id in (table.get("handler_unbuilt", {}) as Dictionary).keys():
		if not TechEffects.HANDLED.has(StringName(id)):
			errors.append("effects: handler_unbuilt lists %s, which has no bespoke handler" % id)
	for id in t_rows.keys():
		if TechEffects.HANDLED.has(StringName(id)):
			errors.append("effects: %s has a bespoke handler and a row" % id)
		if listed.has(id):
			errors.append("effects: %s has a row and is listed as %s" % [id, listed[id]])
		errors.append_array(row_errors(String(id), t_rows[id]))
	for tid in techs.keys():
		var eff: StringName = (techs[tid] as TechDef).effect
		if eff == &"" or TechEffects.HANDLED.has(eff) or t_rows.has(String(eff)) or listed.has(String(eff)):
			continue
		errors.append("tech %s: effect %s has no handler, no row and is not listed as flavour or pending" % [tid, eff])
	return errors


## Every enemy and boss action `effect` is an EnemyEffects arm, a summon, or listed under `enemy_pending`.
static func enemy_errors(enemies: Dictionary, bosses: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for k in enemies.keys():
		for a in (enemies[k] as EnemyDef).actions:
			if not EnemyEffects.known(String(a.get("effect", ""))):
				errors.append("enemy %s action %s: effect %s has no handler and is not listed as pending" % [k, a.get("id", "?"), a["effect"]])
	for b in bosses.keys():
		for ph in bosses[b].get("phases", []):
			for a2 in ph.get("actions", []):
				if not EnemyEffects.known(String(a2.get("effect", ""))):
					errors.append("boss %s action %s: effect %s has no handler and is not listed as pending" % [b, a2.get("id", "?"), a2["effect"]])
	return errors


static func row_errors(id: String, r: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not (r is Dictionary):
		return PackedStringArray(["effects: %s is not an object" % id])
	var d: Dictionary = r
	for k in (d.get("requires", {}) as Dictionary).keys():
		if not REQUIRES.has(String(k)):
			errors.append("effects: %s requires unknown %s" % [id, k])
	for op in d.get("pre", []):
		if not PRE_OPS.has(String(op.get("op", ""))):
			errors.append("effects: %s has unknown pre op %s" % [id, op.get("op", "")])
		errors.append_array(_cond_errors(id, op.get("if", {})))
	for op in d.get("after", []):
		if not OPS.has(String(op.get("op", ""))):
			errors.append("effects: %s has unknown op %s" % [id, op.get("op", "")])
		if op.has("kind") and not BattleFields.KINDS.has(StringName(String(op["kind"]))):
			errors.append("effects: %s field op has unknown kind %s" % [id, op["kind"]])
		errors.append_array(_cond_errors(id, op.get("if", {})))
	for m in d.get("mult", []) + d.get("shave", []):
		errors.append_array(_cond_errors(id, m.get("if", {})))
	if String(d.get("resolve", "damage")) not in ["damage", "support", "none"]:
		errors.append("effects: %s resolve must be damage, support or none" % id)
	return errors


## The flag references a row names, each as Data.load_all validates it (FlagRef.error): the `flag` / `flag_not`
## conditions of its `requires`, `pre`, `after`, `mult` and `shave` (inside `any` too) as written, and each `flag`
## op's `set` as the state it writes (FlagRef.written: a bare name writes "set").
static func flag_refs(r: Dictionary) -> Array[String]:
	var out: Array[String] = []
	_cond_flags(r.get("requires", {}), out)
	for group in ["pre", "after", "mult", "shave"]:
		for entry in r.get(group, []):
			if entry is Dictionary:
				_cond_flags(entry.get("if", {}), out)
				if group == "after" and String(entry.get("op", "")) == "flag":
					out.append(FlagRef.written(String(entry.get("set", ""))))
	return out


static func _cond_flags(cond: Variant, out: Array[String]) -> void:
	if not (cond is Dictionary):
		return
	for k in (cond as Dictionary).keys():
		if String(k) in ["flag", "flag_not"]:
			out.append(String(cond[k]))
		elif String(k) == "any":
			for sub in cond[k]:
				_cond_flags(sub, out)


static func _cond_errors(id: String, cond: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not (cond is Dictionary):
		return PackedStringArray(["effects: %s condition is not an object" % id])
	for k in (cond as Dictionary).keys():
		if not CONDITIONS.has(String(k)):
			errors.append("effects: %s uses unknown condition %s" % [id, k])
		elif String(k) == "any":
			for sub in cond[k]:
				errors.append_array(_cond_errors(id, sub))
	return errors


# ---------------------------------------------------------------- before the hit

## The technique may be offered to `actor` now (the row's `requires`; the coordinator's knows-check asks).
static func requirements_met(c: BattleCoordinator, actor: Node, tech: TechDef) -> bool:
	if tech == null or not has_row(tech.effect):
		return true
	var req: Dictionary = row(tech.effect).get("requires", {})
	for k in req.keys():
		var v: Variant = req[k]
		match String(k):
			"once_per_battle":
				if bool(v) and used(c, tech.effect):
					return false
			"crono_hp_max":
				var crono: Node = c.unit_by_id(&"crono")
				var cst := CombatantStats.of(crono)
				if cst == null or float(cst.hp) / float(maxi(1, cst.base_max_hp)) > float(v):
					return false
			"enemy_ids":
				if c.living_enemies().filter(func(e: Node) -> bool: return id_matches(CombatantStats.of(e).actor_id, v)).is_empty():
					return false
			"caster_stacks":
				var sc := StatusComponent.of(actor)
				for sid in (v as Dictionary).keys():
					if sc == null or sc.stacks(StringName(String(sid))) < int(v[sid]):
						return false
			"bp_min":
				if c.bank.bp < int(v):
					return false
			_:
				if not holds({k: v}, {"c": c, "tech": tech, "casters": [actor], "attacker": actor, "boost": 0}):
					return false
	return true


## The damage multiplier the row gives one target (the resolution's PartyHit.context and the preview read it).
static func damage_mult(c: BattleCoordinator, tech: TechDef, boost: int, target: Node) -> float:
	if tech == null or target == null or not has_row(tech.effect):
		return 1.0
	var r: Dictionary = row(tech.effect)
	var ctx := {"c": c, "tech": tech, "boost": boost, "casters": casters_of(c, tech), "attacker": null}
	var m: float = 1.0
	for entry in r.get("mult", []):
		if holds(entry.get("if", {}), ctx, target):
			m *= float(entry.get("x", 1.0))
	if r.has("per_debuff"):
		m *= 1.0 + float(r["per_debuff"]) * float(debuff_count(target))
	return m


## The flat shave bonus the row gives one target (ShaveBonus.against: the preview and the resolution alike).
static func shave_bonus(c: BattleCoordinator, tech: TechDef, boost: int, target: Node) -> int:
	if tech == null or target == null or not has_row(tech.effect):
		return 0
	var ctx := {"c": c, "tech": tech, "boost": boost, "casters": casters_of(c, tech), "attacker": null}
	var b: int = 0
	for entry in row(tech.effect).get("shave", []):
		if holds(entry.get("if", {}), ctx, target):
			b += int(entry.get("n", 0)) + int(entry.get("per_hit", 0)) * tech.hit_count
	return b


## Mycelia Time Lapse "shaves nothing" (ShaveBonus.penalty).
static func shaves_nothing(tech: TechDef) -> bool:
	return tech != null and bool(row(tech.effect).get("no_shave", false))


## A received hit's context after the statuses rows leave on a target: The Last Joke's crack (the next hits
## ignore DEF, one stack per hit) and the Gold Leaf washi pocket (every party hit is true damage). `spend`: the hit
## lands and spends its stack (PartyHit.terms reads without it); `ahead`: hits before this one not yet landed (the
## preview's later hits), so a 3-stack crack bares DEF to three of them.
static func adjust_hit(ctx: Dictionary, tsc: StatusComponent, spend: bool = true, ahead: int = 0) -> void:
	if tsc == null:
		return
	if tsc.has(&"washi_pocket"):  # TRUE NULL for the pocket (§12.4): no DEF, no resistance, no weakness multiplier
		ctx["def"] = 0.0
		ctx["resist"] = 1.0
		ctx["weakness"] = false
	if tsc.stacks(&"exposed") > ahead:
		ctx["def"] = 0.0
	if spend:
		spend_hit(tsc)


## A hit landed on the bearer: The Last Joke's crack loses one stack (PartyHit.context, after its `terms`).
static func spend_hit(tsc: StatusComponent) -> void:
	if tsc != null and tsc.has(&"exposed"):
		tsc.remove_stacks(&"exposed", 1)


# ---------------------------------------------------------------- conditions

## True when every key of `cond` holds. ctx: {c, tech, boost, casters, attacker, info, action}; `t` the target.
static func holds(cond: Dictionary, ctx: Dictionary, t: Node = null) -> bool:
	for k in cond.keys():
		if not _holds_one(String(k), cond[k], ctx, t):
			return false
	return true


static func _holds_one(k: String, v: Variant, ctx: Dictionary, t: Node) -> bool:
	var c: BattleCoordinator = ctx["c"]
	var tst := CombatantStats.of(t) if t != null else null
	match k:
		"any":
			for sub in v:
				if holds(sub, ctx, t):
					return true
			return false
		"min_boost":
			return int(ctx.get("boost", 0)) >= int(v)
		"caster":
			for u in ctx.get("casters", []):
				if is_instance_valid(u) and CombatantStats.of(u).actor_id == StringName(String(v)):
					return true
			return false
		"target_metal":
			return t != null and c._is_metal(t) == bool(v)
		"target_boss":
			return tst != null and (tst.kind == "boss") == bool(v)
		"target_tag":
			return tst != null and tst.tags.has(StringName(String(v)))
		"target_ids":
			return tst != null and id_matches(tst.actor_id, v)
		"target_status":
			var sc := StatusComponent.of(t)
			return sc != null and sc.has(StringName(String(v)))
		"target_weak_all":
			var sh := ShieldComponent.of(t)
			if sh == null:
				return false
			for tag in v:
				if not sh.weaknesses.has(StringName(String(tag))):
					return false
			return true
		"matches_revealed":
			var sh2 := ShieldComponent.of(t)
			var tech: TechDef = ctx.get("tech", null)
			if sh2 == null or tech == null:
				return false
			for tag in tech.tags:
				if sh2.weaknesses.has(tag) and sh2.is_revealed(tag):
					return bool(v)
			return not bool(v)
		"broke":
			return (ctx.get("info", {}).get("breaks", []) as Array).has(t) == bool(v)
		"target_broken":
			return t != null and c.is_broken(t) == bool(v)
		"caster_hp_below":
			var ast := CombatantStats.of(ctx.get("attacker", null))
			return ast != null and ast.hp_ratio() < float(v)
		"crono_cracked", "crono_galaxy":
			var crono: Node = c.unit_by_id(&"crono")
			var td := TimeDebtComponent.of(crono)
			if td == null:
				return not bool(v)
			var cst := CombatantStats.of(crono)
			var state: bool = c._crono_galaxy(crono) if k == "crono_galaxy" else td.is_hairline_or_worse(float(cst.hp) / float(maxi(1, cst.base_max_hp)))
			return state == bool(v)
		"tuned":
			var stat: Node = c.unit_by_id(&"static")
			var mode: String = String(stat.get_meta("tuning", "")) if stat != null else ""
			if v is bool:
				return (mode != "") == bool(v)
			return mode == String(v)
		"sunlight":
			var xy: Node = c.unit_by_id(&"xyloph")
			return xy != null and int(xy.get_meta("sunlight", 0)) >= int(v)
		"allies_status":
			for u in c.party:
				var usc := StatusComponent.of(u)
				if usc != null and usc.has(StringName(String(v))):
					return true
			return false
		"flag", "flag_not":
			var on: bool = Flags.holds(String(v))  # "Name" (set, any state) or "Name:State" (FlagRef)
			return on if k == "flag" else not on
		"universe":
			return c.universe == int(v)
		"universe_not":
			return c.universe != int(v)
		"light_min":
			return Flags.light >= int(v)
		"synergy_min":
			return float(ctx.get("action", {}).get("synergy", 0.0)) >= float(v)
	push_warning("EffectTable: unknown condition %s" % k)
	return false


# ---------------------------------------------------------------- helpers

## `id` matches one of `patterns` (a pattern ending in * is a prefix).
static func id_matches(id: StringName, patterns: Variant) -> bool:
	for p in patterns:
		var s: String = String(p)
		if s.ends_with("*") and String(id).begins_with(s.trim_suffix("*")):
			return true
		if String(id) == s:
			return true
	return false


## The technique's actors as they stand in this battle (conditions about "the casters" read every actor, so
## the preview, which knows only the acting ally, agrees with the resolution).
static func casters_of(c: BattleCoordinator, tech: TechDef) -> Array:
	var out: Array = []
	for id in tech.actors:
		var u: Node = c.unit_by_id(id)
		if u != null:
			out.append(u)
	return out


static func debuff_count(t: Node) -> int:
	var sc := StatusComponent.of(t)
	if sc == null:
		return 0
	var n: int = 0
	for id in sc.ids():
		if DEBUFFS.has(id):
			n += 1
	return n


## Once-per-battle bookkeeping on the coordinator, cleared when the battle ends.
static func used(c: BattleCoordinator, key: StringName) -> bool:
	return (c.get_meta(META_USED, {}) as Dictionary).has(key)


static func mark_used(c: BattleCoordinator, key: StringName) -> void:
	var d: Dictionary = c.get_meta(META_USED, {})
	if d.is_empty():
		c.battle_ended.connect(func(_v: bool, _s: Dictionary) -> void: c.remove_meta(META_USED), CONNECT_ONE_SHOT)
	d[key] = true
	c.set_meta(META_USED, d)
