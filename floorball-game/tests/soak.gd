extends Node
## The soak test (Play Store readiness): thousands of random inputs on every screen and in matches, at one graphics
## level, the way a restless player or a monkey would: taps and drags anywhere, the phone's Back, the app sent to the
## background and back. It counts every engine error and script error (a logger), every stall (a frame over 2 s
## here), and checks after each step that a screen is up; after each trip to the background that a match is paused,
## not lost; and at the end that the saves read back.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/soak.tscn -- [graphics 0-2] [inputs] [matches]
## Exits 1 on any error, stall or lost match.

var errors := []
var stalls := 0
var lost := 0
var steps := 0
var _rng := RandomNumberGenerator.new()
var _last := 0


class Catch extends Logger:
	var into: Array

	func _init(a: Array) -> void:
		into = a

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		# Engine warnings aside (the dummy audio driver here, the GPU's), errors and script errors count.
		if error_type == ERROR_TYPE_WARNING:
			return
		var what := "%s %s:%d %s %s" % [function, file.get_file(), line, code, rationale]
		if "audio" in what.to_lower() or "alsa" in what.to_lower() or "Lambda capture" in what:
			return
		into.append(what)

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var gfx := int(a[0]) if a.size() > 0 else 0
	var inputs := int(a[1]) if a.size() > 1 else 3000
	var matches := int(a[2]) if a.size() > 2 else 3
	OS.add_logger(Catch.new(errors))
	_rng.seed = 20261027 + gfx
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = gfx
	Game.settings.auto_gfx = false
	get_window().size = Vector2i(1280, 720)
	_last = Time.get_ticks_msec()
	# Menus: random inputs, now and then a random screen.
	var screens := ["res://ui/main_menu.gd", "res://ui/quick_setup.gd", "res://ui/settings_screen.gd", "res://ui/howto_screen.gd",
		"res://ui/cup_screen.gd", "res://ui/season_screen.gd", "res://ui/licences_screen.gd", "res://ui/help_screen.gd",
		"res://ui/privacy_screen.gd", "res://ui/button_layout_screen.gd"]
	Game.show_screen("res://ui/main_menu.gd")
	await _frames(5)
	for i in inputs:
		if i % 150 == 0:
			Game.show_screen(screens[_rng.randi_range(0, screens.size() - 1)])
			await _frames(3)
		await _poke(false)
		if i % 500 == 0:
			print("soak: %d menu inputs, %d errors, %d stalls" % [i, errors.size(), stalls])
	# Matches: one you play, mashed (leaving it by its own pause menu or Back is allowed: that is the player's
	# choice, not a loss); then one AI v AI, sped up, played to the end.
	for k in matches:
		Game.start_match({"home": "SWE", "away": "FIN", "venue": ["arena", "hall", "school"][k % 3], "user_team": k % 2,
			"seed": 40 + k, "period": 1.0, "mode": "quick"})
		await _frames(30)
		var mine: Node = Game.current
		if mine == null or not mine.has_method("set_paused"):
			print("LOST: the match did not start")
			lost += 1
		for i in 400:
			await _poke(true)
		Game.start_match({"home": ["SWE", "SUI", "CZE"][k % 3], "away": ["FIN", "LAT", "SVK"][k % 3],
			"venue": ["arena", "hall", "school"][(k + 1) % 3], "user_team": -1, "seed": 70 + k, "period": 1.0, "mode": "quick"})
		await _frames(10)
		var m: Node = Game.current
		Engine.time_scale = 4.0
		var t0 := Time.get_ticks_msec()
		# Every frame played, one in eight drawn: the match's code all runs, at the speed of the game, not the renderer.
		var f := 0
		while is_instance_valid(m) and m == Game.current and m.get("phase") != "over" and Time.get_ticks_msec() - t0 < 240000:
			RenderingServer.render_loop_enabled = f % 8 == 0
			f += 1
			await _frames(1)
		RenderingServer.render_loop_enabled = true
		Engine.time_scale = 1.0
		var done: bool = is_instance_valid(m) and m.get("phase") == "over"
		if not done:
			lost += 1
		print("soak: AI v AI match %d %s (%s), %d errors, %d stalls, %d lost" % [k + 1, "over" if done else "NOT FINISHED",
			str(m.get("rules").get("goals")) if done else "-", errors.size(), stalls, lost])
		Game.goto_menu()
		await _frames(5)
	# The saves read back.
	var ok_saves := Game._read_json(Game.SETTINGS_PATH) is Dictionary
	print("soak: graphics %d, %d steps: %d errors, %d stalls, %d matches lost, saves %s" % [gfx, steps, errors.size(), stalls, lost, "ok" if ok_saves else "BAD"])
	for e in errors.slice(0, 15):
		print("  error: ", e)
	get_tree().quit(1 if errors.size() > 0 or stalls > 0 or lost > 0 or not ok_saves else 0)


## One random input: a tap, a drag, Back, or the app to the background and back.
func _poke(in_match: bool) -> void:
	steps += 1
	var size := Vector2(get_window().size)
	var r := _rng.randf()
	var cur: Node = Game.current
	if r < 0.55:
		var p := Vector2(_rng.randf() * size.x, _rng.randf() * size.y)
		_touch(p, true)
		await _frames(1)
		_touch(p, false)
	elif r < 0.85:
		var p := Vector2(_rng.randf() * size.x, _rng.randf() * size.y)
		var q := p + Vector2(_rng.randf_range(-300, 300), _rng.randf_range(-300, 300))
		_touch(p, true)
		for k in 4:
			await _frames(1)
			_drag(p.lerp(q, (k + 1) / 4.0))
		_touch(q, false)
	elif r < 0.95:
		# Back, but never from the home screen (that closes the game, and this test with it).
		if cur and is_instance_valid(cur) and not String(cur.get_script().resource_path).ends_with("main_menu.gd"):
			Game.go_back()
	else:
		# Home button or screen off, then back: a match must be paused, and still there.
		var was: Node = Game.current
		Game._notification(NOTIFICATION_APPLICATION_PAUSED)
		Game._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		await _frames(3)
		if is_instance_valid(was) and was.has_method("set_paused"):
			if Game.current != was or was.get("paused") != true:
				lost += 1
				print("LOST: the match was not paused or not kept when the app went to the background")
		Game._notification(NOTIFICATION_APPLICATION_RESUMED)
		Game._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frames(2 if not in_match else 1)
	if Game.current == null or not is_instance_valid(Game.current):
		lost += 1
		print("LOST: no screen after step %d" % steps)
		Game.goto_menu()
		await _frames(3)


## A finger (the project turns the mouse into touch: pointing/emulate_touch_from_mouse).
func _touch(p: Vector2, down: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.position = p
	mb.global_position = p
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = down
	Input.parse_input_event(mb)


func _drag(p: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = p
	mm.global_position = p
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(mm)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		if now - _last > 2000 and Engine.time_scale <= 1.0:
			stalls += 1
			print("STALL: %d ms on a frame (step %d, %s)" % [now - _last, steps, Game.current.get_script().resource_path.get_file() if Game.current else "-"])
		_last = now
