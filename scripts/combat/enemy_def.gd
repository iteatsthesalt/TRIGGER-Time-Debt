## An enemy definition loaded from data/enemies/<u>/*.json (Combat Laws Bible §13, §18.2).
class_name EnemyDef
extends RefCounted

var id: StringName = &""          ## E-number or boss id
var key: StringName = &""         ## snake_case key used by encounters
var display_name: String = ""
var universe: int = 0
var level: int = 1
var kind: String = "regular"
var shield: int = 1
var tags: Array[StringName] = []
var weak: Array[StringName] = []
var resist: Array[StringName] = []
var nullify: Array[StringName] = []
var immune: Array[StringName] = []
var absorb: Array[StringName] = []
var lean: String = ""
var keyed_plates: Array = []
var plate_rules: Dictionary = {}
var brain: StringName = &"default"
var break_effect: StringName = &""
var drops: Array = []
var sprite: StringName = &""
var size: float = 1.0
var body_radius: float = 0.5
var fps: float = 60.0
var hp_mult: float = 1.0
var spd_mult: float = 1.0
var hp_override: int = 0
var actions: Array = []
var behaviour: Dictionary = {}
var is_metal: bool = false
var notes: String = ""
var raw: Dictionary = {}


static func from_dict(d: Dictionary) -> EnemyDef:
	var e := EnemyDef.new()
	e.raw = d
	e.id = StringName(String(d.get("id", "")))
	e.key = StringName(String(d.get("key", e.id)))
	e.display_name = String(d.get("name", e.key))
	e.universe = int(d.get("universe", 0))
	e.level = int(d.get("level", 1))
	e.kind = String(d.get("kind", "regular"))
	e.shield = int(d.get("shield", 1))
	e.tags = CombatTags.to_names(d.get("tags", []))
	e.weak = CombatTags.to_names(d.get("weak", []))
	e.resist = CombatTags.to_names(d.get("resist", []))
	e.nullify = CombatTags.to_names(d.get("nullify", []))
	e.immune = CombatTags.to_names(d.get("immune", []))
	e.absorb = CombatTags.to_names(d.get("absorb", []))
	e.lean = String(d.get("lean", ""))
	e.keyed_plates = d.get("keyed_plates", [])
	e.plate_rules = d.get("plate_rules", {})
	e.brain = StringName(String(d.get("brain", "default")))
	e.break_effect = StringName(String(d.get("break_effect", "")))
	e.drops = d.get("drops", [])
	e.sprite = StringName(String(d.get("sprite", "")))
	e.size = float(d.get("size", 1.0))
	e.body_radius = float(d.get("body_radius", 0.5))
	e.fps = float(d.get("fps", 60.0))
	e.hp_mult = float(d.get("hp_mult", 1.0))
	e.spd_mult = float(d.get("spd_mult", 1.0))
	e.hp_override = int(d.get("hp", 0))
	e.actions = d.get("actions", [])
	e.behaviour = d.get("behaviour", {})
	e.is_metal = bool(d.get("is_metal", e.tags.has(&"FERRO") or e.tags.has(&"GUN")))
	e.notes = String(d.get("notes", ""))
	return e


func shield_config() -> Dictionary:
	var cfg := {
		"shield": shield, "weak": weak, "resist": resist, "nullify": nullify, "immune": immune,
		"absorb": absorb, "keyed_plates": keyed_plates,
	}
	for k in plate_rules.keys():
		cfg[k] = plate_rules[k]
	return cfg


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if key == &"":
		errors.append("enemy without key")
	for group in [tags, weak, resist, nullify, immune, absorb]:
		for tg in group:
			if not CombatTags.is_known(tg):
				errors.append("%s: unknown tag %s" % [key, tg])
	for a in actions:
		for tg in a.get("tags", []):
			if not CombatTags.is_known(StringName(String(tg))):
				errors.append("%s: action %s has unknown tag %s" % [key, a.get("id", "?"), tg])
	if shield < 0:
		errors.append("%s: negative shield" % key)
	return errors
