## Screen-space Shield/weakness plate that stays sharp over DOF blur (ported from Source 02).
## Fixes: uses ShieldComponent.preview_action() so the preview matches what the
## hit will actually do (the v2 formula ignored per-strike Break and the shave cap);
## hides when the enemy dies; no label rebuild every refresh.
class_name EnemyShieldPlate
extends PanelContainer

var target_enemy: Node3D
var camera_3d: Camera3D
var _shield: ShieldComponent
var _stats: CombatantStats
var _badge: Label
var _hp: Label
var _weak_row: HBoxContainer
var _preview: Dictionary = {}


func setup(enemy: Node3D, cam: Camera3D) -> void:
	target_enemy = enemy
	camera_3d = cam
	_shield = enemy.get_node_or_null("ShieldComponent") as ShieldComponent
	_stats = CombatantStats.of(enemy)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	_badge = Label.new()
	top.add_child(_badge)
	var name_label := Label.new()
	name_label.text = enemy.name
	top.add_child(name_label)
	_hp = Label.new()
	box.add_child(_hp)
	_weak_row = HBoxContainer.new()
	box.add_child(_weak_row)
	if _shield:
		_shield.shield_changed.connect(func(_a, _b): refresh())
		_shield.weakness_revealed.connect(func(_t): refresh())
		_shield.broken.connect(func(_b): refresh())
		_shield.break_recovered.connect(refresh)
	if _stats:
		_stats.hp_changed.connect(func(_a, _b): refresh())
	refresh()


func set_preview(preview: Dictionary) -> void:
	_preview = preview
	refresh()


func _process(_delta: float) -> void:
	if not is_instance_valid(target_enemy) or camera_3d == null or (_stats and not _stats.is_alive()):
		visible = false
		return
	var anchor: Vector3 = target_enemy.global_position + Vector3(0.0, 2.0, 0.0)
	if camera_3d.is_position_behind(anchor):
		visible = false
		return
	visible = true
	position = camera_3d.unproject_position(anchor) - size * 0.5


func refresh() -> void:
	if _shield == null:
		return
	var color := Color(0.95, 0.95, 0.95)
	if _shield.is_broken:
		_badge.text = "[BROKEN 2.0x]"
		color = Color(1.0, 0.35, 0.35)
	elif not _preview.is_empty() and int(_preview.get("shave", 0)) > 0:
		var after: int = _shield.current_shields - int(_preview["shave"])
		_badge.text = "[%d -> %d%s]" % [_shield.current_shields, after, " BREAK!" if _preview.get("breaks", false) else ""]
		color = Color(1.0, 0.85, 0.2)
	else:
		_badge.text = "[SHIELD %d]" % _shield.current_shields
		if not _preview.is_empty():
			color = Color(0.5, 1.0, 0.65)
	_badge.add_theme_color_override("font_color", color)
	if _stats:
		_hp.text = "HP %d/%d" % [_stats.hp, _stats.max_hp]
	for c in _weak_row.get_children():
		c.free()
	for w in _shield.weaknesses:
		var l := Label.new()
		var known: bool = _shield.is_revealed(w)
		l.text = "[%s]" % (ShieldComponent.TYPE_LABELS[w] if known else " ? ")
		l.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35) if known else Color(0.65, 0.65, 0.72))
		_weak_row.add_child(l)
