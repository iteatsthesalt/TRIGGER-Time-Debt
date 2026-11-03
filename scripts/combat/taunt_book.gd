## The taunts on the field (Combat Laws Bible §11: Shogun's Command, Bekkler's Guilt): who draws the enemies'
## attacks, how strongly, and for how many of the bearer's turns. "N turns" counts the bearer's actions after the
## one that cast it, as statuses do (DECISIONS "Turn statuses"): a taunt given while its bearer acts is fresh, and
## that action does not count it down. An entry may also carry
##   ring: a guard ring's radius (Bekkler's Guilt): a hit aimed at another ally standing in it lands on the bearer
##         instead (the coordinator's enemy action), scaled by `taken`, and each one gives +1 BP while `bp` lasts;
##   payoff: a status every ally gains when the taunt runs out with its bearer standing (Shogun's Command's
##         ruin_infused: the next hit ignores DEF, PartyHit).
## A ring of strength 0 draws no attack by itself; `drawing` only names a taunt that does.
class_name TauntBook
extends RefCounted

## bearer -> {turns, strength, fresh, ring?, taken?, bp?, payoff?}
var entries: Dictionary = {}


func clear() -> void:
	entries.clear()


## A taunt on `t` for `turns` of its turns; `fresh` when it is given during `t`'s own action.
func add(t: Node, turns: int, strength: float, fresh: bool, extra: Dictionary = {}) -> void:
	var e := {"turns": turns, "strength": strength, "fresh": fresh}
	e.merge(extra, true)
	entries[t] = e


func has(t: Node) -> bool:
	return entries.has(t)


## The turns left on `t`'s taunt (0 when it has none).
func turns_left(t: Node) -> int:
	return int(entries.get(t, {}).get("turns", 0))


## The first bearer `alive` accepts whose taunt draws attacks (strength above 0, turns left), else null.
func drawing(alive: Callable) -> Node:
	for t in entries.keys():
		var e: Dictionary = entries[t]
		if float(e.get("strength", 0.0)) > 0.0 and int(e["turns"]) > 0 and bool(alive.call(t)):
			return t
	return null


## The share of attacks `t`'s taunt binds (1.0 when `t` has none).
func strength_of(t: Node) -> float:
	if entries.has(t):
		return float(entries[t].get("strength", 0.0))
	return 1.0


## The ring bearer a hit aimed at party member `t` lands on instead: one whose ring holds `t` (the flat distance
## within the ring plus `t`'s body radius), standing and targetable, with turns left; null when none does.
func guard_for(c: BattleCoordinator, t: Node) -> Node:
	if not c.party.has(t):
		return null
	for g in entries.keys():
		var e: Dictionary = entries[g]
		if g == t or float(e.get("ring", 0.0)) <= 0.0 or int(e["turns"]) <= 0 or not c.alive(g) or c.untargetable(g):
			continue
		var d: Vector3 = c.position_of(t) - c.position_of(g)
		var st := CombatantStats.of(t)
		if Vector2(d.x, d.z).length() <= float(e["ring"]) + (st.body_radius if st != null else 0.5):
			return g
	return null


## Where a hit aimed at `t` lands, and at what damage factor: [t, 1.0], or [the ring bearer, its `taken`] when a ring
## holds `t` (the bearer's BP for it paid).
func landing(c: BattleCoordinator, t: Node) -> Array:
	var g: Node = guard_for(c, t)
	if g == null:
		return [t, 1.0]
	return [g, redirect(c, g)]


## A hit has been turned onto ring bearer `g`: +1 BP while the ring's `bp` lasts. Returns the hit's damage factor.
func redirect(c: BattleCoordinator, g: Node) -> float:
	var e: Dictionary = entries[g]
	if int(e.get("bp", 0)) > 0:
		e["bp"] = int(e["bp"]) - 1
		c.bank.add(1)
	return float(e.get("taken", 1.0))


## Bearer `t` finished an action: a fresh taunt starts counting from the next one, an older one counts down.
## Returns the entry that ran out with this action, else {}.
func on_turn_taken(t: Node) -> Dictionary:
	if not entries.has(t):
		return {}
	var e: Dictionary = entries[t]
	if bool(e.get("fresh", false)):
		e["fresh"] = false
		return {}
	e["turns"] = int(e["turns"]) - 1
	if int(e["turns"]) > 0:
		return {}
	entries.erase(t)
	return e
