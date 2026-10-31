extends Node
## The soak test, for Play: a monkey (thousands of random taps on whatever buttons are showing, taps anywhere, drags,
## the phone's Back, the app paused and resumed), then AI-v-AI matches played to the end on Low and on High. It
## reports the slowest frames (Android calls 5 s without a response an ANR) and where they were, memory as it goes,
## and any match that stops getting on with it. Script errors show in the log: tools/soak.sh counts them. The settings,
## saves and records are put back as they were at the end. Needs a window (controls are picked under the pointer):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/soak_test.tscn -- [events] [matches]

const STALL_MS := 1000.0    # a frame this slow is reported (a loading screen's is expected: it says which screen)

var _rng := RandomNumberGenerator.new()
var _last_us := 0
var _slow := []             # [ms, where]
var _max_ms := 0.0
var _where := ""
var _events := {}           # what the monkey did -> how many times
var _saved := {}            # user:// file -> its bytes, put back at the end


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var n_events := int(a[0]) if a.size() > 0 else 3000
	var n_matches := int(a[1]) if a.size() > 1 else 12
	_rng.seed = 2026
	_keep_user_files()
	Game.main = self
	get_window().size = Vector2i(1280, 720)
	Game.goto_menu()
	_last_us = Time.get_ticks_usec()
	await _monkey(n_events)
	await _matches(n_matches)
	_slow.sort_custom(func(x, y): return x[0] > y[0])
	print("soak: slowest frame %.0f ms; %d frames over %d ms%s" % [_max_ms, _slow.size(), STALL_MS,
		(": " + ", ".join(_slow.slice(0, 8).map(func(s): return "%.0f ms at %s" % [s[0], s[1]]))) if not _slow.is_empty() else ""])
	_put_back_user_files()
	print("soak: done")
	get_tree().quit()


func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := (now - _last_us) / 1000.0
	_last_us = now
	_max_ms = maxf(_max_ms, ms)
	if ms > STALL_MS:
		_slow.append([ms, _where])


func _screen_name() -> String:
	var c: Node = Game.current
	if c == null or not is_instance_valid(c) or c.get_script() == null:
		return "?"
	return String(c.get_script().resource_path).get_file().get_basename()


# ---------------------------------------------------------------- the monkey

func _monkey(n: int) -> void:
	var t0 := Time.get_ticks_msec()
	for i in n:
		_where = _screen_name()
		var r := _rng.randf()
		if r < 0.55:
			await _tap_button()
		elif r < 0.68:
			await _tap(Vector2(_rng.randf_range(0, 1280), _rng.randf_range(0, 720)), "tap anywhere")
		elif r < 0.78:
			await _drag()
		elif r < 0.88:
			_back()
		elif r < 0.93:
			await _pause_resume()
		else:
			_count("wait")
			await _frames(_rng.randi_range(10, 60))
		await _frames(1)
		if i % 500 == 499:
			print("soak: %d events, on %s, %.0f MB static memory, %.0f s" % [i + 1, _screen_name(),
				Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, (Time.get_ticks_msec() - t0) / 1000.0])
	print("soak: monkey %s" % [_events])


func _count(what: String) -> void:
	_events[what] = int(_events.get(what, 0)) + 1


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame


## A button showing (not the email one: that leaves the game), pressed where it is as a finger would.
func _tap_button() -> void:
	var vp := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var buttons := []
	for b in get_tree().root.find_children("*", "BaseButton", true, false):
		var bb: BaseButton = b
		if not bb.is_visible_in_tree() or bb.disabled:
			continue
		if bb is Button and (bb as Button).text == tr("HELP_EMAIL"):
			continue
		var rect := bb.get_global_rect()
		if rect.size.x < 2.0 or not vp.has_point(rect.get_center()):
			continue
		buttons.append(bb)
	if buttons.is_empty():
		await _tap(Vector2(_rng.randf_range(0, 1280), _rng.randf_range(0, 720)), "tap anywhere")
		return
	var pick: BaseButton = buttons[_rng.randi_range(0, buttons.size() - 1)]
	await _tap(pick.get_global_rect().get_center(), "tap a button")


func _tap(p: Vector2, what: String) -> void:
	_count(what)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = p
	down.global_position = p
	Input.parse_input_event(down)
	await _frames(_rng.randi_range(1, 4))
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)


func _drag() -> void:
	_count("drag")
	var p := Vector2(_rng.randf_range(100, 1180), _rng.randf_range(100, 620))
	var to := p + Vector2(_rng.randf_range(-400, 400), _rng.randf_range(-400, 400))
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = p
	down.global_position = p
	Input.parse_input_event(down)
	for k in 8:
		var mv := InputEventMouseMotion.new()
		var q := p.lerp(to, (k + 1) / 8.0)
		mv.position = q
		mv.global_position = q
		mv.relative = (to - p) / 8.0
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mv)
		await _frames(1)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	up.position = to
	up.global_position = to
	Input.parse_input_event(up)


## The phone's Back (not on the home screen, where it quits the game, unless its language picker is open: Back closes
## that).
func _back() -> void:
	if _screen_name() == "main_menu" and not is_instance_valid(Game.current.get("_picker")):
		_count("back (home screen: would quit)")
		return
	_count("back")
	Game.notification(NOTIFICATION_WM_GO_BACK_REQUEST)


## The home button, or the screen turned off, and back: a match is paused, nothing else changes.
func _pause_resume() -> void:
	_count("app paused and resumed")
	var m: Node = Game.current
	var was_match := m != null and is_instance_valid(m) and m.has_method("set_paused")
	var score := str(m.get("points")) if was_match else ""
	Game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	Game.notification(NOTIFICATION_APPLICATION_PAUSED)
	await _frames(_rng.randi_range(2, 20))
	Game.notification(NOTIFICATION_APPLICATION_RESUMED)
	Game.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(2)
	if was_match and is_instance_valid(m):
		if not bool(m.get("paused")) or str(m.get("points")) != score or Game.current != m:
			push_error("soak: the match was not kept paused and as it was over the app's pause")


# ---------------------------------------------------------------- AI matches

func _matches(n: int) -> void:
	Game.goto_menu()
	await _frames(5)
	var venues := ["national", "mall", "provincial", "park", "beach"]
	var events := ["regu", "doubles", "quadrant", "regu"]
	for i in n:
		var level := Game.GFX_LOW if i % 2 == 0 else Game.GFX_HIGH
		Game.settings.graphics = level
		var venue: String = venues[i % venues.size()]
		var ev: String = events[i % events.size()]
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": ["THA", "VIE", "JPN", "SPB"][i % 4], "away": ["MAS", "INA", "KOR", "NPT"][i % 4], "venue": venue,
			"event": ev, "sets": 1, "points": 15, "user_team": -1, "demo": true, "seed": 500 + i, "mode": "quick"}
		_where = "match %d (%s, %s, %s)" % [i, venue, ev, ["Low", "Medium", "High"][level]]
		var t0 := Time.get_ticks_msec()
		var mem0 := Performance.get_monitor(Performance.MEMORY_STATIC)
		add_child(m)
		m.time_scale = 2.0
		var done := {"res": {}}
		m.finished.connect(func(res): done.res = res)
		var last_now := -1.0
		var still := 0
		while done.res.is_empty():
			await get_tree().process_frame
			var now: float = m.now
			still = still + 1 if now <= last_now and not m.paused else 0
			last_now = now
			if still > 600:
				push_error("soak: %s stopped (no match time for 600 frames, state %d)" % [_where, int(m.state)])
				break
			if (Time.get_ticks_msec() - t0) > 20 * 60 * 1000:
				push_error("soak: %s still not over after 20 minutes" % _where)
				break
		print("soak: %s: %s %s in %.0f s (%.1f match minutes), memory %+.1f MB, video %.0f MB" % [_where,
			done.res.get("sets", "?"), done.res.get("set_scores", "?"), (Time.get_ticks_msec() - t0) / 1000.0,
			float(m.now) / 60.0, (Performance.get_monitor(Performance.MEMORY_STATIC) - mem0) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
		m.queue_free()
		await _frames(3)


# ---------------------------------------------------------------- the user's files, put back

func _keep_user_files() -> void:
	for f in DirAccess.get_files_at("user://"):
		_saved[f] = FileAccess.get_file_as_bytes("user://" + f)


func _put_back_user_files() -> void:
	for f in DirAccess.get_files_at("user://"):
		if not _saved.has(f):
			DirAccess.remove_absolute("user://" + f)
	for f in _saved:
		var fa := FileAccess.open("user://" + f, FileAccess.WRITE)
		if fa:
			fa.store_buffer(_saved[f])
			fa.close()
