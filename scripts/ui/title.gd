## The title screen: the Horologe behind paper grain, the title, and a small menu.
extends Control

var menu: VBoxContainer
var items: Array[Label] = []
var index: int = 0
var options_open: bool = false
var _t: float = 0.0
var backdrop: TextureRect
var subtitle: Label
var _busy: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Universe.set_universe(0, true)
	backdrop = TextureRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if ResourceLoader.exists("res://assets/ui/title/title_backdrop.jpg"):
		backdrop.texture = load("res://assets/ui/title/title_backdrop.jpg")
	backdrop.modulate = Color(0.75, 0.72, 0.68)
	add_child(backdrop)
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.05, 0.04, 0.03, 0.35)
	add_child(vignette)
	var paper := ColorRect.new()
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.material = _paper_material()
	add_child(paper)
	var title := Label.new()
	title.text = "TRIGGER"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#F2EAD7"))
	title.add_theme_color_override("font_shadow_color", Color(0.1, 0.08, 0.05, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.position = Vector2(40, 34)
	add_child(title)
	subtitle = Label.new()
	subtitle.text = "Time Debt"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color("#D4AF37"))
	subtitle.position = Vector2(42, 72)
	add_child(subtitle)
	var rule := ColorRect.new()
	rule.color = Color("#D4AF37")
	rule.position = Vector2(42, 92)
	rule.size = Vector2(140, 1)
	add_child(rule)
	menu = VBoxContainer.new()
	menu.position = Vector2(42, 104)
	menu.add_theme_constant_override("separation", 5)
	add_child(menu)
	_build_menu()
	var foot := Label.new()
	foot.text = "a sequel to Chrono Trigger  ·  Godot 4.7  ·  arrows / Enter"
	foot.add_theme_font_size_override("font_size", 7)
	foot.add_theme_color_override("font_color", Color(0.9, 0.86, 0.78, 0.7))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(42, 338)
	add_child(foot)
	Audio.play_music(&"mus_title", 1.0)
	Router.adopt_current_scene()


func _build_menu() -> void:
	for l in items:
		l.queue_free()
	items.clear()
	var entries: Array[String] = ["New Game"]
	if Saves.exists(0):
		var p: Dictionary = Saves.peek(0)
		var g: Dictionary = p.get("game", {})
		entries.append("Continue  —  Ch.%d  ·  integrity %d%%" % [int(g.get("chapter", 0)), roundi(float(g.get("crono_integrity", 100.0)))])
	entries.append("Options")
	entries.append("Quit")
	for e in entries:
		var l := Label.new()
		l.text = e
		l.add_theme_font_size_override("font_size", 10)
		menu.add_child(l)
		items.append(l)
	index = 0
	_refresh()


func _refresh() -> void:
	for i in items.size():
		var sel: bool = i == index
		items[i].add_theme_color_override("font_color", Color("#F2EAD7") if sel else Color(0.75, 0.72, 0.66))
		items[i].text = ("▸ " if sel else "   ") + items[i].text.trim_prefix("▸ ").trim_prefix("   ")


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event.is_action_pressed("move_down"):
		index = wrapi(index + 1, 0, items.size())
		Audio.play_sfx("ui/cursor")
		_refresh()
	elif event.is_action_pressed("move_up"):
		index = wrapi(index - 1, 0, items.size())
		Audio.play_sfx("ui/cursor")
		_refresh()
	elif event.is_action_pressed("confirm"):
		_choose()


func _choose() -> void:
	var text: String = items[index].text.trim_prefix("▸ ").trim_prefix("   ")
	Audio.play_sfx("ui/confirm")
	if text.begins_with("New Game"):
		_busy = true
		Game.new_game()
		Flags.reset_cycle()
		Router.go(&"guardia_kitchen", &"start", 1.0)
	elif text.begins_with("Continue"):
		_busy = true
		if Saves.load(0):
			Router.go(Game.location, Game.spawn_point, 0.8)
		else:
			_busy = false
	elif text.begins_with("Options"):
		_toggle_options()
	elif text.begins_with("Quit"):
		get_tree().quit()


func _toggle_options() -> void:
	# A compact options list: cycles the accessibility settings most players need first.
	var flicker: bool = bool(Game.settings.get("reduced_flicker", false))
	Game.set_setting("reduced_flicker", not flicker)
	var speed: float = float(Game.settings.get("flow_speed", 1.0))
	Game.set_setting("flow_speed", 0.8 if speed >= 1.0 else 1.0)
	subtitle.text = "Time Debt   ·   reduced flicker %s, battle flow ×%.1f" % ["on" if not flicker else "off", float(Game.settings.get("flow_speed", 1.0))]


func _process(delta: float) -> void:
	_t += delta
	backdrop.position = Vector2(sin(_t * 0.07) * 4.0, cos(_t * 0.05) * 3.0)


func _paper_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D paper : hint_default_white;
void fragment() {
	vec2 uv = SCREEN_UV * vec2(3.2, 1.8);
	float g = fract(sin(dot(floor(uv * 400.0), vec2(12.9898, 78.233))) * 43758.5453);
	float grain = 0.5 + 0.5 * g;
	COLOR = vec4(vec3(0.96, 0.93, 0.86), 0.10 * grain);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
