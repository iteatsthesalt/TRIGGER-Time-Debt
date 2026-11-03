## Shared base for every headless test suite (tests/suite_*.gd): the check helpers, node tracking and
## the battle fixtures. A suite extends this file, writes `func test_*() -> void` methods and is picked up by
## tests/run_tests.gd automatically; override run() only to pin an explicit order (suite_core does).
extends Node

var root: Node
var exit_code: int = 0
## The runner's SCRIPT ERROR counter (tests/script_error_log.gd); null when a suite runs without it.
var error_log: Object = null

var _passed: int = 0
var _failed: int = 0
var _current: String = ""
var _nodes: Array[Node] = []


func run() -> void:
	var tests: Array[Callable] = []
	for m in get_method_list():
		var n: String = m["name"]
		if n.begins_with("test_"):
			tests.append(Callable(self, n))
	await run_list(tests)


func run_list(tests: Array[Callable]) -> void:
	for t in tests:
		_current = t.get_method()
		var before: int = _passed + _failed
		var errors_before: int = _script_errors()
		await t.call()
		_guard(_passed + _failed > before, "ran no checks; it crashed before its first check")
		var raised: int = _script_errors() - errors_before
		_guard(raised == 0, "raised %d SCRIPT ERROR(s) (the log above names them): the test stopped there and its later checks never ran" % raised)
		_cleanup()
	print("\n%s: %d passed, %d failed" % [String(get_script().resource_path).get_file(), _passed, _failed])
	exit_code = 1 if _failed > 0 else 0


## A harness guard on the test that just ran: it counts as a failure when it fails and as nothing when it holds,
## so the totals count the tests' own checks.
func _guard(cond: bool, msg: String) -> void:
	if not cond:
		check(false, msg)


func _script_errors() -> int:
	return int(error_log.call("count")) if error_log != null else 0


func passed() -> int:
	return _passed


func failed() -> int:
	return _failed


# ---------------------------------------------------------------- fixtures

func check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		printerr("FAIL [%s]: %s" % [_current, msg])


func check_eq(a: Variant, b: Variant, msg: String) -> void:
	check(a == b, "%s (got %s, want %s)" % [msg, str(a), str(b)])


func check_near(a: float, b: float, tol: float, msg: String) -> void:
	check(absf(a - b) <= tol, "%s (got %s, want %s)" % [msg, str(a), str(b)])


func _cleanup() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _track(n: Node) -> Node:
	_nodes.append(n)
	return n


func _party_member(id: StringName, level: int, pos: Vector3) -> Node3D:
	var body := Node3D.new()
	body.name = String(id)
	var st := CombatantStats.new()
	st.name = "CombatantStats"
	st.apply_party_curve(id, level)
	st.weapon_tags = [&"SWORD"]
	st.weapon_hits = 2
	if id == &"sera":
		st.weapon_tags = [&"PIERCING"]
	body.add_child(st)
	var sc := StatusComponent.new()
	sc.name = "StatusComponent"
	body.add_child(sc)
	if id == &"crono":
		var td := TimeDebtComponent.new()
		td.name = "TimeDebtComponent"
		body.add_child(td)
	if id == &"sera":
		var sol := SolidityComponent.new()
		sol.name = "SolidityComponent"
		body.add_child(sol)
	root.add_child(body)
	body.global_position = pos
	st.reset_vitals()
	_track(body)
	return body


func _enemy(id: StringName, level: int, pos: Vector3, shield: int, weak: Array, opts: Dictionary = {}) -> Node3D:
	var body := Node3D.new()
	body.name = String(id)
	var st := CombatantStats.new()
	st.name = "CombatantStats"
	st.actor_id = id
	st.apply_enemy_curve(level, String(opts.get("kind", "regular")))
	if opts.has("hp"):
		st.base_max_hp = int(opts["hp"])
	st.weapon_tags = CombatTags.to_names(opts.get("weapon_tags", [&"BLUNT"]))
	st.tags = CombatTags.to_names(opts.get("tags", []))
	body.add_child(st)
	var sh := ShieldComponent.new()
	sh.name = "ShieldComponent"
	sh.max_shield = shield
	sh.weaknesses = CombatTags.to_names(weak)
	if opts.has("keyed"):
		var kp: Array[Dictionary] = []
		for k in opts["keyed"]:
			kp.append(k)
		sh.keyed_plates = kp
	if opts.has("belief"):
		sh.belief_number = int(opts["belief"])
	if opts.has("resists"):
		sh.resists = CombatTags.to_names(opts["resists"])
	body.add_child(sh)
	var sc := StatusComponent.new()
	sc.name = "StatusComponent"
	body.add_child(sc)
	root.add_child(body)
	body.global_position = pos
	st.reset_vitals()
	sh.reset_shields()
	_track(body)
	return body


func _tech(d: Dictionary) -> TechDef:
	return TechDef.from_dict(d)


func _coord(seed_v: int = 7) -> BattleCoordinator:
	var c := BattleCoordinator.new()
	c.auto_tick = false
	c.rng_seed = seed_v
	c.fixed_variance = 1.0
	root.add_child(c)
	_track(c)
	return c


## The coordinator fixture's technique library: the eight techniques the core battle tests cast, as data/techs
## defines them (Data.techs), so a retune of their rows is what those tests exercise (DATA-22).
const LIB_IDS: Array[StringName] = [
	&"time_slice", &"astral_slash", &"rewind", &"hold", &"borrowed_future", &"tachyon_needle", &"eclipse_x_strike",
	&"teppo_ash_cut",
]


func _lib() -> Dictionary:
	var lib: Dictionary = {}
	for id in LIB_IDS:
		lib[id] = Data.techs[id]
	return lib


func _start(c: BattleCoordinator, party: Array, enemies: Array, cfg: Dictionary = {}) -> void:
	var config: Dictionary = {"techs": _lib(), "advantage": "normal"}
	for k in cfg.keys():
		config[k] = cfg[k]
	c.start_battle(party, enemies, Vector3.ZERO, config)


func _advance_until_window(c: BattleCoordinator, max_s: float = 30.0) -> Node:
	var t: float = 0.0
	while c.state != BattleCoordinator.State.COMMAND_WAIT and t < max_s and c.state != BattleCoordinator.State.IDLE:
		c.advance(1.0 / 60.0)
		t += 1.0 / 60.0
	return c.active_actor


func _advance_until_actor(c: BattleCoordinator, id: StringName, max_s: float = 60.0) -> Node:
	var t: float = 0.0
	while t < max_s and c.state != BattleCoordinator.State.IDLE:
		var a: Node = _advance_until_window(c, max_s - t)
		if a == null:
			return null
		if CombatantStats.of(a).actor_id == id:
			return a
		c.cmd_guard(a)
		t += 0.5
	return null
