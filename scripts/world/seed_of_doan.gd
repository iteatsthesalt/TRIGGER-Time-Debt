## The Seed of Doan (Story Bible Ch1 beat 7, §5 "watered three times across three visits", §9.3 "Grown (Light +5
## per water) / Ash"). One spelling for its state, read by every consumer (Promise Across Rust, Endings 4 and 6,
## the Bloom Matriarch's mercy plate, the Forge Tendril): the flag Seed_of_Doan, Grown or Ash (data/flags). The
## `seed_waters` counter only counts the waterings toward it. Each watering pays the Grown state's affinity from
## the flag data; the third sets Seed_of_Doan:Grown, which pays the last one. A grown or burned Seed takes no more
## water. (DECISIONS "The Seed of Doan has one state".)
class_name SeedOfDoan
extends RefCounted

const FLAG := &"Seed_of_Doan"
const GROWN := &"Grown"
const ASH := &"Ash"
const COUNTER := &"seed_waters"
const WATERS_TO_GROW := 3


static func waters() -> int:
	return Flags.counter(COUNTER)


static func grown() -> bool:
	return Flags.is_state(FLAG, GROWN)


## It can take water: not yet grown and not burned for fuel.
static func can_water() -> bool:
	return not Flags.has(FLAG)


## One watering; returns the count after it (unchanged when the Seed takes no more water).
static func water() -> int:
	if not can_water():
		return waters()
	Flags.add_counter(COUNTER, 1)
	if waters() >= WATERS_TO_GROW:
		Flags.set_flag(FLAG, GROWN)  # the flag's own affinity is the third water's
	else:
		var a: Dictionary = affinity_per_water()
		Flags.add_affinity(int(a.get("light", 0)), int(a.get("dark", 0)), int(a.get("prismatic", 0)))
	return waters()


## The Grown state's affinity in data/flags, paid once per watering.
static func affinity_per_water() -> Dictionary:
	for st in Data.flag_def(FLAG).get("states", []):
		if StringName(String(st.get("id", ""))) == GROWN:
			return st.get("affinity", {})
	return {}


## The first sprout on the pot's rim: a green thread with a tiny brass gramophone horn (a placeholder until the
## sprout-stage prop of TRI-77 arrives).
static func grow_sprout(parent: Node3D, rim: Vector3) -> void:
	var green := SceneKit.flat_color(Color(0.45, 0.6, 0.3), Color.BLACK, 0.0, 0.9)
	SceneKit.cylinder(parent, 0.04, 0.5, rim + Vector3(0.0, 0.25, 0.0), green, "Sprout", false)
	var brass := SceneKit.flat_color(Color(0.74, 0.56, 0.28), Color.BLACK, 0.0, 0.35, 0.85)
	var horn := SceneKit.cylinder(parent, 0.12, 0.2, rim + Vector3(0.0, 0.55, -0.1), brass, "SproutHorn", false)
	horn.rotation.x = -0.6
