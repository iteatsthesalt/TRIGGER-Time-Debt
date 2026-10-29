## Drives one boss through its phases inside a BattleScene (Combat Laws Bible §14): watches the HP pool,
## swaps the shield/tags/actions when a phase window is entered, plays the phase's story script with the
## clock stopped, spawns adds, and forwards events to an optional per-boss director script at
## res://scripts/battle/bosses/<id>.gd (methods: on_setup, on_phase, on_break, on_parry, on_action,
## on_tick, on_defeat, on_summon; every one optional).
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
var last_enemy_action: Dictionary = {}
## battle_time until which a Prismatic window stays open (0 = closed).
var window_until: float = 0.0
var window_kind: StringName = &""
## Adds spawned by this controller (directors read it; dead ones are pruned lazily).
var adds_alive: Array[Node] = []


static func create_boss_actor(boss: BossDef, suffix: String = "") -> CombatActor:
	var a: CombatActor = CombatActor.create_enemy(boss.phase_def(0), boss.level, suffix)
	a.set_meta("boss_id", boss.id)
	return a


func setup(battle_scene: BattleScene, coord: BattleCoordinator, boss_actor: CombatActor, boss: BossDef) -> void:
	scene = battle_scene
	coordinator = coord
	actor = boss_actor
	def = boss
	var path: String = "res://scripts/battle/bosses/%s.gd" % String(def.id)
	if ResourceLoader.exists(path):
		var scr: GDScript = load(path)
		if scr != null:
			director = scr.new()
	coordinator.unit_broken.connect(_on_unit_broken)
	coordinator.parry_result.connect(_on_parry)
	coordinator.action_executed.connect(_on_action)
	coordinator.enemy_action_started.connect(_on_enemy_action)
	coordinator.unit_koed.connect(_on_koed)
	coordinator.battle_ended.connect(_on_battle_ended)
	coordinator.summon_requested.connect(_on_summon)
	phase_index = 0
	_apply_phase_def(0)
	_spawn_phase_adds(0)
	_call_director("on_setup", [self])
	_call_director("on_phase", [self, 0])
	phase_changed.emit(0, def.phase(0))


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
	if not actor.stats.is_alive():
		return
	if String(phase().get("advance_on", "")) != "":
		return
	var target: int = def.phase_for_ratio(actor.stats.hp_ratio())
	if target > phase_index:
		_transition_to(target)


func _transition_to(i: int) -> void:
	transitioning = true
	coordinator.paused = true
	scene.set_input_blocked(true)
	coordinator.wind_ups.erase(actor)
	coordinator.telegraph_ended.emit(actor)
	phase_index = i
	_apply_phase_def(i)
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
	if actor.frozen:
		actor.on_recover()
	var p: Dictionary = def.phase(i)
	if bool(p.get("untargetable", false)) or bool(p.get("sealed", false)):
		set_sealed(true)
	else:
		set_sealed(false)


## While sealed the boss takes no HP damage (plates still shave); the Dollhouse Seal, Forge Tendril, etc.
func set_sealed(on: bool) -> void:
	if on and not coordinator.undamageable.has(actor):
		coordinator.undamageable.append(actor)
	elif not on:
		coordinator.undamageable.erase(actor)


func is_sealed() -> bool:
	return coordinator.undamageable.has(actor)


func _spawn_phase_adds(i: int) -> void:
	var p: Dictionary = def.phase(i)
	var pid: String = String(p.get("id", ""))
	for add in def.adds:
		if String(add.get("phase", "")) == pid or (i == 0 and String(add.get("phase", "")) == "start"):
			_on_summon(StringName(String(add.get("key", ""))), int(add.get("count", 1)), actor)


func _add_def(key: StringName) -> EnemyDef:
	var edef: EnemyDef = Data.enemy(key)
	if edef != null:
		return edef
	for add in def.adds:
		if StringName(String(add.get("key", ""))) == key and add.has("def"):
			var d: Dictionary = (add["def"] as Dictionary).duplicate()
			d["key"] = String(key)
			d["id"] = String(key)
			d["name"] = String(add.get("name", String(key).capitalize()))
			d["universe"] = def.universe
			d["level"] = int(add.get("level", def.level))
			if d.get("fps", 60.0) is Array:
				d["fps"] = 60.0
			return EnemyDef.from_dict(d)
	return null


func _on_summon(key: StringName, count: int, near: Node) -> void:
	if ended:
		return
	var edef: EnemyDef = _add_def(key)
	if edef == null:
		push_warning("Boss %s: unknown add %s" % [def.id, key])
		return
	var r: Dictionary = _call_director("on_summon", [self, key, count])
	if r.get("handled", false):
		return
	# Never more than max_adds of one kind standing at once (bosses re-cast summons every few turns).
	var living_same: int = 0
	for e in coordinator.living_enemies():
		if e != actor and CombatantStats.of(e).actor_id == key:
			living_same += 1
	var max_adds: int = int(def.raw.get("max_adds", 3))
	count = mini(count, maxi(0, max_adds - living_same))
	if count <= 0:
		return
	for k in count:
		var a: CombatActor = CombatActor.create_enemy(edef, -1, "_add%d_%d" % [phase_index, k + randi() % 1000])
		scene.get_parent().add_child(a)
		var base: Vector3 = coordinator.position_of(near) if near != null else coordinator.arena_center
		var ang: float = randf() * TAU
		a.global_position = base + Vector3(cos(ang), 0.0, sin(ang)) * (1.8 + float(k) * 0.4)
		a.face_toward(coordinator.arena_center + Vector3(0, 0, 4))
		scene.enemies.append(a)
		coordinator.add_enemy(a, edef)
		scene.hud.register_enemy(a)
		a.sprite.play(&"revive", &"idle")
		adds_alive.append(a)
	scene.hud.show_message("%s calls %s ×%d" % [def.display_name, edef.display_name, count])


func _on_unit_broken(unit: Node, _breaker: Node) -> void:
	if ended:
		return
	if unit != actor:
		_call_director("on_add_break", [self, unit])
		return
	var sig: Array[StringName] = actor.shield.break_signature.duplicate()
	_call_director("on_break", [self, sig])
	var text: String = String(phase().get("on_break", ""))
	if text != "" and director == null:
		scene.hud.show_message(text)
	if String(phase().get("advance_on", "")) == "break" and not transitioning:
		if phase_index + 1 < def.phase_count():
			_transition_to(phase_index + 1)
		else:
			# the fight ends when the last phase Breaks (the 999 Shard Doll)
			ended = true
			_call_director("on_defeat", [self])
			boss_defeated.emit(actor)
			coordinator.force_end(true, "final_break")


## Advance to the next phase from a director (a mechanic completed, not an HP window).
func advance_phase() -> void:
	if transitioning or ended:
		return
	if phase_index + 1 < def.phase_count():
		_transition_to(phase_index + 1)


func _on_parry(ally: Node, perfect: bool) -> void:
	if ended:
		return
	_call_director("on_parry", [self, ally, perfect, last_enemy_action])


func _on_enemy_action(enemy: Node, action: Dictionary) -> void:
	if enemy == actor:
		last_enemy_action = action


func _on_action(info: Dictionary) -> void:
	if ended:
		return
	_call_director("on_action", [self, info])


func _on_koed(unit: Node) -> void:
	if unit == actor and not ended:
		ended = true
		_call_director("on_defeat", [self])
		boss_defeated.emit(actor)
		for item in def.drops:
			var iid: StringName = StringName(String(item))
			if Data.items.has(iid):
				Game.add_item(iid)
			else:
				Game.add_relic(iid)


func _on_battle_ended(_victory: bool, _summary: Dictionary) -> void:
	ended = true
	coordinator.paused = false
	coordinator.undamageable.clear()


## Open a timed window (battle seconds) that a director can test in on_action.
func open_window(kind: StringName, seconds: float) -> void:
	window_kind = kind
	window_until = coordinator.battle_time + seconds
	scene.hud.show_message("A %s window opens." % String(kind))


func window_open(kind: StringName) -> bool:
	return window_kind == kind and coordinator.battle_time <= window_until


func _call_director(method: String, args: Array) -> Dictionary:
	if director == null or not director.has_method(method):
		return {}
	var r: Variant = director.callv(method, args)
	return r if r is Dictionary else {}
