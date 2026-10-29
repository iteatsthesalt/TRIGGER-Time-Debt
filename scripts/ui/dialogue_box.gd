## The dialogue box (Reference Bible §7.6): cream text on ink, a portrait, a name tag, a typewriter,
## and a choice list. Crono's wheel is a choice with [Nod] / [Look Away] / [Say Sera's Name].
class_name DialogueBox
extends Control

signal advanced
signal chosen(index: int)

const INK := Color("#161821")
const CREAM := Color("#F2EAD7")
const PALE := Color("#E1DAC8")
const DARK := Color("#2D3039")
const TYPE_CPS := 45.0

var panel: PanelContainer
var name_label: Label
var text_label: RichTextLabel
var portrait: TextureRect
var choice_box: VBoxContainer
var caption_label: Label
var prompt_arrow: Label
var _typing: bool = false
var _wait_advance: bool = false
var _choice_index: int = -1
var _choice_buttons: Array[Button] = []
var _vaelos_style: bool = false


func _ready() -> void:
	# Created by an autoload before the window settles, so no anchors: sized to the viewport by hand.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_top = 1.0
	panel.offset_top = -96
	panel.offset_bottom = -8
	panel.offset_left = 20
	panel.offset_right = -20
	panel.add_theme_stylebox_override("panel", _frame_style())
	add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	h.add_child(portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	name_label = Label.new()
	name_label.add_theme_color_override("font_color", PALE)
	name_label.add_theme_font_size_override("font_size", 9)
	v.add_child(name_label)
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = false
	text_label.scroll_active = false
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.add_theme_color_override("default_color", CREAM)
	text_label.add_theme_font_size_override("normal_font_size", 11)
	v.add_child(text_label)
	choice_box = VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 2)
	v.add_child(choice_box)
	prompt_arrow = Label.new()
	prompt_arrow.text = "▼"
	prompt_arrow.add_theme_color_override("font_color", PALE)
	prompt_arrow.add_theme_font_size_override("font_size", 9)
	prompt_arrow.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	prompt_arrow.offset_left = -34
	prompt_arrow.offset_top = -24
	prompt_arrow.offset_right = -24
	prompt_arrow.offset_bottom = -12
	prompt_arrow.visible = false
	add_child(prompt_arrow)
	caption_label = Label.new()
	caption_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caption_label.offset_top = 12
	caption_label.offset_left = -220
	caption_label.offset_right = 220
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.add_theme_color_override("font_color", PALE)
	caption_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	caption_label.add_theme_constant_override("shadow_offset_y", 1)
	caption_label.add_theme_font_size_override("font_size", 9)
	caption_label.visible = false
	add_child(caption_label)


func _fit_viewport() -> void:
	var r: Rect2 = get_viewport().get_visible_rect()
	position = r.position
	size = r.size


func _frame_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(INK, 0.94)
	sb.border_color = CREAM
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(8)
	sb.skew = Vector2(0.0, 0.0)
	return sb


func _process(delta: float) -> void:
	if _typing:
		text_label.visible_characters += int(ceil(TYPE_CPS * delta))
		if text_label.visible_characters >= text_label.get_total_character_count():
			text_label.visible_characters = -1
			_typing = false
			prompt_arrow.visible = _wait_advance


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("confirm"):
		if _typing:
			text_label.visible_characters = -1
			_typing = false
			prompt_arrow.visible = _wait_advance
			get_viewport().set_input_as_handled()
		elif _wait_advance:
			_wait_advance = false
			prompt_arrow.visible = false
			advanced.emit()
			get_viewport().set_input_as_handled()
		elif not _choice_buttons.is_empty():
			_pick(_choice_index)
			get_viewport().set_input_as_handled()
	elif not _choice_buttons.is_empty():
		if event.is_action_pressed("move_up"):
			_set_choice(_choice_index - 1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_down"):
			_set_choice(_choice_index + 1)
			get_viewport().set_input_as_handled()


## Show a line and wait for confirm (or auto_advance seconds when > 0).
func say(who: String, text: String, expression: String = "neutral", style: String = "", auto_advance: float = -1.0) -> void:
	visible = true
	panel.visible = true
	_clear_choices()
	var speaker: Dictionary = SpeakerStyles.get_style(who)
	name_label.text = String(speaker.get("name", who.capitalize()))
	name_label.add_theme_color_override("font_color", speaker.get("color", PALE))
	_vaelos_style = (who == "vaelos")
	var sb: StyleBoxFlat = _frame_style()
	if _vaelos_style or style == "clean":
		sb.bg_color = Color(0.02, 0.02, 0.03, 0.98)
		sb.border_color = Color(0.9, 0.9, 0.95)
	elif style == "robo":
		sb.border_color = Color(0.72, 0.62, 0.38)
	panel.add_theme_stylebox_override("panel", sb)
	portrait.texture = PortraitCache.get_portrait(who, expression)
	portrait.visible = portrait.texture != null
	text_label.text = text
	text_label.visible_characters = 0
	_typing = true
	_wait_advance = true
	if auto_advance > 0.0:
		# Probes and smoke runs: very short auto-advance means instant text.
		var t: float = auto_advance + (float(text.length()) / TYPE_CPS if auto_advance >= 0.5 else 0.0)
		if auto_advance < 0.5:
			text_label.visible_characters = -1
			_typing = false
		get_tree().create_timer(t).timeout.connect(func() -> void:
			if _wait_advance:
				_wait_advance = false
				prompt_arrow.visible = false
				advanced.emit())
	await advanced


func caption(text: String, seconds: float) -> void:
	caption_label.text = text
	caption_label.visible = true
	await get_tree().create_timer(seconds).timeout
	caption_label.visible = false


## Show options and return the chosen index.
func choose(who: String, prompt: String, options: Array, auto: int = -1) -> int:
	visible = true
	panel.visible = true
	_clear_choices()
	if who != "":
		var speaker: Dictionary = SpeakerStyles.get_style(who)
		name_label.text = String(speaker.get("name", who.capitalize()))
	text_label.text = prompt
	text_label.visible_characters = -1
	_typing = false
	_wait_advance = false
	for i in options.size():
		var b := Button.new()
		b.text = String(options[i].get("text", "..."))
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", CREAM)
		b.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.6))
		b.add_theme_font_size_override("font_size", 10)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pick.bind(i))
		choice_box.add_child(b)
		_choice_buttons.append(b)
	_set_choice(0)
	if auto >= 0:
		get_tree().create_timer(0.05).timeout.connect(func() -> void: _pick(clampi(auto, 0, options.size() - 1)))
	var idx: int = await chosen
	_clear_choices()
	return idx


func _set_choice(i: int) -> void:
	if _choice_buttons.is_empty():
		return
	_choice_index = wrapi(i, 0, _choice_buttons.size())
	for j in _choice_buttons.size():
		_choice_buttons[j].text = ("▸ " if j == _choice_index else "  ") + _choice_buttons[j].text.trim_prefix("▸ ").trim_prefix("  ")
		_choice_buttons[j].add_theme_color_override("font_color", Color(1, 0.9, 0.6) if j == _choice_index else CREAM)


func _pick(i: int) -> void:
	if _choice_buttons.is_empty():
		return
	chosen.emit(i)


func _clear_choices() -> void:
	for b in _choice_buttons:
		b.queue_free()
	_choice_buttons.clear()
	_choice_index = -1


func hide_box() -> void:
	visible = false
	_clear_choices()
	_typing = false
	_wait_advance = false
