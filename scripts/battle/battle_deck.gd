## What the command deck offers and who a command can aim at (Combat Laws Bible §4.2, §4.6, §17.5), built from
## the coordinator's state so the BattleScene stays glue. Every enemy list comes from targetable_enemies(): a
## doll that has stepped back for its split, or anything else untargetable, is never offered, so a confirm
## can never land on a target the coordinator refuses.
class_name BattleDeck
extends RefCounted


## The main deck for `actor` (Attack, Tech, Guard, Sync Hold, Item, Swap, Spare, Pay Time Debt, Withdraw).
static func main_items(scene: BattleScene, actor: CombatActor) -> Array:
	var c: BattleCoordinator = scene.coordinator
	var items: Array = [{"label": "Attack", "cmd": "attack", "enabled": not c.targetable_enemies().is_empty()}]
	items.append({"label": "Tech", "cmd": "techs", "enabled": not c.available_techs(actor).is_empty()})
	items.append({"label": "Guard", "cmd": "guard"})
	items.append({"label": "Sync Hold", "cmd": "sync", "enabled": SyncHoldRules.can_hold(c, actor)})
	items.append({"label": "Item", "cmd": "items", "enabled": item_items().size() > 1})  # a usable item, not just Back
	items.append({"label": "Swap", "cmd": "swap", "enabled": scene.roster.can_swap(c)})
	items.append({"label": "Spare", "cmd": "spare", "enabled": not targets(c, "spare").is_empty()})
	if SealPayment.offered(scene, actor):
		items.append({"label": SealPayment.label(Game.crono_integrity), "cmd": "pay_debt"})
	if WithdrawRules.offered(c):
		items.append({"label": "Withdraw", "cmd": "withdraw"})
	return items


## The Tech sub-deck: each castable tech with its cost, then Back.
static func tech_items(c: BattleCoordinator, actor: CombatActor) -> Array:
	var items: Array = []
	for t in c.available_techs(actor):
		var cost: Dictionary = t.cost_for(actor.stats.actor_id)
		var cost_txt: String = ""
		if cost.has("mp"):
			cost_txt = "%d MP" % int(cost["mp"])
		elif cost.has("strain_pct"):
			cost_txt = "%s%% ceiling" % str(cost["strain_pct"])
		elif cost.has("solidity_pct"):
			cost_txt = "%s%% solidity" % str(cost["solidity_pct"])
		var prefix: String = "[Dual] " if t.tier == TechDef.Tier.DUAL else ("[Triple] " if t.tier == TechDef.Tier.TRIPLE else "")
		items.append({"label": "%s%s  %s" % [prefix, t.display_name, cost_txt], "cmd": "tech", "payload": {"tech": t}})
	items.append({"label": "Back", "cmd": "back"})
	return items


## The Item sub-deck: each battle consumable on hand, then Back.
static func item_items() -> Array:
	var items: Array = []
	for id in Game.inventory.keys():
		var def: Dictionary = Data.items.get(StringName(id), {})
		if not ItemUse.usable_in_battle(def):  # materials, key items, relics stay in the bag
			continue
		items.append({"label": "%s ×%d" % [String(def.get("name", id)), int(Game.inventory[id])], "cmd": "item", "payload": {"item": def}})
	items.append({"label": "Back", "cmd": "back"})
	return items


## Who a command can aim at. `kind`: "attack" or "enemy" (Attack, an enemy-side tech), "spare", "ally" (an ally
## tech: the living), "item" (any ally: a revive needs the fallen).
static func targets(c: BattleCoordinator, kind: String) -> Array:
	match kind:
		"spare":
			return c.targetable_enemies().filter(func(e: Node) -> bool: return c.can_spare(e))
		"ally":
			return c.party.filter(func(u: Node) -> bool: return c._alive(u))
		"item":
			return c.party.filter(func(u: Node) -> bool: return CombatantStats.of(u) != null)
	return c.targetable_enemies()


## The aim line: "Astral Slash → Doll  2 targets, 2 hits, ~84 dmg   [R/T: Boost Lv1]", with the seal named when a
## previewed body takes no HP damage (the plate always shows the math, §17.5).
static func preview_text(tech: TechDef, target: Node, previews: Dictionary, boost: int) -> String:
	var total_dmg: int = 0
	var hits: int = 0
	var sealed: int = 0
	for e in previews.keys():
		total_dmg += int(previews[e]["damage"])
		hits += int(previews[e]["hits"])
		sealed += 1 if bool(previews[e].get("sealed", false)) else 0
	var n: int = previews.size()
	var text: String = "%s  →  %s   %d target%s, %d hit%s, ~%d dmg" % [tech.display_name if tech != null else "Attack", CombatantStats.of(target).display_name, n, "s" if n != 1 else "", hits, "s" if hits != 1 else "", total_dmg]
	if sealed > 0:
		text += "  (%s)" % ("SEALED: no HP damage" if sealed == n else "%d sealed" % sealed)
	return text + "   [R/T: Boost Lv%d]" % boost


## Use `item` on `target` for `actor`: the inventory pays only when the coordinator accepts the command.
static func use_item(c: BattleCoordinator, actor: Node, item: Dictionary, target: Node) -> Dictionary:
	var id := StringName(String(item.get("id", "")))
	if int(Game.inventory.get(String(id), 0)) <= 0:
		return c._fail("none left")
	var r: Dictionary = c.cmd_item(actor, item, target)
	if bool(r.get("ok", false)):
		Game.take_item(id)
	return r
