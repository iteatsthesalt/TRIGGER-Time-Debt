## What a finished battle leaves on the field (Combat Laws Bible §2.1, §4.2, §16.1, §16.5; DECISIONS
## "Post-battle restore"). One outcome per battle: a victory, a defeat, or a withdraw, which is neither (no
## integrity, no defeat flow). The party stands again (the fallen at 1 HP after a win or a withdraw, at the
## defeat floor after a loss) with their bodies restored, and is written back to Game's roster. The enemies
## settle: the zone that owns them keeps the living at full strength and lets the dead and the spared go,
## and every body no zone owns (story-battle foes, the boss, its adds and summons) is freed, so a retry
## spawns a fresh set instead of stacking a second one. Location calls it once per battle; BattleRoster
## uses the same write-back for the reserves.
class_name BattleAftermath
extends RefCounted

const VICTORY := "victory"
const DEFEAT := "defeat"
const WITHDRAW := "withdraw"
## The HP ratio a fallen member stands up with, by outcome (0 = 1 HP: CombatantStats.revive floors at 1).
## After a defeat the living are raised to the same floor (Sera's jump back, §16.1).
const FLOOR_RATIO := {VICTORY: 0.0, WITHDRAW: 0.0, DEFEAT: 0.3}
## A scripted story loss (the Cradle's retry loop) stands everyone up at half.
const STORY_DEFEAT_RATIO := 0.5


static func outcome(victory: bool, summary: Dictionary) -> String:
	if victory:
		return VICTORY
	return WITHDRAW if String(summary.get("reason", "")) == "withdraw" else DEFEAT


static func floor_ratio(result: String, story: bool) -> float:
	if result == DEFEAT and story:
		return STORY_DEFEAT_RATIO
	return float(FLOOR_RATIO.get(result, 0.0))


## Game holds Crono's integrity and Sera's Translucency Debt between battles (Story commands, the gate toll
## and the field Rewind write it there); the field bodies take it up so the write-back after the next
## battle carries those changes instead of overwriting them with a stale component.
static func sync_from_game(party: Array, integrity: bool = true, debt: bool = true) -> void:
	for a in party:
		if not is_instance_valid(a) or not (a is CombatActor):
			continue
		var ca := a as CombatActor
		if integrity and ca.time_debt != null:
			ca.time_debt.integrity = Game.crono_integrity
		if debt and ca.solidity != null:
			ca.solidity.debt = Game.sera_debt


## Everyone stands again: the fallen get up at `ratio` of max HP (1 HP at 0), the living are raised to it,
## and every body is visible, opaque, untinted and free to walk.
static func restore_party(party: Array, ratio: float) -> void:
	for a in party:
		if not is_instance_valid(a) or not (a is CombatActor):
			continue
		var ca := a as CombatActor
		if not ca.stats.is_alive():
			ca.stats.revive(ratio)
		elif ratio > 0.0:
			ca.stats.hp = maxi(ca.stats.hp, roundi(float(ca.stats.max_hp()) * ratio))
		ca.restore_body()


## Level (Game.set_level), XP and HP ratio into the member's roster row (a guest has one too, Game.set_party),
## Crono's integrity and Sera's Debt into Game. A member still down (a reserve, never stood up) records `ratio`,
## and a living one at least `ratio`, matching what restore_party gives the field party.
static func write_back(a: CombatActor, ratio: float) -> void:
	var row: Dictionary = Game.roster.get(a.actor_id, {})
	Game.set_level(a.actor_id, a.stats.level)  # level-gated kit techs arrive (KitUnlocks)
	row["xp"] = a.stats.xp
	row["hp_ratio"] = maxf(a.stats.hp_ratio(), ratio) if a.stats.is_alive() else ratio
	if a.time_debt != null:
		Game.set_integrity(a.time_debt.integrity)
	if a.solidity != null:
		Game.set_debt(a.solidity.debt)


## An enemy left standing in the field after a battle: back on its feet at full strength, its Break, its
## statuses and its body undone (§16.5: "Enemies return to their wander routes at full strength").
static func restore_enemy(e: CombatActor) -> void:
	e.restore_body()
	e.stats.reset_vitals()
	if e.statuses != null:
		e.statuses.clear_all()
	if e.shield != null:
		e.shield.reset_shields()


## `fought` is every enemy that was on the plane (BattleScene.enemies, adds included), `spared` the ones
## the party spared. Bodies `zone` does not own are freed; the zone settles its own (EncounterZone.settle).
static func settle_enemies(fought: Array, spared: Array, zone: EncounterZone, result: String) -> void:
	for e in fought:
		if is_instance_valid(e) and (zone == null or not zone.enemies.has(e)):
			(e as Node).queue_free()
	if zone != null:
		zone.settle(result, spared)


## After a withdraw the party falls back together: the leader stands where the withdrawing ally reached
## the plane's edge (PartyFollow then snaps the others in behind).
static func regroup(party: Array, at: Variant) -> void:
	if party.is_empty() or not (at is Vector3) or not is_instance_valid(party[0]):
		return
	var leader := party[0] as CombatActor
	leader.global_position = Vector3((at as Vector3).x, leader.global_position.y, (at as Vector3).z)
	leader.reset_physics_interpolation()
