## Runs one seamless battle (Combat Laws Bible §3, §4, §5, §6, §7, §16, §18.4).
## Owns battle_time, every gauge, the Ready Pool, the shared BoostBank, enemy wind-ups, Break timers,
## statuses, fields and resolution. Headless-testable: set auto_tick = false and call advance(dt).
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
var fled: Array[Node] = []
var bank := BoostBank.new()
var fields := BattleFields.new()
var rng := RandomNumberGenerator.new()
var arena_center: Vector3 = Vector3.ZERO
var tech_library: Dictionary = {}
var enemy_defs: Dictionary = {}
var is_boss_battle: bool = false
var hover_sera: Node = null
var prometheus_available: bool = false
var prometheus_used: bool = false
var swapped_once: bool = false
var sera_present_in_story: bool = true
var taunts: Dictionary = {}
var parry_armed: Dictionary = {}
var parry_frames: int = CombatConstants.ENS_PARRY_FRAMES_BASE
var ens_rings: Dictionary = {}
var oil_blight_accum: float = 0.0
var oil_blight: bool = false
var hazard_hooks: Array[Callable] = []
var branch_pending: Dictionary = {}
var branch_callback: Callable = Callable()
var last_summary: Dictionary = {}
var last_break_signature: Array[StringName] = []
var ko_order: Array[Node] = []
var cooldowns: Dictionary = {}
var _break_callables: Dictionary = {}
var _ko_callables: Dictionary = {}
var _perfect_frame_pending: Dictionary = {}
var _last_action_info: Dictionary = {}
## unit -> snapshot {hp, gauge, pos, statuses} taken at its last turn start (Rewind, §3.6).
var turn_snapshots: Dictionary = {}
## unit -> the last action it performed (Borrowed Future's Token Duplicate copies it).
var last_actions: Dictionary = {}
var token_duplicate_active: Node = null
## Set by a boss controller while a mid-battle script plays: the clock stops and no window opens.
var paused: bool = false
## Units that take no HP damage for now (a boss sealed until a Debt is paid); shields still shave.
var undamageable: Array[Node] = []
## When > 0, enemy hits cannot take a party member below this many HP (zero-fail tutorial fights).
var party_hp_floor: int = 0


func _physics_process(delta: float) -> void:
	if auto_tick:
		advance(delta)


# ------------------------------------------------------------------ lifecycle

## config: {advantage: normal|preemptive|ambush, universe, boss, techs: Dictionary, enemy_defs,
##          bench: Array, hover_sera: Node, prometheus: bool, parry_frames, max_bp, max_spend, sera_present}
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
	fled.clear()
	taunts.clear()
	parry_armed.clear()
	ens_rings.clear()
	cooldowns.clear()
	ko_order.clear()
	fields.clear()
	battle_time = 0.0
	oil_blight = false
	oil_blight_accum = 0.0
	prometheus_used = false
	swapped_once = false
	arena_center = center
	universe = int(config.get("universe", universe))
	is_boss_battle = bool(config.get("boss", false))
	tech_library = config.get("techs", tech_library)
	enemy_defs = config.get("enemy_defs", enemy_defs)
	hover_sera = config.get("hover_sera", null)
	prometheus_available = bool(config.get("prometheus", false))
	parry_frames = int(config.get("parry_frames", parry_frames))
	sera_present_in_story = bool(config.get("sera_present", true))
	bank.max_bp = int(config.get("max_bp", CombatConstants.MAX_BP))
	bank.max_spend = int(config.get("max_spend", CombatConstants.MAX_SPEND))
	bank.begin_battle()
	if not bank.changed.is_connected(_on_bank_changed):
		bank.changed.connect(_on_bank_changed)
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	var advantage: String = String(config.get("advantage", "normal"))
	for u in party:
		_init_unit(u, _start_gauge(true, advantage))
	for e in enemies:
		_init_unit(e, _start_gauge(false, advantage))
	if hover_sera != null and not party.has(hover_sera):
		_init_unit(hover_sera, _start_gauge(true, advantage))
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


func _init_unit(u: Node, gauge: float) -> void:
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


func _finish(victory: bool, reason: String = "") -> void:
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
	if victory:
		summary["xp"] = _award_xp()
	for u in party + bench:
		if not is_instance_valid(u):
			continue
		var td := TimeDebtComponent.of(u)
		if td != null:
			if not victory:
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
	_init_unit(u, rng.randf_range(CombatConstants.ENEMY_START_GAUGE.x, CombatConstants.ENEMY_START_GAUGE.y) * 0.5)
	enemy_added.emit(u)


func request_summon(key: StringName, count: int, near: Node) -> void:
	summon_requested.emit(key, count, near)


## End the battle from outside (a boss whose fight ends on a Break, a scripted escape).
func force_end(victory: bool, reason: String = "scripted") -> void:
	if state == State.IDLE or state == State.VICTORY or state == State.DEFEAT:
		return
	_finish(victory, reason)


func _award_xp() -> Dictionary:
	var total: int = 0
	for e in enemies:
		var st := CombatantStats.of(e)
		if st == null:
			continue
		if spared.has(e):
			total += roundi(float(st.xp_reward) * 0.5)
		elif not st.is_alive():
			total += st.xp_reward
	var out: Dictionary = {}
	for u in party:
		var st2 := CombatantStats.of(u)
		if st2 != null:
			var share: int = total if st2.is_alive() else roundi(float(total) * 0.75)
			out[st2.actor_id] = {"xp": share, "levels": st2.gain_xp(share)}
	for b in bench:
		var st3 := CombatantStats.of(b)
		if st3 != null:
			var share2: int = roundi(float(total) * 0.75)
			out[st3.actor_id] = {"xp": share2, "levels": st3.gain_xp(share2)}
	return out


# ------------------------------------------------------------------ timeline

func advance(delta: float) -> void:
	if state != State.TICK or paused:
		return
	var dt: float = delta * flow_speed
	if dt <= 0.0:
		return
	battle_time += dt
	# Timers first (statuses, shields, fields, hazards), then gauges.
	for u in _all_units():
		if not is_instance_valid(u):
			continue
		var sh := ShieldComponent.of(u)
		if sh != null:
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
	_tick_fields(dt)
	_tick_oil_blight(dt)
	_tick_ens_rings(dt)
	for hook in hazard_hooks:
		hook.call(self, dt)
	if state != State.TICK:
		return

	var any_parked: bool = not ready_pool.is_empty()
	for u in _all_units():
		if not _alive(u) or not is_instance_valid(u):
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
				wind_ups.erase(u)
				telegraph_ended.emit(u)
				_execute_enemy_action(u, w["action"])
				if state != State.TICK:
					return
			continue
		var sol := SolidityComponent.of(u)
		if sol != null and sol.is_phased():
			# Her gauge still fills; each time it would reach the gate a phased turn passes.
			gauges[u] = float(gauges[u]) + _fill(u, dt)
			if float(gauges[u]) >= CombatConstants.SYNC_HOLD:
				gauges[u] = 0.0
				sol.on_phased_turn()
				if not sol.is_phased():
					sera_phase_changed.emit(false)
			continue
		gauges[u] = float(gauges[u]) + _fill(u, dt)
	_update_voluntary_windows()

	# Enemies at their gate act without freezing anything.
	var enemy_ready: Array = []
	for e in enemies:
		if _alive(e) and float(gauges.get(e, 0.0)) >= CombatConstants.ENEMY_GATE and not wind_ups.has(e):
			enemy_ready.append(e)
	enemy_ready.sort_custom(func(a: Node, b: Node) -> bool: return float(gauges[a]) > float(gauges[b]))
	for e in enemy_ready:
		_begin_enemy_turn(e)
		if state != State.TICK:
			return

	var next: Node = _pick_party_at_gate()
	if next != null:
		_open_window(next, true)
	if not any_parked and not ready_pool.is_empty():
		ready_pool_changed.emit(ready_pool)


func _fill(u: Node, dt: float) -> float:
	var st := CombatantStats.of(u)
	var speed: float = st.gauge_speed() if st != null else 25.0
	var drift: float = sin(battle_time + float(offsets.get(u, 0.0))) * CombatConstants.DRIFT_AMPLITUDE
	var mult: float = 1.0
	var sc := StatusComponent.of(u)
	if sc != null:
		mult = sc.gauge_multiplier()
	return (speed + drift) * dt * mult


func _update_voluntary_windows() -> void:
	# Sera's phase-out counts as voluntary when a party gauge has been parked at 99.0 for 3 s or more.
	var any_long_hold: bool = false
	for u in ready_pool:
		if float(hold_time.get(u, 0.0)) >= CombatConstants.VOLUNTARY_HOLD_S:
			any_long_hold = true
	for u in party:
		var sol := SolidityComponent.of(u)
		if sol != null:
			sol.voluntary_window = any_long_hold
	if hover_sera != null:
		var sol2 := SolidityComponent.of(hover_sera)
		if sol2 != null:
			sol2.voluntary_window = any_long_hold


func _pick_party_at_gate() -> Node:
	var best: Node = null
	var best_g: float = -INF
	var pool: Array = party.duplicate()
	if hover_sera != null and not party.has(hover_sera):
		pool.append(hover_sera)
	for u in pool:
		if not _alive(u) or ready_pool.has(u):
			continue
		var sol := SolidityComponent.of(u)
		if sol != null and sol.is_phased():
			continue
		var g: float = float(gauges.get(u, 0.0))
		if g >= CombatConstants.SYNC_HOLD and g > best_g:
			best_g = g
			best = u
	return best


func _open_window(u: Node, grant_bp: bool) -> void:
	gauges[u] = CombatConstants.SYNC_HOLD
	if grant_bp:
		bank.add(1, true)
		_snapshot_turn(u)
	if not ready_pool.has(u):
		ready_pool.append(u)
		hold_time[u] = 0.0
		ready_pool_changed.emit(ready_pool)
	var st := CombatantStats.of(u)
	if st != null:
		st.is_guarding = false
	active_actor = u
	state = State.COMMAND_WAIT
	command_requested.emit(u)


## Wake a parked ally at any time while the timeline runs.
func request_command(u: Node) -> bool:
	if state != State.TICK or not ready_pool.has(u) or not _alive(u):
		return false
	_open_window(u, false)
	return true


# ------------------------------------------------------------------ party commands

func cmd_sync_hold(actor: Node) -> Dictionary:
	if not _is_turn(actor):
		return _fail("not this actor's turn")
	active_actor = null
	state = State.TICK
	ready_pool_changed.emit(ready_pool)
	return {"ok": true}


func cmd_move(actor: Node, to: Vector3) -> Dictionary:
	if not _is_turn(actor):
		return _fail("not this actor's turn")
	var st := CombatantStats.of(actor)
	var from: Vector3 = position_of(actor)
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var range_m: float = st.move_range if st != null else 6.0
	if flat.length() > range_m + 0.001:
		to = from + flat.normalized() * range_m
	var half: float = CombatConstants.PLANE_SIZE * 0.5
	to.x = clampf(to.x, arena_center.x - half, arena_center.x + half)
	to.z = clampf(to.z, arena_center.z - half, arena_center.z + half)
	_set_position(actor, to)
	return {"ok": true, "position": to}


func cmd_guard(actor: Node) -> Dictionary:
	if not _is_turn(actor):
		return _fail("not this actor's turn")
	state = State.EXECUTING
	var st := CombatantStats.of(actor)
	st.is_guarding = true
	_finish_turn(actor, CombatConstants.GUARD_NEXT_GAUGE)
	_after_party_action({"kind": "guard", "actor": actor})
	return {"ok": true}


func cmd_attack(actor: Node, target: Node, boost: int = 0) -> Dictionary:
	if not _is_turn(actor):
		return _fail("not this actor's turn")
	if not enemies.has(target) or not _alive(target) or _untargetable(target):
		return _fail("invalid target")
	if not bank.can_spend(boost):
		return _fail("not enough BP")
	var st := CombatantStats.of(actor)
	state = State.EXECUTING
	bank.spend(boost)
	if boost > 0:
		boost_used.emit(actor, boost)
	var action := {
		"kind": "attack", "attacker": actor, "casters": [actor], "tags": Array(st.weapon_tags),
		"shape": {"shape": TechDef.Shape.SINGLE, "scale": CombatConstants.BOOST_SCALE[boost]},
		"hits": maxi(1, st.weapon_hits), "base": 1.0, "uses": TechDef.Uses.PHYSICAL, "boost": boost,
		"tech": null, "aim": position_of(target), "primary": target, "synergy": 1.0,
	}
	var info: Dictionary = _resolve_action(action)
	_finish_turn(actor, 0.0)
	_after_party_action(info)
	return {"ok": true, "info": info}


## Use a technique. partners: the Ready Pool allies joining a Dual/Triple (besides the actor).
func cmd_tech(actor: Node, tech_id: StringName, target: Node, aim: Vector3, boost: int = 0, partners: Array = []) -> Dictionary:
	if not _is_turn(actor):
		return _fail("not this actor's turn")
	var tech: TechDef = tech_library.get(tech_id, null)
	if tech == null:
		return _fail("unknown tech %s" % tech_id)
	var casters: Array = [actor]
	for p in partners:
		if p != actor and not casters.has(p):
			casters.append(p)
	var check: Dictionary = _can_cast(actor, tech, casters, boost)
	if not check["ok"]:
		return check
	if tech.target == "enemy" and tech.shape == TechDef.Shape.SINGLE and (target == null or not enemies.has(target) or not _alive(target) or _untargetable(target)):
		return _fail("invalid target")
	if tech.target == "ally" and (target == null or not (party.has(target) or target == hover_sera or bench.has(target))):
		return _fail("invalid ally target")
	state = State.EXECUTING
	# Pay costs, then Boost.
	for c in casters:
		_pay_costs(c, tech)
	bank.spend(boost)
	if boost > 0:
		boost_used.emit(actor, boost)
	if tech.cooldown_turns > 0:
		cooldowns[tech.id] = tech.cooldown_turns
	var synergy: float = tech.synergy_base() * _pair_synergy(casters)
	var aim_point: Vector3 = aim
	if target != null:
		aim_point = position_of(target)
	elif tech.shape == TechDef.Shape.SELF_AURA or tech.target == "self":
		aim_point = position_of(actor)
	var action := {
		"kind": "tech", "attacker": actor, "casters": casters, "tags": Array(tech.tags),
		"shape": {"shape": tech.shape, "radius": tech.radius, "length": tech.length, "width": tech.width,
			"inner_radius": tech.inner_radius, "beams": tech.beams, "scale": tech.shape_scale(boost)},
		"hits": tech.hit_count, "base": tech.base_per_hit, "uses": tech.uses, "boost": boost,
		"tech": tech, "aim": aim_point, "primary": target, "synergy": synergy,
	}
	var info: Dictionary
	if tech.effect != &"" and TechEffects.handles(tech.effect):
		info = TechEffects.apply(self, tech, action)
	elif tech.heal > 0.0 or tech.target in ["ally", "self", "party"]:
		info = _resolve_support(action)
	else:
		info = _resolve_action(action)
	for c in casters:
		_finish_turn(c, 0.0)
	_after_party_action(info)
	return {"ok": true, "info": info}


func cmd_item(actor: Node, item: Dictionary, target: Node) -> Dictionary:
	if not _is_turn(actor):
		return _fail("not this actor's turn")
	state = State.EXECUTING
	var info := {"kind": "item", "actor": actor, "item": item}
	var st := CombatantStats.of(target) if target != null else null
	if st != null:
		if item.has("heal_pct"):
			var amt: int = roundi(float(st.max_hp()) * float(item["heal_pct"]))
			var healed: int = st.heal(amt)
			heal_resolved.emit(actor, target, healed)
		if item.has("mp"):
			st.restore_mp(int(item["mp"]))
		if item.has("revive_pct") and not st.is_alive():
			st.revive(float(item["revive_pct"]))
			unit_revived.emit(target)
		if item.has("cleanse") and StatusComponent.of(target) != null:
			StatusComponent.of(target).cleanse()
	_finish_turn(actor, 0.0)
	_after_party_action(info)
	return {"ok": true, "info": info}


func cmd_swap(actor: Node, incoming: Node) -> Dictionary:
	if not _is_turn(actor):
		return _fail("not this actor's turn")
	if not bench.has(incoming):
		return _fail("not on the bench")
	state = State.EXECUTING
	var idx: int = party.find(actor)
	party[idx] = incoming
	bench.erase(incoming)
	bench.append(actor)
	_set_position(incoming, position_of(actor))
	_init_unit(incoming, CombatConstants.SWAP_GAUGE)
	ready_pool.erase(actor)
	if not swapped_once:
		swapped_once = true
		bank.add(1)
	active_actor = null
	_after_party_action({"kind": "swap", "out": actor, "in": incoming})
	return {"ok": true}


## Swap a KO'd ally out: any ally within 3 m may do it on their turn.
func cmd_swap_koed(actor: Node, koed: Node, incoming: Node) -> Dictionary:
	if not _is_turn(actor):
		return _fail("not this actor's turn")
	if not party.has(koed) or _alive(koed) or not bench.has(incoming):
		return _fail("invalid swap")
	if position_of(actor).distance_to(position_of(koed)) > 3.0:
		return _fail("too far")
	var idx: int = party.find(koed)
	party[idx] = incoming
	bench.erase(incoming)
	bench.append(koed)
	_set_position(incoming, position_of(koed))
	_init_unit(incoming, CombatConstants.SWAP_GAUGE)
	if not swapped_once:
		swapped_once = true
		bank.add(1)
	return {"ok": true}


func cmd_spare(actor: Node, target: Node) -> Dictionary:
	if not _is_turn(actor):
		return _fail("not this actor's turn")
	if not can_spare(target):
		return _fail("cannot spare: must be Broken and at 25% HP or less")
	state = State.EXECUTING
	spared.append(target)
	unit_spared.emit(target)
	_finish_turn(actor, 0.0)
	_after_party_action({"kind": "spare", "actor": actor, "target": target})
	return {"ok": true}


func can_spare(target: Node) -> bool:
	if not enemies.has(target) or not _alive(target) or spared.has(target):
		return false
	var sh := ShieldComponent.of(target)
	var st := CombatantStats.of(target)
	return sh != null and sh.is_broken and st.hp_ratio() <= CombatConstants.SPARE_HP_PCT


func cmd_withdraw(actor: Node) -> Dictionary:
	if not _is_turn(actor):
		return _fail("not this actor's turn")
	if is_boss_battle:
		return _fail("cannot withdraw from a boss")
	var half: float = CombatConstants.PLANE_SIZE * 0.5
	var p: Vector3 = position_of(actor)
	var edge_dist: float = minf(minf(absf(p.x - (arena_center.x - half)), absf(p.x - (arena_center.x + half))), minf(absf(p.z - (arena_center.z - half)), absf(p.z - (arena_center.z + half))))
	if edge_dist > 2.0:
		return _fail("must be within 2 m of the plane's edge")
	state = State.EXECUTING
	for e in enemies:
		if _alive(e) and float(gauges.get(e, 0.0)) > CombatConstants.WITHDRAW_MAX_ENEMY_GAUGE:
			_finish_turn(actor, 0.0)
			_after_party_action({"kind": "withdraw", "ok": false})
			return {"ok": true, "withdrew": false}
	_finish(false, "withdraw")
	return {"ok": true, "withdrew": true}


## Arm the Ens Parry for a guarding ally (§4.2). Perfect if a hit lands within the window.
func arm_parry(ally: Node) -> void:
	var st := CombatantStats.of(ally)
	if st == null or not st.is_guarding:
		return
	parry_armed[ally] = float(parry_frames) / 60.0


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

func available_techs(actor: Node) -> Array[TechDef]:
	var out: Array[TechDef] = []
	var st := CombatantStats.of(actor)
	if st == null:
		return out
	var sc := StatusComponent.of(actor)
	if sc != null and not sc.can_cast_techs():
		return out
	var ready_ids: Array[StringName] = []
	for u in ready_pool:
		if _alive(u):
			ready_ids.append(CombatantStats.of(u).actor_id)
	if not ready_ids.has(st.actor_id):
		ready_ids.append(st.actor_id)
	for id in tech_library.keys():
		var t: TechDef = tech_library[id]
		if not t.involves(st.actor_id):
			continue
		if not _actor_knows(actor, t):
			continue
		if _actor_set_ready(t, ready_ids):
			out.append(t)
	return out


func _actor_set_ready(t: TechDef, ready_ids: Array[StringName]) -> bool:
	for s in t.actor_sets():
		var ok: bool = true
		for req in (s as Array):
			if not ready_ids.has(req):
				ok = false
				break
		if ok:
			# TRUE NULL allies cannot take part in Duals/Triples.
			if t.is_coop():
				for req2 in (s as Array):
					var u: Node = _unit_by_id(req2)
					if u != null and CombatantStats.of(u).true_null:
						return false
			return true
	return false


## The character knows the tech: unlock check against the kit (delegated to a callable when present).
var knows_tech: Callable = Callable()


func _actor_knows(actor: Node, t: TechDef) -> bool:
	if cooldowns.get(t.id, 0) > 0:
		return false
	if t.tier == TechDef.Tier.ULTIMATE and bank.ultimates_blocked:
		return false
	if knows_tech.is_valid():
		return bool(knows_tech.call(actor, t))
	return true


func partners_for(t: TechDef, actor: Node) -> Array:
	var out: Array = []
	var my_id: StringName = CombatantStats.of(actor).actor_id
	for s in t.actor_sets():
		if not (s as Array).has(my_id):
			continue
		var found: Array = []
		var ok: bool = true
		for req in (s as Array):
			if req == my_id:
				continue
			var u: Node = null
			for r in ready_pool:
				if CombatantStats.of(r).actor_id == req and _alive(r):
					u = r
					break
			if u == null:
				ok = false
				break
			found.append(u)
		if ok:
			return found
	return out


## Preview the shave and damage of an action per target (the plate math, §4.6).
func preview(actor: Node, tech: TechDef, target: Node, aim: Vector3, boost: int) -> Dictionary:
	var st := CombatantStats.of(actor)
	var tags: Array = Array(tech.tags) if tech != null else Array(st.weapon_tags)
	var hits: int = tech.hit_count if tech != null else maxi(1, st.weapon_hits)
	var shape: Dictionary = {"shape": TechDef.Shape.SINGLE, "scale": CombatConstants.BOOST_SCALE[boost]}
	if tech != null:
		shape = {"shape": tech.shape, "radius": tech.radius, "length": tech.length, "width": tech.width, "inner_radius": tech.inner_radius, "beams": tech.beams, "scale": tech.shape_scale(boost)}
	var aim_point: Vector3 = position_of(target) if target != null else aim
	var found: Array = TacticalPositioner.targets_in_shape(shape, position_of(actor), aim_point, _enemy_candidates(), _blockers())
	var bonus: int = _flat_bonus(actor, tech, boost)
	var out: Dictionary = {}
	for h in found:
		var e: Node = h["node"]
		var sh := ShieldComponent.of(e)
		var p: Dictionary = {"shave": 0, "breaks": false, "already_broken": false, "after": 0}
		if sh != null:
			p = sh.preview_action(tags, hits * int(h["hits"]), bonus, st.actor_id)
		p["hits"] = hits * int(h["hits"])
		p["damage"] = _estimate_damage(actor, tech, e, boost, hits * int(h["hits"]), int(h["rank"]), tags)
		out[e] = p
	return out


func _estimate_damage(actor: Node, tech: TechDef, target: Node, boost: int, hits: int, rank: int, tags: Array) -> int:
	var a := CombatantStats.of(actor)
	var t := CombatantStats.of(target)
	var sh := ShieldComponent.of(target)
	var uses: int = tech.uses if tech != null else TechDef.Uses.PHYSICAL
	var base: float = tech.base_per_hit if tech != null else 1.0
	var broken: bool = sh != null and sh.is_broken
	var pair: Dictionary = DamagePipeline.pick_stats(uses, a, t, (CombatConstants.BREAK_DEF_MULT if broken else 1.0))
	var ctx := {
		"atk": pair["atk"], "def": pair["def"], "base": base, "synergy": tech.synergy_base() if tech != null else 1.0,
		"party_synergy": party_synergy(), "home_canvas": _home_canvas(actor), "boost_level": boost,
		"weakness": sh != null and sh.hits_weakness(tags), "broken": broken, "falloff_rank": rank,
		"resist": DamagePipeline.resist_factor(tags, sh, t), "variance": 1.0,
		"astral": tags.has(CombatTags.ASTRAL), "target_hp": t.hp, "is_boss": t.kind == "boss",
	}
	var one: Dictionary = DamagePipeline.compute_hit(ctx)
	return int(one["damage"]) * hits


func party_synergy() -> float:
	var sera: Node = _unit_by_id(&"sera")
	if sera == null:
		sera = hover_sera
	if sera == null:
		return CombatConstants.PARTY_SYNERGY_SERA if sera_present_in_story and false else CombatConstants.PARTY_SYNERGY_ABSENT
	var sol := SolidityComponent.of(sera)
	if sol != null and sol.is_phased():
		return CombatConstants.PARTY_SYNERGY_PHASED
	return CombatConstants.PARTY_SYNERGY_SERA


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


func _set_position(u: Node, p: Vector3) -> void:
	if u is Node3D:
		(u as Node3D).global_position = p
	else:
		u.set_meta("battle_pos", p)
	unit_moved.emit(u, p)


func targetable_party() -> Array:
	var out: Array = []
	for u in party:
		if _alive(u) and not _untargetable(u):
			out.append(u)
	return out


func living_enemies() -> Array:
	var out: Array = []
	for e in enemies:
		if _alive(e) and not spared.has(e) and not fled.has(e):
			out.append(e)
	return out


func is_broken(u: Node) -> bool:
	var sh := ShieldComponent.of(u)
	return sh != null and sh.is_broken


func current_taunter(enemy: Node) -> Node:
	# Father Tank: Lavos-spawn target Crono while Sera is below 40% HP.
	var sera: Node = _unit_by_id(&"sera")
	var crono: Node = _unit_by_id(&"crono")
	if sera != null and crono != null and _alive(crono) and _alive(sera):
		var est := CombatantStats.of(enemy)
		if CombatantStats.of(sera).hp_ratio() < 0.4 and est != null and est.tags.has(&"LAVOS"):
			return crono
	for t in taunts.keys():
		if _alive(t) and int(taunts[t].get("turns", 0)) > 0:
			return t
	return null


func taunt_strength(t: Node) -> float:
	if taunts.has(t):
		return float(taunts[t].get("strength", 0.6))
	return 1.0


func add_taunt(t: Node, turns: int, strength: float) -> void:
	taunts[t] = {"turns": turns, "strength": strength}


# ------------------------------------------------------------------ enemy turns

func _begin_enemy_turn(e: Node) -> void:
	var def: EnemyDef = enemy_defs.get(CombatantStats.of(e).actor_id, null)
	_snapshot_turn(e)
	var action: Dictionary = EnemyBrain.choose(self, e, def, rng)
	gauges[e] = 0.0
	turn_counts[e] = int(turn_counts.get(e, 0)) + 1
	var sc := StatusComponent.of(e)
	if sc != null:
		sc.on_turn_taken()
	enemy_action_started.emit(e, action)
	var wind: float = float(action.get("wind_up_s", 0.0))
	if sc != null:
		wind += sc.hitch_seconds()
	if wind > 0.0:
		wind_ups[e] = {"action": action, "left": wind, "total": wind}
		telegraph_started.emit(e, action)
		return
	_execute_enemy_action(e, action)


func _execute_enemy_action(e: Node, action: Dictionary) -> void:
	if not _alive(e):
		return
	var prev: int = state
	state = State.EXECUTING
	var est := CombatantStats.of(e)
	var targets: Array = action.get("targets", [])
	targets = targets.filter(func(t: Node) -> bool: return _alive(t) and not _untargetable(t))
	if targets.is_empty():
		targets = targetable_party()
	var shape_name: String = String(action.get("shape", "SINGLE"))
	var shape_id: int = int(TechDef.SHAPE_NAMES.get(shape_name, TechDef.Shape.SINGLE))
	var aim: Vector3 = action.get("aim", position_of(targets[0]) if not targets.is_empty() else arena_center)
	var hit_list: Array = []
	if shape_id == TechDef.Shape.SINGLE:
		if not targets.is_empty():
			hit_list = [{"node": targets[0], "hits": 1, "rank": 0}]
	else:
		var params := {"shape": shape_id, "radius": float(action.get("radius", 1.0)), "length": float(action.get("length", 0.0)), "width": float(action.get("width", 1.2)), "scale": 1.0}
		hit_list = TacticalPositioner.targets_in_shape(params, position_of(e), aim, _party_candidates(), _blockers())
	var info := {"kind": "enemy", "attacker": e, "action": action, "targets": [], "damage": {}}
	if float(action.get("heal", 0.0)) > 0.0:
		var amt: int = DamagePipeline.compute_heal(est.e_atk, float(action["heal"]), 0)
		var healed: int = est.heal(amt)
		heal_resolved.emit(e, e, healed)
	var bp_steal: int = int(action.get("bp_steal", 0))
	if bp_steal > 0:
		var stolen: int = bank.drain(bp_steal)
		e.set_meta("stolen_bp", int(e.get_meta("stolen_bp", 0)) + stolen)
	for h in hit_list:
		var t: Node = h["node"]
		info["targets"].append(t)
		var dealt: int = _resolve_enemy_hits(e, t, action, int(h["hits"]), int(h["rank"]))
		info["damage"][t] = dealt
	if String(action.get("effect", "")) != "":
		TechEffects.apply_enemy_effect(self, e, action, hit_list)
	action_executed.emit(info)
	_last_action_info = info
	if state == State.EXECUTING:
		state = prev if prev != State.EXECUTING else State.TICK
	_check_end()


func _resolve_enemy_hits(e: Node, t: Node, action: Dictionary, shape_hits: int, rank: int) -> int:
	var est := CombatantStats.of(e)
	var tst := CombatantStats.of(t)
	var tags: Array = action.get("tags", [])
	var hits: int = maxi(1, int(action.get("hits", 1))) * maxi(1, shape_hits)
	var total: int = 0
	var telegraphed: bool = float(action.get("wind_up_s", 0.0)) > 0.0
	for i in hits:
		if not tst.is_alive():
			break
		# Evasion: LUK × 0.05% + Trauma Silence + status, against non-telegraphed hits only.
		if not telegraphed:
			var evade: float = tst.luk * 0.0005 + _evasion_bonus(t)
			if rng.randf() < evade:
				strike_resolved.emit(e, t, {"damage": 0, "evaded": true, "tags": tags})
				continue
		# Ens Parry: a perfect parry negates the hit and leaves an Ens ring.
		if tst.is_guarding and parry_armed.has(t):
			parry_armed.erase(t)
			ens_rings[t] = {"left": CombatConstants.ENS_RING_DEBT_NULL_S, "shave": 1}
			var td := TimeDebtComponent.of(t)
			if td != null:
				td.debt_null_left = CombatConstants.ENS_RING_DEBT_NULL_S
			parry_result.emit(t, true)
			strike_resolved.emit(e, t, {"damage": 0, "parried": true, "tags": tags})
			continue
		var uses: int = int(TechDef.USES_NAMES.get(String(action.get("uses", "BEST")), TechDef.Uses.BEST))
		var tsc := StatusComponent.of(t)
		var pair: Dictionary = DamagePipeline.pick_stats(uses, est, tst, (tsc.def_multiplier(false) if tsc != null else 1.0))
		var ctx := {
			"atk": pair["atk"], "def": pair["def"], "base": float(action.get("power", 1.0)),
			"falloff_rank": rank, "variance": _variance(),
			"vulnerable": tst.is_vulnerable_to(tags), "resist": (CombatConstants.RESIST_MULT if tst.is_resistant_to(tags) else 1.0),
			"taken_mult": (tsc.damage_taken_multiplier() if tsc != null else 1.0),
		}
		if tst.null_shield or tst.true_null:
			ctx["taken_mult"] = float(ctx["taken_mult"]) * (0.8 if tst.null_shield else 1.0)
		var r: Dictionary = DamagePipeline.compute_hit(ctx)
		var dmg: int = int(r["damage"])
		# Shared damage along a Mycelia net (15%) and Marle's Ward are handled by the status hooks.
		if tsc != null and tsc.has(&"ward"):
			dmg = roundi(float(dmg) * 0.5)
			tsc.remove(&"ward")
		if tsc != null and tsc.has(&"glass_ward"):
			dmg = roundi(float(dmg) * 0.5)
			tsc.remove_stacks(&"glass_ward", 1)
		var vulnerable_breaks_guard: bool = bool(ctx["vulnerable"])
		if party_hp_floor > 0 and party.has(t):
			# zero-fail fights (the 999 Shard Doll): nobody here can be knocked out
			dmg = mini(dmg, maxi(0, tst.hp - party_hp_floor))
		var dealt: int = tst.apply_damage(dmg, vulnerable_breaks_guard)
		total += dealt
		_apply_enemy_status(action, t)
		strike_resolved.emit(e, t, {"damage": dealt, "tags": tags, "crit": r["crit"]})
		_after_damage(t)
	return total


## Passives that fire when a party member is hurt: Krona's gourd, the wrist-seam check.
func _after_damage(t: Node) -> void:
	var st := CombatantStats.of(t)
	if st == null or not st.is_alive():
		return
	if st.actor_id == &"krona" and st.hp_ratio() < 0.25 and not t.get_meta("sipped_this_turn", false):
		t.set_meta("sipped_this_turn", true)
		st.heal(roundi(float(st.max_hp()) * 0.20))
		t.set_meta("corruption", float(t.get_meta("corruption", 0.0)) + 5.0)
		battle_message.emit("Krona drinks from the gourd.")
	if st.actor_id == &"crono" and _crono_galaxy(t) and not t.get_meta("concerned_fired", false):
		t.set_meta("concerned_fired", true)
		var sc := StatusComponent.of(t)
		if sc != null:
			sc.add(&"concerned_target", -1.0, -1)
		truth_moment.emit(&"galaxy_reveal")


func _apply_enemy_status(action: Dictionary, t: Node) -> void:
	var sid: String = String(action.get("status", ""))
	if sid == "":
		return
	var sc := StatusComponent.of(t)
	if sc == null:
		return
	var st := CombatantStats.of(t)
	var resist_chance: float = minf(0.30, st.luk * 0.001)
	if rng.randf() < resist_chance:
		return
	if rng.randf() > float(action.get("status_chance", 1.0)):
		return
	sc.add(StringName(sid), float(action.get("status_seconds", -1.0)), int(action.get("status_turns", -1)))


func _evasion_bonus(t: Node) -> float:
	var st := CombatantStats.of(t)
	var bonus: float = 0.0
	if st.actor_id == &"crono":
		bonus += 0.10
		if st.hp_ratio() < 0.5:
			bonus += 0.10
	var sc := StatusComponent.of(t)
	if sc != null:
		bonus += sc.evasion_bonus()
	return bonus


# ------------------------------------------------------------------ party resolution

func _resolve_action(action: Dictionary) -> Dictionary:
	var attacker: Node = action["attacker"]
	var tech: TechDef = action.get("tech", null)
	var boost: int = int(action.get("boost", 0))
	var tags: Array = action["tags"]
	var casters: Array = action.get("casters", [attacker])
	var shape: Dictionary = action["shape"]
	var aim: Vector3 = action["aim"]
	var extra: Dictionary = {}
	if casters.size() >= 2:
		extra["second_origin"] = position_of(casters[1])
	if casters.size() >= 3:
		extra["third_origin"] = position_of(casters[2])
	var found: Array
	if int(shape["shape"]) == TechDef.Shape.SINGLE:
		var primary: Node = action.get("primary", null)
		found = [{"node": primary, "hits": 1, "rank": 0}] if primary != null else []
	else:
		found = TacticalPositioner.targets_in_shape(shape, position_of(attacker), aim, _enemy_candidates(), _blockers(), extra)
	var info := {"kind": action["kind"], "attacker": attacker, "casters": casters, "tech": tech, "boost": boost, "targets": [], "damage": {}, "shave": {}, "breaks": [], "tags": tags}
	var bonus: int = _flat_bonus(attacker, tech, boost)
	var a_stats := CombatantStats.of(attacker)
	# Use the best relevant attack stat among the actors (§8.7).
	var best_caster: CombatantStats = a_stats
	for c in casters:
		var cs := CombatantStats.of(c)
		if cs != null and maxf(cs.p_atk, cs.e_atk) > maxf(best_caster.p_atk, best_caster.e_atk):
			best_caster = cs
	var ens: bool = ens_rings.has(attacker)
	if ens:
		bonus += int(ens_rings[attacker].get("shave", 1))
		ens_rings.erase(attacker)
	var perfect: bool = bool(_perfect_frame_pending.get(attacker, false))
	_perfect_frame_pending.erase(attacker)
	var hits_per: int = int(action.get("hits", 1))
	var flicker: bool = false
	if a_stats.actor_id == &"sera":
		var sol := SolidityComponent.of(attacker)
		flicker = sol != null and sol.ghost_layers() >= 3
	var filter: Callable = action.get("target_filter", Callable())
	var push_per_hit: float = float(action.get("gauge_push_per_hit", 0.0))
	var bonus_if_status: Dictionary = action.get("bonus_if_status", {})
	for h in found:
		var t: Node = h["node"]
		if t == null or not _alive(t):
			continue
		if filter.is_valid() and not bool(filter.call(t)):
			continue
		info["targets"].append(t)
		var tst := CombatantStats.of(t)
		var sh := ShieldComponent.of(t)
		var tsc := StatusComponent.of(t)
		var total: int = 0
		var shaved: int = 0
		var bonus_left: int = bonus
		for sid in bonus_if_status.keys():
			if tsc != null and tsc.has(sid):
				bonus_left += int(bonus_if_status[sid])
		var n_hits: int = hits_per * maxi(1, int(h["hits"]))
		var in_puddle: bool = tags.has(CombatTags.ASTRAL) and fields.has_kind_at(&"watercolour_puddle", position_of(t))
		if in_puddle:
			bonus_left += 1
		for i in n_hits:
			if not tst.is_alive():
				break
			var res := {"shaved": 0, "hit_weakness": false, "caused_break": false, "matched": false}
			var was_broken: bool = sh != null and sh.is_broken
			if sh != null:
				res = sh.apply_strike(tags, bonus_left, attacker, a_stats.actor_id)
				shaved += int(res["shaved"])
				if res["matched"]:
					bonus_left = 0
				if res["caused_break"]:
					info["breaks"].append(t)
					last_break_signature = sh.break_signature
			var broken_now: bool = sh != null and sh.is_broken
			if sh != null and sh.shield_only and not broken_now:
				strike_resolved.emit(attacker, t, {"damage": 0, "shield_only": true, "shave": res["shaved"], "tags": tags})
				continue
			var pair: Dictionary = DamagePipeline.pick_stats(int(action.get("uses", TechDef.Uses.BEST)), best_caster, tst,
				(CombatConstants.BREAK_DEF_MULT if (was_broken or broken_now) else 1.0) * (tsc.def_multiplier(_is_metal(t)) if tsc != null else 1.0))
			var ctx := {
				"atk": pair["atk"], "def": pair["def"], "base": float(action.get("base", 1.0)),
				"synergy": float(action.get("synergy", 1.0)) * _crit_or_guaranteed(action),
				"party_synergy": party_synergy(), "home_canvas": _home_canvas(attacker),
				"boost_level": boost, "in_field": _in_divinity_or_tether(attacker),
				"weakness": bool(res["hit_weakness"]), "broken": was_broken or broken_now,
				"crit": bool(action.get("guaranteed_crit", false)) or _oil_drinker_crit(attacker, t),
				"perfect": perfect, "falloff_rank": int(h["rank"]), "variance": _variance(),
				"resist": DamagePipeline.resist_factor(tags, sh, tst), "ledge": 0.0,
				"taken_mult": (tsc.damage_taken_multiplier() if tsc != null else 1.0),
				"astral": tags.has(CombatTags.ASTRAL), "target_hp": tst.hp, "is_boss": tst.kind == "boss",
				"flicker_bonus": flicker,
			}
			if tsc != null and tsc.has(&"nulled") and tags.has(CombatTags.ASTRAL) and _crono_galaxy(attacker):
				ctx["base"] = float(ctx["base"]) * 1.5
			var r: Dictionary = DamagePipeline.compute_hit(ctx)
			var dmg: int = int(r["damage"])
			if tags.has(CombatTags.NULL) and not bool(tsc != null and tsc.has(&"nulled_weakness")):
				# NULL is true damage: ignores DEF and resists, never a weakness multiplier.
				dmg = maxi(1, roundi(0.8 * float(pair["atk"]) * float(action.get("base", 1.0)) * CombatConstants.BOOST_POWER[boost] * float(action.get("synergy", 1.0))))
			var dealt: int
			if bool(r["absorbed"]):
				dealt = -tst.heal(dmg)
			elif undamageable.has(t):
				dealt = 0
			else:
				dealt = tst.apply_damage(dmg, true)
			total += maxi(0, dealt)
			if float(r["gauge_push"]) > 0.0 and not broken_now:
				gauges[t] = maxf(0.0, float(gauges.get(t, 0.0)) - float(r["gauge_push"]))
			if push_per_hit > 0.0 and not broken_now:
				gauges[t] = maxf(0.0, float(gauges.get(t, 0.0)) - push_per_hit)
			if tags.has(CombatTags.TACHYON) and rng.randf() < 0.25 and not broken_now:
				gauges[t] = maxf(0.0, float(gauges.get(t, 0.0)) - 10.0)
			if tags.has(CombatTags.HZ) and wind_ups.has(t) and rng.randf() < 0.15:
				wind_ups.erase(t)
				telegraph_ended.emit(t)
			strike_resolved.emit(attacker, t, {"damage": dealt, "shave": res["shaved"], "weakness": res["hit_weakness"], "break": res["caused_break"], "crit": r["crit"], "tags": tags, "absorbed": r["absorbed"]})
		info["damage"][t] = total
		info["shave"][t] = shaved
		if boost >= 2 and tst.is_alive():
			_apply_lv2_debuff(tech, tags, t)
	if boost >= 4:
		_leave_residual(tech, tags, action, found)
	_canvas_clash(tags, aim, shape, attacker)
	if token_duplicate_active != attacker:
		last_actions[attacker] = action.duplicate()
	action_executed.emit(info)
	_last_action_info = info
	return info


func _resolve_support(action: Dictionary) -> Dictionary:
	var attacker: Node = action["attacker"]
	var tech: TechDef = action["tech"]
	var boost: int = int(action.get("boost", 0))
	var casters: Array = action.get("casters", [attacker])
	var a_stats := CombatantStats.of(attacker)
	var targets: Array = []
	match tech.target:
		"self":
			targets = [attacker]
		"party":
			targets = party.filter(func(u: Node) -> bool: return _alive(u))
		"ally":
			if action.get("primary", null) != null:
				targets = [action["primary"]]
		_:
			var shape: Dictionary = action["shape"]
			if int(shape["shape"]) == TechDef.Shape.SELF_AURA or int(shape["shape"]) == TechDef.Shape.CIRCLE:
				for h in TacticalPositioner.targets_in_shape(shape, position_of(attacker), action["aim"], _party_candidates(true)):
					targets.append(h["node"])
			elif action.get("primary", null) != null:
				targets = [action["primary"]]
	var info := {"kind": "support", "attacker": attacker, "casters": casters, "tech": tech, "boost": boost, "targets": targets, "heal": {}}
	for t in targets:
		var tst := CombatantStats.of(t)
		if tst == null:
			continue
		if tech.heal > 0.0:
			var tsc := StatusComponent.of(t)
			var mult: float = tsc.healing_multiplier() if tsc != null else 1.0
			if tst.actor_id == &"crono" and tsc != null and tsc.has(&"concerned_target"):
				mult *= 1.0
			var amt: int = DamagePipeline.compute_heal(a_stats.e_atk, tech.heal, boost, mult)
			var healed: int = 0
			if tst.is_alive():
				healed = tst.heal(amt)
			info["heal"][t] = healed
			heal_resolved.emit(attacker, t, healed)
		if tech.lv2_debuff != &"" and boost >= 2:
			var tsc2 := StatusComponent.of(t)
			if tsc2 != null:
				tsc2.add(tech.lv2_debuff, -1.0, 2)
	action_executed.emit(info)
	_last_action_info = info
	return info


func _flat_bonus(_actor: Node, tech: TechDef, boost: int) -> int:
	var b: int = 0
	if boost >= 3:
		b += CombatConstants.BOOST_LV3_SHAVE_BONUS
	if tech != null:
		b += tech.flat_shave_bonus
	return b


func _pair_synergy(casters: Array) -> float:
	var ids: Array[StringName] = []
	var homes: Dictionary = {}
	for c in casters:
		var st := CombatantStats.of(c)
		ids.append(st.actor_id)
		homes[st.home_universe] = true
	var s: float = 1.0
	if ids.has(&"crono") and ids.has(&"krona"):
		s *= CombatConstants.SYNERGY_CRONO_KRONA
	if ids.has(&"crono") and ids.has(&"sera") and casters.size() == 2:
		s *= CombatConstants.SYNERGY_CRONO_SERA
	if ids.has(&"vaelos_child"):
		s *= CombatConstants.SYNERGY_VAELOS_CHILD
	if casters.size() == 3 and homes.size() == 3:
		s *= CombatConstants.SYNERGY_THREE_UNIVERSES
	return s


func _crit_or_guaranteed(_action: Dictionary) -> float:
	return 1.0


func _oil_drinker_crit(attacker: Node, target: Node) -> bool:
	var st := CombatantStats.of(attacker)
	if st.actor_id != &"krona" or not attacker.has_meta("oil_drinker_plus"):
		return false
	var tst := CombatantStats.of(target)
	if tst.tags.has(&"LAVOS") or _is_metal(target):
		return rng.randf() < 0.25
	return false


func _crono_galaxy(actor: Node) -> bool:
	var td := TimeDebtComponent.of(actor)
	var st := CombatantStats.of(actor)
	if td == null or st == null:
		return false
	return td.crack_state(float(st.hp) / float(st.base_max_hp)) == TimeDebtComponent.CrackState.GALAXY


func _home_canvas(actor: Node) -> float:
	var st := CombatantStats.of(actor)
	if st == null or st.actor_id == &"sera":
		return 1.0
	return 1.0 + CombatConstants.HOME_CANVAS_BONUS if st.home_universe == universe and st.team == CombatantStats.Team.PARTY else 1.0


func _in_divinity_or_tether(actor: Node) -> bool:
	var sc := StatusComponent.of(actor)
	return sc != null and (sc.has(&"tethered") or sc.has(&"divinity"))


func _is_metal(u: Node) -> bool:
	var st := CombatantStats.of(u)
	return st != null and (st.tags.has(&"FERRO") or st.tags.has(&"GUN") or bool(u.get_meta("is_metal", false)))


func _apply_lv2_debuff(tech: TechDef, tags: Array, t: Node) -> void:
	var sc := StatusComponent.of(t)
	if sc == null:
		return
	var id: StringName = tech.lv2_debuff if tech != null else &""
	if id == &"":
		var element: StringName = tech.element_tag() if tech != null else CombatTags.element_of(tags[0] if not tags.is_empty() else &"")
		id = TechEffects.default_lv2(element)
	if id == &"":
		return
	var data: Dictionary = {}
	if id == &"corroded":
		data["def"] = true
	sc.add(id, -1.0, 2, 1, data)


func _leave_residual(tech: TechDef, tags: Array, action: Dictionary, found: Array) -> void:
	var kind: StringName = tech.lv4_field if tech != null else &""
	if kind == &"":
		var element: StringName = tech.element_tag() if tech != null else CombatTags.element_of(tags[0] if not tags.is_empty() else &"")
		kind = BattleFields.default_field_for(element)
	if kind == &"":
		return
	var shape: Dictionary = action["shape"]
	var f: Dictionary
	match int(shape["shape"]):
		TechDef.Shape.LINE_PIERCE:
			var aim: Vector3 = Vector3(action["aim"].x - position_of(action["attacker"]).x, 0.0, action["aim"].z - position_of(action["attacker"]).z)
			f = fields.add_line(kind, position_of(action["attacker"]), aim, float(shape.get("length", 6.0)) * float(shape.get("scale", 1.0)), float(shape.get("width", 1.2)), CombatConstants.RESIDUAL_FIELD_S, 0)
		TechDef.Shape.SINGLE:
			var p: Vector3 = position_of(found[0]["node"]) if not found.is_empty() else action["aim"]
			f = fields.add(kind, p, 2.0, CombatConstants.RESIDUAL_FIELD_S, 0)
		_:
			var center: Vector3 = position_of(action["attacker"]) if int(shape["shape"]) == TechDef.Shape.SELF_AURA else action["aim"]
			f = fields.add(kind, center, float(shape.get("radius", 2.0)) * float(shape.get("scale", 1.0)), CombatConstants.RESIDUAL_FIELD_S, 0)
	field_added.emit(f)


## Elemental Canvas Clash: ASTRAL burns ink pools to golden watercolour; RUIN turns paper to ash (§9.6).
func _canvas_clash(tags: Array, aim: Vector3, shape: Dictionary, attacker: Node) -> void:
	var radius: float = float(shape.get("radius", 1.5)) * float(shape.get("scale", 1.0))
	if int(shape["shape"]) == TechDef.Shape.SINGLE:
		radius = 1.5
	var center: Vector3 = aim
	if int(shape["shape"]) == TechDef.Shape.SELF_AURA:
		center = position_of(attacker)
	if tags.has(CombatTags.ASTRAL):
		var n: int = fields.convert(&"ink_pool", &"golden_patch", center, radius, -1.0)
		if n > 0:
			battle_message.emit("Astral light burns the ink to gold.")
		fields.convert(&"vhs_fog", &"cleared", center, 3.0, 10.0)
	if tags.has(CombatTags.RUIN):
		fields.convert(&"paper", &"ash_field", center, radius, -1.0)
	if tags.has(CombatTags.MYCELIA):
		fields.convert(&"ash_field", &"spore_mat", center, radius, -1.0)
		fields.convert(&"oil", &"spore_mat", center, radius, -1.0)
	if tags.has(CombatTags.NULL):
		fields.blank(center, radius, 8.0)


## Snapshot a unit's state at the start of its turn (for Rewind).
func _snapshot_turn(u: Node) -> void:
	var st := CombatantStats.of(u)
	var sc := StatusComponent.of(u)
	turn_snapshots[u] = {
		"hp": st.hp if st != null else 0,
		"gauge": float(gauges.get(u, 0.0)),
		"pos": position_of(u),
		"statuses": sc.ids() if sc != null else [],
	}


## Restore a unit to its last turn start: HP, gauge, position, statuses gained since (§3.6).
func rewind_unit(u: Node, hp_only: bool = false) -> bool:
	if not turn_snapshots.has(u):
		return false
	var snap: Dictionary = turn_snapshots[u]
	var st := CombatantStats.of(u)
	if st != null:
		if st.hp <= 0 and int(snap["hp"]) > 0:
			st.revive(0.01)
			unit_revived.emit(u)
		st.hp = clampi(int(snap["hp"]), 0, st.max_hp())
		st.hp_changed.emit(st.hp, st.max_hp())
	if hp_only:
		return true
	if not ready_pool.has(u):
		gauges[u] = float(snap["gauge"])
	_set_position(u, snap["pos"])
	var sc := StatusComponent.of(u)
	if sc != null:
		for id in sc.ids():
			if not (snap["statuses"] as Array).has(id):
				sc.remove(id)
	return true


## Every ally gauge −30%, then the ally nearest a full gauge takes a free second turn that copies
## its last action exactly (§3.6, §10.2). Returns the duplicated ally, or null.
func borrowed_future(sera: Node) -> Node:
	var best: Node = null
	var best_g: float = -INF
	for u in party:
		if u == sera or not _alive(u):
			continue
		var g: float = float(gauges.get(u, 0.0))
		if g > best_g:
			best_g = g
			best = u
	for u in party:
		if u == sera:
			continue
		gauges[u] = maxf(0.0, float(gauges.get(u, 0.0)) - CombatConstants.GAUGE_MAX * CombatConstants.BORROWED_FUTURE_GAUGE_PUSH)
	if best == null:
		return null
	if last_actions.has(best):
		var copy: Dictionary = (last_actions[best] as Dictionary).duplicate()
		copy["boost"] = int(copy.get("boost", 0))
		copy["duplicate"] = true
		token_duplicate_active = best
		var prev_var: float = fixed_variance
		if prev_var <= 0.0:
			fixed_variance = 1.0
		_resolve_action(copy)
		fixed_variance = prev_var
		token_duplicate_active = null
		truth_moment.emit(&"token_duplicate")
	else:
		gauges[best] = CombatConstants.SYNC_HOLD
	return best


# ------------------------------------------------------------------ costs

func _can_cast(actor: Node, tech: TechDef, casters: Array, boost: int) -> Dictionary:
	if not available_techs(actor).has(tech):
		return _fail("tech not available")
	if boost < tech.min_boost:
		return _fail("needs Boost Lv%d" % tech.min_boost)
	if not bank.can_spend(boost):
		return _fail("not enough BP")
	var needed: int = tech.actor_count_expected()
	if tech.tier != TechDef.Tier.ULTIMATE and casters.size() != needed:
		return _fail("needs %d actors" % needed)
	for c in casters:
		if c != actor and not ready_pool.has(c):
			return _fail("partner not in the Ready Pool")
		var st := CombatantStats.of(c)
		var cost: Dictionary = tech.cost_for(st.actor_id)
		var mp: int = int(cost.get("mp", 0))
		if mp > 0 and not st.can_pay_mp(mp):
			return _fail("%s lacks MP" % st.actor_id)
		var sc := StatusComponent.of(c)
		if sc != null and sc.has(&"grief") and st.mp < st.max_mp / 2 and boost > 1:
			return _fail("Grief: cannot spend more than 1 BP")
		if cost.has("bp_all") and bank.bp < int(cost["bp_all"]):
			return _fail("needs %d BP" % int(cost["bp_all"]))
	return {"ok": true}


func _pay_costs(c: Node, tech: TechDef) -> void:
	var st := CombatantStats.of(c)
	var cost: Dictionary = tech.cost_for(st.actor_id)
	var mp: int = int(cost.get("mp", 0))
	if mp > 0:
		var sc := StatusComponent.of(c)
		if sc != null and sc.has(&"ash_feeder") and tech.tags.has(CombatTags.RUIN):
			mp = roundi(float(mp) * 0.8)
		st.spend_mp(mp)
	var td := TimeDebtComponent.of(c)
	if td != null:
		var strain: float = float(cost.get("strain_pct", 0.0)) / 100.0
		if strain > 0.0 and c.get_meta("next_astral_free", false):
			c.remove_meta("next_astral_free")
			strain = 0.0
		if strain > 0.0:
			var sc2 := StatusComponent.of(c)
			if sc2 != null and sc2.has(&"core_lattice"):
				strain *= 0.5
			if sc2 != null and sc2.has(&"guilt_halo"):
				strain *= 0.5
			if c.has_meta("fall_break"):
				strain *= 0.5
				c.remove_meta("fall_break")
			if fields.has_kind_at(&"golden_patch", position_of(c)) and not c.has_meta("golden_cast_used"):
				c.set_meta("golden_cast_used", true)
				strain = 0.0
			td.pay_battle_strain(strain)
			st.clamp_to_ceiling()
		var camp: float = float(cost.get("camp_strain_pct", 0.0)) / 100.0
		if camp > 0.0:
			td.pay_camp_strain(camp)
			st.clamp_to_ceiling()
		var integ: float = float(cost.get("integrity", 0.0))
		if integ > 0.0:
			td.pay_integrity(integ)
			st.clamp_to_ceiling()
	var sol := SolidityComponent.of(c)
	if sol != null:
		var pct: float = float(cost.get("solidity_pct", 0.0))
		if pct > 0.0:
			if tech.id == &"borrowed_future" and sol.solidity < 50.0:
				pct += 10.0
			if c.has_meta("fall_break"):
				pct *= 0.5
				c.remove_meta("fall_break")
			spend_solidity(c, pct)
	if cost.has("bp_all"):
		bank.spend_all()
	if cost.has("hp_to_one"):
		st.apply_self_cost(st.hp - 1)
		var sc3 := StatusComponent.of(c)
		if sc3 != null:
			sc3.add(&"fragile", -1.0, 2)


## Spend Sera's solidity; a hairline Crono pays 5% max HP per Rewind/slip; overflow lands on Crono.
func spend_solidity(sera: Node, pct: float) -> Dictionary:
	var sol := SolidityComponent.of(sera)
	if sol == null:
		return {}
	var was_phased: bool = sol.is_phased()
	var r: Dictionary = sol.spend(pct)
	if float(r["overflow"]) > 0.0:
		var crono: Node = _unit_by_id(&"crono")
		var td := TimeDebtComponent.of(crono)
		if td != null:
			td.pay_battle_strain(float(r["overflow"]) / 100.0)
			CombatantStats.of(crono).clamp_to_ceiling()
	if not was_phased and sol.is_phased():
		sera_phase_changed.emit(true)
		truth_moment.emit(&"phase_out")
	return r


## Every Sera Rewind or Chronoslip costs a hairline-or-worse Crono 5% of his max HP (cannot KO).
func crono_pays_for_slip() -> void:
	var crono: Node = _unit_by_id(&"crono")
	if crono == null:
		return
	var td := TimeDebtComponent.of(crono)
	var st := CombatantStats.of(crono)
	if td == null or st == null:
		return
	if td.is_hairline_or_worse(float(st.hp) / float(st.base_max_hp)):
		st.apply_self_cost(roundi(float(st.max_hp()) * CombatConstants.CRONO_HAIRLINE_REWIND_HP))
		strike_resolved.emit(crono, crono, {"damage": 0, "slip_tax": true, "tags": []})


# ------------------------------------------------------------------ turn bookkeeping

func _finish_turn(actor: Node, next_gauge: float) -> void:
	gauges[actor] = next_gauge
	ready_pool.erase(actor)
	hold_time[actor] = 0.0
	turn_counts[actor] = int(turn_counts.get(actor, 0)) + 1
	if active_actor == actor:
		active_actor = null
	var sc := StatusComponent.of(actor)
	if sc != null:
		sc.on_turn_taken()
	if actor.has_meta("sipped_this_turn"):
		actor.remove_meta("sipped_this_turn")
	if taunts.has(actor):
		taunts[actor]["turns"] = int(taunts[actor]["turns"]) - 1
		if int(taunts[actor]["turns"]) <= 0:
			taunts.erase(actor)
			if actor.get_meta("shogun_command_pending", false) and _alive(actor):
				actor.remove_meta("shogun_command_pending")
				for u in party:
					var usc := StatusComponent.of(u)
					if usc != null:
						usc.add(&"ruin_infused", -1.0, 1)
	for id in cooldowns.keys():
		cooldowns[id] = int(cooldowns[id]) - 1
		if int(cooldowns[id]) <= 0:
			cooldowns.erase(id)
	var sol := SolidityComponent.of(actor)
	if sol != null and not actor.get_meta("used_tachyon_this_turn", false):
		sol.on_turn_without_tachyon()
	if actor.has_meta("used_tachyon_this_turn"):
		actor.remove_meta("used_tachyon_this_turn")
	bank.clamp_overflow()
	ready_pool_changed.emit(ready_pool)


func _after_party_action(_info: Dictionary) -> void:
	for u in ready_pool.duplicate():
		if not _alive(u):
			ready_pool.erase(u)
	if _check_end():
		return
	# A parked ally gets the floor back after any party action (no deadlock).
	if not ready_pool.is_empty():
		var u: Node = ready_pool[0]
		_open_window(u, false)
		return
	state = State.TICK


func _check_end() -> bool:
	if state == State.VICTORY or state == State.DEFEAT or state == State.IDLE:
		return true
	if living_enemies().is_empty():
		_finish(true, "victory")
		return true
	var standing: bool = false
	for u in party:
		if _alive(u):
			var sol := SolidityComponent.of(u)
			if sol != null and sol.is_phased():
				continue
			standing = true
	if not standing:
		_finish(false, "defeat")
		return true
	return false


func _on_unit_broken(breaker: Node, unit: Node) -> void:
	gauges[unit] = 0.0
	wind_ups.erase(unit)
	if unit.has_method("on_break"):
		unit.call("on_break")
	unit_broken.emit(unit, breaker)
	var sc := StatusComponent.of(unit)
	if sc != null and sc.has(&"spore_tag"):
		ShieldComponent.of(unit).extend_lock(1.2)
	# Enemies that Break inside a Divinity Field are silenced 15 s.
	if sc != null and fields.has_kind_at(&"divinity_field", position_of(unit)):
		sc.add(&"silence", 15.0)


func _on_unit_defeated(unit: Node) -> void:
	ko_order.append(unit)
	unit_koed.emit(unit)
	if party.has(unit):
		ready_pool.erase(unit)
		var sc := StatusComponent.of(unit)
		if prometheus_available and not prometheus_used and (sc == null or sc.stacks(&"ruin") < 2):
			var td := TimeDebtComponent.of(unit)
			if td == null or td.ruin_stacks < 2:
				prometheus_used = true
				bank.charge_or_owe(1)
				CombatantStats.of(unit).revive(CombatConstants.PROMETHEUS_REVIVE_HP)
				unit_revived.emit(unit)
				battle_message.emit("The Prometheus Core fires.")


# ------------------------------------------------------------------ fields, blights, rings

func _tick_fields(dt: float) -> void:
	fields.tick(dt)
	for f in fields.fields:
		f["accum"] = float(f["accum"]) + dt
		match f["kind"]:
			&"golden_patch":
				if float(f["accum"]) >= 5.0:
					f["accum"] = 0.0
					for u in party:
						if _alive(u) and fields._inside(f, position_of(u)):
							CombatantStats.of(u).restore_mp(2)
			&"spore_mat":
				if float(f["accum"]) >= 2.0:
					f["accum"] = 0.0
					for u in party:
						if _alive(u) and fields._inside(f, position_of(u)):
							var st := CombatantStats.of(u)
							st.heal(roundi(float(st.max_hp()) * 0.02))
			&"ash_field":
				if float(f["accum"]) >= 2.0:
					f["accum"] = 0.0
					for e in enemies:
						if _alive(e) and fields._inside(f, position_of(e)):
							var sh := ShieldComponent.of(e)
							if sh != null and sh.temp_plates > 0:
								sh.temp_plates -= 1
							var sc := StatusComponent.of(e)
							if sc != null:
								sc.add(&"ash_field", 2.5)
			&"divinity_field":
				if float(f["accum"]) >= CombatConstants.DIVINITY_PERIOD_S:
					f["accum"] = 0.0
					var team: int = int(f.get("owner_team", 0))
					var owners: Array = party if team == 0 else enemies
					for u in owners:
						if _alive(u) and fields._inside(f, position_of(u)):
							var st2 := CombatantStats.of(u)
							var sh2 := ShieldComponent.of(u)
							if sh2 != null:
								sh2.temp_plates = mini(sh2.temp_plates + 1, maxi(1, roundi(float(st2.max_hp()) * CombatConstants.DIVINITY_CAP / 50.0)))
							else:
								st2.temp_shield = mini(st2.temp_shield + 1, maxi(1, roundi(float(st2.max_hp()) * CombatConstants.DIVINITY_CAP)))
			&"amber_pool":
				if float(f["accum"]) >= 1.0:
					f["accum"] = 0.0
					for e in enemies:
						if _alive(e) and fields._inside(f, position_of(e)):
							var sc2 := StatusComponent.of(e)
							if sc2 != null:
								sc2.add(&"mercury_slow", 1.5)


func _tick_oil_blight(dt: float) -> void:
	if not oil_blight:
		return
	oil_blight_accum += dt
	while oil_blight_accum >= CombatConstants.OIL_BLIGHT_PERIOD_S:
		oil_blight_accum -= CombatConstants.OIL_BLIGHT_PERIOD_S
		bank.drain(1)


func set_oil_blight(on: bool) -> void:
	oil_blight = on
	bank.ultimates_blocked = on
	if not on:
		oil_blight_accum = 0.0


func _tick_ens_rings(dt: float) -> void:
	for u in ens_rings.keys():
		ens_rings[u]["left"] = float(ens_rings[u]["left"]) - dt
	for u in parry_armed.keys():
		parry_armed[u] = float(parry_armed[u]) - dt
		if float(parry_armed[u]) <= 0.0:
			parry_armed.erase(u)
			var st := CombatantStats.of(u)
			if st != null and universe == 1:
				var sc := StatusComponent.of(u)
				if sc != null:
					sc.add(&"ink_blot", 3.0)
			parry_result.emit(u, false)


func mark_perfect_frame(actor: Node) -> void:
	_perfect_frame_pending[actor] = true


# ------------------------------------------------------------------ helpers

func _is_turn(actor: Node) -> bool:
	return state == State.COMMAND_WAIT and actor == active_actor


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}


func _all_units() -> Array:
	var all: Array = []
	all.append_array(party)
	all.append_array(enemies)
	if hover_sera != null and not party.has(hover_sera):
		all.append(hover_sera)
	return all


func _alive(u: Node) -> bool:
	if not is_instance_valid(u):
		return false
	var st := CombatantStats.of(u)
	return st != null and st.is_alive() and not spared.has(u) and not fled.has(u)


func _untargetable(u: Node) -> bool:
	var sc := StatusComponent.of(u)
	if sc != null and sc.is_untargetable():
		return true
	var sol := SolidityComponent.of(u)
	return sol != null and sol.is_phased()


func _unit_by_id(id: StringName) -> Node:
	for u in party:
		var st := CombatantStats.of(u)
		if st != null and st.actor_id == id:
			return u
	if hover_sera != null and CombatantStats.of(hover_sera) != null and CombatantStats.of(hover_sera).actor_id == id:
		return hover_sera
	return null


func unit_by_id(id: StringName) -> Node:
	var u: Node = _unit_by_id(id)
	if u != null:
		return u
	for e in enemies:
		var st := CombatantStats.of(e)
		if st != null and st.actor_id == id:
			return e
	return null


func _enemy_candidates() -> Array:
	var out: Array = []
	for e in enemies:
		if _alive(e) and not _untargetable(e):
			out.append({"node": e, "pos": position_of(e), "radius": CombatantStats.of(e).body_radius})
	return out


func _party_candidates(include_hover: bool = false) -> Array:
	var out: Array = []
	for u in party:
		if _alive(u) and not _untargetable(u):
			out.append({"node": u, "pos": position_of(u), "radius": CombatantStats.of(u).body_radius})
	if include_hover and hover_sera != null and _alive(hover_sera):
		out.append({"node": hover_sera, "pos": position_of(hover_sera), "radius": 0.5})
	return out


## Break-locked bodies and statues are cover for LINE_PIERCE (§5.5).
func _blockers() -> Array:
	var out: Array = []
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var sh := ShieldComponent.of(e)
		if sh != null and sh.is_broken:
			out.append({"pos": position_of(e), "radius": CombatantStats.of(e).body_radius * (1.0 + CombatConstants.BREAK_HULL_INFLATION)})
	return out


func _variance() -> float:
	if fixed_variance > 0.0:
		return fixed_variance
	return rng.randf_range(CombatConstants.VARIANCE_MIN, CombatConstants.VARIANCE_MAX)


func _on_bank_changed(bp: int, max_bp: int) -> void:
	bp_changed.emit(bp, max_bp)
