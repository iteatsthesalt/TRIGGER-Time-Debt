## When Sync Hold may be offered, which ally reaches the gate, and when a parked ally must be woken (Combat Laws
## Bible §3.4). The
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
		if u == except or c.ready_pool.has(u) or not c.alive(u):
			continue
		return u
	return null


## A parked ally nobody can relieve (null when the pool is empty or a partner is still on the way).
static func stranded(c: BattleCoordinator) -> Node:
	for u in c.ready_pool:
		if c.alive(u) and partner_pending(c, u) == null:
			return u
	return null


## The ally whose gauge reached the gate first (the fullest), among the party and a hovering Sera: not parked, not
## phased (her phased turns pass on their own). Null when nobody is at the gate.
static func next_at_gate(c: BattleCoordinator) -> Node:
	var best: Node = null
	var best_g: float = -INF
	var pool: Array = c.party.duplicate()
	if c.hover_sera != null and not c.party.has(c.hover_sera):
		pool.append(c.hover_sera)
	for u in pool:
		if not c.alive(u) or c.ready_pool.has(u):
			continue
		var sol := SolidityComponent.of(u)
		if sol != null and sol.is_phased():
			continue
		var g: float = float(c.gauges.get(u, 0.0))
		if g >= CombatConstants.SYNC_HOLD and g > best_g:
			best_g = g
			best = u
	return best


## Sera's phase-out counts as voluntary while a party gauge has been parked at 99.0 for VOLUNTARY_HOLD_S or more
## (§10.2): every SolidityComponent on the plane or hovering is told so.
static func update_voluntary(c: BattleCoordinator) -> void:
	var any_long_hold: bool = false
	for u in c.ready_pool:
		if float(c.hold_time.get(u, 0.0)) >= CombatConstants.VOLUNTARY_HOLD_S:
			any_long_hold = true
	var bodies: Array = c.party.duplicate()
	if c.hover_sera != null:
		bodies.append(c.hover_sera)
	for u in bodies:
		var sol := SolidityComponent.of(u)
		if sol != null:
			sol.voluntary_window = any_long_hold
