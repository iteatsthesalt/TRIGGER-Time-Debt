## Swap (Combat Laws Bible §3.6, §4.2): the acting ally trades itself for a Bench member, or, standing within
## 3 m of a KO'd ally, trades that ally for one. Either way the Swap is the acting ally's one action for the
## window (DECISIONS "A Swap is the window's action"): its turn ends as any command's does (turn count,
## cooldowns, statuses) and the floor passes on. The newcomer arrives at the spot it fills with gauge 50; the
## first Swap of a battle pays +1 BP. Only a field ally swaps: hover Sera lives on the Turn Bar.
class_name SwapRules
extends RefCounted

## A KO'd ally can be swapped out by any ally standing within this many metres of them.
const KO_REACH_M := 3.0


## Trade `actor` for `incoming` from the Bench.
static func swap(c: BattleCoordinator, actor: Node, incoming: Node) -> Dictionary:
	if not c._is_turn(actor):
		return c._fail("not this actor's turn")
	if not c.bench.has(incoming) or not c._alive(incoming):
		return c._fail("not on the bench")
	var idx: int = c.party.find(actor)
	if idx < 0:
		return c._fail("only an ally on the plane can swap out")
	c.state = BattleCoordinator.State.EXECUTING
	c._finish_turn(actor, 0.0)
	_trade(c, idx, actor, incoming)
	c._after_party_action({"kind": "swap", "actor": actor, "out": actor, "in": incoming})
	return {"ok": true}


## Trade the KO'd `koed` for `incoming`, on `actor`'s turn, from within KO_REACH_M.
static func swap_koed(c: BattleCoordinator, actor: Node, koed: Node, incoming: Node) -> Dictionary:
	if not c._is_turn(actor):
		return c._fail("not this actor's turn")
	if not c.party.has(koed) or c._alive(koed) or not c.bench.has(incoming) or not c._alive(incoming):
		return c._fail("invalid swap")
	if c.position_of(actor).distance_to(c.position_of(koed)) > KO_REACH_M:
		return c._fail("too far")
	c.state = BattleCoordinator.State.EXECUTING
	_trade(c, c.party.find(koed), koed, incoming)
	c._finish_turn(actor, 0.0)
	c._after_party_action({"kind": "swap_koed", "actor": actor, "out": koed, "in": incoming})
	return {"ok": true}


static func _trade(c: BattleCoordinator, idx: int, outgoing: Node, incoming: Node) -> void:
	c.party[idx] = incoming
	c.bench.erase(incoming)
	c.bench.append(outgoing)
	c.ready_pool.erase(outgoing)
	c._set_position(incoming, c.position_of(outgoing))
	c._init_unit(incoming, CombatConstants.SWAP_GAUGE)
	if not c.swapped_once:
		c.swapped_once = true
		c.bank.add(1)
