## Effective Rank Level (Combat Laws §15.3; DECISIONS "Effective Rank Level"): a regular encounter scales to the
## party when it is laid out (a field zone's spawn, a story battle's foes).
##   ERL = PartyAvg + UniverseBias + HazardOffset
## PartyAvg is the active party's roster levels; UniverseBias is data/universes `bias` of the enemy's universe;
## HazardOffset is the encounter's `hazard` (0-2 by zone), raised by the universe's `hazard_by_flag`
## ({"Azar:Predator": 4} lifts U3's to +4). An enemy fights at ERL + (its authored level - its universe's band
## minimum): the authored level is its rank inside the band, so the codex spread survives and a party at the
## band floor of U0 meets the authored levels. A party under the band minimum meets nothing below band
## minimum - 2 ("never trivialize"). Past band maximum + 5 the encounter is under Time Shear: +15% speed (the
## SLOW immunity and the vignette wait for their systems). Bosses, mini-bosses (any kind but regular and elite)
## and an encounter row with an explicit `level` keep their levels. An add a scaled enemy summons or splits into
## mid-battle (EnemySpawner) is laid out from its summoner's encounter the same way (create_summoned).
class_name EffectiveRank
extends RefCounted

## The encounter terms a body was scaled with ({"hazard": int}), kept on it so its summons scale the same way.
const META_ENCOUNTER := &"rank_encounter"

const SCALED_KINDS: Array[String] = ["regular", "elite"]
const FLOOR_BELOW_BAND := 2
const TIME_SHEAR_MARGIN := 5
const TIME_SHEAR_SPD := 1.15
const MAX_LEVEL := 99


static func party_average(ids: Array) -> float:
	if ids.is_empty():
		return 1.0
	var total: int = 0
	for id in ids:
		total += Game.level_of(StringName(String(id)))
	return float(total) / float(ids.size())


static func band(universe: int) -> Vector2i:
	var b: Array = Data.universe(universe).get("level_band", [1, MAX_LEVEL])
	return Vector2i(int(b[0]), int(b[1])) if b.size() >= 2 else Vector2i(1, MAX_LEVEL)


## The zone's hazard offset, raised by any `hazard_by_flag` entry of the universe whose flag reference holds.
static func hazard(universe: int, base: int) -> int:
	var h: int = base
	var by_flag: Dictionary = Data.universe(universe).get("hazard_by_flag", {})
	for ref in by_flag.keys():
		if Flags.holds(String(ref)):
			h = maxi(h, int(by_flag[ref]))
	return h


static func scales(def: EnemyDef) -> bool:
	return def != null and SCALED_KINDS.has(def.kind)


static func level_for(def: EnemyDef, avg: float, hazard_offset: int = 0) -> int:
	if not scales(def):
		return def.level if def != null else 1
	var b: Vector2i = band(def.universe)
	var erl: int = roundi(avg) + int(Data.universe(def.universe).get("bias", 0)) + hazard_offset
	var lv: int = erl + (def.level - b.x)
	if avg < float(b.x):
		lv = maxi(lv, b.x - FLOOR_BELOW_BAND)
	return clampi(lv, 1, MAX_LEVEL)


static func time_shear(universe: int, avg: float) -> bool:
	return avg > float(band(universe).y + TIME_SHEAR_MARGIN)


## The level an encounter row spawns at: the row's own `level`, else ERL for a scaled kind, else the authored one.
static func spawn_level(def: EnemyDef, row: Variant, enc: Dictionary) -> int:
	if row is Dictionary and int((row as Dictionary).get("level", -1)) > 0:
		return int(row["level"])
	if not scales(def):
		return -1
	return level_for(def, party_average(Game.active_party), hazard(def.universe, int(enc.get("hazard", 0))))


## Create an encounter enemy at its spawn level, under Time Shear when the party has outgrown the universe.
static func create(def: EnemyDef, row: Variant, enc: Dictionary, suffix: String) -> CombatActor:
	var a: CombatActor = CombatActor.create_enemy(def, spawn_level(def, row, enc), suffix)
	if not scales(def) or (row is Dictionary and (row as Dictionary).has("level")):
		return a
	a.set_meta(META_ENCOUNTER, {"hazard": int(enc.get("hazard", 0))})
	if time_shear(def.universe, party_average(Game.active_party)):
		a.stats.spd *= TIME_SHEAR_SPD
		a.set_meta(&"time_shear", true)
	return a


## An add `summoner` calls or splits into mid-battle (EnemySpawner): a scaled kind called by a body this rank
## scaled fights at its own ERL from the summoner's encounter, Time Shear included, so the adds keep step with the
## encounter's own rows. Any other add (a boss's, a mini-boss's, a pinned row's) keeps its authored level.
static func create_summoned(def: EnemyDef, summoner: Node, suffix: String) -> CombatActor:
	if scales(def) and is_instance_valid(summoner) and summoner.has_meta(META_ENCOUNTER):
		return create(def, null, summoner.get_meta(META_ENCOUNTER), suffix)
	return CombatActor.create_enemy(def, -1, suffix)
