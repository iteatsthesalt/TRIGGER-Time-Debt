## Headless Chapter 1 playthrough in the Atrium: loft wake → crack check (focus) → rewind (R) → downstairs
## → Father Tank → dummy fight (autobattle) → Glenn → rest → midnight → hearth → the Fair call.
##   godot --headless --path . --script res://tools/build/ch1_probe.gd -- --autobattle
extends SceneTree

var _frame: int = 0
var _started: bool = false
var _finished: bool = false
var _fail: bool = false
var G: Node
var F: Node
var S: Node
var R: Node


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
	G.call("new_game")
	F.call("reset_cycle")
	G.call("set_chapter", 1)
	G.set("checkpoint", &"atrium_hub")
	G.set("location", &"atrium")
	G.get("settings")["flow_speed"] = 4.0
	S.set("auto_advance_s", 0.05)
	S.set("auto_choice", 0)
	S.set("skip_waits", true)
	for i in 4:
		await process_frame
	while R.get("transitioning"):
		await process_frame
	R.call("go", &"atrium", &"start", 0.0)
	_started = true
	_run()


func _loc() -> Node:
	return R.get("current_scene")


func _cp() -> StringName:
	return G.get("checkpoint")


func _wait_until(pred: Callable, max_frames: int, what: String) -> bool:
	var f: int = 0
	while f < max_frames:
		if pred.call():
			return true
		await process_frame
		f += 1
	print("PROBE STALL waiting for %s" % what)
	_fail = true
	return false


func _idle() -> bool:
	return not S.call("is_running") and not R.get("transitioning")


func _run() -> void:
	if not await _wait_until(func() -> bool: return _cp() == &"ch1_loft" and _idle() and _loc() != null and _loc().get("location_id") == &"atrium" and _loc().get("party_actors").size() > 0, 3000, "loft"):
		return _end()
	print("PROBE loft: party=%s" % str(G.get("active_party")))
	# hold focus for the crack check
	var loc: Node = _loc()
	loc.get("controller").set("focusing", true)
	loc.call("_on_focus", true)
	if not await _wait_until(func() -> bool: return _cp() == &"ch1_rewind" and _idle(), 3000, "rewind prompt"):
		return _end()
	loc.get("controller").set("focusing", false)
	print("PROBE crack check done; pressing R")
	loc.call("_on_rewind")
	if not await _wait_until(func() -> bool: return _cp() == &"ch1_downstairs" and _idle(), 3000, "downstairs"):
		return _end()
	print("PROBE rewind done: debt=%.0f techs=%s" % [float(G.get("sera_debt")), str(G.get("roster")[&"sera"]["known_techs"])])
	# walk down the ramp
	var leader: Node3D = loc.get("party_actors")[0]
	leader.global_position = loc.call("get_marker", &"ramp_top")
	leader.call("walk_to", loc.call("get_marker", &"ramp_bottom"), 4.0)
	if not await _wait_until(func() -> bool: return _cp() == &"ch1_hub_free" and _idle(), 6000, "father tank"):
		return _end()
	print("PROBE father tank done: party=%s flags=%s" % [str(G.get("active_party")), str(F.get("flags").keys())])
	# the dummy
	loc = _loc()
	loc.call("_use_dummy", null)
	var waited: int = 0
	while not F.call("has", &"Atrium_Dummy") and waited < 40000:
		await process_frame
		waited += 1
		if waited % 1500 == 0:
			var battle: Node = loc.get("battle")
			var line: String = "PROBE dummy f%d story=%s" % [waited, str(S.call("is_running"))]
			if battle != null and is_instance_valid(battle) and battle.get("coordinator") != null:
				var coord: Node = battle.get("coordinator")
				var boss: Node = battle.get("boss")
				line += " state=%d t=%.0f" % [int(coord.get("state")), float(coord.get("battle_time"))]
				if boss:
					var sh: Node = boss.get("actor").get("shield")
					line += " phase=%d shield=%d/%d adds=%d" % [int(boss.get("phase_index")), int(sh.get("current_shield")), int(sh.call("max_total")), boss.get("adds_alive").size()]
				for u in coord.get("party"):
					line += " %s=%d" % [String(u.get("actor_id")), int(u.get("stats").get("hp"))]
			print(line)
	if not F.call("has", &"Atrium_Dummy"):
		print("PROBE STALL dummy")
		_fail = true
		return _end()
	print("PROBE dummy done: flag=%s light=%d dark=%d prismatic=%d integrity=%.0f" % [str(F.call("state", &"Atrium_Dummy")), int(F.get("light")), int(F.get("dark")), int(F.get("prismatic")), float(G.get("crono_integrity"))])
	if not await _wait_until(func() -> bool: return _idle(), 2000, "post-dummy idle"):
		return _end()
	# Glenn
	var glenn: Node = loc.get("glenn_npc")
	if glenn:
		var it: Node = glenn.get_node_or_null("Talk")
		if it:
			it.call("use", null)
			await _wait_until(func() -> bool: return _idle(), 2000, "glenn")
			print("PROBE glenn: offered=%s refused=%s" % [str(F.call("has", &"Glenn_Duals_Offered")), str(F.call("has", &"Glenn_Duals_Refused"))])
	# rest with Robo → night
	S.call("run", &"atrium_robo")
	await _wait_until(func() -> bool: return _idle(), 2000, "robo rest")
	print("PROBE after rest: checkpoint=%s tower_time=%.1f" % [String(_cp()), float(loc.get("tower_time"))])
	if not await _wait_until(func() -> bool: return loc.get("midnight_done") and _idle(), 6000, "midnight"):
		return _end()
	loc.call("_use_hearth", null)
	if not await _wait_until(func() -> bool: return F.call("has", &"Crono_Confession"), 3000, "hearth"):
		return _end()
	print("PROBE hearth: %s" % str(F.call("state", &"Crono_Confession")))
	if not await _wait_until(func() -> bool: return F.call("has", &"Ch1_Fair_Left"), 4000, "fair call"):
		return _end()
	print("PROBE fair call: party=%s location=%s" % [str(G.get("active_party")), String(R.get("current_location"))])
	_end()


func _end() -> void:
	print("PROBE_END ok=%s" % str(not _fail))
	_finished = true


func _process(_delta: float) -> bool:
	if not _started:
		return false
	_frame += 1
	if _finished or _frame > 90000:
		return true
	return false
