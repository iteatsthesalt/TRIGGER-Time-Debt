## The parry input (Combat Laws Bible §4.2; DECISIONS "Ens Parry is 'armed'"): a press arms the Ens Parry window of
## the guarding allies it covers, and a hit that lands on one while its window is open is a perfect parry
## (EnemyStrike). A press covers the guarding allies an enemy wind-up is aimed at; when no wind-up is aimed at a
## guard (an untelegraphed strike, or a press with no hit due) it covers every guard, and against U1 ink enemies
## a window that closes unmet throws the ink blot (tick). An area wind-up covers every
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
		arm(c, ally)
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


## Arm the Ens Parry for a guarding ally (§4.2): a hit that lands within the window is perfect (EnemyStrike).
static func arm(c: BattleCoordinator, ally: Node) -> void:
	var st := CombatantStats.of(ally)
	if st == null or not st.is_guarding:
		return
	c.parry_armed[ally] = float(c.parry_frames) / 60.0


## The armed parry windows close on battle time (BattleCoordinator.advance); an unmet one in U1 throws the ink blot.
## (An Ens ring has no clock: it lasts until the next damaging hit, §12.3; only Crono's debt-null runs 5 s, in his
## TimeDebtComponent.)
static func tick(c: BattleCoordinator, dt: float) -> void:
	for u in c.parry_armed.keys():
		c.parry_armed[u] = float(c.parry_armed[u]) - dt
		if float(c.parry_armed[u]) <= 0.0:
			c.parry_armed.erase(u)
			var st := CombatantStats.of(u)
			if st != null and c.universe == 1:
				var sc := StatusComponent.of(u)
				if sc != null:
					sc.add(&"ink_blot", 3.0)
			c.parry_result.emit(u, false)
