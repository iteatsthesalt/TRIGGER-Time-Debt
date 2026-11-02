## How a status lands on a battler (Combat Laws Bible §12.1, §12.2, §7.3, §9.3) and the battle's status
## housekeeping. Every application goes through apply(): bosses take half duration from SLOW, Mercury SLOW,
## Chrono Lag and Knock-Static and are immune to Confuse, GUILTY and Time Stop unless their entry's behaviour
## lists the status under `takes_statuses`; Ruin goes to RuinRules; Stripped takes one resistance off the
## plates for its duration. The undo helpers give NULL's strips back when their status ends.
class_name StatusRules
extends RefCounted

const BOSS_HALVED: Array[StringName] = [&"slow", &"mercury_slow", &"chrono_lag", &"knock_static"]
const BOSS_IMMUNE: Array[StringName] = [&"confuse", &"guilty", &"time_stop"]
## Damage over time (§6.3): the tick is set where the status lands (15% of the hit's raw damage).
const DOTS: Array[StringName] = [&"oil_dot", &"ink_dot", &"bleed", &"burn"]


## Apply status `id` to `target`. seconds/turns < 0 mean "until removed". Returns true when it landed.
static func apply(c: BattleCoordinator, target: Node, id: StringName, seconds: float = -1.0, turns: int = -1, stacks: int = 1, extra: Dictionary = {}) -> bool:
	var sc := StatusComponent.of(target)
	if sc == null or id == &"":
		return false
	var st := CombatantStats.of(target)
	if st != null and st.kind == "boss" and not _takes(c, st, id):
		if BOSS_IMMUNE.has(id):
			return false
		if BOSS_HALVED.has(id):
			if seconds > 0.0:
				seconds *= 0.5
			if turns > 0:
				turns = maxi(1, floori(float(turns) / 2.0))
	if id == &"ruin":
		RuinRules.add(target, stacks)
		return true
	var data: Dictionary = extra.duplicate()
	if id == &"stripped" and not sc.has(id):
		var undo: Callable = strip_one_resist(target)
		if undo.is_valid():
			data["undo"] = undo
	sc.add(id, seconds, turns, stacks, data)
	return true


static func _takes(c: BattleCoordinator, st: CombatantStats, id: StringName) -> bool:
	var def: EnemyDef = c.enemy_defs.get(st.actor_id, null) if c != null else null
	if def == null:
		return false
	for s in def.behaviour.get("takes_statuses", []):
		if StringName(String(s)) == id:
			return true
	return false


## Boost Lv2 (§7.3): the technique's own debuff, else its element's default, for 2 of the target's turns.
static func lv2_debuff(c: BattleCoordinator, tech: TechDef, tags: Array, t: Node) -> void:
	var id: StringName = tech.lv2_debuff if tech != null else &""
	if id == &"":
		var element: StringName = tech.element_tag() if tech != null else CombatTags.element_of(tags[0] if not tags.is_empty() else &"")
		id = TechEffects.default_lv2(element)
	if id == &"":
		return
	var data: Dictionary = {}
	if id == &"corroded":
		data["def"] = true
	apply(c, t, id, -1.0, 2, 1, data)


## Stripped from NULL Lv2: the first resistance on the plates (else on the battler) is gone until the status
## ends. Returns the undo, or an invalid Callable when there was nothing to strip.
static func strip_one_resist(target: Node) -> Callable:
	var sh := ShieldComponent.of(target)
	if sh != null and not sh.resists.is_empty():
		var tag: StringName = sh.resists[0]
		sh.resists.remove_at(0)
		var serial: int = sh.config_serial
		return func() -> void:
			if is_instance_valid(sh) and sh.config_serial == serial and not sh.resists.has(tag):
				sh.resists.append(tag)
	var st := CombatantStats.of(target)
	if st != null and not st.resistant.is_empty():
		var tag2: StringName = st.resistant[0]
		st.resistant.remove_at(0)
		return func() -> void:
			if is_instance_valid(st) and not st.resistant.has(tag2):
				st.resistant.append(tag2)
	return Callable()


## NULL's strip on a shield with weaknesses: resistances and absorbs go until the status ends (§11.10).
static func strip_resists(sh: ShieldComponent) -> Callable:
	var resists: Array[StringName] = sh.resists.duplicate()
	var absorbs: Array[StringName] = sh.absorbs.duplicate()
	var serial: int = sh.config_serial
	sh.resists.clear()
	sh.absorbs.clear()
	return func() -> void:
		if is_instance_valid(sh) and sh.config_serial == serial:
			sh.resists = resists
			sh.absorbs = absorbs


## NULL on a weaknessless shield: `tag` is a real weakness for `turns` (§9.3), carried by `nulled_weakness`.
static func create_weakness(sh: ShieldComponent, sc: StatusComponent, tag: StringName, turns: int) -> void:
	sh.weaknesses.append(tag)
	sh.revealed[tag] = true
	var serial: int = sh.config_serial
	var undo := func() -> void:
		if is_instance_valid(sh) and sh.config_serial == serial:
			sh.weaknesses.erase(tag)
			sh.revealed.erase(tag)
	sc.add(&"nulled_weakness", -1.0, turns, 1, {"tag": tag, "undo": undo})


## One party hit's accuracy roll (§12.2 BLIND −30%, Ink Blot −60%, Ash Inhale −20%, White-Noise −100%).
## No roll at all at full accuracy, so an unaffected battle draws the same numbers as before.
static func hit_lands(c: BattleCoordinator, attacker_sc: StatusComponent) -> bool:
	if attacker_sc == null:
		return true
	var mod: float = attacker_sc.accuracy_mod()
	if mod >= 0.0:
		return true
	return c.rng.randf() < 1.0 + mod


## Battle movement range under SLOW (§12.2 Mercury SLOW: movement 0.5×).
static func move_range(u: Node) -> float:
	var st := CombatantStats.of(u)
	var sc := StatusComponent.of(u)
	return (st.move_range if st != null else 6.0) * (sc.movement_multiplier() if sc != null else 1.0)


# ---------------------------------------------------------------- the battle's housekeeping

## After every unit is initialised: this battle's Ruin cap, the periodic ticks, the break conditions and the
## shared plates.
static func begin_battle(c: BattleCoordinator, config: Dictionary) -> void:
	var cap: int = RuinRules.battle_cap(c.enemies, config)
	for u in c._all_units() + c.bench:
		RuinRules.prepare(u, cap)
		StatusTicks.watch(c, u)
	BreakConditions.begin_battle(c)
	ShieldComponent.link_shared(c.enemies)


## A body joined a running battle (an add, a summon, a phase spawn).
static func enemy_added(c: BattleCoordinator, u: Node) -> void:
	RuinRules.prepare(u, RuinRules.battle_cap(c.enemies))
	StatusTicks.watch(c, u)
	BreakConditions.arm(c, u)
	ShieldComponent.link_shared(c.enemies)


## The battle is over: no more ticks, the party's Ruin clears, conditions and shared plates let go.
static func end_battle(c: BattleCoordinator) -> void:
	for u in c._all_units() + c.bench:
		StatusTicks.release(u)
	for u in c.party + c.bench:
		RuinRules.clear(u)
	if c.hover_sera != null:
		RuinRules.clear(c.hover_sera)
	BreakConditions.end_battle(c)
	ShieldComponent.unlink_shared(c.enemies)
