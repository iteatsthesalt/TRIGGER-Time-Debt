## Runs story scripts: arrays of command dictionaries from data/dialogue/*.json (or built in code).
## Autoload name: Story. The current location scene provides actors and markers through
## get_actor(id) and get_marker(name); everything else is handled here.
extends Node

signal script_started(id: StringName)
signal script_finished(id: StringName)
signal line_shown(who: String, text: String)
signal choice_made(index: int, option: Dictionary)
signal battle_requested(encounter_id: StringName, context: Dictionary)
signal camera_requested(mode: String, focus: Node)

var running: bool = false
var current_id: StringName = &""
var box: DialogueBox
var layer: CanvasLayer
var battle_result: Dictionary = {}
## Set by tests/smoke runs: lines advance by themselves after this many seconds.
var auto_advance_s: float = -1.0
var auto_choice: int = -1
var skip_waits: bool = false
var _battle_waiting: bool = false
var _history: Array[Dictionary] = []
var _vars: Dictionary = {}


func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	box = DialogueBox.new()
	box.visible = false
	layer.add_child(box)


func is_running() -> bool:
	return running


## Run a script by id (from Data.dialogue) or an inline array of commands.
func run(id: StringName, inline: Array = []) -> void:
	if running:
		push_warning("Story: script %s requested while %s is running" % [id, current_id])
		return
	var cmds: Array = inline if not inline.is_empty() else Data.dialogue_script(id)
	if cmds.is_empty():
		push_warning("Story: empty script %s" % id)
		return
	running = true
	current_id = id
	script_started.emit(id)
	var labels: Dictionary = {}
	for i in cmds.size():
		if cmds[i] is Dictionary and cmds[i].has("label"):
			labels[String(cmds[i]["label"])] = i
	var pc: int = 0
	var guard: int = 0
	while pc < cmds.size() and guard < 100000:
		guard += 1
		var cmd: Dictionary = cmds[pc]
		pc += 1
		var jump: String = await _exec(cmd)
		if jump == "__end__":
			break
		if jump != "":
			if labels.has(jump):
				pc = int(labels[jump])
			else:
				push_warning("Story: unknown label %s" % jump)
	box.hide_box()
	running = false
	script_finished.emit(id)
	current_id = &""


func _exec(cmd: Dictionary) -> String:
	if cmd.has("label"):
		return ""
	if cmd.has("say"):
		var who: String = String(cmd.get("who", ""))
		var text: String = _substitute(String(cmd["say"]))
		if cmd.has("voice"):
			Audio.play_voice(who, String(cmd["voice"]))
		line_shown.emit(who, text)
		_history.append({"who": who, "text": text})
		await box.say(who, text, String(cmd.get("portrait", "neutral")), String(cmd.get("style", "")), auto_advance_s)
		return ""
	if cmd.has("caption"):
		if bool(Game.settings.get("captions", true)):
			await box.caption(String(cmd["caption"]), auto_advance_s if auto_advance_s > 0.0 else 1.2)
		return ""
	if cmd.has("choice"):
		var options: Array = cmd["choice"]
		var visible: Array = []
		for o in options:
			if o.has("if") and not _test(o["if"]):
				continue
			visible.append(o)
		var idx: int = await box.choose(String(cmd.get("who", "")), String(cmd.get("prompt", "")), visible, auto_choice)
		idx = clampi(idx, 0, maxi(0, visible.size() - 1))
		if visible.is_empty():
			return ""
		var picked: Dictionary = visible[idx]
		choice_made.emit(idx, picked)
		_apply_side_effects(picked)
		if picked.has("goto"):
			return String(picked["goto"])
		return ""
	if cmd.has("goto"):
		return String(cmd["goto"])
	if cmd.has("if"):
		if _test(cmd["if"]):
			return String(cmd.get("then", ""))
		return String(cmd.get("else", ""))
	if cmd.has("end"):
		return "__end__"
	if cmd.has("wait"):
		if not skip_waits:
			await get_tree().create_timer(float(cmd["wait"])).timeout
		return ""
	_apply_side_effects(cmd)
	if cmd.has("move"):
		await _move_actor(String(cmd["move"]), cmd)
	if cmd.has("face"):
		var a: Node = _actor(String(cmd["face"]))
		if a != null and a.has_method("face"):
			a.call("face", String(cmd.get("dir", "s")))
	if cmd.has("anim"):
		var a2: Node = _actor(String(cmd["anim"]))
		if a2 != null and a2.has_method("play_anim"):
			a2.call("play_anim", String(cmd.get("name", "idle")))
	if cmd.has("show") or cmd.has("hide"):
		var a3: Node = _actor(String(cmd.get("show", cmd.get("hide", ""))))
		if a3 != null:
			a3.set("visible", cmd.has("show"))
	if cmd.has("teleport"):
		var a4: Node = _actor(String(cmd["teleport"]))
		var p: Variant = _marker(String(cmd.get("to", "")))
		if a4 != null and p != null and a4 is Node3D:
			(a4 as Node3D).global_position = p
	if cmd.has("camera"):
		camera_requested.emit(String(cmd["camera"]), _actor(String(cmd.get("focus", ""))))
	if cmd.has("universe"):
		Universe.set_universe(int(cmd["universe"]), bool(cmd.get("instant", false)))
	if cmd.has("music"):
		Audio.play_music(StringName(String(cmd["music"])))
	if cmd.has("stop_music"):
		Audio.stop_music(float(cmd.get("fade", 1.0)))
	if cmd.has("sfx"):
		Audio.play_sfx(String(cmd["sfx"]))
	if cmd.has("ambience"):
		Audio.play_ambience(StringName(String(cmd["ambience"])))
	if cmd.has("fade"):
		if String(cmd["fade"]) == "out":
			await Router.fade_out(float(cmd.get("s", 0.5)))
		else:
			await Router.fade_in(float(cmd.get("s", 0.5)))
	if cmd.has("emote"):
		var a5: Node = _actor(String(cmd["emote"]))
		if a5 != null and a5.has_method("emote"):
			a5.call("emote", String(cmd.get("kind", "!")))
	if cmd.has("shake"):
		var scene: Node = get_tree().current_scene
		if scene != null and scene.has_method("shake"):
			scene.call("shake", float(cmd["shake"]))
	if cmd.has("call"):
		var scene2: Node = get_tree().current_scene
		if scene2 != null and scene2.has_method(String(cmd["call"])):
			var r: Variant = scene2.callv(String(cmd["call"]), cmd.get("args", []))
			if r is Signal:
				await r
	if cmd.has("battle"):
		battle_result = {}
		_battle_waiting = true
		battle_requested.emit(StringName(String(cmd["battle"])), cmd)
		while _battle_waiting:
			await get_tree().process_frame
		if cmd.has("on_win") and bool(battle_result.get("victory", false)):
			return String(cmd["on_win"])
		if cmd.has("on_lose") and not bool(battle_result.get("victory", true)):
			return String(cmd["on_lose"])
	if cmd.has("go"):
		await Router.go(StringName(String(cmd["go"])), StringName(String(cmd.get("spawn", "start"))))
		return "__end__" if bool(cmd.get("end_after", true)) else ""
	return ""


func report_battle_result(result: Dictionary) -> void:
	battle_result = result
	_battle_waiting = false


func _apply_side_effects(cmd: Dictionary) -> void:
	if cmd.has("set") and cmd["set"] is Dictionary:
		var s: Dictionary = cmd["set"]
		Flags.set_flag(StringName(String(s.get("flag", ""))), StringName(String(s.get("state", "set"))), s.get("affinity", {}))
	if cmd.has("set_flag"):
		Flags.set_flag(StringName(String(cmd["set_flag"])), StringName(String(cmd.get("state", "set"))), cmd.get("affinity", {}))
	if cmd.has("affinity") and not cmd.has("set") and not cmd.has("set_flag"):
		var a: Dictionary = cmd["affinity"]
		Flags.add_affinity(int(a.get("light", 0)), int(a.get("dark", 0)), int(a.get("prismatic", 0)))
	if cmd.has("rift"):
		Flags.register_amber_rift(StringName(String(cmd["rift"])))
	if cmd.has("counter"):
		Flags.add_counter(StringName(String(cmd["counter"])), int(cmd.get("add", 1)))
	if cmd.has("var"):
		_vars[String(cmd["var"])] = cmd.get("value", true)
	if cmd.has("give_item"):
		Game.add_item(StringName(String(cmd["give_item"])), int(cmd.get("n", 1)))
	if cmd.has("key_item"):
		Game.add_key_item(StringName(String(cmd["key_item"])))
	if cmd.has("relic"):
		Game.add_relic(StringName(String(cmd["relic"])))
	if cmd.has("integrity"):
		Game.set_integrity(Game.crono_integrity + float(cmd["integrity"]))
	if cmd.has("set_integrity"):
		Game.set_integrity(float(cmd["set_integrity"]))
	if cmd.has("debt"):
		Game.set_debt(Game.sera_debt + float(cmd["debt"]))
	if cmd.has("recruit"):
		Game.recruit(StringName(String(cmd["recruit"])), int(cmd.get("level", -1)))
	if cmd.has("learn"):
		Game.learn_tech(StringName(String(cmd.get("who", "crono"))), StringName(String(cmd["learn"])))
	if cmd.has("chapter"):
		Game.set_chapter(int(cmd["chapter"]))
	if cmd.has("checkpoint"):
		Game.checkpoint = StringName(String(cmd["checkpoint"]))
	if cmd.has("sera_state"):
		Game.sera_in_story = String(cmd["sera_state"])
	if cmd.has("party"):
		var ids: Array[StringName] = []
		for p in cmd["party"]:
			ids.append(StringName(String(p)))
		Game.set_party(ids)
	if cmd.has("rtpc"):
		for k in cmd["rtpc"].keys():
			Audio.set_rtpc(String(k), float(cmd["rtpc"][k]))
	if cmd.has("save"):
		Saves.save(int(cmd["save"]))


func _test(cond: Dictionary) -> bool:
	if cond.has("flag"):
		if cond.has("state"):
			return Flags.is_state(StringName(String(cond["flag"])), StringName(String(cond["state"])))
		return Flags.has(StringName(String(cond["flag"])))
	if cond.has("not_flag"):
		return not Flags.has(StringName(String(cond["not_flag"])))
	if cond.has("light_min"):
		return Flags.light >= int(cond["light_min"])
	if cond.has("dark_min"):
		return Flags.dark >= int(cond["dark_min"])
	if cond.has("prismatic_min"):
		return Flags.prismatic >= int(cond["prismatic_min"])
	if cond.has("counter_min"):
		return Flags.counter(StringName(String(cond["counter_min"]))) >= int(cond.get("value", 1))
	if cond.has("recruited"):
		return Game.recruited.has(StringName(String(cond["recruited"])))
	if cond.has("var"):
		return _vars.get(String(cond["var"]), null) == cond.get("value", true)
	if cond.has("integrity_max"):
		return Game.crono_integrity <= float(cond["integrity_max"])
	if cond.has("chapter_min"):
		return Game.chapter >= int(cond["chapter_min"])
	return true


func _substitute(text: String) -> String:
	return text.replace("{integrity}", str(roundi(Game.crono_integrity))).replace("{debt}", str(roundi(Game.sera_debt)))


func _actor(id: String) -> Node:
	if id == "":
		return null
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("get_actor"):
		return scene.call("get_actor", StringName(id))
	return null


func _marker(name: String) -> Variant:
	if name == "":
		return null
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("get_marker"):
		return scene.call("get_marker", StringName(name))
	return null


func _move_actor(id: String, cmd: Dictionary) -> void:
	var a: Node = _actor(id)
	var p: Variant = _marker(String(cmd.get("to", "")))
	if a == null or p == null:
		return
	if a.has_method("walk_to"):
		if bool(cmd.get("wait", true)):
			await a.call("walk_to", p, float(cmd.get("speed", 2.5)))
		else:
			a.call("walk_to", p, float(cmd.get("speed", 2.5)))
	elif a is Node3D:
		(a as Node3D).global_position = p


func history() -> Array[Dictionary]:
	return _history
