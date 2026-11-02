## Drives one boss through its phases inside a BattleScene (Combat Laws Bible §14): watches the HP pool and the
## phase gates (BossDef), swaps the shield/tags/actions when a phase begins, plays the phase's story script with
## the clock stopped, places its adds (BossAdds), asks a Possibility Branch (BossBranch), ends the fight on a
## final Break or a yield and pays the boss's XP and drops, and forwards events to an optional per-boss director
## at res://scripts/battle/bosses/<id>.gd. Director methods, every one optional: on_setup, on_phase, on_break
## (return {"handled": true} to replace the break line), on_add_break, on_parry, on_action, on_tick, on_summon and
## on_branch (return {"handled": true} to take over), on_defeat, on_battle_end.
##
## §14.1: a phase that comes due while the boss is Broken waits; the Break plays out on the old plates and the new
## phase begins when the boss recovers. HP windows are walked one at a time, so no phase's script, seal or adds are
## skipped, and a sealed phase holds until its seal is paid. A phase's `on_break` / `on_enter` strings are design
## notes and never shown: the boss's first Break shows Sera's bestiary `break_line` instead.
class_name BossController
extends Node

signal phase_changed(index: int, phase: Dictionary)
signal boss_defeated(boss: Node)

var def: BossDef
var actor: CombatActor
var scene: BattleScene
var coordinator: BattleCoordinator
var phase_index: int = -1
var transitioning: bool = false
var ended: bool = false
var director: Object = null
var adds: BossAdds
## The current phase's gate is open: its Break landed, its adds fell, its branch was answered, a director said so.
var gate_open: bool = false
## The option id of the Possibility Branch answered in this fight ("" before one).
var branch_choice: String = ""
## The boss's action in progress (cleared when it has resolved): a parry is credited to it only.
var last_enemy_action: Dictionary = {}
## battle_time until which a Prismatic window stays open (0 = closed).
var window_until: float = 0.0
var window_kind: StringName = &""
## Adds spawned by this controller (directors read it and skip the dead; the dead are pruned on the next
## summon, never mid-iteration). The Location frees every add's body after the battle (BattleAftermath).
var adds_alive: Array[Node] = []
var _forced: bool = false
var _phase_spawned: int = 0
var _break_line_shown: bool = false


static func create_boss_actor(boss: BossDef, suffix: String = "") -> CombatActor:
	var a: CombatActor = CombatActor.create_enemy(boss.phase_def(0), boss.level, suffix)
	a.set_meta("boss_id", boss.id)
	return a


func setup(battle_scene: BattleScene, coord: BattleCoordinator, boss_actor: CombatActor, boss: BossDef) -> void:
	scene = battle_scene
	coordinator = coord
	actor = boss_actor
	def = boss
	def.holds = func(pair: String) -> bool: return BossController.holds(pair)
	adds = BossAdds.new(def)
	var path: String = "res://scripts/battle/bosses/%s.gd" % String(def.id)
	if ResourceLoader.exists(path):
		var scr: GDScript = load(path)
		if scr != null:
			director = scr.new()
	if director == null and not def.director_gates().is_empty():
		push_warning("Boss %s: phases gated by %s need scripts/battle/bosses/%s.gd; they will not advance" % [def.id, ", ".join(def.director_gates()), def.id])
	coordinator.unit_broken.connect(_on_unit_broken)
	coordinator.unit_recovered.connect(_on_unit_recovered)
	coordinator.parry_result.connect(_on_parry)
	coordinator.strike_resolved.connect(_on_strike)
	coordinator.action_executed.connect(_on_action)
	coordinator.enemy_action_started.connect(_on_enemy_action)
	coordinator.unit_koed.connect(_on_koed)
	coordinator.battle_ended.connect(_on_battle_ended)
	coordinator.summon_requested.connect(_on_summon)
	phase_index = 0
	_apply_phase_def(0)
	adds.begin_phase(0, actor.stats.hp_ratio())
	_spawn_phase_adds(0)
	_call_director("on_setup", [self])
	_call_director("on_phase", [self, 0])
	phase_changed.emit(0, def.phase(0))


## A flag reference holds (BossDef's *_by_branch tables, an add's `requires`): "Name:State" or "Name" (FlagRef).
static func holds(pair: String) -> bool:
	return Flags.holds(pair)


func phase() -> Dictionary:
	return def.phase(phase_index)


func _process(delta: float) -> void:
	if ended or transitioning or actor == null or not is_instance_valid(actor):
		return
	if coordinator.state != BattleCoordinator.State.TICK and coordinator.state != BattleCoordinator.State.COMMAND_WAIT:
		return
	if window_until > 0.0 and coordinator.battle_time > window_until:
		window_until = 0.0
		window_kind = &""
	_call_director("on_tick", [self, delta])
	if ended or transitioning or not actor.stats.is_alive():
		return
	for r in adds.hp_lost_rows(phase_index, actor.stats.hp_ratio()):
		_spawn_row(r)
	for r in adds.due_respawns(phase_index, coordinator.battle_time):
		_spawn_row(r, 1)
	check_advance()


## Move the fight on when it is due: the end (the last window's yield, the last phase's gate), a director's advance,
## the gate, one HP window.
func check_advance() -> void:
	if ended or transitioning or actor == null or not is_instance_valid(actor) or not actor.stats.is_alive():
		return
	var ratio: float = actor.stats.hp_ratio()
	var last: bool = phase_index == def.phase_count() - 1
	if last and def.ends_at() > 0.0 and ratio <= def.ends_at():
		end_fight("yield")
		return
	if last and gate_open and def.gate(phase_index) != "":
		end_fight(def.gate(phase_index))  # a gated last phase ends the fight when its gate opens
		return
	if actor.shield.is_broken:
		return  # §14.1: the Break plays out first; the next phase begins when the boss recovers
	if _forced:
		_forced = false
		if phase_index + 1 < def.phase_count():
			_transition_to(phase_index + 1)
		return
	if is_sealed():
		return  # a sealed phase holds its window until the seal is paid
	if def.gate(phase_index) == "adds_defeated" and _phase_spawned > 0 and _living_adds().is_empty():
		gate_open = true
	var n: int = def.next_phase(phase_index, ratio, gate_open)
	if n > 0:
		_transition_to(n)


func _transition_to(i: int) -> void:
	transitioning = true
	gate_open = false
	_forced = false
	_phase_spawned = 0
	coordinator.paused = true
	scene.set_input_blocked(true)
	coordinator.wind_ups.erase(actor)
	coordinator.telegraph_ended.emit(actor)
	phase_index = i
	_apply_phase_def(i)
	adds.begin_phase(i, actor.stats.hp_ratio())
	var p: Dictionary = def.phase(i)
	var pname: String = String(p.get("name", "Phase %d" % (i + 1)))
	scene.hud.show_message("%s — %s" % [def.display_name, pname])
	Audio.play_sfx("combat/phase_shift")
	actor.sprite.play(&"attack", &"idle")
	if scene.rig:
		scene.rig.shake(0.5)
	var script_id: String = String(p.get("script", ""))
	if script_id != "" and Data.dialogue.has(StringName(script_id)):
		await Story.run(StringName(script_id))
	if def.gate(i) == "branch" and not ended:
		await _ask_branch(i)
	_spawn_phase_adds(i)
	_call_director("on_phase", [self, i])
	phase_changed.emit(i, p)
	coordinator.paused = false
	scene.set_input_blocked(false)
	transitioning = false


func _apply_phase_def(i: int) -> void:
	var pdef: EnemyDef = def.phase_def(i)
	coordinator.enemy_defs[actor.actor_id] = pdef
	actor.def = pdef
	actor.stats.tags = pdef.tags.duplicate()
	actor.stats.weapon_tags = pdef.tags.duplicate() if not pdef.tags.is_empty() else [&"BLUNT"]
	actor.shield.configure(pdef.shield_config())
	var p: Dictionary = def.phase(i)
	set_sealed(bool(p.get("untargetable", false)) or bool(p.get("sealed", false)))


## While sealed the boss takes no HP damage (plates still shave); the Dollhouse Seal, Forge Tendril, etc.
func set_sealed(on: bool) -> void:
	if on and not coordinator.undamageable.has(actor):
		coordinator.undamageable.append(actor)
	elif not on:
		coordinator.undamageable.erase(actor)


func is_sealed() -> bool:
	return coordinator.undamageable.has(actor)


# ---------------------------------------------------------------- gates, branches, the end

## Open the current phase's gate (a director's mechanic completed); the HP window still applies after it, and on the
## last phase the fight ends.
func open_gate() -> void:
	gate_open = true


## Advance to the next phase from a director at once (after the boss's Break, if it is Broken).
func advance_phase() -> void:
	if transitioning or ended:
		return
	_forced = true
	check_advance()


func _ask_branch(i: int) -> void:
	var entry: Dictionary = BossBranch.entry_for(def, i)
	if entry.is_empty():
		gate_open = true
		return
	if _call_director("on_branch", [self, entry]).get("handled", false):
		return
	var id: String = await BossBranch.ask(self, entry)
	if not ended:
		answer_branch(id, entry)


## A Possibility Branch was answered (the dialogue box, or a director's in-world action): the option's flag is
## written at once and the gate opens.
func answer_branch(option_id: String, entry: Dictionary = {}) -> void:
	var e: Dictionary = entry if not entry.is_empty() else BossBranch.entry_for(def, phase_index)
	BossBranch.apply(e, option_id, def.universe)
	branch_choice = option_id
	gate_open = true


## End the fight as a victory with the boss still standing (its last phase Broke, it yielded, a director's scripted
## end): its XP counts as a defeat's (RewardResolver.award_xp reads the boss_defeated meta) and its drops are
## given. The battle ends once the action in progress has resolved.
func end_fight(reason: String = "scripted") -> void:
	if ended:
		return
	actor.set_meta(&"boss_defeated", true)
	_close()
	coordinator.call_deferred("force_end", true, reason)


func _close() -> void:
	ended = true
	_call_director("on_defeat", [self])
	boss_defeated.emit(actor)
	RewardResolver.give(def.drops, coordinator.rng)  # by each item's catalogue kind (Game.grant), like enemy drops


# ---------------------------------------------------------------- adds

func _spawn_phase_adds(i: int) -> void:
	for r in adds.rows_for_phase(i):
		_spawn_row(r)


func _spawn_row(r: int, count: int = -1) -> Array[CombatActor]:
	var row: Dictionary = def.adds[r]
	return _summon(StringName(String(row.get("key", ""))), adds.def_for_row(r), count if count > 0 else int(row.get("count", 1)), r)


## Spawn the current phase's adds held back for `trigger` (a director's call: "surrender_order", ...).
func spawn_triggered(trigger: String) -> int:
	var n: int = 0
	for r in adds.rows_for_trigger(phase_index, trigger):
		n += _spawn_row(r).size()
	return n


## The boss's `summon:` actions: defined by its file's add rows, capped through the shared EnemySpawner. A summon
## cast by any other enemy is the BattleScene's.
func _on_summon(key: StringName, count: int, near: Node) -> void:
	if ended or (near != null and near != actor):
		return
	_summon(key, adds.def_for_key(key), count, -1)


func _summon(key: StringName, edef: EnemyDef, count: int, row: int) -> Array[CombatActor]:
	var out: Array[CombatActor] = []
	if ended:
		return out
	if edef == null:
		push_warning("Boss %s: unknown add %s" % [def.id, key])
		return out
	adds_alive = Array(adds_alive.filter(func(a: Variant) -> bool: return is_instance_valid(a) and CombatantStats.of(a).is_alive()), TYPE_OBJECT, &"Node", null)
	if _call_director("on_summon", [self, key, count]).get("handled", false):
		return out
	out = EnemySpawner.spawn(scene, edef, actor, count, adds.cap(), "add%d_" % phase_index)
	for a in out:
		a.set_meta(&"boss_add_row", row)
		adds_alive.append(a)
	_phase_spawned += out.size()
	if not out.is_empty():
		scene.hud.show_message("%s calls %s ×%d" % [def.display_name, edef.display_name, out.size()])
	return out


func _living_adds() -> Array[Node]:
	var out: Array[Node] = []
	for a in adds_alive:
		if is_instance_valid(a) and coordinator.living_enemies().has(a):
			out.append(a)
	return out


## Take an add out of the fight without a kill's rewards (the split dolls folding back into the 999 Shard Doll):
## its Break is lifted so it stands no statue, it pays no XP and never respawns, it leaves through the KO path
## (plate, Turn Bar and living lists drop it) and its body slides into the boss as it fades.
func fold_add(a: Node) -> void:
	var st := CombatantStats.of(a) if is_instance_valid(a) else null
	if st == null or not st.is_alive():
		return
	a.set_meta(&"boss_add_row", -1)
	coordinator.undamageable.erase(a)
	var sh := ShieldComponent.of(a)
	if sh != null and sh.is_broken:
		sh.reset_shields()
	st.xp_reward = 0
	st.apply_damage(st.hp, true)
	if a is Node3D and is_instance_valid(actor):
		a.create_tween().tween_property(a, "global_position", actor.global_position, 0.6)


# ---------------------------------------------------------------- coordinator events

func _on_unit_broken(unit: Node, _breaker: Node) -> void:
	if ended:
		return
	if unit != actor:
		if adds_alive.has(unit) and def.gate(phase_index) == "arm_broken":
			gate_open = true
		_call_director("on_add_break", [self, unit])
		return
	var sig: Array[StringName] = actor.shield.break_signature.duplicate()
	if not _call_director("on_break", [self, sig]).get("handled", false):
		_show_break_line()
	# Refills once (§5.7): the phase's first Break rebuilds the plates and the phase goes on.
	if def.gate(phase_index) == "break" and not transitioning and not actor.shield.consume_refill():
		if phase_index + 1 < def.phase_count():
			gate_open = true  # the next phase begins when this Break has played out
		else:
			end_fight("final_break")  # the fight ends when the last phase Breaks (the 999 Shard Doll)


## Sera's line the first time the boss Breaks in this fight (data/text/bestiary.json `break_line`).
func _show_break_line() -> void:
	if _break_line_shown:
		return
	_break_line_shown = true
	var line: String = String(Data.bestiary(def.id).get("break_line", ""))
	if line != "":
		scene.hud.show_message("Sera: %s" % line)


func _on_unit_recovered(unit: Node) -> void:
	if unit == actor:
		check_advance()


## A perfect parry is credited through the strike that carries its attacker (_on_strike); a parry window that
## closed unused reaches the director with no action.
func _on_parry(ally: Node, perfect: bool) -> void:
	if ended or perfect:
		return
	_call_director("on_parry", [self, ally, false, {}])


func _on_strike(attacker: Node, target: Node, info: Dictionary) -> void:
	if ended or not bool(info.get("parried", false)):
		return
	_call_director("on_parry", [self, target, true, last_enemy_action if attacker == actor else {}])


func _on_enemy_action(enemy: Node, action: Dictionary) -> void:
	if enemy == actor:
		last_enemy_action = action


func _on_action(info: Dictionary) -> void:
	if ended:
		return
	_call_director("on_action", [self, info])
	if info.get("attacker", null) == actor:
		last_enemy_action = {}


func _on_koed(unit: Node) -> void:
	if unit == actor:
		if not ended:
			_close()
	elif not ended:
		adds.on_add_down(BossAdds.row_of(unit), coordinator.battle_time)


func _on_battle_ended(victory: bool, _summary: Dictionary) -> void:
	ended = true
	coordinator.paused = false
	coordinator.undamageable.clear()
	_call_director("on_battle_end", [self, victory])


## Open a timed window (battle seconds) that a director can test in on_action.
func open_window(kind: StringName, seconds: float) -> void:
	window_kind = kind
	window_until = coordinator.battle_time + seconds
	scene.hud.show_message("A %s window opens." % String(kind))


func window_open(kind: StringName) -> bool:
	return window_until > 0.0 and window_kind == kind and coordinator.battle_time <= window_until


func _call_director(method: String, args: Array) -> Dictionary:
	if director == null or not director.has_method(method):
		return {}
	var r: Variant = director.callv(method, args)
	return r if r is Dictionary else {}
