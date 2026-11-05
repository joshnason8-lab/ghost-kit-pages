extends Node
## A soak test before Google Play: thousands of random touches across every screen and into matches, the phone's back
## button on every screen, the app sent to the background and back, then AI v AI matches through to full time, at a
## graphics level. Any crash, script error or stall fails it.
##   godot --headless --path . --fixed-fps 30 res://tests/soak.tscn -- <level 0-2> [touches] [matches] [minutes]
## Exits 1 on a failure; the log is read for SCRIPT ERROR too (as CI does). The HD pack's screen is left at once (its
## button would download 114 MB), and Back on the home screen is not pressed (it closes the game).

var level := Game.GFX_HIGH
var touches := 4000
var matches := 6
var minutes := 8.0
var fails := []
var worst_ms := 0
var stalls := 0
var _last := 0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		level = int(a[0])
	if a.size() > 1:
		touches = int(a[1])
	if a.size() > 2:
		matches = int(a[2])
	if a.size() > 3:
		minutes = float(a[3])
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = level
	Game.settings.coach = false
	get_tree().root.size = Vector2i(1280, 720)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + level
	_last = Time.get_ticks_msec()
	Game.goto_menu()
	await _frames(3)
	await _back_everywhere()
	await _monkey(rng)
	await _pause_keeps_match()
	await _ai_matches()
	print("soak level %d: %d touches, %d matches; slowest frame %d ms, frames over 1 s: %d; failures: %d" % [
		level, touches, matches, worst_ms, stalls, fails.size()])
	for f in fails:
		print("FAIL: ", f)
	get_tree().quit(1 if not fails.is_empty() else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		var dt := now - _last
		_last = now
		worst_ms = maxi(worst_ms, dt)
		# (Building a match or a big screen takes a moment; a stall is a frame far past that.)
		if dt > 1000:
			stalls += 1
			if dt > 5000:
				fails.append("a %d ms stall on %s" % [dt, _where()])


func _where() -> String:
	if Game.current == null or not is_instance_valid(Game.current):
		return "(no screen)"
	var s: Script = Game.current.get_script()
	return s.resource_path.get_file() if s else Game.current.name


func _ok(what: String) -> bool:
	if Game.current == null or not is_instance_valid(Game.current):
		fails.append("no screen after " + what)
		Game.goto_menu()
		return false
	return true


## Every screen's Back (the phone's back button): it leaves the screen (or pauses and resumes a match), never to
## nothing.
func _back_everywhere() -> void:
	var screens := ["res://ui/quick_setup.gd", "res://ui/settings_screen.gd", "res://ui/howto_screen.gd",
		"res://ui/champ_screen.gd", "res://ui/licences_screen.gd", "res://ui/buttons_screen.gd", "res://ui/hd_pack_screen.gd"]
	for path in screens:
		Game.show_screen(path)
		await _frames(3)
		var before := Game.current
		Game.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
		await _frames(3)
		if _ok("Back on " + path.get_file()) and Game.current == before:
			fails.append("Back does nothing on " + path.get_file())
	for pg in ["privacy", "help"]:
		Game.show_screen("res://ui/info_screen.gd", {"page": pg})
		await _frames(3)
		Game.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
		await _frames(3)
		if _ok("Back on " + pg) and _where() != "settings_screen.gd":
			fails.append("Back from the %s page went to %s" % [pg, _where()])
	# In a match: Back pauses, Back again plays on.
	Game.start_match({"home": "KIL", "away": "TIP", "venue": "county", "user_team": 0, "seed": 5, "length": minutes, "mode": "quick"})
	await _frames(40)
	var m := Game.current
	Game.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	var p1 := bool(m.get("paused"))
	Game.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(3)
	if not p1 or bool(m.get("paused")):
		fails.append("Back in a match does not pause and resume it (%s, %s)" % [p1, m.get("paused")])
	m.quit_match()
	await _frames(5)
	Game.goto_menu()
	await _frames(3)


## Random touches: taps (most), drags, Back now and then (not on the home screen), the app sent away and back.
func _monkey(rng: RandomNumberGenerator) -> void:
	var size := Vector2(get_tree().root.size)
	var in_match := 0
	for i in touches:
		var where := _where()
		if where == "hd_pack_screen.gd":
			Game.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
			await _frames(2)
			continue
		var r := rng.randf()
		var at := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		if r < 0.72:
			_touch(at, true)
			await _frames(1)
			_touch(at, false)
		elif r < 0.88:
			var to := at + Vector2(rng.randf_range(-300, 300), rng.randf_range(-300, 300))
			_touch(at, true)
			for k in 4:
				_drag(at.lerp(to, (k + 1) / 4.0))
				await _frames(1)
			_touch(to, false)
		elif r < 0.97:
			if where != "main_menu.gd":
				Game.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
		else:
			Game.notification(NOTIFICATION_APPLICATION_PAUSED)
			if Game.current and is_instance_valid(Game.current):
				Game.current.notification(NOTIFICATION_APPLICATION_PAUSED)
			await _frames(2)
			Game.notification(NOTIFICATION_APPLICATION_RESUMED)
		await _frames(1 + rng.randi() % 3)
		if not _ok("touch %d" % i):
			continue
		# A match the taps started: let it run a while, then leave it (Quit) and carry on.
		if _where() == "match.gd":
			in_match += 1
			if in_match > 900:
				Game.current.quit_match()
				await _frames(5)
				Game.goto_menu()
				await _frames(3)
				in_match = 0
		else:
			in_match = 0
		if i % 500 == 0:
			print("  touch %d on %s" % [i, where])


func _touch(at: Vector2, down: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.position = at
	t.pressed = down
	Input.parse_input_event(t)
	var b := InputEventMouseButton.new()
	b.position = at
	b.global_position = at
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = down
	Input.parse_input_event(b)


func _drag(at: Vector2) -> void:
	var d := InputEventScreenDrag.new()
	d.position = at
	Input.parse_input_event(d)
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.global_position = at
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(mm)


## The app sent to the background mid-match (the home button, the screen off): the match is kept, and Continue on the
## home screen picks it up where it was.
func _pause_keeps_match() -> void:
	Game.delete_champ()
	var c: Championship = Game.new_champ("KIL")
	c.play_byes()
	var f := c.next_fixture()
	Game.save_champ()
	Game.start_match({"home": f.home, "away": f.away, "venue": "county", "user_team": 0 if f.home == "KIL" else 1,
		"seed": 9, "length": minutes, "mode": "champ", "knockout": bool(f.knockout)})
	await _frames(300)
	var m := Game.current
	var clock := float(m.get("clock"))
	Game.notification(NOTIFICATION_APPLICATION_PAUSED)
	m.notification(NOTIFICATION_APPLICATION_PAUSED)
	await _frames(3)
	var snap: Dictionary = Game.suspended()
	if snap.is_empty():
		fails.append("the match was not kept when the app went to the background")
	else:
		# As if the phone had closed the game: back to the home screen, then Continue.
		Game.goto_menu()
		await _frames(3)
		Game.resume_match(snap)
		await _frames(10)
		var m2 := Game.current
		if _where() != "match.gd" or absf(float(m2.get("clock")) - clock) > 5.0:
			fails.append("Continue did not pick the match up where it was (clock %.1f, now %.1f)" % [clock, float(m2.get("clock")) if m2 else -1.0])
		m2.quit_match()
		await _frames(5)
	Game.delete_champ()
	Game.goto_menu()
	await _frames(3)


## AI v AI matches through to full time (as Watch a match), at each venue in turn.
func _ai_matches() -> void:
	var venues := ["parish", "county", "night", "stadium"]
	var ids := DB.counties_ranked()
	for i in matches:
		var cfg := {"home": ids[i % 10], "away": ids[(i * 3 + 4) % 10], "venue": venues[i % venues.size()], "user_team": -1,
			"seed": 300 + i, "length": minutes, "mode": "watch"}
		if cfg.home == cfg.away:
			cfg.away = ids[11]
		Game.start_match(cfg)
		await _frames(2)
		var m := Game.current
		var frames := 0
		var cap := int(minutes * 60.0 * 30.0 * 2.0)
		while is_instance_valid(m) and int(m.get("phase")) != int(m.P.OVER) and frames < cap:
			await _frames(1)
			frames += 1
		if not is_instance_valid(m):
			fails.append("match %d: gone before full time" % i)
			continue
		if int(m.get("phase")) != int(m.P.OVER):
			fails.append("match %d (%s v %s at %s) not over after %d frames" % [i, cfg.home, cfg.away, cfg.venue, frames])
		var s: Array = m.get("score")
		print("  match %d %s v %s at %s: %s v %s, %d frames" % [i, cfg.home, cfg.away, cfg.venue, Rules.fmt(s[0][0], s[0][1]),
			Rules.fmt(s[1][0], s[1][1]), frames])
		await _frames(30)
		Game.goto_menu()
		await _frames(3)
