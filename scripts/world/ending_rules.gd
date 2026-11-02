## The endings table (Story Bible §7.1, Combat Laws §15.9) read from data/endings/endings.json. An ending
## qualifies when every bound holds (`light_min` / `light_max`, `dark_*`, `prismatic_*`, inclusive integers: "Dark
## < 40" is dark_max 39), every reference in `flags` holds and none in `not_flags` does (FlagRef spelling: "Name"
## is set, "Name:State" is in that state), every counter in `counters` has reached its minimum, and at least
## `rifts` Amber Rifts are registered. Flags.qualifying_endings reads it; Data.load_all and lint_data.py reject a
## flag reference that names no defined flag or state, so a predicate can never test a flag nothing can set.
class_name EndingRules
extends RefCounted

const AFFINITIES: Array[String] = ["light", "dark", "prismatic"]
const FIELDS: Array[String] = [
	"id", "name", "plays_in", "notes", "flags", "not_flags", "counters", "rifts",
	"light_min", "light_max", "dark_min", "dark_max", "prismatic_min", "prismatic_max",
]


## The ending numbers whose conditions hold now, in table order.
static func qualifying(endings: Array) -> Array[int]:
	var out: Array[int] = []
	for e in endings:
		if e is Dictionary and qualifies(e):
			out.append(int((e as Dictionary).get("id", 0)))
	return out


static func qualifies(e: Dictionary) -> bool:
	var values: Dictionary = {"light": Flags.light, "dark": Flags.dark, "prismatic": Flags.prismatic}
	for a in AFFINITIES:
		if e.has(a + "_min") and int(values[a]) < int(e[a + "_min"]):
			return false
		if e.has(a + "_max") and int(values[a]) > int(e[a + "_max"]):
			return false
	for r in e.get("flags", []):
		if not Flags.holds(String(r)):
			return false
	for r2 in e.get("not_flags", []):
		if Flags.holds(String(r2)):
			return false
	var counters: Dictionary = e.get("counters", {})
	for c in counters.keys():
		if Flags.counter(StringName(String(c))) < int(counters[c]):
			return false
	return Flags.amber_rifts.size() >= int(e.get("rifts", 0))


## What is wrong with the table against the flag definitions (Data.flags); empty when it is sound.
static func validation_errors(endings: Array, defs: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary = {}
	for e in endings:
		if not (e is Dictionary):
			errors.append("endings: an entry is not an object")
			continue
		var d: Dictionary = e
		var where: String = "ending %s" % str(d.get("id", "?"))
		if not (d.get("id") is float or d.get("id") is int) or seen.has(int(d.get("id"))):
			errors.append("%s: id must be a unique number" % where)
		else:
			seen[int(d["id"])] = true
		for k in d.keys():
			if not FIELDS.has(String(k)):
				errors.append("%s: unknown field %s" % [where, k])
		for list_key in ["flags", "not_flags"]:
			for r in d.get(list_key, []):
				var err: String = FlagRef.error(String(r), defs)
				if err != "":
					errors.append("%s: %s" % [where, err])
		if not (d.get("counters", {}) is Dictionary):
			errors.append("%s: counters must be an object of counter -> minimum" % where)
	return errors
