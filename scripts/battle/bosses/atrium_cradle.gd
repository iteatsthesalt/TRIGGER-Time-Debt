## Director for the Atrium Cradle (Prologue boss, Story Bible §6 Prologue, Combat Laws §14.1).
## Phase 1: the Break Signature decides whether Crono's crack holds (LIGHT) or widens (SWORD/FIRE: 3 integrity).
## Phase 2: the Dollhouse Seal is paid inside the phase script (5% integrity, permanent).
## Phase 3: every Break swaps the canvas to U7 gold leaf for three battle seconds; a perfect parry on the
## Crack-Slide opens a 1.5 s Prismatic window in which Astral Smear Dash catches the bowl.
extends RefCounted

const CRACK_WIDENS: float = 3.0
const GOLD_LEAF_S: float = 3.0

## The canvas the fight began on, which the gold-leaf swap returns to.
var home_universe: int = 0
## battle_time at which the gold leaf ends (0 = no swap showing).
var gold_until: float = 0.0


func on_setup(_ctrl: BossController) -> void:
	home_universe = Universe.target


func on_phase(ctrl: BossController, i: int) -> void:
	match i:
		1:
			ctrl.scene.hud.show_message("Dollhouse Seal: the Cradle takes no damage until Crono pays.")
		2:
			Audio.set_rtpc("vaelos_near", 0.6)


func on_break(ctrl: BossController, signature: Array[StringName]) -> Dictionary:
	match ctrl.phase_index:
		0:
			if signature.has(&"LIGHT"):
				ctrl.scene.hud.show_message("Broken with Light. The crack holds.")
				Flags.add_lean(0, "L")
				return {"handled": true}
			elif signature.has(&"SWORD") or signature.has(&"FIRE"):
				ctrl.scene.hud.show_message("Broken with the blade. The crack widens.")
				Flags.add_lean(0, "D")
				_widen_crack(ctrl)
				return {"handled": true}
		2:
			Universe.set_universe(7, true)
			gold_until = ctrl.coordinator.battle_time + GOLD_LEAF_S
	return {}


## Crono pays the widening through his TimeDebtComponent and Game mirrors it (one source, as every other charge).
func _widen_crack(ctrl: BossController) -> void:
	var crono: Node = ctrl.coordinator.unit_by_id(&"crono")
	var td := TimeDebtComponent.of(crono) if crono != null else null
	if td == null:
		Game.set_integrity(Game.crono_integrity - CRACK_WIDENS)
		return
	td.pay_integrity(CRACK_WIDENS)
	Game.set_integrity(td.integrity)
	if crono is CombatActor:
		(crono as CombatActor).set_porcelain_visuals()


func on_tick(ctrl: BossController, _delta: float) -> void:
	if gold_until > 0.0 and ctrl.coordinator.battle_time >= gold_until:
		_end_gold_leaf()


func _end_gold_leaf() -> void:
	if gold_until > 0.0:
		gold_until = 0.0
		Universe.set_universe(home_universe, false)


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
	_end_gold_leaf()
	Audio.set_rtpc("vaelos_near", 0.0)
	ctrl.scene.hud.show_message("The Cradle shuts down. Six legs fold.")


## A loss (or any end) inside the gold leaf still puts the canvas back.
func on_battle_end(_ctrl: BossController, _victory: bool) -> void:
	_end_gold_leaf()
	Audio.set_rtpc("vaelos_near", 0.0)
