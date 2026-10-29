## Resolves which live combatants a Tech's Boost-scaled 3D shape covers.
##
## Replaces the doc's ShapeCast3D approach, which had these problems:
##  - CLEAVE_CONE was declared but unhandled, so it silently reused the previous shape.
##  - look_at() errors when caster and target overlap (zero direction).
##  - Direction was normalized before zeroing Y, leaving it un-normalized.
##  - Depended on collision layers/groups being set up exactly right and on a
##    physics frame having run.
## Combat already knows the enemy list, so plain XZ-plane geometry is exact,
## deterministic, testable headless and cheap. Use preview_points() for decals.
class_name TacticalPositioner3D
extends Node3D


static func get_targets_in_tech_aoe(
	tech: TechResource,
	caster: Node3D,
	primary_target: Node3D,
	boost_level: int,
	candidates: Array[Node3D]
) -> Array[Node3D]:
	var hits: Array[Node3D] = []
	var s: float = tech.aoe_scale(boost_level)
	var radius: float = tech.base_radius_or_width * s
	var length: float = tech.base_length * s

	if tech.shape_type == TechResource.SpatialShape.SINGLE_TARGET:
		if primary_target != null and _alive(primary_target):
			hits.append(primary_target)
		return hits

	var origin: Vector3 = caster.global_position
	var aim: Vector3 = _flat(primary_target.global_position - origin) if primary_target else Vector3.ZERO
	if aim.length_squared() < 0.0001:
		aim = _flat(-caster.global_transform.basis.z)
	if aim.length_squared() < 0.0001:
		aim = Vector3.FORWARD
	aim = aim.normalized()

	for c in candidates:
		if c == null or not _alive(c):
			continue
		var r_body: float = _body_radius(c)
		var p: Vector3 = c.global_position
		var inside := false
		match tech.shape_type:
			TechResource.SpatialShape.CIRCLE_AROUND_TARGET:
				inside = _flat(p - primary_target.global_position).length() <= radius + r_body
			TechResource.SpatialShape.SELF_AURA:
				inside = _flat(p - origin).length() <= radius + r_body
			TechResource.SpatialShape.LINE_PIERCE:
				var rel: Vector3 = _flat(p - origin)
				var along: float = rel.dot(aim)
				var perp: float = (rel - aim * along).length()
				inside = along >= -r_body and along <= length + r_body and perp <= radius * 0.5 + r_body
			TechResource.SpatialShape.CLEAVE_CONE:
				var rel2: Vector3 = _flat(p - origin)
				var dist: float = rel2.length()
				if dist <= length + r_body:
					if dist < 0.0001:
						inside = true
					else:
						var half: float = deg_to_rad(tech.cone_angle_deg) * 0.5
						# Widen the angle by the body's angular size so edge cases count.
						var slack: float = atan2(r_body, dist)
						inside = aim.angle_to(rel2 / dist) <= half + slack
		if inside and not hits.has(c):
			hits.append(c)
	return hits


## Outline in world space for drawing a targeting decal/preview.
static func preview_points(
	tech: TechResource, caster: Node3D, primary_target: Node3D, boost_level: int, segments: int = 32
) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var s: float = tech.aoe_scale(boost_level)
	var radius: float = tech.base_radius_or_width * s
	var length: float = tech.base_length * s
	var origin: Vector3 = caster.global_position
	var aim: Vector3 = _flat(primary_target.global_position - origin).normalized() if primary_target else Vector3.FORWARD
	if aim.length_squared() < 0.0001:
		aim = Vector3.FORWARD
	var side: Vector3 = aim.cross(Vector3.UP).normalized()
	match tech.shape_type:
		TechResource.SpatialShape.CIRCLE_AROUND_TARGET, TechResource.SpatialShape.SELF_AURA:
			var around_target: bool = tech.shape_type == TechResource.SpatialShape.CIRCLE_AROUND_TARGET
			var center: Vector3 = primary_target.global_position if around_target else origin
			for i in segments + 1:
				var a: float = TAU * float(i) / float(segments)
				pts.append(center + Vector3(cos(a), 0.0, sin(a)) * radius)
		TechResource.SpatialShape.LINE_PIERCE:
			var hw: float = radius * 0.5
			pts.append_array([origin + side * hw, origin + side * hw + aim * length,
				origin - side * hw + aim * length, origin - side * hw, origin + side * hw])
		TechResource.SpatialShape.CLEAVE_CONE:
			var half: float = deg_to_rad(tech.cone_angle_deg) * 0.5
			pts.append(origin)
			for i in segments + 1:
				var a2: float = lerpf(-half, half, float(i) / float(segments))
				pts.append(origin + aim.rotated(Vector3.UP, a2) * length)
			pts.append(origin)
		_:
			if primary_target:
				pts.append(primary_target.global_position)
	return pts


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _alive(n: Node) -> bool:
	var st := CombatantStats.of(n)
	return st == null or st.is_alive()


static func _body_radius(n: Node) -> float:
	var st := CombatantStats.of(n)
	return st.body_radius if st else 0.5
