class_name BattleRewards
extends RefCounted
## Totals a won battle and pays it out: every defeated enemy's XP goes in full to
## each party member still standing (Chrono-style, no split), gold goes to the party.

var xp: int = 0
var gold: int = 0
## actor_id -> levels gained this battle (only members who levelled).
var level_ups: Dictionary = {}
## actor_id -> level after the battle, for every member who received XP.
var new_levels: Dictionary = {}


static func grant(party: Array[Node3D], enemies: Array[Node3D]) -> BattleRewards:
	var r := BattleRewards.new()
	for e in enemies:
		var es := CombatantStats.of(e) if is_instance_valid(e) else null
		if es and not es.is_alive():
			r.xp += es.xp_reward
			r.gold += es.gold_reward
	for p in party:
		var ps := CombatantStats.of(p) if is_instance_valid(p) else null
		if ps == null or not ps.is_alive():
			continue
		var gained := ps.gain_xp(r.xp)
		r.new_levels[ps.actor_id] = ps.level
		if gained > 0:
			r.level_ups[ps.actor_id] = gained
	return r
