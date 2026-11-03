## Using a consumable in battle (Combat Laws §4.1 Item; data/items/items.json). An item's effect fields:
## `heal_pct` (of max HP), `mp`, `revive_pct` (a fallen ally only), `cleanse`, `integrity` (repairs Crono's
## porcelain: the Time Atom's +0.5), `thaw_ruin` (Ruin stacks thawed). Only the `consumable` kind with at least
## one of them is offered in the Item deck; an item that would do nothing to its target is refused before it
## is taken from the bag (a Revive on a standing ally, a Tonic on the fallen).
class_name ItemUse
extends RefCounted

const EFFECTS: Array[String] = ["heal_pct", "mp", "revive_pct", "cleanse", "integrity", "thaw_ruin"]


static func usable_in_battle(def: Dictionary) -> bool:
	if String(def.get("kind", "consumable")) != "consumable":
		return false
	for k in EFFECTS:
		if def.has(k):
			return true
	return false


## The Time Debt component an `integrity` item repairs: the target's own, or the party's Crono's.
static func _porcelain(c: BattleCoordinator, target: Node) -> TimeDebtComponent:
	var td := TimeDebtComponent.of(target)
	return td if td != null else TimeDebtComponent.of(c.unit_by_id(&"crono"))


## Whether the item would do anything to `target` now.
static func works(c: BattleCoordinator, item: Dictionary, target: Node) -> bool:
	var st := CombatantStats.of(target) if target != null else null
	if st == null:
		return false
	if not st.is_alive():
		return item.has("revive_pct")
	if item.has("heal_pct") or item.has("mp") or item.has("cleanse"):
		return true
	if item.has("integrity"):
		var td := _porcelain(c, target)
		if td != null and td.integrity < 100.0:
			return true
	return item.has("thaw_ruin") and RuinRules.stacks(target) > 0


static func apply(c: BattleCoordinator, actor: Node, item: Dictionary, target: Node) -> void:
	var st := CombatantStats.of(target)
	if item.has("revive_pct") and not st.is_alive():
		st.revive(float(item["revive_pct"]))
		c.unit_revived.emit(target)
		return
	if not st.is_alive():
		return
	if item.has("heal_pct"):
		var healed: int = st.heal(roundi(float(st.max_hp()) * float(item["heal_pct"])))
		c.heal_resolved.emit(actor, target, healed)
	if item.has("mp"):
		st.restore_mp(int(item["mp"]))
	if item.has("cleanse") and StatusComponent.of(target) != null:
		StatusComponent.of(target).cleanse()
	if item.has("integrity"):
		var td := _porcelain(c, target)
		if td != null:
			td.repair_integrity(float(item["integrity"]))
	if item.has("thaw_ruin"):
		RuinRules.thaw(target, int(item["thaw_ruin"]))
