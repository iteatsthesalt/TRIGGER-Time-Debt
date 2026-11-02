## Enemy actions with a named `effect` (data/enemies, data/bosses; Combat Laws Bible §12, §13, §14). HANDLED is
## the list lint_data.py and tests/suite_effects.gd check every enemy action effect against (with `summon:<key>`
## and data/effects/effects.json `enemy_pending`). The coordinator calls apply() once the action's hits landed.
class_name EnemyEffects
extends RefCounted

const HANDLED: Array[StringName] = [
	&"bell_slow", &"repaint", &"heal_ally_plates", &"oil_blight", &"time_stop", &"grief", &"fog", &"steal_bp",
	&"spawn_ash_field", &"oil_pool", &"cloak", &"drift_fast", &"split_on_half",
]
const SUMMON_PREFIX := "summon:"
## Cloak (the Porcelain Raptor, the child hiding in the white): untargetable this long, unless a static field
## pins it or a Mercury Pulse lights it up.
const CLOAK_S := 6.0
## Drift-fast bodies (Bike Bros, the Heckler Harlequin) skid this far sideways after every action they take.
const DRIFT_M := 2.5


## True when `effect` names something an enemy action can do (an arm here, a summon, or listed as pending).
static func known(effect: String) -> bool:
	return effect == "" or effect.begins_with(SUMMON_PREFIX) or HANDLED.has(StringName(effect)) \
		or Data.effects.get("enemy_pending", {}).has(effect)


static func apply(c: BattleCoordinator, enemy: Node, action: Dictionary, hit_list: Array) -> void:
	var eff: String = String(action.get("effect", ""))
	if eff.begins_with(SUMMON_PREFIX):
		c.request_summon(StringName(eff.trim_prefix(SUMMON_PREFIX)), int(action.get("count", 2)), enemy)
		return
	if redirect(enemy) == &"decoyed":
		return  # the decoy drew the whole action: its effect lands on nothing either
	match eff:
		"bell_slow":
			for u in c.party:
				StatusRules.apply(c, u, &"slow", 6.0)
		"repaint":
			if not enemy.get_meta("repainted", false):
				enemy.set_meta("repainted", true)
				var sh := ShieldComponent.of(enemy)
				if sh != null and not sh.is_broken:
					sh.current_shield = mini(sh.max_total(), sh.current_shield + 1)
					sh.shield_changed.emit(sh.current_shield, sh.max_total())
		"heal_ally_plates":
			for e in c.living_enemies():
				if e != enemy:
					var sh2 := ShieldComponent.of(e)
					if sh2 != null and not sh2.is_broken:
						sh2.current_shield = mini(sh2.max_total(), sh2.current_shield + int(action.get("plates", 2)))
						sh2.shield_changed.emit(sh2.current_shield, sh2.max_total())
					break
		"oil_blight":
			c.set_oil_blight(true)
		"time_stop":
			for h in hit_list:
				StatusRules.apply(c, h["node"], &"time_stop", 3.0)
		"grief":
			for h in hit_list:
				StatusRules.apply(c, h["node"], &"grief")
		"fog":
			var f: Dictionary = c.fields.add(&"vhs_fog", action.get("aim", c.arena_center), 4.0, 20.0, 1)
			c.field_added.emit(f)
			for h in hit_list:
				StatusRules.apply(c, h["node"], &"blind", 10.0)
		"steal_bp":
			pass  # the action's `bp_steal` drains the pool into the enemy's visible counter (the coordinator, §7.5)
		"spawn_ash_field":
			# The Daimyo's oil flood (BATTLEFIELD: the whole arena), the oil-fire bike's circle: enemy-owned Ash.
			var whole: bool = String(action.get("shape", "")) == "BATTLEFIELD"
			var at: Vector3 = c.arena_center if whole else action.get("aim", c.position_of(enemy))
			var f2: Dictionary = c.fields.add(&"ash_field", at, 40.0 if whole else float(action.get("radius", 3.0)), CombatConstants.RESIDUAL_FIELD_S * 2.0, 1)
			c.field_added.emit(f2)
		"oil_pool":
			# The Mercury Leaker's 3 m pool: Mercury SLOW and Oil-Blight to anyone standing in it (EffectFields).
			var f3: Dictionary = c.fields.add(&"oil", action.get("aim", c.position_of(enemy)), float(action.get("radius", 3.0)), -1.0, 1)
			c.field_added.emit(f3)
		"cloak":
			var sc := StatusComponent.of(enemy)
			if sc != null:
				sc.add(&"cloaked", CLOAK_S)
		"drift_fast":
			drift(c, enemy, hit_list)
		"split_on_half":
			if not enemy.get_meta("split_done", false):
				enemy.set_meta("split_done", true)
				c.request_summon(split_key(enemy, action), int(action.get("count", 2)), enemy)
		_:
			push_warning("EnemyEffects: no handler for %s" % eff)


## A fast drifter skids sideways after acting (§5.5: only a Break pins it for a line-up).
static func drift(c: BattleCoordinator, enemy: Node, hit_list: Array) -> void:
	if c.is_broken(enemy):
		return
	var p: Vector3 = c.position_of(enemy)
	var toward: Vector3 = c.position_of(hit_list[0]["node"]) if not hit_list.is_empty() else c.arena_center
	var side := Vector3(toward.z - p.z, 0.0, p.x - toward.x).normalized()
	if side.length() < 0.01:
		side = Vector3.RIGHT
	c._set_position(enemy, p + side * DRIFT_M * (1.0 if c.rng.randf() < 0.5 else -1.0))


## The bodies a splitter sheds: the action's `summon`, else the first codex key that extends its own
## (vertebray -> vertebray_fawn).
static func split_key(enemy: Node, action: Dictionary) -> StringName:
	if action.has("summon"):
		return StringName(String(action["summon"]))
	var key: String = String(CombatantStats.of(enemy).actor_id)
	var keys: Array = Data.enemies.keys()
	keys.sort()
	for k in keys:
		if String(k).begins_with(key + "_"):
			return k
	return StringName(key)


## The enemy's own statuses that change where its strikes land (EnemyStrike asks before every strike):
## `decoyed` (Ruin Elastic, Guile Elastic's clone: the action is drawn off and lands on nothing) or `mirrored`
## (Masque Feint: the stored attack is reflected onto its maker).
static func redirect(e: Node) -> StringName:
	var sc := StatusComponent.of(e)
	if sc == null:
		return &""
	if sc.has(&"decoyed"):
		return &"decoyed"
	if sc.has(&"mirrored"):
		return &"mirrored"
	return &""
