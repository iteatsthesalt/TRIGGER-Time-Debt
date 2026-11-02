## The UniverseSwitcher (Reference Bible §2.4): the current canvas, the nine blend weights,
## canvas drawing rates and the 0.8 s Chronoslip blend. Autoload name: Universe.
extends Node

signal universe_changed(id: int)
signal weights_changed(weights: PackedFloat32Array)
signal blend_started(from_id: int, to_id: int)

const BLEND_S := 0.8
## Canvas drawing rates and names come from data/universes/universes.json (Data.universe, Reference Bible §3.1);
## the grade parameters live in CanvasStackEffect.GRADES (the compositor's one table).
const DEFAULT_FPS := 60.0

var current: int = 0
var target: int = 0
var weights := PackedFloat32Array([1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
var _from_weights := PackedFloat32Array()
var _blend_t: float = -1.0


func _process(delta: float) -> void:
	if _blend_t >= 0.0:
		_blend_t += delta / BLEND_S
		var t: float = clampf(_blend_t, 0.0, 1.0)
		for i in weights.size():
			var goal: float = 1.0 if i == target else 0.0
			weights[i] = lerpf(_from_weights[i], goal, t)
		weights_changed.emit(weights)
		if _blend_t >= 1.0:
			_blend_t = -1.0
			current = target
			universe_changed.emit(current)


func set_universe(id: int, instant: bool = false) -> void:
	id = clampi(id, 0, 9)
	if instant or not is_inside_tree():
		current = id
		target = id
		for i in weights.size():
			weights[i] = 1.0 if i == id else 0.0
		_blend_t = -1.0
		weights_changed.emit(weights)
		universe_changed.emit(current)
		return
	if id == target:
		return
	blend_started.emit(current, id)
	_from_weights = weights.duplicate()
	target = id
	_blend_t = 0.0


func fps_of(id: int) -> float:
	return float(Data.universe(clampi(id, 0, 9)).get("fps", DEFAULT_FPS))


func current_fps() -> float:
	return fps_of(current)


func name_of(id: int) -> String:
	var u: int = clampi(id, 0, 9)
	return String(Data.universe(u).get("name", "U%d" % u))


## Quantised time for the current canvas: floor(t × fps) / fps.
func quantised_time(t: float) -> float:
	var f: float = current_fps()
	return floor(t * f) / f
