## The Progression balancing tables (Combat Laws Bible §15.4–15.5) as functions of level.
class_name StatCurves
extends RefCounted

## Rows: level, HP tank, HP balanced, HP caster, Def, Spd.
const PARTY_ROWS: Array = [
	[1, 120.0, 95.0, 75.0, 8.0, 100.0],
	[10, 320.0, 260.0, 200.0, 22.0, 108.0],
	[12, 380.0, 310.0, 235.0, 26.0, 110.0],
	[20, 620.0, 505.0, 385.0, 42.0, 118.0],
	[21, 650.0, 530.0, 405.0, 45.0, 120.0],
	[30, 930.0, 760.0, 580.0, 62.0, 132.0],
	[35, 1100.0, 900.0, 685.0, 72.0, 135.0],
	[40, 1350.0, 1100.0, 840.0, 85.0, 140.0],
	[99, 3400.0, 2770.0, 2100.0, 180.0, 165.0],
]

## Per-character attack curves: [patk_base, patk_per_lv, eatk_base, eatk_per_lv, mp_base, mp_per_lv, spd_offset, archetype]
const CHARACTER_CURVES := {
	&"crono": [12.0, 6.0, 6.0, 6.0, 0.0, 0.0, 0.0, "tank"],
	&"sera": [8.0, 4.5, 10.0, 6.2, 30.0, 2.2, 12.0, "caster"],
	&"krona": [14.0, 6.4, 6.0, 5.0, 16.0, 1.6, 4.0, "tank"],
	&"cassia": [10.0, 5.2, 8.0, 5.6, 24.0, 2.0, -8.0, "tank"],
	&"xyloph": [9.0, 5.0, 12.0, 6.0, 30.0, 2.4, 2.0, "balanced"],
	&"vesper": [11.0, 5.8, 10.0, 5.6, 24.0, 2.0, -4.0, "balanced"],
	&"glenn": [12.0, 5.6, 6.0, 4.6, 20.0, 1.8, 10.0, "balanced"],
	&"static": [8.0, 4.6, 12.0, 6.2, 28.0, 2.2, 8.0, "caster"],
	&"omega": [10.0, 5.0, 14.0, 6.4, 40.0, 2.6, -2.0, "caster"],
	&"vaelos_child": [8.0, 4.8, 10.0, 6.0, 24.0, 2.0, 0.0, "caster"],
	&"marle": [9.0, 5.0, 11.0, 5.8, 26.0, 2.0, 6.0, "balanced"],
}


static func _row(level: int) -> Array:
	# Interpolate linearly between rows (level, hp_t, hp_b, hp_c, def, spd).
	var lv: float = float(clampi(level, 1, 99))
	var prev: Array = PARTY_ROWS[0]
	for row in PARTY_ROWS:
		if float(row[0]) >= lv:
			if float(row[0]) == lv or prev == row:
				return row
			var t: float = (lv - float(prev[0])) / float(row[0] - prev[0])
			var out: Array = [lv]
			for i in range(1, 6):
				out.append(lerpf(float(prev[i]), float(row[i]), t))
			return out
		prev = row
	return PARTY_ROWS[PARTY_ROWS.size() - 1]


static func party_hp(level: int, archetype: String) -> int:
	var r: Array = _row(level)
	match archetype:
		"tank":
			return roundi(float(r[1]))
		"caster":
			return roundi(float(r[3]))
	return roundi(float(r[2]))


static func party_def(level: int, archetype: String) -> Vector2:
	var d: float = float(_row(level)[4])
	match archetype:
		"tank":
			return Vector2(d * 1.15, d)
		"caster":
			return Vector2(d * 0.85, d * 1.15)
	return Vector2(d, d)


static func party_spd(level: int, actor_id: StringName) -> float:
	var base: float = float(_row(level)[5])
	var c: Array = CHARACTER_CURVES.get(actor_id, CHARACTER_CURVES[&"marle"])
	return base + float(c[6])


static func party_atk(level: int, actor_id: StringName) -> Vector2:
	var c: Array = CHARACTER_CURVES.get(actor_id, CHARACTER_CURVES[&"marle"])
	return Vector2(float(c[0]) + float(c[1]) * level, float(c[2]) + float(c[3]) * level)


static func party_mp(level: int, actor_id: StringName) -> int:
	var c: Array = CHARACTER_CURVES.get(actor_id, CHARACTER_CURVES[&"marle"])
	return roundi(float(c[4]) + float(c[5]) * level)


static func party_luk(level: int, actor_id: StringName) -> float:
	var bonus: float = 5.0 if actor_id == &"sera" or actor_id == &"glenn" else 0.0
	return 5.0 + 0.5 * level + bonus


static func archetype_of(actor_id: StringName) -> String:
	var c: Array = CHARACTER_CURVES.get(actor_id, CHARACTER_CURVES[&"marle"])
	return String(c[7])


## Enemy curves (§15.5). kind: regular | elite | miniboss | boss
static func enemy_hp(level: int, kind: String) -> int:
	match kind:
		"elite":
			return roundi((30.0 + 25.0 * level) * 3.0)
		"miniboss":
			return roundi(1000.0 * level)
		"boss":
			return roundi(2250.0 * level)
	return roundi(30.0 + 25.0 * level)


static func enemy_atk(level: int) -> float:
	return 12.0 + 6.0 * level


static func enemy_pdef(level: int, kind: String) -> float:
	return 5.5 * level if kind == "boss" else 2.0 + 4.0 * level


static func enemy_edef(level: int, kind: String) -> float:
	return 5.5 * level if kind == "boss" else maxf(1.0, 4.0 * level - 2.0)


static func enemy_spd(level: int, kind: String) -> float:
	return 90.0 + 0.6 * level + (10.0 if kind == "elite" else 0.0)
