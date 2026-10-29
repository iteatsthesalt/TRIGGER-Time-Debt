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


## Set a flag to one of its states. Affinity and Beckons are written from the flag definition
## (data/flags/*.json) unless `affinity` overrides them: {light, dark, prismatic}.
func set_flag(id: StringName, s: StringName, affinity: Dictionary = {}) -> void:
	if flags.has(id) and flags[id] == s:
		return
	flags[id] = s
	var def: Dictionary = Data.flag_def(id) if is_instance_valid(Data) else {}
	var write: Dictionary = affinity
	if write.is_empty() and not def.is_empty():
		for st in def.get("states", []):
			if StringName(String(st.get("id", ""))) == s:
				write = st.get("affinity", {})
	_write_affinity(write)
	if bool(def.get("amber_rift", false)) and s == StringName(String(def.get("rift_state", ""))):
		register_amber_rift(id)
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


## Codex leans from enemies resolved their signature way: +1, capped at +5 per affinity per universe.
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


## Which endings currently qualify (Story Bible §7.1). Returns ending numbers in order.
func qualifying_endings() -> Array[int]:
	var out: Array[int] = []
	var kintsugi: int = counter(&"kintsugi_repairs")
	if light >= 90 and dark < 40 and is_state(&"R66Y", &"Rewound") and kintsugi >= 3 and is_state(&"Prologue_Fall", &"Teach_Her_To_Land") and is_state(&"Kami_Ori", &"Wounds_Kept"):
		out.append(1)
	if dark >= 90 and light < 40 and is_state(&"R66Y", &"Salvaged") and is_state(&"Arris_Dome", &"Incinerated") and is_state(&"Azar", &"Predator"):
		out.append(2)
	if prismatic >= 45 and light >= 45 and dark >= 45 and amber_rifts.size() >= 3 and has(&"The_Bowl_Still_Whole") and has(&"Spoon_Taught") and is_state(&"Kami_Ori", &"Paradox_Child") and is_state(&"Vaelos_Father", &"Both"):
		out.append(3)
	if light >= 90 and dark >= 90 and prismatic >= 45 and is_state(&"Sera_Phase", &"Voluntary_40") and counter(&"voluntary_phase_outs") >= 2 \
			and has(&"Native_Duplicate_Given") and is_state(&"Crono_Porcelain", &"Kintsugi_Pris") and is_state(&"Arris_Dome", &"Sleeping") \
			and is_state(&"R66Y", &"Rewound") and has(&"Seed_of_Doan_Grown") and is_state(&"Kami_Ori", &"Wounds_Kept") and has(&"Crono_Entered_Heart_At_20"):
		out.append(4)
	if dark >= 90 and light < 40 and prismatic < 45 and has(&"Porcelain_Stress_Held_100") and not has(&"Bekkler_Confessed") and not has(&"Cassia_Mended_Crono") and has(&"Grief_Embraced") and counter(&"Atrium_Siege") >= 1:
		out.append(5)
	if light >= 60 and dark < 40 and prismatic >= 60 and prismatic <= 75 and is_state(&"Arris_Dome", &"Sleeping") and is_state(&"R66Y", &"Rewound") and is_state(&"Azar", &"Scholar") and is_state(&"Moon", &"Sleep") and has(&"Seed_of_Doan_Full") and has(&"Mycelia_Tether_Mastery"):
		out.append(6)
	if light >= 90 and dark >= 90 and is_state(&"Glenn_Arm", &"HoseArm_Accepted") and has(&"Bekkler_Doll_Repaired") and has(&"Carnival_Completed") and has(&"Laugh_Track_Resisted") and has(&"Thread_Cutting_Mastery"):
		out.append(7)
	if light < 10 and dark == 0 and prismatic < 20 and counter(&"null_mastery") >= 10 and counter(&"kirie_scales") >= 100 and has(&"Seventh_Arm_Defeated") and has(&"Blank_Slate_Used") and has(&"Codex_True_Null"):
		out.append(8)
	return out


func to_save() -> Dictionary:
	var f: Dictionary = {}
	for k in flags.keys():
		f[String(k)] = String(flags[k])
	var rifts: Array = []
	for r in amber_rifts:
		rifts.append(String(r))
	return {"flags": f, "light": light, "dark": dark, "prismatic": prismatic, "beckons": beckons, "amber_rifts": rifts, "leans": leans, "counters": counters, "cycle": cycle, "bias": String(bias)}


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
	leans = d.get("leans", {})
	counters = d.get("counters", {})
	cycle = int(d.get("cycle", 1))
	bias = StringName(String(d.get("bias", "")))
	affinity_changed.emit(light, dark, prismatic)
