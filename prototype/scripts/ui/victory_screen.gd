class_name VictoryScreen
extends Control
## After a battle: on victory, pays out BattleRewards and shows XP, gold and level-ups
## until the player confirms; on defeat, returns to the title screen (or reloads the
## current scene while no title screen exists yet).

## Emitted once rewards are applied. GameState (backlog) banks the gold from here.
signal rewards_granted(rewards: BattleRewards)
signal closed

@export var coordinator: HybridBattleCoordinator
@export_file("*.tscn") var title_scene: String = "res://scenes/title_screen.tscn"
## Seconds before the panel closes on its own; 0 = wait for ui_accept.
@export var auto_close_time: float = 0.0
## Off in tests: decide the destination but don't actually change scenes.
@export var handle_defeat: bool = true

var last_rewards: BattleRewards
var lines: PackedStringArray = []

var _panel: PanelContainer
var _label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(320, 0)
	add_child(_panel)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_label)
	visible = false
	if coordinator:
		coordinator.combat_ended.connect(_on_combat_ended)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		close()
		get_viewport().set_input_as_handled()


func _on_combat_ended(victory: bool) -> void:
	if victory:
		show_victory(BattleRewards.grant(coordinator.active_party, coordinator.active_enemies))
	else:
		go_to_title()


func show_victory(rewards: BattleRewards) -> void:
	last_rewards = rewards
	lines = PackedStringArray(["VICTORY", "%d XP   %d G" % [rewards.xp, rewards.gold]])
	for id in rewards.level_ups:
		lines.append("%s reached Lv %d!" % [String(id).capitalize(), rewards.new_levels[id]])
	_label.text = "\n".join(lines)
	visible = true
	rewards_granted.emit(rewards)
	if auto_close_time > 0.0 and is_inside_tree():
		get_tree().create_timer(auto_close_time).timeout.connect(close)


func close() -> void:
	if visible:
		visible = false
		closed.emit()


## Where a defeat sends the player.
func defeat_destination() -> String:
	return title_scene if ResourceLoader.exists(title_scene) else ""


func go_to_title() -> void:
	if not handle_defeat or not is_inside_tree():
		return
	var dest := defeat_destination()
	if dest.is_empty():
		get_tree().reload_current_scene.call_deferred()
	else:
		get_tree().change_scene_to_file.call_deferred(dest)
