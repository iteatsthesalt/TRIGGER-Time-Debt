## Save slots as JSON under user://saves/. Autoload name: Saves.
extends Node

signal saved(slot: int)
signal loaded(slot: int)

const DIR := "user://saves"
const SLOTS := 9
const VERSION := 1


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func slot_path(slot: int) -> String:
	return "%s/slot_%02d.json" % [DIR, slot]


func save(slot: int) -> bool:
	var d := {
		"version": VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"game": Game.to_save(),
		"flags": Flags.to_save(),
		"universe": Universe.current,
	}
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("Saves: cannot write slot %d" % slot)
		return false
	f.store_string(JSON.stringify(d, "  "))
	f.close()
	saved.emit(slot)
	return true


func load(slot: int) -> bool:
	var d: Dictionary = peek(slot)
	if d.is_empty():
		return false
	Game.from_save(d.get("game", {}))
	Flags.from_save(d.get("flags", {}))
	Universe.set_universe(int(d.get("universe", 0)), true)
	loaded.emit(slot)
	return true


func peek(slot: int) -> Dictionary:
	if not FileAccess.file_exists(slot_path(slot)):
		return {}
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return {}
	var d: Variant = json.data
	return d if d is Dictionary else {}


func exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func delete(slot: int) -> void:
	if exists(slot):
		DirAccess.remove_absolute(slot_path(slot))


func summaries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(1, SLOTS + 1):
		var d: Dictionary = peek(i)
		if d.is_empty():
			out.append({"slot": i, "empty": true})
		else:
			var g: Dictionary = d.get("game", {})
			out.append({"slot": i, "empty": false, "chapter": int(g.get("chapter", 0)), "play_time": float(g.get("play_time", 0.0)),
				"integrity": float(g.get("crono_integrity", 100.0)), "timestamp": String(d.get("timestamp", "")), "location": String(g.get("location", ""))})
	return out
