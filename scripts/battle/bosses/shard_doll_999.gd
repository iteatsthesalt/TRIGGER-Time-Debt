## Director for the 999 Shard Doll (Chapter 1 tutorial boss, Combat Laws §14.3). Zero-fail: nobody dies
## here; a fall only cracks Crono. Phase 1 hides FERRO until the plate reads 8. Phase 3 splits into three
## dolls, one per canvas, that must all Break within 3 s. Phase 4 shows 999 shields of which 10 are real.
extends RefCounted

## A broken doll is held in its Break until this director rebuilds it. Left alone, the shield's own
## 3 s lock plus rebuild (~8.6 s) raced the lesson's window: once the window grew past it the dolls
## rebuilt uncounted, `rebuilds` froze and the "stay broken" escape never came, so the fight never ended.
const HOLD_S: float = 1.0e6

## The dummy "can only crack him": each floor costs Crono 2 integrity, but only the first few. A slow
## party (the autobattle takes ~5 min over the split) was floored fifty times and left Chapter 1 at 0.
const CRACKING_FALLS: int = 5
const CRACK_PER_FALL: float = 2.0

var break_times: Dictionary = {}
var boost3_count: int = 0
var falls: int = 0
var ferro_revealed: bool = false


var rebuilds: int = 0


func on_setup(ctrl: BossController) -> void:
	ctrl.coordinator.party_hp_floor = 1
	ctrl.coordinator.boost_used.connect(func(_a: Node, level: int) -> void:
		if level >= 3:
			boost3_count += 1)


func on_phase(ctrl: BossController, i: int) -> void:
	var sc := StatusComponent.of(ctrl.actor)
	match i:
		0:
			# the second weakness is hidden until the plate reads 8
			ctrl.actor.shield.revealed[&"SWORD"] = true
			ferro_revealed = false
		1:
			ctrl.actor.shield.reveal_all()
			ctrl.scene.hud.show_message("Tags gained: FERRO, VOLT. Sera: Rewind its gauge when it winds up.")
		2:
			# the doll itself steps back; three shards take the floor
			if sc != null:
				sc.add(&"untargetable", -1.0, -1)
			break_times.clear()
			var k: int = 0
			for a in ctrl.adds_alive:
				if not is_instance_valid(a):
					continue
				# The lesson is about Breaks, so a doll cannot be killed outright (at ~100 HP a basic
				# attack or two did, with its plates still up, and the split then had nothing left to Break).
				if not ctrl.coordinator.undamageable.has(a):
					ctrl.coordinator.undamageable.append(a)
				var ca := a as CombatActor
				match k % 3:
					0:
						ca.sprite.canvas_fps = 60.0
					1:
						ca.sprite.canvas_fps = 24.0
						ca.sprite.set_tint(Color(0.72, 0.72, 0.74))
						ca.sprite.material.set_shader_parameter("canvas_fps", 24.0)
					2:
						ca.sprite.canvas_fps = 12.0
						ca.sprite.set_tint(Color(0.85, 0.72, 0.55))
						ca.sprite.material.set_shader_parameter("canvas_fps", 12.0)
				k += 1
		3:
			if sc != null:
				sc.remove(&"untargetable")
			for a in ctrl.adds_alive:
				if not is_instance_valid(a):
					continue
				ctrl.coordinator.undamageable.erase(a)
				if CombatantStats.of(a).is_alive():
					CombatantStats.of(a).apply_damage(999999, true)
			ctrl.scene.hud.show_message("The plate reads 999. Vaelos's shields are belief. Only the matching hits count.")


func on_tick(ctrl: BossController, _delta: float) -> void:
	# zero-fail: the HP floor keeps everyone standing; a member left at 1 HP costs Crono a little porcelain
	for u in ctrl.coordinator.party:
		var st := CombatantStats.of(u)
		if st != null and st.is_alive() and st.hp <= 1 and not u.has_meta("dummy_floored"):
			u.set_meta("dummy_floored", true)
			falls += 1
			st.heal(roundi(float(st.max_hp()) * 0.25))
			var crono: Node = ctrl.coordinator.unit_by_id(&"crono")
			if falls <= CRACKING_FALLS and crono is CombatActor and (crono as CombatActor).time_debt != null:
				(crono as CombatActor).time_debt.pay_integrity(CRACK_PER_FALL)
				Game.set_integrity((crono as CombatActor).time_debt.integrity)
				(crono as CombatActor).set_porcelain_visuals()
			ctrl.scene.hud.show_message("The dummy cannot kill anyone. It can only crack him.")
		elif st != null and st.hp > 1 and u.has_meta("dummy_floored"):
			u.remove_meta("dummy_floored")
	if ctrl.phase_index == 0 and not ferro_revealed and ctrl.actor.shield.current_shield <= 8:
		ferro_revealed = true
		ctrl.actor.shield.revealed[&"FERRO"] = true
		ctrl.actor.shield.weakness_revealed.emit(&"FERRO")
		ctrl.scene.hud.show_message("Hidden weakness revealed: FERRO.")
	if ctrl.phase_index == 2:
		_tick_split(ctrl)


func _tick_split(ctrl: BossController) -> void:
	var now: float = ctrl.coordinator.battle_time
	var living: Array = []
	for a in ctrl.adds_alive:
		if is_instance_valid(a) and CombatantStats.of(a).is_alive():
			living.append(a)
	if living.is_empty():
		return
	var all_broken: bool = true
	for a in living:
		if not ShieldComponent.of(a).is_broken:
			all_broken = false
	if all_broken:
		ctrl.scene.hud.show_message("All three Break together. The giggle stops.")
		Audio.play_sfx("combat/break_gong_vinyl")
		ctrl.advance_phase()
		return
	# a broken doll rebuilds if the others are still standing 3 s later. The lesson must not become a
	# wall: after four rebuilds the window widens to 12 s and a rebuilt doll comes back with 3 plates;
	# after eight the broken ones simply stay broken (their Breaks are held, see on_add_break).
	if rebuilds >= 8:
		return
	var window: float = 3.0 if rebuilds < 4 else 12.0
	for a in living:
		var sh := ShieldComponent.of(a)
		if sh.is_broken and break_times.has(a) and now - float(break_times[a]) > window:
			sh.reset_shields()
			if rebuilds >= 4:
				sh.current_shield = mini(sh.current_shield, 3)
				sh.shield_changed.emit(sh.current_shield, sh.max_total())
			break_times.erase(a)
			rebuilds += 1
			if a is CombatActor:
				(a as CombatActor).on_recover()
			if rebuilds == 4:
				ctrl.scene.hud.show_message("The dolls are tiring. Their rhythm slows and their plates thin.")
			elif rebuilds == 8:
				ctrl.scene.hud.show_message("The dolls give up rebuilding. Finish them.")
			else:
				ctrl.scene.hud.show_message("The broken doll rebuilds. All three within three seconds.")


func on_add_break(ctrl: BossController, unit: Node) -> void:
	if ctrl.phase_index == 2:
		break_times[unit] = ctrl.coordinator.battle_time
		var sh := ShieldComponent.of(unit)
		if sh != null:
			sh.extend_lock(HOLD_S)


func on_defeat(ctrl: BossController) -> void:
	Flags.add_counter(&"dummy_boost3_spam", boost3_count)
	Flags.add_counter(&"dummy_falls", falls)
	ctrl.scene.hud.show_message("The 999 Shard Doll goes quiet. Its plate reads 0.")
