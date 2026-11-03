## What a technique costs and who pays it (Combat Laws Bible §10.1, §10.2, §11): whether a cast can be paid, MP,
## Crono's Battle Strain, Camp Strain and integrity, Sera's solidity (her overflow lands on Crono), the BP-all and
## HP-to-one costs, and the hairline Crono's slip tax.
class_name TechCosts
extends RefCounted


## {ok: true} when `actor` may cast `tech` with `casters` at `boost` now, else {ok: false, error} (refused before
## anything is paid).
static func can_cast(c: BattleCoordinator, actor: Node, tech: TechDef, casters: Array, boost: int) -> Dictionary:
	if not c.available_techs(actor).has(tech):
		return c.fail("tech not available")
	if boost < tech.min_boost:
		return c.fail("needs Boost Lv%d" % tech.min_boost)
	if not c.bank.can_spend(boost):
		return c.fail("not enough BP")
	var needed: int = tech.actor_count_expected()
	if tech.tier != TechDef.Tier.ULTIMATE and casters.size() != needed:
		return c.fail("needs %d actors" % needed)
	for caster in casters:
		if caster != actor and not c.ready_pool.has(caster):
			return c.fail("partner not in the Ready Pool")
		var st := CombatantStats.of(caster)
		var cost: Dictionary = tech.cost_for(st.actor_id)
		var mp: int = int(cost.get("mp", 0))
		if mp > 0 and not st.can_pay_mp(mp):
			return c.fail("%s lacks MP" % st.actor_id)
		var sc := StatusComponent.of(caster)
		if sc != null and sc.has(&"grief") and float(st.mp) < float(st.max_mp) * 0.5 and boost > 1:
			return c.fail("Grief: cannot spend more than 1 BP")
		if caster != actor and c.cooldowns.left(caster, tech.id) > 0:
			return c.fail("%s: %s is recharging" % [st.actor_id, tech.display_name])
		if cost.has("bp_all") and c.bank.bp < int(cost["bp_all"]):
			return c.fail("needs %d BP" % int(cost["bp_all"]))
	return {"ok": true}


## What `caster` pays for `tech`: MP (Ash Feeder), strain, camp strain and integrity (halved or freed by a status, Fall
## Break or a field), solidity, all BP, HP to one.
static func pay(c: BattleCoordinator, caster: Node, tech: TechDef) -> void:
	var st := CombatantStats.of(caster)
	var cost: Dictionary = tech.cost_for(st.actor_id)
	var mp: int = int(cost.get("mp", 0))
	if mp > 0:
		var sc := StatusComponent.of(caster)
		if sc != null and sc.has(&"ash_feeder") and tech.tags.has(CombatTags.RUIN):
			mp = roundi(float(mp) * 0.8)
		st.spend_mp(mp)
	var td := TimeDebtComponent.of(caster)
	if td != null:
		var strain: float = float(cost.get("strain_pct", 0.0)) / 100.0
		if strain > 0.0 and caster.get_meta("next_astral_free", false):
			caster.remove_meta("next_astral_free")
			strain = 0.0
		if strain > 0.0:
			var sc2 := StatusComponent.of(caster)
			if sc2 != null and sc2.has(&"core_lattice"):
				strain *= 0.5
			if sc2 != null and sc2.has(&"guilt_halo"):
				strain *= 0.5
			if caster.has_meta("fall_break"):
				strain *= 0.5
				caster.remove_meta("fall_break")
			if FieldEffects.free_strain_cast(c, caster):  # a golden patch or a watercolour puddle (§7.4, §9.6)
				strain = 0.0
			td.pay_battle_strain(strain)
			st.clamp_to_ceiling()
		var camp: float = float(cost.get("camp_strain_pct", 0.0)) / 100.0
		if camp > 0.0:
			td.pay_camp_strain(camp)
			st.clamp_to_ceiling()
		var integ: float = float(cost.get("integrity", 0.0))
		if integ > 0.0:
			td.pay_integrity(integ)
			st.clamp_to_ceiling()
	var sol := SolidityComponent.of(caster)
	if sol != null:
		var pct: float = float(cost.get("solidity_pct", 0.0))
		if pct > 0.0:
			if tech.id == &"borrowed_future" and sol.solidity < 50.0:
				pct += 10.0
			if caster.has_meta("fall_break"):
				pct *= 0.5
				caster.remove_meta("fall_break")
			TechCosts.spend_solidity(c, caster, pct)
	if cost.has("bp_all"):
		c.bank.spend_all()
	if cost.has("hp_to_one"):
		st.apply_self_cost(st.hp - 1)
		var sc3 := StatusComponent.of(caster)
		if sc3 != null:
			sc3.add(&"fragile", -1.0, 2)


## Spend Sera's solidity; a hairline Crono pays 5% max HP per Rewind/slip; overflow lands on Crono.
static func spend_solidity(c: BattleCoordinator, sera: Node, pct: float) -> Dictionary:
	var sol := SolidityComponent.of(sera)
	if sol == null:
		return {}
	var was_phased: bool = sol.is_phased()
	sera.set_meta("last_solidity_cost", pct)  # Time Debt Seal refunds it
	var r: Dictionary = sol.spend(pct)
	if float(r["overflow"]) > 0.0:
		var crono: Node = c.party_unit(&"crono")
		var td := TimeDebtComponent.of(crono)
		if td != null:
			td.pay_battle_strain(float(r["overflow"]) / 100.0)
			CombatantStats.of(crono).clamp_to_ceiling()
	if not was_phased and sol.is_phased():
		c.sera_phase_changed.emit(true)
		c.truth_moment.emit(&"phase_out")
	return r


## Every Sera Rewind or Chronoslip costs a hairline-or-worse Crono 5% of his max HP (cannot KO).
static func crono_pays_for_slip(c: BattleCoordinator) -> void:
	var crono: Node = c.party_unit(&"crono")
	if crono == null:
		return
	var td := TimeDebtComponent.of(crono)
	var st := CombatantStats.of(crono)
	if td == null or st == null:
		return
	if td.is_hairline_or_worse(float(st.hp) / float(st.base_max_hp)):
		st.apply_self_cost(roundi(float(st.max_hp()) * CombatConstants.CRONO_HAIRLINE_REWIND_HP))
		c.strike_resolved.emit(crono, crono, {"damage": 0, "slip_tax": true, "tags": []})
