## Enemy decision making (Combat Laws Bible §3.5, §13). Picks one of the EnemyDef's actions
## and the battlers it aims at. Deterministic given the coordinator's RNG.
## Statuses read here (§7.3, §12, §12.2): Silence seals its techniques (a Silenced body makes a plain Attack);
## Jammed rules out wind-ups (a Jammed body whose every action winds up makes a plain Attack); GUILTY turns half its
## attacks on one of its own allies ("turned"); the action carries Probability Lock (consumed: the next action rolls
## twice, keeps the worse) and Refracted (its damage loses 20%) for EnemyStrike, and Knock-Static ("stepped": the
## action hitches) for the coordinator's wind-up, read when the action is chosen so a 2-turn status covers two
## actions.
class_name EnemyBrain
extends RefCounted

## Returns a normalized action: {id, name, tags, shape, radius, length, width, power, hits, wind_up_s,
## status, status_turns, status_seconds, target_rule, targets: Array[Node], aim: Vector3, heal, effect,
## turned, probability_lock, refracted, stepped}
static func choose(coord: BattleCoordinator, enemy: Node, def: EnemyDef, rng: RandomNumberGenerator) -> Dictionary:
	var stats := CombatantStats.of(enemy)
	var st := StatusComponent.of(enemy)
	var actions: Array = def.actions if def != null else []
	var pick: Dictionary = {}
	if actions.is_empty() or (st != null and not st.can_cast_techs()):
		pick = plain_attack(stats)  # Silence: its techniques are sealed, its Attack still works (§12)
	else:
		var jammed: bool = st != null and not st.can_wind_up()
		var ratio: float = stats.hp_ratio()
		# Strict first; then the cadence is relaxed, then the HP window; Jammed always rules out wind-ups.
		var usable: Array = _usable(coord, enemy, actions, ratio, jammed, true, true)
		if usable.is_empty():
			usable = _usable(coord, enemy, actions, ratio, jammed, true, false)
		if usable.is_empty():
			usable = _usable(coord, enemy, actions, ratio, jammed, false, false)
		if usable.is_empty():
			pick = plain_attack(stats)  # Jammed, and every action it has winds up (§12.2)
		else:
			var total: float = 0.0
			for a in usable:
				total += float(a.get("weight", 1.0))
			var roll: float = rng.randf() * maxf(0.0001, total)
			for a in usable:
				roll -= float(a.get("weight", 1.0))
				if roll <= 0.0:
					pick = a.duplicate(true)
					break
			if pick.is_empty():
				pick = usable[usable.size() - 1].duplicate(true)
	var out: Dictionary = {
		"id": String(pick.get("id", "attack")),
		"name": String(pick.get("name", pick.get("id", "Attack"))),
		"tags": pick.get("tags", Array(stats.weapon_tags)),
		"shape": String(pick.get("shape", "SINGLE")),
		"radius": float(pick.get("radius", 1.0)),
		"length": float(pick.get("length", 0.0)),
		"width": float(pick.get("width", 1.2)),
		"power": float(pick.get("power", 1.0)),
		"hits": int(pick.get("hits", 1)),
		"wind_up_s": float(pick.get("wind_up_s", 0.0)),
		"status": String(pick.get("status", "")),
		"status_turns": int(pick.get("status_turns", -1)),
		"status_seconds": float(pick.get("status_seconds", -1.0)),
		"status_chance": float(pick.get("status_chance", 1.0)),
		"target_rule": String(pick.get("target", "weakest")),
		"heal": float(pick.get("heal", 0.0)),
		"effect": String(pick.get("effect", "")),
		"bp_steal": int(pick.get("bp_steal", 0)),
		"self_target": bool(pick.get("self_target", false)),
		"uses": String(pick.get("uses", "BEST")),
	}
	if st != null:
		out["refracted"] = st.has(&"refracted")
		out["stepped"] = st.has(&"knock_static")  # every action of its turns hitches (§12.2)
		out["probability_lock"] = st.has(&"probability_lock")
		st.remove(&"probability_lock")
	var targets: Array = pick_targets(coord, enemy, out["target_rule"], rng)
	out["turned"] = not bool(out["self_target"]) and not targets.is_empty() and coord.enemies.has(targets[0])
	out["targets"] = targets
	out["aim"] = coord.position_of(targets[0]) if not targets.is_empty() else coord.position_of(enemy)
	if out["self_target"]:
		out["aim"] = coord.position_of(enemy)
	return out


## A plain Attack with the body's weapon tags: no wind-up, the weakest target.
static func plain_attack(stats: CombatantStats) -> Dictionary:
	return {"id": "attack", "name": "Attack", "tags": Array(stats.weapon_tags), "shape": "SINGLE", "power": 1.0, "hits": maxi(1, stats.weapon_hits), "wind_up_s": 0.0, "target": "weakest"}


## The actions open to `enemy` now: its HP window (`window`), its cadence (`cadence`), and no wind-up while
## it is Jammed.
static func _usable(coord: BattleCoordinator, enemy: Node, actions: Array, hp_ratio: float, jammed: bool, window: bool, cadence: bool) -> Array:
	var out: Array = []
	for a in actions:
		if window and (hp_ratio < float(a.get("min_hp_ratio", 0.0)) or hp_ratio > float(a.get("max_hp_ratio", 1.0))):
			continue
		var every: int = int(a.get("every_n_turns", 0))
		if cadence and every > 0 and (coord.turns_taken(enemy) + 1) % every != 0:
			continue
		if jammed and float(a.get("wind_up_s", 0.0)) > 0.0:
			continue
		out.append(a)
	return out


static func pick_targets(coord: BattleCoordinator, enemy: Node, rule: String, rng: RandomNumberGenerator) -> Array:
	# GUILTY (§12.2): half its attacks hit one of its own allies.
	var sc := StatusComponent.of(enemy)
	if sc != null and sc.has(&"guilty") and rng.randf() < CombatConstants.GUILTY_REDIRECT:
		var mates: Array = coord.targetable_enemies().filter(func(m: Node) -> bool: return m != enemy)
		if not mates.is_empty():
			return [mates[rng.randi_range(0, mates.size() - 1)]]
	var allies: Array = coord.targetable_party()
	if allies.is_empty():
		return []
	# Taunts override the rule: Shogun's Command binds 60% of attacks; Father Tank pulls Lavos-spawn.
	var taunter: Node = coord.current_taunter(enemy)
	if taunter != null and rng.randf() < coord.taunt_strength(taunter):
		return [taunter]
	match rule:
		"random":
			return [allies[rng.randi_range(0, allies.size() - 1)]]
		"strongest":
			var best: Node = allies[0]
			for a in allies:
				if CombatantStats.of(a).hp > CombatantStats.of(best).hp:
					best = a
			return [best]
		"crono", "sera", "krona", "cassia":
			for a in allies:
				if CombatantStats.of(a).actor_id == StringName(rule):
					return [a]
			return [allies[rng.randi_range(0, allies.size() - 1)]]
		"all":
			return allies
		"nearest":
			var near: Node = allies[0]
			var best_d: float = INF
			for a in allies:
				var d: float = coord.position_of(a).distance_to(coord.position_of(enemy))
				if d < best_d:
					best_d = d
					near = a
			return [near]
		_:
			var weakest: Node = allies[0]
			for a in allies:
				if CombatantStats.of(a).hp < CombatantStats.of(weakest).hp:
					weakest = a
			return [weakest]
