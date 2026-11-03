## The ground a body can stand on in a Location (Combat Laws Bible §2.1: the battle plane is laid over the
## terrain and conforms to it; DECISIONS "Withdraw"). A spot is standable when it lies inside the map bounds less
## INSET_M, world floor (collision layer 1) is under the body's whole footprint within a step of its feet, and no
## world solid overlaps the body standing there. walk() sends a body along a line in STEP_M samples: a sample a
## solid takes (a crate, a ledge, a gate post) is passed over, as the battle's Move passes over it, and the walk
## ends where the ground does (no floor under the footprint, or outside the bounds). WithdrawRules keeps a
## fall-back on it and BattleAftermath stands the party back on it, so neither ever leaves the room.
class_name WalkableGround
extends RefCounted

const INSET_M := 0.6
const STEP_M := 0.5
## The floor may lie this far below / above the feet of the body that samples it (a step, a gentle slope).
const DROP_M := 0.6
const RISE_M := 0.5
## The floor ray starts this far above the feet (below a loft or a balcony, inside a ledge it ignores).
const PROBE_UP_M := 0.9
## The footprint: the floor must also be under these four points around the centre.
const FOOTPRINT: Array[Vector3] = [Vector3(0.4, 0, 0), Vector3(-0.4, 0, 0), Vector3(0, 0, 0.4), Vector3(0, 0, -0.4)]
const WORLD_MASK := 1
## The body tested for overlap: the party capsule, lifted clear of the floor and of a low step.
const BODY_RADIUS_M := 0.35
const BODY_HEIGHT_M := 1.4
const BODY_LIFT_M := 0.25

enum Spot { STAND, BLOCKED, EDGE }

## The map bounds less INSET_M on each side; no area = unbounded.
var bounds: Rect2 = Rect2()
var _world: WeakRef
var _body := CapsuleShape3D.new()


func _init(world: Node3D, map_bounds: Rect2 = Rect2()) -> void:
	_world = weakref(world)
	if map_bounds.has_area():
		bounds = map_bounds.grow(-INSET_M)
	_body.radius = BODY_RADIUS_M
	_body.height = BODY_HEIGHT_M


## `p` on the floor (its height taken from the floor) when a body can stand there, else null.
func stand_at(p: Vector3) -> Variant:
	var space := _space()
	if space == null:
		return null
	var r: Dictionary = _probe(space, p)
	return Vector3(p.x, float(r["y"]), p.z) if int(r["kind"]) == Spot.STAND else null


## A body at `from` walking toward `to`, at most `max_m`: {to: the last standable sample (from itself when there
## is none), edge_m: how far beyond that point the walkable ground ends (INF when it does not end on the way)}.
func walk(from: Vector3, to: Vector3, max_m: float = INF) -> Dictionary:
	var out: Dictionary = {"to": from, "edge_m": INF}
	var space := _space()
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var dist: float = minf(flat.length(), max_m)
	if space == null or dist < 0.001:
		return out
	var dir: Vector3 = flat.normalized()
	var y: float = from.y
	var s: float = 0.0
	var best: float = 0.0
	while s < dist - 0.001:
		s = minf(s + STEP_M, dist)
		var p := Vector3(from.x + dir.x * s, y, from.z + dir.z * s)
		var r: Dictionary = _probe(space, p)
		if int(r["kind"]) == Spot.EDGE:
			out["edge_m"] = s - best
			break
		if int(r["kind"]) == Spot.STAND:
			y = float(r["y"])
			best = s
			out["to"] = Vector3(p.x, y, p.z)
	return out


func _space() -> PhysicsDirectSpaceState3D:
	var w := _world.get_ref() as Node3D
	if w == null or not w.is_inside_tree() or w.get_world_3d() == null:
		return null
	return w.get_world_3d().direct_space_state


## {kind: Spot, y: the floor height under the centre when it is STAND}.
func _probe(space: PhysicsDirectSpaceState3D, p: Vector3) -> Dictionary:
	if bounds.has_area() and not bounds.has_point(Vector2(p.x, p.z)):
		return {"kind": Spot.EDGE, "y": p.y}
	var centre: Variant = _floor(space, p)
	if centre == null:
		return {"kind": Spot.EDGE, "y": p.y}
	if float(centre) > p.y + RISE_M:
		return {"kind": Spot.BLOCKED, "y": p.y}
	for off: Vector3 in FOOTPRINT:
		var h: Variant = _floor(space, p + off)
		if h == null:
			return {"kind": Spot.EDGE, "y": p.y}
		if float(h) > p.y + RISE_M:
			return {"kind": Spot.BLOCKED, "y": p.y}
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _body
	q.collision_mask = WORLD_MASK
	q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, float(centre) + BODY_LIFT_M + BODY_HEIGHT_M * 0.5, p.z))
	if not space.intersect_shape(q, 1).is_empty():
		return {"kind": Spot.BLOCKED, "y": p.y}
	return {"kind": Spot.STAND, "y": float(centre)}


## The height of the first world surface under `p`, from PROBE_UP_M above it to DROP_M below: null when there is
## none (the void past a floor's edge), INF when it is no floor (a solid's side or a steep slope).
func _floor(space: PhysicsDirectSpaceState3D, p: Vector3) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, PROBE_UP_M, 0), p - Vector3(0, DROP_M, 0), WORLD_MASK)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return null
	return (hit["position"] as Vector3).y if (hit["normal"] as Vector3).y >= 0.7 else INF
