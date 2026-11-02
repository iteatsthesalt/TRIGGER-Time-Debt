## The gate-jump toll (Combat Laws §10.1 and §10.2; Story Bible §9.4 and §9.5): the first traversal of a gate along
## the story thread costs Crono 0.4 integrity (the collarbone, halved while Reinforced) and Sera +5 Translucency Debt.
## Returning to the Atrium hub (U0) and going back through a gate that is already open are free. Opened gates are
## remembered as Flags counters ("gate_opened_u<n>"), so they save and reset with the run. Router.go charges it when
## a location change lands in another universe; a Story `universe` command charges it only with "jump": true, so a
## nightmare or a Chronoslip flash that only swaps the canvas costs nothing.
class_name GateJump
extends RefCounted

const COUNTER_PREFIX := "gate_opened_u"


static func counter_id(universe: int) -> StringName:
	return StringName(COUNTER_PREFIX + str(universe))


static func is_opened(universe: int) -> bool:
	return Flags.counter(counter_id(universe)) > 0


## Charge the jump from one universe to another. `scene` is the location the party stands in (its party_actors
## carry the live components, so Reinforced is honoured); null charges Game directly. Returns true when it cost.
static func charge(from_universe: int, to_universe: int, scene: Node = null) -> bool:
	if to_universe == from_universe or to_universe == 0 or is_opened(to_universe):
		return false
	Flags.add_counter(counter_id(to_universe))
	var crono: Node = _party_actor(scene, &"crono")
	var sera: Node = _party_actor(scene, &"sera")
	var td: TimeDebtComponent = TimeDebtComponent.of(crono)
	if td != null:
		var before: float = td.integrity
		td.on_gate_jump()
		Game.set_integrity(Game.crono_integrity - (before - td.integrity))
	else:
		Game.set_integrity(Game.crono_integrity - CombatConstants.CRONO_JUMP_COLLARBONE)
	var sol: SolidityComponent = SolidityComponent.of(sera)
	if sol != null:
		var before_debt: float = sol.debt
		sol.on_gate_jump()
		Game.set_debt(Game.sera_debt + (sol.debt - before_debt))
	else:
		Game.set_debt(Game.sera_debt + CombatConstants.SERA_DEBT_PER_JUMP)
	for a in [crono, sera]:
		if a != null and a.has_method("set_porcelain_visuals"):
			a.call("set_porcelain_visuals")
	return true


## The scene's party actor with this id (Location keeps them in `party_actors`), or null.
static func _party_actor(scene: Node, id: StringName) -> Node:
	if scene == null:
		return null
	var actors: Variant = scene.get("party_actors")
	if not (actors is Array):
		return null
	for a in actors:
		if not (a is Node):
			continue
		var aid: Variant = (a as Node).get("actor_id")
		var key: String = String(aid) if aid != null else String((a as Node).name)
		if key == String(id):
			return a
	return null
