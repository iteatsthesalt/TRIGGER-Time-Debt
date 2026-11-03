## The parry input (Combat Laws Bible §4.2; DECISIONS "Ens Parry is 'armed'"): a press arms the Ens Parry window of
## the guarding allies it covers, and a hit that lands on one while its window is open is a perfect parry
## (EnemyStrike). A press covers the guarding allies an enemy wind-up is aimed at; when no wind-up is aimed at a
## guard (an untelegraphed strike, or a press with no hit due) it covers every guard, and against U1 ink enemies
## a window that closes unmet throws the ink blot (BattleCoordinator._tick_ens_rings). An area wind-up covers every
## guard: any of them may stand in it. A press is spent: the same ally cannot arm again for ENS_PARRY_RECOVER_S of
## battle time, so holding or hammering the key is never a parry. BattleScene owns one per battle.
class_name EnsParry
extends RefCounted

## Battle time (BattleCoordinator.battle_time) from which each ally's next press may arm again.
var _ready_at: Dictionary = {}


## The parry input was pressed: arm the covered guards that are not already armed or still recovering. Returns
## the allies armed by this press.
func press(c: BattleCoordinator) -> Array[Node]:
	var armed: Array[Node] = []
	for ally in covered(c):
		if c.parry_armed.has(ally) or c.battle_time < float(_ready_at.get(ally, -1.0)):
			continue
		c.arm_parry(ally)
		if c.parry_armed.has(ally):
			armed.append(ally)
			_ready_at[ally] = c.battle_time + CombatConstants.ENS_PARRY_RECOVER_S
	return armed


## The living guarding allies a press covers (see the class note).
static func covered(c: BattleCoordinator) -> Array[Node]:
	var guards: Array[Node] = []
	for u in c.party:
		if not is_instance_valid(u):
			continue
		var st := CombatantStats.of(u)
		if st != null and st.is_alive() and st.is_guarding:
			guards.append(u)
	var aimed: Array[Node] = []
	for e in c.wind_ups.keys():
		var action: Dictionary = (c.wind_ups[e] as Dictionary).get("action", {})
		if String(action.get("shape", "SINGLE")) != "SINGLE":
			return guards
		for t in action.get("targets", []):
			if guards.has(t) and not aimed.has(t):
				aimed.append(t as Node)
	return aimed if not aimed.is_empty() else guards
