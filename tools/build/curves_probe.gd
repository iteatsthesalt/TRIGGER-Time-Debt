## Prints the party and enemy stat curves at a few levels (balance reference).
extends SceneTree
func _initialize() -> void:
	for lv in [1, 2, 3, 5, 8, 12]:
		var p := CombatantStats.new()
		p.apply_party_curve(&"crono", lv)
		var m := CombatantStats.new()
		m.apply_party_curve(&"marle", lv)
		var e := CombatantStats.new()
		e.apply_enemy_curve(lv, "regular")
		var b := CombatantStats.new()
		b.apply_enemy_curve(lv, "boss")
		print("Lv%d crono hp=%d patk=%.1f pdef=%.1f | marle hp=%d eatk=%.1f | regular hp=%d atk=%.1f pdef=%.1f | boss hp=%d atk=%.1f pdef=%.1f" % [lv, p.base_max_hp, p.p_atk, p.p_def, m.base_max_hp, m.e_atk, e.base_max_hp, e.p_atk, e.p_def, b.base_max_hp, b.p_atk, b.p_def])
	quit()
