## Runs a seamless on-map battle: transition in, ATB/CTB timeline with an
## Action Gate, Sync Hold ready pool for Dual/Triple Techs, pooled Boost,
## Break locking, victory/defeat, transition out.
##
## Main fixes vs. the original doc (see docs/AUDIT.md for the full list):
##  - Sync Hold could deadlock: a held ally was never re-prompted if the partner
##    acted solo. Held allies are now re-prompted after any party action and can
##    be woken any time with request_command().
##  - Co-op tech list ignored who was asking and offered other characters' Single Techs.
##  - Casters passed as Array[Node3D] into an Array[Node] param (runtime error).
##  - Stats read off the actor body instead of CombatantStats (null math).
##  - hit_count multiplied shield shave but not damage.
##  - Boost dim/restore tweens fought each other in one frame; exposure was
##    restored to a hard-coded 1.0 instead of the era's own value.
##  - Empty camera tween would hang `await tween.finished`.
##  - No basic attack, no MP spend, no victory/defeat, no null-shield guard.
##  - BP was granted again every time a held unit re-entered its turn.
class_name HybridBattleCoordinator
extends Node

signal exploration_lock_changed(locked: bool)
signal combat_started(arena_center: Vector3)
signal actor_ready_for_command(actor: Node3D, available_techs: Array[TechResource])
signal ready_pool_changed(pool: Array[Node3D])
signal enemy_turn_started(enemy: Node3D)
signal enemy_broken(enemy: Node3D, breaker: Node)
signal enemy_recovered(enemy: Node3D)
signal strike_resolved(attacker: Node3D, target: Node3D, damage: int, shield_result: Dictionary)
signal tech_executed(tech: TechResource, casters: Array[Node3D], boost_level: int, targets: Array[Node3D])
signal enemy_drift_requested(enemy: Node3D, delta: float)
signal combat_ended(victory: bool)
signal actor_defended(actor: Node3D)

const GATE: float = 100.0
## Haste/Slow: how much faster or slower a unit's gauge fills. 1.0 is normal.
const HASTE_MULTIPLIER: float = 1.5
const SLOW_MULTIPLIER: float = 0.5

@export var camera_3d: Camera3D
@export var world_env: WorldEnvironment
@export var exploration_fov: float = 32.0
@export var combat_fov: float = 24.0
@export var combat_dof_blur: float = 0.12
@export var transition_time: float = 0.45
@export var all_known_techs: Array[TechResource] = []
## A Break pushes the enemy's gauge this far below zero (one full turn lost).
@export var break_gauge_penalty: float = 100.0
@export var party_start_gauge: Vector2 = Vector2(20.0, 50.0)
@export var enemy_start_gauge: Vector2 = Vector2(0.0, 40.0)
@export var party_anchor_radius: float = 4.0
## 0 = random each battle; anything else gives reproducible openings.
@export var rng_seed: int = 0
## Balance knob from source review: cap shields removed from one target by one
## action (-1 = no cap). Unlimited, a MAX-boosted Fire Whirl strips 5 in one go.
@export var max_shield_shave_per_action: int = -1
## When false the coordinator only advances when advance_timeline() is called (tests, replays).
@export var auto_tick: bool = true

var state: CombatTypes.BattleState = CombatTypes.BattleState.EXPLORATION
var active_party: Array[Node3D] = []
var active_enemies: Array[Node3D] = []
## Enemy drift targets for this battle (from the EncounterZone's WanderNodes).
var arena_wander_points: Array[Vector3] = []
var ready_pool: Array[Node3D] = []
var gauges: Dictionary = {}
## Node3D -> float gauge-fill multiplier (Haste/Slow). Missing = 1.0 (normal speed).
var gauge_multipliers: Dictionary = {}
var active_actor: Node3D = null

var _turn_open: Dictionary = {}
var _break_callables: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _fx_tween: Tween
var _base_exposure: float = 1.0
var _base_dof_blur: float = 0.0


func _physics_process(delta: float) -> void:
	if auto_tick:
		advance_timeline(delta)


# ------------------------------------------------------------------ lifecycle

## party_anchors: battle spots for party members in order (EncounterZone markers); members
## beyond the list fan out on the near side of arena_center. wander_points: where enemies may
## drift while gauges fill.
func start_encounter(party: Array[Node3D], enemies: Array[Node3D], arena_center: Vector3,
		party_anchors: Array[Vector3] = [], wander_points: Array[Vector3] = []) -> void:
	if state != CombatTypes.BattleState.EXPLORATION:
		return
	state = CombatTypes.BattleState.TRANSITION_IN
	exploration_lock_changed.emit(true)

	active_party = party.duplicate()
	active_enemies = enemies.duplicate()
	arena_wander_points = wander_points.duplicate()
	ready_pool.clear()
	gauges.clear()
	gauge_multipliers.clear()
	_turn_open.clear()
	active_actor = null
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	if world_env and world_env.environment:
		_base_exposure = world_env.environment.tonemap_exposure

	for i in active_party.size():
		var ally: Node3D = active_party[i]
		gauges[ally] = _rng.randf_range(party_start_gauge.x, party_start_gauge.y)
		var boost := _boost(ally)
		if boost:
			boost.begin_battle()
		var anchor: Vector3
		if i < party_anchors.size():
			anchor = party_anchors[i]
		else:
			# Fan out on the near side of the arena, centred on the middle member.
			var mid: float = float(active_party.size() - 1) * 0.5
			var angle: float = PI + (float(i) - mid) * 0.55
			anchor = arena_center + Vector3(cos(angle), 0.0, sin(angle)) * party_anchor_radius
		if ally.has_method("move_to"):
			ally.move_to(anchor)

	for enemy in active_enemies:
		gauges[enemy] = _rng.randf_range(enemy_start_gauge.x, enemy_start_gauge.y)
		var shield := _shield(enemy)
		if shield:
			shield.reset_shields()
			if not _break_callables.has(enemy):
				var cb := _on_enemy_broken.bind(enemy)
				shield.broken.connect(cb)
				_break_callables[enemy] = cb

	if camera_3d and camera_3d.is_inside_tree():
		await _tween_camera(true)

	combat_started.emit(arena_center)
	state = CombatTypes.BattleState.TIMELINE_TICK


func _finish(victory: bool) -> void:
	state = CombatTypes.BattleState.VICTORY if victory else CombatTypes.BattleState.DEFEAT
	active_actor = null
	ready_pool.clear()
	for enemy in _break_callables.keys():
		var shield := _shield(enemy)
		if is_instance_valid(enemy) and shield and shield.broken.is_connected(_break_callables[enemy]):
			shield.broken.disconnect(_break_callables[enemy])
		if is_instance_valid(enemy) and enemy.has_method("unfreeze"):
			enemy.unfreeze()
	_break_callables.clear()
	_restore_exposure_now()
	combat_ended.emit(victory)

	state = CombatTypes.BattleState.TRANSITION_OUT
	if camera_3d and camera_3d.is_inside_tree():
		await _tween_camera(false)
	exploration_lock_changed.emit(false)
	state = CombatTypes.BattleState.EXPLORATION


# ------------------------------------------------------------------ timeline

func advance_timeline(delta: float) -> void:
	if state != CombatTypes.BattleState.TIMELINE_TICK:
		return

	var queued := _pick_next_unit()
	if queued:
		_begin_turn(queued)
		return

	# Doc rule: someone waiting at the Action Gate pauses enemy drift.
	var drift_paused: bool = not ready_pool.is_empty()
	for unit in _all_units():
		if not _alive(unit) or ready_pool.has(unit):
			continue
		if gauges.get(unit, 0.0) >= GATE:
			continue
		gauges[unit] = gauges.get(unit, 0.0) + _speed(unit) * get_gauge_multiplier(unit) * delta
		if not drift_paused and active_enemies.has(unit) and not _is_broken(unit):
			enemy_drift_requested.emit(unit, delta)

	var next := _pick_next_unit()
	if next:
		_begin_turn(next)


## Broken units recovering take priority (Octopath anti-stunlock rule), then
## whoever overshot the gate most, then party before enemies on ties.
func _pick_next_unit() -> Node3D:
	var best: Node3D = null
	var best_score: float = -INF
	var order: int = 0
	for unit in _all_units():
		order += 1
		if not _alive(unit) or ready_pool.has(unit):
			continue
		var g: float = gauges.get(unit, 0.0)
		if g < GATE:
			continue
		var score: float = g - float(order) * 0.0001
		if _is_broken(unit):
			score += 100000.0
		if score > best_score:
			best_score = score
			best = unit
	return best


func _begin_turn(unit: Node3D) -> void:
	if _is_broken(unit):
		_shield(unit).recover_from_break()
		if unit.has_method("unfreeze"):
			unit.unfreeze()
		enemy_recovered.emit(unit)

	# Defend's damage halving lasts only until the defender's own next turn.
	var st := _stats(unit)
	if st:
		st.is_defending = false

	if active_party.has(unit):
		if not _turn_open.get(unit, false):
			var boost := _boost(unit)
			if boost:
				boost.on_turn_start()
			_turn_open[unit] = true
		if not ready_pool.has(unit):
			ready_pool.append(unit)
			ready_pool_changed.emit(ready_pool)
		_prompt(unit)
	else:
		state = CombatTypes.BattleState.EXECUTING_ACTION
		enemy_turn_started.emit(unit)
		_execute_enemy_turn(unit)


func _prompt(unit: Node3D) -> void:
	state = CombatTypes.BattleState.COMMAND_WAIT
	active_actor = unit
	actor_ready_for_command.emit(unit, get_available_techs(unit))


# ------------------------------------------------------------------ commands

## Techs this actor can use right now: its own Singles, plus any Dual/Triple
## whose every participant is waiting in the Ready Pool.
func get_available_techs(actor: Node3D) -> Array[TechResource]:
	var my_id: StringName = _actor_id(actor)
	var ready_ids: Array[StringName] = []
	for ally in ready_pool:
		if _alive(ally):
			ready_ids.append(_actor_id(ally))
	var out: Array[TechResource] = []
	for tech in all_known_techs:
		if tech == null or not tech.required_actor_ids.has(my_id):
			continue
		var ok := true
		for req in tech.required_actor_ids:
			if not ready_ids.has(req):
				ok = false
				break
		if ok:
			out.append(tech)
	return out


## Park the active actor in the Ready Pool so a partner can catch up.
func command_sync_hold(actor: Node3D) -> bool:
	if state != CombatTypes.BattleState.COMMAND_WAIT or actor != active_actor:
		return false
	active_actor = null
	ready_pool_changed.emit(ready_pool)
	state = CombatTypes.BattleState.TIMELINE_TICK
	return true


## Wake a held ally (UI: player taps their portrait while the timeline runs).
func request_command(actor: Node3D) -> bool:
	if state != CombatTypes.BattleState.TIMELINE_TICK or not ready_pool.has(actor) or not _alive(actor):
		return false
	_prompt(actor)
	return true


func execute_basic_attack(actor: Node3D, target: Node3D, requested_boost: int) -> Dictionary:
	if state != CombatTypes.BattleState.COMMAND_WAIT or actor != active_actor:
		return _fail("not this actor's turn")
	if not active_enemies.has(target) or not _alive(target):
		return _fail("invalid target")
	var boost := _boost(actor)
	var level: int = 0
	if boost:
		if not boost.can_spend(requested_boost):
			return _fail("not enough BP")
		level = requested_boost
		boost.commit_spend(level)

	state = CombatTypes.BattleState.EXECUTING_ACTION
	var a := _stats(actor)
	var tags: Array = [a.weapon_type]
	var dmg_fn := func(mult: float) -> int:
		var t := _stats(target)
		return maxi(1, roundi(TechResource.core_formula(a.physical_attack, t.physical_defense) * mult))
	# Boosted basic attacks add strikes, not damage scaling.
	var total := _resolve_strikes(actor, target, 1 + level, tags, 0, dmg_fn)
	_finish_actor_turn(actor)
	_end_action(true)
	return {"ok": true, "boost_level": level, "damage": total}


## Halves incoming damage until this actor's own next turn and recovers 1 BP.
## No MP cost, no target.
func execute_defend(actor: Node3D) -> Dictionary:
	if state != CombatTypes.BattleState.COMMAND_WAIT or actor != active_actor:
		return _fail("not this actor's turn")

	state = CombatTypes.BattleState.EXECUTING_ACTION
	var st := _stats(actor)
	st.is_defending = true
	var boost := _boost(actor)
	if boost:
		boost.add_bp(1)
	actor_defended.emit(actor)
	_finish_actor_turn(actor)
	_end_action(true)
	return {"ok": true}


func execute_tech(tech: TechResource, primary_caster: Node3D, primary_target: Node3D, requested_boost: int) -> Dictionary:
	if state != CombatTypes.BattleState.COMMAND_WAIT or primary_caster != active_actor:
		return _fail("not this actor's turn")
	if not get_available_techs(primary_caster).has(tech):
		return _fail("tech not available (partners not ready?)")
	if tech.shape_type != TechResource.SpatialShape.SELF_AURA and (primary_target == null or not _alive(primary_target)):
		return _fail("invalid target")

	var casters: Array[Node3D] = _resolve_casters(tech)
	var caster_stats: Array[CombatantStats] = []
	var boost_comps: Array[BoostComponent] = []
	for c in casters:
		var st := _stats(c)
		if not st.can_pay_mp(tech.mp_cost_per_actor):
			return _fail("%s lacks MP" % st.actor_id)
		caster_stats.append(st)
		var bc := _boost(c)
		if bc:
			boost_comps.append(bc)

	var wanted: int = clampi(requested_boost, 0, BoostComponent.MAX_SPEND_PER_ACTION)
	if wanted > BoostComponent.pooled_bp(boost_comps):
		return _fail("not enough pooled BP")

	# --- commit (nothing below can fail) ---
	state = CombatTypes.BattleState.EXECUTING_ACTION
	for st in caster_stats:
		st.spend_mp(tech.mp_cost_per_actor)
	var plan: Dictionary = BoostComponent.allocate_coop_boost(boost_comps, wanted)
	var level: int = plan["effective_boost_level"]
	for bc in plan["allocation"].keys():
		bc.commit_spend(plan["allocation"][bc])
	_play_boost_fx(level)

	var candidates: Array[Node3D] = []
	for e in active_enemies:
		if _alive(e):
			candidates.append(e)
	var targets: Array[Node3D] = TacticalPositioner3D.get_targets_in_tech_aoe(
		tech, primary_caster, primary_target, level, candidates)

	var bonus: int = 1 if level == BoostComponent.MAX_SPEND_PER_ACTION else 0
	var per_target: Dictionary = {}
	for t in targets:
		var dmg_fn := func(mult: float) -> int:
			return tech.calculate_strike_damage(caster_stats, _stats(t), level, mult)
		per_target[t] = _resolve_strikes(primary_caster, t, tech.hit_count, tech.damage_tags, bonus, dmg_fn)

	for c in casters:
		_finish_actor_turn(c)
	tech_executed.emit(tech, casters, level, targets)
	_end_action(true)
	return {"ok": true, "boost_level": level, "targets": targets, "damage": per_target, "allocation": plan["allocation"]}


# ------------------------------------------------------------------ resolution

func _resolve_strikes(attacker: Node3D, target: Node3D, strikes: int, tags: Array, bonus_shave: int, dmg_fn: Callable) -> int:
	var shield := _shield(target)
	var st := _stats(target)
	var total: int = 0
	var bonus_left: int = bonus_shave
	var shaved: int = 0
	for i in strikes:
		if st == null or not st.is_alive():
			break
		var res: Dictionary = {"damage_multiplier": 1.0, "shields_shaved": 0, "hit_weakness": false, "caused_break": false}
		if shield:
			var cap_left: int = -1 if max_shield_shave_per_action < 0 else maxi(0, max_shield_shave_per_action - shaved)
			res = shield.evaluate_strike(tags, bonus_left, attacker, cap_left)
			shaved += int(res["shields_shaved"])
			if res["hit_weakness"]:
				bonus_left = 0
		var dealt: int = st.apply_damage(dmg_fn.call(res["damage_multiplier"]))
		total += dealt
		strike_resolved.emit(attacker, target, dealt, res)
	return total


## Placeholder AI: one weapon strike on the weakest living ally.
## Override in a subclass or replace with a behaviour resource per enemy.
func _execute_enemy_turn(enemy: Node3D) -> void:
	var target: Node3D = null
	for ally in active_party:
		if _alive(ally) and (target == null or _stats(ally).hp < _stats(target).hp):
			target = ally
	if target:
		var e := _stats(enemy)
		var dmg_fn := func(mult: float) -> int:
			return maxi(1, roundi(TechResource.core_formula(e.physical_attack, _stats(target).physical_defense) * mult))
		_resolve_strikes(enemy, target, 1, [e.weapon_type], 0, dmg_fn)
	gauges[enemy] = 0.0
	_end_action(false)


func _finish_actor_turn(actor: Node3D) -> void:
	gauges[actor] = 0.0
	ready_pool.erase(actor)
	_turn_open[actor] = false
	if active_actor == actor:
		active_actor = null
	ready_pool_changed.emit(ready_pool)


func _end_action(by_party: bool) -> void:
	for u in ready_pool.duplicate():
		if not _alive(u):
			ready_pool.erase(u)
	if not _any_alive(active_enemies):
		_finish(true)
		return
	if not _any_alive(active_party):
		_finish(false)
		return
	# Deadlock fix: a held ally whose partner just acted gets the floor back.
	if by_party and not ready_pool.is_empty():
		_prompt(ready_pool[0])
		return
	state = CombatTypes.BattleState.TIMELINE_TICK


func _on_enemy_broken(_breaker: Node, enemy: Node3D) -> void:
	gauges[enemy] = -break_gauge_penalty
	if enemy.has_method("freeze"):
		enemy.freeze()
	enemy_broken.emit(enemy, _breaker)


## Party members in the Ready Pool who would take part in this Tech (HUD preview).
func resolve_casters(tech: TechResource) -> Array[Node3D]:
	return _resolve_casters(tech)


func _resolve_casters(tech: TechResource) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for ally in ready_pool:
		if tech.required_actor_ids.has(_actor_id(ally)):
			out.append(ally)
	return out


# ------------------------------------------------------------------ presentation

func _tween_camera(entering: bool) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(camera_3d, "fov", combat_fov if entering else exploration_fov, transition_time) \
		.set_trans(Tween.TRANS_CUBIC)
	var attrs := camera_3d.attributes as CameraAttributesPractical
	if attrs:
		attrs.dof_blur_far_enabled = true
		if entering:
			_base_dof_blur = attrs.dof_blur_amount
		tw.tween_property(attrs, "dof_blur_amount", combat_dof_blur if entering else _base_dof_blur, transition_time)
	await tw.finished


func _play_boost_fx(level: int) -> void:
	if level < 2 or world_env == null or world_env.environment == null or not is_inside_tree():
		return
	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
	_fx_tween = create_tween()
	_fx_tween.tween_property(world_env.environment, "tonemap_exposure", _base_exposure * 0.55, 0.15)
	_fx_tween.tween_interval(0.35)
	_fx_tween.tween_property(world_env.environment, "tonemap_exposure", _base_exposure, 0.25)


func _restore_exposure_now() -> void:
	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
	if world_env and world_env.environment:
		world_env.environment.tonemap_exposure = _base_exposure


# ------------------------------------------------------------------ helpers

func set_gauge(unit: Node3D, value: float) -> void:
	gauges[unit] = value


func get_gauge(unit: Node3D) -> float:
	return gauges.get(unit, 0.0)


## Haste/Slow: how fast this unit's gauge fills relative to its own speed. 1.0 is normal.
func set_gauge_multiplier(unit: Node3D, multiplier: float) -> void:
	gauge_multipliers[unit] = maxf(0.0, multiplier)


func get_gauge_multiplier(unit: Node3D) -> float:
	return gauge_multipliers.get(unit, 1.0)


func apply_haste(unit: Node3D) -> void:
	set_gauge_multiplier(unit, HASTE_MULTIPLIER)


func apply_slow(unit: Node3D) -> void:
	set_gauge_multiplier(unit, SLOW_MULTIPLIER)


func clear_gauge_multiplier(unit: Node3D) -> void:
	gauge_multipliers.erase(unit)


func _fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}


func _all_units() -> Array[Node3D]:
	var all: Array[Node3D] = []
	all.append_array(active_party)
	all.append_array(active_enemies)
	return all


func _any_alive(units: Array[Node3D]) -> bool:
	for u in units:
		if _alive(u):
			return true
	return false


func _stats(n: Node) -> CombatantStats:
	return CombatantStats.of(n)


func _boost(n: Node) -> BoostComponent:
	return n.get_node_or_null("BoostComponent") as BoostComponent


func _shield(n: Node) -> ShieldComponent:
	return n.get_node_or_null("ShieldComponent") as ShieldComponent


func _alive(n: Node) -> bool:
	if not is_instance_valid(n):
		return false
	var st := _stats(n)
	return st != null and st.is_alive()


func _is_broken(n: Node) -> bool:
	var sh := _shield(n)
	return sh != null and sh.is_broken


func _speed(n: Node) -> float:
	var st := _stats(n)
	return st.speed if st else 25.0


func _actor_id(n: Node) -> StringName:
	var st := _stats(n)
	return st.actor_id if st and st.actor_id != &"" else StringName(n.name)
