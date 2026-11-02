## The effect-table ops that move bodies, change plates, lay fields or write story state (EffectSteps runs the
## everyday ones). `each` is the op's set after its `if`; ctx is EffectSteps' {c, tech, action, boost, attacker,
## casters, info}. Combat Laws Bible §5.4 (Break extensions), §5.7 (shared plates), §7.4 / §12.5 (fields),
## §10.1 (Crono's integrity and Reinforced), §11 (each technique's text, cited in data/effects/effects.json).
class_name EffectOps
extends RefCounted


static func run(c: BattleCoordinator, name: String, op: Dictionary, ctx: Dictionary, each: Array) -> void:
	match name:
		"field":
			_field(c, op, ctx, each)
		"convert_field":
			var tech: TechDef = ctx["tech"]
			var radius: float = tech.radius * float(ctx["action"]["shape"].get("scale", 1.0))
			for f in c.fields.fields:
				var aim: Vector3 = ctx["action"]["aim"]
				if f["kind"] == StringName(String(op["from"])) and Vector3(f["center"].x - aim.x, 0.0, f["center"].z - aim.z).length() <= radius + float(f["radius"]):
					f["kind"] = StringName(String(op["to"]))
					if op.has("heal_pct"):
						f["heal_pct"] = float(op["heal_pct"])
						f["heal_period"] = float(op.get("period", 2.0))
		"whiteout":
			# Graviton Whiteout (§5.4): no regeneration and no rebuild for `s` seconds.
			for u in each:
				var sh := ShieldComponent.of(u)
				if sh == null:
					continue
				if sh.is_broken:
					sh.extend_lock(float(op["s"]))
				else:
					sh.since_last_shave = minf(sh.since_last_shave, CombatConstants.BREAK_LOCK_S - float(op["s"]))
		"hide_weakness":
			for u in each:
				hide_weakness(c, u, int(op.get("index", 1)), int(op.get("turns", 2)))
		"grant_weakness":
			for u in each:
				var tag: StringName = learned_tag(c, u) if String(op.get("tag", "")) == "learned" else StringName(String(op["tag"]))
				grant_weakness(u, tag, float(op.get("s", -1.0)), int(op.get("turns", -1)))
		"strip_resists":
			for u in each:
				var sh2 := ShieldComponent.of(u)
				if sh2 != null:
					StatusRules.strip_resists(sh2)  # for the rest of the fight: the undo is dropped
				var st := CombatantStats.of(u)
				if st != null:
					st.resistant.clear()
		"steal_buff":
			var to: Node = c.unit_by_id(StringName(String(op.get("to", "glenn"))))
			for u in each:
				var id: StringName = EffectSteps.purge_buff(StatusComponent.of(u))
				if id != &"" and to != null and StatusComponent.of(to) != null:
					StatusComponent.of(to).add(id, -1.0, 2)
		"integrity":
			var crono: Node = c.unit_by_id(&"crono")
			var td := TimeDebtComponent.of(crono)
			var key := StringName("integrity:%s" % ctx["tech"].effect)
			if td != null and not (bool(op.get("once", false)) and EffectTable.used(c, key)):
				td.repair_integrity(float(op.get("n", 0.0)))
				if bool(op.get("once", false)):
					EffectTable.mark_used(c, key)
		"reinforced":
			var td2 := TimeDebtComponent.of(c.unit_by_id(&"crono"))
			if td2 != null:
				td2.reinforced_jumps = maxi(td2.reinforced_jumps, int(op.get("jumps", 3)))
				td2.reinforced_factor = float(op.get("factor", CombatConstants.REINFORCED_REDUCTION))
		"affinity":
			var dark: int = int(op.get("dark", 0))
			if op.has("cap_per_universe"):
				var counter := StringName("%s_dark_u%d" % [String(op.get("key", ctx["tech"].effect)), c.universe])
				dark = mini(dark, maxi(0, int(op["cap_per_universe"]) - Flags.counter(counter)))
				Flags.add_counter(counter, dark)
			Flags.add_affinity(int(op.get("light", 0)), dark, int(op.get("prismatic", 0)))
		"flag":
			var parts: PackedStringArray = String(op["set"]).split(":")
			if parts.size() == 2:
				Flags.set_flag(StringName(parts[0]), StringName(parts[1]))
		"shutdown":
			# Prometheus Overload (§11.5): her next gauge starts at -`gauge`, i.e. that much fill is lost.
			var actor: Node = ctx["attacker"]
			var speed: float = maxf(1.0, CombatantStats.of(actor).gauge_speed())
			StatusComponent.of(actor).add(&"shutdown", float(op.get("gauge", 20.0)) / speed)
		"hurt_allies":
			var me: Node = ctx["attacker"]
			for u in c.party:
				if u != me and c._alive(u) and c.position_of(u).distance_to(c.position_of(me)) <= float(op.get("radius", 2.0)):
					var ust := CombatantStats.of(u)
					var dealt: int = ust.apply_damage(roundi(float(ust.max_hp()) * float(op.get("pct", 0.1))), true)
					c.strike_resolved.emit(me, u, {"damage": dealt, "friendly": true, "tags": []})
		"pull":
			var center: Vector3 = ctx["action"]["aim"]
			for u in each:
				if c.is_broken(u):
					continue  # a Broken body is locked mid-step (§5.4)
				var p: Vector3 = c.position_of(u)
				var to_c := Vector3(center.x - p.x, 0.0, center.z - p.z)
				var step: float = minf(float(op.get("m", 1.0)), maxf(0.0, to_c.length() - 0.5))
				if step > 0.0:
					c._set_position(u, p + to_c.normalized() * step)
		"leap":
			# Mercy Leap: the flung ally lands 1 m behind the last target along the line.
			var who: Node = null
			for u in ctx["casters"]:
				if EffectTable.id_matches(CombatantStats.of(u).actor_id, op.get("who", [])):
					who = u
			var hit: Array = ctx["info"].get("targets", [])
			if who != null and not hit.is_empty():
				var origin: Vector3 = c.position_of(ctx["attacker"])
				var far: Node = hit[0]
				for t in hit:
					if c.position_of(t).distance_to(origin) > c.position_of(far).distance_to(origin):
						far = t
				var dir := Vector3(c.position_of(far).x - origin.x, 0.0, c.position_of(far).z - origin.z).normalized()
				c._set_position(who, c.position_of(far) + dir * 1.0)
		"plates":
			for u in each:
				var sh3 := ShieldComponent.of(u)
				if sh3 != null and not sh3.is_broken and sh3.current_shield > 0:
					# A plate loss never Breaks on its own (as temporary plates, §5.7): at least one plate stays.
					var lose: int = roundi(float(sh3.current_shield) * float(op.get("pct", 0.25)))
					sh3.current_shield = maxi(1, sh3.current_shield - lose)
					sh3.shield_changed.emit(sh3.current_shield, sh3.max_total())
		"unshare":
			unshare(c, each)
		"auto_break":
			_auto_break(c, op, ctx, each)
		"shave_any":
			# Ferro Null "shaves 8 on any target": the action's shave is topped up to `n`, matched or not.
			for u in each:
				var sh4 := ShieldComponent.of(u)
				var done: int = int(ctx["info"].get("shave", {}).get(u, 0))
				if sh4 == null or sh4.is_broken or done >= int(op["n"]):
					continue
				sh4.current_shield = maxi(0, sh4.current_shield - (int(op["n"]) - done))
				sh4.shield_changed.emit(sh4.current_shield, sh4.max_total())
				if sh4.current_shield == 0 and sh4.can_break_now():
					sh4.force_break(ctx["attacker"], ctx["tech"].tags)
					(ctx["info"]["breaks"] as Array).append(u)
		"sever_tethers":
			# Spore Rail cuts the tethers it rides: they release as a heal on the party (§11.12).
			for u in c.party:
				var sc := StatusComponent.of(u)
				if sc != null and sc.has(&"tethered"):
					sc.remove(&"tethered")
				if u.has_meta("tether_nodes"):
					u.remove_meta("tether_nodes")
				EffectSteps.heal_pct(c, ctx["attacker"], u, float(op.get("heal_pct", 0.0)))
		"rift_after":
			# Guile Elastic used `uses` times on one boss without defeating it: an Amber Rift (§11.8).
			for u in each:
				var n: int = int(u.get_meta("uses:%s" % op["source"], 0)) + 1
				u.set_meta("uses:%s" % op["source"], n)
				if n >= int(op.get("uses", 12)) and CombatantStats.of(u).is_alive():
					Flags.register_amber_rift(StringName(String(op["source"])))
		"mines":
			EffectFields.lay_mines(c, ctx["action"], int(op.get("count", 3)), float(op.get("radius", 1.0)), float(op.get("s", 30.0)))
		"rewind_enemies":
			rewind_enemies(c, float(op.get("s", 8.0)))
		_:
			push_warning("EffectOps: unknown op %s" % name)


static func _field(c: BattleCoordinator, op: Dictionary, ctx: Dictionary, each: Array) -> void:
	var tech: TechDef = ctx["tech"]
	var action: Dictionary = ctx["action"]
	var scale: float = float(action["shape"].get("scale", 1.0))
	var kind := StringName(String(op["kind"]))
	var secs: float = float(op.get("s", CombatConstants.RESIDUAL_FIELD_S))
	var made: Array[Dictionary] = []
	match String(op.get("at", "aim")):
		"line":
			var origin: Vector3 = c.position_of(ctx["attacker"])
			var dir := Vector3(action["aim"].x - origin.x, 0.0, action["aim"].z - origin.z)
			if dir.length() < 0.01:
				dir = Vector3.FORWARD
			made.append(c.fields.add_line(kind, origin, dir, maxf(tech.length, 1.0) * scale, tech.width * scale, secs, 0))
		"each":
			for u in each:
				made.append(c.fields.add(kind, c.position_of(u), float(op.get("radius", 2.0)), secs, 0))
		"self":
			made.append(c.fields.add(kind, c.position_of(ctx["attacker"]), float(op.get("radius", tech.radius * scale)), secs, 0))
		_:
			made.append(c.fields.add(kind, action["aim"], float(op.get("radius", tech.radius * scale)), secs, 0))
	for f in made:
		if op.has("heal_pct"):
			f["heal_pct"] = float(op["heal_pct"])
			f["heal_period"] = float(op.get("period", 5.0))
		if op.has("owner_id"):
			f["owner_id"] = StringName(String(op["owner_id"]))
		c.field_added.emit(f)


## White Noise (§11.9): the weakness at `index` reads [?] again for `turns` of the target's turns.
static func hide_weakness(_c: BattleCoordinator, u: Node, index: int, turns: int) -> void:
	var sh := ShieldComponent.of(u)
	var sc := StatusComponent.of(u)
	if sh == null or sc == null or sh.weaknesses.size() <= index or sc.has(&"scrambled"):
		return
	var tag: StringName = sh.weaknesses[index]
	var was: bool = sh.is_revealed(tag)
	sh.revealed[tag] = false
	var serial: int = sh.config_serial
	var undo := func() -> void:
		if is_instance_valid(sh) and sh.config_serial == serial and was:
			sh.revealed[tag] = true
	sc.add(&"scrambled", -1.0, turns, 1, {"tag": tag, "undo": undo})


## A weakness that is real for shaving and the multiplier while its status lasts (AKIRA IN UTERO's [HZ], the
## child's learned tag). One status per tag; a tag the target already has is left alone.
static func grant_weakness(u: Node, tag: StringName, seconds: float, turns: int) -> void:
	var sh := ShieldComponent.of(u)
	var sc := StatusComponent.of(u)
	var sid := StringName("granted_weakness_%s" % String(tag).to_lower())
	if tag == &"" or sh == null or sc == null or sh.weaknesses.has(tag) or sc.has(sid):
		return
	sh.weaknesses.append(tag)
	sh.revealed[tag] = true
	sh.weakness_revealed.emit(tag)
	var serial: int = sh.config_serial
	var undo := func() -> void:
		if is_instance_valid(sh) and sh.config_serial == serial:
			sh.weaknesses.erase(tag)
			sh.revealed.erase(tag)
	sc.add(sid, seconds, turns, 1, {"tag": tag, "undo": undo})


## The weakness tag the Vaelos child is holding: the first tag of the last Break's signature the target lacks.
static func learned_tag(c: BattleCoordinator, u: Node) -> StringName:
	var sh := ShieldComponent.of(u)
	for tag in c.last_break_signature:
		if CombatTags.is_known(tag) and (sh == null or not sh.weaknesses.has(tag)):
			return tag
	return &""


## Shared plates become individual (§5.7; Chrono Laugh, the child's First Light): the shared count is split
## evenly over the bodies of the group, the remainder to the first.
static func unshare(c: BattleCoordinator, hit: Array) -> void:
	var done: Dictionary = {}
	for u in hit:
		var sh := ShieldComponent.of(u)
		if sh == null or (sh.shared_owner == null and sh._members.is_empty()) or done.has(sh._owner()):
			continue
		var holder: ShieldComponent = sh._owner()
		done[holder] = true
		var total: int = holder.current_shield
		var bodies: Array[ShieldComponent] = holder._group()
		for m in bodies:
			m.unshare()
			m.shared_group = &""
		holder._members.clear()
		var per: int = floori(float(total) / float(bodies.size()))
		for i in bodies.size():
			var m2: ShieldComponent = bodies[i]
			m2.current_shield = per + ((total - per * bodies.size()) if i == 0 else 0)
			m2.shield_changed.emit(m2.current_shield, m2.max_total())


static func _auto_break(_c: BattleCoordinator, op: Dictionary, ctx: Dictionary, each: Array) -> void:
	var picks: Array = []
	if String(op.get("pick", "smallest")) == "zero":
		picks = each.filter(func(u: Node) -> bool: return ShieldComponent.of(u) != null and not ShieldComponent.of(u).is_broken and ShieldComponent.of(u).current_shield <= 0)
	else:
		var best: Node = null
		for u in each:
			var sh := ShieldComponent.of(u)
			if sh != null and not sh.is_broken and (best == null or sh.current_shield < ShieldComponent.of(best).current_shield):
				best = u
		if best != null:
			picks = [best]
	for u in picks:
		var sh2 := ShieldComponent.of(u)
		if sh2.can_break_now():
			sh2.force_break(ctx["attacker"], ctx["tech"].tags)
			(ctx["info"]["breaks"] as Array).append(u)


## Rewind Reel (§11.3): every enemy's telegraph, gauge and position go back `seconds` of battle time; allies keep
## theirs. The engine keeps one record per body (its last turn start), so positions return there, a wind-up in
## progress is undone and the gauge loses what `seconds` of filling gave it (DECISIONS "Effect table").
static func rewind_enemies(c: BattleCoordinator, seconds: float) -> void:
	for e in c.living_enemies():
		if c.wind_ups.has(e):
			c.wind_ups.erase(e)
			c.telegraph_ended.emit(e)
		var st := CombatantStats.of(e)
		c.set_gauge(e, c.get_gauge(e) - seconds * (st.gauge_speed() if st != null else 25.0))
		var snap: Dictionary = c.turn_snapshots.get(e, {})
		if snap.has("pos"):
			c._set_position(e, snap["pos"])
		var sc := StatusComponent.of(e)
		if sc != null:
			sc.remove(&"invulnerable")  # the Heckler Harlequin's ignored-for-15 s state
