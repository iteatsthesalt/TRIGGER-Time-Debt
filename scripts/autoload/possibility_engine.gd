## The Possibility Engine (Story Bible §9.1–9.3; Combat Laws §7.7, §15.9): flags with exclusive
## states, the three hidden affinities, Beckons, codex leans and Amber Rifts. Autoload name: Flags.
extends Node

signal flag_set(id: StringName, state: StringName)
signal affinity_changed(light: int, dark: int, prismatic: int)
signal amber_rift(source: StringName)
signal beckons_changed(value: int)

var flags: Dictionary = {}        ## id -> state
var light: int = 0
var dark: int = 0
var prismatic: int = 0
var beckons: int = 0
var amber_rifts: Array[StringName] = []
## universe -> {L: n, D: n, P: n} codex leans this universe (capped at +5 each, §13.1)
var leans: Dictionary = {}
var counters: Dictionary = {}     ## numeric story counters (Atrium_Siege, spoon lessons, kirie scales, threads cut)
var cycle: int = 1
var bias: StringName = &""


func reset_cycle(keep_bias: StringName = &"") -> void:
	flags.clear()
	light = 0
	dark = 0
	prismatic = 0
	beckons = 0
	amber_rifts.clear()
	leans.clear()
	counters.clear()
	cycle += 1
	bias = keep_bias
	match keep_bias:
		&"light":
			light = 10
		&"dark":
			dark = 10
		&"prismatic":
			prismatic = 10
	affinity_changed.emit(light, dark, prismatic)


func has(id: StringName) -> bool:
	return flags.has(id)


func state(id: StringName) -> StringName:
	return flags.get(id, &"")


func is_state(id: StringName, s: StringName) -> bool:
	return flags.get(id, &"") == s


## A flag reference holds now: "Name" is set (any state) or "Name:State" is in that state (FlagRef).
func holds(ref: String) -> bool:
	var p: PackedStringArray = FlagRef.split(ref)
	if p[0] == "" or ref.contains("="):
		return false
	return is_state(StringName(p[0]), StringName(p[1])) if p[1] != "" else has(StringName(p[0]))


## Set a flag to one of its states. Affinity and Beckons are written from the flag definition
## (data/flags/*.json) unless `affinity` overrides them: {light, dark, prismatic}.
## A defined flag is permanent for the cycle (Story Bible §9.2): once set, a different state is refused with a
## warning unless its definition says `"mutable": true` (the Seed burns, the Ribbon is lost, Glenn's Duals come
## back). Script-local flags (no definition) are free. An Amber Rift flag reaching its `rift_state` registers the
## rift (once per source: its `rift_source`, else the flag) and the rift is its only Prismatic writer, +15 by any
## route (§9.1, Combat Laws §15.9): the override's or the state's Prismatic is not paid on top.
func set_flag(id: StringName, s: StringName, affinity: Dictionary = {}) -> void:
	if flags.has(id) and flags[id] == s:
		return
	var def: Dictionary = Data.flag_def(id) if is_instance_valid(Data) else {}
	if flags.has(id) and not def.is_empty() and not bool(def.get("mutable", false)):
		push_warning("Flags: %s is already %s this cycle; %s refused (flags are permanent, Story Bible 9.2)" % [id, flags[id], s])
		return
	flags[id] = s
	var write: Dictionary = affinity
	if write.is_empty() and not def.is_empty():
		for st in def.get("states", []):
			if StringName(String(st.get("id", ""))) == s:
				write = st.get("affinity", {})
	var rift: bool = bool(def.get("amber_rift", false)) and s == StringName(String(def.get("rift_state", "")))
	if rift and write.has("prismatic"):
		write = write.duplicate()
		write.erase("prismatic")
	_write_affinity(write)
	if rift:
		register_amber_rift(StringName(String(def.get("rift_source", id))))
	flag_set.emit(id, s)


func _write_affinity(write: Dictionary) -> void:
	if write.is_empty():
		return
	var l: int = int(write.get("light", 0))
	var d: int = int(write.get("dark", 0))
	var p: int = int(write.get("prismatic", 0))
	light = maxi(0, light + l)
	dark = maxi(0, dark + d)
	prismatic = maxi(0, prismatic + p)
	var earned: int = maxi(0, l) + maxi(0, d) + maxi(0, p)
	if earned > 0:
		beckons += earned
		beckons_changed.emit(beckons)
	affinity_changed.emit(light, dark, prismatic)


func add_affinity(l: int, d: int, p: int) -> void:
	_write_affinity({"light": l, "dark": d, "prismatic": p})


## An intentional causality break (§9.1): +15 Prismatic, once per source.
func register_amber_rift(source: StringName) -> bool:
	if amber_rifts.has(source):
		return false
	amber_rifts.append(source)
	_write_affinity({"prismatic": CombatConstants.AFF_RIFT})
	amber_rift.emit(source)
	return true


## Codex leans from enemies resolved their signature way: +1, capped at +5 per affinity per universe (§15.9).
## A lean is earned in battle, so it grants no Beckons (§7.7: Beckons come from story choices, never from
## battle; DECISIONS "Codex leans grant no Beckons"). Keys are int universes, also after a load (from_save).
func add_lean(universe: int, kind: String) -> void:
	if not leans.has(universe):
		leans[universe] = {"L": 0, "D": 0, "P": 0}
	var u: Dictionary = leans[universe]
	if int(u.get(kind, 0)) >= CombatConstants.AFF_LEAN_CAP_PER_UNIVERSE:
		return
	u[kind] = int(u.get(kind, 0)) + 1
	match kind:
		"L":
			light += 1
		"D":
			dark += 1
		"P":
			prismatic += 1
	affinity_changed.emit(light, dark, prismatic)


func spend_beckons(n: int) -> bool:
	if n > beckons:
		return false
	beckons -= n
	beckons_changed.emit(beckons)
	return true


func counter(id: StringName) -> int:
	return int(counters.get(id, 0))


func add_counter(id: StringName, n: int = 1) -> int:
	counters[id] = int(counters.get(id, 0)) + n
	return int(counters[id])


func dominant_affinity() -> StringName:
	if light >= dark and light >= prismatic:
		return &"light"
	if dark >= prismatic:
		return &"dark"
	return &"prismatic"


## Which endings currently qualify (Story Bible §7.1): the table in data/endings/endings.json (EndingRules).
## Returns ending numbers in order.
func qualifying_endings() -> Array[int]:
	return EndingRules.qualifying(Data.endings if is_instance_valid(Data) else [])


func to_save() -> Dictionary:
	var f: Dictionary = {}
	for k in flags.keys():
		f[String(k)] = String(flags[k])
	var rifts: Array = []
	for r in amber_rifts:
		rifts.append(String(r))
	var ln: Dictionary = {}
	for u in leans.keys():
		ln[str(u)] = (leans[u] as Dictionary).duplicate()
	var cn: Dictionary = {}
	for c in counters.keys():
		cn[String(c)] = int(counters[c])
	return {"flags": f, "light": light, "dark": dark, "prismatic": prismatic, "beckons": beckons, "amber_rifts": rifts, "leans": ln, "counters": cn, "cycle": cycle, "bias": String(bias)}


func from_save(d: Dictionary) -> void:
	flags.clear()
	for k in d.get("flags", {}).keys():
		flags[StringName(k)] = StringName(String(d["flags"][k]))
	light = int(d.get("light", 0))
	dark = int(d.get("dark", 0))
	prismatic = int(d.get("prismatic", 0))
	beckons = int(d.get("beckons", 0))
	amber_rifts.clear()
	for r in d.get("amber_rifts", []):
		amber_rifts.append(StringName(String(r)))
	# JSON gives every key back as a String: leans are keyed by int universe (add_lean) and counters by
	# StringName, so a reload neither reopens a universe's +5 lean cap nor keeps two records per universe.
	leans.clear()
	var ld: Dictionary = d.get("leans", {})
	for u2 in ld.keys():
		var row: Dictionary = ld[u2] if ld[u2] is Dictionary else {}
		var lean: Dictionary = leans.get(int(u2), {"L": 0, "D": 0, "P": 0})
		for kind in ["L", "D", "P"]:
			lean[kind] = maxi(int(lean[kind]), int(row.get(kind, 0)))
		leans[int(u2)] = lean
	counters.clear()
	var cd: Dictionary = d.get("counters", {})
	for c2 in cd.keys():
		counters[StringName(String(c2))] = int(cd[c2])
	cycle = int(d.get("cycle", 1))
	bias = StringName(String(d.get("bias", "")))
	affinity_changed.emit(light, dark, prismatic)
