## Tooling and harness (the "tools" audit cluster): what the probes' debug start gives the party (BootArgs:
## --party, --level and --chapter in a fixed order, the Prologue kit by default, guests included), the import
## settings every committed sidecar keeps (sprites never switch to VRAM compression on their first 3D use,
## world textures are mipmapped, every uid is Godot's own text so `--import` never rewrites one), and the
## ActorSprite stepping and row maths no capture checks (eight sectors, four-row sheets, holds, one-shots,
## rewinds, mirrored west rows).
extends "res://tests/suite_base.gd"

const DT := 1.0 / 60.0


func _cleanup() -> void:
	Game.new_game()
	super._cleanup()


# ---------------------------------------------------------------- the debug start (GAP3-3)

func test_boot_args_parse_whatever_the_order() -> void:
	var a: Dictionary = BootArgs.parse(PackedStringArray(["--level=4", "--chapter=2", "--party=crono, sera,marle", "--autobattle"]))
	check_eq(a["party"], [&"crono", &"sera", &"marle"] as Array[StringName], "the party ids, trimmed")
	check_eq(int(a["level"]), 4, "the level")
	check_eq(int(a["chapter"]), 2, "the chapter")
	var none: Dictionary = BootArgs.parse(PackedStringArray(["--scene=test_arena"]))
	check((none["party"] as Array).is_empty() and int(none["level"]) == 0 and int(none["chapter"]) == -1, "nothing given, nothing set")


func test_level_reaches_every_party_member_guests_included() -> void:
	Game.new_game()
	# --level before --party: the guest's roster row is created first all the same
	BootArgs.apply(PackedStringArray(["--level=4", "--party=crono,sera,marle"]), true)
	check_eq(Game.active_party, [&"crono", &"sera", &"marle"] as Array[StringName], "the party")
	for id in [&"crono", &"sera", &"marle"]:
		check_eq(Game.level_of(id), 4, "%s is level 4" % id)
	check(Game.roster.has(&"marle"), "the guest has a roster row")


func test_a_debug_start_learns_the_prologue_kit_without_chapter() -> void:
	Game.new_game()
	BootArgs.apply(PackedStringArray(["--party=crono,sera,marle", "--level=4"]), true)
	check_eq(Game.chapter, 0, "still the Prologue")
	for pair in [[&"crono", &"astral_smear_dash"], [&"crono", &"time_debt_seal"],
			[&"marle", &"light_bolt"], [&"marle", &"ward"]]:
		check(Game.knows_tech(pair[0], pair[1]), "%s knows %s (the Prologue kit)" % [pair[0], pair[1]])
	check(not Game.knows_tech(&"sera", &"fall_break"), "Sera's Fall Break waits for the Cradle's phase 2, as in a real Prologue")
	check(not Game.knows_tech(&"crono", &"time_slice"), "no Chapter 1 tech without --chapter")
	check(not Game.knows_tech(&"sera", &"rewind"), "Sera's Rewind waits for Chapter 1")


## F4: the kit a debug start fights the Cradle with (battle_probe: BootArgs, no --chapter) is the kit a real New Game
## brings to it: the Prologue's own scripts (breakfast, the gate) teach Crono Astral Smear Dash and Time Debt Seal
## before the first fight, and Sera nothing yet; the Cradle's phase-2 beat teaches her Fall Break in both, and the
## Prologue's end (Chapter 1) leaves nobody without it.
func test_the_debug_prologue_kit_is_the_real_one_at_the_cradle() -> void:
	Game.new_game()
	Story.auto_advance_s = 0.01
	Story.auto_choice = 0
	Story.skip_waits = true
	await Story.run(&"prologue_breakfast")
	await Story.run(&"prologue_gate")
	var real: Dictionary = {}
	for id in [&"crono", &"sera"]:
		real[id] = (Game.roster[id]["known_techs"] as Array).duplicate()
	check((real[&"crono"] as Array).has("time_debt_seal"), "a real Prologue teaches Crono Time Debt Seal before the Cradle (Story Bible: he uses it there)")
	check((real[&"crono"] as Array).has("astral_smear_dash"), "and Astral Smear Dash")
	check(not (real[&"sera"] as Array).has("fall_break"), "Sera has no Fall Break before the Cradle's phase 2")
	Game.new_game()
	BootArgs.apply(PackedStringArray(["--party=crono,sera,marle", "--level=4"]), true)
	for id in [&"crono", &"sera"]:
		var debug: Array = (Game.roster[id]["known_techs"] as Array).duplicate()
		debug.sort()
		var want: Array = (real[id] as Array).duplicate()
		want.sort()
		check_eq(debug, want, "%s fights the debug Cradle with the real Prologue kit" % id)
	await Story.run(&"prologue_cradle_phase2")
	check(Game.knows_tech(&"sera", &"fall_break"), "the Cradle's phase-2 beat teaches Sera Fall Break")
	Game.new_game()
	Game.set_chapter(1)
	check(Game.knows_tech(&"sera", &"fall_break") and Game.knows_tech(&"crono", &"time_debt_seal"), "a Chapter 1 start knows both Prologue techs")
	Story.auto_advance_s = -1.0
	Story.auto_choice = -1
	Story.skip_waits = false
	Game.new_game()


func test_chapter_teaches_its_kit_to_a_guest_already_in_the_party() -> void:
	Game.new_game()
	BootArgs.apply(PackedStringArray(["--party=crono,sera,marle", "--chapter=2"]), true)
	check_eq(Game.chapter, 2, "--chapter sets the chapter")
	check(Game.knows_tech(&"crono", &"time_slice") and Game.knows_tech(&"sera", &"hover_rewind_hp"), "the recruited learn up to Chapter 2")
	check(Game.knows_tech(&"marle", &"porcelain_promise"), "the guest learns her Chapter 2 tech too (set_chapter teaches every learner)")
	check(not Game.knows_tech(&"marle", &"vitreous_arrow"), "but not her Chapter 10 one")


## F2: a debug start plays a made-up state, so it keeps its saves and settings in the scratch directory unless
## --save asks for the player's own; a plain start (the title, --say alone, battle-only arguments) does not.
func test_a_debug_start_keeps_its_saves_apart_unless_asked() -> void:
	for args in [["--scene=atrium"], ["--location=atrium", "--spawn=loft_bed"], ["--checkpoint=ch1_loft"],
			["--party=crono,sera"], ["--level=4"], ["--chapter=1"], ["--integrity=40"], ["--flag=Atrium_Dummy:Spared"],
			["--scene=atrium", "--checkpoint=ch1_loft", "--demo=dummy"]]:
		check(BootArgs.suspends_saves(PackedStringArray(args)), "%s is a debug start: its saves stay in scratch" % str(args))
	for args in [[], ["--scene=title"], ["--say=hello"], ["--autobattle"], ["--frames=60", "--every=60"]]:
		check(not BootArgs.suspends_saves(PackedStringArray(args)), "%s is not a debug start" % str(args))
	check(not BootArgs.suspends_saves(PackedStringArray(["--scene=atrium", "--checkpoint=ch1_loft", "--save"])), "--save lets a debug start write the player's files")


func test_a_title_start_learns_nothing() -> void:
	Game.new_game()
	BootArgs.apply(PackedStringArray([]), false)
	check((Game.roster[&"crono"]["known_techs"] as Array).is_empty(), "the title leaves the kit to the Prologue's own teaches")
	check_eq(Game.active_party, [&"crono"] as Array[StringName], "and the party as New Game made it")


# ---------------------------------------------------------------- import sidecars (WORLD-12, TOOLS-5)

func _import_files(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		var path: String = dir.path_join(n)
		if d.current_is_dir():
			if not n.begins_with("."):
				_import_files(path, out)
		elif n.ends_with(".import"):
			out.append(path)
		n = d.get_next()
	d.list_dir_end()


func test_sprite_sidecars_stay_lossless_and_never_switch_to_vram() -> void:
	var files: Array[String] = []
	_import_files("res://assets", files)
	check(files.size() > 100, "the asset sidecars are found (%d)" % files.size())
	var bad: Array[String] = []
	var sprites: int = 0
	for path in files:
		if path.begins_with("res://assets/textures/"):
			continue
		var cf := ConfigFile.new()
		if cf.load(path) != OK or String(cf.get_value("remap", "importer", "")) != "texture":
			continue
		sprites += 1
		# Reference 1.12 / the breakdown's section 12: lossless, no mipmaps, Detect 3D -> Compress To: Disabled
		if int(cf.get_value("params", "compress/mode", -1)) != 0:
			bad.append("%s compress/mode" % path)
		if bool(cf.get_value("params", "mipmaps/generate", true)):
			bad.append("%s mipmaps" % path)
		if int(cf.get_value("params", "detect_3d/compress_to", -1)) != 0:
			bad.append("%s detect_3d/compress_to" % path)
	check(sprites > 100, "sprite, portrait and UI sidecars were read (%d)" % sprites)
	check(bad.is_empty(), "every sprite/portrait/UI sidecar is lossless, unmipmapped, Detect-3D-safe: %s" % str(bad.slice(0, 8)))


func test_world_textures_are_mipmapped_and_detect_3d_safe() -> void:
	var files: Array[String] = []
	_import_files("res://assets/textures", files)
	check(files.size() > 10, "the texture sidecars are found (%d)" % files.size())
	var bad: Array[String] = []
	for path in files:
		var cf := ConfigFile.new()
		if cf.load(path) != OK:
			bad.append("%s unreadable" % path)
			continue
		# SceneKit samples them with a mipmapped anisotropic filter (scene_kit.gd), so the mips must exist
		if not bool(cf.get_value("params", "mipmaps/generate", false)):
			bad.append("%s has no mipmaps" % path)
		if int(cf.get_value("params", "detect_3d/compress_to", -1)) != 0:
			bad.append("%s detect_3d/compress_to" % path)
	check(bad.is_empty(), "world textures: %s" % str(bad.slice(0, 8)))


func test_every_sidecar_uid_is_godots_own_text() -> void:
	var files: Array[String] = []
	_import_files("res://assets", files)
	_import_files("res://audio", files)
	var seen: Dictionary = {}
	var bad: Array[String] = []
	for path in files:
		var cf := ConfigFile.new()
		if cf.load(path) != OK:
			continue
		var uid: String = String(cf.get_value("remap", "uid", ""))
		if uid == "":
			continue
		var id: int = ResourceUID.text_to_id(uid)
		# a uid Godot cannot parse, or prints differently, is rewritten by the next --import (git churn)
		if id == ResourceUID.INVALID_ID or ResourceUID.id_to_text(id) != uid:
			bad.append("%s %s" % [path, uid])
		if seen.has(uid):
			bad.append("%s repeats %s's uid" % [path, seen[uid]])
		seen[uid] = path
	check(seen.size() > 250, "sidecar uids were read (%d)" % seen.size())
	check(bad.is_empty(), "every uid is canonical and unique: %s" % str(bad.slice(0, 8)))


# ---------------------------------------------------------------- ActorSprite stepping and rows (WORLD-20)

func _sprite(rows: int, table: Dictionary, mirror_w: bool = false) -> ActorSprite:
	var img := Image.create(64 * 12, 64 * rows, false, Image.FORMAT_RGBA8)
	var s := ActorSprite.new()
	_track(s)
	s.set_sheet(ImageTexture.create_from_image(img), 64, table, 60.0, mirror_w)
	return s


func _rect(s: ActorSprite) -> Vector4:
	return s.material.get_shader_parameter("frame_rect")


func _row_of(s: ActorSprite) -> int:
	return int(round(_rect(s).y / _rect(s).w))


func _col_of(s: ActorSprite) -> int:
	return int(round(_rect(s).x / _rect(s).z))


const TABLE := {
	"idle": {"col": 0, "count": 2, "fps": 4, "loop": true},
	"walk": {"col": 2, "count": 4, "fps": 10, "loop": true, "holds": [0.5, 0.1, 0.1, 0.1]},
	"attack": {"col": 6, "count": 3, "fps": 10, "loop": false},
}


func test_eight_row_sheets_face_eight_sectors() -> void:
	var s: ActorSprite = _sprite(8, TABLE)
	check_eq(s.rows, 8, "eight rows")
	var cases: Array = [[Vector3(0, 0, 1), &"s"], [Vector3(1, 0, 1), &"se"], [Vector3(1, 0, 0), &"e"],
		[Vector3(1, 0, -1), &"ne"], [Vector3(0, 0, -1), &"n"], [Vector3(-1, 0, -1), &"nw"],
		[Vector3(-1, 0, 0), &"w"], [Vector3(-1, 0, 1), &"sw"]]
	for c in cases:
		s.face_vector(c[0])
		check_eq(s.facing, c[1], "%s faces %s" % [str(c[0]), c[1]])
		check_eq(_row_of(s), ActorSprite.DIRECTIONS.find(c[1]), "%s reads its own row" % c[1])
	s.face_vector(Vector3(0.01, 0, 0.01))
	check_eq(s.facing, &"sw", "a vector shorter than 5 cm keeps the facing")


func test_four_row_sheets_fold_diagonals_onto_cardinals() -> void:
	var s: ActorSprite = _sprite(4, TABLE)
	check_eq(s.rows, 4, "four rows")
	s.set_facing(&"se")
	check_eq(s.facing, &"s", "south-east shows the south row")
	s.set_facing(&"nw")
	check_eq(s.facing, &"n", "north-west shows the north row")
	check_eq(_row_of(s), 3, "the north row is row 3")
	s.face_vector(Vector3(1, 0, 0.4))
	check_eq(s.facing, &"e", "the wider axis wins on four rows")
	check(_row_of(s) < 4, "never a row the sheet does not have")


func test_mirrored_west_reads_the_east_row_flipped() -> void:
	var s: ActorSprite = _sprite(4, TABLE, true)
	s.set_facing(&"w")
	check_eq(_row_of(s), ActorSprite.DIRECTIONS.find(&"e"), "west reads the east row")
	check(bool(s.material.get_shader_parameter("flip_h")), "flipped")
	s.set_facing(&"e")
	check(not bool(s.material.get_shader_parameter("flip_h")), "east is not flipped")


func test_holds_set_each_frames_time() -> void:
	var s: ActorSprite = _sprite(8, TABLE)
	s.play(&"walk")
	check_eq(_col_of(s), 2, "walk starts at its column")
	for i in 24:  # 0.4 s: the first frame is held 0.5 s
		s._process(DT)
	check_eq(s.frame, 0, "the held first frame is still up at 0.4 s")
	for i in 7:  # 0.517 s
		s._process(DT)
	check_eq(s.frame, 1, "the next frame after its 0.5 s hold")
	check_eq(_col_of(s), 3, "and the rect moved one column")


func test_a_one_shot_returns_to_its_anim_and_rewinds_wrap() -> void:
	var s: ActorSprite = _sprite(8, TABLE)
	s.play(&"attack", &"idle")
	for i in 40:  # three frames at 10 fps = 0.3 s
		s._process(DT)
	check_eq(s.anim, &"idle", "the one-shot handed back to idle")
	s.play(&"attack")
	for i in 40:
		s._process(DT)
	check(s.is_finished() and s.frame == 2, "without a return it holds its last frame")
	s.play_backwards(&"idle", 1.0)
	s._process(0.26)  # idle at 4 fps: one step back from frame 0 wraps to the last frame
	check_eq(s.frame, 1, "a rewind steps backwards and wraps")
