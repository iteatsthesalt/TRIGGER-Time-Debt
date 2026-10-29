## Resolves sprite ids to sheets and frame tables (assets/<group>/<id>/<id>_field.png + <id>_frames.json),
## falling back to the painted stand-in, then to a generated placeholder so every actor is always visible.
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


static func apply(sprite: ActorSprite, id: String, fps: float) -> void:
	for g in GROUPS:
		var dir: String = "res://assets/%s/%s" % [g, id]
		var sheet_path: String = "%s/%s_field.png" % [dir, id]
		var table_path: String = "%s/%s_frames.json" % [dir, id]
		if ResourceLoader.exists(sheet_path):
			var tex: Texture2D = load(sheet_path)
			var table: Dictionary = _load_table(table_path, fps)
			var cell: int = int(table.get("_cell", 128))
			var mirror: bool = bool(table.get("_mirror_w", false))
			var height_px: int = int(table.get("_height_px", 0))
			var height_m: float = float(table.get("_height_m", 0.0))
			table.erase("_cell")
			table.erase("_mirror_w")
			table.erase("_height_px")
			table.erase("_height_m")
			sprite.set_height(height_px, height_m)
			sprite.set_sheet(tex, cell, table, fps, mirror)
			var n_path: String = "%s/%s_field_n.png" % [dir, id]
			if ResourceLoader.exists(n_path):
				sprite.set_normal_sheet(load(n_path))
			var m_path: String = "%s/%s_field_m.png" % [dir, id]
			if ResourceLoader.exists(m_path):
				sprite.set_mask_sheet(load(m_path))
			return
		var painted: String = "%s/%s_painted.png" % [dir, id]
		if ResourceLoader.exists(painted):
			sprite.set_standin(load(painted), fps)
			return
	sprite.set_standin(placeholder(id, Color(0.6, 0.6, 0.65), 128, 110), fps)


static func apply_enemy(sprite: ActorSprite, def: EnemyDef) -> void:
	var id: String = String(def.sprite if def.sprite != &"" else def.key)
	var key: String = String(def.key)
	for cand in [id, key]:
		for g in ["enemies", "bosses"]:
			for sub in ["u%d/%s" % [def.universe, cand], cand]:
				var dir: String = "res://assets/%s/%s" % [g, sub]
				var sheet_path: String = "%s/%s_sheet.png" % [dir, cand]
				if ResourceLoader.exists(sheet_path):
					var table: Dictionary = _load_table("%s/%s_frames.json" % [dir, cand], def.fps)
					var cell: int = int(table.get("_cell", 128))
					var mirror: bool = bool(table.get("_mirror_w", true))
					var height_px: int = int(table.get("_height_px", 0))
					var height_m: float = float(table.get("_height_m", 0.0))
					table.erase("_cell")
					table.erase("_mirror_w")
					table.erase("_height_px")
					table.erase("_height_m")
					sprite.set_height(height_px, height_m)
					sprite.set_sheet(load(sheet_path), cell, table, def.fps, mirror)
					return
				var painted: String = "%s/%s_painted.png" % [dir, cand]
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
