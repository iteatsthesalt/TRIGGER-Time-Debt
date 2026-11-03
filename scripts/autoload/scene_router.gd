## Scene routing: locations, battles and endings, with a fade. Autoload name: Router.
extends Node

signal location_loaded(id: StringName, node: Node)
## The screen starts to go black (fade_out): Story clears a finished line so it does not hang over the black.
signal fading_out

## The transition fade's CanvasLayer. Story's dialogue box and captions sit above it (StoryRunner.LAYER), so a line
## or a caption shown while the screen is black (a wake in the dark, "A few days later...") is read over the black.
const FADE_LAYER := 100

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
	_layer.layer = FADE_LAYER
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


## The registry every run starts with, built scenes and scheduled ones alike. A dialogue `go` must name one of
## these (DialogueCheck and lint_data.py read it: unknown is an error, scheduled but not built a warning).
const DEFAULT_LOCATIONS: Dictionary = {
	&"title": "res://scenes/ui/title.tscn",
	&"guardia_kitchen": "res://scenes/u0/guardia_kitchen.tscn",
	&"guardia_courtyard": "res://scenes/u0/guardia_courtyard.tscn",
	&"atrium": "res://scenes/u0/atrium_horologe.tscn",
	&"leene_square": "res://scenes/u0/leene_square.tscn",
	&"bamboo_grove": "res://scenes/u1/bamboo_grove.tscn",
	&"kuro_truce": "res://scenes/u1/kuro_truce.tscn",
	&"ossuary_arrival": "res://scenes/u2/ossuary_arrival.tscn",
	&"test_diorama": "res://scenes/test/diorama.tscn",
	&"test_arena": "res://scenes/test/arena.tscn",
	&"test_lineup": "res://scenes/test/lineup.tscn",
}


func _register_defaults() -> void:
	for id in DEFAULT_LOCATIONS.keys():
		locations[id] = DEFAULT_LOCATIONS[id]


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
	# a location holding the screen black for its own opening (Location.holds_black) lifts the fade itself
	if not (is_instance_valid(next) and "holds_black" in next and next.get("holds_black") == true):
		await fade_in(fade_s)
	transitioning = false
	return true


func fade_out(seconds: float) -> void:
	fading_out.emit()
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
