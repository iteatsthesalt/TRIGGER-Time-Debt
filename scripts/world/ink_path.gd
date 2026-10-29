## Indigo ink footprints that bloom like watercolour and fade (Story Bible U0 "Krona marks", Ch1 beat 6):
## Chronoslip residue pointing at the next thing to do, instead of a minimap. Repeats while active.
class_name InkPath
extends Node3D

var points: PackedVector3Array = PackedVector3Array()
var life: float = 6.0
var step: float = 0.55
var repeat_every: float = 14.0
var active: bool = true
var colour: Color = Color(0.16, 0.12, 0.42, 0.9)
var glow_colour: Color = Color(0.85, 0.72, 0.25)
var prismatic: bool = false
var _timer: float = 0.0
var _prints: Array[MeshInstance3D] = []
static var _tex: ImageTexture
static var _mat: StandardMaterial3D


static func make(parent: Node, pts: Array, life_s: float = 6.0) -> InkPath:
	var p := InkPath.new()
	p.name = "InkPath"
	for v in pts:
		p.points.append(v)
	p.life = life_s
	parent.add_child(p)
	return p


func _ready() -> void:
	if _tex == null:
		_tex = _make_footprint_texture()
	_timer = repeat_every  # bloom at once


func _process(delta: float) -> void:
	if not active:
		return
	_timer += delta
	if _timer >= repeat_every:
		_timer = 0.0
		_bloom()


func _bloom() -> void:
	for m in _prints:
		if is_instance_valid(m):
			m.queue_free()
	_prints.clear()
	var total: float = 0.0
	var left: bool = true
	var delay: float = 0.0
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var seg: float = a.distance_to(b)
		var d: float = 0.0
		while d < seg:
			var pos: Vector3 = a.lerp(b, d / seg)
			var dir: Vector3 = (b - a).normalized()
			var side: Vector3 = Vector3(-dir.z, 0.0, dir.x) * (0.14 if left else -0.14)
			_spawn_print(pos + side, atan2(dir.x, dir.z), delay)
			left = not left
			d += step
			delay += 0.09
			total += step
	if total <= 0.0 and points.size() == 1:
		_spawn_print(points[0], 0.0, 0.0)


func _spawn_print(pos: Vector3, yaw: float, delay: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.22, 0.34)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _tex
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if prismatic:
		mat.emission_enabled = true
		mat.emission = glow_colour
		mat.emission_energy_multiplier = 1.2
	mi.material_override = mat
	mi.position = pos + Vector3(0, 0.025, 0)
	mi.rotation.y = yaw
	mi.scale = Vector3(0.2, 1.0, 0.2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_prints.append(mi)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(mi, "scale", Vector3(1.15, 1.0, 1.15), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(1.0, 1.0, 1.0), 0.15)
	tw.tween_interval(maxf(0.5, life - 1.0))
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.0)
	tw.tween_callback(mi.queue_free)


static func _make_footprint_texture() -> ImageTexture:
	var w: int = 32
	var h: int = 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var fx: float = (float(x) + 0.5) / w * 2.0 - 1.0
			var fy: float = (float(y) + 0.5) / h * 2.0 - 1.0
			# sole: an ellipse; heel: a smaller ellipse; toes: five dots
			var sole: float = (fx * fx) / 0.55 + ((fy + 0.15) * (fy + 0.15)) / 0.55
			var heel: float = (fx * fx) / 0.35 + ((fy - 0.62) * (fy - 0.62)) / 0.16
			var v: float = 0.0
			if sole < 1.0:
				v = 1.0 - sole * 0.35
			if heel < 1.0:
				v = maxf(v, 1.0 - heel * 0.3)
			for t in 5:
				var tx: float = -0.62 + 0.31 * float(t)
				var ty: float = -0.82 + 0.08 * absf(float(t) - 1.5)
				var dd: float = ((fx - tx) * (fx - tx)) / 0.025 + ((fy - ty) * (fy - ty)) / 0.03
				if dd < 1.0:
					v = maxf(v, 1.0 - dd * 0.3)
			# watercolour edge: darker rim
			var a: float = clampf(v, 0.0, 1.0)
			var edge: float = 1.0 if a > 0.0 and a < 0.75 else 0.82
			img.set_pixel(x, y, Color(edge, edge, edge, a))
	return ImageTexture.create_from_image(img)
