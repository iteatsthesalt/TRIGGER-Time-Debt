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


## Game holds Crono's integrity, Sera's Translucency Debt and Krona's Corruption between battles (Story commands,
## the gate toll and the field Rewind write the first two there); the field bodies take it up so the write-back
## after the next battle carries those changes instead of overwriting them with a stale component. (Game follows
## Corruption through a battle, follow_ledger, so taking it up is never stale.)
static func sync_from_game(party: Array, integrity: bool = true, debt: bool = true) -> void:
	for a in party:
		if not is_instance_valid(a) or not (a is CombatActor):
			continue
		var ca := a as CombatActor
		if integrity and ca.time_debt != null:
			ca.time_debt.integrity = Game.crono_integrity
		if debt and ca.solidity != null:
			ca.solidity.debt = Game.sera_debt
		if ca.corruption != null:
			ca.corruption.value = Game.krona_corruption


## Game's ledger moved (a Story `debt` or `integrity` command, the gate toll): the party and the cast standing in
## the location take it up, and with `redraw` (in the field) wear it at once (CombatActor.set_porcelain_visuals:
## Sera's thinness and crack, Crono's crack state). In battle the bodies own the ledger and the battle draws them.
static func follow_game(party: Array, cast: Array, integrity: bool, debt: bool, redraw: bool) -> void:
	var bodies: Array = []
	bodies.append_array(party)
	bodies.append_array(cast)
	sync_from_game(bodies, integrity, debt)
	if not redraw:
		return
	for a in bodies:
		if is_instance_valid(a) and a is CombatActor:
			(a as CombatActor).set_porcelain_visuals()


## A battle begins: the bodies take up Game's ledger, and until the write-back Game follows Crono's and Sera's
## components (every in-battle charge or repair lands there first), so a Story write mid-fight (a phase script's
## `integrity: -2`) starts from the live value and the Game-to-body sync it fires loses nothing.
static func enter_battle(party: Array) -> void:
	sync_from_game(party)
	for a in party:
		if is_instance_valid(a) and a is CombatActor:
			follow_ledger(a as CombatActor, true)


## Game follows the body's integrity, Debt and Corruption (on), or stops following it (off, at the write-back).
static func follow_ledger(a: CombatActor, on: bool) -> void:
	if a.time_debt != null:
		_link(a.time_debt.integrity_changed, Game.set_integrity, on)
	if a.solidity != null:
		_link(a.solidity.debt_changed, Game.set_debt, on)
	if a.corruption != null:
		_link(a.corruption.corruption_changed, Game.set_corruption, on)


static func _link(sig: Signal, to: Callable, on: bool) -> void:
	if on and not sig.is_connected(to):
		sig.connect(to)
	elif not on and sig.is_connected(to):
		sig.disconnect(to)


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
## Crono's integrity, Sera's Debt and Krona's Corruption into Game. A member still down (a reserve, never stood up) records `ratio`,
## and a living one at least `ratio`, matching what restore_party gives the field party.
static func write_back(a: CombatActor, ratio: float) -> void:
	follow_ledger(a, false)
	var row: Dictionary = Game.roster.get(a.actor_id, {})
	Game.set_level(a.actor_id, a.stats.level)  # level-gated kit techs arrive (KitUnlocks)
	row["xp"] = a.stats.xp
	row["hp_ratio"] = maxf(a.stats.hp_ratio(), ratio) if a.stats.is_alive() else ratio
	if a.time_debt != null:
		Game.set_integrity(a.time_debt.integrity)
	if a.solidity != null:
		Game.set_debt(a.solidity.debt)
	if a.corruption != null:
		Game.set_corruption(a.corruption.value)


## An enemy left standing in the field after a battle: back on its feet at full strength, its Break, its
## statuses and its body undone (§16.5: "Enemies return to their wander routes at full strength"). The statuses
## go first: an enemy's Ruin lowers its max_hp() (StatusRules.end_battle clears only the party's), so the vitals
## are refilled to the whole ceiling, not to the Ruined one. What held for the battle (a repaint, a split, the BP it
## stole: BattleMarks) goes too.
static func restore_enemy(e: CombatActor) -> void:
	e.restore_body()
	BattleMarks.clear(e)
	RuinRules.clear(e)
	if e.statuses != null:
		e.statuses.clear_all()
	e.stats.reset_vitals()
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


## The party back in the field, standing on ground `ground` says can hold it. After a withdraw the leader stands
## where the withdrawing ally broke away (`at`); after any battle, a leader the ground cannot hold there (or where
## it stands, when there is no `at`) stands where it stood before the battle (`fallback`). Then the followers snap
## in behind (PartyFollow), and one the ground cannot hold there steps back toward the leader (a wall, a ledge or
## the void behind it).
static func regroup(follow: PartyFollow, party: Array, at: Variant, ground: WalkableGround, fallback: Variant) -> void:
	if party.is_empty() or not is_instance_valid(party[0]):
		return
	var leader := party[0] as CombatActor
	var spot: Variant = at
	if ground != null and (at is Vector3 or ground.stand_at(leader.global_position) == null):
		spot = ground.stand_at(at) if at is Vector3 else null
		if spot == null and fallback is Vector3:
			spot = ground.stand_at(fallback)
			spot = fallback if spot == null else spot
	if spot is Vector3:
		leader.global_position = spot
		leader.reset_physics_interpolation()
	if follow != null:
		follow.snap_behind()
	for i in range(1, party.size()):
		var f := party[i] as CombatActor
		if ground == null or not is_instance_valid(f) or ground.stand_at(f.global_position) != null:
			continue
		f.global_position = ground.walk(leader.global_position, f.global_position)["to"]
		f.reset_physics_interpolation()
