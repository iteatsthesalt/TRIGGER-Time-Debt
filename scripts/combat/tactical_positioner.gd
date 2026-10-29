## Analytic XZ geometry for technique shapes (Combat Laws Bible §8). Deterministic and headless-testable.
## Battlers are passed as {node, pos: Vector3, radius: float}. Returns hits as {node, hits: int, rank: int}.
class_name TacticalPositioner
extends RefCounted

## shape params: {shape: TechDef.Shape, radius, length, width, inner_radius, beams, scale}
## origin: caster position; aim_point: the target or the placed point; extra: {second_origin, third_origin}
static func targets_in_shape(params: Dictionary, origin: Vector3, aim_point: Vector3,
		candidates: Array, blockers: Array = [], extra: Dictionary = {}) -> Array:
	var shape: int = int(params.get("shape", TechDef.Shape.SINGLE))
	var s: float = float(params.get("scale", 1.0))
	var radius: float = float(params.get("radius", 1.0)) * s
	var length: float = float(params.get("length", 0.0)) * s
	var width: float = float(params.get("width", 1.2)) * s
	var inner: float = float(params.get("inner_radius", 1.0)) * s
	var hits: Array = []
	var aim: Vector3 = _flat(aim_point - origin)
	if aim.length_squared() < 0.0001:
		aim = Vector3.FORWARD
	aim = aim.normalized()

	match shape:
		TechDef.Shape.SINGLE:
			for c in candidates:
				if _flat(c["pos"] - aim_point).length() <= 0.01 + float(c.get("radius", 0.5)):
					hits.append({"node": c["node"], "hits": 1, "dist": 0.0})
					break
		TechDef.Shape.CIRCLE, TechDef.Shape.CAGE:
			for c in candidates:
				var d: float = _flat(c["pos"] - aim_point).length()
				if d <= radius + float(c.get("radius", 0.5)):
					hits.append({"node": c["node"], "hits": 1, "dist": d})
		TechDef.Shape.SELF_AURA:
			for c in candidates:
				var d2: float = _flat(c["pos"] - origin).length()
				var r_body: float = float(c.get("radius", 0.5))
				if d2 <= radius + r_body and d2 + r_body >= inner:
					hits.append({"node": c["node"], "hits": 1, "dist": d2})
		TechDef.Shape.LINE_PIERCE:
			hits = _line_hits(origin, aim, length, width, candidates, blockers)
		TechDef.Shape.FATE_LINE:
			hits = _line_hits(origin, aim, 99.0 * s, width, candidates, [])
		TechDef.Shape.CONE:
			var half: float = atan2(radius, maxf(0.01, length))
			for c in candidates:
				var rel: Vector3 = _flat(c["pos"] - origin)
				var dist: float = rel.length()
				var rb: float = float(c.get("radius", 0.5))
				if dist <= length + rb:
					var inside: bool = dist < 0.0001
					if not inside:
						var slack: float = atan2(rb, dist)
						inside = aim.angle_to(rel / dist) <= half + slack
					if inside:
						hits.append({"node": c["node"], "hits": 1, "dist": dist})
		TechDef.Shape.CROSS:
			var side: Vector3 = aim.cross(Vector3.UP).normalized()
			var half_len: float = length * 0.5
			var a1: Array = _line_hits(aim_point - aim * half_len, aim, length, width, candidates, [])
			var a2: Array = _line_hits(aim_point - side * half_len, side, length, width, candidates, [])
			hits = _merge(a1, a2)
			for h in hits:
				h["at_crossing"] = _flat(_pos_of(h["node"], candidates) - aim_point).length() <= radius
		TechDef.Shape.DELTA:
			var p2: Vector3 = extra.get("second_origin", origin)
			var p3: Vector3 = extra.get("third_origin", aim_point)
			for c in candidates:
				var p: Vector3 = c["pos"]
				var rb2: float = float(c.get("radius", 0.5))
				var inside_tri: bool = _point_in_triangle(_flat(p), _flat(origin), _flat(p2), _flat(p3))
				var on_edge: bool = _dist_to_segment(p, origin, p2) <= width * 0.5 + rb2 \
					or _dist_to_segment(p, p2, p3) <= width * 0.5 + rb2 \
					or _dist_to_segment(p, p3, origin) <= width * 0.5 + rb2
				if inside_tri or on_edge:
					hits.append({"node": c["node"], "hits": 1, "dist": _flat(p - origin).length()})
		TechDef.Shape.SPLIT_CONE:
			var n: int = maxi(1, int(params.get("beams", 3)))
			var half2: float = atan2(radius, maxf(0.01, length))
			var counts: Dictionary = {}
			for i in n:
				var t: float = 0.5 if n == 1 else float(i) / float(n - 1)
				var ang: float = lerpf(-half2, half2, t)
				var dir: Vector3 = aim.rotated(Vector3.UP, ang)
				for h in _line_hits(origin, dir, length, width * 0.6, candidates, []):
					counts[h["node"]] = int(counts.get(h["node"], 0)) + 1
			for node in counts.keys():
				hits.append({"node": node, "hits": int(counts[node]), "dist": _flat(_pos_of(node, candidates) - origin).length()})
		TechDef.Shape.PARTY, TechDef.Shape.BATTLEFIELD:
			for c in candidates:
				hits.append({"node": c["node"], "hits": 1, "dist": 0.0})
	# Rank by distance from the shape's anchor for falloff (nearest first).
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["dist"]) < float(b["dist"]))
	for i in hits.size():
		hits[i]["rank"] = i
	return hits


static func _line_hits(origin: Vector3, aim: Vector3, length: float, width: float, candidates: Array, blockers: Array) -> Array:
	# Find where the line stops: the nearest blocker along it (Break-locked bodies, walls, cover).
	var stop_at: float = length
	for b in blockers:
		var rel: Vector3 = _flat(b["pos"] - origin)
		var along: float = rel.dot(aim)
		var perp: float = (rel - aim * along).length()
		var rb: float = float(b.get("radius", 0.5))
		if along > 0.0 and along < stop_at and perp <= width * 0.5 + rb:
			stop_at = along + rb  # the blocker itself is still inside the line
	var out: Array = []
	for c in candidates:
		var rel2: Vector3 = _flat(c["pos"] - origin)
		var along2: float = rel2.dot(aim)
		var perp2: float = (rel2 - aim * along2).length()
		var rb2: float = float(c.get("radius", 0.5))
		if along2 >= -rb2 and along2 <= stop_at and perp2 <= width * 0.5 + rb2:
			out.append({"node": c["node"], "hits": 1, "dist": maxf(0.0, along2)})
	return out


static func _merge(a: Array, b: Array) -> Array:
	var out: Array = a.duplicate(true)
	for h in b:
		var found: bool = false
		for o in out:
			if o["node"] == h["node"]:
				found = true
				break
		if not found:
			out.append(h.duplicate())
	return out


static func _pos_of(node: Variant, candidates: Array) -> Vector3:
	for c in candidates:
		if c["node"] == node:
			return c["pos"]
	return Vector3.ZERO


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _point_in_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var d1: float = _sign(p, a, b)
	var d2: float = _sign(p, b, c)
	var d3: float = _sign(p, c, a)
	var has_neg: bool = d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_pos: bool = d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_neg and has_pos)


static func _sign(p1: Vector3, p2: Vector3, p3: Vector3) -> float:
	return (p1.x - p3.x) * (p2.z - p3.z) - (p2.x - p3.x) * (p1.z - p3.z)


static func _dist_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = _flat(b - a)
	var ap: Vector3 = _flat(p - a)
	var l2: float = ab.length_squared()
	if l2 < 0.0001:
		return ap.length()
	var t: float = clampf(ap.dot(ab) / l2, 0.0, 1.0)
	return (ap - ab * t).length()


## Outline points for decals/previews.
static func preview_points(params: Dictionary, origin: Vector3, aim_point: Vector3, segments: int = 32) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var shape: int = int(params.get("shape", TechDef.Shape.SINGLE))
	var s: float = float(params.get("scale", 1.0))
	var radius: float = float(params.get("radius", 1.0)) * s
	var length: float = float(params.get("length", 0.0)) * s
	var width: float = float(params.get("width", 1.2)) * s
	var aim: Vector3 = _flat(aim_point - origin)
	if aim.length_squared() < 0.0001:
		aim = Vector3.FORWARD
	aim = aim.normalized()
	var side: Vector3 = aim.cross(Vector3.UP).normalized()
	match shape:
		TechDef.Shape.CIRCLE, TechDef.Shape.CAGE, TechDef.Shape.SELF_AURA, TechDef.Shape.SINGLE:
			var center: Vector3 = origin if shape == TechDef.Shape.SELF_AURA else aim_point
			var r: float = radius if shape != TechDef.Shape.SINGLE else 1.0 * s
			for i in segments + 1:
				var a: float = TAU * float(i) / float(segments)
				pts.append(center + Vector3(cos(a), 0.0, sin(a)) * r)
		TechDef.Shape.LINE_PIERCE, TechDef.Shape.FATE_LINE:
			var hw: float = width * 0.5
			var l: float = length if shape == TechDef.Shape.LINE_PIERCE else 99.0
			pts.append_array([origin + side * hw, origin + side * hw + aim * l, origin - side * hw + aim * l, origin - side * hw, origin + side * hw])
		TechDef.Shape.CONE, TechDef.Shape.SPLIT_CONE:
			var half: float = atan2(radius, maxf(0.01, length))
			pts.append(origin)
			for i in segments + 1:
				var a2: float = lerpf(-half, half, float(i) / float(segments))
				pts.append(origin + aim.rotated(Vector3.UP, a2) * length)
			pts.append(origin)
		TechDef.Shape.CROSS:
			var hl: float = length * 0.5
			var hw2: float = width * 0.5
			pts.append_array([aim_point - aim * hl + side * hw2, aim_point + aim * hl + side * hw2, aim_point + aim * hl - side * hw2, aim_point - aim * hl - side * hw2, aim_point - aim * hl + side * hw2])
			pts.append_array([aim_point - side * hl + aim * hw2, aim_point + side * hl + aim * hw2, aim_point + side * hl - aim * hw2, aim_point - side * hl - aim * hw2, aim_point - side * hl + aim * hw2])
		_:
			pts.append(aim_point)
	return pts


## Snap: among sampled caster positions within move range, pick the one landing the most hits,
## weighted toward weakness hits and targets near Breaking. Returns {origin, aim, hits}.
static func best_placement(params: Dictionary, caster_pos: Vector3, move_range: float, aim_point: Vector3,
		candidates: Array, blockers: Array, weights: Dictionary = {}, samples: int = 16) -> Dictionary:
	var best := {"origin": caster_pos, "aim": aim_point, "hits": targets_in_shape(params, caster_pos, aim_point, candidates, blockers), "score": -1.0}
	best["score"] = _score(best["hits"], weights)
	var shape: int = int(params.get("shape", TechDef.Shape.SINGLE))
	if shape in [TechDef.Shape.SINGLE, TechDef.Shape.PARTY, TechDef.Shape.BATTLEFIELD]:
		return best
	for ring in [0.5, 1.0]:
		for i in samples:
			var a: float = TAU * float(i) / float(samples)
			var o: Vector3 = caster_pos + Vector3(cos(a), 0.0, sin(a)) * move_range * float(ring)
			# Placed shapes keep the aim point; caster-anchored shapes aim at the same target.
			var h: Array = targets_in_shape(params, o, aim_point, candidates, blockers)
			var sc: float = _score(h, weights)
			if sc > float(best["score"]) + 0.001:
				best = {"origin": o, "aim": aim_point, "hits": h, "score": sc}
	return best


static func _score(hits: Array, weights: Dictionary) -> float:
	var s: float = 0.0
	for h in hits:
		s += float(h["hits"]) * float(weights.get(h["node"], 1.0))
	return s
