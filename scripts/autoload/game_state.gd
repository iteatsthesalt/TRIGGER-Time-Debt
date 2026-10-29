## Persistent game state: the roster, levels, party, inventory, Crono's integrity, Sera's debt,
## chapter progress and settings. Autoload name: Game.
extends Node

signal party_changed
signal integrity_changed(value: float)
signal debt_changed(value: float)
signal chapter_changed(chapter: int)
signal settings_changed

const ROSTER_ORDER: Array[StringName] = [&"crono", &"sera", &"krona", &"cassia", &"xyloph", &"vesper", &"glenn", &"static", &"omega", &"vaelos_child"]

## actor_id -> {level, xp, hp_ratio, known_techs: Array, equipment: {}, flags: {}}
var roster: Dictionary = {}
var active_party: Array[StringName] = [&"crono"]
var recruited: Array[StringName] = [&"crono", &"sera"]
var inventory: Dictionary = {}      ## item id -> count
var key_items: Array[StringName] = []
var relics: Array[StringName] = []
var crono_integrity: float = 100.0
var sera_debt: float = 0.0
var sera_permanent_baseline: float = 0.0
var krona_corruption: float = 0.0
var cassia_synergy: int = 0
var cassia_resentment: int = 0
var chapter: int = 0
var checkpoint: StringName = &"prologue_kitchen"
var location: StringName = &"guardia_kitchen"
var spawn_point: StringName = &"start"
var play_time: float = 0.0
var prometheus_core: bool = false
var max_bp: int = CombatConstants.MAX_BP
var max_spend: int = CombatConstants.MAX_SPEND
var parry_frames: int = CombatConstants.ENS_PARRY_FRAMES_BASE
var hold_upgraded: bool = false
var sera_in_story: String = "with"  ## with | hover | taken | absent
var endings_seen: Array[int] = []
var new_game_plus: bool = false
var settings: Dictionary = {
	"reduced_flicker": false, "flow_speed": 1.0, "text_size": 1.0, "screen_shake": true,
	"dof": true, "truth_lerp": true, "auto_sync_hold": false, "captions": true, "music": 0.8, "sfx": 0.9, "voice": 1.0,
}
var debug_mode: bool = false


func _ready() -> void:
	if roster.is_empty():
		new_game()


func _process(delta: float) -> void:
	play_time += delta


func new_game() -> void:
	roster.clear()
	for id in ROSTER_ORDER:
		roster[id] = {"level": 1, "xp": 0, "hp_ratio": 1.0, "known_techs": [], "equipment": {}, "flags": {}}
	roster[&"crono"]["level"] = 1
	roster[&"sera"]["level"] = 1
	active_party = [&"crono"]
	recruited = [&"crono", &"sera"]
	inventory = {"tonic": 3, "ether": 1}
	key_items.clear()
	relics.clear()
	crono_integrity = 100.0
	sera_debt = 0.0
	krona_corruption = 0.0
	cassia_synergy = 0
	cassia_resentment = 0
	chapter = 0
	checkpoint = &"prologue_kitchen"
	location = &"guardia_kitchen"
	spawn_point = &"start"
	prometheus_core = false
	max_bp = CombatConstants.MAX_BP
	max_spend = CombatConstants.MAX_SPEND
	parry_frames = CombatConstants.ENS_PARRY_FRAMES_BASE
	hold_upgraded = false
	sera_in_story = "with"
	Flags.reset_cycle(Flags.bias if new_game_plus else &"")
	if not new_game_plus:
		Flags.cycle = 1
	if new_game_plus:
		sera_permanent_baseline = 5.0
		sera_debt = 5.0
	party_changed.emit()


func join_level_for(id: StringName) -> int:
	match id:
		&"krona":
			return 6
		&"cassia":
			return 14
		&"xyloph":
			return 23
		&"vesper":
			return 33
		&"glenn":
			return 43
		&"static":
			return 52
		&"omega":
			return 68
	return 1


func recruit(id: StringName, join_level: int = -1) -> void:
	if not recruited.has(id):
		recruited.append(id)
		var lv: int = join_level if join_level > 0 else join_level_for(id)
		roster[id]["level"] = maxi(int(roster[id]["level"]), lv)
		_learn_defaults(id)
	if active_party.size() < 4 and not active_party.has(id):
		active_party.append(id)
	party_changed.emit()


func _learn_defaults(id: StringName) -> void:
	var kit: Dictionary = Data.character(id)
	for entry in kit.get("techs", []):
		var tid: String = String(entry.get("id", entry) if entry is Dictionary else entry)
		var unlock: Dictionary = entry.get("unlock", {}) if entry is Dictionary else {}
		if unlock.is_empty() or (unlock.has("chapter") and int(unlock["chapter"]) <= chapter) or unlock.get("on_join", false):
			learn_tech(id, StringName(tid))


func learn_tech(id: StringName, tech_id: StringName) -> void:
	if not roster.has(id):
		return
	var known: Array = roster[id]["known_techs"]
	if not known.has(String(tech_id)):
		known.append(String(tech_id))


func knows_tech(id: StringName, tech_id: StringName) -> bool:
	if not roster.has(id):
		return false
	return (roster[id]["known_techs"] as Array).has(String(tech_id))


func level_of(id: StringName) -> int:
	return int(roster.get(id, {}).get("level", 1))


func set_party(ids: Array[StringName]) -> void:
	active_party = ids.duplicate()
	party_changed.emit()


func bench_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in recruited:
		if not active_party.has(id) and sera_available_for(id):
			out.append(id)
	return out


func sera_available_for(id: StringName) -> bool:
	if id != &"sera":
		return true
	return sera_in_story == "with"


func add_item(id: StringName, n: int = 1) -> void:
	inventory[String(id)] = int(inventory.get(String(id), 0)) + n


func take_item(id: StringName, n: int = 1) -> bool:
	var have: int = int(inventory.get(String(id), 0))
	if have < n:
		return false
	inventory[String(id)] = have - n
	if inventory[String(id)] <= 0:
		inventory.erase(String(id))
	return true


func add_key_item(id: StringName) -> void:
	if not key_items.has(id):
		key_items.append(id)


func add_relic(id: StringName) -> void:
	if not relics.has(id):
		relics.append(id)


func set_integrity(v: float) -> void:
	crono_integrity = clampf(v, 0.0, 100.0)
	integrity_changed.emit(crono_integrity)


func set_debt(v: float) -> void:
	sera_debt = clampf(v, 0.0, CombatConstants.SERA_DEBT_CAP)
	debt_changed.emit(sera_debt)


func set_chapter(c: int) -> void:
	chapter = c
	# chapter-gated kit entries unlock for everyone recruited so far
	for id in recruited:
		_learn_defaults(id)
	chapter_changed.emit(c)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	settings_changed.emit()


func to_save() -> Dictionary:
	var ap: Array = []
	for a in active_party:
		ap.append(String(a))
	var rec: Array = []
	for r in recruited:
		rec.append(String(r))
	var ki: Array = []
	for k in key_items:
		ki.append(String(k))
	var rl: Array = []
	for r2 in relics:
		rl.append(String(r2))
	var ros: Dictionary = {}
	for id in roster.keys():
		ros[String(id)] = roster[id]
	return {
		"roster": ros, "active_party": ap, "recruited": rec, "inventory": inventory, "key_items": ki, "relics": rl,
		"crono_integrity": crono_integrity, "sera_debt": sera_debt, "sera_permanent_baseline": sera_permanent_baseline,
		"krona_corruption": krona_corruption, "cassia_synergy": cassia_synergy, "cassia_resentment": cassia_resentment,
		"chapter": chapter, "checkpoint": String(checkpoint), "location": String(location), "spawn_point": String(spawn_point),
		"play_time": play_time, "prometheus_core": prometheus_core, "max_bp": max_bp, "max_spend": max_spend,
		"parry_frames": parry_frames, "hold_upgraded": hold_upgraded, "sera_in_story": sera_in_story,
		"endings_seen": endings_seen, "new_game_plus": new_game_plus, "settings": settings,
	}


func from_save(d: Dictionary) -> void:
	roster.clear()
	for id in d.get("roster", {}).keys():
		roster[StringName(id)] = d["roster"][id]
	active_party.clear()
	for a in d.get("active_party", ["crono"]):
		active_party.append(StringName(String(a)))
	recruited.clear()
	for r in d.get("recruited", ["crono", "sera"]):
		recruited.append(StringName(String(r)))
	inventory = d.get("inventory", {})
	key_items.clear()
	for k in d.get("key_items", []):
		key_items.append(StringName(String(k)))
	relics.clear()
	for r2 in d.get("relics", []):
		relics.append(StringName(String(r2)))
	crono_integrity = float(d.get("crono_integrity", 100.0))
	sera_debt = float(d.get("sera_debt", 0.0))
	sera_permanent_baseline = float(d.get("sera_permanent_baseline", 0.0))
	krona_corruption = float(d.get("krona_corruption", 0.0))
	cassia_synergy = int(d.get("cassia_synergy", 0))
	cassia_resentment = int(d.get("cassia_resentment", 0))
	chapter = int(d.get("chapter", 0))
	checkpoint = StringName(String(d.get("checkpoint", "prologue_kitchen")))
	location = StringName(String(d.get("location", "guardia_kitchen")))
	spawn_point = StringName(String(d.get("spawn_point", "start")))
	play_time = float(d.get("play_time", 0.0))
	prometheus_core = bool(d.get("prometheus_core", false))
	max_bp = int(d.get("max_bp", CombatConstants.MAX_BP))
	max_spend = int(d.get("max_spend", CombatConstants.MAX_SPEND))
	parry_frames = int(d.get("parry_frames", CombatConstants.ENS_PARRY_FRAMES_BASE))
	hold_upgraded = bool(d.get("hold_upgraded", false))
	sera_in_story = String(d.get("sera_in_story", "with"))
	endings_seen.clear()
	for e in d.get("endings_seen", []):
		endings_seen.append(int(e))
	new_game_plus = bool(d.get("new_game_plus", false))
	for k in d.get("settings", {}).keys():
		settings[k] = d["settings"][k]
	party_changed.emit()
	integrity_changed.emit(crono_integrity)
	debt_changed.emit(sera_debt)
	settings_changed.emit()
