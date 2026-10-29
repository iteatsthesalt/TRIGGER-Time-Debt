## Writes labeled placeholder sprite sheets (4 directions x idle/walk/attack)
## for every cast member and sample enemy, laid out the way ActorSprite reads them.
##   godot --headless --path . --script res://tools/sprites/make_placeholders.gd
##   godot --headless --path . --import    # import the new PNGs before build_samples.gd
## Plain silhouettes + name only: returning Chrono Trigger characters stay labeled
## placeholders until original art exists (AUTOPILOT.md art rules).
extends SceneTree

const OUT_DIR := "res://assets/sprites/placeholders"
## [sheet id, label, body colour, silhouette]
const CAST := [
	[&"crono", "CRONO", Color(0.25, 0.41, 0.88), &"hero"],
	[&"lucca", "LUCCA", Color(0.58, 0.44, 0.86), &"hero"],
	[&"frog", "FROG", Color(0.18, 0.55, 0.34), &"hero"],
	[&"marle", "MARLE", Color(0.93, 0.78, 0.35), &"hero"],
	[&"tove", "TOVE", Color(0.20, 0.62, 0.70), &"hero"],
	[&"dov", "DOV", Color(0.72, 0.42, 0.22), &"hero"],
	[&"ilse", "ILSE", Color(0.80, 0.36, 0.52), &"hero"],
	[&"ogre", "OGRE", Color(0.70, 0.13, 0.13), &"brute"],
	[&"imp", "IMP", Color(1.00, 0.55, 0.00), &"imp"],
]
## 3x5 pixel font; rows top to bottom, '#' = ink.
const FONT := {
	"A": [".#.", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
	"C": [".##", "#..", "#..", "#..", ".##"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
	"E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
	"G": [".##", "#..", "#.#", "#.#", ".##"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
	"I": ["###", ".#.", ".#.", ".#.", "###"], "J": ["..#", "..#", "..#", "#.#", ".#."],
	"K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
	"M": ["#.#", "###", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
	"O": [".#.", "#.#", "#.#", "#.#", ".#."], "P": ["##.", "#.#", "##.", "#..", "#.."],
	"Q": [".#.", "#.#", "#.#", "##.", ".##"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
	"S": [".##", "#..", ".#.", "..#", "##."], "T": ["###", ".#.", ".#.", ".#.", ".#."],
	"U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
	"W": ["#.#", "#.#", "###", "###", "#.#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
	"Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "Z": ["###", "..#", ".#.", "#..", "###"],
}
const STEP_DIRS := {&"down": Vector2i(0, 1), &"left": Vector2i(-1, 0), &"right": Vector2i(1, 0), &"up": Vector2i(0, -1)}

var _clip: Rect2i


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for d in CAST:
		var img := make_sheet(d[1], d[2], d[3])
		var path := "%s/%s.png" % [OUT_DIR, d[0]]
		print("saved %s (%s)" % [path, error_string(img.save_png(ProjectSettings.globalize_path(path)))])
	quit()


func make_sheet(label: String, color: Color, shape: StringName) -> Image:
	var fs := ActorSprite.FRAME_SIZE
	var img := Image.create(fs.x * ActorSprite.SHEET_COLUMNS, fs.y * ActorSprite.DIRECTIONS.size(), false, Image.FORMAT_RGBA8)
	for row in ActorSprite.DIRECTIONS.size():
		for act in ActorSprite.ANIMS:
			var spec: Array = ActorSprite.ANIMS[act]
			for f in int(spec[1]):
				var origin := Vector2i((int(spec[0]) + f) * fs.x, row * fs.y)
				_clip = Rect2i(origin, fs)
				_draw_frame(img, origin, ActorSprite.DIRECTIONS[row], act, f, label, color, shape)
	return img


func _draw_frame(img: Image, o: Vector2i, dir: StringName, act: StringName, f: int,
		label: String, color: Color, shape: StringName) -> void:
	var ink := color.darkened(0.6)
	var skin := color.lightened(0.45)
	var side_view: bool = dir == &"left" or dir == &"right"
	var torso_w: int = {&"hero": 10, &"brute": 16, &"imp": 8}[shape]
	var head_r: int = 5 if shape == &"imp" else 6
	var bob: int = 0
	var stride: int = 0
	match act:
		&"idle":
			bob = f
		&"walk":
			stride = [2, 0, -2, 0][f]
			bob = [0, 1, 0, 1][f]
	var cx: int = o.x + 16

	# Legs: side by side from the front/back, scissoring in profile.
	for leg in 2:
		var lx: int
		var lh: int = 9
		if side_view:
			lx = cx - 2 + (stride if leg == 0 else -stride)
		else:
			lx = cx - 5 + leg * 6
			if (stride > 0 and leg == 0) or (stride < 0 and leg == 1):
				lh -= 2
		_rect(img, Rect2i(lx - 1, o.y + 31, 6, lh + 2), ink)
		_rect(img, Rect2i(lx, o.y + 32, 4, lh), color.darkened(0.25))

	# Torso.
	var torso := Rect2i(cx - torso_w / 2, o.y + 17 + bob, torso_w, 15)
	_rect(img, torso.grow(1), ink)
	_rect(img, torso, color)

	# Arms swing with the stride; attacks swing a weapon out along the facing.
	if act == &"attack":
		var d: Vector2i = STEP_DIRS[dir]
		var start := Vector2i(cx + (0 if side_view else 6), o.y + 23 + bob)
		var reach: int = [4, 11, 7][f]
		_line(img, start, d, reach + 4, 3, ink)
		_line(img, start, d, reach + 3, 1, color.lightened(0.7))
	elif side_view:
		_rect(img, Rect2i(cx - 2 + stride, o.y + 20 + bob, 4, 9), color.darkened(0.15))
	else:
		_rect(img, Rect2i(torso.position.x - 3, o.y + 19 + bob + stride / 2, 3, 10), color.darkened(0.15))
		_rect(img, Rect2i(torso.end.x, o.y + 19 + bob - stride / 2, 3, 10), color.darkened(0.15))

	# Head, horns, face.
	var hc := Vector2i(cx, o.y + 10 + bob)
	if shape == &"imp":
		for s in [-1, 1]:
			for i in 3:
				_rect(img, Rect2i(hc.x + s * (3 + i / 2), hc.y - head_r - i, 1, 1), ink)
	_disc(img, hc, head_r + 1, ink)
	_disc(img, hc, head_r, color.darkened(0.3) if dir == &"up" else skin)
	match dir:
		&"down":
			_rect(img, Rect2i(hc.x - 3, hc.y, 1, 2), ink)
			_rect(img, Rect2i(hc.x + 2, hc.y, 1, 2), ink)
		&"left":
			_rect(img, Rect2i(hc.x - 3, hc.y, 1, 2), ink)
		&"right":
			_rect(img, Rect2i(hc.x + 3, hc.y, 1, 2), ink)

	_label(img, o, label)


func _label(img: Image, o: Vector2i, text: String) -> void:
	var w: int = text.length() * 4 - 1
	var x0: int = o.x + (ActorSprite.FRAME_SIZE.x - w) / 2
	_rect(img, Rect2i(x0 - 1, o.y + 42, w + 2, 6), Color(0, 0, 0, 0.8))
	for i in text.length():
		var glyph: Array = FONT.get(text[i], [])
		for gy in glyph.size():
			for gx in 3:
				if glyph[gy][gx] == "#":
					_rect(img, Rect2i(x0 + i * 4 + gx, o.y + 42 + gy, 1, 1), Color.WHITE)


func _rect(img: Image, r: Rect2i, c: Color) -> void:
	var clipped := r.intersection(_clip)
	if clipped.has_area():
		img.fill_rect(clipped, c)


func _disc(img: Image, center: Vector2i, r: int, c: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r + r:
				_rect(img, Rect2i(center.x + dx, center.y + dy, 1, 1), c)


func _line(img: Image, start: Vector2i, d: Vector2i, length: int, thickness: int, c: Color) -> void:
	var across := Vector2i(absi(d.y), absi(d.x))
	for i in length:
		for t in thickness:
			var p: Vector2i = start + d * i + across * (t - thickness / 2)
			_rect(img, Rect2i(p, Vector2i.ONE), c)
