extends Node
## The soak test before a store release (not part of CI's suite: it runs for many minutes). At one graphics level:
##   godot [--headless] --path . --fixed-fps 30 res://tests/soak.tscn -- GFX [inputs] [matches] [minutes] [stall_ms]
## 1. Back on every screen: it goes somewhere (a match pauses and resumes), never to nothing.
## 2. A monkey: thousands of random taps, drags, Back presses and the app being sent to the background and brought
##    back, through the menus and the matches they lead to. The game must always have a screen, a match sent to the
##    background must pause, and no frame may stall.
## 3. AI against AI, every court in turn, with the app paused and resumed and Back pressed during play: each match must
##    reach its end and its result screen.
## 4. A tournament match sent to the background and resumed: the match goes on, and the tournament's save is intact
##    on disk throughout and records the result after.
## Script errors print to the log: the caller greps for them (SCRIPT ERROR). Exits 1 on any failure.

const SCREENS := ["res://ui/quick_setup.gd", "res://ui/settings_screen.gd", "res://ui/howto_screen.gd",
	"res://ui/licences_screen.gd", "res://ui/help_screen.gd", "res://ui/privacy_screen.gd", "res://ui/buttons_screen.gd",
	"res://ui/cup_screen.gd"]
var stall_ms := 1500.0        # a frame longer than this is a stall (headless frames take a few ms; give more when the
                              # frames are drawn by a software renderer)

var gfx := 0
var failures := 0
var checks := 0
var worst_ms := 0.0
var worst_where := ""
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	gfx = int(args[0]) if args.size() > 0 else 0
	var inputs := int(args[1]) if args.size() > 1 else 4000
	var matches := int(args[2]) if args.size() > 2 else 10
	var mins := float(args[3]) if args.size() > 3 else 3.0
	stall_ms = float(args[4]) if args.size() > 4 else stall_ms
	rng.seed = 2026 + gfx
	# Headless, the window is 64 x 64: give it a phone's shape so taps land where the screens are.
	get_tree().root.size = Vector2i(1280, 720)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = gfx
	Game.settings.coach = false
	Game.delete_cup()
	var t0 := Time.get_ticks_msec()
	# Start as the game does (main.gd): the loading screen readies the sounds, bodies and home screen, and draws a
	# match behind it.
	var loading: Node = (load("res://ui/loading_screen.gd") as Script).new()
	add_child(loading)
	loading.run()
	await Game.loaded
	Game.settings.graphics = gfx
	print("loaded in %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	await _back_everywhere()
	await _monkey(inputs)
	await _ai_matches(matches, mins)
	await _cup_pause()
	print("soak gfx %d: %d checks, %d failures; worst frame %.0f ms (%s); %.1f min" % [gfx, checks, failures, worst_ms,
		worst_where, (Time.get_ticks_msec() - t0) / 60000.0])
	get_tree().quit(1 if failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + what)


## Waits n frames, timing each one.
func frames(n: int) -> void:
	for i in n:
		var t := Time.get_ticks_usec()
		await get_tree().process_frame
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		if ms > worst_ms:
			worst_ms = ms
			worst_where = _where()
		if ms > stall_ms:
			check(false, "a frame took %.0f ms on %s" % [ms, _where()])


func _where() -> String:
	if Game.current == null or not is_instance_valid(Game.current):
		return "(no screen)"
	var s: Script = Game.current.get_script()
	var w: String = s.resource_path.get_file() if s else String(Game.current.name)
	if "phase" in Game.current:
		w += " phase %d" % int(Game.current.phase)
	return w


func _screen_ok() -> bool:
	return Game.current != null and is_instance_valid(Game.current) and Game.current.is_inside_tree()


func _is_match() -> bool:
	return _screen_ok() and Game.current.has_method("set_paused")


func _on_menu() -> bool:
	return _screen_ok() and String(Game.current.get_script().resource_path).ends_with("main_menu.gd")


## Back on the home screen quits the game (as a phone's Back should); the monkey does not press it there.
func _back() -> void:
	if _on_menu():
		var picker = Game.current.get("_picker")
		if picker == null or not is_instance_valid(picker):
			return
	Game.go_back()


## The app sent to the background (home button, screen off) and brought back.
func _background_and_back() -> void:
	var was_match := _is_match()
	Game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	Game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await frames(3)
	if was_match and _is_match():
		check(bool(Game.current.paused), "a match sent to the background pauses (%s)" % _where())
	Game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	Game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await frames(2)
	check(_screen_ok(), "the game has a screen after coming back from the background")


func _tap(at: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = at
	e.global_position = at
	e.pressed = true
	Input.parse_input_event(e)
	await frames(rng.randi_range(1, 4))
	var u := e.duplicate() as InputEventMouseButton
	u.pressed = false
	Input.parse_input_event(u)


func _drag(from: Vector2, to: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = from
	e.global_position = from
	e.pressed = true
	Input.parse_input_event(e)
	var steps := rng.randi_range(4, 14)
	for i in steps:
		var m := InputEventMouseMotion.new()
		var p := from.lerp(to, float(i + 1) / steps)
		m.position = p
		m.global_position = p
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		m.relative = (to - from) / steps
		Input.parse_input_event(m)
		await frames(1)
	var u := e.duplicate() as InputEventMouseButton
	u.position = to
	u.global_position = to
	u.pressed = false
	Input.parse_input_event(u)


## The middle of a random control that takes touches (a button, a chip, a card): random input that still reaches
## every screen, where taps anywhere mostly land on nothing.
func _rand_target() -> Vector2:
	var found: Array[Control] = []
	_targets(get_tree().root, found)
	if found.is_empty():
		return _rand_point()
	var c := found[rng.randi() % found.size()]
	var r := c.get_global_rect()
	var p := r.position + Vector2(rng.randf_range(0.2, 0.8) * r.size.x, rng.randf_range(0.2, 0.8) * r.size.y)
	return get_tree().root.get_final_transform() * p


func _targets(n: Node, out: Array[Control]) -> void:
	if n is Control:
		var c := n as Control
		if not c.is_visible_in_tree():
			return
		if (c is BaseButton and not (c as BaseButton).disabled) or (c.mouse_filter == Control.MOUSE_FILTER_STOP and c.gui_input.get_connections().size() > 0):
			if get_viewport().get_visible_rect().intersects(c.get_global_rect()):
				out.append(c)
	for ch in n.get_children():
		_targets(ch, out)


func _rand_point() -> Vector2:
	var r := Vector2(get_tree().root.size)
	return Vector2(rng.randf() * r.x, rng.randf() * r.y)


func _back_everywhere() -> void:
	Game.new_cup("ESC")
	for path in SCREENS:
		var s := Game.show_screen(path)
		await frames(4)
		Game.go_back()
		await frames(4)
		check(_screen_ok() and Game.current != s, "Back leaves %s for another screen (%s)" % [path.get_file(), _where()])
	Game.start_match({"home": "ESC", "away": "LLA", "venue": "village", "rules": "ulama", "user_team": 0, "seed": 3,
		"length": 3.0, "mode": "quick", "difficulty": 1, "ritual": false})
	await frames(30)
	Game.go_back()
	await frames(3)
	check(_is_match() and bool(Game.current.paused), "Back pauses a match")
	Game.go_back()
	await frames(3)
	check(_is_match() and not bool(Game.current.paused), "Back again resumes it")
	Game.delete_cup()
	Game.goto_menu()
	await frames(4)


func _monkey(n: int) -> void:
	var t0 := Time.get_ticks_msec()
	var seen := {}
	var changed_gfx := 0
	for i in n:
		var r := rng.randf()
		if r < 0.36:
			await _tap(_rand_point())
		elif r < 0.72:
			await _tap(_rand_target())
		elif r < 0.84:
			await _drag(_rand_point(), _rand_point())
		elif r < 0.93:
			_back()
		elif r < 0.97:
			await _background_and_back()
		else:
			await frames(rng.randi_range(10, 90))   # let a match play a little
		await frames(rng.randi_range(1, 3))
		if not _screen_ok():
			check(false, "input %d left the game with no screen" % i)
			Game.goto_menu()
			await frames(3)
		seen[_where().get_slice(" ", 0)] = true
		# Taps on Settings may change the level; the test is of one level.
		if int(Game.settings.graphics) != gfx:
			Game.settings.graphics = gfx
			changed_gfx += 1
		# A match left paused would swallow the rest of the inputs: most of the time, play on.
		if _is_match() and bool(Game.current.paused) and rng.randf() < 0.5:
			Game.go_back()
		# Don't spend the whole run in one long match.
		if _is_match() and float(Game.current.phase_t) > 0.0 and i % 600 == 599:
			Game.goto_menu()
			await frames(3)
	check(true, "monkey")
	print("monkey: %d inputs in %.1f min over %s (level put back %d times)" % [n, (Time.get_ticks_msec() - t0) / 60000.0,
		", ".join(PackedStringArray(seen.keys())), changed_gfx])
	Game.goto_menu()
	await frames(4)


func _ai_matches(n: int, mins: float) -> void:
	var venues: Array = DB.VENUE_ORDER
	for i in n:
		var venue: String = venues[i % venues.size()]
		var rules: String = DB.venue(venue).rules
		var cfg := {"home": "ESC", "away": "LLA" if rules == "ulama" else "PIS", "venue": venue, "rules": rules,
			"user_team": -1, "seed": 100 + i, "length": mins, "mode": "watch", "difficulty": i % 3}
		Game.start_match(cfg)
		var m: Node = Game.current
		var f := 0
		var limit := int(mins * 60.0 * 30.0) + 30 * 240
		var pauses := 0
		while is_instance_valid(m) and Game.current == m and f < limit:
			await frames(1)
			f += 1
			if f % 900 == 450:
				await _background_and_back()
				if is_instance_valid(m) and bool(m.paused):
					Game.go_back()        # the player comes back and taps resume
				pauses += 1
			elif f % 900 == 0 and is_instance_valid(m) and m.phase == m.P.LIVE:
				Game.go_back()
				await frames(15)
				if is_instance_valid(m):
					check(bool(m.paused), "Back pauses AI match %d" % i)
					Game.go_back()
		var ended := _screen_ok() and String(Game.current.get_script().resource_path).ends_with("result_screen.gd")
		check(ended, "AI match %d (%s, %s) reaches its result screen (%d frames, %d pauses, now %s)" % [i, venue, rules, f,
			pauses, _where()])
		print("AI match %d: %s %s, %d frames, %d pauses, ended: %s" % [i, venue, rules, f, pauses, ended])
		Game.goto_menu()
		await frames(3)


func _cup_pause() -> void:
	Game.delete_cup()
	var cup = Game.new_cup("ESC")
	var before := FileAccess.get_file_as_string(Game.CUP_PATH)
	check(before.length() > 10, "the tournament is saved when it starts")
	Game.settings.length = 0     # the shortest games
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(5)
	# The cup screen's own Play: a tournament match as the player would start it.
	var play := _find_button(Game.current, tr("PLAY_NEXT"))
	check(play != null, "the tournament screen has its Play button")
	if play == null:
		return
	play.pressed.emit()
	await frames(60)
	check(_is_match(), "Play starts the tournament match (%s)" % _where())
	if not _is_match():
		return
	# Nobody touches the screen: the player's side plays on without them (user_bot's idle mode), to the end.
	var m: Node = Game.current
	await _background_and_back()
	check(bool(m.paused), "the tournament match waits, paused, while the app is away")
	check(FileAccess.get_file_as_string(Game.CUP_PATH) == before, "the tournament's save is untouched while it is paused")
	var clock: float = m.clock
	await frames(60)
	check(is_equal_approx(float(m.clock), clock), "a paused match's clock stands still")
	Game.go_back()
	var limit := 30 * 60 * 20
	var n := 0
	while is_instance_valid(m) and Game.current == m and n < limit:
		await frames(1)
		n += 1
	check(_screen_ok() and String(Game.current.get_script().resource_path).ends_with("result_screen.gd"),
		"the resumed tournament match plays to its result (%s)" % _where())
	var after := FileAccess.get_file_as_string(Game.CUP_PATH)
	check(after.length() > 10 and after != before, "the tournament's save records the result")
	Game.delete_cup()


func _find_button(n: Node, t: String) -> Button:
	if n is Button and (n as Button).text.strip_edges().to_upper() == t.strip_edges().to_upper():
		return n
	for c in n.get_children():
		var b := _find_button(c, t)
		if b:
			return b
	return null
