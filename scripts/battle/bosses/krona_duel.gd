## Director for Krona's Bamboo Grove duel (Chapter 2, Combat Laws §14.4). The duel ends at 50%: the last phase's
## window closes there and BossController yields the fight (BossDef.ends_at). In "She Ate the Star" the phase
## script (ch2_duel_mid) offers the Epoch gauntlet overcharge; taken, the ASTRAL burst Breaks her outright and
## ends the duel at once. The script's `call: duel_overcharge` is answered here, so the grove scene needs none.
extends RefCounted

const OVERCHARGE_SCRIPT := &"ch2_duel_mid"
const OVERCHARGE_LABEL := "overcharge"

var overcharged: bool = false
var _listening: Callable = Callable()


func on_setup(_ctrl: BossController) -> void:
	_listening = _on_choice
	Story.choice_made.connect(_listening)


func _on_choice(_index: int, option: Dictionary) -> void:
	if Story.current_id == OVERCHARGE_SCRIPT and String(option.get("goto", "")) == OVERCHARGE_LABEL:
		overcharged = true


## Runs after the phase script: the overcharge is the ASTRAL burst that Breaks her and ends the duel.
func on_phase(ctrl: BossController, _i: int) -> void:
	if not overcharged or ctrl.ended:
		return
	var crono: Node = ctrl.coordinator.unit_by_id(&"crono")
	ctrl.actor.shield.force_break(crono, [CombatTags.ASTRAL])
	ctrl.scene.hud.show_message("The gauntlet bursts gold. Krona is Broken outright.")
	ctrl.end_fight("overcharge")


func on_battle_end(_ctrl: BossController, _victory: bool) -> void:
	if _listening.is_valid() and Story.choice_made.is_connected(_listening):
		Story.choice_made.disconnect(_listening)
