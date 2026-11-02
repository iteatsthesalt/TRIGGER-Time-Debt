## The UniverseSwitcher (Reference Bible §2.4): the current canvas, the blend weights, canvas drawing rates
## and the 0.8 s Chronoslip, staged (ChronoslipStages): paper 0.0–0.3 s, grade 0.2–0.6 s, the frame rate
## snapping at 0.5 s. Autoload name: Universe.
extends Node

signal universe_changed(id: int)
## Emitted whenever any stage moves; `weights` is the grade's (paper_weights and fps_weights move with it).
signal weights_changed(weights: PackedFloat32Array)
signal blend_started(from_id: int, to_id: int)

const BLEND_S := ChronoslipStages.BLEND_S
## Canvas drawing rates and names come from data/universes/universes.json (Data.universe, Reference Bible §3.1);
## the grade parameters live in CanvasStackEffect.GRADES (the compositor's one table).
const DEFAULT_FPS := 60.0

var current: int = 0
var target: int = 0
## The grade's weights U0..U9 (LUT, inks, line, VHS): what "which canvas is showing" means.
var weights := PackedFloat32Array([1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
## The paper's weights: they lead the grade (0.0–0.3 s).
var paper_weights := PackedFloat32Array([1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
## The frame rate's weights: all on one universe, switching at the 0.5 s snap.
var fps_weights := PackedFloat32Array([1, 0, 0, 0, 0, 0, 0, 0, 0, 0])
var _from_weights := PackedFloat32Array()
var _from_paper := PackedFloat32Array()
var _from_fps := PackedFloat32Array()
var _blend_s: float = -1.0


func _process(delta: float) -> void:
	advance(delta)


## Move a running Chronoslip on by `delta` seconds (the frame's step; tests call it directly).
func advance(delta: float) -> void:
	if _blend_s < 0.0:
		return
	_blend_s += maxf(delta, 0.0)
	var k: Dictionary = ChronoslipStages.progress(_blend_s)
	paper_weights = ChronoslipStages.toward(_from_paper, target, float(k["paper"]))
	weights = ChronoslipStages.toward(_from_weights, target, float(k["grade"]))
	fps_weights = ChronoslipStages.toward(_from_fps, target, float(k["fps"]))
	weights_changed.emit(weights)
	if _blend_s >= BLEND_S:
		_blend_s = -1.0
		current = target
		universe_changed.emit(current)


func set_universe(id: int, instant: bool = false) -> void:
	id = clampi(id, 0, 9)
	if instant or not is_inside_tree():
		current = id
		target = id
		weights = ChronoslipStages.only(id)
		paper_weights = ChronoslipStages.only(id)
		fps_weights = ChronoslipStages.only(id)
		_blend_s = -1.0
		weights_changed.emit(weights)
		universe_changed.emit(current)
		return
	if id == target:
		return
	blend_started.emit(current, id)
	# A slip that starts mid-slip leaves from wherever each stage stands.
	_from_weights = weights.duplicate()
	_from_paper = paper_weights.duplicate()
	_from_fps = fps_weights.duplicate()
	target = id
	_blend_s = 0.0


func fps_of(id: int) -> float:
	return float(Data.universe(clampi(id, 0, 9)).get("fps", DEFAULT_FPS))


## The canvas rate showing now: the current universe's, or mid-slip whichever side of the 0.5 s snap holds it.
func current_fps() -> float:
	return fps_of(ChronoslipStages.dominant(fps_weights))


func name_of(id: int) -> String:
	var u: int = clampi(id, 0, 9)
	return String(Data.universe(u).get("name", "U%d" % u))


## Quantised time for the current canvas: floor(t × fps) / fps.
func quantised_time(t: float) -> float:
	var f: float = current_fps()
	return floor(t * f) / f
