## Rendering and sprites: the sprite material's two passes (opacity fades), the canvas stack's staged
## Chronoslip and HDR pass-through, sprite densities and the frames json contract, and the small render
## helpers (dialogue timers, SceneKit boxes, the camera rig).
extends "res://tests/suite_base.gd"

const CUTOUT := "res://shaders/sprite_canvas.gdshader"
const FADE := "res://shaders/sprite_canvas_fade.gdshader"
const BODY := "res://shaders/sprite_canvas.gdshaderinc"
const STACK := "res://shaders/compositor/canvas_stack.glsl"
const TMP_FRAMES := "user://suite_render_frames.json"


func _text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _uniforms(path: String) -> Array[String]:
	var out: Array[String] = []
	var sh: Shader = load(path)
	if sh == null:
		return out
	for u in sh.get_shader_uniform_list():
		out.append(String(u["name"]))
	out.sort()
	return out


# ---------------------------------------------------------------- WORLD-1: opacity fades

func test_both_sprite_passes_compile_with_one_set_of_uniforms() -> void:
	var cut: Array[String] = _uniforms(CUTOUT)
	var fade: Array[String] = _uniforms(FADE)
	check(cut.size() > 20, "the cut-out pass compiles (%d uniforms)" % cut.size())
	check_eq(fade, cut, "the fade pass compiles with the same uniforms")
	for n in ["opacity", "seed", "sheet", "frame_rect", "porcelain_state"]:
		check(cut.has(n), "uniform %s is declared" % n)


func test_only_the_fade_pass_writes_alpha_and_nothing_scissors_it() -> void:
	var body: String = _text(BODY)
	check(body.length() > 1000, "the shared body is readable")
	check(not body.contains("ALPHA_SCISSOR_THRESHOLD"), "no alpha scissor: opacity is never a 0.5 step")
	var in_fade: bool = false
	var writes_out: Array[String] = []
	var fade_writes: Array[String] = []
	for line in body.split("\n"):
		var l: String = line.strip_edges()
		if l.begins_with("#ifdef SPRITE_FADE"):
			in_fade = true
		elif l.begins_with("#endif"):
			in_fade = false
		elif l.begins_with("ALPHA"):
			(fade_writes if in_fade else writes_out).append(l)
	check(writes_out.is_empty(), "the cut-out pass never writes ALPHA, so `transparency` fades it: %s" % str(writes_out))
	check_eq(fade_writes, ["ALPHA *= opacity;"] as Array[String], "the fade pass multiplies the instance fade by opacity")
	check(body.contains("if (c.a < 0.5) { discard; }"), "the sheet's hard edge is still cut")
	check(_text(FADE).contains("#define SPRITE_FADE"), "the fade shader defines SPRITE_FADE")
	check(not _text(CUTOUT).contains("#define SPRITE_FADE"), "the cut-out shader does not")
	for path in [CUTOUT, FADE]:
		check(_text(path).contains("#include \"res://shaders/sprite_canvas.gdshaderinc\""), "%s includes the shared body" % path)


func test_opacity_below_one_draws_the_fade_pass_and_keeps_the_sheet() -> void:
	var s := ActorSprite.new()
	_track(s)
	SpriteLibrary.apply(s, "crono", 60.0)
	var cut: Shader = s.material.shader
	check_eq(cut.resource_path, CUTOUT, "a sprite starts on the cut-out pass")
	var sheet: Variant = s.material.get_shader_parameter("sheet")
	var rect: Variant = s.material.get_shader_parameter("frame_rect")
	s.set_opacity(0.45)  # the field Rewind's ghosts
	check(s.is_faded(), "opacity 0.45 draws blended")
	check_eq(s.material.shader.resource_path, FADE, "through the fade shader")
	check_near(float(s.material.get_shader_parameter("opacity")), 0.45, 0.0001, "at 45 %")
	check_eq(s.material.get_shader_parameter("sheet"), sheet, "the sheet carries over")
	check_eq(s.material.get_shader_parameter("frame_rect"), rect, "and the frame")
	s.set_opacity(0.18)  # Sera phased
	check(s.is_faded() and is_equal_approx(s.opacity, 0.18), "a phased Sera reads at 18 %")
	s.set_opacity(1.0)
	check(not s.is_faded(), "full opacity returns to the cut-out pass (depth, shadows)")
	check_eq(s.material.shader, cut, "the same cut-out shader")
	s.set_opacity(1.7)
	check_near(s.opacity, 1.0, 0.0001, "opacity is clamped")
	check(not s.is_faded(), "and stays opaque")


## RA-3: a faded body writes no depth, so the battle's ground overlays must come before every sprite in the
## transparent list, or a body past the plane's centre is washed by the plane and cut by its gold edge.
func test_the_battle_ground_overlays_draw_under_a_faded_body() -> void:
	Game.new_game()
	Game.recruit(&"sera")
	Game.set_party([&"crono", &"sera"] as Array[StringName])
	Game.set_debt(25.0)
	var loc: Location = (load("res://scenes/test/arena.tscn") as PackedScene).instantiate()
	root.add_child(loc)
	_track(loc)
	loc.place_party(&"start")
	await get_tree().process_frame
	var z: EncounterZone = loc.zones[0]
	z.active = false
	loc._on_zone_triggered(z, "normal")
	var scene: BattleScene = loc.battle
	scene.coordinator.auto_tick = false
	var sera := loc.get_actor(&"sera") as CombatActor
	check(sera.sprite.is_faded(), "Sera at 25 Debt draws through the fade pass")
	var body: int = sera.sprite.material.render_priority
	check(scene.plane_mat.render_priority < body, "the battle plane sorts before her (%d < %d)" % [scene.plane_mat.render_priority, body])
	var decal: MeshInstance3D = BattleFx.telegraph(scene, {"shape": "CIRCLE", "radius": 2.0}, scene.center, scene.center.y + 0.05)
	var ring: int = (decal.material_override as Material).render_priority
	check(ring < body, "a wind-up decal sorts before her too")
	check(scene.plane_mat.render_priority < ring, "and over the plane")
	decal.queue_free()
	scene.coordinator.force_end(true)
	Engine.time_scale = 4.0
	var t: float = 0.0
	while loc.battle != null and t < 8.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	Engine.time_scale = 1.0
	check(loc.battle == null, "the battle still ends")
	Game.new_game()


# ---------------------------------------------------------------- GAP4-10: densities

func test_density_fallback_follows_the_cell() -> void:
	check_near(ActorSprite.PIXELS_PER_METRE, SceneKit.PX_PER_M, 0.0001, "the sprite density is the world's 32 px/m")
	check_near(ActorSprite.fallback_pixel_size(64), 1.0 / 32.0, 1e-6, "a recipe 64 cell without a height stands at 32 px/m")
	check_near(ActorSprite.fallback_pixel_size(96), 1.0 / 32.0, 1e-6, "and a 96 cell")
	check_near(ActorSprite.fallback_pixel_size(128), 1.0 / 64.0, 1e-6, "a legacy 128 cell keeps 64 px/m")


func _expected_quad(r: Dictionary, tex: Texture2D) -> float:
	var meta: Dictionary = SpriteLibrary.frames_meta(r)
	if meta.is_empty():
		meta = SpriteLibrary.frames_meta({"dir": r["dir"], "stem": r["id"]})
	var cell: int = int(meta.get("cell", 128))
	var hp: int = int(meta.get("height_px", 0))
	var hm: float = float(meta.get("height_m", 0.0))
	var ps: float = hm / float(hp) if hp > 0 and hm > 0.0 else (1.0 / 32.0 if cell <= 96 else 1.0 / 64.0)
	return float(cell) * ps if tex != null else 0.0


func test_every_shipped_sheet_keeps_its_on_screen_size() -> void:
	var ids: Array[String] = []
	for g in SpriteLibrary.GROUPS:
		var da := DirAccess.open("res://assets/%s" % g)
		if da == null:
			continue
		for d in da.get_directories():
			if not ids.has(d):
				ids.append(d)
	ids.sort()
	var sheets: int = 0
	var bad: Array[String] = []
	for id in ids:
		var s := ActorSprite.new()
		_track(s)
		SpriteLibrary.apply(s, id, 60.0)
		var q := s.mesh as QuadMesh
		var r: Dictionary = SpriteLibrary.resolve(id)
		if not r.is_empty():
			sheets += 1
			var want: float = _expected_quad(r, load(r["sheet"]))
			if absf(q.size.y - want) > 0.001:
				bad.append("%s %.3f m (want %.3f)" % [id, q.size.y, want])
			var meta: Dictionary = SpriteLibrary.frames_meta(r)
			if int(meta.get("height_px", 0)) <= 0 and int(meta.get("cell", 128)) <= 96:
				bad.append("%s: a recipe-size sheet without a height" % id)
		else:
			var painted: String = ""
			for g in SpriteLibrary.GROUPS:
				var p: String = "res://assets/%s/%s/%s_painted.png" % [g, id, id]
				if painted == "" and ResourceLoader.exists(p):
					painted = p
			if painted != "":
				var tex: Texture2D = load(painted)
				if absf(q.size.y - float(tex.get_height()) / 64.0) > 0.001:
					bad.append("%s painted %.3f m (want %.3f)" % [id, q.size.y, float(tex.get_height()) / 64.0])
	check(sheets >= 15, "the shipped sheets were applied (%d)" % sheets)
	check(bad.is_empty(), "no shipped sheet or stand-in shrinks or doubles: %s" % str(bad))
	# Pinned sizes: the legacy NPC sheets at 128 px / 64 px per m, the anchor-scale Crono by his height.
	var guard := ActorSprite.new()
	_track(guard)
	SpriteLibrary.apply(guard, "guard", 60.0)
	check_near((guard.mesh as QuadMesh).size.y, 2.0, 0.001, "a 128-cell NPC sheet without a height stands in a 2 m quad")
	var crono := ActorSprite.new()
	_track(crono)
	SpriteLibrary.apply(crono, "crono", 60.0)
	check_near(crono.pixel_size * 95.0, 1.78, 0.01, "Crono's 95 drawn px stand 1.78 m")


## The rows of a sprite's bound sheet that hold any visible pixel: the drawn figure's height in pixels.
func _figure_rows(sprite: ActorSprite) -> int:
	var tex: Texture2D = sprite.material.get_shader_parameter("sheet") as Texture2D
	check(tex != null, "%s has a sheet bound" % sprite.sprite_id)
	if tex == null:
		return 0
	var img: Image = tex.get_image()
	check(img != null, "%s's sheet can be read back" % sprite.sprite_id)
	if img == null:
		return 0
	var rows: int = 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				rows += 1
				break
	return rows


func test_placeholders_are_drawn_at_the_world_density_at_the_old_size() -> void:
	var s := ActorSprite.new()
	_track(s)
	SpriteLibrary.apply(s, "nobody_has_this_sprite", 60.0)
	check_eq(s.cell, SpriteLibrary.PLACEHOLDER_CELL, "the character placeholder is a 64 px cell")
	check_near(s.pixel_size, 1.0 / 32.0, 1e-6, "at 32 px per metre")
	check_near((s.mesh as QuadMesh).size.y, 2.0, 0.001, "in the same 2 m quad as before")
	check_near(float(SpriteLibrary.PLACEHOLDER_HEIGHT_PX) / 32.0, 1.72, 0.01, "its figure stands 1.72 m")
	var char_rows: int = _figure_rows(s)
	check_eq(char_rows, SpriteLibrary.PLACEHOLDER_HEIGHT_PX, "the character placeholder draws its 55 px figure")
	check_near(float(char_rows) * s.pixel_size, 1.72, 1.0 / 32.0, "and that figure stands 1.72 m on screen")
	var sizes: Dictionary = {}
	var figures: Dictionary = {}
	var bins: Dictionary = {}
	for k in Data.enemies.keys():
		var def: EnemyDef = Data.enemies[k]
		var e := ActorSprite.new()
		_track(e)
		SpriteLibrary.apply_enemy(e, def)
		if e.cell <= 256 and is_equal_approx(e.pixel_size, 1.0 / 32.0):
			var want: float = 2.0 if def.size <= 1.3 else (4.0 if def.size <= 2.5 else 8.0)
			var quad_h: float = (e.mesh as QuadMesh).size.y
			sizes[String(k)] = absf(quad_h - want) < 0.001
			# The blob itself, not only its quad: 1.6 m per metre of `size`, capped at 0.8 of the quad.
			var fig_m: float = float(_figure_rows(e)) * e.pixel_size
			var fig_want: float = minf(0.8 * quad_h, 1.6 * def.size)
			figures[String(k)] = "%.3f m (want %.3f)" % [fig_m, fig_want]
			if absf(fig_m - fig_want) <= 1.0 / 32.0:
				figures.erase(String(k))
			bins[want] = int(bins.get(want, 0)) + 1
	check(sizes.size() > 10, "enemy placeholders were drawn (%d)" % sizes.size())
	check(not sizes.values().has(false), "each enemy placeholder keeps its 2 / 4 / 8 m quad: %s" % str(sizes.keys().filter(func(k: String) -> bool: return not bool(sizes[k]))))
	check(int(bins.get(2.0, 0)) > 10, "the shipped size <= 1.3 placeholders were measured: %s" % str(bins))
	check(figures.is_empty(), "each enemy placeholder's figure stands 1.6 m per metre of size, as before: %s" % str(figures))
	# Every quad tier, by size (no shipped enemy without art is above 1.3 today): the old 64 px/m code drew
	# 102.4 px per metre of size up to 0.8 of the cell (1.6 m per metre); at 32 px/m that is 51.2 px.
	for case in [[1.0, 2.0, 51], [0.6, 2.0, 30], [1.5, 4.0, 76], [2.0, 4.0, 102], [2.4, 4.0, 102], [3.0, 8.0, 153], [5.0, 8.0, 204]]:
		var d := EnemyDef.new()
		d.key = StringName("suite_render_size_%s" % str(case[0]))
		d.size = float(case[0])
		var b := ActorSprite.new()
		_track(b)
		SpriteLibrary.apply_enemy(b, d)
		var rows: int = _figure_rows(b)
		check_near((b.mesh as QuadMesh).size.y, float(case[1]), 0.001, "a size-%s placeholder stands in a %s m quad" % [str(case[0]), str(case[1])])
		check_eq(rows, int(case[2]), "a size-%s placeholder draws a %d px figure" % [str(case[0]), int(case[2])])
		check_near(float(rows) * b.pixel_size, minf(0.8 * float(case[1]), 1.6 * float(case[0])), 1.0 / 32.0, "a size-%s figure stands 1.6 m per metre of size (capped at 0.8 of the quad)" % str(case[0]))


# ---------------------------------------------------------------- WORLD-13: frames json keys

func _write_frames(d: Dictionary) -> void:
	var f := FileAccess.open(TMP_FRAMES, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()


func test_frames_json_fps_is_the_sheets_rate_unless_the_caller_names_one() -> void:
	_write_frames({"cell": 64, "fps": 24, "rows": ["s", "w", "e", "n"], "anims": {"idle": {"col": 0, "count": 2}, "walk": {"col": 2, "count": 4, "fps": 10}}})
	var t: Dictionary = SpriteLibrary._load_table(TMP_FRAMES, 0.0)
	check_near(float(t.get("_fps", 0.0)), 24.0, 0.0001, "the sheet's own fps is read")
	check_near(float(t[&"idle"]["fps"]), 24.0, 0.0001, "an anim without fps steps at the sheet's rate when the caller gives none")
	check_near(float(t[&"walk"]["fps"]), 10.0, 0.0001, "an anim's own fps wins")
	check_eq(t.get("_rows", []), [&"s", &"w", &"e", &"n"], "rows are read as the row order")
	var t2: Dictionary = SpriteLibrary._load_table(TMP_FRAMES, 60.0)
	check_near(float(t2[&"idle"]["fps"]), 60.0, 0.0001, "a caller's rate (the character's data) wins over the sheet's")
	_write_frames({"cell": 64, "rows": ["s", "up", "e"], "anims": {"idle": {"col": 0, "count": 1}}})
	check_eq(SpriteLibrary._load_table(TMP_FRAMES, 60.0).get("_rows", null), [], "rows that are not directions fall back to the default order")
	var missing: Dictionary = SpriteLibrary._load_table("user://suite_render_no_such_frames.json", 0.0)
	check(missing.has(&"attack") and int(missing["_cell"]) == 128, "a missing frames json reads the default table (and warns)")
	check_near(float(missing[&"idle"]["fps"]), 60.0, 0.0001, "at 60 when no rate is known")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_FRAMES))
	# A shipped sheet: the U1 soldier is drawn at 24.
	var npc := ActorSprite.new()
	_track(npc)
	SpriteLibrary.apply(npc, "ashen_soldier", 0.0)
	check_near(npc.canvas_fps, 24.0, 0.0001, "an NPC added with no rate quantises at its sheet's 24")
	SpriteLibrary.apply(npc, "ashen_soldier", 60.0)
	check_near(npc.canvas_fps, 60.0, 0.0001, "an explicit rate still wins")


func test_anims_past_the_last_column_are_cut_not_smeared() -> void:
	var table: Dictionary = {
		&"idle": {"col": 0, "count": 4, "fps": 5.0, "loop": true, "holds": []},
		&"walk": {"col": 8, "count": 6, "fps": 10.0, "loop": true, "holds": []},
		&"ready": {"col": 23, "count": 4, "fps": 10.0, "loop": true, "holds": []},
	}
	SpriteLibrary._fit_columns(table, 10, "res://test/sheet.png")
	check(table.has(&"idle") and int(table[&"idle"]["count"]) == 4, "an anim inside the sheet is untouched")
	check_eq(int(table[&"walk"]["count"]), 2, "an anim running off the last column is shortened")
	check(not table.has(&"ready"), "an anim past the sheet is dropped (idle stands in)")


func test_row_order_from_the_frames_json_picks_the_row() -> void:
	var img := Image.create(64 * 2, 64 * 4, false, Image.FORMAT_RGBA8)
	var s := ActorSprite.new()
	_track(s)
	var table: Dictionary = {&"idle": {"col": 0, "count": 1, "fps": 5.0, "loop": true, "holds": []}}
	s.set_sheet(ImageTexture.create_from_image(img), 64, table, 60.0, false, [&"n", &"e", &"w", &"s"])
	s.set_facing(&"n")
	var r: Vector4 = s.material.get_shader_parameter("frame_rect")
	check_eq(int(round(r.y / r.w)), 0, "north is the first row of a sheet that says so")
	s.set_facing(&"s")
	r = s.material.get_shader_parameter("frame_rect")
	check_eq(int(round(r.y / r.w)), 3, "south its last")
	s.set_facing(&"se")
	r = s.material.get_shader_parameter("frame_rect")
	check_eq(int(round(r.y / r.w)), 3, "a diagonal folds to its cardinal on a four-row sheet")
	s.set_sheet(ImageTexture.create_from_image(img), 64, table, 60.0)
	check_eq(s.row_order, ActorSprite.DIRECTIONS, "no order given: s, w, e, n, sw, se, nw, ne")


# ---------------------------------------------------------------- WORLD-24: per-sprite seed

func test_each_sprite_id_gets_its_own_crack_and_drift_seed() -> void:
	var a := ActorSprite.new()
	var b := ActorSprite.new()
	_track(a)
	_track(b)
	SpriteLibrary.apply(a, "crono", 60.0)
	SpriteLibrary.apply(b, "sera", 60.0)
	var sa: float = float(a.material.get_shader_parameter("seed"))
	var sb: float = float(b.material.get_shader_parameter("seed"))
	check_near(sa, SpriteLibrary.seed_of("crono"), 1e-5, "the seed is the sprite id's")
	check(not is_equal_approx(sa, sb), "two characters do not share one crack pattern (%s, %s)" % [sa, sb])
	check(sa >= 0.0 and sa < 100.0, "the seed stays small enough for the shader's sin hash")
	var e := ActorSprite.new()
	_track(e)
	SpriteLibrary.apply_enemy(e, Data.enemies.values()[0])
	check(e.material.get_shader_parameter("seed") != null, "an enemy placeholder is seeded too")


# ---------------------------------------------------------------- WORLD-15: the staged Chronoslip

func test_chronoslip_stages_follow_reference_2_4() -> void:
	var k: Dictionary = ChronoslipStages.progress(0.15)
	check_near(float(k["paper"]), 0.5, 0.001, "0.15 s: the paper is half dissolved")
	check_near(float(k["grade"]), 0.0, 0.001, "the grade has not started")
	k = ChronoslipStages.progress(0.4)
	check_near(float(k["paper"]), 1.0, 0.001, "0.4 s: the paper is done")
	check_near(float(k["grade"]), 0.5, 0.001, "the grade is half way")
	check_eq(float(k["fps"]), 0.0, "the old canvas rate holds")
	k = ChronoslipStages.progress(0.5)
	check_eq(float(k["fps"]), 1.0, "0.5 s: the frame rate snaps")
	k = ChronoslipStages.progress(0.6)
	check_near(float(k["grade"]), 1.0, 0.001, "0.6 s: the grade is done")


func test_universe_switcher_runs_the_three_stages() -> void:
	Universe.set_universe(0, true)
	Universe.set_universe(2)
	Universe.advance(0.15)
	check_near(Universe.paper_weights[2], 0.5, 0.01, "0.15 s: the paper is half way to U2")
	check_near(Universe.weights[2], 0.0, 0.001, "the grade has not begun")
	check_eq(Universe.current, 0, "the slip is under way")
	Universe.advance(0.25)
	check_near(Universe.paper_weights[2], 1.0, 0.001, "0.40 s: paper done")
	check_near(Universe.weights[2], 0.5, 0.01, "grade half way")
	check_near(Universe.current_fps(), 60.0, 0.001, "still quantising at U0's 60")
	Universe.advance(0.05)
	check_near(Universe.current_fps(), 60.0, 0.001, "0.45 s: the old rate holds")
	Universe.advance(0.10)
	check_near(Universe.current_fps(), 12.0, 0.001, "0.55 s: snapped to U2's 12")
	check_eq(Universe.fps_weights, ChronoslipStages.only(2), "all of the rate on U2, none blended")
	Universe.advance(1.0)
	check_eq(Universe.current, 2, "past 0.8 s the slip has landed")
	check_eq(Universe.weights, ChronoslipStages.only(2), "every stage on U2")
	check_eq(Universe.paper_weights, ChronoslipStages.only(2), "paper too")
	# A fine sweep back to U0: the rate is always one canvas's, 12 or 60.
	Universe.set_universe(0)
	var blended: Array[float] = []
	for i in 100:
		Universe.advance(0.01)
		var r: float = Universe.current_fps()
		if not is_equal_approx(r, 60.0) and not is_equal_approx(r, 12.0):
			blended.append(r)
	check(blended.is_empty(), "the canvas rate is never a blend: %s" % str(blended))
	check_eq(Universe.current, 0, "back home")
	Universe.set_universe(5, true)
	check_eq(Universe.fps_weights, ChronoslipStages.only(5), "an instant switch sets all three")
	Universe.set_universe(0, true)


func test_canvas_stack_packs_the_three_weight_sets() -> void:
	var fx := CanvasStackEffect.new()
	fx.weights = PackedFloat32Array([0.5, 0, 0.5, 0, 0, 0, 0, 0, 0, 0])
	fx.paper_weights = PackedFloat32Array([0.0, 0, 2.0, 0, 0, 0, 0, 0, 0, 0])
	fx.fps_weights = ChronoslipStages.only(0)
	fx.debt = 0.25
	var p: PackedFloat32Array = fx.pack_params()
	check_eq(p.size(), CanvasStackEffect.U_BASE + 10 * CanvasStackEffect.U_STRIDE, "the buffer holds the header, three sets and the table")
	check_near(p[1], 0.25, 0.0001, "debt in the header")
	check_near(p[CanvasStackEffect.W_GRADE + 2], 0.5, 0.0001, "grade weights at 4..13")
	check_near(p[CanvasStackEffect.W_PAPER + 2], 1.0, 0.0001, "paper weights at 14..23, normalised")
	check_near(p[CanvasStackEffect.W_FPS + 0], 1.0, 0.0001, "frame-rate weights at 24..33")
	check_near(p[CanvasStackEffect.U_BASE + 2 * CanvasStackEffect.U_STRIDE + 15], 12.0, 0.0001, "U2's fps in the per-universe table")
	var src: String = _text(STACK)
	check(src.contains("const int W_PAPER = %d;" % CanvasStackEffect.W_PAPER) and src.contains("const int W_FPS = %d;" % CanvasStackEffect.W_FPS) and src.contains("const int U_BASE = %d;" % CanvasStackEffect.U_BASE), "the shader reads the same offsets")
	check(src.contains("float fps = canvas_fps();"), "the shader quantises at the dominant canvas's rate, not a blend")


func test_canvas_stack_compiles_and_carries_hdr_past_the_grade() -> void:
	var f: RDShaderFile = load(STACK)
	check(f != null, "the canvas stack imports")
	if f != null:
		var spirv: RDShaderSPIRV = f.get_spirv()
		check(spirv != null and spirv.compile_error_compute == "", "it compiles to SPIR-V: %s" % (spirv.compile_error_compute if spirv else "none"))
		check(spirv != null and spirv.bytecode_compute.size() > 1000, "with bytecode")
	var src: String = _text(STACK)
	check(src.contains("to_linear(col) + excess"), "the light above linear 1.0 is added back after the grade, so the glow still sees it")
	check(src.contains("vec3 excess = max(hdr - vec3(1.0), vec3(0.0));"), "the excess is what the 1.0 clamp would cut")
	check(not src.contains("max(vec3(0.05), paper_tint)"), "the paper multiply is written as what it computes")


func test_hub_leaks_bleed_grade_and_paper_but_never_the_rate() -> void:
	Universe.set_universe(0, true)
	var w := HD2DWorld.new()
	w.environment = Environment.new()
	_track(w)
	root.add_child(w)
	w.set_leak(1, 0.3)
	check(w.canvas_stack.weights[1] > 0.2, "a leak bleeds into the grade")
	check(w.canvas_stack.paper_weights[1] > 0.2, "and the paper")
	check_eq(w.canvas_stack.fps_weights, ChronoslipStages.only(0), "but U0 keeps its rate")
	w.set_leak(1, 0.0)
	check_eq(w.canvas_stack.weights, ChronoslipStages.only(0), "a closed leak leaves U0 alone")


# ---------------------------------------------------------------- WORLD-17: dialogue timers

func test_a_stale_auto_advance_timer_never_skips_the_next_line() -> void:
	var box := DialogueBox.new()
	_track(box)
	root.add_child(box)
	var count: Array[int] = [0]
	box.advanced.connect(func() -> void: count[0] += 1)
	box.say("crono", "The first line, long enough to read.", "neutral", "", 1.5)
	var first: int = box._line
	var ev := InputEventAction.new()
	ev.action = &"confirm"
	ev.pressed = true
	box._unhandled_input(ev)  # finish the typewriter
	box._unhandled_input(ev)  # and confirm early
	check_eq(count[0], 1, "the player's confirm advanced the first line")
	box.say("crono", "The second line.", "neutral", "", 1.5)
	check(box._line != first, "the second line has its own number")
	box._auto_advance(first)  # the first line's timer fires during the second
	check_eq(count[0], 1, "the stale timer does nothing")
	check(box._wait_advance, "the second line still waits")
	box._auto_advance(box._line)  # its own timer
	check_eq(count[0], 2, "the line's own timer advances it")
	var opts: Array = [{"text": "Yes"}, {"text": "No"}]
	var picked: Array[int] = []
	box.chosen.connect(func(i: int) -> void: picked.append(i))
	box.choose("crono", "Well?", opts, 1)
	var choice_line: int = box._line
	box._pick(0)  # the player answers before the auto-pick timer
	box.choose("crono", "And now?", opts)
	box._auto_pick(choice_line, 1)  # the first choice's timer fires during the second
	check_eq(picked, [0] as Array[int], "a stale auto-pick does not answer a later choice")
	box._pick(1)
	check_eq(picked, [0, 1] as Array[int], "the later choice is the player's")
	box.hide_box()


# ---------------------------------------------------------------- WORLD-19 / WORLD-24: helpers

func test_boxes_share_the_material_they_are_given() -> void:
	var holder := Node3D.new()
	_track(holder)
	var brass := SceneKit.flat_color(Color(0.7, 0.55, 0.3))
	var a := SceneKit.box(holder, Vector3(0.2, 3.0, 0.2), Vector3.ZERO, brass, "BarA", false)
	var b := SceneKit.box(holder, Vector3(4.0, 0.2, 0.2), Vector3(0, 3, 0), brass, "Rail", false)
	check(a.material_override == brass and b.material_override == brass, "every box wears the one material, not a private copy")


func test_the_camera_rig_has_no_dead_yaw() -> void:
	var rig := HD2DCameraRig.new()
	_track(rig)
	check(rig.get("_yaw") == null, "no unused yaw member")
	rig.pitch_degrees = 30.0
	rig.distance = 10.0
	var off: Vector3 = rig.camera_offset()
	check(off.is_equal_approx(Vector3(0.0, 5.0, 10.0 * cos(deg_to_rad(30.0)))), "the offset is pitch and distance alone (%s)" % off)


func test_seras_float_comes_from_her_data() -> void:
	check_near(float(Data.characters[&"sera"].get("y_offset", 0.0)), 0.0625, 0.0001, "data/characters/sera.json carries her lift")
	var sera: CombatActor = CombatActor.create_party_member(&"sera")
	_track(sera)
	check_near(sera.sprite.position.y, 0.0625, 0.0001, "Sera's sprite floats by her data's y_offset")
	var crono: CombatActor = CombatActor.create_party_member(&"crono")
	_track(crono)
	check_near(crono.sprite.position.y, 0.0, 0.0001, "Crono stands on the ground")


# ---------------------------------------------------------------- Sera's Debt opacity (review nit on WORLD-1)

## Opacity really fades now, so un-phasing (BattleScene._on_sera_phase) and a revive (restore_body) hand Sera
## back her Debt's thinness (CombatActor.body_opacity), never a pop to fully solid.
func test_un_phasing_and_reviving_return_sera_to_her_debt_opacity() -> void:
	var debt_op: float = 1.0 - 40.0 * CombatActor.DEBT_OPACITY_PER_POINT
	var sera: CombatActor = CombatActor.create_party_member(&"sera")
	_track(sera)
	root.add_child(sera)
	sera.solidity.debt = 40.0
	sera.set_porcelain_visuals()
	check_near(sera.body_opacity(), debt_op, 0.0001, "40 Debt leaves Sera's body at 0.8")
	check_near(sera.sprite.opacity, debt_op, 0.0001, "and that is what she shows")
	sera.die()
	sera.restore_body()
	check_near(sera.sprite.opacity, debt_op, 0.0001, "a revive brings her back at her Debt, not fully solid")
	var crono: CombatActor = CombatActor.create_party_member(&"crono")
	_track(crono)
	root.add_child(crono)
	crono.sprite.set_opacity(0.3)
	crono.restore_body()
	check_near(crono.sprite.opacity, 1.0, 0.0001, "every other body is restored fully solid")
	# The battle scene's phase hook, driven through the coordinator's signal.
	Game.new_game()
	Game.recruit(&"sera")
	Game.set_party([&"crono", &"sera"] as Array[StringName])
	var loc: Location = (load("res://scenes/test/arena.tscn") as PackedScene).instantiate()
	root.add_child(loc)
	_track(loc)
	loc.place_party(&"start")
	await get_tree().process_frame
	var z: EncounterZone = loc.zones[0]
	z.active = false
	loc._on_zone_triggered(z, "normal")
	var c: BattleCoordinator = loc.battle.coordinator
	c.auto_tick = false
	var s := c.unit_by_id(&"sera") as CombatActor
	check(s != null, "Sera fights in the arena battle")
	if s == null:
		Game.new_game()
		return
	s.solidity.debt = 40.0
	s.set_porcelain_visuals()
	# the look reads her phase (CombatActor.apply_body_look, RA-1): a Rewind past 20 phases her, and the
	# coordinator says so on sera_phase_changed itself
	TechCosts.spend_solidity(c, s, s.solidity.solidity - 15.0)
	check(s.solidity.is_phased(), "a Rewind past 20 phases her out")
	check_near(s.sprite.opacity, 0.18, 0.0001, "phased, she reads at 18 %")
	s.solidity.phased_turns_left = 1
	s.solidity.on_phased_turn()  # her last phased turn passes, as BattleCoordinator.advance counts it
	c.sera_phase_changed.emit(false)
	check_near(s.sprite.opacity, debt_op, 0.0001, "un-phased, she is back at her Debt's 0.8, not 1.0")
	c.force_end(true)
	Engine.time_scale = 4.0
	var t: float = 0.0
	while loc.battle != null and t < 8.0:
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	await get_tree().process_frame
	Engine.time_scale = 1.0
	check(loc.battle == null, "the battle still ends")
	Game.new_game()
