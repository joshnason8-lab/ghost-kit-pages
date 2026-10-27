extends Node
## The soak test (Play Store readiness): a long run looking for crashes, freezes, stalls and dead ends. The monkey
## needs a window (Godot picks no controls under the pointer when headless); the AI v AI matches also run headless,
## far quicker on a machine without a GPU (High in llvmpipe draws about two frames a second):
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 --resolution 640x360 res://tests/soak.tscn -- low 3000 12 20
##   godot --headless --path . --fixed-fps 30 res://tests/soak.tscn -- high 0 12 20 parts=lifecycle,matches
## XDG_DATA_HOME=/some/dir in front keeps the run's user:// away from the game's own saves on a Linux machine.
## Arguments, in order: graphics (low|medium|high), random inputs, AI v AI matches, quarter length in seconds; then
## any of seed=N, stall=S (seconds of game time a match may go without moving on) and parts=a,b (some of the four
## parts only: back, lifecycle, matches, monkey). The parts:
##   back       every screen (and a match paused, at an interval, at full time, with the team card, moving buttons,
##              rolling changes) and Back on it, as Esc and as the phone's button: it goes somewhere sensible
##   lifecycle  what a phone does on the home button or screen off (paused, focus out) in a cup match: the match
##              pauses and holds, resumes on Resume, and the cup, settings and records on the phone survive
##   matches    AI v AI matches in each venue, with Back and the home button now and then: each finishes with a
##              result and never stalls (its phase, clock, score or ball holder moves on within stall seconds)
##   monkey     random taps, drags, two-finger touches, clicks, Back and the home button, from the home screen
##              through the menus and into matches (quarters cut to the quarter length)
## Any SCRIPT ERROR or ERROR in the log fails the run (the audio driver's complaints without a sound card aside). Back
## on the home screen quits the game on a phone: the monkey never presses it there (it checks it would quit). The
## player's saves (settings, records, cup, league) are copied aside first and put back at the end, and after a run
## that died part way the next run puts them back before it starts. Exits 1 on any failure.

const SAVES := [Game.SETTINGS_PATH, Game.RECORDS_PATH, Game.CUP_PATH, Game.LEAGUE_PATH]
const BACKUP := "user://soak_backup"
const VENUES := ["arena", "outdoor", "hall"]
## The log lines that are not the game's: no sound card under xvfb or in a container.
const HARMLESS := ["ALSA", "drivers/alsa", "drivers/pulseaudio", "audio_server.cpp", "PulseAudio", "pulseaudio", "AudioDriver", "audio driver", "Audio driver", "WASAPI", "CoreAudio"]

var failures := 0
var checks := 0
var gfx := Game.GFX_LOW
var inputs := 3000
var n_matches := 10
var quarter_s := 40.0
var stall_s := 45.0
var parts: PackedStringArray = ["back", "lifecycle", "matches", "monkey"]
var rng := RandomNumberGenerator.new()
var log_errors: ErrorLog
var _keep_settings := {}
var _stats := {"taps": 0, "button_taps": 0, "drags": 0, "two_finger": 0, "clicks": 0, "back_esc": 0, "back_phone": 0,
	"home_back_skipped": 0, "app_pause": 0, "matches_entered": 0, "results": 0, "screens": {}}
# The stall watch: whichever match is Game.current.
var _w_match: Node = null
var _w_sig := ""
var _w_t := 0.0
var _w_stalled := false
var _worst_frame_ms := 0.0
var _last_us := 0


## Every error the engine logs (a script error, an engine ERROR), kept for the end of the run.
class ErrorLog extends Logger:
	var mutex := Mutex.new()
	var lines: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_keep("%s %s:%d %s: %s %s" % [["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"][clampi(error_type, 0, 3)], file, line, function, code, rationale])

	func _log_message(message: String, error: bool) -> void:
		if error and (message.begins_with("ERROR") or message.begins_with("SCRIPT ERROR")):
			_keep(message.strip_edges())

	func _keep(s: String) -> void:
		for h in HARMLESS:
			if s.contains(h):
				return
		mutex.lock()
		lines.append(s)
		mutex.unlock()

	func count() -> int:
		mutex.lock()
		var n := lines.size()
		mutex.unlock()
		return n


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 1
	log_errors = ErrorLog.new()
	OS.add_logger(log_errors)
	_args()
	_backup_saves()
	_keep_settings = Game.settings.duplicate(true)
	Game.settings.graphics = gfx
	Game.settings.auto_gfx = false    # the level asked for, all run (a slow software renderer would drop it)
	Game.settings.coach = false
	Game.save_settings()
	Game.main = self
	print("soak: graphics %s, %d inputs, %d matches, %.0f s quarters, seed %d, stall %.0f s, %s%s" % [["low", "medium", "high"][gfx],
		inputs, n_matches, quarter_s, rng.seed, stall_s, ",".join(parts), " (headless: taps reach no controls)" if DisplayServer.get_name() == "headless" else ""])
	# As the game starts: the loading screen, then the home screen.
	var loading: Node = (load("res://ui/loading_screen.gd") as Script).new()
	add_child(loading)
	loading.run()
	var guard := 0
	while (Game.loading or not _on("main_menu.gd")) and guard < 3000:
		await frames(1)
		guard += 1
	check(_on("main_menu.gd"), "the game starts on the home screen")
	var t0 := Time.get_ticks_msec()
	if "back" in parts:
		print("soak: Back on every screen")
		await _back_tour()
	var t1 := Time.get_ticks_msec()
	if "lifecycle" in parts:
		print("soak: the home button and screen off")
		await _lifecycle()
	var t2 := Time.get_ticks_msec()
	if "matches" in parts:
		print("soak: AI v AI matches")
		await _ai_matches()
	var t3 := Time.get_ticks_msec()
	if "monkey" in parts and inputs > 0:
		print("soak: the monkey")
		await _monkey()
	var t4 := Time.get_ticks_msec()
	Game.test_quarter_s = 0.0
	Game.goto_menu()
	await frames(5)
	_restore_saves()
	Game.settings = _keep_settings
	var errs := log_errors.lines.duplicate()
	check(errs.is_empty(), "no errors in the log (%d)" % errs.size())
	for e in errs.slice(0, 40):
		print("  LOG: ", e)
	print("soak times: back %.0f s, lifecycle %.0f s, matches %.0f s, monkey %.0f s; worst frame %.0f ms" % [(t1 - t0) / 1000.0,
		(t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t4 - t3) / 1000.0, _worst_frame_ms])
	print("soak monkey: %s" % JSON.stringify(_stats))
	print("soak: %d checks, %d failures" % [checks, failures])
	print("SOAK %s" % ("FAILED" if failures > 0 else "PASSED"))
	OS.remove_logger(log_errors)
	get_tree().quit(1 if failures > 0 else 0)


func _args() -> void:
	var pos := 0
	for a in OS.get_cmdline_user_args():
		if a.contains("="):
			var kv := a.split("=")
			match kv[0]:
				"seed":
					rng.seed = int(kv[1])
				"stall":
					stall_s = float(kv[1])
				"parts":
					parts = kv[1].split(",")
			continue
		match pos:
			0:
				gfx = maxi(0, ["low", "medium", "high"].find(a.to_lower()))
			1:
				inputs = int(a)
			2:
				n_matches = int(a)
			3:
				quarter_s = float(a)
		pos += 1


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_us > 0 and Engine.get_process_frames() > 120:
		_worst_frame_ms = maxf(_worst_frame_ms, (now - _last_us) / 1000.0)
	_last_us = now
	_watch(delta)


## The stall watch: a match not paused moves on (its phase, period, clock, score, ball holder or ball) within stall_s
## seconds of its own time; an interval, time-out or injury in your match waits for you, up to its real length.
func _watch(delta: float) -> void:
	var m = Game.current
	if not (m is Match) or not is_instance_valid(m):
		_w_match = null
		return
	if m != _w_match:
		_w_match = m
		_w_sig = ""
		_w_t = 0.0
		_w_stalled = false
	if m.paused or m._ended:
		return
	var tl := "inf" if is_inf(m.time_left) else str(int(m.time_left * 2.0))
	var sig := "%s|%d|%s|%s|%s|%s" % [m.phase, m.q, tl, m.score, (str(m.holder.team) + m.holder.pos) if m.holder else "-", m.ball.state]
	if sig != _w_sig:
		_w_sig = sig
		_w_t = 0.0
		return
	_w_t += minf(delta, 0.05)
	var limit := stall_s
	if not m.demo and m.phase in ["break", "timeout", "injury"]:
		limit = 200.0
	if _w_t > limit and not _w_stalled:
		_w_stalled = true
		check(false, "a match stalls: %s for %.0f s (%s v %s, %s)" % [sig, _w_t, m.team_id(0), m.team_id(1), m.config.get("venue", "")])


func _on(script_file: String) -> bool:
	var c = Game.current
	return c != null and is_instance_valid(c) and c.get_script() != null and String(c.get_script().resource_path).ends_with(script_file)


func _current_name() -> String:
	var c = Game.current
	if c == null or not is_instance_valid(c) or c.get_script() == null:
		return "none"
	return String(c.get_script().resource_path).get_file()


# ---------------------------------------------------------------- the player's saves

func _backup_saves() -> void:
	var manifest := BACKUP + "/saves.json"
	if FileAccess.file_exists(manifest):
		print("soak: an earlier run stopped part way: putting the player's saves back first")
		_restore_saves()
	elif DirAccess.dir_exists_absolute(BACKUP):
		_remove_backup()   # died while copying: the saves themselves were not touched yet
	DirAccess.make_dir_recursive_absolute(BACKUP)
	var had := {}
	for p in SAVES:
		had[p] = FileAccess.file_exists(p)
		if had[p]:
			DirAccess.copy_absolute(p, BACKUP + "/" + String(p).get_file())
	var f := FileAccess.open(manifest, FileAccess.WRITE)
	f.store_string(JSON.stringify(had))
	f.close()


func _restore_saves() -> void:
	var f := FileAccess.open(BACKUP + "/saves.json", FileAccess.READ)
	var had = JSON.parse_string(f.get_as_text()) if f else null
	if not (had is Dictionary):
		return
	for p in SAVES:
		if bool(had.get(p, false)):
			DirAccess.copy_absolute(BACKUP + "/" + String(p).get_file(), p)
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	_remove_backup()
	Game.cup = null
	Game.league = null
	var r = Game._read_json(Game.RECORDS_PATH)
	Game.records = r if r is Dictionary else {}


func _remove_backup() -> void:
	var d := DirAccess.open(BACKUP)
	if d:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(BACKUP)


# ---------------------------------------------------------------- input

func _esc() -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = down
		Input.parse_input_event(e)


## The phone's Back button: the window passes it to every node (Game hears it).
func _phone_back() -> void:
	get_tree().root.propagate_notification(NOTIFICATION_WM_GO_BACK_REQUEST)


## Back, as Esc or as the phone's button, then a few frames for it to happen.
func _back(phone: bool) -> void:
	if phone:
		_phone_back()
		_stats.back_phone += 1
	else:
		_esc()
		_stats.back_esc += 1
	await frames(4)


## What a phone sends on the home button or screen off (and what a desktop or browser window sends on losing focus).
func _app_away(kind: int) -> void:
	match kind:
		0:
			get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		1:
			get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_PAUSED)
			get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		_:
			get_tree().root.propagate_notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)


func _app_back(kind: int) -> void:
	match kind:
		0:
			get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		1:
			get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_RESUMED)
			get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		_:
			get_tree().root.propagate_notification(NOTIFICATION_WM_WINDOW_FOCUS_IN)


func _to_window(p: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * p


func _touch(at: Vector2, down: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = down
	Input.parse_input_event(e)


func _drag_to(at: Vector2, rel: Vector2, index := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	e.relative = rel
	e.velocity = rel * 30.0
	Input.parse_input_event(e)


func _tap(at: Vector2) -> void:
	_touch(at, true)
	await frames(1 + rng.randi() % 3)
	_touch(at, false)


func _click(at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	Input.parse_input_event(mv)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = at
		e.global_position = at
		e.button_index = MOUSE_BUTTON_LEFT
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		e.pressed = down
		Input.parse_input_event(e)
		await frames(1)


func _swipe(from: Vector2, to: Vector2, steps: int, index := 0) -> void:
	_touch(from, true, index)
	var last := from
	for i in steps:
		var p := from.lerp(to, float(i + 1) / steps)
		_drag_to(p, p - last, index)
		last = p
		await frames(1)
	_touch(to, false, index)


func _rand_point() -> Vector2:
	var s := Vector2(DisplayServer.window_get_size())
	if s.x <= 0:
		s = get_viewport().get_visible_rect().size
	return Vector2(rng.randf() * s.x, rng.randf() * s.y)


## A button on the screen to aim a tap at (most taps are, so the monkey gets about), in window pixels.
func _rand_button() -> Variant:
	var view := get_viewport().get_visible_rect()
	var found: Array = []
	var stack: Array = [get_tree().root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is BaseButton and (n as Control).is_visible_in_tree() and not (n as BaseButton).disabled:
			var r := (n as Control).get_global_rect()
			if view.has_point(r.get_center()):
				found.append(r)
	if found.is_empty():
		return null
	var r: Rect2 = found[rng.randi() % found.size()]
	return _to_window(r.get_center() + Vector2(rng.randf_range(-0.3, 0.3) * r.size.x, rng.randf_range(-0.3, 0.3) * r.size.y))


# ---------------------------------------------------------------- Back on every screen

## Opens a screen (or uses the one open), presses Back, and checks where it went.
func _back_from(path: String, args: Dictionary, want: String, phone: bool, open := true) -> void:
	if open:
		Game.show_screen(path, args)
		await frames(4)
	var before := log_errors.count()
	await _back(phone)
	check(_on(want), "Back (%s) on %s %s goes to %s (it went to %s)" % ["phone" if phone else "Esc", path.get_file(), args, want, _current_name()])
	check(log_errors.count() == before, "Back on %s logs no errors" % path.get_file())


func _back_tour() -> void:
	var simple := [["res://ui/quick_setup.gd", {}, "main_menu.gd"], ["res://ui/settings_screen.gd", {}, "main_menu.gd"],
		["res://ui/howto_screen.gd", {"tab": 0}, "main_menu.gd"], ["res://ui/howto_screen.gd", {"tab": 1}, "main_menu.gd"],
		["res://ui/howto_screen.gd", {"tab": 2}, "main_menu.gd"], ["res://ui/howto_screen.gd", {"tab": 3}, "main_menu.gd"],
		["res://ui/records_screen.gd", {}, "main_menu.gd"], ["res://ui/licences_screen.gd", {}, "settings_screen.gd"],
		["res://ui/help_screen.gd", {}, "settings_screen.gd"], ["res://ui/privacy_screen.gd", {}, "settings_screen.gd"]]
	for phone in [false, true]:
		for s in simple:
			await _back_from(s[0], s[1], s[2], phone)
		# The cup and the league: none started, and one under way.
		Game.delete_cup()
		Game.delete_league()
		await _back_from("res://ui/cup_screen.gd", {}, "main_menu.gd", phone)
		await _back_from("res://ui/league_screen.gd", {}, "main_menu.gd", phone)
		Game.new_cup("ENG")
		Game.new_league(String(DB.club_ids()[0]))
		await _back_from("res://ui/cup_screen.gd", {}, "main_menu.gd", phone)
		await _back_from("res://ui/league_screen.gd", {}, "main_menu.gd", phone)
		# The home screen: Back closes the language list; with nothing open it would leave the game on a phone.
		Game.goto_menu()
		await frames(4)
		var menu = Game.current
		menu._open_language()
		await frames(3)
		await _back(phone)
		check(Game.current == menu and (menu._picker == null or not is_instance_valid(menu._picker) or menu._picker.is_queued_for_deletion()),
			"Back on the home screen's language list closes the list")
		check(MainMenu_quits(), "Back on the home screen (nothing open) leaves the game on a phone")
		# Settings > Move buttons: Back finishes moving them (still in Settings), Back again goes home.
		var st := Game.show_screen("res://ui/settings_screen.gd")
		await frames(4)
		st._move_buttons()
		await frames(3)
		await _back(phone)
		check(_on("settings_screen.gd") and Game.current == st, "Back while moving buttons in Settings stays in Settings")
		await _back(phone)
		check(_on("main_menu.gd"), "and Back again goes home")
		# Results: a quick match's goes home, a cup's to the cup, a league's to the league.
		for mode in ["quick", "cup", "league"]:
			var hub: String = {"quick": "main_menu.gd", "cup": "cup_screen.gd", "league": "league_screen.gd"}[mode]
			var res := {"config": {"home": "ENG", "away": "WAL", "mode": mode, "venue": "hall"}, "score": [30, 28], "q_scores": [[8, 7], [7, 7], [8, 7], [7, 7]],
				"stats": {}, "winner": 0, "potm": "", "user_team": 0, "log": [], "calls": {}, "periods": 4}
			await _back_from("res://ui/result_screen.gd", {"result": res}, hub, phone)
		await _match_backs(phone)
	Game.delete_cup()
	Game.delete_league()
	Game.goto_menu()
	await frames(4)


func MainMenu_quits() -> bool:
	var s: Script = load("res://ui/main_menu.gd")
	return s.quits_on_back()


func _start(cfg: Dictionary) -> Match:
	var base := {"home": "ENG", "away": "WAL", "venue": "hall", "user_team": 0, "seed": rng.randi(), "quarter": 15, "mode": "quick",
		"difficulty": 1, "quarter_s": 20.0}
	base.merge(cfg, true)
	Game.start_match(base)
	await frames(20)
	return Game.current as Match


## Back in a match: it pauses, and Back again resumes; Back from what the pause menu opens (moving the buttons, rolling
## changes) goes back to the pause menu; Back over the team card, at an interval and at full time.
func _match_backs(phone: bool) -> void:
	var m := await _start({"rolling": true, "card": true})
	check(m != null and m.hud.card != null, "a cup-style match opens with the team card")
	await _back(phone)
	check(m.paused and _pause_shown(m), "Back over the team card pauses the match")
	await _back(phone)
	check(not m.paused and not _pause_shown(m), "Back again resumes it")
	await _back(phone)
	m.hud._move_buttons()
	await frames(3)
	await _back(phone)
	check(m.paused and _pause_shown(m) and not m.controls.editing and m.hud._layout_panel == null,
		"Back while moving buttons in a match goes back to the pause menu (paused %s, editing %s)" % [m.paused, m.controls.editing])
	m.hud.show_pause(false)
	m.hud._rolling_changes()
	await frames(3)
	await _back(phone)
	check(m.paused and _pause_shown(m) and m.hud._changes_layer == null, "Back from rolling changes goes back to the pause menu (paused %s)" % m.paused)
	await _back(phone)
	check(not m.paused and not _pause_shown(m), "and Back again resumes the match")
	# An interval: Back pauses over it, Back resumes with it still up; Continue goes on.
	m.time_left = 0.05
	m._cp_whistled = true
	var guard := 0
	while not (m.phase == "break" and m._break_shown) and guard < 900:
		await frames(1)
		guard += 1
	check(m.phase == "break" and m.hud._break != null, "the interval screen comes up")
	await _back(phone)
	check(m.paused and _pause_shown(m), "Back at the interval pauses")
	await _back(phone)
	check(not m.paused and m.phase == "break" and m.hud._break != null, "Back again: the interval screen again")
	m.skip_break()
	await frames(4)
	check(m.phase != "break" and m.q == 2, "Continue goes on to the second quarter")
	# Full time: the last quarter run out, Back while the final whistle sounds, then the result.
	m.q = 4
	m.time_left = 0.05
	m._cp_whistled = true
	guard = 0
	while m.phase != "over" and guard < 900:
		await frames(1)
		guard += 1
	await _back(phone)
	check(m.paused, "Back at the final whistle pauses")
	await _back(phone)
	guard = 0
	while not _on("result_screen.gd") and guard < 900:
		await frames(1)
		guard += 1
	check(_on("result_screen.gd"), "the match goes on to its result (%s)" % _current_name())
	await _back(phone)
	check(_on("main_menu.gd"), "Back on the result goes home")
	# Quit from the pause menu: two taps on Quit.
	m = await _start({})
	m.set_paused(true)
	await frames(2)
	var quit := _button(m.hud._pause, tr("QUIT_MATCH"))
	quit.pressed.emit()
	await frames(2)
	quit.pressed.emit()
	await frames(4)
	check(_on("main_menu.gd"), "Quit match (sure) goes home")


func _pause_shown(m: Match) -> bool:
	return m.hud._pause != null and is_instance_valid(m.hud._pause) and not m.hud._pause.is_queued_for_deletion()


func _button(root: Node, text: String) -> Button:
	if root == null:
		return null
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null


# ---------------------------------------------------------------- the home button, screen off

func _lifecycle() -> void:
	Game.delete_cup()
	var cup = Game.new_cup("ENG")
	Game.settings.vibration = not bool(Game.settings.vibration)   # a setting changed (and saved, as Settings does)
	Game.save_settings()
	Game.records.soak_mark = 1
	Game.save_records()
	var cs := Game.show_screen("res://ui/cup_screen.gd")
	await frames(4)
	cs._play(cup, cup.next_user_match())
	await frames(30)
	var m := Game.current as Match
	check(m != null and String(m.config.mode) == "cup", "a cup match starts from the cup screen")
	if m == null:
		return
	if m.hud.card:
		m.hud.card.queue_free()
	for kind in 3:
		# Play running, then the phone goes away.
		guard_unpause(m)
		var g := 0
		while not m._cp_whistled and g < 600:
			await frames(1)
			g += 1
		await frames(20)
		_stats.app_pause += 1
		_app_away(kind)
		await frames(2)
		check(m.paused and _pause_shown(m), "%s pauses the match" % ["focus out", "app paused", "window focus out"][kind])
		var tl := m.time_left
		var sc: Array = m.score.duplicate()
		await frames(60)
		check(m.time_left == tl and m.score == sc, "a paused match holds (clock %.2f -> %.2f)" % [tl, m.time_left])
		_app_back(kind)
		await frames(10)
		check(m.paused and is_instance_valid(m) and Game.current == m, "coming back: the match is there, still paused, for Resume")
		var resume := _button(m.hud._pause, tr("RESUME"))
		check(resume != null, "the pause menu has Resume")
		if resume:
			resume.pressed.emit()
		await frames(30)
		check(not m.paused and m.time_left < tl, "Resume: play goes on (clock %.2f -> %.2f)" % [tl, m.time_left])
	# The saves on the phone survive: what is on disk is what the game holds.
	var on_disk = Game._read_json(Game.CUP_PATH)
	check(on_disk is Dictionary and JSON.stringify(on_disk) == JSON.stringify(JSON.parse_string(JSON.stringify(Game.cup.to_dict()))),
		"the cup in progress is saved")
	var s_disk = Game._read_json(Game.SETTINGS_PATH)
	check(s_disk is Dictionary and bool(s_disk.vibration) == bool(Game.settings.vibration), "settings are saved")
	var r_disk = Game._read_json(Game.RECORDS_PATH)
	check(r_disk is Dictionary and int(r_disk.get("soak_mark", 0)) == 1, "records are saved")
	# The match played to its end: the cup moves on, and that is saved too.
	var played := 0
	for f in Game.cup.fixtures:
		played += 1 if f.played else 0
	m.q = 4
	m.time_left = 0.05
	var g2 := 0
	while not _on("result_screen.gd") and g2 < 3000:
		if m and is_instance_valid(m) and m.phase == "break":
			m.skip_break()
		await frames(1)
		g2 += 1
	check(_on("result_screen.gd"), "the cup match ends with its result")
	_stats.results += 1
	var back = Cup.from_dict(Game._read_json(Game.CUP_PATH))
	var played_now := 0
	for f in back.fixtures:
		played_now += 1 if f.played else 0
	check(played_now > played, "the cup's saved results move on (%d -> %d played)" % [played, played_now])
	Game.records.erase("soak_mark")
	Game.save_records()
	Game.delete_cup()
	Game.goto_menu()
	await frames(4)


func guard_unpause(m: Match) -> void:
	if m.paused:
		m.set_paused(false)


# ---------------------------------------------------------------- AI v AI matches

func _ai_matches() -> void:
	var ids: Array = DB.team_ids()
	for i in n_matches:
		var venue: String = VENUES[i % VENUES.size()]
		var home: String = ids[rng.randi() % ids.size()]
		var away: String = ids[rng.randi() % ids.size()]
		while away == home:
			away = ids[rng.randi() % ids.size()]
		var cfg := {"home": home, "away": away, "venue": venue, "user_team": -1, "demo": true, "seed": rng.randi(),
			"quarter_s": quarter_s, "quarter": 15, "mode": "quick", "need_winner": i % 4 == 3}
		var t0 := Time.get_ticks_msec()
		Game.start_match(cfg)
		var m := Game.current as Match
		var done := [null]
		m.finished.connect(func(r): done[0] = r)
		var game_t := 0.0
		var limit := quarter_s * 6.0 + 240.0
		var next_poke := rng.randf_range(10.0, 40.0)
		while done[0] == null and game_t < limit and not _w_stalled and is_instance_valid(m):
			await frames(1)
			if not m.paused:
				game_t += minf(get_process_delta_time(), 0.05)
			if game_t > next_poke:
				next_poke = game_t + rng.randf_range(15.0, 50.0)
				await _poke(m)
		var res = done[0]
		check(res is Dictionary, "match %d (%s v %s, %s) finishes (%.0f s of game time)" % [i + 1, home, away, venue, game_t])
		if res is Dictionary:
			var sc: Array = res.score
			check(int(res.periods) >= 4 and (res.q_scores as Array).size() == int(res.periods) or int(res.periods) == 7,
				"match %d: a score for each period (%d periods)" % [i + 1, int(res.periods)])
			check(int(sc[0]) + int(sc[1]) > 0, "match %d: goals scored (%s)" % [i + 1, sc])
			if bool(cfg.need_winner):
				check(int(res.winner) >= 0, "match %d: a knockout has a winner (%s)" % [i + 1, sc])
			print("soak match %d: %s %d-%d %s at %s, %d periods, %.0f s real" % [i + 1, home, sc[0], sc[1], away, venue, int(res.periods),
				(Time.get_ticks_msec() - t0) / 1000.0])
		_w_stalled = false
	Game.goto_menu()
	await frames(4)


## Now and then in an AI match: Back twice (paused, resumed), or the home button and back again (then Resume).
func _poke(m: Match) -> void:
	if rng.randf() < 0.5:
		await _back(rng.randf() < 0.5)
		check(m.paused, "Back pauses an AI match")
		await frames(10)
		await _back(rng.randf() < 0.5)
		check(not m.paused, "Back resumes it")
	else:
		var kind := rng.randi() % 3
		_app_away(kind)
		_stats.app_pause += 1
		await frames(10)
		check(m.paused, "the home button pauses an AI match")
		_app_back(kind)
		await frames(5)
		var r := _button(m.hud._pause if m.hud else null, tr("RESUME"))
		if r:
			r.pressed.emit()
		await frames(2)
		check(not m.paused, "Resume resumes it")


# ---------------------------------------------------------------- the monkey

func _monkey() -> void:
	Game.test_quarter_s = quarter_s
	Game.goto_menu()
	await frames(10)
	var screen_steps := 0
	var last_screen := ""
	for i in inputs:
		var name := _current_name()
		_stats.screens[name] = int(_stats.screens.get(name, 0)) + 1
		if name != last_screen:
			if name == "match.gd":
				_stats.matches_entered += 1
			elif name == "result_screen.gd":
				_stats.results += 1
			last_screen = name
			screen_steps = 0
		screen_steps += 1
		var r := rng.randf()
		if r < 0.5:
			var at = _rand_button() if rng.randf() < 0.75 else null
			if at == null:
				at = _rand_point()
			else:
				_stats.button_taps += 1
			_stats.taps += 1
			await _tap(at)
		elif r < 0.7:
			_stats.drags += 1
			var from := _rand_point()
			await _swipe(from, from + Vector2(rng.randf_range(-400, 400), rng.randf_range(-300, 300)), 2 + rng.randi() % 14)
		elif r < 0.78:
			# Two thumbs: the stick on the left and a button on the right, as in a match.
			_stats.two_finger += 1
			var s := Vector2(DisplayServer.window_get_size())
			var a := Vector2(rng.randf_range(0.05, 0.4) * s.x, rng.randf_range(0.3, 0.95) * s.y)
			var b := Vector2(rng.randf_range(0.6, 0.98) * s.x, rng.randf_range(0.4, 0.98) * s.y)
			_touch(a, true, 0)
			await frames(1)
			_touch(b, true, 1)
			for k in 1 + rng.randi() % 10:
				var p := a + Vector2(rng.randf_range(-120, 120), rng.randf_range(-120, 120))
				_drag_to(p, p - a, 0)
				await frames(1)
			_touch(b, false, 1)
			_touch(a, false, 0)
		elif r < 0.88:
			_stats.clicks += 1
			await _click(_rand_point())
		elif r < 0.97:
			await _monkey_back()
		else:
			var kind := rng.randi() % 3
			_stats.app_pause += 1
			_app_away(kind)
			await frames(1 + rng.randi() % 20)
			_app_back(kind)
		await frames(1 + rng.randi() % 4)
		# A match the monkey cannot get out of in good time (a break waiting on Continue it never finds): it plays on.
		var m = Game.current
		if m is Match and screen_steps > 400 and rng.randf() < 0.05:
			if m.paused:
				m.set_paused(false)
			if m.phase == "break":
				m.skip_break()
		if not is_instance_valid(Game.current):
			check(false, "no screen after input %d" % i)
			Game.goto_menu()
			await frames(4)
		if i % 500 == 499:
			print("soak monkey: %d inputs, on %s, %d errors so far" % [i + 1, _current_name(), log_errors.count()])


## Back from the monkey: never on the home screen with nothing open (that leaves the game on a phone).
func _monkey_back() -> void:
	await frames(2)
	var c = Game.current
	if _on("main_menu.gd") and not (c._picker and is_instance_valid(c._picker)):
		_stats.home_back_skipped += 1
		return
	await _back(rng.randf() < 0.5)
