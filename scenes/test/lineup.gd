## Cast lineup: every generated character sheet standing on a lit stage, one row per character,
## eight facings each (s, sw, w, nw, n, ne, e, se), playing the animation named by --anim= (default walk).
## Used for art review captures: tools/capture/render.sh test_lineup lineup 40 -- --ids=crono,sera --anim=walk [--tier=action] [--variant=u1]
extends Node3D

var ids: Array[String] = ["crono"]
var anim: StringName = &"walk"
var tier: StringName = &"field"
var variant: StringName = &""
var rig: HD2DCameraRig
var world: HD2DWorld
var _sprites: Array[ActorSprite] = []
var _t: float = 0.0
var _facings: Array[StringName] = [&"s", &"sw", &"w", &"nw", &"n", &"ne", &"e", &"se"]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ids="):
			ids.clear()
			for s in arg.trim_prefix("--ids=").split(","):
				ids.append(s.strip_edges())
		elif arg.begins_with("--anim="):
			anim = StringName(arg.trim_prefix("--anim="))
		elif arg.begins_with("--tier="):
			tier = StringName(arg.trim_prefix("--tier="))
		elif arg.begins_with("--variant="):
			variant = StringName(arg.trim_prefix("--variant="))
	world = HD2DWorld.new()
	world.name = "World"
	add_child(world)
	HD2DWorld.add_three_point_lights(self)
	var stone := SceneKit.material("res://assets/textures/stone_mossy_albedo.png", "res://assets/textures/stone_normal.png", 0.95, Color(0.9, 0.9, 0.9), true)
	var wall := SceneKit.material("res://assets/textures/castle_wall_albedo.png", "res://assets/textures/castle_wall_normal.png", 0.9, Color(0.95, 0.95, 0.95), true)
	SceneKit.floor_plane(self, Vector2(30, 30), Vector3.ZERO, stone)
	SceneKit.box(self, Vector3(30, 5, 0.6), Vector3(0, 2.5, -4.0 - float(ids.size()) * 1.4), wall, "BackWall")
	var centre := Node3D.new()
	centre.name = "Centre"
	add_child(centre)
	var row_count: int = ids.size()
	for r in row_count:
		var id: String = ids[r]
		for f in _facings.size():
			var holder := Node3D.new()
			holder.name = "%s_%s" % [id, String(_facings[f])]
			holder.position = Vector3((float(f) - 3.5) * 2.0, 0.0, (float(r) - float(row_count - 1) * 0.5) * 2.6)
			add_child(holder)
			var s := ActorSprite.new()
			holder.add_child(s)
			SpriteLibrary.apply(s, id, 60.0, tier, variant)
			s.set_facing(_facings[f])
			s.play(anim)
			_sprites.append(s)
	centre.position = Vector3(0, 0, 0)
	rig = HD2DCameraRig.new()
	rig.name = "CameraRig"
	rig.distance = 14.5 + float(row_count) * 1.2
	rig.pitch_degrees = 22.0
	rig.height_offset = 0.9
	add_child(rig)
	rig.target = centre
	rig.snap()
	Universe.set_universe(0, true)


func _process(delta: float) -> void:
	_t += delta
	# Facing labels are implied by position; keep every sprite on its chosen facing (play() may reset to idle).
	for s in _sprites:
		if s.anim != anim and s.anims.has(anim):
			s.play(anim)


func get_actor(_id: StringName) -> Node:
	return get_node_or_null("Centre")


func get_marker(_name: StringName) -> Variant:
	return Vector3.ZERO
