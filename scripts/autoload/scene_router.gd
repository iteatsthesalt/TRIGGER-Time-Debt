## Scene routing: locations, battles and endings, with a fade. Autoload name: Router.
extends Node

signal location_loaded(id: StringName, node: Node)

## Location id -> scene path. Filled by _register_defaults() and register(); an entry whose scene is not built
## yet is tolerated (has_location checks the file), so callers guard with has_location or read go()'s result.
var locations: Dictionary = {}
var current_location: StringName = &""
var current_scene: Node = null
var fade: ColorRect
var transitioning: bool = false
var _layer: CanvasLayer


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_layer.add_child(fade)
	_fit_fade()
	get_viewport().size_changed.connect(_fit_fade)
	_register_defaults()


func _fit_fade() -> void:
	# Autoload UI is created before the window settles; size it by hand.
	var r: Rect2 = get_viewport().get_visible_rect()
	fade.position = r.position
	fade.size = r.size


func _register_defaults() -> void:
	locations[&"title"] = "res://scenes/ui/title.tscn"
	locations[&"guardia_kitchen"] = "res://scenes/u0/guardia_kitchen.tscn"
	locations[&"guardia_courtyard"] = "res://scenes/u0/guardia_courtyard.tscn"
	locations[&"atrium"] = "res://scenes/u0/atrium_horologe.tscn"
	locations[&"leene_square"] = "res://scenes/u0/leene_square.tscn"
	locations[&"bamboo_grove"] = "res://scenes/u1/bamboo_grove.tscn"
	locations[&"kuro_truce"] = "res://scenes/u1/kuro_truce.tscn"
	locations[&"test_diorama"] = "res://scenes/test/diorama.tscn"
	locations[&"test_arena"] = "res://scenes/test/arena.tscn"
	locations[&"test_lineup"] = "res://scenes/test/lineup.tscn"


func register(id: StringName, path: String) -> void:
	locations[id] = path


func has_location(id: StringName) -> bool:
	return locations.has(id) and ResourceLoader.exists(locations[id])


## Go to a location. spawn is the Marker3D name to appear at. Returns false when nothing happened: a transition
## is already running, the id is unknown or its scene is not built, or the scene failed to load. A location that
## lands in another universe is a gate jump and is charged (GateJump).
func go(id: StringName, spawn: StringName = &"start", fade_s: float = 0.5) -> bool:
	if transitioning:
		push_warning("Router: go(%s) refused, a transition is already running" % id)
		return false
	if not has_location(id):
		push_error("Router: unknown location %s" % id)
		return false
	transitioning = true
	await fade_out(fade_s)
	var packed: PackedScene = load(locations[id]) as PackedScene
	if packed == null:
		push_error("Router: cannot load %s" % locations[id])
		transitioning = false
		await fade_in(fade_s)
		return false
	Game.location = id
	Game.spawn_point = spawn
	current_location = id
	var tree := get_tree()
	var from_universe: int = Universe.current
	var next: Node = packed.instantiate()
	if current_scene != null and is_instance_valid(current_scene):
		# take the old scene out now so the new one keeps its name (a location can reload itself)
		tree.root.remove_child(current_scene)
		current_scene.queue_free()
	tree.root.add_child(next)
	tree.current_scene = next
	current_scene = next
	if next.has_method("place_party"):
		next.call("place_party", spawn)
	if Universe.current != from_universe:
		GateJump.charge(from_universe, Universe.current, next)
	location_loaded.emit(id, next)
	await tree.process_frame
	await fade_in(fade_s)
	transitioning = false
	return true


func fade_out(seconds: float) -> void:
	if seconds <= 0.0:
		fade.color.a = 1.0
		return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, seconds)
	await tw.finished


func fade_in(seconds: float) -> void:
	if seconds <= 0.0:
		fade.color.a = 0.0
		return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 0.0, seconds)
	await tw.finished


func adopt_current_scene() -> void:
	current_scene = get_tree().current_scene
