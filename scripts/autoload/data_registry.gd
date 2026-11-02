## Loads every JSON data file under res://data/ into typed definitions and validates them (§18.2).
## Autoload name: Data.
extends Node

var techs: Dictionary = {}        ## StringName -> TechDef
var enemies: Dictionary = {}      ## key StringName -> EnemyDef
var enemies_by_id: Dictionary = {} ## E-number -> EnemyDef
var characters: Dictionary = {}   ## StringName -> Dictionary (kit)
var flags: Dictionary = {}        ## StringName -> Dictionary (flag def)
var universes: Dictionary = {}    ## int -> Dictionary
var statuses: Dictionary = {}
var items: Dictionary = {}
var encounters: Dictionary = {}
var dialogue: Dictionary = {}     ## script id -> Array of commands
var bosses: Dictionary = {}
var text: Dictionary = {}         ## text layer: kind (bestiary, techs, items, ambient, codex) -> Dictionary
var text_gaps: PackedStringArray = [] ## game ids that have no text yet (a warning, not an error)
var errors: PackedStringArray = []
var loaded: bool = false


func _ready() -> void:
	load_all()


func load_all() -> void:
	errors.clear()
	techs.clear()
	enemies.clear()
	enemies_by_id.clear()
	characters.clear()
	flags.clear()
	universes.clear()
	statuses.clear()
	items.clear()
	encounters.clear()
	dialogue.clear()
	bosses.clear()
	text.clear()
	text_gaps.clear()
	for d in _json_files("res://data/techs"):
		var list: Array = d.get("techs", [d]) if d is Dictionary else []
		for entry in list:
			var t := TechDef.from_dict(entry)
			for e in t.validation_errors():
				errors.append(e)
			if techs.has(t.id):
				errors.append("duplicate tech id %s" % t.id)
			techs[t.id] = t
	_check_tech_signatures()
	for d in _json_files("res://data/enemies"):
		var list2: Array = d.get("enemies", [d]) if d is Dictionary else []
		for entry in list2:
			var e := EnemyDef.from_dict(entry)
			for err in e.validation_errors():
				errors.append(err)
			if enemies.has(e.key):
				errors.append("duplicate enemy key %s" % e.key)
			enemies[e.key] = e
			if e.id != &"":
				enemies_by_id[e.id] = e
	for d in _json_files("res://data/characters"):
		if d is Dictionary and d.has("id"):
			characters[StringName(String(d["id"]))] = d
			for tid in d.get("techs", []):
				if not techs.has(StringName(String(tid.get("id", tid) if tid is Dictionary else tid))):
					errors.append("character %s lists unknown tech %s" % [d["id"], tid])
	for d in _json_files("res://data/flags"):
		for entry in d.get("flags", []):
			flags[StringName(String(entry["id"]))] = entry
	for d in _json_files("res://data/universes"):
		for entry in d.get("universes", []):
			universes[int(entry["id"])] = entry
	for d in _json_files("res://data/statuses"):
		for entry in d.get("statuses", []):
			statuses[StringName(String(entry["id"]))] = entry
	for d in _json_files("res://data/items"):
		for entry in d.get("items", []):
			items[StringName(String(entry["id"]))] = entry
	for d in _json_files("res://data/encounters"):
		for entry in d.get("encounters", []):
			encounters[StringName(String(entry["id"]))] = entry
			for ek in entry.get("enemies", []):
				var key: StringName = StringName(String(ek if ek is String else ek.get("key", "")))
				if not enemies.has(key):
					errors.append("encounter %s uses unknown enemy %s" % [entry["id"], key])
	for d in _json_files("res://data/bosses"):
		if d is Dictionary and d.has("id"):
			bosses[StringName(String(d["id"]))] = d
	for path in _list_files("res://data/dialogue", ".json"):
		var d2: Variant = _load_json(path)
		if d2 is Dictionary:
			for key in d2.keys():
				dialogue[StringName(String(key))] = d2[key]
	for path in _list_files("res://data/text", ".json"):
		var d3: Variant = _load_json(path)
		if d3 is Dictionary:
			text[StringName(path.get_file().get_basename())] = d3
	_check_text_layer()
	loaded = true
	if not errors.is_empty():
		push_warning("Data: %d validation problems" % errors.size())
		for e in errors:
			push_warning("  " + e)


func _check_tech_signatures() -> void:
	var seen: Dictionary = {}
	for id in techs.keys():
		var sig: String = (techs[id] as TechDef).signature()
		if seen.has(sig):
			errors.append("techs %s and %s share tags, shape and size" % [seen[sig], id])
		seen[sig] = id


## The text layer (data/text/*.json, written to the contract in docs/JOB_CHATGPT.md). A text key that
## names nothing in the game is an error; a game id without text is a gap, warned once, so content can
## land before its prose does.
func _check_text_layer() -> void:
	var bestiary: Dictionary = text.get(&"bestiary", {})
	for key in bestiary.keys():
		var k := StringName(String(key))
		if not enemies.has(k) and not bosses.has(k):
			errors.append("text/bestiary: unknown enemy or boss %s" % key)
	for k in enemies.keys():
		if not bestiary.has(String(k)):
			text_gaps.append("bestiary:%s" % k)
	for k in bosses.keys():
		if not bestiary.has(String(k)):
			text_gaps.append("bestiary:%s" % k)
	var tech_text: Dictionary = text.get(&"techs", {})
	for key in tech_text.keys():
		if not techs.has(StringName(String(key))):
			errors.append("text/techs: unknown tech %s" % key)
	for k in techs.keys():
		if not tech_text.has(String(k)):
			text_gaps.append("techs:%s" % k)
	var item_text: Dictionary = text.get(&"items", {})
	var granted: Dictionary = _dialogue_item_ids()
	for key in item_text.keys():
		if not items.has(StringName(String(key))) and not granted.has(String(key)):
			errors.append("text/items: %s is neither a catalogue item nor granted by any dialogue" % key)
	for k in items.keys():
		if not item_text.has(String(k)):
			text_gaps.append("items:%s" % k)
	for k in granted.keys():
		if not item_text.has(String(k)):
			text_gaps.append("items:%s" % k)
	var codex: Dictionary = text.get(&"codex", {})
	for key in codex.keys():
		var fid := StringName(String(key))
		if not flags.has(fid):
			errors.append("text/codex: unknown flag %s" % key)
			continue
		var pages: Dictionary = (codex[key] as Dictionary).get("pages", {})
		var state_ids: Array[String] = []
		for s in (flags[fid] as Dictionary).get("states", []):
			state_ids.append(String((s as Dictionary).get("id", "")))
		for sid in state_ids:
			if not pages.has(sid):
				text_gaps.append("codex:%s:%s" % [key, sid])
		for p in pages.keys():
			if not state_ids.has(String(p)):
				errors.append("text/codex: flag %s has no state %s" % [key, p])
	for k in flags.keys():
		if not codex.has(String(k)):
			text_gaps.append("codex:%s" % k)
	var ambient: Dictionary = text.get(&"ambient", {})
	for key in ambient.keys():
		if not (ambient[key] is Array) or (ambient[key] as Array).is_empty():
			errors.append("text/ambient: %s has no lines" % key)
	if not text_gaps.is_empty():
		push_warning("Data: %d game ids have no text yet (see Data.text_gaps)" % text_gaps.size())


## Every item id a dialogue command can hand out (give_item, key_item, relic), including inside choices.
func _dialogue_item_ids() -> Dictionary:
	var out: Dictionary = {}
	for cmds in dialogue.values():
		for cmd in cmds:
			if not (cmd is Dictionary):
				continue
			var nodes: Array = [cmd]
			nodes.append_array((cmd as Dictionary).get("choice", []))
			for node in nodes:
				if not (node is Dictionary):
					continue
				for key in ["give_item", "key_item", "relic"]:
					if (node as Dictionary).has(key):
						out[String((node as Dictionary)[key])] = true
	return out


func tech(id: StringName) -> TechDef:
	return techs.get(id, null)


## Text layer lookups. Each returns {} (or [] / "") when the prose has not been written yet.
func text_entry(kind: StringName, key: StringName) -> Dictionary:
	var table: Dictionary = text.get(kind, {})
	var v: Variant = table.get(String(key), {})
	return v if v is Dictionary else {}


func bestiary(key: StringName) -> Dictionary:
	return text_entry(&"bestiary", key)


func tech_text(id: StringName) -> Dictionary:
	return text_entry(&"techs", id)


func item_text(id: StringName) -> Dictionary:
	return text_entry(&"items", id)


func codex_title(flag: StringName) -> String:
	return String(text_entry(&"codex", flag).get("title", ""))


func codex_page(flag: StringName, state: StringName) -> String:
	var pages: Dictionary = text_entry(&"codex", flag).get("pages", {})
	return String(pages.get(String(state), ""))


func ambient_lines(location_id: StringName) -> Array:
	var table: Dictionary = text.get(&"ambient", {})
	var v: Variant = table.get(String(location_id), [])
	return v if v is Array else []


func enemy(key: StringName) -> EnemyDef:
	if enemies.has(key):
		return enemies[key]
	return enemies_by_id.get(key, null)


func character(id: StringName) -> Dictionary:
	return characters.get(id, {})


func flag_def(id: StringName) -> Dictionary:
	return flags.get(id, {})


func universe(id: int) -> Dictionary:
	return universes.get(id, {})


func dialogue_script(id: StringName) -> Array:
	return dialogue.get(id, [])


func _json_files(dir: String) -> Array:
	var out: Array = []
	for path in _list_files(dir, ".json"):
		var v: Variant = _load_json(path)
		if v != null:
			out.append(v)
	return out


func _list_files(dir: String, ext: String) -> PackedStringArray:
	var out := PackedStringArray()
	var da := DirAccess.open(dir)
	if da == null:
		return out
	da.list_dir_begin()
	var name: String = da.get_next()
	while name != "":
		var full: String = dir.path_join(name)
		if da.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_list_files(full, ext))
		elif name.ends_with(ext):
			out.append(full)
		name = da.get_next()
	da.list_dir_end()
	out.sort()
	return out


func _load_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("cannot open %s" % path)
		return null
	var txt: String = f.get_as_text()
	var json := JSON.new()
	var err: int = json.parse(txt)
	if err != OK:
		errors.append("%s: JSON error at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
