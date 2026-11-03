## Runs story scripts: arrays of command dictionaries from data/dialogue/*.json (or built in code).
## Autoload name: Story. The current location scene provides actors and markers through
## get_actor(id) and get_marker(name); everything else is handled here.
##
## Every command runs in three steps, so keys may be combined on one line: first the state side effects
## (set_flag, give_item, counter, ...), then the scene actions (move, face, fade, music, call, battle, go, ...),
## then the one verb that shows or steers (say, caption, choice; wait; goto, if, end). A `wait` that is a
## bool belongs to `move`; a `fade` that is a number belongs to `stop_music`.
extends Node

signal script_started(id: StringName)
signal script_finished(id: StringName)
signal line_shown(who: String, text: String)
signal choice_made(index: int, option: Dictionary)
signal battle_requested(encounter_id: StringName, context: Dictionary)
signal camera_requested(mode: String, focus: Node)

## The dialogue history keeps the last lines only (a long session would otherwise hold every line ever shown).
const HISTORY_MAX := 200

var running: bool = false
var current_id: StringName = &""
var box: DialogueBox
var layer: CanvasLayer
var battle_result: Dictionary = {}
## Set by tests/smoke runs: lines advance by themselves after this many seconds.
var auto_advance_s: float = -1.0
var auto_choice: int = -1
var skip_waits: bool = false
## The last `go` the Router refused (unknown location or a transition already running); &"" when none.
var last_refused_go: StringName = &""
var _battle_waiting: bool = false
## How many scripts are running (a phase beat runs nested inside the one waiting on its battle), and the depth of
## the script whose `battle` command is waiting: while that script is the innermost, the battle has the player.
var _depth: int = 0
var _battle_depth: int = 0
var _in_run_cmd: bool = false
var _history: Array[Dictionary] = []
var _vars: Dictionary = {}


func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	box = DialogueBox.new()
	box.visible = false
	layer.add_child(box)
	Game.new_game_started.connect(reset)


func is_running() -> bool:
	return running


## True while a script steers the screen: one is running and it is not merely waiting on the battle it started
## (its `battle` command). A story battle takes the player's input; a phase beat nested in it does not.
func blocks_battle_input() -> bool:
	return running and not (_battle_waiting and _depth == _battle_depth)


## A new game: script variables and the line history start empty.
func reset() -> void:
	_vars.clear()
	_history.clear()
	last_refused_go = &""


## Script variables travel with the save (Saves writes them under "story").
func to_save() -> Dictionary:
	return {"vars": _vars.duplicate(true)}


func from_save(d: Dictionary) -> void:
	_vars = d.get("vars", {}).duplicate(true) if d.get("vars", {}) is Dictionary else {}
	_history.clear()


## Run a script by id (from Data.dialogue) or an inline array of commands. A script may start while
## another is waiting on a battle (a boss phase beat): it runs nested and the outer one resumes after.
func run(id: StringName, inline: Array = []) -> void:
	if running and not _battle_waiting and not _in_run_cmd:
		push_warning("Story: script %s requested while %s is running" % [id, current_id])
		return
	var cmds: Array = inline if not inline.is_empty() else Data.dialogue_script(id)
	if cmds.is_empty():
		push_warning("Story: empty script %s" % id)
		return
	var nested: bool = running
	var outer_id: StringName = current_id
	var outer_waiting: bool = _battle_waiting
	var outer_battle_depth: int = _battle_depth
	running = true
	_depth += 1
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
	script_finished.emit(id)
	_depth -= 1
	if nested:
		current_id = outer_id
		_battle_waiting = outer_waiting
		_battle_depth = outer_battle_depth
	else:
		running = false
		_depth = 0
		current_id = &""


## One command: side effects, then scene actions, then the verb. Returns a label to jump to, "__end__" or "".
func _exec(cmd: Dictionary) -> String:
	_apply_side_effects(cmd)
	var jump: String = await _apply_actions(cmd)
	if jump != "":
		return jump
	return await _exec_verb(cmd)


## say / caption / choice show something; wait sleeps; goto / if / end steer. A choice's option may jump.
func _exec_verb(cmd: Dictionary) -> String:
	if cmd.has("say"):
		var who: String = String(cmd.get("who", ""))
		var text: String = _substitute(String(cmd["say"]))
		if cmd.has("voice"):
			Audio.play_voice(who, String(cmd["voice"]))
		line_shown.emit(who, text)
		_push_history(who, text)
		await box.say(who, text, String(cmd.get("portrait", "neutral")), String(cmd.get("style", "")), auto_advance_s)
	elif cmd.has("caption"):
		if bool(Game.settings.get("captions", true)):
			await box.caption(String(cmd["caption"]), auto_advance_s if auto_advance_s > 0.0 else 1.2)
	elif cmd.has("choice"):
		var picked: String = await _choose(cmd)
		if picked != "":
			return picked
	if cmd.has("wait") and (cmd["wait"] is float or cmd["wait"] is int):
		if not skip_waits:
			await get_tree().create_timer(float(cmd["wait"])).timeout
	if cmd.has("goto"):
		return String(cmd["goto"])
	if cmd.has("if"):
		if _test(cmd["if"]):
			return String(cmd.get("then", ""))
		return String(cmd.get("else", ""))
	if cmd.has("end"):
		return "__end__"
	return ""


## Offer the options whose `if` holds. Returns the picked option's goto label, or "".
func _choose(cmd: Dictionary) -> String:
	var options: Array = cmd["choice"]
	var visible: Array = []
	for o in options:
		if o.has("if") and not _test(o["if"]):
			continue
		visible.append(o)
	if visible.is_empty():
		push_warning("Story: every option of a choice in %s is hidden; skipping it" % current_id)
		return ""
	var idx: int = await box.choose(String(cmd.get("who", "")), String(cmd.get("prompt", "")), visible, auto_choice)
	idx = clampi(idx, 0, visible.size() - 1)
	var picked: Dictionary = visible[idx]
	choice_made.emit(idx, picked)
	_apply_side_effects(picked)
	if picked.has("goto"):
		return String(picked["goto"])
	return ""


## The scene actions. Returns a label only from `battle` (on_win / on_lose) and `go` (ends the script).
func _apply_actions(cmd: Dictionary) -> String:
	if cmd.has("move"):
		await _move_actor(String(cmd["move"]), cmd)
	if cmd.has("face"):
		_face_actor(String(cmd["face"]), cmd)
	if cmd.has("anim"):
		var a2: Node = _actor(String(cmd["anim"]))
		if a2 != null and a2.has_method("play_anim"):
			a2.call("play_anim", String(cmd.get("name", "idle")))
	if cmd.has("show") or cmd.has("hide"):
		var a3: Node = _actor(String(cmd.get("show", cmd.get("hide", ""))))
		if a3 != null:
			if cmd.has("show") and cmd.has("at"):
				_place(a3, _marker(String(cmd["at"])))
			a3.set("visible", cmd.has("show"))
	if cmd.has("teleport"):
		_place(_actor(String(cmd["teleport"])), _marker(String(cmd.get("to", ""))))
	if cmd.has("camera"):
		camera_requested.emit(String(cmd["camera"]), _focus_node(String(cmd.get("focus", ""))))
	if cmd.has("universe"):
		var from_u: int = Universe.target
		var to_u: int = int(cmd["universe"])
		Universe.set_universe(to_u, bool(cmd.get("instant", false)))
		if bool(cmd.get("jump", false)):
			GateJump.charge(from_u, to_u, get_tree().current_scene)
	if cmd.has("music"):
		if String(cmd["music"]) == "stop":
			Audio.stop_music(float(cmd.get("fade", 1.0)))
		else:
			Audio.play_music(StringName(String(cmd["music"])))
	if cmd.has("stop_music"):
		Audio.stop_music(float(cmd.get("fade", 1.0)))
	if cmd.has("sfx"):
		Audio.play_sfx(String(cmd["sfx"]))
	if cmd.has("ambience"):
		Audio.play_ambience(StringName(String(cmd["ambience"])))
	if cmd.has("fade") and cmd["fade"] is String:
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
	if cmd.has("run"):
		_in_run_cmd = true
		await run(StringName(String(cmd["run"])))
		_in_run_cmd = false
	if cmd.has("call"):
		var scene2: Node = get_tree().current_scene
		if scene2 != null and scene2.has_method(String(cmd["call"])):
			# await is transparent here: a coroutine (GDScriptFunctionState) or a Signal is waited for,
			# a plain return value comes back at once.
			await scene2.callv(String(cmd["call"]), cmd.get("args", []))
	if cmd.has("battle"):
		battle_result = {}
		_battle_waiting = true
		_battle_depth = _depth
		battle_requested.emit(StringName(String(cmd["battle"])), cmd)
		while _battle_waiting:
			await get_tree().process_frame
		if cmd.has("on_win") and bool(battle_result.get("victory", false)):
			return String(cmd["on_win"])
		if cmd.has("on_lose") and not bool(battle_result.get("victory", true)):
			return String(cmd["on_lose"])
	if cmd.has("go"):
		var dest: StringName = StringName(String(cmd["go"]))
		var ok: bool = await Router.go(dest, StringName(String(cmd.get("spawn", "start"))))
		if not ok:
			last_refused_go = dest
			push_warning("Story: %s asked to go to %s and the Router refused (unknown location or a transition already running)" % [current_id, dest])
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
		var pair: PackedStringArray = _flag_pair(String(cmd["set_flag"]), String(cmd.get("state", "")))
		Flags.set_flag(StringName(pair[0]), StringName(pair[1] if pair[1] != "" else "set"), cmd.get("affinity", {}))
	if cmd.has("affinity") and not cmd.has("set") and not cmd.has("set_flag"):
		var a: Dictionary = cmd["affinity"]
		Flags.add_affinity(int(a.get("light", 0)), int(a.get("dark", 0)), int(a.get("prismatic", 0)))
	if cmd.has("rift"):
		Flags.register_amber_rift(StringName(String(cmd["rift"])))
	if cmd.has("counter"):
		Flags.add_counter(StringName(String(cmd["counter"])), int(cmd.get("add", 1)))
	if cmd.has("var"):
		_vars[String(cmd["var"])] = cmd.get("value", true)
	# the item catalogue's kind decides where it goes (Game.grant); the verb is the fallback for an unlisted id
	if cmd.has("give_item"):
		Game.grant(StringName(String(cmd["give_item"])), int(cmd.get("n", 1)), &"consumable")
	if cmd.has("key_item"):
		Game.grant(StringName(String(cmd["key_item"])), 1, &"key")
	if cmd.has("relic"):
		Game.grant(StringName(String(cmd["relic"])), 1, &"relic")
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


## "Name:State" (the README form, the same one boot.gd reads from --flag=) or "Name" plus a separate state.
## An explicit state wins over the colon; the result is [name, state] with state "" when neither gives one.
func _flag_pair(id: String, state: String) -> PackedStringArray:
	if id.contains(":"):
		var parts: PackedStringArray = id.split(":", true, 1)
		return PackedStringArray([parts[0], state if state != "" else parts[1]])
	return PackedStringArray([id, state])


func _test(cond: Dictionary) -> bool:
	if cond.has("flag"):
		var pair: PackedStringArray = _flag_pair(String(cond["flag"]), String(cond.get("state", "")))
		if pair[1] != "":
			return Flags.is_state(StringName(pair[0]), StringName(pair[1]))
		return Flags.has(StringName(pair[0]))
	if cond.has("not_flag"):
		var pair2: PackedStringArray = _flag_pair(String(cond["not_flag"]), String(cond.get("state", "")))
		if pair2[1] != "":
			return not Flags.is_state(StringName(pair2[0]), StringName(pair2[1]))
		return not Flags.has(StringName(pair2[0]))
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
	if cond.has("has_key_item"):
		return Game.key_items.has(StringName(String(cond["has_key_item"])))
	if cond.has("has_item"):
		return int(Game.inventory.get(StringName(String(cond["has_item"])), 0)) > 0
	if cond.has("party_has"):
		return Game.active_party.has(StringName(String(cond["party_has"])))
	return true


func _substitute(text: String) -> String:
	return text.replace("{integrity}", str(roundi(Game.crono_integrity))).replace("{debt}", str(roundi(Game.sera_debt)))


func _push_history(who: String, text: String) -> void:
	_history.append({"who": who, "text": text})
	while _history.size() > HISTORY_MAX:
		_history.pop_front()


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


## A camera focus: an actor by id, else the marker node of that name (the location keeps them in `markers`).
func _focus_node(name: String) -> Node:
	var a: Node = _actor(name)
	if a != null or name == "":
		return a
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var markers: Variant = scene.get("markers")
	if markers is Dictionary and (markers as Dictionary).has(StringName(name)):
		var m: Variant = (markers as Dictionary)[StringName(name)]
		return m if m is Node else null
	return null


## A point in the scene: an actor's position by id, else a marker's position by name, else null.
func _point(name: String) -> Variant:
	var a: Node = _actor(name)
	if a is Node3D:
		return (a as Node3D).global_position
	return _marker(name)


func _place(a: Node, p: Variant) -> void:
	if a is Node3D and p is Vector3:
		(a as Node3D).global_position = p
		(a as Node3D).reset_physics_interpolation()


## `face` with `dir` (s/n/e/w) or with `to` (an actor id or a marker name the actor turns toward).
func _face_actor(id: String, cmd: Dictionary) -> void:
	var a: Node = _actor(id)
	if a == null:
		return
	if cmd.has("to") and a.has_method("face_toward"):
		var p: Variant = _point(String(cmd["to"]))
		if p is Vector3:
			a.call("face_toward", p)
			return
	if a.has_method("face"):
		a.call("face", String(cmd.get("dir", "s")))


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
		(a as Node3D).reset_physics_interpolation()


func history() -> Array[Dictionary]:
	return _history
