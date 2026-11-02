## The field kinds and field options the effect table and the enemy effects lay (FieldEffects.tick hands every
## field without an arm of its own here): a Saurian canopy (+1 Sunlight Stack to its owner every 5 s; Bloom
## Crown, Reptite Crown), Time Mines (a mine at an enemy's ghost position that blows when the enemy comes back
## to it, or is Rewound there), Origami Requiem's gold fold (thaws Ruin like a Divinity Field), an enemy oil pool
## (Mercury SLOW and Oil-Blight to the party inside) and any field carrying `heal_pct` (Ash Graveyard's caustic
## floor, the canopy's light), which heals the party inside every `heal_period` seconds.
class_name EffectFields
extends RefCounted

const CANOPY_PERIOD_S := 5.0


static func tick(c: BattleCoordinator, f: Dictionary, dt: float) -> void:
	if f.has("heal_pct"):
		f["heal_accum"] = float(f.get("heal_accum", 0.0)) + dt
		if float(f["heal_accum"]) >= float(f.get("heal_period", 2.0)):
			f["heal_accum"] = 0.0
			for u in c.party:
				if c._alive(u) and FieldEffects.reaches(c, f, u):
					EffectSteps.heal_pct(c, null, u, float(f["heal_pct"]))
	match f["kind"]:
		&"canopy":
			f["fx_accum"] = float(f.get("fx_accum", 0.0)) + dt
			if float(f["fx_accum"]) >= CANOPY_PERIOD_S:
				f["fx_accum"] = 0.0
				var owner: Node = c.unit_by_id(StringName(f.get("owner_id", &"xyloph")))
				if owner != null and c._alive(owner):
					owner.set_meta("sunlight", int(owner.get_meta("sunlight", 0)) + 1)
		&"gold_fold":
			f["fx_accum"] = float(f.get("fx_accum", 0.0)) + dt
			if float(f["fx_accum"]) >= CombatConstants.DIVINITY_THAW_PERIOD_S:
				f["fx_accum"] = 0.0
				for u in c.party:
					if c._alive(u) and FieldEffects.reaches(c, f, u):
						FieldEffects._thaw(f, u)
		&"time_mine":
			_tick_mine(c, f)
		&"oil":
			if int(f.get("owner_team", 0)) == 1:
				for u in c.party:
					if c._alive(u) and FieldEffects.reaches(c, f, u):
						StatusRules.apply(c, u, &"mercury_slow", 1.5)
						if not c.oil_blight:
							c.set_oil_blight(true)


## Enemy-owned ground hurts the party (the Daimyo's oil flood, the oil-fire bike's ash): an Ash Field slows the
## party inside (0.5x movement) and chips one temporary plate's worth (5% max HP) of temporary shield per 2 s.
static func ash_on_party(c: BattleCoordinator, f: Dictionary) -> void:
	for u in c.party:
		if not c._alive(u) or not FieldEffects.reaches(c, f, u):
			continue
		var sc := StatusComponent.of(u)
		if sc != null:
			sc.add(&"ash_field", 2.5)
		var st := CombatantStats.of(u)
		if st != null and st.temp_shield > 0:
			st.temp_shield = maxi(0, st.temp_shield - maxi(1, roundi(float(st.max_hp()) * FieldEffects.DIVINITY_PLATE_HP)))


# ---------------------------------------------------------------- Time Mines

## Time Mines (§11.12): up to `count` mines at living enemies' last-turn-start positions (their ghosts), each
## carrying the cast's action so its detonation hits like the technique (2 hits within `radius`).
static func lay_mines(c: BattleCoordinator, action: Dictionary, count: int, radius: float, seconds: float) -> void:
	var laid: int = 0
	for e in c.living_enemies():
		if laid >= count:
			break
		var snap: Dictionary = c.turn_snapshots.get(e, {})
		var at: Vector3 = snap.get("pos", c.position_of(e))
		var f: Dictionary = c.fields.add(&"time_mine", at, radius, seconds, 0)
		f["watch"] = e
		f["armed"] = c.position_of(e).distance_to(at) > radius  # it must leave its spot before it can come back
		var boom: Dictionary = action.duplicate()
		boom["shape"] = {"shape": TechDef.Shape.CIRCLE, "radius": radius, "scale": 1.0}
		boom["primary"] = null
		boom["aim"] = at
		f["action"] = boom
		c.field_added.emit(f)
		laid += 1


static func _tick_mine(c: BattleCoordinator, f: Dictionary) -> void:
	var e: Node = f.get("watch", null)
	if not is_instance_valid(e) or not c._alive(e):
		c.fields.fields.erase(f)
		return
	var inside: bool = c.fields._inside(f, c.position_of(e))
	if not bool(f["armed"]):
		f["armed"] = not inside
		return
	if inside:
		c.fields.fields.erase(f)
		var boom: Dictionary = f["action"]
		if is_instance_valid(boom.get("attacker", null)):
			c._resolve_action(boom)
			c._check_end()
