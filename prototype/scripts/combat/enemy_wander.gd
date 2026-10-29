class_name EnemyWander
extends Node
## Moves enemies between the battle's wander points while their gauges fill.
## Listens to the coordinator's enemy_drift_requested, which already skips broken
## enemies and pauses while anyone waits at the Action Gate. Each enemy claims one
## point at a time so two enemies never head for the same spot.

@export var coordinator: HybridBattleCoordinator
## Metres per second while drifting (slower than walking: it reads as circling).
@export var drift_speed: float = 1.2
## Close enough to a point to pick the next one.
@export var arrive_distance: float = 0.1

## enemy -> index into coordinator.arena_wander_points
var claims: Dictionary = {}


func _ready() -> void:
	if coordinator:
		coordinator.enemy_drift_requested.connect(drift)
		coordinator.combat_started.connect(func(_c): claims.clear())
		coordinator.combat_ended.connect(func(_v): claims.clear())


func drift(enemy: Node3D, delta: float) -> void:
	var points: Array[Vector3] = coordinator.arena_wander_points if coordinator else []
	if points.is_empty() or not is_instance_valid(enemy) or enemy.get("frozen"):
		return
	if not claims.has(enemy):
		var first := _free_point_nearest(enemy.global_position, points, -1)
		if first < 0:
			return
		claims[enemy] = first
	var goal: Vector3 = points[claims[enemy]]
	var to := goal - enemy.global_position
	to.y = 0.0
	if to.length() <= arrive_distance:
		var next := _free_point_nearest(enemy.global_position, points, claims[enemy])
		if next >= 0:
			claims[enemy] = next
		return
	var step := to.normalized() * minf(drift_speed * delta, to.length())
	enemy.global_position += step
	var sprite = enemy.get("sprite")
	if sprite:
		sprite.update_from_velocity(step / maxf(delta, 0.0001))


## Index of the nearest point no other enemy has claimed, never `exclude`; -1 if none.
func _free_point_nearest(from: Vector3, points: Array[Vector3], exclude: int) -> int:
	var taken := {}
	for e in claims:
		taken[claims[e]] = true
	var best := -1
	var best_d := INF
	for i in points.size():
		if i == exclude or taken.has(i):
			continue
		var d := from.distance_squared_to(points[i])
		if d < best_d:
			best_d = d
			best = i
	return best
