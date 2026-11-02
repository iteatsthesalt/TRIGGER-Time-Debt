## What a won battle pays, in one place (Combat Laws §5.2 Spare and Salvage, §13.1 Lean, §15.2 Experience;
## DECISIONS "Rewards: XP, drops and leans"). BattleCoordinator._finish merges resolve() into the summary on a
## victory; a defeat or a withdraw pays nothing.
## - XP: a defeated enemy (or a boss that ended its fight standing) pays its full reward, a spared one half;
##   the living party share all of it, the fallen and the bench 75%.
## - Drops: every defeated enemy rolls its EnemyDef.drops (`{"item", "chance", "count"}` or a bare id) into
##   Game.grant, which routes each item by its catalogue kind; the enemy key goes into Game.looted (kit `drop`
##   unlocks). A boss body is skipped: its BossController gives the boss file's drops through Game.grant when
##   the fight ends. Its adds are ordinary enemies.
## - Leans: an enemy resolved its codex signature way feeds that affinity (+1, capped +5 per universe,
##   Flags.add_lean): an L enemy when spared, a D enemy when salvaged (killed while Broken by a [RUIN] or [FERRO]
##   finisher) or incinerated (a [FIRE] finisher), a P enemy when a Dual or Triple finished it. An enemy with no
##   lean feeds what its resolution names. Bosses lean through their branches and directors.
class_name RewardResolver
extends RefCounted

const META_KO := &"reward_ko"  ## {broken: bool, tags: Array, tier: int} set while the battle runs


## Record how each enemy is finished (start_battle calls it; connects once per coordinator).
static func watch(c: BattleCoordinator) -> void:
	if c.has_meta(&"reward_watch"):
		return
	c.set_meta(&"reward_watch", true)
	c.unit_koed.connect(func(u: Node) -> void:
		if c.enemies.has(u) and is_instance_valid(u):
			u.set_meta(META_KO, {"broken": c.is_broken(u), "tags": [], "tier": -1}))
	c.strike_resolved.connect(func(_a: Node, t: Node, info: Dictionary) -> void:
		var ko: Dictionary = _ko(t)
		if not ko.is_empty() and (ko["tags"] as Array).is_empty() and not bool(info.get("friendly", false)):
			ko["tags"] = (info.get("tags", []) as Array).duplicate())
	c.action_executed.connect(func(info: Dictionary) -> void:
		var tech: Variant = info.get("tech", null)
		for t in info.get("targets", []):
			var ko: Dictionary = _ko(t)
			if not ko.is_empty() and int(ko["tier"]) < 0:
				ko["tier"] = (tech as TechDef).tier if tech is TechDef else TechDef.Tier.SINGLE)


static func _ko(u: Variant) -> Dictionary:
	if not (u is Node) or not is_instance_valid(u) or not (u as Node).has_meta(META_KO):
		return {}
	return (u as Node).get_meta(META_KO)


## {"xp": {actor_id: {xp, levels}}, "drops": [{item, n, kind, from}], "leans": [{key, lean}]}
static func resolve(c: BattleCoordinator) -> Dictionary:
	return {"xp": award_xp(c), "drops": award_drops(c), "leans": award_leans(c)}


static func award_xp(c: BattleCoordinator) -> Dictionary:
	var total: int = 0
	for e in c.enemies:
		var st := CombatantStats.of(e)
		if st == null:
			continue
		if c.spared.has(e):
			total += roundi(float(st.xp_reward) * 0.5)
		elif not st.is_alive() or e.has_meta(&"boss_defeated"):  # a boss that ends its fight standing (BossController.end_fight)
			total += st.xp_reward
	var out: Dictionary = {}
	for u in c.party:
		var st2 := CombatantStats.of(u)
		if st2 != null:
			var share: int = total if st2.is_alive() else roundi(float(total) * 0.75)
			out[st2.actor_id] = {"xp": share, "levels": st2.gain_xp(share)}
	for b in c.bench:
		var st3 := CombatantStats.of(b)
		if st3 != null:
			var share2: int = roundi(float(total) * 0.75)
			out[st3.actor_id] = {"xp": share2, "levels": st3.gain_xp(share2)}
	return out


## A drop list as [{item, chance, count}] (a bare string is one certain drop), the one shape for enemy and
## boss files alike.
static func normalize(drops: Array) -> Array:
	var out: Array = []
	for d in drops:
		if d is Dictionary:
			out.append({"item": String(d.get("item", "")), "chance": float(d.get("chance", 1.0)), "count": int(d.get("count", 1))})
		elif d is String or d is StringName:
			out.append({"item": String(d), "chance": 1.0, "count": 1})
	return out


## Roll `drops` with `rng` and give what lands; returns [{item, n, kind}].
static func give(drops: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	for d in normalize(drops):
		if String(d["item"]) == "" or rng.randf() >= float(d["chance"]):
			continue
		var kind: StringName = Game.grant(StringName(String(d["item"])), int(d["count"]))
		out.append({"item": d["item"], "n": d["count"], "kind": kind})
	return out


static func award_drops(c: BattleCoordinator) -> Array:
	var out: Array = []
	for e in c.enemies:
		var st := CombatantStats.of(e)
		if st == null or st.is_alive() or c.spared.has(e) or (e as Node).has_meta("boss_id"):
			continue
		var def: EnemyDef = c.enemy_defs.get(st.actor_id, null)
		if def == null or def.drops.is_empty():
			continue
		for g in give(def.drops, c.rng):
			g["from"] = String(def.key)
			out.append(g)
		Game.note_drop(def.key)
	return out


## The lean an enemy's resolution names: "L" spared, "D" salvaged or incinerated, "P" a Dual/Triple finish, ""
## for anything else (a plain kill, a DoT, a field).
static func resolution(c: BattleCoordinator, e: Node) -> String:
	if c.spared.has(e):
		return "L"
	var ko: Dictionary = _ko(e)
	if ko.is_empty():
		return ""
	var tier: int = int(ko["tier"])
	if tier == TechDef.Tier.DUAL or tier == TechDef.Tier.TRIPLE:
		return "P"
	var tags: Array = ko["tags"]
	if tags.has(&"FIRE") or (bool(ko["broken"]) and (tags.has(&"RUIN") or tags.has(&"FERRO"))):
		return "D"
	return ""


static func award_leans(c: BattleCoordinator) -> Array:
	var out: Array = []
	for e in c.enemies:
		var st := CombatantStats.of(e)
		if st == null or (e as Node).has_meta("boss_id"):
			continue
		var how: String = resolution(c, e)
		if how == "":
			continue
		var def: EnemyDef = c.enemy_defs.get(st.actor_id, null)
		var lean: String = def.lean.left(1).to_upper() if def != null else ""
		if lean != "" and lean != how:
			continue
		Flags.add_lean(c.universe, how)
		out.append({"key": String(st.actor_id), "lean": how})
	return out
