## The test runner's error counter (OS.add_logger): every SCRIPT ERROR the engine reports while the suites run (a
## call on null, a bad index, a parse error in a suite) is counted here, so a test that dies part way through,
## before or after an await, fails by name in suite_base.run_list instead of passing on the checks it made before
## it died. push_error and engine errors are not counted (tests provoke those on purpose); warnings neither.
## Not a suite: run_tests.gd loads only suite_*.gd. The engine may log from any thread, hence the mutex.
extends Logger

var _mutex := Mutex.new()
var _count: int = 0
var _first: String = ""


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	_mutex.lock()
	_count += 1
	if _first == "":
		_first = "%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function]
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


## The SCRIPT ERRORs reported so far.
func count() -> int:
	_mutex.lock()
	var n: int = _count
	_mutex.unlock()
	return n


## The first one, for the runner's summary ("" when there was none).
func first() -> String:
	_mutex.lock()
	var s: String = _first
	_mutex.unlock()
	return s
