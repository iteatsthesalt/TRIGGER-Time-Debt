## The flat shave bonus of one action (Combat Laws Bible §5.3; acceptance §18.7 #23). The preview and
## the resolution both read `against()`, so the Shield Plate preview always equals the shave the hit
## then does: an armed Ens ring, a technique's bonus against a status the target carries and the
## watercolour puddle's +1 are counted in both places (DECISIONS "Lv3 flat shave bonus").
class_name ShaveBonus
extends RefCounted


## The bonus every target of the action receives: the Lv3 +1 and the technique's own flat bonus.
static func flat(tech: TechDef, boost: int) -> int:
	var b: int = 0
	if boost >= 3:
		b += CombatConstants.BOOST_LV3_SHAVE_BONUS
	if tech != null:
		b += tech.flat_shave_bonus
	return b


## The bonus the action carries against one target: `flat`, plus the actor's armed Ens ring (§4.2; the
## coordinator consumes the ring once the action has resolved), the technique's bonus against a status
## the target carries (`bonus_if_status`, e.g. Tachyon Needle vs MAGNETIZED) and +1 for an ASTRAL hit
## on a target standing in a watercolour puddle.
static func against(c: BattleCoordinator, actor: Node, tech: TechDef, boost: int, target: Node, tags: Array, bonus_if_status: Dictionary = {}) -> int:
	var b: int = flat(tech, boost)
	if c.ens_rings.has(actor):
		b += int(c.ens_rings[actor].get("shave", 1))
	if target == null:
		return b
	b += EffectTable.shave_bonus(c, tech, boost, target)  # the effect table's bonuses (Lily Lancets, Spore Rail, ...)
	var tsc := StatusComponent.of(target)
	for sid in bonus_if_status.keys():
		if tsc != null and tsc.has(sid):
			b += int(bonus_if_status[sid])
	if tags.has(CombatTags.ASTRAL) and c.fields.has_kind_at(&"watercolour_puddle", c.position_of(target)):
		b += 1
	return b


## Shave the actor's hits lose on every matching strike (§12.2): ranged [BOW][GUN] hits under BLIND lose 1,
## Crono's ASTRAL hits under Sticky Ash lose 1. Read by the preview and the resolution alike. A technique whose
## row says it shaves nothing (Mycelia Time Lapse) loses every shave and keeps its weakness damage.
static func penalty(actor: Node, tags: Array, tech: TechDef = null) -> int:
	if EffectTable.shaves_nothing(tech):
		return 999
	var sc := StatusComponent.of(actor)
	if sc == null:
		return 0
	var p: int = 0
	if sc.has(&"blind") and (tags.has(CombatTags.BOW) or tags.has(CombatTags.GUN)):
		p += 1
	var st := CombatantStats.of(actor)
	if sc.has(&"sticky_ash") and tags.has(CombatTags.ASTRAL) and st != null and st.actor_id == &"crono":
		p += 1
	return p
