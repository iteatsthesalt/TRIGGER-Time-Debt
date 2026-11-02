## The gold porcelain statues of Combat Laws Bible §5.4 ("Killed while Broken"): a target whose HP reaches 0
## while Broken stands for BROKEN_STATUE_S of battle time, keeping its inflated hull and still terrain (§5.5),
## then shatters (§18.7 check 9). The coordinator starts one on the kill, ticks them with battle time and asks
## whether a dead body still stands as LINE_PIERCE cover; the body's `shatter()` runs when its time is up.
class_name StatueTimers
extends RefCounted

signal shattered(unit: Node)

## unit -> battle seconds it still stands
var left: Dictionary = {}


## The coordinator's hook for every KO: an enemy that died Broken becomes a statue.
func on_defeated(unit: Node, died_broken: bool) -> void:
	if died_broken:
		left[unit] = CombatConstants.BROKEN_STATUE_S


func standing(unit: Node) -> bool:
	return left.has(unit)


func time_left(unit: Node) -> float:
	return float(left.get(unit, 0.0))


func clear() -> void:
	left.clear()


## Advance battle time: a statue whose time is up shatters (the body's `shatter()`, then `shattered`).
func tick(dt: float) -> void:
	for u in left.keys():
		if not is_instance_valid(u):
			left.erase(u)
			continue
		left[u] = float(left[u]) - dt
		if float(left[u]) > 0.0:
			continue
		left.erase(u)
		if u.has_method("shatter"):
			u.call("shatter")
		shattered.emit(u)
