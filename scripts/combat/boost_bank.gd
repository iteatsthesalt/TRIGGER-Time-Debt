## The shared party Boost pool (Combat Laws Bible §7.1).
class_name BoostBank
extends RefCounted

signal changed(bp: int, max_bp: int)

var bp: int = CombatConstants.START_BP
var max_bp: int = CombatConstants.MAX_BP
var max_spend: int = CombatConstants.MAX_SPEND
## While true, the gate grants no BP (the Ash Ringmaster's lock).
var gain_locked: bool = false
## Oil-Blight and the blackened Laurel block Ultimates.
var ultimates_blocked: bool = false
## Carnival of Souls may exceed the cap by one until the next ally turn ends.
var overflow_allowance: int = 0
## The revive core owes this many BP (it fires with an empty pool).
var owed: int = 0


func begin_battle() -> void:
	bp = CombatConstants.START_BP
	gain_locked = false
	ultimates_blocked = false
	overflow_allowance = 0
	owed = 0
	changed.emit(bp, max_bp)


func effective_cap() -> int:
	return max_bp + overflow_allowance


## Add BP (gate arrival, swaps, steals). Returns how many were actually added.
func add(n: int, from_gate: bool = false) -> int:
	if n <= 0 or (from_gate and gain_locked):
		return 0
	var paid_debt: int = mini(owed, n)
	owed -= paid_debt
	n -= paid_debt
	var before: int = bp
	bp = mini(effective_cap(), bp + n)
	changed.emit(bp, max_bp)
	return bp - before


func can_spend(n: int) -> bool:
	return n >= 0 and n <= max_spend and n <= bp


func spend(n: int) -> bool:
	if not can_spend(n):
		return false
	bp -= n
	changed.emit(bp, max_bp)
	return true


## Drains (Oil-Blight, thefts). Returns how many were removed.
func drain(n: int) -> int:
	var removed: int = mini(bp, maxi(0, n))
	bp -= removed
	changed.emit(bp, max_bp)
	return removed


## Spend all (The Last Joke, kin-thread cuts). Returns the amount.
func spend_all() -> int:
	var n: int = bp
	bp = 0
	changed.emit(bp, max_bp)
	return n


## The Prometheus Core costs 1 BP when it fires; an empty pool owes the next gain.
func charge_or_owe(n: int) -> void:
	var paid: int = mini(bp, n)
	bp -= paid
	owed += n - paid
	changed.emit(bp, max_bp)


func clamp_overflow() -> void:
	overflow_allowance = 0
	if bp > max_bp:
		bp = max_bp
		changed.emit(bp, max_bp)
