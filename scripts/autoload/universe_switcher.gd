## The UniverseSwitcher (Reference Bible §2.4): the current canvas, the nine blend weights,
## canvas drawing rates and the 0.8 s Chronoslip blend. Autoload name: Universe.
extends Node

signal universe_changed(id: int)
signal weights_changed(weights: PackedFloat32Array)
signal blend_started(from_id: int, to_id: int)

const BLEND_S := 0.8
## Canvas drawing rates by universe (Reference Bible §3.1).
const FPS: Array[float] = [60.0, 24.0, 12.0, 30.0, 60.0, 12.0, 15.0, 24.0, 15.0, 60.0]
const NAMES: Array[String] = [
	"Atrium Horologe", "Crimson Shogunate", "Clockwork Ossuary", "Saurian Eden", "Drowned Cathedral",
	"Carnival of Ash", "1999 A.D. Singularity", "Bone-Tree of Eternity", "Vaelos Heart", "White Void",
]
## Paper tint and the LUT-like grade parameters per universe, read by the compositor.
const GRADE := {
	0: {"saturation": 0.85, "paper": Color(0.96, 0.93, 0.86), "gold": 0.15, "edge": 0.0, "vhs": 0.0, "posterize": 0, "ink": 0.0},
	1: {"saturation": 0.15, "paper": Color(0.95, 0.93, 0.85), "gold": 0.0, "edge": 0.6, "vhs": 0.0, "posterize": 4, "ink": 1.0},
	2: {"saturation": 0.70, "paper": Color(0.80, 0.72, 0.62), "gold": 0.0, "edge": 0.2, "vhs": 1.0, "posterize": 0, "ink": 0.0},
	3: {"saturation": 1.0, "paper": Color(0.98, 0.96, 0.93), "gold": 0.0, "edge": 1.0, "vhs": 0.0, "posterize": 6, "ink": 0.2},
	4: {"saturation": 1.15, "paper": Color(0.85, 0.88, 0.92), "gold": 0.1, "edge": 0.8, "vhs": 0.0, "posterize": 0, "ink": 0.0},
	5: {"saturation": 0.35, "paper": Color(0.85, 0.79, 0.61), "gold": 0.0, "edge": 0.5, "vhs": 0.3, "posterize": 5, "ink": 0.4},
	6: {"saturation": 1.1, "paper": Color(0.75, 0.78, 0.88), "gold": 0.0, "edge": 0.4, "vhs": 0.8, "posterize": 4, "ink": 0.3},
	7: {"saturation": 0.6, "paper": Color(0.99, 0.98, 0.95), "gold": 1.0, "edge": 0.3, "vhs": 0.0, "posterize": 0, "ink": 0.0},
	8: {"saturation": 0.9, "paper": Color(1.0, 1.0, 1.0), "gold": 0.6, "edge": 0.3, "vhs": 0.3, "posterize": 0, "ink": 0.0},
	9: {"saturation": 0.0, "paper": Color(1.0, 1.0, 1.0), "gold": 0.1, "edge": 0.0, "vhs": 0.0, "posterize": 0, "ink": 0.0},
}

var current: int = 0
var target: int = 0
var weights := PackedFloat32Array([1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
var _from_weights := PackedFloat32Array()
var _blend_t: float = -1.0
## Extra leak weights for the hub (up to two universes leaking into U0, §2.4).
var leaks: Dictionary = {}


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
	return FPS[clampi(id, 0, FPS.size() - 1)]


func current_fps() -> float:
	return fps_of(current)


func name_of(id: int) -> String:
	return NAMES[clampi(id, 0, NAMES.size() - 1)]


func grade(id: int) -> Dictionary:
	return GRADE.get(id, GRADE[0])


## Quantised time for the current canvas: floor(t × fps) / fps.
func quantised_time(t: float) -> float:
	var f: float = current_fps()
	return floor(t * f) / f


func is_blending() -> bool:
	return _blend_t >= 0.0
