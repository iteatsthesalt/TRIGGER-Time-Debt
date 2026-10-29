## A lit billboard sprite on a quad with the sprite_canvas shader (Reference Bible §1.7, §1.9).
## Frames come from a sheet whose rows are directions (S, W, E, N) and whose columns are animations,
## described by a frame table; steps at the character's own canvas rate with per-frame holds.
class_name ActorSprite
extends MeshInstance3D

const PIXELS_PER_METRE := 64.0
const DIRECTIONS: Array[StringName] = [&"s", &"w", &"e", &"n"]

var cell: int = 128
var columns: int = 1
var rows: int = 1
var canvas_fps: float = 60.0
## anim name -> {col: first column, count: n, fps: f, loop: bool, holds: Array[float] (seconds per frame)}
var anims: Dictionary = {}
var anim: StringName = &"idle"
var facing: StringName = &"s"
var frame: int = 0
var mirror_w_from_e: bool = false
var material: ShaderMaterial
var _accum: float = 0.0
var _finished: bool = false
var _one_shot_return: StringName = &""
var _sheet_size: Vector2 = Vector2(128, 128)

static var _shader: Shader
static var _galaxy: Cubemap
static var _crack: Texture2D


func _init() -> void:
	mesh = QuadMesh.new()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if _shader == null:
		_shader = load("res://shaders/sprite_canvas.gdshader")
	material = ShaderMaterial.new()
	material.shader = _shader
	material_override = material
	if _crack == null and ResourceLoader.exists("res://assets/textures/crack_noise.png"):
		_crack = load("res://assets/textures/crack_noise.png")
	if _galaxy == null and ResourceLoader.exists("res://assets/textures/galaxy_cubemap_6x1.png"):
		_galaxy = _make_cubemap(load("res://assets/textures/galaxy_cubemap_6x1.png"))
	if _crack != null:
		material.set_shader_parameter("crack_noise", _crack)
	if _galaxy != null:
		material.set_shader_parameter("galaxy", _galaxy)


static func _make_cubemap(tex: Texture2D) -> Cubemap:
	var img: Image = tex.get_image()
	if img == null:
		return null
	var face: int = img.get_height()
	var faces: Array[Image] = []
	for i in 6:
		faces.append(img.get_region(Rect2i(i * face, 0, face, face)))
	var cm := Cubemap.new()
	cm.create_from_images(faces)
	return cm


## A single painted image used as a stand-in (every direction shows the same drawing).
func set_standin(tex: Texture2D, fps: float = 60.0) -> void:
	canvas_fps = fps
	cell = tex.get_height()
	columns = 1
	rows = 1
	anims = {&"idle": {"col": 0, "count": 1, "fps": fps, "loop": true, "holds": []}}
	_apply_sheet(tex)
	_set_quad_size(tex.get_width(), tex.get_height())
	play(&"idle")


## A full sheet: rows are directions, `table` maps anim -> {col, count, fps, loop, holds}.
func set_sheet(tex: Texture2D, cell_px: int, table: Dictionary, fps: float = 60.0, mirror_w: bool = false) -> void:
	canvas_fps = fps
	cell = cell_px
	columns = maxi(1, tex.get_width() / cell_px)
	rows = maxi(1, tex.get_height() / cell_px)
	anims = table
	mirror_w_from_e = mirror_w
	_apply_sheet(tex)
	_set_quad_size(cell_px, cell_px)
	play(&"idle")


func _apply_sheet(tex: Texture2D) -> void:
	_sheet_size = Vector2(tex.get_width(), tex.get_height())
	material.set_shader_parameter("sheet", tex)
	material.set_shader_parameter("sheet_px", _sheet_size)
	material.set_shader_parameter("canvas_fps", canvas_fps)


func _set_quad_size(w: int, h: int) -> void:
	var q := mesh as QuadMesh
	q.size = Vector2(float(w) / PIXELS_PER_METRE, float(h) / PIXELS_PER_METRE)
	q.center_offset = Vector3(0.0, q.size.y * 0.5 - 8.0 / PIXELS_PER_METRE, 0.0)


func set_normal_sheet(tex: Texture2D) -> void:
	material.set_shader_parameter("sheet_normal", tex)
	material.set_shader_parameter("use_normal", tex != null)


func set_mask_sheet(tex: Texture2D) -> void:
	material.set_shader_parameter("sheet_mask", tex)
	material.set_shader_parameter("use_mask", tex != null)


func set_porcelain(state: int, crack_amount: float, kintsugi: float = 0.0, moss: float = 0.0) -> void:
	material.set_shader_parameter("porcelain_state", state)
	material.set_shader_parameter("crack_amount", crack_amount)
	material.set_shader_parameter("kintsugi", kintsugi)
	material.set_shader_parameter("moss_amount", moss)


func set_tint(c: Color) -> void:
	material.set_shader_parameter("tint", c)


func set_opacity(a: float) -> void:
	material.set_shader_parameter("opacity", a)


func set_wobble(px: float) -> void:
	material.set_shader_parameter("wobble_px", px)


func play(name: StringName, return_to: StringName = &"") -> void:
	if not anims.has(name):
		if anims.has(&"idle"):
			name = &"idle"
		else:
			return
	if anim == name and not _finished and return_to == &"":
		return
	anim = name
	frame = 0
	_accum = 0.0
	_finished = false
	_one_shot_return = return_to
	_update_rect()


func set_facing(dir: StringName) -> void:
	if DIRECTIONS.has(dir) and dir != facing:
		facing = dir
		_update_rect()


func face_vector(v: Vector3) -> void:
	var flat := Vector2(v.x, v.z)
	if flat.length() < 0.05:
		return
	if absf(flat.x) > absf(flat.y):
		set_facing(&"e" if flat.x > 0.0 else &"w")
	else:
		set_facing(&"s" if flat.y > 0.0 else &"n")


func update_from_velocity(v: Vector3, walking_anim: StringName = &"walk") -> void:
	var flat := Vector2(v.x, v.z)
	if flat.length() > 0.1:
		face_vector(v)
		if _one_shot_return == &"":
			play(walking_anim)
	elif _one_shot_return == &"":
		play(&"idle")


func _process(delta: float) -> void:
	if not anims.has(anim):
		return
	var a: Dictionary = anims[anim]
	var count: int = int(a.get("count", 1))
	if count <= 1 or _finished:
		return
	var holds: Array = a.get("holds", [])
	var fps: float = float(a.get("fps", canvas_fps))
	var frame_time: float = float(holds[frame]) if frame < holds.size() else 1.0 / maxf(1.0, fps)
	_accum += delta
	while _accum >= frame_time:
		_accum -= frame_time
		frame += 1
		if frame >= count:
			if bool(a.get("loop", true)):
				frame = 0
			else:
				frame = count - 1
				_finished = true
				if _one_shot_return != &"":
					var back: StringName = _one_shot_return
					_one_shot_return = &""
					play(back)
					return
				break
		frame_time = float(holds[frame]) if frame < holds.size() else 1.0 / maxf(1.0, fps)
	_update_rect()


func _update_rect() -> void:
	if not anims.has(anim):
		return
	var a: Dictionary = anims[anim]
	var col: int = int(a.get("col", 0)) + frame
	var row: int = 0
	var flip: bool = false
	if rows >= 4:
		row = DIRECTIONS.find(facing)
		if mirror_w_from_e and facing == &"w":
			row = DIRECTIONS.find(&"e")
			flip = true
	elif rows >= 1 and a.has("row"):
		row = int(a["row"])
	var cw: float = float(cell) / _sheet_size.x
	var ch: float = float(cell) / _sheet_size.y
	material.set_shader_parameter("frame_rect", Vector4(float(col) * cw, float(row) * ch, cw, ch))
	material.set_shader_parameter("flip_h", flip)


func is_finished() -> bool:
	return _finished
