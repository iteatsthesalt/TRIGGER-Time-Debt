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


func tech(id: StringName) -> TechDef:
	return techs.get(id, null)


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
