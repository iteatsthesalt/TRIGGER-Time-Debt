## What the fields on the battle plane do (Combat Laws Bible §7.4, §9.6, §12.5): the timed ticks, the gauge,
## tag, targeting and Break rules the coordinator asks about, and the per-strike effects. BattleFields holds the
## fields; this class only reads and spends them. Floor fields never touch Sera (§10.2 Quantum Flicker, §12.1),
## for good or ill; BattleFields.AIRBORNE lists the fields that are not on the floor.
class_name FieldEffects
extends RefCounted

## Ghost ring (TACHYON Lv4): ally gauges inside fill 1.15×.
const GHOST_RING_FILL := 1.15
## Mercury pool (Ferro Graviton Lv3, §11.5): the next FERRO hit on an enemy inside +20%, then the pool is spent.
const MERCURY_POOL_BONUS := 0.20
## One temporary plate is worth 5% of max HP, so the Divinity cap of 20% of max HP as temporary shield is
## four plates on a shielded body and 20% of max HP of temp shield on an ally (DECISIONS "Divinity Field").
const DIVINITY_PLATE_HP := 0.05


## `u` stands on the floor: Sera never does; neither does a body with the `ignores_floor` meta.
static func grounded(u: Node) -> bool:
	return is_instance_valid(u) and SolidityComponent.of(u) == null and not bool(u.get_meta("ignores_floor", false))


## Field `f` reaches `u`: `u` is inside it and on the floor, unless the field is not a floor field.
static func reaches(c: BattleCoordinator, f: Dictionary, u: Node) -> bool:
	if not c.fields._inside(f, c.position_of(u)):
		return false
	return BattleFields.AIRBORNE.has(f["kind"]) or grounded(u)


## True when a field of `kind` reaches `u`.
static func stands_in(c: BattleCoordinator, u: Node, kind: StringName) -> bool:
	for f in c.fields.fields:
		if f["kind"] == kind and reaches(c, f, u):
			return true
	return false


# ---------------------------------------------------------------- battle-time ticks

static func tick(c: BattleCoordinator, dt: float) -> void:
	c.fields.tick(dt)
	for f in c.fields.fields.duplicate():  # a time mine leaves the list when it blows
		f["accum"] = float(f["accum"]) + dt
		match f["kind"]:
			&"golden_patch":
				if float(f["accum"]) >= 5.0:
					f["accum"] = 0.0
					for u in _living(c, c.party):
						if reaches(c, f, u):
							CombatantStats.of(u).restore_mp(2)
			&"spore_mat":
				if float(f["accum"]) >= 2.0:
					f["accum"] = 0.0
					for u in _living(c, c.party):
						if reaches(c, f, u):
							var st := CombatantStats.of(u)
							st.heal(roundi(float(st.max_hp()) * 0.02))
			&"ash_field":
				if float(f["accum"]) >= 2.0:
					f["accum"] = 0.0
					if int(f.get("owner_team", 0)) == 1:
						EffectFields.ash_on_party(c, f)  # an enemy's Ash (the Daimyo's oil flood) slows the party
					for e in (_living(c, c.enemies) if int(f.get("owner_team", 0)) == 0 else []):
						if reaches(c, f, e):
							var sh := ShieldComponent.of(e)
							if sh != null and sh.temp_plates > 0:
								sh.temp_plates -= 1
							var sc := StatusComponent.of(e)
							if sc != null:
								sc.add(&"ash_field", 2.5)
			&"divinity_field":
				_tick_divinity(c, f, dt)
			&"amber_pool":
				for u in _living(c, c.party):
					if reaches(c, f, u):  # Cassia-09 recharges Mercury Pulse standing in it (§7.4)
						c.cooldowns.recharge_in(u, &"amber_pool", c.tech_library)
				if float(f["accum"]) >= 1.0:
					f["accum"] = 0.0
					for e in _living(c, c.enemies):
						if reaches(c, f, e):
							var sc2 := StatusComponent.of(e)
							if sc2 != null:
								sc2.add(&"mercury_slow", 1.5)
			_:
				EffectFields.tick(c, f, dt)  # canopies, mines, gold folds, enemy oil, healing floors


## +1 temporary plate every 5 s to whoever owns it (capped at 20% of max HP), Ruin thawed 1% per 8 s (§12.5).
static func _tick_divinity(c: BattleCoordinator, f: Dictionary, dt: float) -> void:
	f["thaw_accum"] = float(f.get("thaw_accum", 0.0)) + dt
	var owners: Array = _living(c, c.party if int(f.get("owner_team", 0)) == 0 else c.enemies)
	if float(f["accum"]) >= CombatConstants.DIVINITY_PERIOD_S:
		f["accum"] = 0.0
		for u in owners:
			if reaches(c, f, u):
				_divinity_plate(u)
	if float(f["thaw_accum"]) >= CombatConstants.DIVINITY_THAW_PERIOD_S:
		f["thaw_accum"] = 0.0
		for u in owners:
			if reaches(c, f, u):
				_thaw(f, u)


static func _divinity_plate(u: Node) -> void:
	var st := CombatantStats.of(u)
	var sh := ShieldComponent.of(u)
	if sh != null:
		sh.temp_plates = mini(sh.temp_plates + 1, roundi(CombatConstants.DIVINITY_CAP / DIVINITY_PLATE_HP))
	elif st != null:
		var cap: int = roundi(float(st.max_hp()) * CombatConstants.DIVINITY_CAP)
		st.temp_shield = mini(st.temp_shield + maxi(1, roundi(float(st.max_hp()) * DIVINITY_PLATE_HP)), cap)


## 1% of the ceiling per tick; a whole Ruin stack (15%) thaws once enough has gathered on this field.
static func _thaw(f: Dictionary, u: Node) -> void:
	if RuinRules.stacks(u) <= 0:
		return
	if not f.has("thaw"):
		f["thaw"] = {}
	var acc: Dictionary = f["thaw"]
	acc[u] = float(acc.get(u, 0.0)) + CombatConstants.DIVINITY_RUIN_THAW
	if float(acc[u]) >= CombatConstants.RUIN_STACK - 0.0001:
		acc[u] = 0.0
		RuinRules.thaw(u, 1)


# ---------------------------------------------------------------- queries

## The gauge multiplier the fields give `u` (a ghost ring for a grounded ally).
static func gauge_multiplier(c: BattleCoordinator, u: Node) -> float:
	if not c.party.has(u) or not stands_in(c, u, &"ghost_ring"):
		return 1.0
	return GHOST_RING_FILL


## The tags a party strike from `attacker` carries into `target`: a white blank a NULL Boost left erases them
## all (neutral damage, no shave, no debuff, §7.4); a caustic floor the hit passes over, or Vesper's Rose Window
## on the attacker (§11.7), adds [VITREOUS]. The preview and the resolution both read this, so the plate shows
## what the hit does (§18.7 #23).
static func hit_tags(c: BattleCoordinator, attacker: Node, target: Node, tags: Array) -> Array:
	var to: Vector3 = c.position_of(target)
	for f in c.fields.fields:
		if f["kind"] == &"white_blank" and bool(f.get("strips_tags", false)) and c.fields._inside(f, to):
			return []
	var a_sc := StatusComponent.of(attacker)
	if not tags.has(CombatTags.VITREOUS) and ((a_sc != null and a_sc.has(&"rose_window")) or c.fields.path_crosses(&"caustic_floor", c.position_of(attacker), to)):
		var out: Array = tags.duplicate()
		out.append(CombatTags.VITREOUS)
		return out
	return tags


## A party strike landed on enemy `target`: a confetti pit makes it drop 1 BP (once per enemy, §7.4); a mercury
## pool gives the first FERRO hit +20% and is spent (§11.5). Returns the damage multiplier for this strike.
static func on_party_strike(c: BattleCoordinator, target: Node, tags: Array) -> float:
	var mult: float = 1.0
	for f in c.fields.fields.duplicate():
		if not reaches(c, f, target):
			continue
		match f["kind"]:
			&"confetti_pit":
				if not (f["consumed"] as Dictionary).has(target):
					f["consumed"][target] = true
					c.bank.add(1)
			&"mercury_pool":
				if tags.has(CombatTags.FERRO):
					mult *= 1.0 + MERCURY_POOL_BONUS
					c.fields.fields.erase(f)
	return mult


## Nothing an enemy does makes it untargetable inside a static field (HZ Lv4, §7.4).
static func pins_target(c: BattleCoordinator, u: Node) -> bool:
	return c.enemies.has(u) and c.fields.has_kind_at(&"static_field", c.position_of(u))


## A Divinity Field silences a foe of its owner that Breaks inside it (§12.5): never its own side.
static func silences_on_break(c: BattleCoordinator, unit: Node) -> bool:
	var team: int = 1 if c.enemies.has(unit) else 0
	for f in c.fields.fields:
		if f["kind"] == &"divinity_field" and int(f.get("owner_team", 0)) != team and c.fields._inside(f, c.position_of(unit)):
			return true
	return false


## Crono's first cast from inside a golden watercolour patch or a watercolour puddle costs no Battle Strain
## (§7.4, §9.6): once per field. Returns true when this cast is the free one.
static func free_strain_cast(c: BattleCoordinator, caster: Node) -> bool:
	for f in c.fields.fields:
		if (f["kind"] == &"golden_patch" or f["kind"] == &"watercolour_puddle") and reaches(c, f, caster) and not (f["consumed"] as Dictionary).has(caster):
			f["consumed"][caster] = true
			return true
	return false


static func _living(c: BattleCoordinator, units: Array) -> Array:
	return units.filter(func(u: Node) -> bool: return c.alive(u))
