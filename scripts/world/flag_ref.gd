## A flag reference as the data writes it, in one spelling everywhere (kit and tech unlocks, a tech's
## `requires_flags`, a boss's `*_by_branch` keys and `requires`, dialogue `set_flag` / `flag` / `not_flag`):
## "Name" (the flag is set, to any state) or "Name:State" (it is in exactly that state). Name and State are a
## flag and one of its states in data/flags (Story Bible §9.3). Flags.holds tests one; lint_data.py and
## Data.load_all reject one that names no defined flag or state (DECISIONS "One flag spelling").
class_name FlagRef
extends RefCounted


## [name, state]; state is "" for the bare form.
static func split(ref: String) -> PackedStringArray:
	var parts: PackedStringArray = ref.strip_edges().split(":", true, 1)
	var state: String = parts[1].strip_edges() if parts.size() > 1 else ""
	return PackedStringArray([parts[0].strip_edges(), state])


## What is wrong with `ref` against the flag definitions (Data.flags: id -> {states: [{id}]}); "" when it is a
## defined flag (and, for "Name:State", one of its states).
static func error(ref: String, defs: Dictionary) -> String:
	if ref.contains("=") or ref.strip_edges() == "":
		return "flag reference \"%s\" is not Name or Name:State" % ref
	var p: PackedStringArray = split(ref)
	var def: Dictionary = defs.get(StringName(p[0]), {})
	if def.is_empty():
		return "flag reference \"%s\" names no flag in data/flags" % ref
	if p[1] == "":
		return ""
	for s in def.get("states", []):
		if String((s as Dictionary).get("id", "")) == p[1]:
			return ""
	return "flag reference \"%s\": %s has no state %s" % [ref, p[0], p[1]]
