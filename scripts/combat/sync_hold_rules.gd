## When Sync Hold may be offered and when a parked ally must be woken (Combat Laws Bible §3.4). The
## bible promises that a parked ally "can leave the pool and act alone at any later decision window",
## which presumes a window will come: another ally has to reach the gate. With a lone ally, with every
## other ally already parked, or once the partner is KO'd while one ally waits, no window would ever
## open and the enemies would act until defeat; these rules close that trap at both layers (the deck
## disables the command, the coordinator re-prompts a stranded ally with no new BP).
class_name SyncHoldRules
extends RefCounted


## Whether `actor` may park: another ally must still be able to arrive at the gate.
static func can_hold(c: BattleCoordinator, actor: Node) -> bool:
	return partner_pending(c, actor) != null


## The first ally other than `except` who can still reach the gate: living, not parked, in the party or
## hovering. A phased Sera counts (she returns after two of her turns, §10.2); KO'd allies and the bench
## do not (the bench only arrives through a Swap, which needs a window).
static func partner_pending(c: BattleCoordinator, except: Node) -> Node:
	var pool: Array = c.party.duplicate()
	if c.hover_sera != null and not pool.has(c.hover_sera):
		pool.append(c.hover_sera)
	for u in pool:
		if u == except or c.ready_pool.has(u) or not c._alive(u):
			continue
		return u
	return null


## A parked ally nobody can relieve (null when the pool is empty or a partner is still on the way).
static func stranded(c: BattleCoordinator) -> Node:
	for u in c.ready_pool:
		if c._alive(u) and partner_pending(c, u) == null:
			return u
	return null
