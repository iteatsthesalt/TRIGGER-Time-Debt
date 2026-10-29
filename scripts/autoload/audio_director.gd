## The AudioDirector (Reference Bible §8.2): buses, RTPCs, music with stems, SFX pools.
## Autoload name: Audio. Everything degrades gracefully when a file is missing.
extends Node

signal music_changed(track_id: StringName)

const MUSIC_DIR := "res://audio/music"
const SFX_DIR := "res://audio/sfx"
const AMB_DIR := "res://audio/ambience"
const VO_DIR := "res://audio/vo"

var rtpc: Dictionary = {
	"porcelain_stress": 0.0, "vhs_tracking": 0.0, "mycelia_shared": 12.0, "bp_stolen": 0.0, "shave_bonus": 0.0,
	"translucency": 100.0, "camera_fov": 32.0, "glow_intensity": 50.0, "grief_resonance": 0.0, "breath": 100.0, "heartbeat": 72.0,
}
var current_track: StringName = &""
var _music_players: Array[AudioStreamPlayer] = []
var _ambience_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _vo_player: AudioStreamPlayer
var _stream_cache: Dictionary = {}
var _music_fade: Tween
var _lowpass: AudioEffectLowPassFilter
var _pitch: AudioEffectPitchShift
var _master_set: bool = false


func _ready() -> void:
	_setup_buses()
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = &"Ambience"
	add_child(_ambience_player)
	_vo_player = AudioStreamPlayer.new()
	_vo_player.bus = &"VO"
	add_child(_vo_player)
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)
	if is_instance_valid(Game):
		Game.settings_changed.connect(_apply_volumes)
		_apply_volumes()


func _setup_buses() -> void:
	var names: Array[StringName] = [&"Music", &"Ambience", &"SFX", &"VO", &"Sub"]
	for n in names:
		if AudioServer.get_bus_index(n) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, n)
			AudioServer.set_bus_send(idx, &"Master")
	var music_idx: int = AudioServer.get_bus_index(&"Music")
	if music_idx >= 0 and AudioServer.get_bus_effect_count(music_idx) == 0:
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(music_idx, _lowpass)
		_pitch = AudioEffectPitchShift.new()
		_pitch.pitch_scale = 1.0
		AudioServer.add_bus_effect(music_idx, _pitch)
		AudioServer.set_bus_effect_enabled(music_idx, 1, false)


func _apply_volumes() -> void:
	_set_bus_volume(&"Music", float(Game.settings.get("music", 0.8)))
	_set_bus_volume(&"Ambience", float(Game.settings.get("music", 0.8)))
	_set_bus_volume(&"SFX", float(Game.settings.get("sfx", 0.9)))
	_set_bus_volume(&"VO", float(Game.settings.get("voice", 1.0)))


func _set_bus_volume(bus: StringName, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, linear)))


func _load(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		_stream_cache[path] = null
		return null
	var s: AudioStream = load(path) as AudioStream
	_stream_cache[path] = s
	return s


## Play a music track with any number of stems: audio/music/<track>__<stem>.ogg, or <track>.ogg.
func play_music(track_id: StringName, fade_s: float = 1.5, stems: Array = []) -> void:
	if track_id == current_track:
		return
	stop_music(fade_s)
	current_track = track_id
	var paths: Array[String] = []
	if stems.is_empty():
		paths.append("%s/%s.ogg" % [MUSIC_DIR, track_id])
		for stem in ["box", "piano", "strings", "hiss", "bass", "drums", "lead", "pad", "quartet", "crackle", "wind", "tick"]:
			var p: String = "%s/%s__%s.ogg" % [MUSIC_DIR, track_id, stem]
			if ResourceLoader.exists(p):
				paths.append(p)
	else:
		for stem2 in stems:
			paths.append("%s/%s__%s.ogg" % [MUSIC_DIR, track_id, stem2])
	for path in paths:
		var stream: AudioStream = _load(path)
		if stream == null:
			continue
		var p2 := AudioStreamPlayer.new()
		p2.bus = &"Music"
		p2.stream = stream
		p2.volume_db = -40.0
		add_child(p2)
		p2.play()
		_music_players.append(p2)
		var tw := create_tween()
		tw.tween_property(p2, "volume_db", 0.0, fade_s)
	music_changed.emit(track_id)


func stop_music(fade_s: float = 1.0) -> void:
	for p in _music_players:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -40.0, fade_s)
		tw.tween_callback(p.queue_free)
	_music_players.clear()
	current_track = &""


func set_stem_volume(stem_index: int, linear: float, fade_s: float = 0.5) -> void:
	if stem_index < 0 or stem_index >= _music_players.size():
		return
	var tw := create_tween()
	tw.tween_property(_music_players[stem_index], "volume_db", linear_to_db(maxf(0.0001, linear)), fade_s)


func play_ambience(id: StringName, fade_s: float = 2.0) -> void:
	var stream: AudioStream = _load("%s/%s.ogg" % [AMB_DIR, id])
	if stream == null:
		_ambience_player.stop()
		return
	if _ambience_player.stream == stream and _ambience_player.playing:
		return
	_ambience_player.stream = stream
	_ambience_player.volume_db = -30.0
	_ambience_player.play()
	var tw := create_tween()
	tw.tween_property(_ambience_player, "volume_db", -6.0, fade_s)


## Play a one-shot: audio/sfx/<family>/<id>.wav, trying numbered variations <id>_01..05.
func play_sfx(id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _find_sfx(id)
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return
	_sfx_pool[0].stream = stream
	_sfx_pool[0].volume_db = volume_db
	_sfx_pool[0].pitch_scale = pitch
	_sfx_pool[0].play()


func _find_sfx(id: String) -> AudioStream:
	var base: String = "%s/%s" % [SFX_DIR, id]
	var variants: Array[String] = []
	for i in range(1, 6):
		var p: String = "%s_%02d.wav" % [base, i]
		if ResourceLoader.exists(p):
			variants.append(p)
	if variants.is_empty():
		for ext in [".wav", ".ogg"]:
			if ResourceLoader.exists(base + ext):
				return _load(base + ext)
		return null
	return _load(variants[randi() % variants.size()])


func play_voice(speaker: String, line_id: String) -> void:
	var stream: AudioStream = _load("%s/%s/%s.ogg" % [VO_DIR, speaker, line_id])
	if stream == null:
		return
	_vo_player.stream = stream
	_vo_player.play()


## RTPCs drive bus effects: porcelain_stress low-passes and detunes the music (the degradation chain).
func set_rtpc(name: String, value: float) -> void:
	rtpc[name] = value
	match name:
		"porcelain_stress":
			if _lowpass != null:
				_lowpass.cutoff_hz = lerpf(20000.0, 2500.0, clampf(value / 100.0, 0.0, 1.0))
		"camera_fov":
			pass


func get_rtpc(name: String) -> float:
	return float(rtpc.get(name, 0.0))


## Half-second tape stop (defeat, Debt advancing).
func tape_stop() -> void:
	var idx: int = AudioServer.get_bus_index(&"Music")
	if idx < 0 or _pitch == null:
		return
	AudioServer.set_bus_effect_enabled(idx, 1, true)
	var tw := create_tween()
	tw.tween_property(_pitch, "pitch_scale", 0.05, 0.4)
	tw.tween_interval(0.3)
	tw.tween_callback(func() -> void:
		_pitch.pitch_scale = 1.0
		AudioServer.set_bus_effect_enabled(idx, 1, false))
