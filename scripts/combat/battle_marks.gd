## The marks a battle leaves on a body as Node metas that hold for that battle only (Combat Laws Bible §10-§12:
## "once per battle", "for the battle"). The bodies outlive the battle: Location gives the same party to every
## fight in a room, and a zone's survivors stand again after a defeat or a withdraw (BattleAftermath.restore_enemy),
## so BattleCoordinator.start_battle clears these on everyone it is given and restore_enemy clears them on a zone
## survivor. A battle-long rule written as a meta goes here. What must outlast a battle is not a meta at all
## (Krona's Corruption is CorruptionComponent, Crono's integrity TimeDebtComponent, Sera's Debt SolidityComponent),
## and the marks a body is made with (EffectiveRank's encounter, a boss id, is_metal) are never cleared.
class_name BattleMarks
extends RefCounted

const PER_BATTLE: Array[StringName] = [
	&"seal_used",  # Time Debt Seal cancels a Causal Collapse once per battle (§11)
	&"last_solidity_cost",  # what the Seal refunds: Sera's last solidity cost in this battle
	&"tuning",  # Static's Tune locks his frequency for the battle (§10)
	&"sunlight",  # Xyloph's Sunlight Stacks (§10)
	&"tether_nodes",  # Xyloph's tether nodes (§11)
	&"loom_mended",  # Wire Loom Mend's +0.6 integrity, once per battle (§10.1)
	&"concerned_fired",  # the galaxy reveal makes the allies Concerned once per battle (§12.3)
	&"next_astral_free",  # Porcelain Promise: Crono's next ASTRAL cost is 0
	&"fall_break",  # Fall Break: the next strain or solidity cost is halved
	&"used_tachyon_this_turn",  # no +2 solidity on a TACHYON turn (§10.2)
	&"sipped_action",  # the gourd sips at most once per enemy action against Krona (DECISIONS)
	&"theft_immune_once",  # Balloon Escape: the next BP theft against the party fails (§11)
	&"repainted",  # an Ashen enemy repaints once per battle (EnemyEffects)
	&"split_done",  # a doll splits once per battle (EnemyEffects)
	&"stolen_bp",  # the BP an enemy stole this battle, which Glenn steals back (§7.5)
]


## Clear every per-battle mark on `u`.
static func clear(u: Node) -> void:
	if not is_instance_valid(u):
		return
	for m in PER_BATTLE:
		if u.has_meta(m):
			u.remove_meta(m)
