extends Node
## The soak test before Play (store/PLAY_STORE.md, "Stability"): thousands of random taps, drags and Back presses
## across every screen and into matches, the app sent to the background and back again and again, then Back on every
## screen and a match and a championship through a pause. A frame that takes over STALL_MS, a screen left empty or
## the game leaving its screens counts as a failure; Godot's own script errors are counted from the log by the caller
## (tools/soak.sh). Rendered:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/soak.tscn -- [events] [low|high] [seed]

const STALL_MS := 2000
const SCREENS := ["res://ui/main_menu.gd", "res://ui/match_setup.gd", "res://ui/cup_screen.gd", "res://ui/howto_screen.gd",
	"res://ui/records_screen.gd", "res://ui/settings_screen.gd", "res://ui/licences_screen.gd", "res://ui/help_screen.gd",
	"res://ui/privacy_screen.gd", "res://ui/button_layout.gd"]

var failures := 0
var checks := 0
var rng := RandomNumberGenerator.new()
var _last_ms := 0
var worst_ms := 0
var stalls := 0
var _watch := false


func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", what)


func _process(_d: float) -> void:
	var now := Time.get_ticks_msec()
	if _watch and _last_ms > 0:
		var dt := now - _last_ms
		worst_ms = maxi(worst_ms, dt)
		if dt > STALL_MS:
			stalls += 1
			print("STALL: %d ms on %s" % [dt, _screen_name()])
	_last_ms = now


func _screen_name() -> String:
	var c = Game.current
	if c == null or not is_instance_valid(c):
		return "(none)"
	return String(c.get_script().resource_path).get_file()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var events := int(a[0]) if a.size() > 0 else 3000
	var level := Game.GFX_HIGH if a.size() > 1 and a[1] == "high" else Game.GFX_LOW
	rng.seed = int(a[2]) if a.size() > 2 else 7
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = level
	Game.settings.coach = false
	get_tree().root.size = Vector2i(1280, 720)
	Game._size_theme()
	Game.delete_cup()
	Game.goto_menu()
	await frames(10)
	_watch = true
	await _monkey(events)
	await _back_everywhere()
	await _background_match()
	await _background_cup()
	_watch = false
	print("soak (%s, %d events): %d checks, %d failures, %d stalls, worst frame %d ms" % [
		"high" if level == Game.GFX_HIGH else "low", events, checks, failures, stalls, worst_ms])
	Game.delete_cup()
	get_tree().quit(1 if failures > 0 or stalls > 0 else 0)


## Random input: taps (most), drags, Back, the app to the background and back, and now and then straight to a
## screen. A tap that would quit (Back on the home screen) is not sent; anything else is fair.
func _monkey(n: int) -> void:
	var vp := get_viewport()
	var size := vp.get_visible_rect().size
	var in_match := 0
	for i in n:
		var r := rng.randf()
		var c = Game.current
		var is_match: bool = c != null and is_instance_valid(c) and c.has_method("set_paused")
		if r < 0.62:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			_touch(p, true)
			await frames(1)
			_touch(p, false)
		elif r < 0.78:
			var p0 := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			var p1 := p0 + Vector2(rng.randf_range(-400, 400), rng.randf_range(-400, 400))
			_touch(p0, true)
			for k in 4:
				var e := InputEventScreenDrag.new()
				e.position = p0.lerp(p1, (k + 1) / 4.0)
				e.relative = (p1 - p0) / 4.0
				vp.push_input(e)
				await frames(1)
			_touch(p1, false)
		elif r < 0.86:
			if not _on_home():
				Game.go_back()
		elif r < 0.9:
			Game._notification(NOTIFICATION_APPLICATION_PAUSED)
			await frames(2)
			Game._notification(NOTIFICATION_APPLICATION_RESUMED)
		elif r < 0.93:
			Game.show_screen(SCREENS[rng.randi_range(0, SCREENS.size() - 1)])
		elif r < 0.95 and not is_match:
			# Into a match: a random ground, rule book and side (or the AI on both), as the menus would start it.
			var venues: Array = DB.venue_ids()
			Game.start_match({"home": "MAH", "away": ["ODI", "KAR", "IND", "NEP"][rng.randi_range(0, 3)],
				"venue": venues[rng.randi_range(0, venues.size() - 1)], "format": [KhoRules.CLASSIC, KhoRules.FAST][rng.randi_range(0, 1)],
				"turn_len": 60.0, "user_team": rng.randi_range(-1, 1), "seed": rng.randi(), "mode": "quick", "chase_first": rng.randi_range(0, 1),
				"difficulty": rng.randi_range(0, 3)})
			await frames(30)
		await frames(1 + (2 if is_match else 0))
		if is_match:
			in_match += 1
		c = Game.current
		check(c != null and is_instance_valid(c) and c.get_child_count() > 0, "event %d: a screen with something on it (%s)" % [i, _screen_name()])
		if failures > 20:
			return
	print("  monkey: %d events, %d of them in a match" % [n, in_match])


func _on_home() -> bool:
	return _screen_name() == "main_menu.gd"


func _touch(p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = p
	e.pressed = down
	get_viewport().push_input(e)
	var m := InputEventMouseButton.new()
	m.position = p
	m.global_position = p
	m.button_index = MOUSE_BUTTON_LEFT
	m.pressed = down
	get_viewport().push_input(m)


## Back on every screen goes somewhere (not out of the game), and back again comes home.
func _back_everywhere() -> void:
	for path in SCREENS:
		if path.ends_with("main_menu.gd"):
			continue
		Game.show_screen(path)
		await frames(4)
		var was := _screen_name()
		Game.go_back()
		await frames(4)
		check(_screen_name() != was and Game.current != null, "Back on %s leaves it (now %s)" % [was, _screen_name()])
		for k in 3:
			if _on_home():
				break
			Game.go_back()
			await frames(4)
		check(_on_home(), "and Back again comes home from %s (%s)" % [was, _screen_name()])


## A quick match sent to the background mid-turn: paused, the score and the clock kept, then carried on; Back pauses
## and resumes.
func _background_match() -> void:
	Game.start_match({"home": "MAH", "away": "ODI", "venue": "school", "format": KhoRules.CLASSIC, "turn_len": 120.0,
		"user_team": 0, "seed": 4, "mode": "quick", "chase_first": 0})
	await frames(240)
	var m = Game.current
	var clock: float = m.clock
	var score: Array = m.score.duplicate()
	Game._notification(NOTIFICATION_APPLICATION_PAUSED)
	await frames(60)
	check(m.paused and absf(m.clock - clock) < 0.5 and m.score == score, "a match in the background: paused, nothing lost")
	Game._notification(NOTIFICATION_APPLICATION_RESUMED)
	m.set_paused(false)
	await frames(60)
	check(not m.paused and m.clock < clock, "and on again after (clock %.1f -> %.1f)" % [clock, m.clock])
	Game.go_back()
	await frames(2)
	check(m.paused, "Back in a match pauses it")
	Game.go_back()
	await frames(2)
	check(not m.paused, "and Back again resumes it")


## A championship: the app to the background in a cup match leaves the championship saved on disk as it was.
func _background_cup() -> void:
	Game.delete_cup()
	var cup = Game.new_cup("national", "MAH")
	var before := JSON.stringify(cup.to_dict())
	var p: Array = cup.user_fixture()
	Game.start_match({"home": p[0], "away": p[1], "venue": "maidan", "format": cup.fmt(), "turn_len": 120.0,
		"user_team": 0, "seed": 5, "mode": "cup", "chase_first": 0})
	await frames(120)
	Game._notification(NOTIFICATION_APPLICATION_PAUSED)
	await frames(5)
	check(FileAccess.file_exists(Game.CUP_PATH), "a championship is on disk when the app goes to the background")
	Game.cup = null
	var back = Game.get_cup()
	check(back != null and JSON.stringify(back.to_dict()) == before, "and read back from it unchanged")
