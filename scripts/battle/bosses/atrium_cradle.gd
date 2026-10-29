## Director for the Atrium Cradle (Prologue boss, Story Bible §6 Prologue, Combat Laws §14.1).
## Phase 1: the Break Signature decides whether Crono's crack holds (LIGHT) or widens (SWORD/FIRE).
## Phase 2: the Dollhouse Seal is paid inside the phase script (5% integrity, permanent).
## Phase 3: every Break swaps the canvas to U7 gold leaf for three seconds; a perfect parry on the
## Crack-Slide opens a 1.5 s Prismatic window in which Astral Smear Dash catches the bowl.
extends RefCounted

var _u7_timer: SceneTreeTimer


func on_phase(ctrl: BossController, i: int) -> void:
	match i:
		1:
			ctrl.scene.hud.show_message("Dollhouse Seal: the Cradle takes no damage until Crono pays.")
		2:
			Audio.set_rtpc("vaelos_near", 0.6)


func on_break(ctrl: BossController, signature: Array[StringName]) -> void:
	match ctrl.phase_index:
		0:
			if signature.has(&"LIGHT"):
				ctrl.scene.hud.show_message("Broken with Light. The crack holds.")
				Flags.add_lean(0, "L")
			elif signature.has(&"SWORD") or signature.has(&"FIRE"):
				ctrl.scene.hud.show_message("Broken with the blade. The crack widens.")
				Game.set_integrity(Game.crono_integrity - 3.0)
				Flags.add_lean(0, "D")
				var crono: Node = ctrl.coordinator.unit_by_id(&"crono")
				if crono is CombatActor:
					var td := TimeDebtComponent.of(crono)
					if td != null:
						td.pay_integrity(3.0)
					(crono as CombatActor).set_porcelain_visuals()
		2:
			Universe.set_universe(7, true)
			_u7_timer = ctrl.get_tree().create_timer(3.0)
			_u7_timer.timeout.connect(func() -> void: Universe.set_universe(0, false))


func on_parry(ctrl: BossController, _ally: Node, perfect: bool, action: Dictionary) -> void:
	if perfect and ctrl.phase_index == 2 and String(action.get("id", "")) == "crack_slide":
		ctrl.open_window(&"prismatic", 1.5)


func on_action(ctrl: BossController, info: Dictionary) -> void:
	if String(info.get("kind", "")) != "tech" or not ctrl.window_open(&"prismatic"):
		return
	var tech: TechDef = info.get("tech", null)
	if tech == null or tech.id != &"astral_smear_dash":
		return
	ctrl.window_until = 0.0
	if not Flags.has(&"The_Bowl_Still_Whole"):
		Flags.set_flag(&"The_Bowl_Still_Whole", &"set", {"prismatic": 15})
		Game.learn_tech(&"crono", &"bekkler_guilt")
		ctrl.scene.hud.show_message("The bowl, caught whole. Vaelos: —you remember how to catch—")
		Audio.play_sfx("time/amber_chime")


func on_defeat(ctrl: BossController) -> void:
	Universe.set_universe(0, false)
	Audio.set_rtpc("vaelos_near", 0.0)
	ctrl.scene.hud.show_message("The Cradle shuts down. Six legs fold.")
