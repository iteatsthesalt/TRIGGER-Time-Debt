## The cap upgrades of Combat Laws Bible §7.6 and §15.7: the Boost cap, the spend cap, the Ens Parry window and
## HOLD's step. A flag state earns one by naming it under "upgrade" in data/flags (Krona_Joined set:
## parry_taught; Goyama Repainted: parry_dojo; Central_Eye Broken: hold_step). Game applies them whenever a flag
## is set; the values live in the save and an upgrade is never taken back. max_bp (the five Memory Shards,
## U2-U6) and max_spend (the first Vaelos rift closed, after U4) are ready for the flags those chapters write.
class_name CapUpgrades
extends RefCounted

## upgrade id -> the Game fields it raises (ints rise to at least the value; bools turn on).
const UPGRADES := {
	"max_bp": {"max_bp": CombatConstants.MAX_BP_UPGRADED},
	"max_spend": {"max_spend": CombatConstants.MAX_SPEND_UPGRADED},
	"parry_taught": {"parry_frames": CombatConstants.ENS_PARRY_FRAMES_TAUGHT},
	"parry_dojo": {"parry_frames": CombatConstants.ENS_PARRY_FRAMES_DOJO},
	"hold_step": {"hold_upgraded": true},
}


## The upgrade a flag definition's `state` earns, or "".
static func upgrade_of(flag_def: Dictionary, state: StringName) -> String:
	for st in flag_def.get("states", []):
		if StringName(String(st.get("id", ""))) == state:
			return String(st.get("upgrade", ""))
	return ""


## Raise `game`'s caps for every upgrade the flags in `flag_states` (id -> state) earn. `defs` maps a flag id to
## its definition (default: Data.flag_def). Returns the upgrade ids that changed something.
static func apply(game: Object, flag_states: Dictionary, defs: Callable = Callable()) -> Array[String]:
	var out: Array[String] = []
	for id in flag_states.keys():
		var def: Dictionary = defs.call(StringName(String(id))) if defs.is_valid() else Data.flag_def(StringName(String(id)))
		var up: String = upgrade_of(def, StringName(String(flag_states[id])))
		if up == "":
			continue
		if not UPGRADES.has(up):
			push_warning("CapUpgrades: flag %s names an unknown upgrade %s" % [id, up])
			continue
		if _grant(game, UPGRADES[up]):
			out.append(up)
	return out


static func _grant(game: Object, fields: Dictionary) -> bool:
	var changed: bool = false
	for key in fields.keys():
		var want: Variant = fields[key]
		var have: Variant = game.get(key)
		if want is bool:
			if not bool(have) and bool(want):
				game.set(key, true)
				changed = true
		elif int(have) < int(want):
			game.set(key, int(want))
			changed = true
	return changed
