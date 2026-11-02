## Persistent game state: the roster, levels, party, inventory, Crono's integrity, Sera's debt,
## chapter progress and settings. Autoload name: Game. The settings are the player's, not the run's: they live in
## the settings file (Saves.read_settings / write_settings), never in a save slot.
extends Node

signal party_changed
signal integrity_changed(value: float)
signal debt_changed(value: float)
signal chapter_changed(chapter: int)
signal settings_changed
## A fresh run started (New Game): listeners that keep per-run state (Story's script variables) clear it.
signal new_game_started

## Item kinds (data/items/items.json `kind`): consumable and material go to the inventory, key to key_items,
## relic to relics, counter to the Flags counter the item names (Kirie Scales count toward Ending 8).
const ITEM_KINDS: Array[StringName] = [&"consumable", &"material", &"key", &"relic", &"counter"]
const ROSTER_ORDER: Array[StringName] = [&"crono", &"sera", &"krona", &"cassia", &"xyloph", &"vesper", &"glenn", &"static", &"omega", &"vaelos_child"]

## actor_id -> {level, xp, hp_ratio, known_techs: Array, equipment: {}, flags: {}}
var roster: Dictionary = {}
var active_party: Array[StringName] = [&"crono"]
var recruited: Array[StringName] = [&"crono", &"sera"]
var inventory: Dictionary = {}      ## item id -> count
var key_items: Array[StringName] = []
var relics: Array[StringName] = []
## Enemy keys whose drops have been awarded this cycle (RewardResolver): a kit `drop` unlock reads it.
var looted: Array[StringName] = []
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
## The spawn of the last save made in the Atrium (AtriumSiege.note_checkpoint): where a siege jumps back to.
var atrium_spawn: StringName = &""
var play_time: float = 0.0
var prometheus_core: bool = false
var max_bp: int = CombatConstants.MAX_BP
var max_spend: int = CombatConstants.MAX_SPEND
var parry_frames: int = CombatConstants.ENS_PARRY_FRAMES_BASE
var hold_upgraded: bool = false
var sera_in_story: String = "with"  ## with | hover | taken | absent
var endings_seen: Array[int] = []
var new_game_plus: bool = false
const DEFAULT_SETTINGS: Dictionary = {
	"reduced_flicker": false, "flow_speed": 1.0, "text_size": 1.0, "screen_shake": true,
	"dof": true, "truth_lerp": true, "auto_sync_hold": false, "captions": true, "music": 0.8, "sfx": 0.9, "voice": 1.0,
}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var debug_mode: bool = false
## The range a numeric setting may take: a value outside it (a probe's x4 battle flow) is never adopted.
const SETTING_RANGES: Dictionary = {
	"flow_speed": [0.75, 1.25], "text_size": [0.5, 2.0], "music": [0.0, 1.0], "sfx": [0.0, 1.0], "voice": [0.0, 1.0],
}


func _ready() -> void:
	adopt_settings(Saves.read_settings())
	if roster.is_empty():
		new_game()
	Flags.flag_set.connect(func(_id: StringName, _s: StringName) -> void: CapUpgrades.apply(self, Flags.flags))  # §15.7
	# a flag or an affinity threshold can unlock kit techs (KitUnlocks)
	Flags.flag_set.connect(func(_id: StringName, _s: StringName) -> void: refresh_unlocks(KitUnlocks.ON_FLAGS))
	Flags.affinity_changed.connect(func(_l: int, _d: int, _p: int) -> void: refresh_unlocks(KitUnlocks.ON_FLAGS))


func _process(delta: float) -> void:
	play_time += delta


func new_game() -> void:
	roster.clear()
	for id in ROSTER_ORDER:
		roster[id] = _default_row(1)
	active_party = [&"crono"]
	recruited = [&"crono", &"sera"]
	inventory = {"tonic": 3, "ether": 1}
	key_items.clear()
	relics.clear()
	looted.clear()
	crono_integrity = 100.0
	sera_debt = 0.0
	krona_corruption = 0.0
	cassia_synergy = 0
	cassia_resentment = 0
	chapter = 0
	checkpoint = &"prologue_kitchen"
	location = &"guardia_kitchen"
	spawn_point = &"start"
	atrium_spawn = &""
	prometheus_core = false
	max_bp = CombatConstants.MAX_BP
	max_spend = CombatConstants.MAX_SPEND
	parry_frames = CombatConstants.ENS_PARRY_FRAMES_BASE
	hold_upgraded = false
	sera_in_story = "with"
	# the one owner of the cycle reset; New Game+ biases +10 toward the finished cycle's dominant affinity (§15.10)
	Flags.reset_cycle(Flags.dominant_affinity() if new_game_plus else &"")
	if not new_game_plus:
		Flags.cycle = 1
	# Sera remembers the loop (§15.10): 5 permanent Debt on New Game+, none on a fresh file
	sera_permanent_baseline = 5.0 if new_game_plus else 0.0
	sera_debt = sera_permanent_baseline
	party_changed.emit()
	new_game_started.emit()


func _default_row(level: int) -> Dictionary:
	return {"level": level, "xp": 0, "hp_ratio": 1.0, "known_techs": [], "equipment": {}, "flags": {}}


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
	if Data.character(id).is_empty() and not roster.has(id):
		push_warning("Game.recruit: no kit and no roster row for %s; ignored" % id)
		return
	if not roster.has(id):  # an actor added after this save was written
		roster[id] = _default_row(1)
	if not recruited.has(id):
		recruited.append(id)
		var lv: int = join_level if join_level > 0 else join_level_for(id)
		roster[id]["level"] = maxi(int(roster[id]["level"]), lv)
		_learn_defaults(id)
	if active_party.size() < 4 and not active_party.has(id):
		active_party.append(id)
	party_changed.emit()


## Learn the kit entries of `id` whose unlock holds (KitUnlocks). With `kinds`, only the entries that wait on
## one of those kinds are checked (a flag set, a level-up, a drop); learning is idempotent.
func _learn_defaults(id: StringName, kinds: Array[String] = []) -> void:
	for pair in KitUnlocks.entries(Data.character(id)):
		var unlock: Dictionary = pair[1]
		if not kinds.is_empty() and not KitUnlocks.waits_on(unlock, kinds):
			continue
		if KitUnlocks.holds(unlock, id):
			learn_tech(id, StringName(String(pair[0])))


## Everyone who can learn: the recruited and any guest with a roster row (Marle).
func learners() -> Array[StringName]:
	var out: Array[StringName] = recruited.duplicate()
	for id in roster.keys():
		if not out.has(id) and bool(Data.character(id).get("guest", false)):
			out.append(id)
	return out


## Re-check the kit entries that wait on `kinds` for every learner (KitUnlocks.ON_FLAGS / ON_LEVEL / ON_DROP).
func refresh_unlocks(kinds: Array[String]) -> void:
	for id in learners():
		_learn_defaults(id, kinds)


## A member's level after a battle (BattleAftermath.write_back): level-gated kit entries arrive (§15.8).
func set_level(id: StringName, lv: int) -> void:
	if not roster.has(id):
		return
	var before: int = int(roster[id]["level"])
	roster[id]["level"] = lv
	if lv > before:
		_learn_defaults(id, KitUnlocks.ON_LEVEL)


## An enemy's drops were awarded (RewardResolver): kit `drop` unlocks naming it arrive.
func note_drop(enemy_key: StringName) -> void:
	if looted.has(enemy_key):
		return
	looted.append(enemy_key)
	refresh_unlocks(KitUnlocks.ON_DROP)


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
	for id in ids:
		_ensure_guest_row(id)
	active_party = ids.duplicate()
	party_changed.emit()


## A guest (Combat Laws 2.2: Marle in the Prologue; her kit says "guest": true) walks with the party without
## being recruited, so she never sits on the Bench, but she gets a roster row the first time she is in a
## party (her join level, her kit's unlocked techs) so her level, XP, HP and Tech deck work like anyone's.
func _ensure_guest_row(id: StringName) -> void:
	if recruited.has(id) or not bool(Data.character(id).get("guest", false)):
		return
	if not roster.has(id):
		roster[id] = {"level": join_level_for(id), "xp": 0, "hp_ratio": 1.0, "known_techs": [], "equipment": {}, "flags": {}}
	_learn_defaults(id)


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


## Give `n` of an item by its catalogue kind: the one path for boss and enemy drops (RewardResolver) and
## dialogue grants. An id the catalogue does not define goes by `fallback` with a warning (lint rejects one).
## Returns the kind it was given as.
func grant(id: StringName, n: int = 1, fallback: StringName = &"relic") -> StringName:
	var def: Dictionary = Data.items.get(id, {})
	var kind: StringName = StringName(String(def.get("kind", "consumable")))
	if def.is_empty():
		push_warning("Game.grant: %s is not in data/items/items.json; given as %s" % [id, fallback])
		kind = fallback
	match kind:
		&"key":
			add_key_item(id)
		&"relic":
			add_relic(id)
		&"counter":
			Flags.add_counter(StringName(String(def.get("counter", id))), n)
		_:
			add_item(id, n)
	return kind


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
	Saves.write_settings(settings)


## Every option back to its default (the test runner starts from these, whatever the player chose).
func reset_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	settings_changed.emit()


## Merge settings read from a file: only the keys the game knows, of their type, numbers inside SETTING_RANGES.
func adopt_settings(d: Dictionary) -> void:
	for k in d.keys():
		if setting_ok(String(k), d[k]):
			settings[String(k)] = float(d[k]) if settings[String(k)] is float else d[k]
	settings_changed.emit()


func setting_ok(key: String, v: Variant) -> bool:
	if not settings.has(key):
		return false
	var current: Variant = settings[key]
	if current is float:
		if not (v is float or v is int):
			return false
		var r: Array = SETTING_RANGES.get(key, [-INF, INF])
		return float(v) >= float(r[0]) and float(v) <= float(r[1])
	return typeof(v) == typeof(current)


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
	var lt: Array = []
	for k2 in looted:
		lt.append(String(k2))
	return {
		"roster": ros, "active_party": ap, "recruited": rec, "inventory": inventory, "key_items": ki, "relics": rl, "looted": lt,
		"crono_integrity": crono_integrity, "sera_debt": sera_debt, "sera_permanent_baseline": sera_permanent_baseline,
		"krona_corruption": krona_corruption, "cassia_synergy": cassia_synergy, "cassia_resentment": cassia_resentment,
		"chapter": chapter, "checkpoint": String(checkpoint), "location": String(location), "spawn_point": String(spawn_point),
		"atrium_spawn": String(atrium_spawn),
		"play_time": play_time, "prometheus_core": prometheus_core, "max_bp": max_bp, "max_spend": max_spend,
		"parry_frames": parry_frames, "hold_upgraded": hold_upgraded, "sera_in_story": sera_in_story,
		"endings_seen": endings_seen, "new_game_plus": new_game_plus,
	}


func from_save(d: Dictionary) -> void:
	roster.clear()
	for id in ROSTER_ORDER:  # an actor added after the save was written still has a row
		roster[id] = _default_row(1)
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
	looted.clear()
	for k2 in d.get("looted", []):
		looted.append(StringName(String(k2)))
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
	atrium_spawn = StringName(String(d.get("atrium_spawn", "")))
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
	party_changed.emit()
	integrity_changed.emit(crono_integrity)
	debt_changed.emit(sera_debt)
