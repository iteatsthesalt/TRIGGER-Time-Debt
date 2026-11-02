## A lit billboard sprite on a quad with the sprite_canvas shader (Reference Bible §1.7, §1.9).
## Frames come from a sheet whose rows are directions (S, W, E, N) and whose columns are animations,
## described by a frame table; steps at the character's own canvas rate with per-frame holds.
class_name ActorSprite
extends MeshInstance3D

## The world's density (SceneKit.PX_PER_M, DECISIONS "Direction"): a sheet drawn on the Nov 1 recipe's
## 64-96 px canvas with no height in its frames json stands at 32 px per metre.
const PIXELS_PER_METRE := SceneKit.PX_PER_M
## The superseded density of the 128 px chibi cells, the painted stand-ins and every older sheet without a
## height (Reference Bible §1.2): they keep their on-screen size until their 64 px replacements arrive.
const LEGACY_PIXELS_PER_METRE := 64.0
## A height-less sheet whose cell is above this was drawn at the legacy density.
const RECIPE_MAX_CELL := 96
## Below this opacity the sprite draws with the blended fade shader instead of the cut-out one.
const OPAQUE_AT := 0.999
## Sheet rows in order. Four-row sheets use the first four; eight-row sheets add the diagonals. A frames json
## may name its own order (`rows`); this is the default and the order the importer writes.
const DIRECTIONS: Array[StringName] = [&"s", &"w", &"e", &"n", &"sw", &"se", &"nw", &"ne"]
const CARDINALS: Array[StringName] = [&"s", &"w", &"e", &"n"]

## What this sprite shows: the sprite id and the requested tier/variant (SpriteLibrary.apply sets them),
## plus what was actually found (loaded_*), so a cut-in can swap tiers and come back.
var sprite_id: String = ""
var tier: StringName = &"field"
var variant: StringName = &""
var loaded_tier: StringName = &"field"
var loaded_variant: StringName = &""
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
## The sheet's row order (its frames json `rows`, else DIRECTIONS).
var row_order: Array[StringName] = DIRECTIONS.duplicate()
## 0..1; below OPAQUE_AT the fade shader draws it blended (set_opacity).
var opacity: float = 1.0
var material: ShaderMaterial
var _accum: float = 0.0
var _finished: bool = false
var _one_shot_return: StringName = &""
var _reverse_left: float = 0.0
var _sheet_size: Vector2 = Vector2(128, 128)
## Metres per sheet pixel. A sheet with a height in its frames json stands at that height whatever its
## drawn pixel height (set_height); one without falls back to its cell's density (fallback_pixel_size).
var pixel_size: float = 1.0 / LEGACY_PIXELS_PER_METRE

static var _shader: Shader
static var _shader_fade: Shader
static var _galaxy: Cubemap
static var _crack: Texture2D


func _init() -> void:
	mesh = QuadMesh.new()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if _shader == null:
		_shader = load("res://shaders/sprite_canvas.gdshader")
		_shader_fade = load("res://shaders/sprite_canvas_fade.gdshader")
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


## A single painted image used as a stand-in (every direction shows the same drawing), drawn at
## `px_per_m`: the painted stand-ins at the legacy density, SpriteLibrary's placeholders at the world's.
func set_standin(tex: Texture2D, fps: float = 60.0, px_per_m: float = LEGACY_PIXELS_PER_METRE) -> void:
	canvas_fps = fps if fps > 0.0 else 60.0
	pixel_size = 1.0 / maxf(1.0, px_per_m)
	cell = tex.get_height()
	columns = 1
	rows = 1
	row_order = DIRECTIONS.duplicate()
	anims = {&"idle": {"col": 0, "count": 1, "fps": canvas_fps, "loop": true, "holds": []}}
	_apply_sheet(tex)
	_set_quad_size(tex.get_width(), tex.get_height())
	anim = &""  # force play() to set the frame rect even if we were already on idle
	play(&"idle")


## A full sheet: rows are directions (in `order`, else DIRECTIONS), `table` maps anim -> {col, count, fps,
## loop, holds}.
func set_sheet(tex: Texture2D, cell_px: int, table: Dictionary, fps: float = 60.0, mirror_w: bool = false, order: Array = []) -> void:
	canvas_fps = fps if fps > 0.0 else 60.0
	cell = cell_px
	columns = maxi(1, tex.get_width() / cell_px)
	rows = maxi(1, tex.get_height() / cell_px)
	anims = table
	mirror_w_from_e = mirror_w
	row_order.clear()
	for d in (order if not order.is_empty() else DIRECTIONS):
		row_order.append(StringName(d))
	_apply_sheet(tex)
	_set_quad_size(cell_px, cell_px)
	anim = &""  # force play() to set the frame rect even if we were already on idle
	play(&"idle")


func _apply_sheet(tex: Texture2D) -> void:
	_sheet_size = Vector2(tex.get_width(), tex.get_height())
	material.set_shader_parameter("sheet", tex)
	material.set_shader_parameter("sheet_px", _sheet_size)
	material.set_shader_parameter("canvas_fps", canvas_fps)


func _set_quad_size(w: int, h: int) -> void:
	var q := mesh as QuadMesh
	q.size = Vector2(float(w) * pixel_size, float(h) * pixel_size)
	q.center_offset = Vector3(0.0, q.size.y * 0.5 - 8.0 * pixel_size, 0.0)


## Scale the sheet so `height_px` drawn pixels stand `height_m` metres tall (feet stay on the ground line).
## Without a height the sheet stands at its cell's density (fallback_pixel_size); `cell_px` < 0 keeps the cell.
func set_height(height_px: int, height_m: float, cell_px: int = -1) -> void:
	if cell_px > 0:
		cell = cell_px
	if height_px > 0 and height_m > 0.0:
		pixel_size = height_m / float(height_px)
	else:
		pixel_size = fallback_pixel_size(cell)
	_set_quad_size(cell, cell)


## Metres per pixel of a sheet with no height: the recipe canvas (cell up to 96 px) at the world's 32 px/m,
## the older 128 px and larger cells at the legacy 64 px/m, so no shipped sheet changes size.
static func fallback_pixel_size(cell_px: int) -> float:
	return 1.0 / (PIXELS_PER_METRE if cell_px <= RECIPE_MAX_CELL else LEGACY_PIXELS_PER_METRE)


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


## 1 draws the cut-out pass (opaque, shadows; `transparency` still fades it); below 1 the fade pass blends it
## at (1 - transparency) × opacity, so a ghost at 0.45 reads at 45 % and its transparency tween fades it out.
func set_opacity(a: float) -> void:
	opacity = clampf(a, 0.0, 1.0)
	material.set_shader_parameter("opacity", opacity)
	var want: Shader = _shader if opacity >= OPAQUE_AT else _shader_fade
	if want != null and material.shader != want:
		_swap_shader(want)


## True while the blended fade pass draws this sprite.
func is_faded() -> bool:
	return material.shader == _shader_fade and _shader_fade != null


func _swap_shader(want: Shader) -> void:
	var keep: Dictionary = {}
	for u in material.shader.get_shader_uniform_list():
		var v: Variant = material.get_shader_parameter(u["name"])
		if v != null:
			keep[u["name"]] = v
	material.shader = want
	for k in keep.keys():
		material.set_shader_parameter(k, keep[k])  # both passes share one body: every value carries over


## The per-sprite pattern of crack veins and drift jitter (SpriteLibrary seeds it from the sprite id).
func set_seed(s: float) -> void:
	material.set_shader_parameter("seed", s)


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
	if not CARDINALS.has(dir) and (rows < 8 or not row_order.has(dir)):
		dir = _to_cardinal(dir)
	if DIRECTIONS.has(dir) and dir != facing:
		facing = dir
		_update_rect()


static func _to_cardinal(dir: StringName) -> StringName:
	match dir:
		&"sw", &"se":
			return &"s"
		&"nw", &"ne":
			return &"n"
	return dir


func face_vector(v: Vector3) -> void:
	var flat := Vector2(v.x, v.z)
	if flat.length() < 0.05:
		return
	if rows >= 8:
		# Eight-way: 45° sectors around +z = south.
		var ang: float = atan2(flat.x, flat.y)  # 0 = south, +90° = east, ±180° = north, -90° = west
		var sector: int = wrapi(int(round(ang / (PI * 0.25))), 0, 8)
		var by_sector: Array[StringName] = [&"s", &"se", &"e", &"ne", &"n", &"nw", &"w", &"sw"]
		set_facing(by_sector[sector])
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


## Swap to another tier of the same character (action for a Dual Tech cut-in, map on the overworld), keeping
## facing and the current animation when the new sheet has it. Falls back to field when the tier is missing.
## Returns true when the requested tier was actually loaded.
func set_tier(new_tier: StringName) -> bool:
	if sprite_id == "":
		return false
	var keep_anim: StringName = anim
	var keep_facing: StringName = facing
	SpriteLibrary.apply(self, sprite_id, canvas_fps, new_tier, variant)
	facing = keep_facing
	if anims.has(keep_anim):
		anim = &""
		play(keep_anim)
	_update_rect()
	return loaded_tier == new_tier


## Swap to a variant (another universe's canvas, a story state such as debt20). Missing variants fall back
## to the base sheet of the same tier. Returns true when the variant was found.
func set_variant(new_variant: StringName) -> bool:
	if sprite_id == "":
		return false
	var keep_anim: StringName = anim
	var keep_facing: StringName = facing
	SpriteLibrary.apply(self, sprite_id, canvas_fps, tier, new_variant)
	facing = keep_facing
	if anims.has(keep_anim):
		anim = &""
		play(keep_anim)
	_update_rect()
	return loaded_variant == new_variant


## Play an animation's frames in reverse for `seconds` (Sera's Rewind winds her father's idle back).
func play_backwards(name: StringName, seconds: float) -> void:
	play(name)
	_reverse_left = seconds


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
	if _reverse_left > 0.0:
		_reverse_left -= delta
		while _accum >= frame_time:
			_accum -= frame_time
			frame = wrapi(frame - 1, 0, count)
		_update_rect()
		return
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
		var f: StringName = facing if rows >= 8 else _to_cardinal(facing)
		row = row_order.find(f)
		if row < 0:
			row = row_order.find(_to_cardinal(f))
		if mirror_w_from_e and f == &"w":
			row = row_order.find(&"e")
			flip = true
		elif mirror_w_from_e and rows >= 8 and (f == &"sw" or f == &"nw"):
			row = row_order.find(&"se" if f == &"sw" else &"ne")
			flip = true
		if row < 0 or row >= rows:
			row = 0
	elif rows >= 1 and a.has("row"):
		row = int(a["row"])
	var cw: float = float(cell) / _sheet_size.x
	var ch: float = float(cell) / _sheet_size.y
	material.set_shader_parameter("frame_rect", Vector4(float(col) * cw, float(row) * ch, cw, ch))
	material.set_shader_parameter("flip_h", flip)


func is_finished() -> bool:
	return _finished
