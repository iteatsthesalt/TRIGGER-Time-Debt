## The periodic statuses on battle time (Combat Laws Bible §12.2, §6.3): StatusComponent emits `periodic` on
## its PERIODS table and this answers it. Grief −2 MP per stack per 10 s, Laugh Track Drain −1 MP per 8 s on
## every bearer, DoTs (oil, ink, bleed, burn) take the tick they were applied with (never crit, never shave,
## the zero-fail HP floor holds), regen heals its tick (2% max HP by default). The coordinator watches every
## unit when the battle starts (StatusRules.begin_battle) and releases them when it ends.
class_name StatusTicks
extends RefCounted

const META := &"status_ticks_cb"


static func watch(c: BattleCoordinator, u: Node) -> void:
	var sc := StatusComponent.of(u)
	if sc == null:
		return
	release(u)
	var cb := func(id: StringName, stacks: int) -> void: tick(c, u, id, stacks)
	sc.periodic.connect(cb)
	sc.set_meta(META, cb)


static func release(u: Node) -> void:
	if not is_instance_valid(u):
		return
	var sc := StatusComponent.of(u)
	if sc == null or not sc.has_meta(META):
		return
	var cb: Callable = sc.get_meta(META)
	if sc.periodic.is_connected(cb):
		sc.periodic.disconnect(cb)
	sc.remove_meta(META)


static func tick(c: BattleCoordinator, u: Node, id: StringName, stacks: int) -> void:
	if not is_instance_valid(c) or not is_instance_valid(u):
		return
	var st := CombatantStats.of(u)
	var sc := StatusComponent.of(u)
	if st == null or sc == null or not c.alive(u):
		return  # the fallen and the spared are out of the fight (§4.2): no DoT, regen or drain reaches them
	var n: int = maxi(1, stacks)
	match id:
		&"grief":
			st.spend_mp(CombatConstants.GRIEF_MP * n)
		&"laugh_track_drain":
			st.spend_mp(CombatConstants.LAUGH_TRACK_MP * n)
		&"regen":
			var amount: int = int(sc.data(id).get("tick", maxi(1, roundi(float(st.max_hp()) * CombatConstants.REGEN_PCT))))
			c.heal_resolved.emit(u, u, st.heal(amount * n))
		_:
			if StatusRules.DOTS.has(id):
				_damage(c, u, st, maxi(1, int(sc.data(id).get("tick", 1))) * n)


static func _damage(c: BattleCoordinator, u: Node, st: CombatantStats, amount: int) -> void:
	if c.undamageable.has(u):
		return
	var dmg: int = amount
	if c.party_hp_floor > 0 and c.party.has(u):
		dmg = mini(dmg, maxi(0, st.hp - c.party_hp_floor))
	var dealt: int = st.apply_damage(dmg, true)
	c.strike_resolved.emit(u, u, {"damage": dealt, "dot": true, "tags": []})
	if not st.is_alive():
		c.check_end()
