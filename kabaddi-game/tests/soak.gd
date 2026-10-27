extends Node
## The long soak before a store release: thousands of random inputs through the whole game, then AI-v-AI matches,
## on each graphics level asked for. It counts engine and script errors (a Logger sees every one), frames that
## stall, screens that trap the player, saves that stop reading back, and matches that never end.
##   godot --headless --path . --fixed-fps 30 res://tests/soak.tscn -- [inputs] [matches] [levels]
##   (defaults 4000 inputs, 10 matches, levels "0,2": Low and High; 0 inputs or 0 matches leaves that part out)
## The inputs need a window to land in, so run them drawn, on a virtual screen (which also draws Low and High):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --resolution 1560x720 \
##       --fixed-fps 30 res://tests/soak.tscn -- 4000 0
## and the matches headless, where they run faster: godot --headless ... res://tests/soak.tscn -- 0 10
## The random inputs: taps on a visible button (as a finger would, through the viewport), taps and drags anywhere,
## the phone's back button, and the app going into the background and back (home button, screen off), checking
## each time that a match in progress is paused and kept and that every save still reads back. The matches: two AI
## teams on each ground in turn, sent to the background partway, each to its final whistle.
## Exits 1 on any error, stall, trap, lost match, unreadable save or unfinished match. It plays with the real
## saves (user://): back them up first if they matter.

const STALL_MS := 5000      # one frame this long is a freeze: Android calls an app this slow to answer "not responding"
# Building a screen or a match takes its one frame longer, more so drawn without a GPU (a match on the virtual screen's
# software renderer: up to ~8 s, compiling its shaders); longer than this is a freeze too.
const LOAD_MS := 30000
const TRAP_STEPS := 400     # inputs on one screen with nothing to press and Back doing nothing
const MATCH_STEPS := 1500   # inputs spent in one played match before Back is pressed to reach its pause menu
const MATCH_FRAMES := 30 * 60 * 30   # an AI match's frames before it counts as never ending (30 game minutes)
const SAVES := ["user://settings.json", "user://season.json", "user://cup.json", "user://career.json"]


class Errors extends Logger:
	var lines: Array[String] = []
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		lines.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func count() -> int:
		_lock.lock()
		var n := lines.size()
		_lock.unlock()
		return n


var errors := Errors.new()
var rng := RandomNumberGenerator.new()
var problems: Array[String] = []
var _last_tick := 0
var worst_ms := 0       # the slowest frame that was not building a new screen
var worst_load_ms := 0  # the slowest that was
var stalls := 0
var _main: Node = null
var _building := false  # the next frame builds a match the soak made itself
var _load_frames := 0


func _ready() -> void:
	OS.add_logger(errors)
	rng.seed = 20261027
	var args := OS.get_cmdline_user_args()
	var inputs := int(args[0]) if args.size() > 0 else 4000
	var matches := int(args[1]) if args.size() > 1 else 10
	var levels := (args[2] if args.size() > 2 else "0,2").split(",")
	var keep_gfx := int(Game.settings.graphics)
	for lv in levels:
		Game.settings.graphics = int(lv)
		Game.settings.auto_gfx = false
		var name: String = ["Low", "Medium", "High"][int(lv)]
		var e0 := errors.count()
		var s0 := stalls
		var p0 := problems.size()
		var t0 := Time.get_ticks_msec()
		if inputs > 0:
			await _monkey(inputs, name)
		var ui_line := "SOAK %s inputs: %d in %.0f s, %d errors, %d stalls, %d problems, worst frame %d ms (%d building a screen)" % [
				name, inputs, (Time.get_ticks_msec() - t0) / 1000.0, errors.count() - e0, stalls - s0,
				problems.size() - p0, worst_ms, worst_load_ms]
		if inputs > 0:
			print(ui_line)
		e0 = errors.count()
		s0 = stalls
		p0 = problems.size()
		worst_ms = 0
		worst_load_ms = 0
		t0 = Time.get_ticks_msec()
		if matches <= 0:
			continue
		var raids := await _matches(matches, name)
		print("SOAK %s matches: %d (%d raids) in %.0f s, %d errors, %d stalls, %d problems, worst frame %d ms (%d building a match)" % [
				name, matches, raids, (Time.get_ticks_msec() - t0) / 1000.0, errors.count() - e0, stalls - s0,
				problems.size() - p0, worst_ms, worst_load_ms])
		worst_ms = 0
		worst_load_ms = 0
	Game.settings.graphics = keep_gfx
	Game.settings.auto_gfx = true
	Game.save_settings()
	for line in errors.lines.slice(0, 40):
		print("ERROR ", line)
	for p in problems.slice(0, 40):
		print("PROBLEM ", p)
	var bad := errors.count() + stalls + problems.size()
	print("soak: %d errors, %d stalls, %d problems" % [errors.count(), stalls, problems.size()])
	get_tree().quit(1 if bad else 0)


## A frame has gone by: was it a freeze?
func _frame() -> void:
	var screen = Game.current
	await get_tree().process_frame
	var now := Time.get_ticks_msec()
	if _last_tick > 0:
		var ms := now - _last_tick
		if Game.current != screen or _building:
			_load_frames = 3   # this frame built it; the next ones draw it the first time (compiling its shaders)
		var load := _load_frames > 0
		_load_frames -= 1
		if load:
			worst_load_ms = maxi(worst_load_ms, ms)
		else:
			worst_ms = maxi(worst_ms, ms)
		if ms > (LOAD_MS if load else STALL_MS):
			stalls += 1
			problems.append("a %d ms frame on %s" % [ms, _screen_name()])
	_last_tick = now
	_building = false


func _frames(n: int) -> void:
	for i in n:
		await _frame()


func _screen_name() -> String:
	var c = Game.current
	if c == null or not is_instance_valid(c) or c.get_script() == null:
		return "(none)"
	return String(c.get_script().resource_path).get_file()


# ---------------------------------------------------------------- random inputs

func _monkey(steps: int, level: String) -> void:
	if _main == null:
		_main = (load("res://main.tscn") as PackedScene).instantiate()
		add_child(_main)
		# The loading screen, then the home screen behind it.
		var waited := 0
		while (Game.loading or _screen_name() != "main_menu.gd") and waited < 30 * 120:
			await _frame()
			waited += 1
		if _screen_name() != "main_menu.gd":
			problems.append("the home screen never came up after the loading screen")
			return
	else:
		Game.goto_menu()
		await _frames(10)
	var screens := {}
	var same := 0
	var in_match := 0
	var last := ""
	for step in steps:
		var name := _screen_name()
		screens[name] = int(screens.get(name, 0)) + 1
		same = same + 1 if name == last else 0
		last = name
		var is_match := name == "match.gd"
		in_match = in_match + 1 if is_match else 0
		var buttons := _buttons()
		if same > TRAP_STEPS and buttons.is_empty() and not is_match:
			problems.append("%s: stuck, nothing to press for %d inputs (%s)" % [level, same, name])
			Game.goto_menu()
			same = 0
		var r := rng.randf()
		if is_match and in_match > MATCH_STEPS:
			# Long enough in this match: Back to its pause menu, from which the taps will leave it.
			_back()
			in_match = MATCH_STEPS / 2
		elif r < 0.55 and not buttons.is_empty():
			var b: Control = buttons[rng.randi() % buttons.size()]
			_tap(b.get_global_rect().get_center())
		elif r < 0.72:
			_tap(Vector2(rng.randf(), rng.randf()) * get_viewport().get_visible_rect().size)
		elif r < 0.80:
			await _drag()
		elif r < 0.92:
			_back()
		else:
			await _background(level)
		await _frames(rng.randi_range(1, 6))
	await _check_saves(level, "after the inputs")
	var seen := screens.keys()
	seen.sort()
	print("SOAK %s screens reached: %d (%s)" % [level, seen.size(), ", ".join(seen)])


## Every button a finger could press now: visible, enabled, on screen, and not one that leaves the game for a web page.
func _buttons() -> Array:
	var out := []
	var vis := get_viewport().get_visible_rect()
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is BaseButton and (n as BaseButton).is_visible_in_tree() and not (n as BaseButton).disabled \
				and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			if n is Button and (n as Button).text == tr("VIEW_ONLINE"):
				continue
			var rect := (n as Control).get_global_rect()
			if rect.size.x > 2 and rect.size.y > 2 and vis.has_point(rect.get_center()):
				out.append(n)
	return out


## A finger's tap, as the phone sends it (Godot makes the mouse click the buttons take from it).
func _tap(at: Vector2) -> void:
	for pressed in [true, false]:
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.position = at
		t.pressed = pressed
		Input.parse_input_event(t)


func _drag() -> void:
	var size := get_viewport().get_visible_rect().size
	var a := Vector2(rng.randf(), rng.randf()) * size
	var b := Vector2(rng.randf(), rng.randf()) * size
	var steps := rng.randi_range(4, 20)
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		if i == 0:
			var t := InputEventScreenTouch.new()
			t.index = 0
			t.position = p
			t.pressed = true
			Input.parse_input_event(t)
		else:
			var d := InputEventScreenDrag.new()
			d.index = 0
			d.position = p
			d.relative = (b - a) / steps
			Input.parse_input_event(d)
		await _frame()
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = b
	up.pressed = false
	Input.parse_input_event(up)


## The phone's back button, as Android sends it; never on the home screen, where it leaves the game.
func _back() -> void:
	if _screen_name() == "main_menu.gd":
		var menu = Game.current
		if not (menu._picker and is_instance_valid(menu._picker) and not menu._picker.is_queued_for_deletion()):
			return
	Game.notification(NOTIFICATION_WM_GO_BACK_REQUEST)


## The home button or the screen going off, and coming back a moment later.
func _background(level: String) -> void:
	var before = Game.current
	var was_match := _screen_name() == "match.gd"
	var clock := float(before.clock) if was_match else 0.0
	Game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	Game.notification(NOTIFICATION_APPLICATION_PAUSED)
	await _frames(rng.randi_range(2, 20))
	Game.notification(NOTIFICATION_APPLICATION_RESUMED)
	Game.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	await _frame()
	if Game.current != before:
		problems.append("%s: the screen changed while the app was in the background (%s)" % [level, _screen_name()])
	elif was_match:
		var m = Game.current
		if String(m.phase) != "fulltime" and not bool(m.paused):
			problems.append("%s: a match came back from the background unpaused" % level)
		if float(m.clock) < clock - 0.5:
			problems.append("%s: the match clock ran on in the background (%.1f to %.1f)" % [level, clock, m.clock])
	await _check_saves(level, "after the background")


func _check_saves(level: String, when: String) -> void:
	for p in SAVES:
		if not FileAccess.file_exists(p):
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		if f == null or not (JSON.parse_string(f.get_as_text()) is Dictionary):
			problems.append("%s: %s no longer reads back %s" % [level, p, when])
		if FileAccess.file_exists(p + ".tmp"):
			problems.append("%s: %s.tmp left behind %s" % [level, p, when])


# ---------------------------------------------------------------- AI v AI

func _matches(n: int, level: String) -> int:
	Game.goto_menu()
	await _frames(5)
	# The home screen's match behind it would play alongside: leave it for a screen with none.
	Game.show_screen("res://ui/settings_screen.gd")
	await _frames(5)
	var pairs := [["MUM", "DEL"], ["PAT", "BLR"], ["IND", "IRN"], ["KOL", "JAI"], ["PUN", "CHE"], ["BAN", "PAK"]]
	var raids := 0
	for i in n:
		var pr: Array = pairs[i % pairs.size()]
		var arena: String = DB.ARENAS[i % DB.ARENAS.size()].id
		var m: Node = load("res://game/match.gd").new()
		m.config = {"home": pr[0], "away": pr[1], "arena": arena, "mode": "quick", "autoplay": true,
				"autoplay_no_report": true, "length": 0, "difficulty": i % 4}
		var done := [false, {}]
		m.finished.connect(func(r):
			done[0] = true
			done[1] = r)
		_building = true
		add_child(m)
		var away_at := rng.randi_range(600, 6000)
		var frames := 0
		while not done[0] and frames < MATCH_FRAMES:
			await _frame()
			frames += 1
			if frames == away_at:
				# Into the background and back: the match waits, paused, then plays on.
				var clock := float(m.clock)
				m.set_paused(true)
				await _frames(30)
				if absf(float(m.clock) - clock) > 0.01:
					problems.append("%s match %d: the clock ran while paused" % [level, i + 1])
				m.set_paused(false)
		if not done[0]:
			problems.append("%s match %d (%s v %s, %s): no final whistle after %d frames, phase %s" % [
					level, i + 1, pr[0], pr[1], arena, frames, m.phase])
		else:
			var res: Dictionary = done[1]
			raids += (res.raid_log as Array).size()
			print("SOAK %s match %d: %s %d - %d %s at %s, %d raids, %d frames" % [level, i + 1, pr[0], res.score[0],
					res.score[1], pr[1], arena, (res.raid_log as Array).size(), frames])
		m.queue_free()
		await _frames(3)
	return raids
