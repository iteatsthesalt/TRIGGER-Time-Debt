## Builds the one WorldEnvironment + Compositor every scene shares (Reference Bible §2.2–2.3) and
## keeps the CanvasStackEffect fed with the UniverseSwitcher's weights and the Debt.
class_name HD2DWorld
extends WorldEnvironment

var canvas_stack: CanvasStackEffect
var _attached: bool = false


static func make_environment(universe_id: int = 0) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.09, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.70)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.0
	env.glow_enabled = true
	env.glow_intensity = 1.15
	env.glow_strength = 0.85
	env.glow_bloom = 0.35
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.sdfgi_enabled = false
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	_tint_for(env, universe_id)
	return env


static func _tint_for(env: Environment, universe_id: int) -> void:
	match universe_id:
		1:
			env.background_color = Color(0.05, 0.15, 0.35)
			env.ambient_light_color = Color(0.55, 0.62, 0.78)
		2:
			env.background_color = Color(0.10, 0.08, 0.07)
			env.ambient_light_color = Color(0.60, 0.52, 0.42)
		3:
			env.background_color = Color(0.86, 0.90, 0.94)
			env.ambient_light_color = Color(0.85, 0.88, 0.80)
			env.ambient_light_energy = 0.8
		4:
			env.background_color = Color(0.02, 0.06, 0.10)
			env.ambient_light_color = Color(0.25, 0.40, 0.55)
		5:
			env.background_color = Color(0.20, 0.17, 0.12)
			env.ambient_light_color = Color(0.70, 0.62, 0.45)
		6:
			env.background_color = Color(0.06, 0.06, 0.14)
			env.ambient_light_color = Color(0.35, 0.40, 0.65)
		7, 9:
			env.background_color = Color(0.98, 0.97, 0.94)
			env.ambient_light_color = Color(0.95, 0.93, 0.88)
			env.ambient_light_energy = 0.9
		8:
			env.background_color = Color(0.95, 0.94, 0.92)
			env.ambient_light_color = Color(0.85, 0.85, 0.9)


func _ready() -> void:
	if environment == null:
		environment = make_environment(Universe.current if is_instance_valid(Universe) else 0)
	canvas_stack = CanvasStackEffect.new()
	if compositor == null:
		compositor = Compositor.new()
	var effects: Array[CompositorEffect] = compositor.compositor_effects
	effects.append(canvas_stack)
	compositor.compositor_effects = effects
	if is_instance_valid(Universe):
		canvas_stack.weights = Universe.weights.duplicate()
		Universe.weights_changed.connect(_on_weights)
	if is_instance_valid(Game):
		_on_integrity(Game.crono_integrity)
		Game.integrity_changed.connect(_on_integrity)
		Game.settings_changed.connect(_on_settings)
		_on_settings()


func _on_weights(w: PackedFloat32Array) -> void:
	canvas_stack.weights = _with_leaks(w)


## Hub leaks (§2.4): another universe bleeds into the current grade without changing the universe.
var _leaks: Dictionary = {}


func set_leak(universe_id: int, amount: float) -> void:
	if amount <= 0.001:
		_leaks.erase(universe_id)
	else:
		_leaks[universe_id] = clampf(amount, 0.0, 1.0)
	if is_instance_valid(Universe):
		canvas_stack.weights = _with_leaks(Universe.weights)


func _with_leaks(w: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = w.duplicate()
	if _leaks.is_empty():
		return out
	var total_leak: float = 0.0
	for k in _leaks.keys():
		total_leak += float(_leaks[k])
	total_leak = minf(total_leak, 0.85)
	for i in out.size():
		out[i] *= (1.0 - total_leak)
	for k in _leaks.keys():
		var idx: int = int(k)
		if idx >= 0 and idx < out.size():
			out[idx] += float(_leaks[k]) * (total_leak / maxf(0.001, _sum_leaks()))
	return out


func _sum_leaks() -> float:
	var t: float = 0.0
	for k in _leaks.keys():
		t += float(_leaks[k])
	return t


func _on_integrity(v: float) -> void:
	# U0 dilutes as the Debt grows: paper shows through below 60% integrity.
	canvas_stack.debt = clampf((60.0 - v) / 60.0, 0.0, 1.0) * 0.8


func _on_settings() -> void:
	canvas_stack.reduced_flicker = bool(Game.settings.get("reduced_flicker", false))


func set_vaelos_near(amount: float) -> void:
	canvas_stack.vaelos_near = clampf(amount, 0.0, 1.0)


## A key light, fill and rim arranged for a diorama; returns the key light.
static func add_three_point_lights(parent: Node3D, warm: bool = true) -> DirectionalLight3D:
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color(1.0, 0.93, 0.82) if warm else Color(0.85, 0.9, 1.0)
	key.light_energy = 1.35
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	key.directional_shadow_max_distance = 60.0
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 1.5
	key.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	parent.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.light_color = Color(0.70, 0.78, 0.95)
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-30.0, -120.0, 0.0)
	parent.add_child(fill)
	return key
