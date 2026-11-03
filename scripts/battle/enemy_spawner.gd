## Brings summoned enemies into a running battle: one rule for every summoner, a boss placing its phase adds
## or a regular enemy casting `summon:<key>` (TechEffects). The cap is the summoner's own: `max_adds` in its
## definition (the boss file, or the enemy's entry), default 3, never more than that many of one kind standing
## beside it at once, since summoners re-cast every few turns. A scaled summoner's adds fight at the rank its
## encounter gives them (EffectiveRank.create_summoned); a boss's keep their authored level. The newcomers ring the
## summoner, face the party, join the coordinator and get a Turn-Bar marker and a plate.
class_name EnemySpawner
extends RefCounted

const DEFAULT_MAX_ADDS := 3


## A summoner's cap from its raw definition.
static func max_adds_of(raw: Dictionary) -> int:
	return int(raw.get("max_adds", DEFAULT_MAX_ADDS))


## The cap of the body that cast the summon: its EnemyDef's `max_adds`, else the default.
static func cap_of(summoner: Node) -> int:
	if summoner is CombatActor and (summoner as CombatActor).def != null:
		return max_adds_of((summoner as CombatActor).def.raw)
	return DEFAULT_MAX_ADDS


## How many of `count` more `key` may join while `summoner` stands with `cap` as its limit.
static func allowed(c: BattleCoordinator, key: StringName, summoner: Node, count: int, cap: int) -> int:
	var standing: int = 0
	for e in c.living_enemies():
		if e != summoner and CombatantStats.of(e).actor_id == key:
			standing += 1
	return mini(count, maxi(0, cap - standing))


## Spawn up to `count` of `edef` around `near` (within the cap) into `scene`. Returns the new bodies.
static func spawn(scene: BattleScene, edef: EnemyDef, near: Node, count: int, cap: int, tag: String = "sum") -> Array[CombatActor]:
	var out: Array[CombatActor] = []
	var c: BattleCoordinator = scene.coordinator
	var n: int = allowed(c, edef.key, near, count, cap)
	var base: Vector3 = c.position_of(near) if near != null else c.arena_center
	for k in n:
		var a: CombatActor = EffectiveRank.create_summoned(edef, near, "_%s%d" % [tag, k + 10 * (randi() % 1000)])  # §15.3
		scene.get_parent().add_child(a)
		var ang: float = randf() * TAU
		a.global_position = base + Vector3(cos(ang), 0.0, sin(ang)) * (1.8 + 0.4 * float(k))
		a.face_toward(c.arena_center + Vector3(0, 0, 4))
		scene.enemies.append(a)
		c.add_enemy(a, edef)
		scene.hud.register_enemy(a)
		a.sprite.play(&"revive", &"idle")
		out.append(a)
	return out
