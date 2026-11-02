## The residual field a Boosted technique leaves where it landed (Combat Laws Bible §7.4; DECISIONS "Lv3
## fields"). Boost Lv4: the technique's lv4_field, else its own lv3_field, else its element's default. Boost Lv3:
## only a technique whose own row says Lv3 leaves a field (Astral Slash's watercolour puddle, Ferro Graviton's
## mercury pool, Prism Refraction's caustic floor, §11). A plain Attack leaves nothing: a Boosted Attack scales
## its power and its shape only (§4.2, §7.2). The field covers the shape (CIRCLE: the circle; LINE: the line;
## SINGLE: a 2 m circle under the target) for 6 s of battle time.
class_name ResidualFields
extends RefCounted


## The field kind `tech` leaves at `boost`, or &"" for none.
static func kind_for(tech: TechDef, boost: int) -> StringName:
	if tech == null:
		return &""
	if boost >= 4:
		if tech.lv4_field != &"":
			return tech.lv4_field
		if tech.lv3_field != &"":
			return tech.lv3_field
		return BattleFields.default_field_for(tech.element_tag())
	if boost >= 3:
		return tech.lv3_field
	return &""


## Leave the action's field, if any. `found`: the targets the shape caught (SINGLE puts the field under the
## first). Returns the field, or an empty Dictionary.
static func leave(c: BattleCoordinator, action: Dictionary, found: Array) -> Dictionary:
	var kind: StringName = kind_for(action.get("tech", null), int(action.get("boost", 0)))
	if kind == &"":
		return {}
	var shape: Dictionary = action["shape"]
	var origin: Vector3 = c.position_of(action["attacker"])
	var aim: Vector3 = action["aim"]
	var scale: float = float(shape.get("scale", 1.0))
	var f: Dictionary
	match int(shape["shape"]):
		TechDef.Shape.LINE_PIERCE:
			var dir := Vector3(aim.x - origin.x, 0.0, aim.z - origin.z)
			f = c.fields.add_line(kind, origin, dir, float(shape.get("length", 6.0)) * scale, float(shape.get("width", 1.2)), CombatConstants.RESIDUAL_FIELD_S, 0)
		TechDef.Shape.SINGLE:
			var p: Vector3 = c.position_of(found[0]["node"]) if not found.is_empty() else aim
			f = c.fields.add(kind, p, 2.0, CombatConstants.RESIDUAL_FIELD_S, 0)
		_:
			var center: Vector3 = origin if int(shape["shape"]) == TechDef.Shape.SELF_AURA else aim
			f = c.fields.add(kind, center, float(shape.get("radius", 2.0)) * scale, CombatConstants.RESIDUAL_FIELD_S, 0)
	if kind == &"white_blank":
		f["strips_tags"] = true  # the NULL residual erases the tags of hits inside (§7.4), the clash blank does not
	c.field_added.emit(f)
	return f
