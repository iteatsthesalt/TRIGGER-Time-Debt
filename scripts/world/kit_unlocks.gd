## Kit tech unlocks (data/characters/<id>.json `techs[].unlock`; Combat Laws §11, §15.8; DECISIONS "Kit
## unlocks"). Every key of an unlock must hold; an empty unlock holds at once:
## - `chapter`: Game.chapter >= n.            - `on_join`: true (the actor is in the roster).
## - `level`: the actor's roster level >= n.  - `flag`: a flag reference, "Name" or "Name:State" (FlagRef).
## - `light_min` / `dark_min` / `prismatic_min`: the affinity, as a dialogue `if` reads it.
## - `drop`: an enemy key; holds once that enemy's drops have been awarded this cycle (Game.looted).
## - `story`: never by itself; the value names the beat whose chapter script `learn`s the tech.
## Game re-checks the entries that wait on an event when it happens: chapter and recruit check every kind,
## a flag or affinity change the `flag` / `*_min` kinds, a level-up `level`, an awarded drop `drop`.
class_name KitUnlocks
extends RefCounted

const KINDS: Array[String] = ["chapter", "on_join", "level", "flag", "light_min", "dark_min", "prismatic_min", "drop", "story"]
const ON_FLAGS: Array[String] = ["flag", "light_min", "dark_min", "prismatic_min"]
const ON_LEVEL: Array[String] = ["level"]
const ON_DROP: Array[String] = ["drop"]


## The kit's techs as [tech id, unlock] pairs (a bare id string has an empty unlock).
static func entries(kit: Dictionary) -> Array:
	var out: Array = []
	for entry in kit.get("techs", []):
		var tid: String = String(entry.get("id", "")) if entry is Dictionary else String(entry)
		var unlock: Variant = entry.get("unlock", {}) if entry is Dictionary else {}
		out.append([tid, unlock if unlock is Dictionary else {}])
	return out


static func holds(unlock: Dictionary, actor_id: StringName) -> bool:
	for k in unlock.keys():
		var v: Variant = unlock[k]
		match String(k):
			"chapter":
				if Game.chapter < int(v):
					return false
			"on_join":
				pass
			"level":
				if Game.level_of(actor_id) < int(v):
					return false
			"flag":
				if not Flags.holds(String(v)):
					return false
			"light_min":
				if Flags.light < int(v):
					return false
			"dark_min":
				if Flags.dark < int(v):
					return false
			"prismatic_min":
				if Flags.prismatic < int(v):
					return false
			"drop":
				if not Game.looted.has(StringName(String(v))):
					return false
			_:  # "story" and anything unknown wait for a chapter script's `learn`
				return false
	return true


## The unlock waits on one of `kinds` (so an event of that kind should re-check it).
static func waits_on(unlock: Dictionary, kinds: Array[String]) -> bool:
	for k in unlock.keys():
		if kinds.has(String(k)):
			return true
	return false


## Problems with a kit's unlocks: an unknown kind, a non-numeric chapter / level / threshold, a flag
## reference that names no defined flag or state, a drop that names no enemy with drops.
static func validation_errors(kit: Dictionary, flag_defs: Dictionary, enemies: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var who: String = String(kit.get("id", "?"))
	for pair in entries(kit):
		var unlock: Dictionary = pair[1]
		for k in unlock.keys():
			var v: Variant = unlock[k]
			var where: String = "character %s tech %s unlock" % [who, pair[0]]
			match String(k):
				"chapter", "level", "light_min", "dark_min", "prismatic_min":
					if not (v is int or v is float):
						errors.append("%s: %s must be a number" % [where, k])
				"flag":
					var e: String = FlagRef.error(String(v), flag_defs)
					if e != "":
						errors.append("%s: %s" % [where, e])
				"drop":
					var def: Variant = enemies.get(StringName(String(v)), null)
					if def == null or (def is EnemyDef and (def as EnemyDef).drops.is_empty()):
						errors.append("%s: drop %s names no enemy that drops anything" % [where, v])
				"on_join", "story":
					pass
				_:
					errors.append("%s: unknown kind %s (one of %s)" % [where, k, ", ".join(KINDS)])
	return errors
