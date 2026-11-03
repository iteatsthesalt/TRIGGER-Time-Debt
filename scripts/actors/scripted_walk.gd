## One scripted walk to a point (a Story `move`, a cutscene beat, an NPC's wander), shared by CombatActor and
## FieldNPC, with a progress watchdog so an awaited walk always resolves: it ends on arrival, or where the walker
## stands once it has made no headway for STALL_S (a prop or a wall in the way, a frozen body) or has used up
## the time the distance should take plus GRACE_S. The walker calls step() once per physics tick.
class_name ScriptedWalk
extends RefCounted

const ARRIVED := "arrived"
const STALLED := "stalled"
const TIMEOUT := "timeout"
## No headway (the distance left shrinking by at least MIN_PROGRESS_M) for this long ends the walk.
const STALL_S := 0.75
const MIN_PROGRESS_M := 0.01
## Slack on top of distance / speed before a walk that still creeps forward is called off.
const GRACE_S := 2.0

var target: Vector3
var speed: float
var arrive_m: float
## "" while walking, then ARRIVED, STALLED or TIMEOUT.
var result: String = ""
var _best: float = INF
var _since_progress: float = 0.0
var _budget: float = 0.0


func _init(from: Vector3, to: Vector3, walk_speed: float, arrive_within: float) -> void:
	target = to
	speed = maxf(0.1, walk_speed)
	arrive_m = arrive_within
	_best = _flat(to - from).length()
	_budget = _best / speed + GRACE_S


func done() -> bool:
	return result != ""


## The horizontal velocity to walk with from `pos` this tick; ZERO once the walk is over (see result).
func step(pos: Vector3, delta: float) -> Vector3:
	if done():
		return Vector3.ZERO
	var flat: Vector3 = _flat(target - pos)
	var dist: float = flat.length()
	if dist < arrive_m:
		result = ARRIVED
		return Vector3.ZERO
	_budget -= delta
	if dist < _best - MIN_PROGRESS_M:
		_best = dist
		_since_progress = 0.0
	else:
		_since_progress += delta
	if _since_progress >= STALL_S:
		result = STALLED
	elif _budget <= 0.0:
		result = TIMEOUT
	return Vector3.ZERO if done() else flat / dist * speed


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
