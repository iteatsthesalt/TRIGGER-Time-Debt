## A boss loaded from data/bosses/<id>.json (Combat Laws Bible §14). A boss is one HP pool with ordered
## phases; each phase supplies its own shield configuration, tags, actions and mechanics. phase_def(i)
## builds the EnemyDef the coordinator's brain reads while that phase is active.
class_name BossDef
extends RefCounted

var id: StringName = &""
var display_name: String = ""
var universe: int = 0
var level: int = 1
var hp: int = 1000
var sprite: StringName = &""
var size: float = 2.0
var body_radius: float = 1.0
var fps: float = 60.0
var is_metal: bool = false
var tags: Array[StringName] = []
var resist: Array[StringName] = []
var immune: Array[StringName] = []
var arena_hazards: Array = []
var adds: Array = []
var phases: Array = []
var branches: Array = []
var drops: Array = []
var flags: Dictionary = {}
var notes: String = ""
var raw: Dictionary = {}


static func from_dict(d: Dictionary) -> BossDef:
	var b := BossDef.new()
	b.raw = d
	b.id = StringName(String(d.get("id", "")))
	b.display_name = String(d.get("name", b.id))
	b.universe = int(d.get("universe", 0))
	b.level = int(d.get("level", 1))
	b.hp = int(d.get("hp", 1000))
	b.sprite = StringName(String(d.get("sprite", "")))
	b.size = float(d.get("size", 2.0))
	b.body_radius = float(d.get("body_radius", 1.0))
	b.fps = float(d.get("fps", 60.0))
	b.tags = CombatTags.to_names(d.get("tags", []))
	b.resist = CombatTags.to_names(d.get("resist", []))
	b.immune = CombatTags.to_names(d.get("immune", []))
	b.is_metal = bool(d.get("is_metal", b.tags.has(&"FERRO")))
	b.arena_hazards = d.get("arena_hazards", [])
	b.adds = d.get("adds", [])
	b.phases = d.get("phases", [])
	b.branches = d.get("branches", [])
	b.drops = d.get("drops", [])
	b.flags = d.get("flags", {})
	b.notes = String(d.get("notes", ""))
	return b


func phase_count() -> int:
	return phases.size()


func phase(i: int) -> Dictionary:
	if i < 0 or i >= phases.size():
		return {}
	return phases[i]


## The EnemyDef for phase i: boss header merged with the phase's shield, tags and actions.
func phase_def(i: int) -> EnemyDef:
	var p: Dictionary = phase(i)
	var sh: Dictionary = p.get("shield", {})
	var d: Dictionary = {
		"id": String(id), "key": String(id), "name": display_name, "universe": universe, "level": level,
		"kind": "boss", "hp": hp, "xp": int(raw.get("xp", 0)), "sprite": String(sprite), "size": size, "body_radius": body_radius, "fps": fps,
		"is_metal": is_metal,
		"tags": p.get("tags", CombatTags.to_names(raw.get("tags", []))),
		"weak": sh.get("weak", []), "resist": sh.get("resist", resist), "nullify": sh.get("nullify", []),
		"immune": sh.get("immune", immune), "absorb": sh.get("absorb", []),
		"shield": int(sh.get("shield", 1)), "keyed_plates": sh.get("keyed_plates", []),
		"actions": p.get("actions", []), "behaviour": p.get("behaviour", {}), "drops": drops,
	}
	var rules: Dictionary = {}
	for k in ["regenerating", "refill_once", "shield_only", "break_condition", "only_hit_by", "shared_owner", "belief", "regen_rate", "lock_seconds", "shared_group"]:
		if sh.has(k):
			rules[k] = sh[k]
	if not rules.is_empty():
		d["plate_rules"] = rules
	return EnemyDef.from_dict(d)


## Index of the phase whose HP window contains `ratio` (phases are ordered high→low).
func phase_for_ratio(ratio: float) -> int:
	for i in phases.size():
		var p: Dictionary = phases[i]
		var lo: float = float(p.get("hp_to", 0.0))
		if ratio > lo or i == phases.size() - 1:
			return i
	return maxi(0, phases.size() - 1)


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("boss without id")
	if phases.is_empty():
		errors.append("%s: no phases" % id)
	for i in phases.size():
		var e: EnemyDef = phase_def(i)
		for err in e.validation_errors():
			errors.append("%s phase %d: %s" % [id, i, err])
	return errors
