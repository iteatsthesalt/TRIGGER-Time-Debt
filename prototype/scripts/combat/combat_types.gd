## Shared enums for the combat layer.
## Kept in one place so ShieldComponent, TechResource and the coordinator
## don't depend on each other just to name a damage type (avoids cyclic class refs).
class_name CombatTypes
extends RefCounted

enum DamageType {
	SWORD, SPEAR, DAGGER, AXE, BOW, STAFF,
	FIRE, ICE, LIGHTNING, WIND, LIGHT, SHADOW,
}

enum Team { PARTY, ENEMY }

enum BattleState {
	EXPLORATION,
	TRANSITION_IN,
	TIMELINE_TICK,
	COMMAND_WAIT,
	EXECUTING_ACTION,
	VICTORY,
	DEFEAT,
	TRANSITION_OUT,
}


static func damage_type_name(t: int) -> String:
	return DamageType.keys()[t] if t >= 0 and t < DamageType.size() else "?"
