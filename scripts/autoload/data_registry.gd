## Loads every JSON data file under res://data/ into typed definitions and validates them (§18.2).
## Autoload name: Data.
extends Node

var techs: Dictionary = {}        ## StringName -> TechDef
var enemies: Dictionary = {}      ## key StringName -> EnemyDef
var enemies_by_id: Dictionary = {} ## E-number -> EnemyDef
var characters: Dictionary = {}   ## StringName -> Dictionary (kit)
var flags: Dictionary = {}        ## StringName -> Dictionary (flag def)
var universes: Dictionary = {}    ## int -> Dictionary
var items: Dictionary = {}        ## StringName -> Dictionary (data/items: kind, effects; Game.grant routes by kind)
var encounters: Dictionary = {}
var dialogue: Dictionary = {}     ## script id -> Array of commands
var bosses: Dictionary = {}
var props: Dictionary = {}        ## prop key StringName -> Dictionary (data/props: universe, height_m, solid …)
var text: Dictionary = {}         ## text layer: kind (bestiary, techs, items, ambient, codex) -> Dictionary
var text_gaps: PackedStringArray = [] ## game ids that have no text yet (a warning, not an error)
var effects: Dictionary = {}      ## data/effects/effects.json: technique effect rows, flavour, pending (EffectTable)
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
	items.clear()
	encounters.clear()
	dialogue.clear()
	bosses.clear()
	props.clear()
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
	var fx: Variant = _load_json("res://data/effects/effects.json")
	effects = fx if fx is Dictionary else {}
	errors.append_array(EffectTable.validation_errors(techs, effects))
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
			errors.append_array(BossDef.from_dict(d).validation_errors())
	for d in _json_files("res://data/props"):
		for entry in d.get("props", []):
			_add_prop(entry)
	for path in _list_files("res://data/dialogue", ".json"):
		var d2: Variant = _load_json(path)
		if d2 is Dictionary:
			for key in d2.keys():
				dialogue[StringName(String(key))] = d2[key]
	for path in _list_files("res://data/text", ".json"):
		var d3: Variant = _load_json(path)
		if d3 is Dictionary:
			text[StringName(path.get_file().get_basename())] = d3
	errors.append_array(EffectTable.enemy_errors(enemies, bosses))
	_check_kits()
	_check_flag_refs()
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


## Kits: every unlock is a kind KitUnlocks evaluates and names defined flags and enemies; the weapon, vulnerable
## and resistant tags are CombatTags (a typo would never halve or double anything).
func _check_kits() -> void:
	for id in characters.keys():
		var kit: Dictionary = characters[id]
		errors.append_array(KitUnlocks.validation_errors(kit, flags, enemies))
		var groups: Dictionary = {"weapon": kit.get("weapon", {}).get("tags", []), "vulnerable": kit.get("vulnerable", []), "resistant": kit.get("resistant", [])}
		for g in groups.keys():
			for tg in groups[g]:
				if not CombatTags.is_known(StringName(String(tg))):
					errors.append("character %s: unknown tag %s in %s" % [id, tg, g])


## Flag references outside dialogue use one spelling, "Name" or "Name:State" (FlagRef): a tech's
## requires_flags and unlock flag, and a boss's *_by_branch keys and its adds' and actions' `requires`.
func _check_flag_refs() -> void:
	for tid in techs.keys():
		var t: TechDef = techs[tid]
		var refs: Array = []
		refs.append_array(t.requires_flags)  # a copy: never grow the TechDef's own list
		if t.unlock.has("flag"):
			refs.append(t.unlock["flag"])
		for r in refs:
			var e: String = FlagRef.error(String(r), flags)
			if e != "":
				errors.append("tech %s: %s" % [tid, e])
	for bid in bosses.keys():
		for r in boss_flag_refs(bosses[bid]):
			var e2: String = FlagRef.error(r, flags)
			if e2 != "":
				errors.append("boss %s: %s" % [bid, e2])


## The machine-read flag references in a boss file: *_by_branch keys anywhere, and the `requires` of its adds
## and phase actions (a `requires` that is prose, with no ":" or "=", is a design note and is skipped).
static func boss_flag_refs(d: Variant) -> Array[String]:
	var out: Array[String] = []
	if d is Dictionary:
		for k in (d as Dictionary).keys():
			var v: Variant = d[k]
			if String(k).ends_with("_by_branch") and v is Dictionary:
				for key in (v as Dictionary).keys():
					out.append(String(key))
			out.append_array(boss_flag_refs(v))
	elif d is Array:
		for v in d:
			if v is Dictionary and (v as Dictionary).get("requires", null) is String:
				var req: String = String(v["requires"])
				if (req.contains(":") or req.contains("=")) and not req.contains(" "):
					out.append(req)
			out.append_array(boss_flag_refs(v))
	return out


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


## The fields a data/props entry may carry (docs/ART_PIPELINE.md §6); anything else is a typo and an error.
const PROP_FIELDS: Array[String] = ["key", "universe", "height_m", "solid", "y_offset", "anims", "emission", "footprint", "pending", "request", "notes"]
const PROP_ANIM_FIELDS: Array[String] = ["match", "fps", "loop", "holds"]


## A prop is a billboard with a height in metres: the key names its universe (prp_u<n>_…), height_m is
## required and positive, the optional fields are typed, and nothing unknown is allowed.
func _add_prop(entry: Variant) -> void:
	if not (entry is Dictionary):
		errors.append("props: an entry is not an object")
		return
	var e: Dictionary = entry
	var key := StringName(String(e.get("key", "")))
	if key == &"":
		errors.append("props: entry without a key")
		return
	if props.has(key):
		errors.append("duplicate prop key %s" % key)
	for f in e.keys():
		if not PROP_FIELDS.has(String(f)):
			errors.append("prop %s: unknown field %s" % [key, f])
	var universe: int = int(e.get("universe", -1))
	if universe < 0 or universe > 9:
		errors.append("prop %s: universe must be 0..9" % key)
	elif not String(key).begins_with("prp_u%d_" % universe):
		errors.append("prop %s: key does not name its universe u%d" % [key, universe])
	var h: Variant = e.get("height_m", null)
	if not (h is float or h is int) or float(h) <= 0.0:
		errors.append("prop %s: height_m must be a positive number" % key)
	for name in ["solid", "pending"]:
		if e.has(name) and not (e[name] is bool):
			errors.append("prop %s: %s must be true or false" % [key, name])
	for name in ["y_offset", "emission"]:
		if e.has(name) and not (e[name] is float or e[name] is int):
			errors.append("prop %s: %s must be a number" % [key, name])
	if e.has("footprint") and not _footprint_ok(e["footprint"]):
		errors.append("prop %s: footprint must be [width, depth], \"posts\" or a list of [width, depth, x_offset] boxes" % key)
	var anims: Variant = e.get("anims", {})
	if not (anims is Dictionary):
		errors.append("prop %s: anims must be an object" % key)
	else:
		for a in (anims as Dictionary).keys():
			var spec: Variant = anims[a]
			if not (spec is Dictionary):
				errors.append("prop %s: anim %s must be an object" % [key, a])
				continue
			for f in (spec as Dictionary).keys():
				if not PROP_ANIM_FIELDS.has(String(f)):
					errors.append("prop %s: anim %s has unknown field %s" % [key, a, f])
	props[key] = e


## A prop footprint (PropBillboard.boxes): [width, depth], "posts", or a list of [width, depth(, x)].
static func _footprint_ok(fp: Variant) -> bool:
	if fp is String:
		return String(fp) == "posts"
	if not (fp is Array) or (fp as Array).is_empty():
		return false
	var a: Array = fp
	if not (a[0] is Array):
		return a.size() == 2 and (a[0] is float or a[0] is int) and (a[1] is float or a[1] is int)
	for b in a:
		if not (b is Array) or (b as Array).size() < 2 or (b as Array).size() > 3:
			return false
		for v in b:
			if not (v is float or v is int):
				return false
	return true


func prop(key: StringName) -> Dictionary:
	return props.get(key, {})


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
