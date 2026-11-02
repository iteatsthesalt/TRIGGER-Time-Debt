## Pay Time Debt (Combat Laws Bible §14.1 Prologue; DECISIONS "The Dollhouse Seal is paid from the deck"): while
## a boss is sealed, Crono's deck offers to pay INTEGRITY_COST points of integrity (0-100 scale, so "5%
## integrity"; through TimeDebtComponent.max_hp_factor that lowers his HP ceiling by half as many points) and the
## Seal lifts. A free action: the deck reopens on the same window. The deck label and the floating number are
## both built here, from the one cost, so they cannot disagree.
class_name SealPayment
extends RefCounted

const INTEGRITY_COST := 5.0


## Offered on `actor`'s deck while the scene's boss is sealed and the actor carries Time Debt (Crono).
static func offered(scene: BattleScene, actor: CombatActor) -> bool:
	return scene.boss != null and scene.boss.is_sealed() and actor.time_debt != null


static func label(integrity_now: float) -> String:
	return "Pay Time Debt (%d%% integrity, now %d)" % [roundi(INTEGRITY_COST), roundi(integrity_now)]


static func number_text() -> String:
	return "−%d%% integrity" % roundi(INTEGRITY_COST)


static func pay(scene: BattleScene, actor: CombatActor) -> void:
	actor.time_debt.pay_integrity(INTEGRITY_COST)
	Game.set_integrity(actor.time_debt.integrity)
	actor.set_porcelain_visuals()
	if scene.boss != null:
		scene.boss.set_sealed(false)
	Flags.add_counter(&"debts_paid", 1)
	Audio.play_sfx("porcelain/crack_small")
	scene.hud.spawn_number(actor.global_position, number_text(), Color(0.8, 0.85, 1.0), true)
	scene.hud.show_message("Paid. The Seal opens by exactly as much as he gives it.")
	if Flags.has(&"The_Bowl_Still_Whole"):
		BattleFx.gold_shatter(scene, actor.global_position)
