## Headless Prologue playthrough: boots into the kitchen with a fresh game, lets the opening scripts
## auto-advance, opens the gate, walks into the hall to start the Cradle, autobattles it, then takes
## the exit to the courtyard and on to the Atrium. Prints PROBE lines; exits with 1 on a stall.
##   godot --headless --path . --script res://tools/build/prologue_probe.gd -- --autobattle
extends SceneTree

var _frame: int = 0
var _started: bool = false
var _stage: String = "boot"
var _stage_frames: int = 0
var _fail: bool = false
var _finished: bool = false
var G: Node
var F: Node
var S: Node
var R: Node
var SV: Node


func _initialize() -> void:
	_boot.call_deferred()


func _boot() -> void:
	var packed: PackedScene = load("res://scenes/boot/boot.tscn")
	var node: Node = packed.instantiate()
	root.add_child(node)
	current_scene = node
	await process_frame
	G = root.get_node("Game")
	F = root.get_node("Flags")
	S = root.get_node("Story")
	R = root.get_node("Router")
	SV = root.get_node("Saves")
	G.call("new_game")
	F.call("reset_cycle")
	S.set("auto_advance_s", 0.05)
	S.set("auto_choice", 0)
	S.set("skip_waits", true)
	G.get("settings")["flow_speed"] = 4.0
	for i in 4:
		await process_frame
	while R.get("transitioning"):
		await process_frame
	R.call("go", &"guardia_kitchen", &"start", 0.0)
	_started = true
	_run()


func _loc() -> Node:
	return R.get("current_scene")


func _cp() -> StringName:
	return G.get("checkpoint")


func _wait_frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait_until(pred: Callable, max_frames: int, what: String) -> bool:
	var f: int = 0
	while f < max_frames:
		if pred.call():
			return true
		await process_frame
		f += 1
	print("PROBE STALL waiting for %s (%d frames)" % [what, max_frames])
	_fail = true
	return false


func _run() -> void:
	_stage = "opening"
	await _wait_frames(5)
	var kitchen: Node = _loc()
	print("PROBE location=%s" % str(kitchen.name if kitchen else null))
	if not await _wait_until(func() -> bool: return _cp() == &"prologue_breakfast_done", 6000, "breakfast"):
		return _end()
	print("PROBE breakfast done: party=%s integrity=%.0f flags=%s" % [str(G.get("active_party")), float(G.get("crono_integrity")), str(F.get("flags").keys())])
	kitchen = _loc()
	_stage = "gate"
	await _wait_frames(10)
	kitchen.call("_use_gate", null)
	if not await _wait_until(func() -> bool: return _cp() == &"prologue_gate_open", 2000, "gate"):
		return _end()
	print("PROBE gate open: integrity=%.0f zones=%d" % [float(G.get("crono_integrity")), kitchen.get("zones").size()])
	_stage = "cradle"
	await _wait_frames(10)
	var leader: Node3D = kitchen.get("party_actors")[0]
	leader.global_position = Vector3(2.0, 0.05, 0.0)
	kitchen.call("place_party", &"gate")
	await _wait_frames(5)
	leader.call("walk_to", Vector3(7.0, 0.0, 0.0), 6.0)
	var waited: int = 0
	while _cp() != &"prologue_cradle_done" and waited < 30000:
		await process_frame
		waited += 1
		if waited % 1500 == 0:
			var battle: Node = kitchen.get("battle")
			var line: String = "PROBE cradle f%d started=%s story=%s" % [waited, str(kitchen.get("_cradle_started")), str(S.call("is_running"))]
			if battle != null and is_instance_valid(battle):
				var coord: Node = battle.get("coordinator")
				var boss: Node = battle.get("boss")
				line += " state=%d t=%.0f paused=%s" % [int(coord.get("state")), float(coord.get("battle_time")), str(coord.get("paused"))]
				if boss:
					line += " phase=%d sealed=%s boss_hp=%d" % [int(boss.get("phase_index")), str(boss.call("is_sealed")), int(boss.get("actor").get("stats").get("hp"))]
				for u in coord.get("party"):
					line += " %s=%d" % [String(u.get("actor_id")), int(u.get("stats").get("hp"))]
			else:
				line += " leader=%s" % str(leader.global_position)
			print(line)
	if _cp() != &"prologue_cradle_done":
		print("PROBE STALL cradle")
		_fail = true
		return _end()
	print("PROBE cradle done: integrity=%.0f relics=%s crono_lv=%d" % [float(G.get("crono_integrity")), str(G.get("relics")), int(G.get("roster")[&"crono"]["level"])])
	_stage = "exit"
	if not await _wait_until(func() -> bool: return not S.call("is_running"), 2000, "story idle"):
		return _end()
	kitchen.call("_use_exit", null)
	if not await _wait_until(func() -> bool: return R.get("current_location") == &"guardia_courtyard" and not R.get("transitioning"), 3000, "courtyard"):
		return _end()
	print("PROBE in courtyard")
	if not await _wait_until(func() -> bool: return R.get("current_location") == &"atrium" and not R.get("transitioning"), 6000, "atrium"):
		return _end()
	print("PROBE in atrium: chapter=%d checkpoint=%s" % [int(G.get("chapter")), String(_cp())])
	if not await _wait_until(func() -> bool: return F.call("has", &"Ch1_Arrived") and not S.call("is_running"), 3000, "ch1 arrival"):
		return _end()
	print("PROBE ch1 arrival done; save exists=%s" % str(SV.call("exists", 0)))
	_end()


func _end() -> void:
	print("PROBE_END ok=%s stage=%s" % [str(not _fail), _stage])
	_finished = true


func _process(_delta: float) -> bool:
	if not _started:
		return false
	_frame += 1
	if _finished:
		return true
	if _frame > 60000:
		print("PROBE timeout at stage %s" % _stage)
		return true
	return false
