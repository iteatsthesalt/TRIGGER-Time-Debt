## The autobattle brain the probes and `--autobattle` use: one party decision per window, from the
## BattleScene's point of view (its coordinator, its acting actor, its boss). Moved out of BattleScene so
## the scene stays glue; it is not an AI the shipped game exposes (the enemy brain is EnemyBrain).
class_name AutoBattler
extends RefCounted

## Shapes that can catch more than one enemy in a single cast.
const MULTI_SHAPES: Array[int] = [
	TechDef.Shape.LINE_PIERCE, TechDef.Shape.CONE, TechDef.Shape.CIRCLE, TechDef.Shape.CROSS,
	TechDef.Shape.DELTA, TechDef.Shape.SPLIT_CONE,
]


static func act(scene: BattleScene) -> void:
	var c: BattleCoordinator = scene.coordinator
	var actor: CombatActor = scene.actor
	var living: Array = c.living_enemies()
	if living.is_empty():
		return
	if scene.boss != null and scene.boss.is_sealed() and actor.time_debt != null:
		scene._on_deck_command("pay_debt", {})
		return
	scene.auto_timer = 0.15
	if actor == scene.roster.hover:
		c.cmd_guard(actor)  # hover Sera waits on the Turn Bar; her daggers are a player's call
		return
	var targetable: Array = living.filter(func(e: Node) -> bool: return not c._untargetable(e))
	if targetable.is_empty():
		c.cmd_guard(actor)
		return
	# heal when someone is low and a healing item is on hand
	var low: Node = null
	for u in c.party:
		var st := CombatantStats.of(u)
		if st != null and st.is_alive() and st.hp_ratio() < 0.35:
			low = u
	if low != null and int(Game.inventory.get(&"tonic", 0)) > 0 and randf() < 0.7:
		if Game.take_item(&"tonic"):
			c.cmd_item(actor, Data.items[&"tonic"], low)
			return
	# focus fire: unbroken targets first, lowest plates first
	targetable.sort_custom(func(a: Node, b: Node) -> bool:
		var sa := ShieldComponent.of(a)
		var sb := ShieldComponent.of(b)
		var ka: int = (1000 if sa != null and sa.is_broken else 0) + (sa.current_shield if sa != null else 0)
		var kb: int = (1000 if sb != null and sb.is_broken else 0) + (sb.current_shield if sb != null else 0)
		return ka < kb)
	var t: Node = targetable[0] if randf() < 0.8 else targetable[randi() % targetable.size()]
	var techs: Array[TechDef] = c.available_techs(actor).filter(func(x: TechDef) -> bool: return x.is_attack and x.target in ["enemy", "point"] and x.effect == &"")
	var b: int = mini(c.bank.bp, randi() % 3)
	if not techs.is_empty() and randf() < 0.6:
		var tech: TechDef = pick_tech(techs, targetable)
		var r: Dictionary = c.cmd_tech(actor, tech.id, t, c.position_of(t), b, c.partners_for(tech, actor))
		if bool(r.get("ok", false)):
			actor.sprite.play(&"attack", &"ready")
			return
	actor.sprite.play(&"attack", &"ready")
	var r2: Dictionary = c.cmd_attack(actor, t, b)
	if not bool(r2.get("ok", true)):
		c.cmd_guard(actor)


## Which of the actor's attack techs the autobattle casts this turn. `techs` are the castable attacks,
## `targetable` the enemies that can be hit right now (the 999 Shard Doll's split puts three up at once).
## With several enemies up it takes the multi-target tech whose tags hit the most weaknesses, so a split
## of dolls sharing a weakness is lined up rather than chipped one at a time; two casts in five stay
## random so fights keep some variety.
static func pick_tech(techs: Array[TechDef], targetable: Array) -> TechDef:
	if targetable.size() < 2 or randf() < 0.4:
		return techs[randi() % techs.size()]
	var best: TechDef = null
	var best_hits: int = 1
	for tech in techs:
		if not MULTI_SHAPES.has(tech.shape):
			continue
		var hits: int = 0
		for e in targetable:
			var sh := ShieldComponent.of(e)
			if sh != null and sh.hits_weakness(tech.tags):
				hits += 1
		if hits > best_hits:
			best_hits = hits
			best = tech
	return best if best != null else techs[randi() % techs.size()]
