## Sera's hold on a turn (Combat Laws Bible §3.6, §10.2): every unit's state is snapshotted when its turn starts,
## Rewind puts a unit back to it, and Borrowed Future pushes the ally gauges back and lets the ally nearest a full
## gauge repeat its last action exactly (the coordinator keeps turn_snapshots, last_actions, token_duplicate_active).
class_name TurnRewind
extends RefCounted


## Snapshot a unit's state at the start of its turn (for Rewind).
static func snapshot(c: BattleCoordinator, u: Node) -> void:
	var st := CombatantStats.of(u)
	var sc := StatusComponent.of(u)
	c.turn_snapshots[u] = {
		"hp": st.hp if st != null else 0,
		"gauge": float(c.gauges.get(u, 0.0)),
		"pos": c.position_of(u),
		"statuses": sc.ids() if sc != null else [],
		"ruin": RuinRules.stacks(u),
	}


## Restore a unit to its last turn start: HP, gauge, position, statuses gained since (§3.6). Ruin gained since
## thaws through RuinRules (Crono's component and its mirror alike) before the HP, so the ceiling is back first.
static func rewind_unit(c: BattleCoordinator, u: Node, hp_only: bool = false) -> bool:
	if not c.turn_snapshots.has(u):
		return false
	var snap: Dictionary = c.turn_snapshots[u]
	var st := CombatantStats.of(u)
	var sc := StatusComponent.of(u)
	if not hp_only:
		RuinRules.rewind_to(u, int(snap.get("ruin", RuinRules.stacks(u))))
		if sc != null:
			for id in sc.ids():
				if id != &"ruin" and not (snap["statuses"] as Array).has(id):
					sc.remove(id)
	if st != null:
		if st.hp <= 0 and int(snap["hp"]) > 0:
			st.revive(0.01)
			c.unit_revived.emit(u)
		st.hp = clampi(int(snap["hp"]), 0, st.max_hp())
		st.hp_changed.emit(st.hp, st.max_hp())
	if hp_only:
		return true
	if not c.ready_pool.has(u):
		c.gauges[u] = float(snap["gauge"])
	c.move_unit(u, snap["pos"])
	return true


## Every ally gauge −30%, then the ally nearest a full gauge takes a free second turn that copies
## its last action exactly (§3.6, §10.2). Returns the duplicated ally, or null.
static func borrowed_future(c: BattleCoordinator, sera: Node) -> Node:
	var best: Node = null
	var best_g: float = -INF
	for u in c.party:
		if u == sera or not c.alive(u):
			continue
		var g: float = float(c.gauges.get(u, 0.0))
		if g > best_g:
			best_g = g
			best = u
	for u in c.party:
		if u == sera:
			continue
		c.gauges[u] = maxf(0.0, float(c.gauges.get(u, 0.0)) - CombatConstants.GAUGE_MAX * CombatConstants.BORROWED_FUTURE_GAUGE_PUSH)
	if best == null:
		return null
	if c.last_actions.has(best):
		var copy: Dictionary = (c.last_actions[best] as Dictionary).duplicate()
		copy["boost"] = int(copy.get("boost", 0))
		copy["duplicate"] = true
		c.token_duplicate_active = best
		var prev_var: float = c.fixed_variance
		if prev_var <= 0.0:
			c.fixed_variance = 1.0
		StrikeResolution.resolve(c, copy)
		c.fixed_variance = prev_var
		c.token_duplicate_active = null
		c.truth_moment.emit(&"token_duplicate")
	else:
		c.gauges[best] = CombatConstants.SYNC_HOLD
	return best
