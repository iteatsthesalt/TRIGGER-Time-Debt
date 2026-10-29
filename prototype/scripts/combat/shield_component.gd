## Octopath-style Shield Points + hidden weaknesses, evaluated one strike at a time.
##
## Fixes vs. the original doc:
##  - Evaluated per strike, so a Break on strike 1 makes strike 2 hit at 2.0x
##    (the doc evaluated all hits at once and returned 1.3x for the whole Tech).
##  - Duplicate tags in one attack no longer double-count a weakness.
##  - Bonus shave (MAX Boost) is the caller's choice per strike, not baked into
##    every hit-count multiplication.
class_name ShieldComponent
extends Node

signal shield_changed(current_shields: int, max_shields: int)
signal weakness_revealed(damage_type: int)
signal broken(breaker: Node)
signal break_recovered

const WEAKNESS_DAMAGE_MULT: float = 1.3
const BREAK_DAMAGE_MULT: float = 2.0
## Short labels for HUD plates.
const TYPE_LABELS: PackedStringArray = [
	"SWD", "SPR", "DAG", "AXE", "BOW", "STF", "FIR", "ICE", "LTG", "WND", "LGT", "SHD",
]

@export var max_shields: int = 4
@export var weaknesses: Array[CombatTypes.DamageType] = []

var current_shields: int = -1
var is_broken: bool = false
## DamageType -> true once the player has discovered it.
var revealed: Dictionary = {}


func _ready() -> void:
	if current_shields < 0:
		reset_shields()


func reset_shields() -> void:
	current_shields = max_shields
	is_broken = false


func is_revealed(t: int) -> bool:
	return revealed.get(t, false)


## Number of distinct weaknesses these tags would hit. Never reveals anything.
func count_matching_weaknesses(attack_tags: Array) -> int:
	var seen: Dictionary = {}
	var n: int = 0
	for tag in attack_tags:
		if not seen.has(tag) and tag in weaknesses:
			n += 1
		seen[tag] = true
	return n


## Pure preview of an action (HUD): how many shields it would remove and whether it breaks.
## Mirrors evaluate_strike exactly, including bonus-on-first-weakness-strike and the cap.
func preview_action(attack_tags: Array, strikes: int, bonus_shave: int, shave_cap: int = -1) -> Dictionary:
	if current_shields < 0:
		reset_shields()
	if is_broken:
		return {"shave": 0, "breaks": false, "already_broken": true}
	var matches: int = count_matching_weaknesses(attack_tags)
	if matches == 0:
		return {"shave": 0, "breaks": false, "already_broken": false}
	var left: int = current_shields
	var total: int = 0
	for i in strikes:
		var s: int = matches + (bonus_shave if i == 0 else 0)
		if shave_cap >= 0:
			s = mini(s, shave_cap - total)
		s = mini(s, left)
		total += s
		left -= s
		if left == 0:
			break
	return {"shave": total, "breaks": left == 0, "already_broken": false}


## Evaluates ONE strike that may carry several tags (Dual/Triple Techs).
## shave_cap_left < 0 means unlimited; otherwise at most that many shields come off.
## Returns { damage_multiplier, shields_shaved, hit_weakness, caused_break }.
func evaluate_strike(attack_tags: Array, bonus_shave: int, attacker: Node, shave_cap_left: int = -1) -> Dictionary:
	if current_shields < 0:
		reset_shields()

	var matches: int = _match_and_reveal(attack_tags)
	var result := {
		"damage_multiplier": 1.0,
		"shields_shaved": 0,
		"hit_weakness": matches > 0,
		"caused_break": false,
	}

	if is_broken:
		result["damage_multiplier"] = BREAK_DAMAGE_MULT
		return result

	if matches == 0:
		return result

	var before: int = current_shields
	var shave: int = matches + maxi(0, bonus_shave)
	if shave_cap_left >= 0:
		shave = mini(shave, shave_cap_left)
	current_shields = maxi(0, current_shields - shave)
	result["damage_multiplier"] = WEAKNESS_DAMAGE_MULT
	result["shields_shaved"] = before - current_shields
	shield_changed.emit(current_shields, max_shields)

	if current_shields == 0:
		is_broken = true
		result["caused_break"] = true
		broken.emit(attacker)

	return result


func recover_from_break() -> void:
	if not is_broken:
		return
	is_broken = false
	current_shields = max_shields
	shield_changed.emit(current_shields, max_shields)
	break_recovered.emit()


func _match_and_reveal(attack_tags: Array) -> int:
	var seen: Dictionary = {}
	var matches: int = 0
	for tag in attack_tags:
		if seen.has(tag):
			continue
		seen[tag] = true
		if tag in weaknesses:
			matches += 1
			if not revealed.get(tag, false):
				revealed[tag] = true
				weakness_revealed.emit(tag)
	return matches
