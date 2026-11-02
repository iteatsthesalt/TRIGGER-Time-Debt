## Dialogue validation (data/dialogue/*.json, README "Dialogue and cutscenes"), run by Data.load_all; the same rules
## run in tools/build/lint_data.py for check.sh. Errors: a script id defined in two files; a jump (goto, then, else,
## a choice's goto, a battle's on_win / on_lose) to a label its script lacks; `run` of an unknown script; a flag
## written or tested that is neither a data/flags flag in one of its states nor a declared script-local marker
## (data/flags/script_local.json) in one of its states; an item, encounter, boss, tech or character id that does not
## exist; an `sfx` cue AudioDirector cannot find; a `sera_state` Game does not know; a `go` to an id the Router does
## not register. Warnings: a music id with no track yet, a `go` to a registered location whose scene is not built.
class_name DialogueCheck
extends RefCounted

const SFX_DIR := "res://audio/sfx"
const MUSIC_DIR := "res://audio/music"
## The stems AudioDirector.play_music loads beside <id>.ogg (kept in step with it).
const MUSIC_STEMS: Array[String] = ["box", "piano", "strings", "hiss", "bass", "drums", "lead", "pad", "quartet", "crackle", "wind", "tick"]
## Game.sera_in_story values besides BattleRoster.HOVER_STATES (the hover states put Sera on the Turn Bar).
const SERA_STATES: Array[String] = ["with", "taken", "absent"]
## Command keys whose value is a label of the same script.
const JUMP_KEYS: Array[String] = ["goto", "then", "else", "on_win", "on_lose"]
const ITEM_VERBS: Array[String] = ["give_item", "key_item", "relic"]


## Adds one file's scripts to `into` (origin remembers the file of each id). A script id another file already
## defined is an error: the later file would silently replace it.
static func merge(into: Dictionary, origin: Dictionary, file: String, scripts: Dictionary) -> PackedStringArray:
	var errs := PackedStringArray()
	for key in scripts.keys():
		var id := StringName(String(key))
		if into.has(id):
			errs.append("dialogue: script %s is defined in %s and again in %s" % [id, origin.get(id, "?"), file])
		into[id] = scripts[key]
		origin[id] = file
	return errs


## The script-local markers of data/flags/script_local.json files (their `script_local` lists): id -> states.
static func script_flags_from(files: Array) -> Dictionary:
	var out: Dictionary = {}
	for d in files:
		if not (d is Dictionary):
			continue
		for entry in (d as Dictionary).get("script_local", []):
			if entry is Dictionary and (entry as Dictionary).has("id"):
				out[StringName(String(entry["id"]))] = (entry as Dictionary).get("states", ["set"])
	return out


## `refs` holds Data's tables: flags, script_flags (script_flags_from), items, encounters, bosses, techs and
## characters, and locations (Router.DEFAULT_LOCATIONS: id -> scene path). Returns {errors, warnings}.
static func validate(dialogue: Dictionary, refs: Dictionary) -> Dictionary:
	var errs := PackedStringArray()
	var warns := PackedStringArray()
	for sid in dialogue.keys():
		var cmds: Variant = dialogue[sid]
		if not (cmds is Array):
			errs.append("dialogue %s: a script is a list of commands" % sid)
			continue
		var labels: Dictionary = {}
		for c in cmds:
			if c is Dictionary and (c as Dictionary).has("label"):
				labels[String(c["label"])] = true
		for c in cmds:
			if not (c is Dictionary):
				errs.append("dialogue %s: a command is not an object" % sid)
				continue
			_check_command("dialogue %s" % sid, c, labels, dialogue, refs, errs, warns)
	return {"errors": errs, "warnings": warns}


static func _check_command(where: String, cmd: Dictionary, labels: Dictionary, dialogue: Dictionary, refs: Dictionary, errs: PackedStringArray, warns: PackedStringArray) -> void:
	var nodes: Array = [cmd]
	for o in cmd.get("choice", []):
		if o is Dictionary:
			nodes.append(o)
	for node in nodes:
		var n: Dictionary = node
		for key in JUMP_KEYS:
			if n.has(key) and String(n[key]) != "" and not labels.has(String(n[key])):
				errs.append("%s: %s jumps to a missing label %s" % [where, key, n[key]])
		for e in _flag_errors(n, refs):
			errs.append("%s: %s" % [where, e])
		for verb in ITEM_VERBS:
			if n.has(verb) and not (refs.get("items", {}) as Dictionary).has(StringName(String(n[verb]))):
				errs.append("%s: %s %s is not in data/items" % [where, verb, n[verb]])
	_check_ids(where, cmd, dialogue, refs, errs)
	if cmd.has("sfx") and not sfx_exists(String(cmd["sfx"])):
		errs.append("%s: sfx %s has no file under %s (AudioDirector plays silence)" % [where, cmd["sfx"], SFX_DIR])
	if cmd.has("music") and String(cmd["music"]) != "stop" and not music_exists(String(cmd["music"])):
		warns.append("%s: music %s has no track under %s yet" % [where, cmd["music"], MUSIC_DIR])
	if cmd.has("sera_state") and not (SERA_STATES.has(String(cmd["sera_state"])) or BattleRoster.HOVER_STATES.has(String(cmd["sera_state"]))):
		errs.append("%s: sera_state %s is none of %s" % [where, cmd["sera_state"], ", ".join(PackedStringArray(SERA_STATES + BattleRoster.HOVER_STATES))])
	if cmd.has("go"):
		var locations: Dictionary = refs.get("locations", {})
		var dest := StringName(String(cmd["go"]))
		if not locations.has(dest):
			errs.append("%s: go %s is not a Router location (scene_router.gd DEFAULT_LOCATIONS)" % [where, dest])
		elif not ResourceLoader.exists(String(locations[dest])):
			warns.append("%s: go %s is scheduled; its scene %s is not built yet (the Router refuses it)" % [where, dest, locations[dest]])


## Ids that must name something: run (a script), battle (an encounter), boss_id, learn (a tech), recruit and party
## (characters).
static func _check_ids(where: String, cmd: Dictionary, dialogue: Dictionary, refs: Dictionary, errs: PackedStringArray) -> void:
	if cmd.has("run") and not dialogue.has(StringName(String(cmd["run"]))):
		errs.append("%s: run %s names no script" % [where, cmd["run"]])
	if cmd.has("battle") and String(cmd["battle"]) != "" and not (refs.get("encounters", {}) as Dictionary).has(StringName(String(cmd["battle"]))):
		errs.append("%s: battle %s is not an encounter" % [where, cmd["battle"]])
	if String(cmd.get("boss_id", "")) != "" and not (refs.get("bosses", {}) as Dictionary).has(StringName(String(cmd["boss_id"]))):
		errs.append("%s: boss_id %s is not a boss" % [where, cmd["boss_id"]])
	if cmd.has("learn") and not (refs.get("techs", {}) as Dictionary).has(StringName(String(cmd["learn"]))):
		errs.append("%s: learn %s is not a tech" % [where, cmd["learn"]])
	var chars: Dictionary = refs.get("characters", {})
	var who: Array = [cmd["recruit"]] if cmd.has("recruit") else []
	if cmd.get("party", null) is Array:
		who.append_array(cmd["party"])
	for c in who:
		if not chars.has(StringName(String(c))):
			errs.append("%s: %s is not a character" % [where, c])


## The flags a command (or a choice option) writes or tests, as [name, state] pairs; a write with no state sets
## "set" (StoryRunner), a test with no state asks only that the flag is set.
static func flag_uses(n: Dictionary) -> Array:
	var out: Array = []
	if n.get("set", null) is Dictionary:
		var s: Dictionary = n["set"]
		out.append([String(s.get("flag", "")), String(s.get("state", "set"))])
	if n.has("set_flag"):
		var p: PackedStringArray = _pair(String(n["set_flag"]), String(n.get("state", "")))
		out.append([p[0], p[1] if p[1] != "" else "set"])
	for ck in ["if", "show_if"]:
		var cond: Variant = n.get(ck, null)
		if not (cond is Dictionary):
			continue
		for fk in ["flag", "not_flag"]:
			if (cond as Dictionary).has(fk):
				var p2: PackedStringArray = _pair(String(cond[fk]), String(cond.get("state", "")))
				out.append([p2[0], p2[1]])
	return out


static func _flag_errors(n: Dictionary, refs: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var flags: Dictionary = refs.get("flags", {})
	var local: Dictionary = refs.get("script_flags", {})
	for use in flag_uses(n):
		var id := StringName(String(use[0]))
		var state: String = use[1]
		if flags.has(id):
			var e: String = FlagRef.error(String(id) if state == "" else "%s:%s" % [id, state], flags)
			if e != "":
				out.append(e)
		elif local.has(id):
			if state != "" and not (local[id] as Array).has(state):
				out.append("script-local flag %s has no state %s (data/flags/script_local.json)" % [id, state])
		else:
			out.append("flag %s is neither in data/flags nor a declared script-local flag (data/flags/script_local.json)" % id)
	return out


## StoryRunner's "Name:State" reading: an explicit state wins over the colon.
static func _pair(id: String, state: String) -> PackedStringArray:
	var p: PackedStringArray = FlagRef.split(id)
	return PackedStringArray([p[0], state if state != "" else p[1]])


## AudioDirector._find_sfx's lookup: audio/sfx/<id>.wav or .ogg, or numbered variations <id>_01.wav...
static func sfx_exists(id: String) -> bool:
	var base: String = "%s/%s" % [SFX_DIR, id]
	return ResourceLoader.exists(base + ".wav") or ResourceLoader.exists(base + ".ogg") or ResourceLoader.exists(base + "_01.wav")


## AudioDirector.play_music's lookup: audio/music/<id>.ogg or any of its stems <id>__<stem>.ogg.
static func music_exists(id: String) -> bool:
	if ResourceLoader.exists("%s/%s.ogg" % [MUSIC_DIR, id]):
		return true
	for stem in MUSIC_STEMS:
		if ResourceLoader.exists("%s/%s__%s.ogg" % [MUSIC_DIR, id, stem]):
			return true
	return false
