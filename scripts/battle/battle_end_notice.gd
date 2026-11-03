## The line and the sting that close a battle (Combat Laws Bible §16.1, §16.5, §17): the XP tally and the
## victory sting on a win, "The Debt advances" and the defeat sting on a loss, and a quiet line with no sting
## for a withdraw, which costs nothing but the fight.
class_name BattleEndNotice
extends RefCounted


static func announce(hud: BattleHUD, party: Array, victory: bool, summary: Dictionary) -> void:
	if victory:
		Audio.play_sting("victory")
		for p in party:
			if is_instance_valid(p) and p.stats.is_alive():
				p.sprite.play(&"victory", &"idle")
		hud.show_message(xp_line(summary))
	elif BattleAftermath.outcome(victory, summary) == BattleAftermath.WITHDRAW:
		hud.show_message("Withdrawn. It cost nothing but the fight.")
	else:
		hud.show_message("The Debt advances: Crono −%s integrity." % str(summary.get("integrity_lost", 5)))
		Audio.play_sting("defeat")


## "Crono +40 XP (Lv up ×1)  Sera +40 XP  1 spared".
static func xp_line(summary: Dictionary) -> String:
	var xp: Dictionary = summary.get("xp", {})
	var parts: Array = []
	for id in xp.keys():
		var lv: int = int(xp[id]["levels"])
		parts.append("%s +%d XP%s" % [String(id).capitalize(), int(xp[id]["xp"]), (" (Lv up ×%d)" % lv) if lv > 0 else ""])
	if int(summary.get("spared", 0)) > 0:
		parts.append("%d spared" % int(summary.get("spared", 0)))
	return "  ".join(PackedStringArray(parts))
