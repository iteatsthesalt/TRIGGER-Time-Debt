## Designer-authored Single / Dual / Triple Tech (.tres).
class_name TechResource
extends Resource

enum TechTier { SINGLE, DUAL, TRIPLE }
enum SpatialShape { SINGLE_TARGET, LINE_PIERCE, CIRCLE_AROUND_TARGET, SELF_AURA, CLEAVE_CONE }

@export var tech_id: StringName = &""
@export var display_name: String = ""
@export var tier: TechTier = TechTier.SINGLE

## CombatantStats.actor_id values that must all be in the Ready Pool.
@export var required_actor_ids: Array[StringName] = []
@export var mp_cost_per_actor: int = 0

## Every tag is checked against weaknesses on every strike.
@export var damage_tags: Array[CombatTypes.DamageType] = []

@export var uses_elemental_attack: bool = true
## Potency PER STRIKE (the doc applied hit_count to shields but not to damage).
@export var base_multiplier: float = 1.0
## Chrono Trigger co-op bonus. Must be 1.0 for SINGLE techs.
@export var synergy_multiplier: float = 1.0
@export_range(1, 16) var hit_count: int = 1
@export var boost_bonus_per_level: float = 0.90

@export_group("3D Spatial AoE")
@export var shape_type: SpatialShape = SpatialShape.SINGLE_TARGET
## Circle/aura radius, or full width of a line.
@export var base_radius_or_width: float = 2.5
## Line length or cone range.
@export var base_length: float = 6.0
@export_range(10.0, 180.0) var cone_angle_deg: float = 70.0
@export var boost_aoe_scale_per_level: float = 0.25


func boost_damage_multiplier(boost_level: int) -> float:
	return 1.0 + boost_bonus_per_level * float(clampi(boost_level, 0, 3))


func aoe_scale(boost_level: int) -> float:
	return 1.0 + boost_aoe_scale_per_level * float(clampi(boost_level, 0, 3))


## Damage for ONE strike against one target.
## Typed as Array[CombatantStats]: the doc passed Array[Node3D] into an
## Array[Node] parameter, which Godot 4 rejects (typed arrays are invariant).
func calculate_strike_damage(
	casters: Array[CombatantStats],
	target: CombatantStats,
	boost_level: int,
	strike_multiplier: float
) -> int:
	var combined_atk: float = 0.0
	for c in casters:
		combined_atk += c.elemental_attack if uses_elemental_attack else c.physical_attack
	var target_def: float = 0.0
	if target != null:
		target_def = target.elemental_defense if uses_elemental_attack else target.physical_defense

	var dmg: float = (
		core_formula(combined_atk, target_def)
		* base_multiplier
		* synergy_multiplier
		* boost_damage_multiplier(boost_level)
		* strike_multiplier
	)
	return maxi(1, roundi(dmg))


## Damage formula as specified in the architecture doc: 0.8 × (Atk − Def × 0.5).
static func core_formula(attack: float, defense: float) -> float:
	return 0.8 * maxf(1.0, attack - defense * 0.5)


## Returns a list of authoring problems; empty means the resource is valid.
func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var expected: int = [1, 2, 3][tier]
	if required_actor_ids.size() != expected:
		errors.append("%s: tier %s needs %d actor ids, has %d" % [
			tech_id, TechTier.keys()[tier], expected, required_actor_ids.size()])
	if tier == TechTier.SINGLE and not is_equal_approx(synergy_multiplier, 1.0):
		errors.append("%s: SINGLE techs must have synergy_multiplier 1.0" % tech_id)
	if tier != TechTier.SINGLE and synergy_multiplier <= 1.0:
		errors.append("%s: co-op techs should have synergy_multiplier > 1.0" % tech_id)
	if damage_tags.is_empty():
		errors.append("%s: no damage_tags (cannot shave shields)" % tech_id)
	if hit_count < 1:
		errors.append("%s: hit_count must be >= 1" % tech_id)
	return errors
