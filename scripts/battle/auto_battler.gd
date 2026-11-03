## The autobattle brain the probes and `--autobattle` use: one party decision per window, from the
## BattleScene's point of view (its coordinator, its acting actor, its boss). Moved out of BattleScene so
## the scene stays glue; it is not an AI the shipped game exposes (the enemy brain is EnemyBrain).
## Besides Attack, attack techs, Guard and a Tonic it sometimes casts the party's effect techs where they are
## safe and useful (EFFECT_USES), boosts to the bank's limit one window in four and takes a Sync Hold when a
## partner can relieve it, so a green probe also runs TechEffects.apply, the Lv3 shave and the Ready Pool.
## Every decision is tallied and report() prints the tally when the battle ends ("AUTOBATTLE ..." lines).
class_name AutoBattler
extends RefCounted

## Shapes that can catch more than one enemy in a single cast.
const MULTI_SHAPES: Array[int] = [
	TechDef.Shape.LINE_PIERCE, TechDef.Shape.CONE, TechDef.Shape.CIRCLE, TechDef.Shape.CROSS,
	TechDef.Shape.DELTA, TechDef.Shape.SPLIT_CONE,
]
## Effect techs the autobattle may cast, by the target that makes each worth it: "unbroken" an enemy with its
## plates up, "broken" a Broken enemy, "hurt" an ally under 50% HP, "rewindable" an ally whose last turn start
## had 20%+ more HP than now, "ally" any living ally. Anything not listed (costly or story-bound) is never cast.
const EFFECT_USES: Dictionary = {
	&"tachyon_needle": "unbroken", &"hold": "broken", &"rewind": "rewindable", &"ward": "hurt",
	&"fall_break": "ally",
}
## Chances per window: an effect tech when one has a target, a full Boost, a Sync Hold.
const EFFECT_CHANCE := 0.3
const FULL_BOOST_CHANCE := 0.25
const SYNC_HOLD_CHANCE := 0.1

## Decisions taken since the last report(): "attack", "tech:<id>", "guard", "item:<id>", "pay_debt",
## "sync_hold", "boost<n>".
static var tally: Dictionary = {}


static func act(scene: BattleScene) -> void:
	var c: BattleCoordinator = scene.coordinator
	var actor: CombatActor = scene.actor
	if c.living_enemies().is_empty():
		return
	if SealPayment.offered(scene, actor):
		_note("pay_debt")
		scene._on_deck_command("pay_debt", {})
		return
	scene.auto_timer = 0.15
	if actor == scene.roster.hover:
		_guard(c, actor)  # hover Sera waits on the Turn Bar; her daggers are a player's call
		return
	var targetable: Array = c.targetable_enemies()
	if targetable.is_empty():
		_guard(c, actor)
		return
	# heal when someone is low and a healing item is on hand
	var low: Node = null
	for u in c.party:
		var st := CombatantStats.of(u)
		if st != null and st.is_alive() and st.hp_ratio() < 0.35:
			low = u
	if low != null and int(Game.inventory.get("tonic", 0)) > 0 and randf() < 0.7:
		if bool(BattleDeck.use_item(c, actor, Data.items[&"tonic"], low).get("ok", false)):
			_note("item:tonic")
			return
	if randf() < EFFECT_CHANCE and _cast_effect(c, actor, targetable):
		return
	if randf() < SYNC_HOLD_CHANCE and SyncHoldRules.can_hold(c, actor) and bool(c.cmd_sync_hold(actor).get("ok", false)):
		_note("sync_hold")
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
	var b: int = mini(c.bank.bp, c.bank.max_spend if randf() < FULL_BOOST_CHANCE else randi() % 3)
	if not techs.is_empty() and randf() < 0.6:
		var tech: TechDef = pick_tech(techs, targetable)
		var r: Dictionary = c.cmd_tech(actor, tech.id, t, c.position_of(t), b, c.partners_for(tech, actor))
		if bool(r.get("ok", false)):
			actor.sprite.play(&"attack", &"ready")
			_note("tech:%s" % tech.id, b)
			return
	actor.sprite.play(&"attack", &"ready")
	if bool(c.cmd_attack(actor, t, b).get("ok", false)):
		_note("attack", b)
	else:
		_guard(c, actor)


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


## The first known EFFECT_USES tech with a target, as {tech, target}; empty when none has one.
static func pick_effect(c: BattleCoordinator, actor: Node, targetable: Array) -> Dictionary:
	for tech in c.available_techs(actor):
		if not EFFECT_USES.has(tech.effect):
			continue
		var t: Node = effect_target(c, String(EFFECT_USES[tech.effect]), targetable)
		if t != null:
			return {"tech": tech, "target": t}
	return {}


## The unit an EFFECT_USES condition picks, or null.
static func effect_target(c: BattleCoordinator, use: String, targetable: Array) -> Node:
	var pool: Array = targetable if use in ["unbroken", "broken"] else c.party.filter(func(u: Node) -> bool: return c.alive(u))
	for u in pool:
		var st := CombatantStats.of(u)
		var ok: bool = false
		match use:
			"unbroken":
				ok = not c.is_broken(u)
			"broken":
				ok = c.is_broken(u)
			"hurt":
				ok = st.hp_ratio() < 0.5
			"rewindable":
				ok = c.turn_snapshots.has(u) and float(int(c.turn_snapshots[u]["hp"]) - st.hp) >= 0.2 * float(st.max_hp())
			"ally":
				ok = true
		if ok:
			return u
	return null


static func _cast_effect(c: BattleCoordinator, actor: Node, targetable: Array) -> bool:
	var pick: Dictionary = pick_effect(c, actor, targetable)
	if pick.is_empty():
		return false
	var tech: TechDef = pick["tech"]
	var t: Node = pick["target"]
	var r: Dictionary = c.cmd_tech(actor, tech.id, t, c.position_of(t), 0, c.partners_for(tech, actor))
	if not bool(r.get("ok", false)):
		return false
	if actor is CombatActor:
		(actor as CombatActor).sprite.play(&"attack", &"ready")
	_note("tech:%s" % tech.id)
	return true


static func _guard(c: BattleCoordinator, actor: Node) -> void:
	c.cmd_guard(actor)
	_note("guard")


static func _note(kind: String, boost: int = 0) -> void:
	tally[kind] = int(tally.get(kind, 0)) + 1
	if boost > 0:
		tally["boost%d" % boost] = int(tally.get("boost%d" % boost, 0)) + 1


## Print and clear the tally: "AUTOBATTLE victory=true attack=12 boost3=2 tech:hold=1 ...".
static func report(victory: bool) -> void:
	var keys: Array = tally.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for k in keys:
		parts.append("%s=%d" % [k, int(tally[k])])
	print("AUTOBATTLE victory=%s %s" % [str(victory), " ".join(parts)])
	tally.clear()
