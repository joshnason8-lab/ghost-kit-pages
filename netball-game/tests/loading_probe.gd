extends Node
## The loading overlay (WsgLoading, Game.start_match_loading) on each Start button, as the game runs: the loading
## screen and the home screen first (its attract match on Medium and High), then the screen, a real tap on its button
## (in a window), the overlay, the match. WsgLoading prints each load's WSG_LOADING line (its steps' main-thread ms, the
## longest slice and its step, the longest frame). Windowed, so frames are really drawn:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/loading_probe.tscn -- <level 0|1|2> [entries] [shots_dir]
## entries: comma-separated quick, watch, cup, league, rematch (default all, in that order, one session). With a
## shots_dir, frames of the overlay are saved there (the tap's frame, mid-load); not for timing (saving takes time).

var shots := ""
var _shot_n := 0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var level := int(a[0]) if a.size() > 0 else Game.GFX_LOW
	var entries := (a[1] if a.size() > 1 else "quick,watch,cup,league,rematch").split(",")
	shots = a[2] if a.size() > 2 else ""
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = level
	Game.settings.auto_gfx = false
	Game.settings.coach = false
	Game.settings.language = "en"
	Game.save_settings()
	WsgFoundation.tier = level
	var loading: Node = (load("res://ui/loading_screen.gd") as Script).new()
	add_child(loading)
	loading.run()
	var guard := 0
	while (Game.loading or Game.current == null) and guard < 3000:
		await get_tree().process_frame
		guard += 1
	await _frames(30)
	var fails := 0
	for e in entries:
		if not await _entry(e, level):
			fails += 1
	print("loading_probe: level %d, %d entries, %d failed" % [level, entries.size(), fails])
	get_tree().quit(1 if fails > 0 else 0)


func _entry(e: String, level: int) -> bool:
	var screen: Node
	var key := "PLAY"
	match e:
		"quick":
			screen = Game.show_screen("res://ui/quick_setup.gd")
		"watch":
			screen = Game.show_screen("res://ui/watch_setup.gd")
			key = "WATCH_GO"
		"cup":
			Game.delete_cup()
			Game.new_cup("ENG")
			screen = Game.show_screen("res://ui/cup_screen.gd")
		"league":
			Game.delete_league()
			Game.new_league(String(DB.club_ids()[0]))
			screen = Game.show_screen("res://ui/league_screen.gd")
		"rematch":
			var m = Game.current
			if not (m is Match):
				Game.start_match({"home": "ENG", "away": "JAM", "venue": "arena", "quarter": 5, "mode": "quick", "user_team": 0, "seed": 3})
				await _frames(5)
				m = Game.current
			# The result of a Quick Match (Rematch is on a Quick Match's result; a cup's or season's has Continue).
			var r: Dictionary = m.result_dict()
			r.config = {"home": "ENG", "away": "JAM", "venue": "arena", "quarter": 5, "mode": "quick", "user_team": 0, "card": true}
			screen = Game.show_screen("res://ui/result_screen.gd", {"result": r})
			key = "REMATCH"
	await _frames(8)
	var btn: Button = null
	for b in screen.find_children("*", "Button", true, false):
		if (b as Button).text == tr(key) and (b as Button).is_visible_in_tree():
			btn = b
			break
	if btn == null:
		print("loading_probe: %s: no %s button" % [e, key])
		return false
	var at := btn.get_global_rect().get_center()
	_push_move(at)
	_push_mouse(at, true)
	await get_tree().process_frame
	var f0 := Engine.get_process_frames()
	_push_mouse(at, false)       # the button presses on release: the overlay is added here, in this frame
	var ld := WsgLoading.current()
	var up_now := ld != null and btn.disabled
	print("loading_probe: %s: overlay up in the tap's frame %s, button off %s" % [e, ld != null, btn.disabled])
	if shots != "":
		await RenderingServer.frame_post_draw
		_shot("%s_l%d_tap" % [e, level])
	var bar := []
	var mid_shot := false
	var warm_shot := false
	var guard := 0
	var t_last := Time.get_ticks_usec()
	var slow := []
	while WsgLoading.busy() and guard < 2000:
		await get_tree().process_frame
		guard += 1
		var now := Time.get_ticks_usec()
		var cur := WsgLoading.current()
		if (now - t_last) / 1000.0 > 50.0:
			slow.append("%.0f ms after '%s'" % [(now - t_last) / 1000.0, cur._label if cur else "-"])
		t_last = now
		if cur:
			bar.append(cur.shown())
			if shots != "" and not mid_shot and cur.shown() >= 0.45:
				mid_shot = true
				await RenderingServer.frame_post_draw
				_shot("%s_l%d_mid" % [e, level])
			elif shots != "" and not warm_shot and cur._label == "Warming up" and cur.shown() >= 0.8:
				warm_shot = true          # the warm-up: the match swapped in behind the opaque overlay
				await RenderingServer.frame_post_draw
				_shot("%s_l%d_warm" % [e, level])
	var mono := true
	for i in range(1, bar.size()):
		if bar[i] < bar[i - 1] - 1e-6:
			mono = false
	print("loading_probe: %s: frames over 50 ms: %s" % [e, ", ".join(slow)])
	var frames_to := Engine.get_process_frames() - f0
	var m = Game.current
	# Kicked off: the team card, then the centre pass's whistle (a few seconds), then play.
	var waited := 0
	while m is Match and is_instance_valid(m) and m.phase == "setup" and waited < 900:
		await get_tree().process_frame
		waited += 1
	var playing: bool = m is Match and m.process_mode == Node.PROCESS_MODE_INHERIT and not m.held and m.phase != "setup"
	print("loading_probe: %s: %d frames to the match, bar %d samples non-decreasing %s, last %.3f; match plays %s (phase %s, %d frames after)" % [e,
		frames_to, bar.size(), mono, bar[-1] if not bar.is_empty() else -1.0, playing, m.phase if m is Match else "-", waited])
	return up_now and mono and playing


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(shots.path_join("%02d_%s_%dx%d.png" % [_shot_n, name, img.get_width(), img.get_height()]))
	_shot_n += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _push_mouse(at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = at
	ev.global_position = at
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	ev.pressed = down
	get_viewport().push_input(ev, true)    # (canvas coordinates, whatever the window's size)


func _push_move(at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	get_viewport().push_input(ev, true)    # (canvas coordinates, whatever the window's size)
