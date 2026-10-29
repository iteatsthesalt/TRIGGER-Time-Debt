## Pixel-art billboard for a CombatActor. Builds its SpriteFrames from a sheet
## laid out as rows = DIRECTIONS, columns = ANIMS (see tools/sprites/make_placeholders.gd),
## and picks walk/idle + facing from the body's velocity.
class_name ActorSprite
extends AnimatedSprite3D

const FRAME_SIZE := Vector2i(32, 48)
const DIRECTIONS: Array[StringName] = [&"down", &"left", &"right", &"up"]
## name: [first column, frame count, fps, loops]
const ANIMS := {
	&"idle": [0, 2, 2.5, true],
	&"walk": [2, 4, 8.0, true],
	&"attack": [6, 3, 10.0, false],
}
const SHEET_COLUMNS := 9
## The 48 px frame is this tall in metres (matches the 1.6 m collision capsule).
const WORLD_HEIGHT := 1.6
## Below this flat speed (m/s) the actor counts as standing still.
const WALK_THRESHOLD := 0.1

@export var sheet: Texture2D:
	set = set_sheet

var facing: StringName = &"down"
var action: StringName = &"idle"


func _init() -> void:
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	shaded = false
	pixel_size = WORLD_HEIGHT / float(FRAME_SIZE.y)
	animation_finished.connect(_on_animation_finished)


func set_sheet(value: Texture2D) -> void:
	sheet = value
	sprite_frames = build_frames(value) if value else null
	_play()


static func anim_name(act: StringName, dir: StringName) -> StringName:
	return StringName("%s_%s" % [act, dir])


static func build_frames(tex: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for row in DIRECTIONS.size():
		for act in ANIMS:
			var spec: Array = ANIMS[act]
			var anim := anim_name(act, DIRECTIONS[row])
			frames.add_animation(anim)
			frames.set_animation_speed(anim, spec[2])
			frames.set_animation_loop(anim, spec[3])
			for f in int(spec[1]):
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(Vector2((int(spec[0]) + f) * FRAME_SIZE.x, row * FRAME_SIZE.y), FRAME_SIZE)
				frames.add_frame(anim, atlas)
	return frames


## Called every physics frame by CombatActor. Attacks play out before walking resumes.
func update_from_velocity(v: Vector3) -> void:
	var flat := Vector2(v.x, v.z)
	if flat.length() > WALK_THRESHOLD and action != &"attack":
		if absf(flat.x) > absf(flat.y):
			facing = &"right" if flat.x > 0.0 else &"left"
		else:
			facing = &"down" if flat.y > 0.0 else &"up"  # camera looks toward -Z
	if action != &"attack":
		action = &"walk" if flat.length() > WALK_THRESHOLD else &"idle"
	_play()


func play_attack() -> void:
	action = &"attack"
	_play()


func _play() -> void:
	if sprite_frames == null:
		return
	var anim := anim_name(action, facing)
	if animation != anim and sprite_frames.has_animation(anim):
		play(anim)


func _on_animation_finished() -> void:
	if action == &"attack":
		action = &"idle"
		_play()
