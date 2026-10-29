## The battle HUD (Reference Bible §7.2): the Turn Bar with Sync Hold at 99.0, the party panel with
## Crono's crack portrait and Sera's translucency ring, the shared BP pips, the command deck, enemy shield
## plates with the preview math, telegraph-synced plate pulses, and damage numbers. Built in code.
class_name BattleHUD
extends CanvasLayer

signal command_chosen(cmd: String, payload: Dictionary)
signal target_changed(index: int)
signal boost_changed(level: int)
signal cancelled

const INK := Color("#161821")
const CREAM := Color("#F2EAD7")
const PALE := Color("#E1DAC8")
const DARK := Color("#2D3039")
const GOLD := Color("#D4AF37")
const CYAN := Color(0.25, 0.85, 1.0)
const ORANGE := Color(1.0, 0.65, 0.15)

var root: Control
var turn_bar: Control
var turn_markers: Dictionary = {}
var party_panel: VBoxContainer
var party_rows: Dictionary = {}
var bp_box: HBoxContainer
var bp_pips: Array[ColorRect] = []
var bp_label: Label
var deck: VBoxContainer
var deck_title: Label
var deck_items: Array[Dictionary] = []
var deck_buttons: Array[Label] = []
var deck_index: int = 0
var deck_open: bool = false
var preview_label: Label
var boost_label: Label
var message_label: Label
var plates: Dictionary = {}
var numbers: Array[Dictionary] = []
var sync_tint: ColorRect
var coordinator: BattleCoordinator
var camera: Camera3D
var _msg_tween: Tween
var targeting: bool = false
var boost_level: int = 0
var _flow_time_label: Label


func _ready() -> void:
	layer = 30
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	sync_tint = ColorRect.new()
	sync_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	sync_tint.color = Color(0.1, 0.12, 0.2, 0.0)
	sync_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sync_tint)
	_build_turn_bar()
	_build_party_panel()
	_build_bp()
	_build_deck()
	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	message_label.offset_top = 34
	message_label.offset_left = -220
	message_label.offset_right = 220
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 11)
	message_label.add_theme_color_override("font_color", PALE)
	message_label.modulate.a = 0.0
	root.add_child(message_label)
	_flow_time_label = Label.new()
	_flow_time_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_flow_time_label.offset_left = -70
	_flow_time_label.offset_top = 26
	_flow_time_label.add_theme_font_size_override("font_size", 8)
	_flow_time_label.add_theme_color_override("font_color", Color(PALE, 0.6))
	root.add_child(_flow_time_label)


func _frame(color: Color = INK, border: Color = CREAM) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.92)
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_content_margin_all(5)
	return sb


# ---------------------------------------------------------------- turn bar

func _build_turn_bar() -> void:
	turn_bar = Control.new()
	turn_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	turn_bar.offset_left = 60
	turn_bar.offset_right = -60
	turn_bar.offset_top = 8
	turn_bar.offset_bottom = 26
	root.add_child(turn_bar)
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", _frame(DARK, PALE))
	turn_bar.add_child(bg)
	var gate := ColorRect.new()
	gate.color = GOLD
	gate.anchor_left = 0.99
	gate.anchor_right = 0.99
	gate.offset_left = -1
	gate.offset_right = 1
	gate.anchor_top = 0.0
	gate.anchor_bottom = 1.0
	turn_bar.add_child(gate)
	var gl := Label.new()
	gl.text = "99"
	gl.add_theme_font_size_override("font_size", 7)
	gl.add_theme_color_override("font_color", GOLD)
	gl.anchor_left = 0.99
	gl.anchor_right = 0.99
	gl.offset_left = -12
	gl.offset_top = 18
	turn_bar.add_child(gl)


func register_units(party: Array, enemies: Array, hover: Node = null) -> void:
	for k in turn_markers.keys():
		turn_markers[k].queue_free()
	turn_markers.clear()
	var all: Array = party.duplicate()
	all.append_array(enemies)
	if hover != null:
		all.append(hover)
	for u in all:
		var st := CombatantStats.of(u)
		var m := Panel.new()
		m.custom_minimum_size = Vector2(14, 14)
		m.size = Vector2(14, 14)
		var is_party: bool = st != null and st.team == CombatantStats.Team.PARTY
		var sb := _frame(_actor_colour(st) if is_party else Color(0.35, 0.2, 0.2), CREAM if is_party else Color(0.9, 0.5, 0.4))
		sb.set_content_margin_all(0)
		m.add_theme_stylebox_override("panel", sb)
		var l := Label.new()
		l.text = String(st.actor_id).left(2).to_upper() if st != null else "?"
		l.add_theme_font_size_override("font_size", 7)
		l.add_theme_color_override("font_color", CREAM)
		l.position = Vector2(1, 1)
		m.add_child(l)
		turn_bar.add_child(m)
		turn_markers[u] = m
	for k in party_rows.keys():
		party_rows[k].queue_free()
	party_rows.clear()
	for u in party:
		_add_party_row(u)
	if hover != null:
		_add_party_row(hover, true)


func _actor_colour(st: CombatantStats) -> Color:
	if st == null:
		return DARK
	match st.actor_id:
		&"crono":
			return Color(0.26, 0.31, 0.52)
		&"sera":
			return Color(0.40, 0.33, 0.62)
		&"krona":
			return Color(0.45, 0.12, 0.12)
		&"cassia":
			return Color(0.55, 0.38, 0.18)
		&"marle":
			return Color(0.25, 0.42, 0.6)
	return DARK


func update_turn_bar() -> void:
	if coordinator == null:
		return
	var w: float = turn_bar.size.x
	for u in turn_markers.keys():
		if not is_instance_valid(u):
			continue
		var m: Panel = turn_markers[u]
		var g: float = coordinator.get_gauge(u)
		var st := CombatantStats.of(u)
		m.visible = st != null and st.is_alive()
		m.position = Vector2(clampf(g / 100.0, 0.0, 1.0) * (w - 14.0), 2.0)
		var broken: bool = coordinator.is_broken(u)
		m.modulate = Color(1, 0.85, 0.4) if broken else (Color(1, 1, 1, 1) if not coordinator.ready_pool.has(u) else Color(0.8, 1.0, 1.0))
		if coordinator.wind_ups.has(u):
			var wu: Dictionary = coordinator.wind_ups[u]
			var t: float = 1.0 - float(wu["left"]) / maxf(0.01, float(wu["total"]))
			m.modulate = CYAN.lerp(ORANGE, t)
	_flow_time_label.text = "t %.1f" % coordinator.battle_time


# ---------------------------------------------------------------- party panel

func _build_party_panel() -> void:
	party_panel = VBoxContainer.new()
	party_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	party_panel.offset_left = 8
	party_panel.offset_top = -112
	party_panel.offset_bottom = -8
	party_panel.offset_right = 190
	party_panel.add_theme_constant_override("separation", 2)
	root.add_child(party_panel)


func _add_party_row(u: Node, hover: bool = false) -> void:
	var st := CombatantStats.of(u)
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _frame())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	row.add_child(h)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(22, 22)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = PortraitCache.get_portrait(String(st.actor_id))
	h.add_child(portrait)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var name_l := Label.new()
	name_l.text = st.display_name + ("  (hover)" if hover else "")
	name_l.add_theme_font_size_override("font_size", 8)
	name_l.add_theme_color_override("font_color", PALE)
	v.add_child(name_l)
	var hp := ProgressBar.new()
	hp.custom_minimum_size = Vector2(120, 6)
	hp.show_percentage = false
	hp.max_value = 1.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.3, 0.3)
	var back := StyleBoxFlat.new()
	back.bg_color = DARK
	hp.add_theme_stylebox_override("fill", fill)
	hp.add_theme_stylebox_override("background", back)
	v.add_child(hp)
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 7)
	sub.add_theme_color_override("font_color", CREAM)
	v.add_child(sub)
	party_panel.add_child(row)
	party_rows[u] = row
	row.set_meta("hp", hp)
	row.set_meta("sub", sub)
	row.set_meta("name", name_l)
	row.set_meta("portrait", portrait)


func update_party() -> void:
	for u in party_rows.keys():
		if not is_instance_valid(u):
			continue
		var row: PanelContainer = party_rows[u]
		var st := CombatantStats.of(u)
		var hp: ProgressBar = row.get_meta("hp")
		hp.value = st.hp_ratio()
		var sub: Label = row.get_meta("sub")
		var text: String = "HP %d/%d" % [st.hp, st.max_hp()]
		var td := TimeDebtComponent.of(u)
		if td != null:
			var state: int = td.crack_state(float(st.hp) / float(maxi(1, st.base_max_hp)))
			var names: Array = ["", "hairline", "GALAXY", "flatline"]
			text += "  ceiling %d%%" % roundi(td.max_hp_factor() * 100.0)
			if state > 0:
				text += "  " + names[state]
			(row.get_meta("portrait") as TextureRect).modulate = [Color.WHITE, Color(1, 0.95, 0.8), Color(0.8, 0.85, 1.0), Color(0.5, 0.5, 0.5)][state]
		else:
			text += "  MP %d/%d" % [st.mp, st.max_mp]
		var sol := SolidityComponent.of(u)
		if sol != null:
			text += "  solidity %d%%" % roundi(sol.solidity)
			if sol.is_phased():
				text += "  PHASED (%d)" % sol.phased_turns_left
			(row.get_meta("portrait") as TextureRect).modulate.a = clampf(sol.solidity / 100.0, 0.25, 1.0)
		var sc := StatusComponent.of(u)
		if sc != null and not sc.statuses.is_empty():
			var ids: Array = sc.ids()
			var short: Array = []
			for id in ids.slice(0, 3):
				short.append(String(id))
			text += "  [" + ", ".join(PackedStringArray(short)) + "]"
		if st.is_guarding:
			text += "  GUARD"
		sub.text = text
		(row.get_meta("name") as Label).add_theme_color_override("font_color", GOLD if coordinator != null and coordinator.active_actor == u else PALE)
		row.modulate.a = 1.0 if st.is_alive() else 0.45


# ---------------------------------------------------------------- BP

func _build_bp() -> void:
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.offset_left = -150
	box.offset_right = -8
	box.offset_top = -40
	box.offset_bottom = -8
	box.add_theme_stylebox_override("panel", _frame())
	root.add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	bp_label = Label.new()
	bp_label.text = "BOOST"
	bp_label.add_theme_font_size_override("font_size", 8)
	bp_label.add_theme_color_override("font_color", PALE)
	v.add_child(bp_label)
	bp_box = HBoxContainer.new()
	bp_box.add_theme_constant_override("separation", 3)
	v.add_child(bp_box)
	for i in 6:
		var p := ColorRect.new()
		p.custom_minimum_size = Vector2(14, 8)
		p.color = DARK
		bp_box.add_child(p)
		bp_pips.append(p)


func update_bp() -> void:
	if coordinator == null:
		return
	for i in bp_pips.size():
		bp_pips[i].visible = i < coordinator.bank.max_bp
		if i < coordinator.bank.bp:
			bp_pips[i].color = GOLD if i < boost_level and targeting else CREAM
		else:
			bp_pips[i].color = DARK
	bp_label.text = "BOOST %d/%d" % [coordinator.bank.bp, coordinator.bank.max_bp] + ("   Lv%d  %d%%" % [boost_level, roundi(CombatConstants.BOOST_POWER[boost_level] * 100.0)] if targeting else "")


# ---------------------------------------------------------------- command deck

func _build_deck() -> void:
	var box := PanelContainer.new()
	box.name = "Deck"
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -70
	box.offset_right = 110
	box.offset_top = -118
	box.offset_bottom = -8
	box.add_theme_stylebox_override("panel", _frame())
	root.add_child(box)
	deck = VBoxContainer.new()
	deck.add_theme_constant_override("separation", 1)
	box.add_child(deck)
	deck_title = Label.new()
	deck_title.add_theme_font_size_override("font_size", 8)
	deck_title.add_theme_color_override("font_color", GOLD)
	deck.add_child(deck_title)
	box.visible = false
	deck.set_meta("box", box)
	preview_label = Label.new()
	preview_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	preview_label.offset_left = -200
	preview_label.offset_right = 200
	preview_label.offset_top = -138
	preview_label.offset_bottom = -120
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.add_theme_font_size_override("font_size", 9)
	preview_label.add_theme_color_override("font_color", CREAM)
	preview_label.visible = false
	root.add_child(preview_label)


## items: [{label, cmd, payload, enabled}]
func open_deck(title: String, items: Array) -> void:
	deck_items = items
	for b in deck_buttons:
		b.queue_free()
	deck_buttons.clear()
	deck_title.text = title
	for it in items:
		var l := Label.new()
		l.text = String(it.get("label", "?"))
		l.add_theme_font_size_override("font_size", 9)
		l.add_theme_color_override("font_color", CREAM if bool(it.get("enabled", true)) else Color(CREAM, 0.4))
		deck.add_child(l)
		deck_buttons.append(l)
	deck_index = 0
	_refresh_deck()
	(deck.get_meta("box") as Control).visible = true
	deck_open = true


func close_deck() -> void:
	(deck.get_meta("box") as Control).visible = false
	deck_open = false


func _refresh_deck() -> void:
	for i in deck_buttons.size():
		var it: Dictionary = deck_items[i]
		var sel: bool = i == deck_index
		deck_buttons[i].text = ("▸ " if sel else "  ") + String(it.get("label", "?"))
		var enabled: bool = bool(it.get("enabled", true))
		deck_buttons[i].add_theme_color_override("font_color", (GOLD if sel else CREAM) if enabled else Color(CREAM, 0.4))


func deck_move(d: int) -> void:
	if deck_buttons.is_empty():
		return
	deck_index = wrapi(deck_index + d, 0, deck_buttons.size())
	_refresh_deck()


func deck_confirm() -> void:
	if deck_items.is_empty():
		return
	var it: Dictionary = deck_items[deck_index]
	if not bool(it.get("enabled", true)):
		Audio.play_sfx("ui/error")
		return
	command_chosen.emit(String(it.get("cmd", "")), it.get("payload", {}))


func set_targeting(on: bool) -> void:
	targeting = on
	preview_label.visible = on
	update_bp()


func set_preview(text: String) -> void:
	preview_label.text = text


# ---------------------------------------------------------------- plates

func ensure_plate(enemy: Node) -> Control:
	if plates.has(enemy):
		return plates[enemy]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _frame(INK, PALE))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var l1 := Label.new()
	l1.add_theme_font_size_override("font_size", 8)
	l1.add_theme_color_override("font_color", CREAM)
	v.add_child(l1)
	var l2 := Label.new()
	l2.add_theme_font_size_override("font_size", 7)
	l2.add_theme_color_override("font_color", PALE)
	v.add_child(l2)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(60, 2)
	bar.color = GOLD
	bar.visible = false
	v.add_child(bar)
	p.set_meta("l1", l1)
	p.set_meta("l2", l2)
	p.set_meta("bar", bar)
	root.add_child(p)
	plates[enemy] = p
	return p


func update_plates(previews: Dictionary, blind: bool, target: Node) -> void:
	if camera == null or coordinator == null:
		return
	for e in plates.keys():
		var p: PanelContainer = plates[e]
		if not is_instance_valid(e):
			p.visible = false
			continue
		var st := CombatantStats.of(e)
		var sh := ShieldComponent.of(e)
		if st == null or not st.is_alive() or coordinator.spared.has(e):
			p.visible = false
			continue
		var head: Vector3 = (e as Node3D).global_position + Vector3(0, (e.height_m if e is CombatActor else 1.8) + 0.3, 0)
		if camera.is_position_behind(head):
			p.visible = false
			continue
		p.visible = true
		var sp: Vector2 = camera.unproject_position(head)
		var scale: float = root.size.x / float(get_viewport().get_visible_rect().size.x)
		p.position = sp * scale - Vector2(p.size.x * 0.5, p.size.y)
		var l1: Label = p.get_meta("l1")
		var l2: Label = p.get_meta("l2")
		var bar: ColorRect = p.get_meta("bar")
		if sh == null:
			l1.text = st.display_name
			l2.text = "HP %d" % st.hp
			continue
		var line: String
		if sh.is_broken:
			line = "[BREAK]"
			l1.add_theme_color_override("font_color", GOLD)
			bar.visible = true
			bar.custom_minimum_size.x = 60.0 * sh.rebuild_ratio()
		else:
			bar.visible = false
			l1.add_theme_color_override("font_color", CREAM)
			var shown: int = sh.display_number()
			if previews.has(e):
				var pv: Dictionary = previews[e]
				var after: int = maxi(0, shown - int(pv["shave"]))
				line = "[SHIELD %d -> %d (-%d)%s]" % [shown, after, int(pv["shave"]), " -> BREAK!" if bool(pv["breaks"]) else ""]
				if bool(pv["breaks"]):
					l1.add_theme_color_override("font_color", GOLD)
			else:
				line = "[SHIELD %d]" % shown
			if sh.uses_keyed_plates() and sh.current_key() != &"":
				line += " %s->%s" % [CombatTags.short(sh.current_material()), CombatTags.short(sh.current_key())]
		if e == target:
			line = "◆ " + line
		l1.text = line
		var tags: Array[String] = []
		var vis: Array[StringName] = sh.visible_weaknesses(blind)
		for w in vis:
			tags.append("[%s]" % CombatTags.short(w))
		for i in range(vis.size(), sh.weaknesses.size()):
			tags.append("[?]")
		var hp_txt: String = "  %s  %d%%" % [st.display_name, roundi(st.hp_ratio() * 100.0)]
		l2.text = " ".join(PackedStringArray(tags)) + hp_txt
		if coordinator.wind_ups.has(e):
			var wu: Dictionary = coordinator.wind_ups[e]
			var t: float = 1.0 - float(wu["left"]) / maxf(0.01, float(wu["total"]))
			p.modulate = Color.WHITE.lerp(ORANGE, 0.5 + 0.5 * sin(t * TAU * 2.0) * 0.5 + t * 0.5)
		else:
			p.modulate = Color.WHITE


# ---------------------------------------------------------------- numbers and messages

func spawn_number(world_pos: Vector3, text: String, color: Color, big: bool = false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14 if big else 10)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 3)
	root.add_child(l)
	numbers.append({"label": l, "pos": world_pos + Vector3(randf_range(-0.3, 0.3), 1.6, 0), "t": 0.0})


func _process(delta: float) -> void:
	if camera == null:
		return
	var scale: float = root.size.x / float(get_viewport().get_visible_rect().size.x)
	for n in numbers.duplicate():
		n["t"] = float(n["t"]) + delta
		var t: float = float(n["t"])
		var l: Label = n["label"]
		if t > 1.1:
			l.queue_free()
			numbers.erase(n)
			continue
		var p: Vector3 = n["pos"] + Vector3(0, t * 0.9, 0)
		if camera.is_position_behind(p):
			l.visible = false
			continue
		l.visible = true
		l.position = camera.unproject_position(p) * scale - l.size * 0.5
		l.modulate.a = 1.0 - maxf(0.0, t - 0.7) / 0.4
	if coordinator != null:
		update_turn_bar()
		update_party()
		update_bp()
		var hold: bool = coordinator.state == BattleCoordinator.State.COMMAND_WAIT
		sync_tint.color.a = lerpf(sync_tint.color.a, 0.18 if hold else 0.0, delta * 8.0)


func show_message(text: String) -> void:
	message_label.text = text
	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()
	message_label.modulate.a = 1.0
	_msg_tween = create_tween()
	_msg_tween.tween_interval(1.8)
	_msg_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)
