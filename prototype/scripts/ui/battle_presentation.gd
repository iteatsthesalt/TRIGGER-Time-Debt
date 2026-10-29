class_name BattlePresentation
extends Node3D
## Battle feedback that only listens to the coordinator: floating damage numbers,
## a shield-crack pop when shields are shaved, a BREAK! flash, and the attacker's
## swing animation. Nothing here changes combat state.

@export var coordinator: HybridBattleCoordinator
## Seconds a popup stays up while it rises and fades.
@export var popup_time: float = 0.8
@export var popup_rise: float = 0.9
## Height above the actor's origin where popups start (sprites are 1.6 m tall).
@export var popup_height: float = 1.9

const COLOR_DAMAGE := Color(1.0, 0.96, 0.85)
const COLOR_WEAK := Color(1.0, 0.78, 0.25)
const COLOR_SHIELD := Color(0.55, 0.85, 1.0)
const COLOR_BREAK := Color(1.0, 0.35, 0.3)


func _ready() -> void:
	if coordinator:
		coordinator.strike_resolved.connect(_on_strike_resolved)
		coordinator.enemy_broken.connect(_on_enemy_broken)


## Live popups (Label3D) still on screen.
func popups() -> Array[Label3D]:
	var out: Array[Label3D] = []
	for c in get_children():
		if c is Label3D and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _on_strike_resolved(attacker: Node3D, target: Node3D, damage: int, result: Dictionary) -> void:
	var sprite = attacker.get("sprite") if is_instance_valid(attacker) else null
	if sprite:
		sprite.play_attack()
	if not is_instance_valid(target):
		return
	var weak: bool = result.get("hit_weakness", false)
	spawn_popup(target, str(damage), COLOR_WEAK if weak else COLOR_DAMAGE, 64 if weak else 48)
	var shaved: int = result.get("shields_shaved", 0)
	if shaved > 0:
		spawn_popup(target, "-%d SHIELD" % shaved, COLOR_SHIELD, 32, Vector3(0.0, -0.35, 0.0))


func _on_enemy_broken(enemy: Node3D, _breaker: Node) -> void:
	if not is_instance_valid(enemy):
		return
	spawn_popup(enemy, "BREAK!", COLOR_BREAK, 72, Vector3(0.0, 0.45, 0.0))
	flash(enemy)


func spawn_popup(over: Node3D, text: String, color: Color, font_size: int, offset := Vector3.ZERO) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.font_size = font_size
	label.outline_size = 10
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(label)
	label.global_position = over.global_position + Vector3(0.0, popup_height, 0.0) + offset
	if is_inside_tree():
		var tw := label.create_tween().set_parallel(true)
		tw.tween_property(label, "position:y", label.position.y + popup_rise, popup_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(label, "modulate:a", 0.0, popup_time * 0.4).set_delay(popup_time * 0.6)
		tw.chain().tween_callback(label.queue_free)
	return label


## White-hot flash on the enemy's sprite that settles back to normal.
func flash(enemy: Node3D) -> void:
	var sprite = enemy.get("sprite")
	if sprite == null or not is_inside_tree():
		return
	sprite.modulate = Color(3.0, 3.0, 3.0)
	var tw: Tween = sprite.create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.35)
