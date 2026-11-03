## The three stages of a Chronoslip (Reference Bible §2.4): over the 0.8 s blend the paper dissolves first
## (0.0–0.3 s), the grade crossfades (0.2–0.6 s: saturation, inks, posterise, gold, line, VHS) and the canvas
## frame rate snaps to the new canvas at 0.5 s, never passing through the rates in between.
## UniverseSwitcher runs one set of weights per stage; the canvas stack reads all three.
class_name ChronoslipStages
extends RefCounted

const BLEND_S := 0.8
const PAPER_FROM_S := 0.0
const PAPER_TO_S := 0.3
const GRADE_FROM_S := 0.2
const GRADE_TO_S := 0.6
const FPS_SNAP_S := 0.5


## How far each stage is at `t_s` seconds into the blend, 0..1: {paper, grade, fps}. Paper and grade ease in
## and out over their windows; fps is 0 until the snap, then 1.
static func progress(t_s: float) -> Dictionary:
	return {
		"paper": smoothstep(PAPER_FROM_S, PAPER_TO_S, t_s),
		"grade": smoothstep(GRADE_FROM_S, GRADE_TO_S, t_s),
		"fps": 1.0 if t_s >= FPS_SNAP_S else 0.0,
	}


## `from` moved `k` of the way to all-on-`to_id` (ten universe weights).
static func toward(from: PackedFloat32Array, to_id: int, k: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(from.size())
	for i in from.size():
		out[i] = lerpf(from[i], 1.0 if i == to_id else 0.0, clampf(k, 0.0, 1.0))
	return out


## Every weight on universe `id`.
static func only(id: int, n: int = 10) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = 1.0 if i == id else 0.0
	return out


## The universe holding the most weight (the canvas whose rate the frame quantises at).
static func dominant(w: PackedFloat32Array) -> int:
	var best: int = 0
	for i in w.size():
		if w[i] > w[best]:
			best = i
	return best
