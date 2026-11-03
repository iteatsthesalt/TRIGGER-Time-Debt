## An enemy's BP theft (Combat Laws Bible §7.5): an action's `bp_steal` drains the shared pool into the thief's
## visible counter (its `stolen_bp` mark, BattleMarks), which Glenn's steal takes back first (TechEffects). After a
## Balloon Escape (§11, `theft_immune_once` on the ally who cast it) the next theft against the party this battle
## fails: nothing leaves the pool and the mark is spent.
class_name BpTheft
extends RefCounted

const COUNTER := &"stolen_bp"
const BALLOON := &"theft_immune_once"


## `thief` steals up to `n` BP. Returns what it took.
static func steal(c: BattleCoordinator, thief: Node, n: int) -> int:
	if n <= 0:
		return 0
	for u in c.party + c.bench:
		if is_instance_valid(u) and u.has_meta(BALLOON):
			u.remove_meta(BALLOON)
			c.battle_message.emit("The balloon pops. The theft comes away empty.")
			return 0
	var stolen: int = c.bank.drain(n)
	thief.set_meta(COUNTER, int(thief.get_meta(COUNTER, 0)) + stolen)
	return stolen


## What `thief` holds of the party's BP.
static func held(thief: Node) -> int:
	return int(thief.get_meta(COUNTER, 0)) if is_instance_valid(thief) else 0
