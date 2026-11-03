## Technique cooldowns (data `cooldown_turns`; Cassia-09's Mercury Pulse "recharges after 2 of her turns").
## A cooldown belongs to the caster: it counts that caster's own actions, starting with the next one (the cast
## itself does not count, as with turn statuses), and every caster of a Dual or Triple carries its own. A field
## a technique names as its `recharge_field` (Mercury Pulse: the amber pool, §7.4, §9.6) clears it at once.
class_name TechCooldowns
extends RefCounted

## caster -> {tech_id: turns left}
var _left: Dictionary = {}


func clear() -> void:
	_left.clear()


## `caster` has just cast `tech`: it waits `tech.cooldown_turns` of its own actions.
func start(caster: Node, tech: TechDef) -> void:
	if tech == null or tech.cooldown_turns <= 0:
		return
	if not _left.has(caster):
		_left[caster] = {}
	_left[caster][tech.id] = tech.cooldown_turns


## Turns `caster` still waits before casting `tech_id` again (0 = ready).
func left(caster: Node, tech_id: StringName) -> int:
	return int((_left.get(caster, {}) as Dictionary).get(tech_id, 0))


## `caster` finished an action: its own cooldowns count down by one.
func on_turn_taken(caster: Node) -> void:
	if not _left.has(caster):
		return
	var mine: Dictionary = _left[caster]
	for id in mine.keys():
		mine[id] = int(mine[id]) - 1
		if int(mine[id]) <= 0:
			mine.erase(id)
	if mine.is_empty():
		_left.erase(caster)


## Clear `caster`'s cooldown on every technique in `library` that names `field_kind` as its recharge field.
## Returns how many came back.
func recharge_in(caster: Node, field_kind: StringName, library: Dictionary) -> int:
	if not _left.has(caster):
		return 0
	var n: int = 0
	var mine: Dictionary = _left[caster]
	for id in mine.keys():
		var t: TechDef = library.get(id, null)
		if t != null and t.recharge_field == field_kind:
			mine.erase(id)
			n += 1
	if mine.is_empty():
		_left.erase(caster)
	return n
