## Withdraw (Combat Laws Bible §4.1, §4.2, §16.5; DECISIONS "Withdraw"). The ally first falls back toward the
## plane's nearest edge with its move for the window (§4.1: move, then one action), stopping 1 m inside it. In
## the field the plane is laid over the room (§2.1), so the fall-back only lands on ground the party can stand on
## (the coordinator's WalkableGround: inside the map bounds, on floor, clear of solids) and the room's walkable
## edge counts as the plane's edge where it comes first. Standing within 2 m of either edge the ally attempts
## the withdraw: that succeeds when no enemy gauge is above 80 and otherwise costs the turn. A fall-back that
## ends short of an edge costs the turn too, so from the party's opening spots (9.5 m in) a withdraw takes two
## of that ally's turns, and in a small room often one. A success ends the battle as its own outcome (reason
## "withdraw"): no integrity, no defeat flow, the enemies back on their wander routes at full strength
## (BattleAftermath). Never in a boss fight (§4.2), never in a story battle (its script decides how that fight
## ends).
class_name WithdrawRules
extends RefCounted

## The bible's reach: the attempt needs the ally within this many metres of the edge.
const EDGE_M := 2.0
## The fall-back stops this far inside the edge.
const INSET_M := 1.0


static func offered(c: BattleCoordinator) -> bool:
	return not c.is_boss_battle and not c.is_story_battle


## Distance from `p` to the nearest edge of the square plane.
static func edge_distance(c: BattleCoordinator, p: Vector3) -> float:
	var half: float = CombatConstants.PLANE_SIZE * 0.5
	return maxf(0.0, minf(half - absf(p.x - c.arena_center.x), half - absf(p.z - c.arena_center.z)))


## Where a fall-back from `p` aims: straight toward the nearest edge, INSET_M inside it (ties go to the
## near side, +Z, where the party stands).
static func retreat_point(c: BattleCoordinator, p: Vector3) -> Vector3:
	var reach: float = CombatConstants.PLANE_SIZE * 0.5 - INSET_M
	var off: Vector3 = p - c.arena_center
	var to: Vector3 = p
	if absf(off.x) > absf(off.z):
		to.x = c.arena_center.x + (reach if off.x >= 0.0 else -reach)
	else:
		to.z = c.arena_center.z + (reach if off.z >= 0.0 else -reach)
	return to


## Where `actor` at `from` falls back to this window: toward the plane's nearest edge, at most its move range
## (SLOW halves it, §12.2), and in the field only onto standable ground. {to, edge_m}: edge_m is how far past
## `to` the room's walkable ground ends (INF on a bare plane, or when it does not end on the way).
static func fall_back(c: BattleCoordinator, actor: Node, from: Vector3) -> Dictionary:
	var aim: Vector3 = retreat_point(c, from)
	var range_m: float = StatusRules.move_range(actor)
	if c.ground == null:
		var flat := Vector3(aim.x - from.x, 0.0, aim.z - from.z)
		return {"to": from + flat.limit_length(range_m), "edge_m": INF}
	return c.ground.walk(from, aim, range_m)


## The Withdraw command on `actor`'s window. Returns {ok, withdrew, position, reached_edge}; ok is false only
## when the command was not legal (not this actor's turn, a boss or story battle).
static func attempt(c: BattleCoordinator, actor: Node) -> Dictionary:
	if not c.is_turn(actor):
		return c.fail("not this actor's turn")
	if not offered(c):
		return c.fail("cannot withdraw from a boss" if c.is_boss_battle else "this fight cannot be left")
	var from: Vector3 = c.position_of(actor)
	var reached: bool = edge_distance(c, from) <= EDGE_M
	if not reached:
		var plan: Dictionary = fall_back(c, actor, from)
		var to: Vector3 = plan["to"]
		if to.distance_to(from) > 0.01:
			c.cmd_move(actor, to)  # refused when the ally already moved this window (§4.1)
		var stands: Vector3 = c.position_of(actor)
		reached = edge_distance(c, stands) <= EDGE_M or (float(plan["edge_m"]) <= EDGE_M and stands.distance_to(to) <= 0.01)
	var at: Vector3 = c.position_of(actor)
	var who: String = CombatantStats.of(actor).display_name if CombatantStats.of(actor) != null else "The ally"
	var verdict: String = ""
	if not reached:
		verdict = ("%s falls back toward the edge." if at.distance_to(from) > 0.01 else "%s finds no way back from here.") % who
	else:
		for e in c.enemies:
			if c.alive(e) and float(c.gauges.get(e, 0.0)) > CombatConstants.WITHDRAW_MAX_ENEMY_GAUGE:
				verdict = "%s cannot break away: an enemy is about to act." % who
				break
	c.state = BattleCoordinator.State.EXECUTING
	if verdict != "":
		c.battle_message.emit(verdict)
		c.finish_turn(actor, 0.0)
		c.after_party_action({"kind": "withdraw", "ok": false, "actor": actor})
		return {"ok": true, "withdrew": false, "position": at, "reached_edge": reached}
	c.finish(false, "withdraw", {"withdraw_at": at})
	return {"ok": true, "withdrew": true, "position": at, "reached_edge": true}
