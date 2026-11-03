## Brings summoned enemies into a running battle: one rule for every summoner, a boss placing its phase adds
## or a regular enemy casting `summon:<key>` (TechEffects). The cap is the summoner's own: `max_adds` in its
## definition (the boss file, or the enemy's entry), default 3, never more than that many of one kind standing
## beside it at once, since summoners re-cast every few turns. A scaled summoner's adds fight at the rank its
## encounter gives them (EffectiveRank.create_summoned); a boss's keep their authored level. The newcomers ring the
## summoner on ground a body can stand on (the battle's WalkableGround: never inside a pillar or over the void),
## face the party's side (BattleScene.party_side, which PartyPlacement may have turned), join the coordinator and get
## a Turn-Bar marker and a plate.
class_name EnemySpawner
extends RefCounted

const DEFAULT_MAX_ADDS := 3
## The ring: the k-th newcomer stands RING_M + RING_STEP_M * k from the summoner (DECISIONS "One summon rule").
const RING_M := 1.8
const RING_STEP_M := 0.4
## The angles a ring spot is tried at, from its random start, before it falls back to the summoner's own spot.
const RING_TRIES := 8


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
		a.global_position = ring_spot(c.ground, base, RING_M + RING_STEP_M * float(k), randf() * TAU)
		a.reset_physics_interpolation()
		a.face_toward(scene.center + scene.party_side * 4.0)  # as BattleScene faces the enemies it opens with
		scene.enemies.append(a)
		c.add_enemy(a, edef)
		scene.hud.register_enemy(a)
		a.sprite.play(&"revive", &"idle")
		out.append(a)
	return out


## A spot `radius` from `base` a body can stand on: the ring at `start_ang`, then RING_TRIES - 1 more angles round
## it; with no ground (a headless test) the first; when none holds, the summoner's own spot (on the ground when
## it can stand there).
static func ring_spot(ground: WalkableGround, base: Vector3, radius: float, start_ang: float) -> Vector3:
	for i in RING_TRIES:
		var ang: float = start_ang + TAU * float(i) / float(RING_TRIES)
		var p: Vector3 = base + Vector3(cos(ang), 0.0, sin(ang)) * radius
		if ground == null:
			return p
		var spot: Variant = ground.stand_at(p)
		if spot is Vector3:
			return spot
	var own: Variant = ground.stand_at(base)
	return own if own is Vector3 else base
