## Residual fields and converted terrain on the battle plane (Combat Laws Bible §7.4, §9.6, §12.5).
## Pure data; the coordinator ticks it on battle time and queries it when resolving hits.
class_name BattleFields
extends RefCounted

## Each field: {kind: StringName, center: Vector3, radius: float, left: float (-1 = permanent),
##              owner_team: int, line: bool, dir: Vector3, length: float, accum: float}
var fields: Array[Dictionary] = []

const ELEMENT_FIELD := {
	&"ASTRAL": &"watercolour_puddle", &"TACHYON": &"ghost_ring", &"RUIN": &"ash_field",
	&"FERRO": &"amber_pool", &"MYCELIA": &"spore_mat", &"VITREOUS": &"caustic_floor",
	&"GUILE": &"confetti_pit", &"HZ": &"static_field", &"NULL": &"white_blank",
}


static func default_field_for(element: StringName) -> StringName:
	return ELEMENT_FIELD.get(element, &"")


func add(kind: StringName, center: Vector3, radius: float, seconds: float = CombatConstants.RESIDUAL_FIELD_S, owner_team: int = 0) -> Dictionary:
	var f := {"kind": kind, "center": center, "radius": radius, "left": seconds, "owner_team": owner_team, "line": false, "accum": 0.0, "consumed": {}}
	fields.append(f)
	return f


func add_line(kind: StringName, origin: Vector3, dir: Vector3, length: float, width: float, seconds: float, owner_team: int = 0) -> Dictionary:
	var f := {"kind": kind, "center": origin, "radius": width * 0.5, "left": seconds, "owner_team": owner_team, "line": true, "dir": dir.normalized(), "length": length, "accum": 0.0, "consumed": {}}
	fields.append(f)
	return f


func clear() -> void:
	fields.clear()


## Returns the fields a point is inside.
func at(pos: Vector3) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in fields:
		if _inside(f, pos):
			out.append(f)
	return out


func has_kind_at(kind: StringName, pos: Vector3) -> bool:
	for f in fields:
		if f["kind"] == kind and _inside(f, pos):
			return true
	return false


func _inside(f: Dictionary, pos: Vector3) -> bool:
	var rel := Vector3(pos.x - f["center"].x, 0.0, pos.z - f["center"].z)
	if bool(f["line"]):
		var along: float = rel.dot(f["dir"])
		var perp: float = (rel - f["dir"] * along).length()
		return along >= 0.0 and along <= float(f["length"]) and perp <= float(f["radius"])
	return rel.length() <= float(f["radius"])


## Advance timers; returns the fields that expired.
func tick(dt: float) -> Array[Dictionary]:
	var expired: Array[Dictionary] = []
	for f in fields.duplicate():
		if float(f["left"]) < 0.0:
			continue
		f["left"] = float(f["left"]) - dt
		if float(f["left"]) <= 0.0:
			fields.erase(f)
			expired.append(f)
	return expired


## Replace a field kind inside a circle (Canvas Clash: ASTRAL burns ink pools to gold, NULL blanks).
func convert(from_kind: StringName, to_kind: StringName, center: Vector3, radius: float, seconds: float = -1.0) -> int:
	var n: int = 0
	for f in fields:
		if f["kind"] == from_kind and Vector3(f["center"].x - center.x, 0.0, f["center"].z - center.z).length() <= radius + float(f["radius"]):
			f["kind"] = to_kind
			f["left"] = seconds
			n += 1
	return n


## NULL's white blank erases every field in the shape.
func blank(center: Vector3, radius: float, turns_seconds: float) -> void:
	for f in fields.duplicate():
		if Vector3(f["center"].x - center.x, 0.0, f["center"].z - center.z).length() <= radius + float(f["radius"]):
			fields.erase(f)
	add(&"white_blank", center, radius, turns_seconds)
