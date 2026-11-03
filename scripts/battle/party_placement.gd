## Where the bodies stand when a battle opens (Combat Laws Bible §2.1: the plane is laid over the terrain and
## conforms to it). The enemies keep their spots, pushed ENEMY_GAP_M apart. The party fans out RADIUS_M from the
## centre on the near side (+Z, toward the camera). On a Location's ground (WalkableGround) every anchor must be a
## spot a body can stand on: when one is not (the void past a floor's edge, a wall, a crate), the fan first comes
## in to NEAR_M on the same side, then turns about the centre (TURNS, the near side's flanks before the far side)
## until everyone stands. When no fan holds the whole party, each member walks out from the centre toward its
## near-side anchor and stops on the last floor, or keeps its own spot when the way has none. So no battle stands
## anyone over the void, and a won fight hands back a party already on the floor.
class_name PartyPlacement
extends RefCounted

const RADIUS_M := 4.5
const NEAR_M := 3.0
## The angle between neighbours in the fan, in radians.
const SPREAD_RAD := 0.5
const ENEMY_GAP_M := 1.3
## The fan's turns about the centre, in degrees, in the order tried: the near side, its flanks, the far side.
const TURNS: Array[float] = [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0, 180.0]


## Enemies keep their positions but never overlap (at least ENEMY_GAP_M apart).
static func spread_enemies(enemies: Array) -> void:
	for i in enemies.size():
		for j in range(i):
			var a: Node3D = enemies[i]
			var b: Node3D = enemies[j]
			var d: Vector3 = a.global_position - b.global_position
			d.y = 0.0
			if d.length() < ENEMY_GAP_M:
				var push: Vector3 = (d.normalized() if d.length() > 0.01 else Vector3(1, 0, 0)) * (ENEMY_GAP_M - d.length()) * 0.5
				a.global_position += push
				b.global_position -= push


## Stand `party` around `center` on `ground` (null: the near-side fan as it is, each member at its own height),
## facing across the centre, ready and free to move. Returns the side the party stands on (a unit vector from the
## centre), which the enemies face.
static func place(party: Array, center: Vector3, ground: WalkableGround) -> Vector3:
	var starts: Array[Vector3] = []
	for a in party:
		starts.append((a as Node3D).global_position)
	var f: Dictionary = fan(center, starts, ground)
	var side: Vector3 = f["side"]
	var anchors: Array[Vector3] = f["anchors"]
	for i in party.size():
		var a := party[i] as CombatActor
		a.global_position = anchors[i]
		a.reset_physics_interpolation()
		a.frozen = false
		a.velocity = Vector3.ZERO
		a.sprite.update_from_velocity(Vector3.ZERO)
		a.face_toward(center - side * 5.0)
		a.sprite.play(&"ready")
	return side


## {anchors: one spot per member of `starts` (their positions before the battle), side: the party's side}.
static func fan(center: Vector3, starts: Array[Vector3], ground: WalkableGround) -> Dictionary:
	if ground == null:
		return {"anchors": _fan(center, starts, RADIUS_M, 0.0), "side": _side(0.0)}
	for turn: float in TURNS:
		for radius: float in [RADIUS_M, NEAR_M]:
			var stood: Array[Vector3] = []
			for p: Vector3 in _fan(center, starts, radius, deg_to_rad(turn)):
				var s: Variant = ground.stand_at(p)
				if s == null:
					break
				stood.append(s)
			if stood.size() == starts.size():
				return {"anchors": stood, "side": _side(deg_to_rad(turn))}
	var near: Array[Vector3] = _fan(center, starts, RADIUS_M, 0.0)
	var out: Array[Vector3] = []
	for i in starts.size():
		var from := Vector3(center.x, starts[i].y, center.z)
		var to: Vector3 = ground.walk(from, near[i])["to"]
		out.append(to if to != from else starts[i])
	return {"anchors": out, "side": _side(0.0)}


## The fan turned by `turn` radians: member i at `radius` from the centre, at its own height.
static func _fan(center: Vector3, starts: Array[Vector3], radius: float, turn: float) -> Array[Vector3]:
	var n: int = starts.size()
	var mid: float = float(n - 1) * 0.5
	var out: Array[Vector3] = []
	for i in n:
		var angle: float = PI * 0.5 + turn + (float(i) - mid) * SPREAD_RAD
		var p: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		p.y = starts[i].y
		out.append(p)
	return out


static func _side(turn: float) -> Vector3:
	return Vector3(cos(PI * 0.5 + turn), 0.0, sin(PI * 0.5 + turn))
