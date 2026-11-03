## An enemy's turn (Combat Laws Bible §3.5, §7.5, §12): the brain picks the action, a wind-up telegraphs it, and
## its strikes land through EnemyStrike on whom its shape catches (taunts and Bekkler's Guilt decide the landing).
## after_damage runs the passives a hurt ally triggers (Krona's gourd, Crono's wrist seam).
class_name EnemyTurn
extends RefCounted


## `e` reached its gate: it chooses, and either winds up (a telegraph) or acts at once.
static func begin(c: BattleCoordinator, e: Node) -> void:
	var def: EnemyDef = c.enemy_defs.get(CombatantStats.of(e).actor_id, null)
	TurnRewind.snapshot(c, e)
	var action: Dictionary = EnemyBrain.choose(c, e, def, c.rng)
	c.gauges[e] = 0.0
	c.turn_counts[e] = int(c.turn_counts.get(e, 0)) + 1
	var sc := StatusComponent.of(e)
	if sc != null:
		sc.on_turn_taken()
	c.enemy_action_started.emit(e, action)
	var wind: float = float(action.get("wind_up_s", 0.0))
	if sc != null:
		wind += sc.hitch_seconds(bool(action.get("stepped", false)))  # Knock-Static as it was when chosen
	if wind > 0.0:
		c.wind_ups[e] = {"action": action, "left": wind, "total": wind}
		c.telegraph_started.emit(e, action)
		return
	EnemyTurn.execute(c, e, action)


## `e` acts: its strikes on whom the shape catches, its heal, its theft, its effect; then the battle may end.
static func execute(c: BattleCoordinator, e: Node, action: Dictionary) -> void:
	if not c.alive(e):
		return
	var prev: int = c.state
	c.state = BattleCoordinator.State.EXECUTING
	c.enemy_action_serial += 1
	var est := CombatantStats.of(e)
	var targets: Array = action.get("targets", [])
	targets = targets.filter(func(t: Node) -> bool: return c.alive(t) and not c.untargetable(t))
	if targets.is_empty():
		targets = c.targetable_party()
	var shape_name: String = String(action.get("shape", "SINGLE"))
	var shape_id: int = int(TechDef.SHAPE_NAMES.get(shape_name, TechDef.Shape.SINGLE))
	var aim: Vector3 = action.get("aim", c.position_of(targets[0]) if not targets.is_empty() else c.arena_center)
	var hit_list: Array = []
	if shape_id == TechDef.Shape.SINGLE or bool(action.get("turned", false)):  # GUILTY: one of its own allies
		if not targets.is_empty():
			hit_list = [{"node": targets[0], "hits": 1, "rank": 0}]
	else:
		var params := {"shape": shape_id, "radius": float(action.get("radius", 1.0)), "length": float(action.get("length", 0.0)), "width": float(action.get("width", 1.2)), "scale": 1.0}
		hit_list = TacticalPositioner.targets_in_shape(params, c.position_of(e), aim, CastReach.party_bodies(c), CastReach.blockers(c))
	var info := {"kind": "enemy", "attacker": e, "action": action, "targets": [], "damage": {}}
	if float(action.get("heal", 0.0)) > 0.0:
		var amt: int = DamagePipeline.compute_heal(est.e_atk, float(action["heal"]), 0)
		var healed: int = est.heal(amt)
		c.heal_resolved.emit(e, e, healed)
	BpTheft.steal(c, e, int(action.get("bp_steal", 0)))  # into its visible counter; a Balloon Escape foils one
	var landed: Array = []  # where the hits came down: the action's effect follows them (a Guilt-turned hit included)
	for h in hit_list:
		var landing: Array = c.taunts.landing(c, h["node"])  # Bekkler's Guilt: a hit on an ally in its ring lands on Crono
		var t: Node = landing[0]
		if not info["targets"].has(t):
			info["targets"].append(t)
			landed.append({"node": t, "hits": h["hits"], "rank": h["rank"]})
		info["damage"][t] = int(info["damage"].get(t, 0)) + EnemyStrike.resolve(c, e, t, action, int(h["hits"]), int(h["rank"]), float(landing[1]))
	if String(action.get("effect", "")) != "":
		EnemyEffects.apply(c, e, action, landed)
	c.action_executed.emit(info)
	if c.state == BattleCoordinator.State.EXECUTING:
		c.state = prev if prev != BattleCoordinator.State.EXECUTING else BattleCoordinator.State.TICK
	c.check_end()


## Passives that fire when a party member is hurt: Krona's gourd, the wrist-seam check.
static func after_damage(c: BattleCoordinator, t: Node) -> void:
	var st := CombatantStats.of(t)
	if st == null or not st.is_alive():
		return
	if st.actor_id == &"krona" and st.hp_ratio() < 0.25 and int(t.get_meta("sipped_action", -1)) != c.enemy_action_serial:
		t.set_meta("sipped_action", c.enemy_action_serial)  # once per enemy action against her (DECISIONS)
		st.heal(roundi(float(st.max_hp()) * 0.20))
		CorruptionComponent.add_to(t, CorruptionComponent.GOURD_SIP)
		c.battle_message.emit("Krona drinks from the gourd.")
	if st.actor_id == &"crono" and TimeDebtComponent.in_galaxy(t) and not t.get_meta("concerned_fired", false):
		t.set_meta("concerned_fired", true)
		var sc := StatusComponent.of(t)
		if sc != null:
			sc.add(&"concerned_target", -1.0, -1)
		c.truth_moment.emit(&"galaxy_reveal")
