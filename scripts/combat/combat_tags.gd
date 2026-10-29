## Every tag the combat layer knows, as StringNames (Combat Laws Bible §9).
## Elements own exactly three tags each; weapon, world and mode tags are shared.
## `is_known()` is the validation gate: data files may not use a tag that is not listed here.
class_name CombatTags
extends RefCounted

# --- element tag sets (§9.1) ---
const ASTRAL := &"ASTRAL"
const SWORD := &"SWORD"
const TIME_DEBT := &"TIME_DEBT"
const TACHYON := &"TACHYON"
const PIERCING := &"PIERCING"
const PROBABILITY := &"PROBABILITY"
const RUIN := &"RUIN"
const ENTROPY := &"ENTROPY"
const ASH := &"ASH"
const FERRO := &"FERRO"
const RESONANCE := &"RESONANCE"
const MAGNETIC := &"MAGNETIC"
const MYCELIA := &"MYCELIA"
const LIFE := &"LIFE"
const SPORE := &"SPORE"
const VITREOUS := &"VITREOUS"
const REFRACT := &"REFRACT"
const PRISM := &"PRISM"
const GUILE := &"GUILE"
const TRICK := &"TRICK"
const BP_STEAL := &"BP_STEAL"
const HZ := &"HZ"
const SIGNAL := &"SIGNAL"
const WHITE_NOISE := &"WHITE_NOISE"
const NULL := &"NULL"
const NULL_LEARNING := &"NULL_LEARNING"

# --- weapon, world and mode tags (§9.2) ---
const BLUNT := &"BLUNT"
const GUN := &"GUN"
const BOW := &"BOW"
const FIRE := &"FIRE"
const ICE := &"ICE"
const WATER := &"WATER"
const WIND := &"WIND"
const VOLT := &"VOLT"
const LIGHT := &"LIGHT"
const DARK := &"DARK"
const INK := &"INK"
const SOUND := &"SOUND"
const RUBBER := &"RUBBER"
const SMOKE := &"SMOKE"
const SAURIA := &"SAURIA"
const DIVINE := &"DIVINE"
const AURA := &"AURA"
const CARRION := &"CARRION"
const NOISE := &"NOISE"
const REMEMBER := &"REMEMBER"
const PRISMATIC := &"PRISMATIC"

## Every valid tag. Includes the descriptive tags enemies and techs carry (BEAM, PAPER...).
const ALL: Array[StringName] = [
	&"ASTRAL", &"SWORD", &"TIME_DEBT", &"TACHYON", &"PIERCING", &"PROBABILITY",
	&"RUIN", &"ENTROPY", &"ASH", &"FERRO", &"RESONANCE", &"MAGNETIC",
	&"MYCELIA", &"LIFE", &"SPORE", &"VITREOUS", &"REFRACT", &"PRISM",
	&"GUILE", &"TRICK", &"BP_STEAL", &"HZ", &"SIGNAL", &"WHITE_NOISE",
	&"NULL", &"NULL_LEARNING",
	&"BLUNT", &"GUN", &"BOW", &"FIRE", &"ICE", &"WATER", &"WIND", &"VOLT",
	&"LIGHT", &"DARK", &"INK", &"SOUND", &"RUBBER", &"SMOKE", &"SAURIA",
	&"DIVINE", &"AURA", &"CARRION", &"NOISE", &"REMEMBER", &"PRISMATIC",
	# descriptive tags that appear on techs and enemies
	&"BEAM", &"CROSS", &"VOID", &"LAVOS", &"GUILT", &"GUARD", &"ENTOMB", &"SEVER",
	&"FATE", &"COBALT", &"CORE_OVERLOAD", &"CROWN", &"BIO", &"ELASTIC", &"MASQUE",
	&"PARADOX", &"GENESIS", &"DELTA", &"ERASE", &"FOLD", &"TAUNT", &"PAPER", &"OIL",
	&"WARD", &"HEAVY", &"VOICE", &"TICKET", &"STATIC",
	# shape weaknesses (§9.3)
	&"CIRCLE", &"LINE",
]

const ELEMENTS: Array[StringName] = [
	&"ASTRAL", &"TACHYON", &"RUIN", &"FERRO", &"MYCELIA", &"VITREOUS", &"GUILE", &"HZ", &"NULL",
]

## The element each element-tag belongs to.
const ELEMENT_OF := {
	&"ASTRAL": &"ASTRAL", &"SWORD": &"ASTRAL", &"TIME_DEBT": &"ASTRAL",
	&"TACHYON": &"TACHYON", &"PIERCING": &"TACHYON", &"PROBABILITY": &"TACHYON",
	&"RUIN": &"RUIN", &"ENTROPY": &"RUIN", &"ASH": &"RUIN",
	&"FERRO": &"FERRO", &"RESONANCE": &"FERRO", &"MAGNETIC": &"FERRO",
	&"MYCELIA": &"MYCELIA", &"LIFE": &"MYCELIA", &"SPORE": &"MYCELIA",
	&"VITREOUS": &"VITREOUS", &"REFRACT": &"VITREOUS", &"PRISM": &"VITREOUS",
	&"GUILE": &"GUILE", &"TRICK": &"GUILE", &"BP_STEAL": &"GUILE",
	&"HZ": &"HZ", &"SIGNAL": &"HZ", &"WHITE_NOISE": &"HZ",
	&"NULL": &"NULL",
}

## Short labels for shield plates (§5.2).
const SHORT := {
	&"SWORD": "SWD", &"FIRE": "FIR", &"ASTRAL": "AST", &"TACHYON": "TAC", &"FERRO": "FER",
	&"RUIN": "RUI", &"MYCELIA": "MYC", &"VITREOUS": "VIT", &"GUILE": "GUI", &"HZ": "HZ",
	&"NULL": "NUL", &"ICE": "ICE", &"LIGHT": "LGT", &"DARK": "DRK", &"BLUNT": "BLT",
	&"PIERCING": "PRC", &"GUN": "GUN", &"BOW": "BOW", &"WATER": "WTR", &"WIND": "WND",
	&"VOLT": "VLT", &"INK": "INK", &"SOUND": "SND", &"TIME_DEBT": "TDB", &"RUBBER": "RUB",
	&"SMOKE": "SMK", &"SAURIA": "SAU", &"DIVINE": "DIV", &"AURA": "AUR", &"CARRION": "CRN",
	&"SIGNAL": "SIG", &"NOISE": "NSE", &"REMEMBER": "REM", &"PRISMATIC": "PRS",
	&"MAGNETIC": "MAG", &"RESONANCE": "RES", &"SPORE": "SPR", &"LIFE": "LIF",
	&"REFRACT": "RFR", &"PRISM": "PRM", &"TRICK": "TRK", &"BP_STEAL": "BPS",
	&"WHITE_NOISE": "WHN", &"ENTROPY": "ENT", &"ASH": "ASH", &"PROBABILITY": "PRB",
	&"CIRCLE": "CIR", &"LINE": "LIN", &"VOID": "VOI", &"LAVOS": "LAV",
}


static func is_known(tag: StringName) -> bool:
	return ALL.has(tag)


static func short(tag: StringName) -> String:
	return SHORT.get(tag, String(tag).left(3))


static func element_of(tag: StringName) -> StringName:
	return ELEMENT_OF.get(tag, &"")


## Distinct element tags carried by a tag list (for the [PRISMATIC] match, §9.3).
static func count_elements(tags: Array) -> int:
	var seen: Dictionary = {}
	for t in tags:
		var e: StringName = element_of(t)
		if e != &"":
			seen[e] = true
	return seen.size()


static func to_names(tags: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for t in tags:
		out.append(StringName(String(t)))
	return out
