## A flag reference as the data writes it, in one spelling everywhere (kit and tech unlocks, a tech's
## `requires_flags`, a boss's `*_by_branch` keys, `requires` and branch options, the effect table's `flag` /
## `flag_not` conditions and `flag` op, dialogue `set_flag` / `flag` / `not_flag`): "Name" (the flag is set, to any
## state) or "Name:State" (it is in exactly that state). Name and State are a flag and one of its states in
## data/flags (Story Bible §9.3). Flags.holds tests one and Flags.set_ref writes one (the bare form writes the state
## "set", as dialogue's set_flag does); lint_data.py and Data.load_all reject one that names no defined flag or state
## (DECISIONS "One flag spelling").
class_name FlagRef
extends RefCounted


## [name, state]; state is "" for the bare form.
static func split(ref: String) -> PackedStringArray:
	var parts: PackedStringArray = ref.strip_edges().split(":", true, 1)
	var state: String = parts[1].strip_edges() if parts.size() > 1 else ""
	return PackedStringArray([parts[0].strip_edges(), state])


## [name, state] of `ref` with an explicit `state` (a dialogue command's or a branch option's `state` key) taking
## the place of the one after the colon; "" when neither gives one.
static func with_state(ref: String, state: String) -> PackedStringArray:
	var p: PackedStringArray = split(ref)
	return PackedStringArray([p[0], state.strip_edges() if state.strip_edges() != "" else p[1]])


## The reference a write sets: "Name:State", the bare "Name" written as "Name:set" (dialogue's set_flag rule), so a
## write is validated as exactly the state it writes. "" for an empty name.
static func written(ref: String) -> String:
	var p: PackedStringArray = split(ref)
	if p[0] == "":
		return ""
	return "%s:%s" % [p[0], p[1] if p[1] != "" else "set"]


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
