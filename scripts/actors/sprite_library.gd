## Resolves sprite ids to sheets and frame tables. A character is a set of sprites (docs/ART_PIPELINE.md):
## tiers map (64) / field (128, also battle) / action (256 cut-ins) / portrait, and variants (another canvas
## or a story state): assets/<group>/<id>/<id>[_<variant>]_<tier>.png + _frames.json (+ _n normal, _m mask).
## Missing tiers or variants fall back to field/base, then the painted stand-in, then a generated placeholder.
class_name SpriteLibrary
extends RefCounted

static var _placeholders: Dictionary = {}

const GROUPS := ["characters", "npcs", "enemies", "bosses"]
## Default frame table for generated CHR-F sheets (columns): idle 4, walk 6, run 6, interact 3, emote 4,
## ready 4, attack 6, charge 4, release 6, hurt 3, ko 6, revive 5, victory 6, break 1, death 6.
const DEFAULT_TABLE := {
	"idle": {"col": 0, "count": 4, "loop": true},
	"walk": {"col": 4, "count": 6, "loop": true},
	"run": {"col": 10, "count": 6, "loop": true},
	"interact": {"col": 16, "count": 3, "loop": false},
	"emote": {"col": 19, "count": 4, "loop": false},
	"ready": {"col": 23, "count": 4, "loop": true},
	"attack": {"col": 27, "count": 6, "loop": false},
	"charge": {"col": 33, "count": 4, "loop": true},
	"release": {"col": 37, "count": 6, "loop": false},
	"hurt": {"col": 43, "count": 3, "loop": false},
	"ko": {"col": 46, "count": 6, "loop": false},
	"revive": {"col": 52, "count": 5, "loop": false},
	"victory": {"col": 57, "count": 6, "loop": false},
	"break": {"col": 63, "count": 1, "loop": false},
	"death": {"col": 64, "count": 6, "loop": false},
}


## Resolve the sheet for (id, tier, variant) with fallbacks: the variant's tier, the base tier, the
## variant's field sheet, the base field sheet, the legacy `_sheet`, then the painted stand-in.
## Returns {"dir": String, "stem": String, "sheet": String, "tier": StringName, "variant": StringName} or {}.
static func resolve(id: String, tier: StringName = &"field", variant: StringName = &"", groups: Array = GROUPS, subdirs: Array = [""]) -> Dictionary:
	var stems: Array = []
	var seen: Dictionary = {}
	for t in [tier, &"field"]:
		for v in [variant, &""]:
			var stem: String = id + ("_" + String(v) if v != &"" else "") + "_" + String(t)
			if not seen.has(stem):
				seen[stem] = true
				stems.append({"stem": stem, "tier": t, "variant": v})
	for g in groups:
		for sub in subdirs:
			var dir: String = "res://assets/%s/%s%s" % [g, sub, id]
			for st in stems:
				var path: String = "%s/%s.png" % [dir, st["stem"]]
				if ResourceLoader.exists(path):
					return {"id": id, "dir": dir, "stem": st["stem"], "sheet": path, "tier": st["tier"], "variant": st["variant"]}
			var legacy: String = "%s/%s_sheet.png" % [dir, id]
			if ResourceLoader.exists(legacy):
				return {"id": id, "dir": dir, "stem": id + "_sheet", "sheet": legacy, "tier": &"field", "variant": &""}
	return {}


static func has_tier(id: String, tier: StringName, variant: StringName = &"") -> bool:
	var r: Dictionary = resolve(id, tier, variant)
	return not r.is_empty() and r["tier"] == tier and (variant == &"" or r["variant"] == variant)


static func apply(sprite: ActorSprite, id: String, fps: float, tier: StringName = &"field", variant: StringName = &"") -> void:
	sprite.sprite_id = id
	sprite.tier = tier
	sprite.variant = variant
	var r: Dictionary = resolve(id, tier, variant)
	if not r.is_empty():
		_apply_resolved(sprite, r, fps, false)
		return
	for g in GROUPS:
		var painted: String = "res://assets/%s/%s/%s_painted.png" % [g, id, id]
		if ResourceLoader.exists(painted):
			sprite.set_standin(load(painted), fps)
			return
	sprite.set_standin(placeholder(id, Color(0.6, 0.6, 0.65), 128, 110), fps)


static func _apply_resolved(sprite: ActorSprite, r: Dictionary, fps: float, default_mirror: bool) -> void:
	var tex: Texture2D = load(r["sheet"])
	var table_path: String = "%s/%s_frames.json" % [r["dir"], r["stem"]]
	if not FileAccess.file_exists(table_path):
		table_path = "%s/%s_frames.json" % [r["dir"], r["id"]]  # legacy placeholder sheets: <id>_frames.json
	var table: Dictionary = _load_table(table_path, fps)
	var cell: int = int(table.get("_cell", 128))
	var mirror: bool = bool(table.get("_mirror_w", default_mirror))
	var height_px: int = int(table.get("_height_px", 0))
	var height_m: float = float(table.get("_height_m", 0.0))
	table.erase("_cell")
	table.erase("_mirror_w")
	table.erase("_height_px")
	table.erase("_height_m")
	sprite.set_height(height_px, height_m)
	sprite.set_sheet(tex, cell, table, fps, mirror)
	sprite.loaded_tier = r["tier"]
	sprite.loaded_variant = r["variant"]
	var n_path: String = "%s/%s_n.png" % [r["dir"], r["stem"]]
	sprite.set_normal_sheet(load(n_path) if ResourceLoader.exists(n_path) else null)
	var m_path: String = "%s/%s_m.png" % [r["dir"], r["stem"]]
	sprite.set_mask_sheet(load(m_path) if ResourceLoader.exists(m_path) else null)


static func apply_enemy(sprite: ActorSprite, def: EnemyDef, tier: StringName = &"field", variant: StringName = &"") -> void:
	var id: String = String(def.sprite if def.sprite != &"" else def.key)
	var key: String = String(def.key)
	for cand in [id, key]:
		var r: Dictionary = resolve(cand, tier, variant, ["enemies", "bosses"], ["u%d/" % def.universe, ""])
		if not r.is_empty():
			sprite.sprite_id = cand
			sprite.tier = tier
			sprite.variant = variant
			_apply_resolved(sprite, r, def.fps, true)
			return
		for g in ["enemies", "bosses"]:
			for sub in ["u%d/%s" % [def.universe, cand], cand]:
				var painted: String = "res://assets/%s/%s/%s_painted.png" % [g, sub, cand]
				if ResourceLoader.exists(painted):
					sprite.set_standin(load(painted), def.fps)
					return
	var cell_px: int = 128 if def.size <= 1.3 else (256 if def.size <= 2.5 else 512)
	sprite.set_standin(placeholder(key, _element_colour(def), cell_px, int(float(cell_px) * 0.8 * minf(1.0, def.size / (cell_px / 128.0)))), def.fps)


static func _load_table(path: String, fps: float) -> Dictionary:
	var table: Dictionary = {}
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			var json := JSON.new()
			if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
				var d: Dictionary = json.data
				table["_cell"] = int(d.get("cell", 128))
				table["_mirror_w"] = bool(d.get("mirror_w", false))
				table["_height_px"] = int(d.get("height_px", 0))
				table["_height_m"] = float(d.get("height_m", 0.0))
				var anims: Dictionary = d.get("anims", {})
				for k in anims.keys():
					var a: Dictionary = anims[k]
					var holds: Array[float] = []
					for h in a.get("holds", []):
						holds.append(float(h))
					table[StringName(k)] = {"col": int(a.get("col", 0)), "count": int(a.get("count", 1)), "fps": float(a.get("fps", fps)), "loop": bool(a.get("loop", true)), "holds": holds}
				return table
	for k in DEFAULT_TABLE.keys():
		var a: Dictionary = DEFAULT_TABLE[k]
		table[StringName(k)] = {"col": a["col"], "count": a["count"], "fps": fps, "loop": a["loop"], "holds": []}
	table["_cell"] = 128
	return table


static func _element_colour(def: EnemyDef) -> Color:
	var t: Array = def.tags
	if t.has(&"FERRO") or t.has(&"GUN"):
		return Color(0.65, 0.55, 0.42)
	if t.has(&"RUIN") or t.has(&"INK") or t.has(&"DARK"):
		return Color(0.22, 0.2, 0.22)
	if t.has(&"FIRE"):
		return Color(0.72, 0.3, 0.2)
	if t.has(&"LIGHT") or t.has(&"DIVINE"):
		return Color(0.9, 0.86, 0.7)
	if t.has(&"MYCELIA") or t.has(&"SAURIA"):
		return Color(0.5, 0.7, 0.4)
	if t.has(&"VITREOUS"):
		return Color(0.4, 0.6, 0.8)
	if t.has(&"GUILE") or t.has(&"RUBBER"):
		return Color(0.85, 0.8, 0.6)
	if t.has(&"HZ"):
		return Color(0.95, 0.8, 0.3)
	if t.has(&"NULL"):
		return Color(0.95, 0.94, 0.9)
	return Color(0.6, 0.6, 0.65)


## A readable placeholder: a soft blob silhouette with two eyes in the given colour (never shipped).
static func placeholder(id: String, colour: Color, cell: int = 128, height_px: int = 100) -> Texture2D:
	var key: String = "%s|%d|%d|%s" % [id, cell, height_px, colour.to_html()]
	if _placeholders.has(key):
		return _placeholders[key]
	var img := Image.create(cell, cell, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var h: int = height_px
	var w: int = int(float(h) * 0.6)
	var cx: int = cell / 2
	var bottom: int = cell - 8
	var seed_v: int = id.hash()
	var dark: Color = colour.darkened(0.45)
	var light: Color = colour.lightened(0.2)
	for y in range(bottom - h, bottom):
		var t: float = float(bottom - y) / float(h)
		var half: float = float(w) * 0.5 * (0.55 + 0.45 * sin(t * PI) + 0.1 * sin(t * 9.0 + float(seed_v % 7)))
		for x in range(int(cx - half), int(cx + half) + 1):
			if x < 0 or x >= cell:
				continue
			var edge: bool = absf(float(x - cx)) > half - 1.5
			var shade: Color = colour
			if float(x - cx) < -half * 0.3:
				shade = light
			if float(x - cx) > half * 0.4:
				shade = dark
			img.set_pixel(x, y, dark.darkened(0.4) if edge else shade)
	var ey: int = bottom - int(float(h) * 0.72)
	for ex in [cx - w / 5, cx + w / 5]:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if absi(dx) + absi(dy) <= 3:
					img.set_pixel(ex + dx, ey + dy, Color(0.1, 0.1, 0.12))
		img.set_pixel(ex, ey - 1, Color(0.9, 0.9, 0.95))
	var tex := ImageTexture.create_from_image(img)
	_placeholders[key] = tex
	return tex
