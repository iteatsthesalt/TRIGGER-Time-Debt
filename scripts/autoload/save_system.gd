## Save slots as JSON under user://saves/ and the player's settings in user://settings.cfg. Autoload name: Saves.
## Slot 0 is the autosave every checkpoint writes; 1..SLOTS are manual slots. Every file is written atomically
## (a temporary file renamed over it), so an interrupted write leaves the previous file whole. A slot is loaded
## only when it parses as a save this build understands (status): a corrupt or newer-format file reads as no save.
## `suspended` keeps every write in this process's own scratch directory (user://scratch/<pid>, ScratchDir): the
## probes, the test runner and the capture harness set it, the `--no-save` user argument and a debug start
## (BootArgs.suspends_saves) do too, so such a run never touches the player's saves or settings, and two of them
## running at once never touch each other's.
extends Node

signal saved(slot: int)
signal loaded(slot: int)

const DIR := "user://saves"
const SCRATCH_DIR := "user://scratch"
const SETTINGS_FILE := "settings.cfg"
const SLOTS := 9
## 2: the settings left the slot for the settings file; Flags restores int-keyed codex leans.
const VERSION := 2

## A slot's state (status): no file, a save this build loads, a file that is not a save, a later build's save.
const EMPTY := &"empty"
const LOADABLE := &"ok"
const CORRUPT := &"corrupt"
const NEWER := &"newer"

var suspended: bool = OS.get_cmdline_user_args().has("--no-save")
var _scratch: String = ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(dir())


## The run is over: its scratch directory goes with it.
func _exit_tree() -> void:
	if _scratch != "":
		ScratchDir.remove(_scratch)
		_scratch = ""


## This process's scratch directory, claimed (emptied) on its first use: SCRATCH_DIR/<pid>.
func scratch_dir() -> String:
	if _scratch == "":
		_scratch = ScratchDir.claim(SCRATCH_DIR, OS.get_process_id())
	return _scratch


func dir() -> String:
	return scratch_dir() + "/saves" if suspended else DIR


func slot_path(slot: int) -> String:
	return "%s/slot_%02d.json" % [dir(), slot]


func settings_path() -> String:
	return "%s/%s" % [scratch_dir(), SETTINGS_FILE] if suspended else "user://" + SETTINGS_FILE


func save(slot: int) -> bool:
	AtriumSiege.note_checkpoint()  # a save in the Atrium is the checkpoint a siege jumps back to (§16.3)
	var d := {
		"version": VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"game": Game.to_save(),
		"flags": Flags.to_save(),
		"universe": Universe.current,  # Continue lands in it, so the Router does not charge a gate jump
		"story": Story.to_save(),
	}
	if not write_atomic(slot_path(slot), JSON.stringify(d, "  ")):
		push_error("Saves: cannot write slot %d" % slot)
		return false
	saved.emit(slot)
	return true


func load(slot: int) -> bool:
	var r: Array = _read(slot)
	if r[0] != LOADABLE:
		if r[0] != EMPTY:
			push_warning("Saves: slot %d is %s; not loaded" % [slot, r[0]])
		return false
	var d: Dictionary = r[1]
	Game.from_save(d.get("game", {}))
	# a version 1 save carried the settings: they come over once, while no settings file exists yet
	var legacy: Variant = (d.get("game", {}) as Dictionary).get("settings", null)
	if legacy is Dictionary and not FileAccess.file_exists(settings_path()):
		Game.adopt_settings(legacy)
		write_settings(Game.settings)
	Flags.from_save(d.get("flags", {}))
	Universe.set_universe(int(d.get("universe", 0)), true)
	Story.from_save(d.get("story", {}))
	loaded.emit(slot)
	return true


## EMPTY, LOADABLE, CORRUPT or NEWER (see the constants).
func status(slot: int) -> StringName:
	return _read(slot)[0]


## The slot's save when it can be loaded, else {}.
func peek(slot: int) -> Dictionary:
	var r: Array = _read(slot)
	return r[1] if r[0] == LOADABLE else {}


## A file is in the slot (it may still be corrupt: status tells).
func exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".tmp")


func delete(slot: int) -> void:
	for p in [slot_path(slot), slot_path(slot) + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Every slot, the autosave (slot 0) first: {slot, autosave, status, empty} plus, for a loadable save, chapter,
## play_time, integrity, timestamp and location.
func summaries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(0, SLOTS + 1):
		var r: Array = _read(i)
		var row: Dictionary = {"slot": i, "autosave": i == 0, "status": String(r[0]), "empty": r[0] != LOADABLE}
		if r[0] == LOADABLE:
			var g: Dictionary = (r[1] as Dictionary).get("game", {})
			row.merge({"chapter": int(g.get("chapter", 0)), "play_time": float(g.get("play_time", 0.0)),
				"integrity": float(g.get("crono_integrity", 100.0)), "timestamp": String((r[1] as Dictionary).get("timestamp", "")),
				"location": String(g.get("location", ""))})
		out.append(row)
	return out


## [status, save]: the save is migrated to VERSION when it is loadable.
func _read(slot: int) -> Array:
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		path += ".tmp"  # the rename was cut after the old slot went (Windows replaces in two steps)
		if not FileAccess.file_exists(path):
			return [EMPTY, {}]
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		return [CORRUPT, {}]
	var d: Dictionary = json.data
	if not (d.get("game") is Dictionary) or not (d.get("flags") is Dictionary):
		return [CORRUPT, {}]
	if int(d.get("version", 1)) > VERSION:
		return [NEWER, {}]
	return [LOADABLE, migrate(d)]


## Flag ids a version 1 save can hold that the game no longer reads, and the "Name:State" each became: Glenn's
## offer and refusal were two flags before they were the states of Glenn_Duals (296eba2, DATA-15).
const RETIRED_FLAGS_V1: Dictionary = {
	"Glenn_Duals_Offered": "Glenn_Duals:Granted",
	"Glenn_Duals_Refused": "Glenn_Duals:Refused",
}


## Bring an older save up to VERSION. Version 1 carried the settings (load adopts them once), String-keyed codex
## leans (Flags.from_save re-keys them) and the retired flag ids of RETIRED_FLAGS_V1, renamed here: a refusal kept
## under its old id would read as no refusal, and the honour check that writes the new one never runs again.
static func migrate(d: Dictionary) -> Dictionary:
	if int(d.get("version", 1)) < 2:
		var engine: Variant = d.get("flags", {})
		if engine is Dictionary and (engine as Dictionary).get("flags") is Dictionary:
			rename_flags((engine as Dictionary)["flags"], RETIRED_FLAGS_V1)
	d["version"] = VERSION
	return d


## Rename the flags of `flags` (id -> state, a save's form) that `retired` lists (old id -> "Name:State"); a flag
## already set under its new id keeps its state.
static func rename_flags(flags: Dictionary, retired: Dictionary) -> void:
	for old in retired.keys():
		if not flags.has(old):
			continue
		var to: PackedStringArray = FlagRef.split(String(retired[old]))
		if not flags.has(to[0]):
			flags[to[0]] = to[1] if to[1] != "" else "set"
		flags.erase(old)


## Write `text` to `path` through a temporary file renamed over it.
static func write_atomic(path: String, text: String) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp: String = path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.flush()
	var ok: bool = f.get_error() == OK
	f.close()
	if not ok:
		DirAccess.remove_absolute(tmp)
		return false
	return DirAccess.rename_absolute(tmp, path) == OK


## The player's settings, kept outside every slot (DECISIONS "Settings live in their own file"); {} when none.
func read_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path()) != OK or not cfg.has_section("settings"):
		return {}
	var out: Dictionary = {}
	for k in cfg.get_section_keys("settings"):
		out[k] = cfg.get_value("settings", k)
	return out


func write_settings(settings: Dictionary) -> bool:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("settings", String(k), settings[k])
	return write_atomic(settings_path(), cfg.encode_to_text())
