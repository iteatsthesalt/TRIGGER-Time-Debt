## A prop standing in a location (docs/ART_PIPELINE.md §6; Reference Bible §1.4 PRP-S/PRP-M): a lit
## billboard from assets/props/u<n>/<key>/ (the same ActorSprite, shader, normal sheet and canvas rate
## as the cast) standing `height_m` metres tall from data/props, with an optional collision box sized
## from the drawn sprite, looping its idle clip when it has one. When the asset has not arrived (or the
## key is unknown) a labelled placeholder box of the declared height stands in, so a scene never breaks.
class_name PropBillboard
extends Node3D

const PLACEHOLDER_COLOUR := Color(0.52, 0.46, 0.58)

## The share of the drawn width each post of a "posts" footprint takes (an arch's uprights).
const POST_SHARE := 0.2

var key: StringName = &""
var def: Dictionary = {}
var sprite: ActorSprite
var body: StaticBody3D
## Width, height and depth of the prop in metres: the measured box (drawn width, declared height).
var footprint: Vector3 = Vector3(0.6, 1.0, 0.4)
## The collision boxes when the prop is solid, as [size, centre offset] pairs: one box the size of
## `footprint` by default; data/props `footprint` may replace it with `[width, depth]` (one centred
## box), `"posts"` (two uprights at the drawn ends, so an arch or gate frames a walkable opening) or a
## list of `[width, depth, x_offset]` boxes (a portcullis: two posts and the grille between them).
var boxes: Array[Array] = []
var y_offset: float = 0.0
var placeholder: bool = false


## Build a prop for `key`. `facing` picks the rotation row on multi-rotation sheets; `solid` can switch
## the data's collision off for a decorative copy (it never switches it on for a prop declared not solid).
static func make(prop_key: StringName, facing: StringName = &"s", solid: bool = true) -> PropBillboard:
	var p := PropBillboard.new()
	p.name = "Prop_" + String(prop_key)
	p.key = prop_key
	p.def = Data.prop(prop_key)
	if p.def.is_empty():
		push_warning("PropBillboard: %s is not in data/props; a placeholder stands in" % prop_key)
	var height_m: float = maxf(0.05, float(p.def.get("height_m", 1.0)))
	p.y_offset = float(p.def.get("y_offset", 0.0))
	var universe: int = int(p.def.get("universe", -1))
	var r: Dictionary = {} if bool(p.def.get("pending", false)) else SpriteLibrary.resolve_prop(String(prop_key), universe)
	if r.is_empty():
		p._build_placeholder(height_m)
	else:
		p._build_sprite(r, facing, height_m, universe)
	p.boxes = p._boxes_from(p.def.get("footprint", null))
	if solid and bool(p.def.get("solid", true)):
		p._add_collision()
	return p


## The collision boxes a data `footprint` describes (see `boxes`); null or an empty list means the
## measured box.
func _boxes_from(fp: Variant) -> Array[Array]:
	var out: Array[Array] = []
	if fp is String and String(fp) == "posts":
		var post_w: float = maxf(0.3, footprint.x * POST_SHARE)
		var dx: float = (footprint.x - post_w) * 0.5
		out.append([Vector3(post_w, footprint.y, footprint.z), Vector3(-dx, 0.0, 0.0)])
		out.append([Vector3(post_w, footprint.y, footprint.z), Vector3(dx, 0.0, 0.0)])
	elif fp is Array and (fp as Array).size() >= 2 and not ((fp as Array)[0] is Array):
		footprint = Vector3(float(fp[0]), footprint.y, float(fp[1]))
		out.append([footprint, Vector3.ZERO])
	elif fp is Array:
		for b in fp:
			if b is Array and (b as Array).size() >= 2:
				out.append([Vector3(float(b[0]), footprint.y, float(b[1])), Vector3(float(b[2]) if (b as Array).size() >= 3 else 0.0, 0.0, 0.0)])
	if out.is_empty():
		out.append([footprint, Vector3.ZERO])
	return out


func _build_sprite(r: Dictionary, facing: StringName, height_m: float, universe: int) -> void:
	sprite = ActorSprite.new()
	sprite.name = "Sprite"
	add_child(sprite)
	SpriteLibrary.apply_prop(sprite, String(key), Universe.fps_of(maxi(universe, 0)), universe)
	sprite.set_facing(facing)
	var emission: float = float(def.get("emission", 0.0))
	if emission > 0.0:
		sprite.material.set_shader_parameter("emission_strength", emission)
	var meta: Dictionary = SpriteLibrary.frames_meta(r)
	var width_px: float = float(meta.get("width_px", sprite.cell))
	var width_m: float = maxf(0.2, width_px * sprite.pixel_size)
	footprint = Vector3(width_m, height_m, clampf(width_m * 0.5, 0.3, 1.2))


## A readable stand-in: a box of the declared height with the key written on it (never shipped).
func _build_placeholder(height_m: float) -> void:
	placeholder = true
	var w: float = maxf(0.4, height_m * 0.6)
	footprint = Vector3(w, height_m, maxf(0.3, height_m * 0.4))
	var mat := SceneKit.flat_color(PLACEHOLDER_COLOUR, Color.BLACK, 0.0, 0.9)
	SceneKit.box(self, footprint, Vector3(0.0, height_m * 0.5, 0.0), mat, "Placeholder", false)
	var label := Label3D.new()
	label.name = "Label"
	label.text = String(key).trim_prefix("prp_")
	label.font_size = 48
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(0.95, 0.92, 0.85)
	label.outline_modulate = Color(0.1, 0.08, 0.12)
	label.outline_size = 10
	label.position = Vector3(0.0, height_m + 0.25, 0.0)
	add_child(label)


func _add_collision() -> void:
	body = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	for b in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = b[0]
		cs.shape = shape
		cs.position = (b[1] as Vector3) + Vector3(0.0, (b[0] as Vector3).y * 0.5, 0.0)
		body.add_child(cs)
	add_child(body)


## Freeze an animated prop on its drawn rotation (the hearth gone cold), or let it loop again.
func set_still(still: bool) -> void:
	if sprite == null:
		return
	if still and sprite.anims.has(&"still"):
		sprite.play(&"still")
	else:
		sprite.play(&"idle")


func set_tint(c: Color) -> void:
	if sprite:
		sprite.set_tint(c)
