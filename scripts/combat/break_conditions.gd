## Break-immune until (Combat Laws Bible §5.7): a body whose plates carry a `break_condition` can be shaved to 0
## but does not Break until the condition holds; the shield then Breaks on its next tick (or at once through
## release()). Conditions: `ferro_in_party` (a living FERRO character in the active party: the Porcelain
## Choir, §13.4 E38) is read live; any other (`springs_cut`, the Prop Chest Mimic's three spring puppets) holds
## once a mechanic calls release() on the body. Re-armed every battle, so a zone survivor starts immune again.
class_name BreakConditions
extends RefCounted

const MET := &"break_condition_met"


static func begin_battle(c: BattleCoordinator) -> void:
	for e in c.enemies:
		arm(c, e)


static func arm(c: BattleCoordinator, e: Node) -> void:
	var sh := ShieldComponent.of(e)
	if sh == null:
		return
	if e.has_meta(MET):
		e.remove_meta(MET)
	sh.break_allowed = sh.break_condition == &""
	# Read live, so a phase that gains a condition mid-fight (ShieldComponent.configure) is covered too.
	sh.break_check = func() -> bool: return is_instance_valid(c) and is_instance_valid(e) and holds(c, e, sh.break_condition)


static func holds(c: BattleCoordinator, e: Node, condition: StringName) -> bool:
	match condition:
		&"":
			return true
		&"ferro_in_party":
			for u in c.party:
				var st := CombatantStats.of(u)
				if c.alive(u) and st != null and String(Data.character(st.actor_id).get("element", "")) == "FERRO":
					return true
			return false
	return bool(e.get_meta(MET, false))


## A mechanic met the body's condition: a shield already at 0 Breaks now.
static func release(e: Node, breaker: Node = null) -> void:
	e.set_meta(MET, true)
	var sh := ShieldComponent.of(e)
	if sh != null:
		sh.try_release_pending_break(breaker)


static func end_battle(c: BattleCoordinator) -> void:
	for e in c.enemies:
		var sh := ShieldComponent.of(e) if is_instance_valid(e) else null
		if sh != null:
			sh.break_check = Callable()
