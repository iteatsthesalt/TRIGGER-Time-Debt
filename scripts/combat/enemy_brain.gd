## Enemy decision making (Combat Laws Bible §3.5, §13). Picks one of the EnemyDef's actions
## and the battlers it aims at. Deterministic given the coordinator's RNG.
class_name EnemyBrain
extends RefCounted

## Returns a normalized action: {id, name, tags, shape, radius, length, width, power, hits, wind_up_s,
## status, status_turns, status_seconds, target_rule, targets: Array[Node], aim: Vector3, heal, effect}
static func choose(coord: BattleCoordinator, enemy: Node, def: EnemyDef, rng: RandomNumberGenerator) -> Dictionary:
	var stats := CombatantStats.of(enemy)
	var actions: Array = def.actions if def != null else []
	var pick: Dictionary = {}
	if actions.is_empty():
		pick = {"id": "attack", "name": "Attack", "tags": Array(stats.weapon_tags), "shape": "SINGLE", "power": 1.0, "hits": maxi(1, stats.weapon_hits), "wind_up_s": 0.0, "target_rule": "weakest"}
	else:
		var usable: Array = []
		var total: float = 0.0
		var hp_ratio: float = stats.hp_ratio()
		for a in actions:
			var min_hp: float = float(a.get("min_hp_ratio", 0.0))
			var max_hp: float = float(a.get("max_hp_ratio", 1.0))
			if hp_ratio < min_hp or hp_ratio > max_hp:
				continue
			var every: int = int(a.get("every_n_turns", 0))
			if every > 0:
				var turns: int = coord.turns_taken(enemy)
				if (turns + 1) % every != 0:
					continue
			var st := StatusComponent.of(enemy)
			if float(a.get("wind_up_s", 0.0)) > 0.0 and st != null and not st.can_wind_up():
				continue
			usable.append(a)
			total += float(a.get("weight", 1.0))
		if usable.is_empty():
			usable = actions.duplicate()
			total = 0.0
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
	var targets: Array = pick_targets(coord, enemy, out["target_rule"], rng)
	out["targets"] = targets
	out["aim"] = coord.position_of(targets[0]) if not targets.is_empty() else coord.position_of(enemy)
	if out["self_target"]:
		out["aim"] = coord.position_of(enemy)
	return out


static func pick_targets(coord: BattleCoordinator, enemy: Node, rule: String, rng: RandomNumberGenerator) -> Array:
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
