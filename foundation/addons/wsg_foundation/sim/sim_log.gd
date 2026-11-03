class_name WsgSimLog
extends Logger
## WsgSim's ear on the engine's log: every error and script error during a match (a GDScript error does not stop the
## game - it carries on wrong, which is why "the match finished" is not a pass), and the last lines printed, kept with
## a failure. Thread-safe (the engine logs from any thread).

const KEEP := 60

var _mutex := Mutex.new()
var _errors: Array = []
var _recent: Array = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
		error_type: int, _script_backtraces: Array) -> void:
	if error_type == ERROR_TYPE_WARNING:
		_add_recent("WARNING: %s %s (%s:%d)" % [code, rationale, file, line])
		return
	var kind := "script error" if error_type == ERROR_TYPE_SCRIPT else ("shader error" if error_type == ERROR_TYPE_SHADER else "engine error")
	var msg := "%s at %s:%d in %s(): %s%s" % [kind, file.get_file(), line, function, code, (" - " + rationale) if rationale != "" else ""]
	_mutex.lock()
	_errors.append(msg)
	_mutex.unlock()
	_add_recent(msg)


func _log_message(message: String, _error: bool) -> void:
	_add_recent(message.strip_edges())


func _add_recent(s: String) -> void:
	_mutex.lock()
	_recent.append(s)
	if _recent.size() > KEEP:
		_recent.pop_front()
	_mutex.unlock()


## The errors since the last take.
func take() -> Array:
	_mutex.lock()
	var e := _errors.duplicate()
	_errors.clear()
	_mutex.unlock()
	return e


func recent() -> Array:
	_mutex.lock()
	var r := _recent.duplicate()
	_mutex.unlock()
	return r


func clear() -> void:
	_mutex.lock()
	_errors.clear()
	_recent.clear()
	_mutex.unlock()
