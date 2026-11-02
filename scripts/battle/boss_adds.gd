## A boss's adds as its file authors them (data/bosses/<id>.json `adds`): which rows a phase places when it
## begins, the rows a `trigger` holds back for later, the respawn clock and each row's overrides. BossController
## owns one and does the spawning (EnemySpawner).
##
## A row: {key, count, phase ("<phase id>" or "start"), def? (inline definition), shield? level? weak? tags?
## resist? hp? xp? (overrides on the codex enemy), trigger?, requires? ("Flag=State"), respawn_s?}.
## - `trigger` rows never spawn when their phase begins: "every_<N>pct_hp_lost" fires each time the boss loses
##   another N% while the phase lasts; any other trigger id waits for spawn_triggered(id) (a director's call).
## - `requires` holds a row back unless the boss's `holds` says the pair is set (Goyama=Incinerated).
## - `respawn_s`: an add of that row that falls comes back that many battle seconds later, while its phase lasts.
## The cap per kind is the file's `max_adds`, else the largest authored count (never below EnemySpawner's 3), so
## an authored "6 arms" places six.
class_name BossAdds
extends RefCounted

const OVERRIDES: Array[String] = ["shield", "level", "weak", "resist", "tags", "hp", "xp"]

var boss: BossDef
## row index -> how many N% steps of HP the boss had lost when last checked (every_<N>pct_hp_lost)
var _hp_steps: Dictionary = {}
## [{row, at}] respawns waiting on battle_time
var _respawns: Array[Dictionary] = []


func _init(b: BossDef) -> void:
	boss = b


## The cap on one kind of add standing at once.
func cap() -> int:
	if boss.raw.has("max_adds"):
		return EnemySpawner.max_adds_of(boss.raw)
	var most: int = EnemySpawner.DEFAULT_MAX_ADDS
	for row in boss.adds:
		most = maxi(most, int(row.get("count", 1)))
	return most


func rows() -> Array:
	return boss.adds


## The rows phase i places as it begins (no trigger, requirement met).
func rows_for_phase(i: int) -> Array[int]:
	var out: Array[int] = []
	for r in boss.adds.size():
		var row: Dictionary = boss.adds[r]
		if _in_phase(row, i) and String(row.get("trigger", "")) == "" and _required(row):
			out.append(r)
	return out


## The rows of phase i held back for `trigger`.
func rows_for_trigger(i: int, trigger: String) -> Array[int]:
	var out: Array[int] = []
	for r in boss.adds.size():
		var row: Dictionary = boss.adds[r]
		if _in_phase(row, i) and String(row.get("trigger", "")) == trigger and _required(row):
			out.append(r)
	return out


## Phase i begins at `hp_ratio`: its HP-lost rows count their steps from here.
func begin_phase(i: int, hp_ratio: float) -> void:
	for r in boss.adds.size():
		var step: float = hp_step(String(boss.adds[r].get("trigger", "")))
		if step > 0.0 and _in_phase(boss.adds[r], i):
			_hp_steps[r] = _steps(hp_ratio, step)


## Rows of phase i whose every_<N>pct_hp_lost step was crossed since the last call, each once per step crossed.
func hp_lost_rows(i: int, hp_ratio: float) -> Array[int]:
	var out: Array[int] = []
	for r in boss.adds.size():
		var row: Dictionary = boss.adds[r]
		var step: float = hp_step(String(row.get("trigger", "")))
		if step <= 0.0 or not _in_phase(row, i) or not _required(row):
			continue
		var steps: int = _steps(hp_ratio, step)
		var before: int = int(_hp_steps.get(r, 0))
		_hp_steps[r] = maxi(before, steps)
		for k in maxi(0, steps - before):
			out.append(r)
	return out


static func _steps(hp_ratio: float, step: float) -> int:
	return int(floor((1.0 - hp_ratio) / step + 0.0001))


## 0.2 for "every_20pct_hp_lost", else 0.
static func hp_step(trigger: String) -> float:
	if trigger.begins_with("every_") and trigger.ends_with("pct_hp_lost"):
		var n: float = float(trigger.trim_prefix("every_").trim_suffix("pct_hp_lost"))
		return n / 100.0 if n > 0.0 else 0.0
	return 0.0


## An add of row `r` fell at battle time `now`: queue it back if the row respawns.
func on_add_down(r: int, now: float) -> void:
	if r < 0 or r >= boss.adds.size():
		return
	var s: float = float(boss.adds[r].get("respawn_s", 0.0))
	if s > 0.0:
		_respawns.append({"row": r, "at": now + s})


## Rows whose respawn is due at `now` while phase i lasts (a respawn queued in an earlier phase is dropped).
func due_respawns(i: int, now: float) -> Array[int]:
	var out: Array[int] = []
	var keep: Array[Dictionary] = []
	for w in _respawns:
		var r: int = int(w["row"])
		if not _in_phase(boss.adds[r], i):
			continue
		if float(w["at"]) <= now:
			out.append(r)
		else:
			keep.append(w)
	_respawns = keep
	return out


## The EnemyDef row r spawns: its inline `def`, or the codex enemy with the row's overrides applied.
func def_for_row(r: int) -> EnemyDef:
	return _def_for(boss.adds[r]) if r >= 0 and r < boss.adds.size() else null


## The EnemyDef for `key` (a `summon:<key>` action): the first row naming it, else the codex enemy.
func def_for_key(key: StringName) -> EnemyDef:
	for row in boss.adds:
		if StringName(String(row.get("key", ""))) == key:
			return _def_for(row)
	return Data.enemy(key)


## The row index an add was spawned from (-1 for a plain summon).
static func row_of(add: Node) -> int:
	return int(add.get_meta(&"boss_add_row", -1)) if add != null else -1


func _def_for(row: Dictionary) -> EnemyDef:
	var key: String = String(row.get("key", ""))
	var d: Dictionary
	if row.has("def"):
		d = (row["def"] as Dictionary).duplicate(true)
		d["name"] = String(row.get("name", key.capitalize()))
		d["universe"] = boss.universe
		d["level"] = boss.level
		if d.get("fps", 60.0) is Array:
			d["fps"] = 60.0
	else:
		var codex: EnemyDef = Data.enemy(StringName(key))
		if codex == null:
			return null
		var touched: bool = false
		for k in OVERRIDES:
			touched = touched or row.has(k)
		if not touched:
			return codex
		d = codex.raw.duplicate(true)
	d["key"] = key
	d["id"] = String(d.get("id", key)) if not row.has("def") else key
	for k in OVERRIDES:
		if row.has(k):
			d[k] = row[k]
	return EnemyDef.from_dict(d)


func _in_phase(row: Dictionary, i: int) -> bool:
	var ph: String = String(row.get("phase", ""))
	return ph == String(boss.phase(i).get("id", "")) or (i == 0 and ph == "start")


func _required(row: Dictionary) -> bool:
	var req: String = String(row.get("requires", ""))
	return req == "" or (boss.holds.is_valid() and bool(boss.holds.call(req)))
