## Scene routing: locations, battles and endings, with a fade. Autoload name: Router.
extends Node

signal location_loaded(id: StringName, node: Node)
signal fade_finished

## Location id -> scene path. Filled from data/universes/locations and extended by code.
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


func register(id: StringName, path: String) -> void:
	locations[id] = path


func has_location(id: StringName) -> bool:
	return locations.has(id) and ResourceLoader.exists(locations[id])


## Go to a location. spawn is the Marker3D name to appear at.
func go(id: StringName, spawn: StringName = &"start", fade_s: float = 0.5) -> void:
	if transitioning:
		return
	if not has_location(id):
		push_error("Router: unknown location %s" % id)
		return
	transitioning = true
	await fade_out(fade_s)
	var packed: PackedScene = load(locations[id]) as PackedScene
	if packed == null:
		push_error("Router: cannot load %s" % locations[id])
		transitioning = false
		await fade_in(fade_s)
		return
	Game.location = id
	Game.spawn_point = spawn
	current_location = id
	var tree := get_tree()
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
	location_loaded.emit(id, next)
	await tree.process_frame
	await fade_in(fade_s)
	transitioning = false


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
	fade_finished.emit()


func adopt_current_scene() -> void:
	current_scene = get_tree().current_scene
