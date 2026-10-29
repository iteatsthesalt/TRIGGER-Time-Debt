## Boost Point bank: 0–5 BP stored, 0–3 spent per action, no gain on the
## turn after boosting.
class_name BoostComponent
extends Node

signal bp_changed(current_bp: int, max_bp: int)

const MAX_BP: int = 5
const MAX_SPEND_PER_ACTION: int = 3
const STARTING_BP: int = 1

var current_bp: int = STARTING_BP
var spent_bp_last_turn: bool = false


func begin_battle() -> void:
	current_bp = STARTING_BP
	spent_bp_last_turn = false
	bp_changed.emit(current_bp, MAX_BP)


## Call exactly once when this unit's gauge crosses the Action Gate.
## (The coordinator guards against re-calling it when a held unit is re-prompted.)
func on_turn_start() -> void:
	if not spent_bp_last_turn:
		add_bp(1)
	spent_bp_last_turn = false


func add_bp(amount: int) -> void:
	current_bp = clampi(current_bp + amount, 0, MAX_BP)
	bp_changed.emit(current_bp, MAX_BP)


func can_spend(amount: int) -> bool:
	return amount >= 0 and amount <= MAX_SPEND_PER_ACTION and amount <= current_bp


func commit_spend(amount: int) -> void:
	if amount > 0:
		current_bp = maxi(0, current_bp - amount)
		spent_bp_last_turn = true
		bp_changed.emit(current_bp, MAX_BP)


static func pooled_bp(participants: Array[BoostComponent]) -> int:
	var total: int = 0
	for comp in participants:
		total += comp.current_bp
	return total


## Splits a requested total (0..3) across Dual/Triple Tech participants,
## drawing 1 BP at a time from whoever currently has the most left.
static func allocate_coop_boost(participants: Array[BoostComponent], requested_total_bp: int) -> Dictionary:
	var target_bp: int = clampi(requested_total_bp, 0, MAX_SPEND_PER_ACTION)
	var allocation: Dictionary = {}
	for comp in participants:
		allocation[comp] = 0

	var remaining: int = target_bp
	while remaining > 0:
		var best: BoostComponent = null
		var best_avail: int = 0
		for comp in participants:
			var avail: int = comp.current_bp - int(allocation[comp])
			if avail > best_avail:
				best_avail = avail
				best = comp
		if best == null:
			break
		allocation[best] = int(allocation[best]) + 1
		remaining -= 1

	return {
		"success": remaining == 0,
		"effective_boost_level": target_bp - remaining,
		"allocation": allocation,
	}
