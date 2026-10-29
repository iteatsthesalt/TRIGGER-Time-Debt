## Timeline bar, Ready Pool, BP pips, and keyboard command deck (ported from Source 02).
## Keys: 1-9 choose command · Tab next target · Q/E boost −/+ · H Sync Hold ·
##       Space/Enter execute · W wake a held ally while the timeline runs.
## Fixes vs. v2: uses public coordinator API only; adds basic Attack; boost cap
## shown per command; previews come from the same geometry/shield code the hit uses;
## held allies can be woken (v2 had no way back, matching the coordinator deadlock).
class_name BattleTimelineHUD
extends Control

@export var coordinator: HybridBattleCoordinator
@export var camera_3d: Camera3D
@export var decal: AoEDecalVisualizer3D

var _track: Control
var _pool_label: Label
var _party_label: Label
var _cmd_panel: VBoxContainer
var _cmd_header: Label
var _cmd_status: Label
var _cmd_list: Label

var _tokens: Dictionary = {}
var _plates: Dictionary = {}
var _actor: Node3D = null
var _options: Array = []   # null = basic Attack, otherwise TechResource
var _option_idx: int = 0
var _target_idx: int = 0
var _boost: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	if coordinator:
		coordinator.combat_started.connect(_on_combat_started)
		coordinator.actor_ready_for_command.connect(_on_ready)
		coordinator.ready_pool_changed.connect(_on_pool_changed)
		coordinator.combat_ended.connect(func(_v): _close_command())


func _build() -> void:
	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(top)
	var tv := VBoxContainer.new()
	top.add_child(tv)
	_track = Control.new()
	_track.custom_minimum_size = Vector2(0, 30)
	tv.add_child(_track)
	_pool_label = Label.new()
	_pool_label.add_theme_color_override("font_color", Color(0.55, 0.92, 1.0))
	tv.add_child(_pool_label)

	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(bottom)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 28)
	bottom.add_child(bh)
	_party_label = Label.new()
	_party_label.custom_minimum_size = Vector2(320, 0)
	bh.add_child(_party_label)
	_cmd_panel = VBoxContainer.new()
	_cmd_panel.visible = false
	bh.add_child(_cmd_panel)
	_cmd_header = Label.new()
	_cmd_header.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_cmd_panel.add_child(_cmd_header)
	_cmd_list = Label.new()
	_cmd_panel.add_child(_cmd_list)
	_cmd_status = Label.new()
	_cmd_panel.add_child(_cmd_status)
	_on_pool_changed([])


func _process(_delta: float) -> void:
	if coordinator == null or coordinator.state == CombatTypes.BattleState.EXPLORATION:
		visible = false
		return
	visible = true
	var w: float = maxf(300.0, _track.size.x - 140.0)
	for unit in _tokens.keys():
		var tok: Label = _tokens[unit]
		if not is_instance_valid(unit) or not CombatantStats.of(unit).is_alive():
			tok.visible = false
			continue
		var g: float = coordinator.get_gauge(unit)
		tok.position = Vector2(8.0 + clampf(g / HybridBattleCoordinator.GATE, 0.0, 1.0) * w, 4.0)
		var sh := unit.get_node_or_null("ShieldComponent") as ShieldComponent
		if sh and sh.is_broken:
			tok.text = "[%s BROKEN]" % unit.name
		elif coordinator.ready_pool.has(unit):
			tok.text = "[%s READY]" % unit.name
		else:
			tok.text = "[%s]" % unit.name
	var lines := PackedStringArray(["BOOST POINTS"])
	for ally in coordinator.active_party:
		var bc := ally.get_node_or_null("BoostComponent") as BoostComponent
		var bp: int = bc.current_bp if bc else 0
		var st := CombatantStats.of(ally)
		lines.append("%-6s %s  HP %d  MP %d" % [ally.name, "●".repeat(bp) + "○".repeat(BoostComponent.MAX_BP - bp), st.hp, st.mp])
	_party_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if coordinator == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_W and coordinator.state == CombatTypes.BattleState.TIMELINE_TICK and not coordinator.ready_pool.is_empty():
		coordinator.request_command(coordinator.ready_pool[0])
		return
	if not _cmd_panel.visible or _actor == null:
		return
	if key >= KEY_1 and key <= KEY_9 and key - KEY_1 < _options.size():
		_option_idx = key - KEY_1
		_boost = mini(_boost, _boost_cap())
	match key:
		KEY_TAB:
			_target_idx += 1
		KEY_Q:
			_boost = maxi(0, _boost - 1)
		KEY_E:
			_boost = mini(_boost_cap(), _boost + 1)
		KEY_H:
			var a := _actor
			_close_command()
			coordinator.command_sync_hold(a)
			return
		KEY_SPACE, KEY_ENTER:
			_execute()
			return
	_refresh()


func _on_combat_started(_center: Vector3) -> void:
	for t in _tokens.values():
		t.queue_free()
	_tokens.clear()
	for p in _plates.values():
		p.queue_free()
	_plates.clear()
	for u in coordinator.active_party + coordinator.active_enemies:
		var l := Label.new()
		l.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55) if coordinator.active_party.has(u) else Color(1.0, 0.45, 0.45))
		_track.add_child(l)
		_tokens[u] = l
	for e in coordinator.active_enemies:
		var plate := EnemyShieldPlate.new()
		add_child(plate)
		plate.setup(e, camera_3d)
		_plates[e] = plate


func _on_ready(actor: Node3D, techs: Array[TechResource]) -> void:
	_actor = actor
	_options = [null]
	_options.append_array(techs)
	_option_idx = 0
	_target_idx = 0
	_boost = 0
	_cmd_panel.visible = true
	_refresh()


func _on_pool_changed(pool: Array) -> void:
	var names := PackedStringArray()
	for a in pool:
		names.append(a.name)
	_pool_label.text = "READY POOL: %s   [H] hold on your turn · [W] wake a held ally" % (
		"[" + ", ".join(names) + "]" if not names.is_empty() else "empty")


func _alive_enemies() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for e in coordinator.active_enemies:
		if CombatantStats.of(e).is_alive():
			out.append(e)
	return out


func _current_target() -> Node3D:
	var es := _alive_enemies()
	if es.is_empty():
		return null
	_target_idx = posmod(_target_idx, es.size())
	return es[_target_idx]


func _boost_cap() -> int:
	var opt = _options[_option_idx]
	if opt == null:
		var bc := _actor.get_node_or_null("BoostComponent") as BoostComponent
		return mini(BoostComponent.MAX_SPEND_PER_ACTION, bc.current_bp if bc else 0)
	var comps: Array[BoostComponent] = []
	for c in coordinator.resolve_casters(opt):
		var bc2 := c.get_node_or_null("BoostComponent") as BoostComponent
		if bc2:
			comps.append(bc2)
	return mini(BoostComponent.MAX_SPEND_PER_ACTION, BoostComponent.pooled_bp(comps))


func _refresh() -> void:
	var target := _current_target()
	var opt = _options[_option_idx]
	var rows := PackedStringArray()
	for i in _options.size():
		var o = _options[i]
		var label: String = "Attack" if o == null else "%s %s" % [["", "DUAL", "TRIPLE"][o.tier], o.display_name]
		rows.append("%s[%d] %s" % ["> " if i == _option_idx else "  ", i + 1, label.strip_edges()])
	_cmd_list.text = "\n".join(rows)
	_cmd_header.text = "%s — Tab target · Q/E boost · H hold · Space go" % _actor.name
	_cmd_status.text = "Target: %s   Boost %d/%d" % [target.name if target else "-", _boost, _boost_cap()]

	for p in _plates.values():
		p.set_preview({})
	if target == null:
		return
	if opt == null:
		if decal:
			decal.hide_preview()
		var sh := target.get_node_or_null("ShieldComponent") as ShieldComponent
		if sh and _plates.has(target):
			_plates[target].set_preview(sh.preview_action([CombatantStats.of(_actor).weapon_type], 1 + _boost, 0,
				coordinator.max_shield_shave_per_action))
		return
	if decal:
		decal.show_preview(opt, _actor, target, _boost)
	var hits := TacticalPositioner3D.get_targets_in_tech_aoe(opt, _actor, target, _boost, _alive_enemies())
	var bonus: int = 1 if _boost == BoostComponent.MAX_SPEND_PER_ACTION else 0
	for e in hits:
		var sh2 := e.get_node_or_null("ShieldComponent") as ShieldComponent
		if sh2 and _plates.has(e):
			_plates[e].set_preview(sh2.preview_action(opt.damage_tags, opt.hit_count, bonus,
				coordinator.max_shield_shave_per_action))


func _execute() -> void:
	var target := _current_target()
	var opt = _options[_option_idx]
	var a := _actor
	var b := _boost
	_close_command()
	var r: Dictionary = coordinator.execute_basic_attack(a, target, b) if opt == null \
		else coordinator.execute_tech(opt, a, target, b)
	if not r.get("ok", false):
		push_warning("Command rejected: %s" % r.get("error", "?"))
		if coordinator.active_actor == a:
			_on_ready(a, coordinator.get_available_techs(a))


func _close_command() -> void:
	_cmd_panel.visible = false
	_actor = null
	if decal:
		decal.hide_preview()
	for p in _plates.values():
		p.set_preview({})
