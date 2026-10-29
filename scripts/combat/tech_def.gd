## A technique definition loaded from data/techs/*.json (Combat Laws Bible §11, §18.2).
class_name TechDef
extends RefCounted

enum Tier { SINGLE, DUAL, TRIPLE, ULTIMATE }
enum Shape { SINGLE, LINE_PIERCE, CIRCLE, SELF_AURA, CONE, CROSS, DELTA, CAGE, SPLIT_CONE, FATE_LINE, PARTY, BATTLEFIELD }
enum Uses { PHYSICAL, ELEMENTAL, ASTRAL, BEST }

const SHAPE_NAMES := {
	"SINGLE": Shape.SINGLE, "LINE_PIERCE": Shape.LINE_PIERCE, "LINE": Shape.LINE_PIERCE,
	"CIRCLE": Shape.CIRCLE, "SELF_AURA": Shape.SELF_AURA, "CONE": Shape.CONE, "CROSS": Shape.CROSS,
	"DELTA": Shape.DELTA, "CAGE": Shape.CAGE, "SPLIT_CONE": Shape.SPLIT_CONE, "FATE_LINE": Shape.FATE_LINE,
	"PARTY": Shape.PARTY, "BATTLEFIELD": Shape.BATTLEFIELD,
}
const TIER_NAMES := {"single": Tier.SINGLE, "dual": Tier.DUAL, "triple": Tier.TRIPLE, "ultimate": Tier.ULTIMATE}
const USES_NAMES := {"PHYSICAL": Uses.PHYSICAL, "ELEMENTAL": Uses.ELEMENTAL, "ASTRAL": Uses.ASTRAL, "BEST": Uses.BEST}

var id: StringName = &""
var display_name: String = ""
var tier: int = Tier.SINGLE
var actors: Array[StringName] = []
## Alternative actor sets (Origami Requiem: Crono + Sera, or Crono + Omega-Spekkio).
var alt_actor_sets: Array = []
var tags: Array[StringName] = []
var shape: int = Shape.SINGLE
var radius: float = 1.0
var length: float = 0.0
var width: float = 1.2
var inner_radius: float = 1.0
var beams: int = 0
var aoe_scale: float = 1.0
var hit_count: int = 1
var base_per_hit: float = 1.0
var uses: int = Uses.BEST
## actor_id -> {mp, strain_pct, camp_strain_pct, integrity, solidity_pct, bp_all, hp_to_one}
var costs: Dictionary = {}
var lv2_debuff: StringName = &""
var lv4_field: StringName = &""
var flat_shave_bonus: int = 0
var wind_up_s: float = 0.0
var unlock: Dictionary = {}
var requires_flags: Array[StringName] = []
var effect: StringName = &""
## enemy | ally | self | party | point | any
var target: String = "enemy"
var heal: float = 0.0
var is_attack: bool = true
var min_boost: int = 0
var cooldown_turns: int = 0
var notes: String = ""
var raw: Dictionary = {}


static func from_dict(d: Dictionary) -> TechDef:
	var t := TechDef.new()
	t.raw = d
	t.id = StringName(String(d.get("id", "")))
	t.display_name = String(d.get("name", t.id))
	t.tier = int(TIER_NAMES.get(String(d.get("tier", "single")).to_lower(), Tier.SINGLE))
	t.actors = CombatTags.to_names(d.get("actors", []))
	t.alt_actor_sets = d.get("alt_actors", [])
	t.tags = CombatTags.to_names(d.get("tags", []))
	t.shape = int(SHAPE_NAMES.get(String(d.get("shape", "SINGLE")).to_upper(), Shape.SINGLE))
	t.radius = float(d.get("radius", 1.0))
	t.length = float(d.get("length", 0.0))
	t.width = float(d.get("width", 1.2))
	t.inner_radius = float(d.get("inner_radius", 1.0))
	t.beams = int(d.get("beams", 0))
	t.aoe_scale = float(d.get("aoe_scale", 1.0))
	t.hit_count = int(d.get("hits", 1))
	t.base_per_hit = float(d.get("power", 1.0))
	t.uses = int(USES_NAMES.get(String(d.get("uses", "BEST")).to_upper(), Uses.BEST))
	t.costs = d.get("costs", {})
	t.lv2_debuff = StringName(String(d.get("lv2_debuff", "")))
	t.lv4_field = StringName(String(d.get("lv4_field", "")))
	t.flat_shave_bonus = int(d.get("flat_shave_bonus", 0))
	t.wind_up_s = float(d.get("wind_up_s", 0.0))
	t.unlock = d.get("unlock", {})
	t.requires_flags = CombatTags.to_names(d.get("requires_flags", []))
	t.effect = StringName(String(d.get("effect", "")))
	t.target = String(d.get("target", "enemy"))
	t.heal = float(d.get("heal", 0.0))
	t.is_attack = bool(d.get("is_attack", t.heal <= 0.0 and t.target in ["enemy", "point", "any"]))
	t.min_boost = int(d.get("min_boost", 0))
	t.cooldown_turns = int(d.get("cooldown_turns", 0))
	t.notes = String(d.get("notes", ""))
	return t


func is_coop() -> bool:
	return tier == Tier.DUAL or tier == Tier.TRIPLE


func actor_count_expected() -> int:
	match tier:
		Tier.DUAL:
			return 2
		Tier.TRIPLE:
			return 3
	return 1


## All actor sets that can perform this tech.
func actor_sets() -> Array:
	var sets: Array = [actors]
	for alt in alt_actor_sets:
		sets.append(CombatTags.to_names(alt))
	return sets


func involves(actor_id: StringName) -> bool:
	for s in actor_sets():
		if (s as Array).has(actor_id):
			return true
	return false


func cost_for(actor_id: StringName) -> Dictionary:
	return costs.get(String(actor_id), {})


func shape_scale(boost_level: int) -> float:
	return CombatConstants.BOOST_SCALE[clampi(boost_level, 0, 4)] * aoe_scale


func synergy_base() -> float:
	match tier:
		Tier.DUAL:
			return CombatConstants.SYNERGY_DUAL
		Tier.TRIPLE:
			return CombatConstants.SYNERGY_TRIPLE
	return CombatConstants.SYNERGY_SOLO


func element_tag() -> StringName:
	for tg in tags:
		var e: StringName = CombatTags.element_of(tg)
		if e != &"":
			return e
	return &""


## Authoring problems; empty means valid.
func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("tech without id")
	if actors.size() != actor_count_expected() and tier != Tier.ULTIMATE:
		errors.append("%s: tier needs %d actors, has %d" % [id, actor_count_expected(), actors.size()])
	for alt in alt_actor_sets:
		if (alt as Array).size() != actor_count_expected():
			errors.append("%s: alt actor set has wrong size" % id)
	if tags.is_empty():
		errors.append("%s: no tags" % id)
	for tg in tags:
		if not CombatTags.is_known(tg):
			errors.append("%s: unknown tag %s" % [id, tg])
	if hit_count < 1:
		errors.append("%s: hits must be >= 1" % id)
	if shape in [Shape.CIRCLE, Shape.SELF_AURA, Shape.CAGE] and radius <= 0.0:
		errors.append("%s: shape needs a radius" % id)
	if shape in [Shape.LINE_PIERCE, Shape.CONE, Shape.CROSS] and length <= 0.0:
		errors.append("%s: shape needs a length" % id)
	if shape == Shape.SPLIT_CONE and beams <= 0:
		errors.append("%s: split cone needs beams" % id)
	return errors


## Two techniques may not share tags, shape and radius (§17.5).
func signature() -> String:
	var sorted_tags: Array = tags.duplicate()
	sorted_tags.sort()
	var who: Array = actors.duplicate()
	who.sort()
	return "%s|%s|%s|%d|%.2f|%.2f" % [",".join(PackedStringArray(who)), effect, ",".join(PackedStringArray(sorted_tags)), shape, radius, length]
