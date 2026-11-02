## A boss loaded from data/bosses/<id>.json (Combat Laws Bible §14). A boss is one HP pool with ordered
## phases; each phase supplies its own shield configuration, tags, actions and mechanics. phase_def(i)
## builds the EnemyDef the coordinator's brain reads while that phase is active.
##
## A phase is left by HP when the ratio falls to its `hp_to` (and to the next phase's `hp_from`), one window at a
## time, unless it is gated by `advance_on`: GENERIC_GATES are opened by BossController itself, DIRECTOR_GATES only
## by the boss's director (scripts/battle/bosses/<id>.gd calling open_gate / advance_phase). A gated phase may be
## zero-width (R-66Y's Possibility Branch): it is entered when the phase before it is left. An ungated last phase
## whose window ends above 0 ends the fight when it closes (the Krona duel yields at 50%).
## `shield_by_branch` / `hp_from_by_branch` ({"Flag=State": value}) pick a value by the branch already taken.
class_name BossDef
extends RefCounted

## "break": the boss's own Break; "adds_defeated": every add it has is down; "arm_broken": one of its adds
## Breaks (Kami-Ori's arms); "branch": the Possibility Branch was answered (BossBranch).
const GENERIC_GATES: Array[String] = ["break", "adds_defeated", "arm_broken", "branch"]
## Mechanics a director owns (it opens the gate when its mechanic completes).
const DIRECTOR_GATES: Array[String] = ["scripted", "threads_cut", "honest_lines", "sera_voluntary_phase_out", "stand_still_12s", "ending"]

var id: StringName = &""
var display_name: String = ""
var universe: int = 0
var level: int = 1
var hp: int = 1000
var sprite: StringName = &""
var size: float = 2.0
var body_radius: float = 1.0
var fps: float = 60.0
var is_metal: bool = false
var tags: Array[StringName] = []
var resist: Array[StringName] = []
var immune: Array[StringName] = []
var arena_hazards: Array = []
var adds: Array = []
var phases: Array = []
var branches: Array = []
var drops: Array = []
var flags: Dictionary = {}
var notes: String = ""
var raw: Dictionary = {}
## Tests a "Flag=State" pair for the *_by_branch tables (BossController points it at Flags); unset = none holds.
var holds: Callable = Callable()


static func from_dict(d: Dictionary) -> BossDef:
	var b := BossDef.new()
	b.raw = d
	b.id = StringName(String(d.get("id", "")))
	b.display_name = String(d.get("name", b.id))
	b.universe = int(d.get("universe", 0))
	b.level = int(d.get("level", 1))
	b.hp = int(d.get("hp", 1000))
	b.sprite = StringName(String(d.get("sprite", "")))
	b.size = float(d.get("size", 2.0))
	b.body_radius = float(d.get("body_radius", 1.0))
	b.fps = float(d.get("fps", 60.0))
	b.tags = CombatTags.to_names(d.get("tags", []))
	b.resist = CombatTags.to_names(d.get("resist", []))
	b.immune = CombatTags.to_names(d.get("immune", []))
	b.is_metal = bool(d.get("is_metal", b.tags.has(&"FERRO")))
	b.arena_hazards = d.get("arena_hazards", [])
	b.adds = d.get("adds", [])
	b.phases = d.get("phases", [])
	b.branches = d.get("branches", [])
	b.drops = d.get("drops", [])
	b.flags = d.get("flags", {})
	b.notes = String(d.get("notes", ""))
	return b


func phase_count() -> int:
	return phases.size()


func phase(i: int) -> Dictionary:
	if i < 0 or i >= phases.size():
		return {}
	return phases[i]


## The EnemyDef for phase i: boss header merged with the phase's shield, tags and actions.
func phase_def(i: int) -> EnemyDef:
	var p: Dictionary = phase(i)
	var sh: Dictionary = p.get("shield", {})
	var d: Dictionary = {
		"id": String(id), "key": String(id), "name": display_name, "universe": universe, "level": level,
		"kind": String(raw.get("kind", "boss")), "hp": hp, "xp": int(raw.get("xp", 0)), "sprite": String(sprite), "size": size, "body_radius": body_radius, "fps": fps,
		"is_metal": is_metal,
		"tags": p.get("tags", CombatTags.to_names(raw.get("tags", []))),
		"weak": sh.get("weak", []), "resist": sh.get("resist", resist), "nullify": sh.get("nullify", []),
		"immune": sh.get("immune", immune), "absorb": sh.get("absorb", []),
		"shield": int(by_branch(sh.get("shield_by_branch", {}), sh.get("shield", 1))), "keyed_plates": sh.get("keyed_plates", []),
		"actions": p.get("actions", []), "behaviour": p.get("behaviour", {}), "drops": drops,
	}
	var rules: Dictionary = {}
	for k in ["regenerating", "refill_once", "shield_only", "break_condition", "only_hit_by", "shared_owner", "belief", "belief_number", "regen_rate", "lock_seconds", "shared_group"]:
		if sh.has(k):
			rules[k] = sh[k]
	if not rules.is_empty():
		d["plate_rules"] = rules
	return EnemyDef.from_dict(d)


## The phase the boss stands in at `ratio`, walking the windows from `from_index` one at a time and stopping at
## the first gated phase (gates never open by HP). Phases are ordered high to low.
func phase_for_ratio(ratio: float, from_index: int = 0) -> int:
	var i: int = clampi(from_index, 0, maxi(0, phases.size() - 1))
	var n: int = next_phase(i, ratio)
	while n >= 0:
		i = n
		n = next_phase(i, ratio)
	return i


## The phase after `i` when its HP window has closed at `ratio`, or -1. A gated phase is left only once its
## gate is open (`gate_open`); the next phase is entered no earlier than its own `hp_from`.
func next_phase(i: int, ratio: float, gate_open: bool = false) -> int:
	if i < 0 or i + 1 >= phases.size():
		return -1
	if gate(i) != "" and not gate_open:
		return -1
	if ratio > float(phase(i).get("hp_to", 0.0)) or ratio > hp_from(i + 1):
		return -1
	return i + 1


## What gates phase i ("" = its HP window).
func gate(i: int) -> String:
	return String(phase(i).get("advance_on", ""))


## Where phase i's window starts, by the branch already taken when the phase names one.
func hp_from(i: int) -> float:
	var p: Dictionary = phase(i)
	return float(by_branch(p.get("hp_from_by_branch", {}), p.get("hp_from", 1.0)))


## The last phase's window ends above 0 and nothing gates it: the fight ends when it closes.
func ends_at() -> float:
	var last: int = phases.size() - 1
	if last < 0 or gate(last) != "":
		return 0.0
	return float(phase(last).get("hp_to", 0.0))


## {"Flag=State": value}: the value of the first entry whose pair `holds`, else `fallback`.
func by_branch(table: Variant, fallback: Variant) -> Variant:
	if table is Dictionary and holds.is_valid():
		for k in (table as Dictionary).keys():
			if bool(holds.call(String(k))):
				return table[k]
	return fallback


## The director-only gates this boss uses (they stall without scripts/battle/bosses/<id>.gd).
func director_gates() -> PackedStringArray:
	var out := PackedStringArray()
	for i in phases.size():
		if DIRECTOR_GATES.has(gate(i)) and not out.has(gate(i)):
			out.append(gate(i))
	return out


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		errors.append("boss without id")
	if phases.is_empty():
		errors.append("%s: no phases" % id)
	for i in phases.size():
		var e: EnemyDef = phase_def(i)
		for err in e.validation_errors():
			errors.append("%s phase %d: %s" % [id, i, err])
		var g: String = gate(i)
		if g != "" and not GENERIC_GATES.has(g) and not DIRECTOR_GATES.has(g):
			errors.append("%s phase %d: unknown advance_on %s" % [id, i, g])
	return errors
