## Runs one seamless battle (Combat Laws Bible §3, §4, §5, §6, §7, §16, §18.4).
## Owns battle_time, every gauge, the Ready Pool, the shared BoostBank, enemy wind-ups, Break timers,
## statuses and fields: the lifecycle, the timeline, the command entry points, the queries and the turn
## bookkeeping. The rules live in static classes that take it as their first argument and use only its public
## members (suite_acceptance pins that): PartyActions (Attack, techniques), StrikeResolution, TechCosts,
## TechAvailability, ActionPreview, TurnRewind (Rewind, Borrowed Future), EnemyTurn, SyncHoldRules, EnsParry,
## SwapRules, WithdrawRules, StatusRules and the effect classes. Headless-testable: set auto_tick = false and call
## advance(dt).
class_name BattleCoordinator
extends Node

signal battle_started(arena_center: Vector3)
signal battle_ended(victory: bool, summary: Dictionary)
signal command_requested(actor: Node)
signal ready_pool_changed(pool: Array)
signal enemy_action_started(enemy: Node, action: Dictionary)
signal telegraph_started(enemy: Node, action: Dictionary)
signal telegraph_ended(enemy: Node)
signal strike_resolved(attacker: Node, target: Node, info: Dictionary)
signal action_executed(info: Dictionary)
signal unit_broken(unit: Node, breaker: Node)
signal unit_recovered(unit: Node)
signal unit_koed(unit: Node)
signal unit_revived(unit: Node)
signal unit_spared(unit: Node)
signal bp_changed(bp: int, max_bp: int)
signal sera_phase_changed(phased: bool)
signal boost_used(actor: Node, level: int)
signal field_added(field: Dictionary)
signal truth_moment(kind: StringName)
signal battle_message(text: String)
signal parry_result(ally: Node, perfect: bool)
signal possibility_branch(branch_id: StringName, options: Array)
signal heal_resolved(source: Node, target: Node, amount: int)
signal unit_moved(unit: Node, to: Vector3)
signal summon_requested(key: StringName, count: int, near: Node)
signal enemy_added(unit: Node)

enum State { IDLE, TRANSITION_IN, TICK, COMMAND_WAIT, EXECUTING, BRANCH, VICTORY, DEFEAT, TRANSITION_OUT }

@export var auto_tick: bool = true
@export var flow_speed: float = 1.0
## 0 = random each battle; anything else is reproducible (tests).
@export var rng_seed: int = 0
@export var universe: int = 0
## Fixed variance for tests (0 = roll 0.95–1.05).
@export var fixed_variance: float = 0.0

var state: int = State.IDLE
var battle_time: float = 0.0
var party: Array[Node] = []
var bench: Array[Node] = []
var enemies: Array[Node] = []
var ready_pool: Array[Node] = []
var active_actor: Node = null
var gauges: Dictionary = {}
var offsets: Dictionary = {}
var hold_time: Dictionary = {}
var turn_counts: Dictionary = {}
var wind_ups: Dictionary = {}
var spared: Array[Node] = []
var bank := BoostBank.new()
var fields := BattleFields.new()
var statues := StatueTimers.new()
var rng := RandomNumberGenerator.new()
var arena_center: Vector3 = Vector3.ZERO
var tech_library: Dictionary = {}
var enemy_defs: Dictionary = {}
var is_boss_battle: bool = false
## A battle the story started (Location._on_story_battle): its script owns the ending, so no Withdraw.
var is_story_battle: bool = false
var ground: WalkableGround = null  # the field's floor (Location): a Withdraw falls back onto it (WithdrawRules)
var hover_sera: Node = null
var prometheus_available: bool = false
var prometheus_used: bool = false
var swapped_once: bool = false
var taunts := TauntBook.new()  # who draws the enemies' attacks, and Bekkler's Guilt's ring
var parry_armed: Dictionary = {}
var parry_frames: int = CombatConstants.ENS_PARRY_FRAMES_BASE
var ens_rings: Dictionary = {}
var branch_pending: Dictionary = {}
var branch_callback: Callable = Callable()
var last_summary: Dictionary = {}
var last_break_signature: Array[StringName] = []
var ko_order: Array[Node] = []
## Technique cooldowns, per caster (TechCooldowns).
var cooldowns := TechCooldowns.new()
## Counts enemy actions: Krona's gourd sips at most once per enemy action against her (DECISIONS).
var enemy_action_serial: int = 0
var _break_callables: Dictionary = {}
var _ko_callables: Dictionary = {}
var perfect_frame_pending: Dictionary = {}
## unit -> snapshot {hp, gauge, pos, statuses} taken at its last turn start (Rewind, §3.6).
var turn_snapshots: Dictionary = {}
## unit -> the last action it performed (Borrowed Future's Token Duplicate copies it).
var last_actions: Dictionary = {}
var token_duplicate_active: Node = null
## Set by a boss controller while a mid-battle script plays: the clock stops and no window opens.
var paused: bool = false
## Units that take no HP damage for now (a boss sealed until a Debt is paid); shields still shave.
var undamageable: Array[Node] = []
## The ally that has used its move this window (§4.1: one optional move, then one action).
var moved_this_window: Node = null
## When > 0, enemy hits cannot take a party member below this many HP (zero-fail tutorial fights).
var party_hp_floor: int = 0


func _physics_process(delta: float) -> void:
	if auto_tick:
		advance(delta)


# ------------------------------------------------------------------ lifecycle

## config: {advantage: normal|preemptive|ambush, universe, boss, story, techs, enemy_defs, bench, hover_sera, prometheus, parry_frames, max_bp, max_spend, ground}
func start_battle(party_in: Array, enemies_in: Array, center: Vector3, config: Dictionary = {}) -> void:
	if state != State.IDLE:
		return
	state = State.TRANSITION_IN
	party.clear()
	for p in party_in:
		party.append(p)
	enemies.clear()
	for e in enemies_in:
		enemies.append(e)
	bench.clear()
	for b in config.get("bench", []):
		bench.append(b)
	ready_pool.clear()
	gauges.clear()
	offsets.clear()
	hold_time.clear()
	turn_counts.clear()
	wind_ups.clear()
	spared.clear()
	taunts.clear()
	parry_armed.clear()
	ens_rings.clear()
	cooldowns.clear()
	ko_order.clear()
	statues.clear()
	fields.clear()
	battle_time = 0.0
	prometheus_used = false
	swapped_once = false
	arena_center = center
	universe = int(config.get("universe", universe))
	is_boss_battle = bool(config.get("boss", false))
	is_story_battle = bool(config.get("story", false))
	ground = config.get("ground") as WalkableGround
	tech_library = config.get("techs", tech_library)
	enemy_defs = config.get("enemy_defs", enemy_defs)
	hover_sera = config.get("hover_sera", null)
	prometheus_available = bool(config.get("prometheus", false))
	parry_frames = int(config.get("parry_frames", parry_frames))
	bank.max_bp = int(config.get("max_bp", CombatConstants.MAX_BP))
	bank.max_spend = int(config.get("max_spend", CombatConstants.MAX_SPEND))
	bank.begin_battle()
	if not bank.changed.is_connected(_on_bank_changed):
		bank.changed.connect(_on_bank_changed)
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	for u in all_units() + bench:
		BattleMarks.clear(u)  # the bodies outlive a battle: what held for the last one does not hold for this one
	var advantage: String = String(config.get("advantage", "normal"))
	for u in party:
		init_unit(u, _start_gauge(true, advantage))
	for e in enemies:
		init_unit(e, _start_gauge(false, advantage))
	if hover_sera != null and not party.has(hover_sera):
		init_unit(hover_sera, _start_gauge(true, advantage))
	StatusRules.begin_battle(self, config)  # Ruin cap, periodic ticks, break conditions, shared plates
	RewardResolver.watch(self)  # how each enemy is finished: its lean and its drops at the end
	bp_changed.emit(bank.bp, bank.max_bp)
	battle_started.emit(center)
	state = State.TICK


func _start_gauge(is_party: bool, advantage: String) -> float:
	match advantage:
		"preemptive":
			return rng.randf_range(CombatConstants.PREEMPT_START.x, CombatConstants.PREEMPT_START.y) if is_party else 0.0
		"ambush":
			return 0.0 if is_party else rng.randf_range(CombatConstants.PREEMPT_START.x, CombatConstants.PREEMPT_START.y)
	if is_party:
		return rng.randf_range(CombatConstants.PARTY_START_GAUGE.x, CombatConstants.PARTY_START_GAUGE.y)
	return rng.randf_range(CombatConstants.ENEMY_START_GAUGE.x, CombatConstants.ENEMY_START_GAUGE.y)


func init_unit(u: Node, gauge: float) -> void:
	gauges[u] = gauge
	offsets[u] = rng.randf_range(0.0, TAU)
	hold_time[u] = 0.0
	turn_counts[u] = 0
	var st := CombatantStats.of(u)
	if st != null:
		st.is_guarding = false
		if st.hp < 0:
			st.reset_vitals()
		if not _ko_callables.has(u):
			var cb := _on_unit_defeated.bind(u)
			st.defeated.connect(cb)
			_ko_callables[u] = cb
	var usc := StatusComponent.of(u)
	if usc != null:
		usc.acting = false
	var sh := ShieldComponent.of(u)
	if sh != null:
		sh.reset_shields()
		if not _break_callables.has(u):
			var cb2 := _on_unit_broken.bind(u)
			sh.broken.connect(cb2)
			_break_callables[u] = cb2
	var sol := SolidityComponent.of(u)
	if sol != null:
		sol.begin_battle()
	var td := TimeDebtComponent.of(u)
	if td != null:
		td.strain_this_battle = 0.0
		td.battle_strain = 0.0


## Ends the battle. A withdraw (reason "withdraw", WithdrawRules) is no defeat: no integrity; `extra` (its point) joins the summary.
func finish(victory: bool, reason: String = "", extra: Dictionary = {}) -> void:
	if state == State.VICTORY or state == State.DEFEAT or state == State.IDLE:
		return
	state = State.VICTORY if victory else State.DEFEAT
	active_actor = null
	ready_pool.clear()
	for u in _break_callables.keys():
		var sh := ShieldComponent.of(u)
		if is_instance_valid(u) and sh != null and sh.broken.is_connected(_break_callables[u]):
			sh.broken.disconnect(_break_callables[u])
	_break_callables.clear()
	for u in _ko_callables.keys():
		var st := CombatantStats.of(u)
		if is_instance_valid(u) and st != null and st.defeated.is_connected(_ko_callables[u]):
			st.defeated.disconnect(_ko_callables[u])
	_ko_callables.clear()
	var summary: Dictionary = {"victory": victory, "reason": reason, "xp": {}, "spared": spared.size(), "battle_time": battle_time, "integrity_lost": 0.0}
	summary.merge(extra)
	if victory:
		summary.merge(RewardResolver.resolve(self), true)  # XP, drops, leans
	for u in party + bench:
		if not is_instance_valid(u):
			continue
		var td := TimeDebtComponent.of(u)
		if td != null:
			if not victory and reason != "withdraw":
				td.pay_integrity(CombatConstants.CRONO_DEFEAT_INTEGRITY)
				summary["integrity_lost"] = CombatConstants.CRONO_DEFEAT_INTEGRITY
			td.end_battle()
		var sol := SolidityComponent.of(u)
		if sol != null:
			sol.end_battle()
		var sc := StatusComponent.of(u)
		if sc != null:
			sc.cleanse()
		var st := CombatantStats.of(u)
		if st != null:
			st.is_guarding = false
			st.temp_shield = 0
	if hover_sera != null:
		var sol2 := SolidityComponent.of(hover_sera)
		if sol2 != null:
			sol2.end_battle()
	StatusRules.end_battle(self)
	last_summary = summary
	battle_ended.emit(victory, summary)
	state = State.IDLE


## Bring a new enemy into a running battle (adds, summons, phase spawns).
func add_enemy(u: Node, def: EnemyDef = null) -> void:
	if enemies.has(u):
		return
	enemies.append(u)
	if def != null:
		enemy_defs[CombatantStats.of(u).actor_id] = def
	init_unit(u, rng.randf_range(CombatConstants.ENEMY_START_GAUGE.x, CombatConstants.ENEMY_START_GAUGE.y) * 0.5)
	StatusRules.enemy_added(self, u)
	enemy_added.emit(u)


func request_summon(key: StringName, count: int, near: Node) -> void:
	summon_requested.emit(key, count, near)


## End the battle from outside (a boss whose fight ends on a Break, a scripted escape).
func force_end(victory: bool, reason: String = "scripted") -> void:
	if state == State.IDLE or state == State.VICTORY or state == State.DEFEAT:
		return
	finish(victory, reason)


# ------------------------------------------------------------------ timeline

func advance(delta: float) -> void:
	if state != State.TICK or paused:
		return
	var dt: float = delta * flow_speed
	if dt <= 0.0:
		return
	battle_time += dt
	# Timers first (statuses, shields, fields, hazards), then gauges.
	for u in all_units():
		if not is_instance_valid(u):
			continue
		var sh := ShieldComponent.of(u)
		if sh != null and alive(u):  # a body that died Broken never recovers: it stands as a statue (§5.4)
			if sh.is_broken:
				if sh.tick(dt):
					unit_recovered.emit(u)
			else:
				sh.tick(dt)
				sh.tick_resume(dt)
		var sc := StatusComponent.of(u)
		if sc != null:
			sc.tick(dt)
		var td := TimeDebtComponent.of(u)
		if td != null:
			td.tick(dt)
	statues.tick(dt)
	FieldEffects.tick(self, dt)
	bank.tick_oil_blight(dt)
	EnsParry.tick(self, dt)
	if state != State.TICK:
		return

	var any_parked: bool = not ready_pool.is_empty()
	for u in all_units():
		if not alive(u) or not is_instance_valid(u):
			continue
		if ready_pool.has(u):
			hold_time[u] = float(hold_time.get(u, 0.0)) + dt
			continue
		var sh2 := ShieldComponent.of(u)
		if sh2 != null and (sh2.is_broken or sh2.resume_left > 0.0):
			continue
		if wind_ups.has(u):
			var w: Dictionary = wind_ups[u]
			w["left"] = float(w["left"]) - dt
			if float(w["left"]) <= 0.0:
				end_wind_up(u)
				EnemyTurn.execute(self, u, w["action"])
				if state != State.TICK:
					return
			continue
		var sol := SolidityComponent.of(u)
		if sol != null and sol.is_phased():
			# Her gauge still fills; each time it would reach the gate a phased turn passes.
			gauges[u] = float(gauges[u]) + gauge_fill(u, dt)
			if float(gauges[u]) >= CombatConstants.SYNC_HOLD:
				gauges[u] = 0.0
				sol.on_phased_turn()
				if not sol.is_phased():
					sera_phase_changed.emit(false)
			continue
		gauges[u] = float(gauges[u]) + gauge_fill(u, dt)
	SyncHoldRules.update_voluntary(self)

	# Enemies at their gate act without freezing anything.
	var enemy_ready: Array = []
	for e in enemies:
		if alive(e) and float(gauges.get(e, 0.0)) >= CombatConstants.ENEMY_GATE and not wind_ups.has(e):
			enemy_ready.append(e)
	enemy_ready.sort_custom(func(a: Node, b: Node) -> bool: return float(gauges[a]) > float(gauges[b]))
	for e in enemy_ready:
		EnemyTurn.begin(self, e)
		if state != State.TICK:
			return

	var next: Node = SyncHoldRules.next_at_gate(self)
	if next != null:
		open_window(next, true)
	else:
		# A parked ally nobody can relieve gets the floor back without new BP (§3.4, SyncHoldRules).
		var stranded: Node = SyncHoldRules.stranded(self)
		if stranded != null:
			open_window(stranded, false)
	if not any_parked and not ready_pool.is_empty():
		ready_pool_changed.emit(ready_pool)


func gauge_fill(u: Node, dt: float) -> float:
	var st := CombatantStats.of(u)
	var speed: float = st.gauge_speed() if st != null else 25.0
	var drift: float = sin(battle_time + float(offsets.get(u, 0.0))) * CombatConstants.DRIFT_AMPLITUDE
	var mult: float = 1.0
	var sc := StatusComponent.of(u)
	if sc != null:
		mult = sc.gauge_multiplier()
	mult *= FieldEffects.gauge_multiplier(self, u)  # a ghost ring (§7.4)
	return (speed + drift) * dt * mult


func open_window(u: Node, grant_bp: bool) -> void:
	gauges[u] = CombatConstants.SYNC_HOLD
	if grant_bp:
		bank.add(1, true)
		TurnRewind.snapshot(self, u)
	if not ready_pool.has(u):
		ready_pool.append(u)
		hold_time[u] = 0.0
		ready_pool_changed.emit(ready_pool)
	var st := CombatantStats.of(u)
	if st != null:
		st.is_guarding = false
	var sc := StatusComponent.of(u)
	if sc != null:
		sc.begin_action()  # what this action gives its actor is not counted down by it (DECISIONS "Turn statuses")
	active_actor = u
	moved_this_window = null
	state = State.COMMAND_WAIT
	command_requested.emit(u)


## Wake a parked ally at any time while the timeline runs.
func request_command(u: Node) -> bool:
	if state != State.TICK or not ready_pool.has(u) or not alive(u):
		return false
	open_window(u, false)
	return true


# ------------------------------------------------------------------ party commands

func cmd_sync_hold(actor: Node) -> Dictionary:
	if not is_turn(actor):
		return fail("not this actor's turn")
	var sc := StatusComponent.of(actor)
	if sc != null:
		sc.acting = false  # parked: what lands on it while it waits counts against its next action
	active_actor = null
	state = State.TICK
	ready_pool_changed.emit(ready_pool)
	return {"ok": true}


func cmd_move(actor: Node, to: Vector3) -> Dictionary:
	if not is_turn(actor):
		return fail("not this actor's turn")
	if moved_this_window == actor:
		return fail("already moved this window")
	moved_this_window = actor
	var from: Vector3 = position_of(actor)
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var range_m: float = StatusRules.move_range(actor)  # SLOW halves it (§12.2)
	if flat.length() > range_m + 0.001:
		to = from + flat.normalized() * range_m
	var half: float = CombatConstants.PLANE_SIZE * 0.5
	to.x = clampf(to.x, arena_center.x - half, arena_center.x + half)
	to.z = clampf(to.z, arena_center.z - half, arena_center.z + half)
	move_unit(actor, to)
	return {"ok": true, "position": to}


func cmd_guard(actor: Node) -> Dictionary:
	if not is_turn(actor):
		return fail("not this actor's turn")
	state = State.EXECUTING
	var st := CombatantStats.of(actor)
	st.is_guarding = true
	finish_turn(actor, CombatConstants.GUARD_NEXT_GAUGE)
	after_party_action({"kind": "guard", "actor": actor})
	return {"ok": true}


## Attack (§4.2; PartyActions.attack).
func cmd_attack(actor: Node, target: Node, boost: int = 0) -> Dictionary:
	return PartyActions.attack(self, actor, target, boost)


## Use a technique (PartyActions.tech). partners: the Ready Pool allies joining a Dual/Triple (besides the actor).
## options: the cast's choices, copied into the action (PartyActions.ACTION_OPTIONS: HOLD's "steps", Tune's "mode").
func cmd_tech(actor: Node, tech_id: StringName, target: Node, aim: Vector3, boost: int = 0, partners: Array = [], options: Dictionary = {}) -> Dictionary:
	return PartyActions.tech(self, actor, tech_id, target, aim, boost, partners, options)


func cmd_item(actor: Node, item: Dictionary, target: Node) -> Dictionary:
	if not is_turn(actor):
		return fail("not this actor's turn")
	if not ItemUse.works(self, item, target):  # refused before it leaves the bag (BattleDeck.use_item)
		return fail("it would do nothing")
	state = State.EXECUTING
	var info := {"kind": "item", "actor": actor, "item": item}
	ItemUse.apply(self, actor, item, target)
	finish_turn(actor, 0.0)
	after_party_action(info)
	return {"ok": true, "info": info}


## Swap and swap-a-KO'd-ally (§4.2): the rules and the bookkeeping live in SwapRules; both end the turn.
func cmd_swap(actor: Node, incoming: Node) -> Dictionary:
	return SwapRules.swap(self, actor, incoming)


func cmd_swap_koed(actor: Node, koed: Node, incoming: Node) -> Dictionary:
	return SwapRules.swap_koed(self, actor, koed, incoming)


func cmd_spare(actor: Node, target: Node) -> Dictionary:
	if not is_turn(actor):
		return fail("not this actor's turn")
	if not can_spare(target):
		return fail("cannot spare: must be Broken and at 25% HP or less")
	state = State.EXECUTING
	spared.append(target)
	end_wind_up(target)  # it leaves the fight (§4.2) and takes any telegraph with it
	unit_spared.emit(target)
	finish_turn(actor, 0.0)
	after_party_action({"kind": "spare", "actor": actor, "target": target})
	return {"ok": true}


func can_spare(target: Node) -> bool:
	if not enemies.has(target) or not alive(target) or spared.has(target):
		return false
	var sh := ShieldComponent.of(target)
	var st := CombatantStats.of(target)
	return sh != null and sh.is_broken and st.hp_ratio() <= CombatConstants.SPARE_HP_PCT


## Withdraw (§4.2, §16.5): the fall-back move, the edge and gauge rules and the outcome live in WithdrawRules.
func cmd_withdraw(actor: Node) -> Dictionary:
	return WithdrawRules.attempt(self, actor)


## The Possibility Branch answer (bosses).
func choose_branch(option: StringName) -> void:
	if state != State.BRANCH:
		return
	var cb: Callable = branch_callback
	branch_pending = {}
	branch_callback = Callable()
	state = State.TICK
	if cb.is_valid():
		cb.call(option)


func open_branch(branch_id: StringName, options: Array, callback: Callable) -> void:
	branch_pending = {"id": branch_id, "options": options}
	branch_callback = callback
	state = State.BRANCH
	possibility_branch.emit(branch_id, options)


# ------------------------------------------------------------------ queries

## The techniques `actor` may use now (TechAvailability).
func available_techs(actor: Node) -> Array[TechDef]:
	return TechAvailability.available(self, actor)


## The character knows the tech: unlock check against the kit (delegated to a callable when present).
var knows_tech: Callable = Callable()


## The Ready Pool allies who would join `actor` in `t` (TechAvailability).
func partners_for(t: TechDef, actor: Node) -> Array:
	return TechAvailability.partners_for(self, t, actor)


## Preview the shave and damage of an action per target (§4.6; ActionPreview).
func preview(actor: Node, tech: TechDef, target: Node, aim: Vector3, boost: int, partners: Array = []) -> Dictionary:
	return ActionPreview.of(self, actor, tech, target, aim, boost, partners)


func get_gauge(u: Node) -> float:
	return float(gauges.get(u, 0.0))


func set_gauge(u: Node, v: float) -> void:
	gauges[u] = clampf(v, 0.0, CombatConstants.GAUGE_MAX)


func turns_taken(u: Node) -> int:
	return int(turn_counts.get(u, 0))


func position_of(u: Node) -> Vector3:
	if u is Node3D:
		return (u as Node3D).global_position
	if u != null and u.has_meta("battle_pos"):
		return u.get_meta("battle_pos")
	return arena_center


func move_unit(u: Node, p: Vector3) -> void:
	if u is Node3D:
		(u as Node3D).global_position = p
	else:
		u.set_meta("battle_pos", p)
	unit_moved.emit(u, p)


func targetable_party() -> Array:
	var out: Array = []
	for u in party:
		if alive(u) and not untargetable(u):
			out.append(u)
	return out


func living_enemies() -> Array:
	var out: Array = []
	for e in enemies:
		if alive(e) and not spared.has(e):
			out.append(e)
	return out


## The enemies a command can aim at: living and not untargetable (a doll stepped back for its split, a phase-out).
func targetable_enemies() -> Array:
	return enemies.filter(func(e: Node) -> bool: return alive(e) and not untargetable(e))


func is_broken(u: Node) -> bool:
	var sh := ShieldComponent.of(u)
	return sh != null and sh.is_broken


func current_taunter(enemy: Node) -> Node:
	# Father Tank: Lavos-spawn target Crono while Sera is below 40% HP.
	var sera: Node = party_unit(&"sera")
	var crono: Node = party_unit(&"crono")
	if sera != null and crono != null and alive(crono) and alive(sera):
		var est := CombatantStats.of(enemy)
		if CombatantStats.of(sera).hp_ratio() < 0.4 and est != null and est.tags.has(&"LAVOS"):
			return crono
	return taunts.drawing(alive)


func taunt_strength(t: Node) -> float:
	return taunts.strength_of(t)


## A taunt on `t` for `turns` of its turns; one given while `t` acts counts from its next action (TauntBook).
func add_taunt(t: Node, turns: int, strength: float, extra: Dictionary = {}) -> void:
	var sc := StatusComponent.of(t)
	taunts.add(t, turns, strength, sc.acting if sc != null else t == active_actor, extra)


## The next strike of `actor` lands on a Perfect Frame (§6.4: +15%; washi_hollow_rebirth's 4-frame input, unbuilt).
func mark_perfect_frame(actor: Node) -> void:
	perfect_frame_pending[actor] = true


# ------------------------------------------------------------------ wind-ups (EnemyTurn plays an enemy's turn)

## The wind-up of `e` is over (it resolved, or a Break, a KO, a spare, an HZ hit or an effect cancelled it): the
## entry goes and its telegraph decal with it. Returns false when `e` was not winding up.
func end_wind_up(e: Node) -> bool:
	if not wind_ups.erase(e):
		return false
	telegraph_ended.emit(e)
	return true


# ------------------------------------------------------------------ turn bookkeeping

func finish_turn(actor: Node, next_gauge: float) -> void:
	gauges[actor] = next_gauge
	ready_pool.erase(actor)
	hold_time[actor] = 0.0
	turn_counts[actor] = int(turn_counts.get(actor, 0)) + 1
	if active_actor == actor:
		active_actor = null
	var sc := StatusComponent.of(actor)
	if sc != null:
		sc.on_turn_taken()
	var ended: Dictionary = taunts.on_turn_taken(actor)
	if ended.has("payoff") and alive(actor):  # Shogun's Command held: every ally's next hit ignores DEF (§11)
		for u in party:
			StatusRules.apply(self, u, StringName(String(ended["payoff"])))
	cooldowns.on_turn_taken(actor)
	var sol := SolidityComponent.of(actor)
	if sol != null and not actor.get_meta("used_tachyon_this_turn", false):
		sol.on_turn_without_tachyon()
	if actor.has_meta("used_tachyon_this_turn"):
		actor.remove_meta("used_tachyon_this_turn")
	bank.clamp_overflow()
	ready_pool_changed.emit(ready_pool)


func after_party_action(_info: Dictionary) -> void:
	for u in ready_pool.duplicate():
		if not alive(u):
			ready_pool.erase(u)
	if check_end():
		return
	# A parked ally gets the floor back after any party action (no deadlock).
	if not ready_pool.is_empty():
		var u: Node = ready_pool[0]
		open_window(u, false)
		return
	state = State.TICK


func check_end() -> bool:
	if state == State.VICTORY or state == State.DEFEAT or state == State.IDLE:
		return true
	if living_enemies().is_empty():
		finish(true, "victory")
		return true
	var standing: bool = false
	for u in party:
		if alive(u):
			var sol := SolidityComponent.of(u)
			if sol != null and sol.is_phased():
				continue
			standing = true
	if not standing:
		finish(false, "defeat")
		return true
	return false


func _on_unit_broken(breaker: Node, unit: Node) -> void:
	gauges[unit] = 0.0
	end_wind_up(unit)  # a Break cancels the wind-up (§3.5): its decal goes with it
	if unit.has_method("on_break"):
		unit.call("on_break")
	unit_broken.emit(unit, breaker)
	var sc := StatusComponent.of(unit)
	if sc != null and sc.has(&"spore_tag"):
		ShieldComponent.of(unit).extend_lock(1.2)
	# A foe of the field's owner that Breaks inside a Divinity Field is silenced 15 s (§12.5).
	if sc != null and FieldEffects.silences_on_break(self, unit):
		sc.add(&"silence", 15.0)


func _on_unit_defeated(unit: Node) -> void:
	ko_order.append(unit)
	end_wind_up(unit)  # a body that falls mid wind-up never lands it: no telegraph stays on the plane
	statues.on_defeated(unit, enemies.has(unit) and is_broken(unit))
	unit_koed.emit(unit)
	if party.has(unit):
		ready_pool.erase(unit)
		if prometheus_available and not prometheus_used and not RuinRules.blocks_prometheus(unit):
			prometheus_used = true
			bank.charge_or_owe(1)
			CombatantStats.of(unit).revive(CombatConstants.PROMETHEUS_REVIVE_HP)
			unit_revived.emit(unit)
			battle_message.emit("The Prometheus Core fires.")


# ------------------------------------------------------------------ helpers

func is_turn(actor: Node) -> bool:
	return state == State.COMMAND_WAIT and actor == active_actor


func fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}


func all_units() -> Array:
	var all: Array = []
	all.append_array(party)
	all.append_array(enemies)
	if hover_sera != null and not party.has(hover_sera):
		all.append(hover_sera)
	return all


func alive(u: Node) -> bool:
	if not is_instance_valid(u):
		return false
	var st := CombatantStats.of(u)
	return st != null and st.is_alive() and not spared.has(u)


func untargetable(u: Node) -> bool:
	if FieldEffects.pins_target(self, u):
		return false  # nothing inside a static field can be untargetable (§7.4)
	var sc := StatusComponent.of(u)
	if sc != null and sc.is_untargetable():
		return true
	var sol := SolidityComponent.of(u)
	return sol != null and sol.is_phased()


func party_unit(id: StringName) -> Node:
	for u in party:
		var st := CombatantStats.of(u)
		if st != null and st.actor_id == id:
			return u
	if hover_sera != null and CombatantStats.of(hover_sera) != null and CombatantStats.of(hover_sera).actor_id == id:
		return hover_sera
	return null


func unit_by_id(id: StringName) -> Node:
	var u: Node = party_unit(id)
	if u != null:
		return u
	for e in enemies:
		var st := CombatantStats.of(e)
		if st != null and st.actor_id == id:
			return e
	return null


func variance() -> float:
	if fixed_variance > 0.0:
		return fixed_variance
	return rng.randf_range(CombatConstants.VARIANCE_MIN, CombatConstants.VARIANCE_MAX)


func _on_bank_changed(bp: int, max_bp: int) -> void:
	bp_changed.emit(bp, max_bp)
