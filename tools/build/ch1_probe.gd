## Headless Chapter 1 playthrough in the Atrium: loft wake → crack check (focus) → rewind (R) → downstairs
## → Father Tank → dummy fight (autobattle) → Glenn → rest → midnight → hearth → the Fair call.
## Ends with `PROBE_END ok=<bool>` and exits with 1 when it is false (a stall, a failed check, a timeout).
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
var SV: Node


func _initialize() -> void:
	_boot.call_deferred()


func _boot() -> void:
	# the probe plays the real scenes, which autosave: keep it out of the player's slots and settings (Saves)
	root.get_node("Saves").set("suspended", true)
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
					# the split lesson: each doll's plates, and how often the director has rebuilt one
					for a in boss.get("adds_alive"):
						var ash: Node = a.get_node_or_null("ShieldComponent") if is_instance_valid(a) else null
						if ash != null:
							line += " [%d%s]" % [int(ash.get("current_shield")), "B" if bool(ash.get("is_broken")) else ""]
					var director: Variant = boss.get("director")
					if director != null and "rebuilds" in director:
						line += " rebuilds=%d" % int(director.get("rebuilds"))
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
	# the dummy's result is autosaved without ending the day (GAP2-6), where the fight left the party
	_expect_save("dummy autosave", &"ch1_hub_free", &"dummy_center")
	# the Seed's first watering: the sprout rises from the rim of the pot prop, not inside its billboard
	loc.call("_use_seed", null)
	if not await _wait_until(func() -> bool: return loc.get_node_or_null("Sprout") != null and _idle(), 3000, "seed watering"):
		return _end()
	var sprout: Node3D = loc.get_node("Sprout")
	var pot: Node3D = loc.call("get_prop", &"prp_u0_seed_of_doan_pot")
	var rim_y: float = (pot.global_position.y + float(pot.get("footprint").y)) if pot != null else 1.1
	var sprout_base: float = sprout.global_position.y - 0.25
	if sprout_base < rim_y - 0.01:
		print("PROBE FAIL sprout base %.2f m sits below the pot rim %.2f m" % [sprout_base, rim_y])
		_fail = true
	print("PROBE seed watered: sprout base %.2f m, pot rim %.2f m, waters=%d" % [sprout_base, rim_y, int(F.call("counter", &"seed_waters"))])
	# Glenn
	var glenn: Node = loc.get("glenn_npc")
	if glenn:
		var it: Node = glenn.get_node_or_null("Talk")
		if it:
			it.call("use", null)
			await _wait_until(func() -> bool: return _idle(), 2000, "glenn")
			print("PROBE glenn: Glenn_Duals=%s" % str(F.call("state", &"Glenn_Duals")))
	# rest with Robo → night
	S.call("run", &"atrium_robo")
	await _wait_until(func() -> bool: return _idle(), 2000, "robo rest")
	print("PROBE after rest: checkpoint=%s tower_time=%.1f" % [String(_cp()), float(loc.get("tower_time"))])
	_expect_save("rest save", &"ch1_night", &"dais")
	if not await _wait_until(func() -> bool: return loc.get("midnight_done") and _idle(), 6000, "midnight"):
		return _end()
	var fair_done: Array[bool] = [false]
	S.connect("script_finished", func(id: StringName) -> void:
		if id == &"ch1_fair_call":
			fair_done[0] = true)
	loc.call("_use_hearth", null)
	if not await _wait_until(func() -> bool: return F.call("has", &"Crono_Confession"), 3000, "hearth"):
		return _end()
	print("PROBE hearth: %s light=%d dark=%d" % [str(F.call("state", &"Crono_Confession")), int(F.get("light")), int(F.get("dark"))])
	if not await _wait_until(func() -> bool: return fair_done[0] and _idle(), 4000, "fair call"):
		return _end()
	_expect_save("hearth autosave", &"ch1_fair_ready", &"hearth")
	# the Fair commits only when Leene Square can be reached; until then the hub stays as it was (GAP2-1)
	var built: bool = R.call("has_location", &"leene_square")
	var left: bool = F.call("has", &"Ch1_Fair_Left")
	print("PROBE fair call: left=%s leene_square_built=%s party=%s location=%s" % [str(left), str(built), str(G.get("active_party")), String(R.get("current_location"))])
	if left != built:
		print("PROBE FAIL the Fair departure (left=%s) disagrees with Leene Square being built (%s)" % [str(left), str(built)])
		_fail = true
	if not built and (G.get("active_party") != [&"sera", &"crono"] or R.get("current_location") != &"atrium" or loc.get("party_actors").size() != 2):
		print("PROBE FAIL the hub did not stay as it was: party=%s field=%d" % [str(G.get("active_party")), loc.get("party_actors").size()])
		_fail = true
	_end()


## The autosave (slot 0, scratch) carries this checkpoint and resumes at this marker, never the loft (GAP2-4).
func _expect_save(what: String, cp: StringName, spawn: StringName) -> void:
	var g: Dictionary = (SV.call("peek", 0) as Dictionary).get("game", {})
	print("PROBE %s: checkpoint=%s spawn=%s" % [what, String(g.get("checkpoint", "")), String(g.get("spawn_point", ""))])
	if StringName(String(g.get("checkpoint", ""))) != cp or StringName(String(g.get("spawn_point", ""))) != spawn:
		print("PROBE FAIL %s should be %s at %s" % [what, cp, spawn])
		_fail = true


func _end() -> void:
	print("PROBE_END ok=%s" % str(not _fail))
	_finished = true


func _process(_delta: float) -> bool:
	if not _started:
		return false
	_frame += 1
	if not _finished and _frame > 90000:
		print("PROBE timeout")
		_fail = true
		_end()
	if _finished:
		quit(1 if _fail else 0)
		return true
	return false
