extends Node
## How long each way into a match keeps the player waiting after the tap, on a graphics level (default Low), the game
## booted as main.tscn boots it (the loading screen, then the home screen with its match behind it):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/load_probe.tscn [-- level [WxH [scenarios]]]
## For each: the tap's own frame (everything the tap does before the frame can end), whether the loading overlay
## (WsgLoading, Game.play_match) was up in that frame, the tap to the first frame drawn after it, the tap to the match
## started (the overlay gone), the tap to settled (three frames in a row under SETTLED_MS), the longest frame in
## between (the main thread's longest stall), and the frames the overlay's bar moved in of those it was up for; all in
## ms of this machine. Then each load's WSG_LOADING line.
## scenarios: comma-separated indices into _scenarios() (default all, one after another in one session); a fresh
## process for each gives each its cold, first-of-the-session time. With LOAD_SHOTS=<dir> in the environment, the screen
## is saved there on the first frame after each tap and at a third and two thirds of the way.

const SETTLED_MS := 70.0
const SETTLE_MAX := 8.0

var _draws: Array[int] = []   # each frame's end (usec)


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	Game.settings.graphics = int(a[0]) if a.size() > 0 else Game.GFX_LOW
	if a.size() > 1:
		var wh := a[1].split("x")
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	Engine.max_fps = 0
	Game.main = self
	RenderingServer.frame_post_draw.connect(func(): _draws.append(Time.get_ticks_usec()))
	var loading: Node = (load("res://ui/loading_screen.gd") as Script).new()
	add_child(loading)
	var b0 := Time.get_ticks_usec()
	loading.run()
	await Game.loaded
	print("boot: loading screen to the home screen running smoothly %d ms %s" % [(Time.get_ticks_usec() - b0) / 1000, loading.times])
	await _frames(30)
	var all := _scenarios()
	var pick: Array = range(all.size())
	if a.size() > 2:
		pick = Array(a[2].split(",")).map(func(x): return int(x))
	var rows := []
	for i in pick:
		var sc: Array = all[i]
		rows.append(await _tap(sc[0], sc[1], sc[2] if sc.size() > 2 else Callable()))
	print("\n%-40s %6s %7s %7s %7s %7s %7s %9s" % ["", "tap", "overlay", "1st frm", "started", "settled", "longest", "bar moved"])
	for r in rows:
		print("%-40s %6d %7s %7d %7d %7d %7d %9s" % r.slice(0, 8))
	for r in rows:
		if not (r[8] as Dictionary).is_empty():
			print("%s: WSG_LOADING %s" % [r[0], JSON.stringify(r[8])])
	get_tree().quit()


## The ways in: [what, the tap, the screen it is on (shown first)]. (By index on the command line: 0 alone is a
## session's first match at the National Arena.)
func _scenarios() -> Array:
	var out := [
		["quick match (national)", func(): Game.current.call("_play"), func(): Game.show_screen("res://ui/quick_setup.gd")],
		["rematch (national)", func(): Game.play_match({"home": "THA", "away": "MAS", "venue": "national", "event": "regu",
			"sets": 1, "points": 15, "difficulty": 1, "mode": "quick", "user_team": 0, "seed": 7})],
		["Watch AI (national)", func(): Game.current.call("_play"), func(): Game.show_screen("res://ui/quick_setup.gd", {"watch": true})],
		["season: start (new season, its hub)", func():
			Game.new_season("MY", "PRK")
			Game.show_screen("res://ui/season_hub.gd")],
		["season: Play", func(): _press(Game.current, tr("PLAY")), func():
			if not Game.current or not Game.current.get_script() or not str(Game.current.get_script().resource_path).ends_with("season_hub.gd"):
				Game.new_season("MY", "PRK")
				Game.show_screen("res://ui/season_hub.gd")],
		["international: start (new cup, its screen)", func():
			Game.new_cup("world", "THA")
			Game.show_screen("res://ui/cup_screen.gd")],
		["international: Play (the mall)", func(): _press(Game.current, tr("PLAY")), func():
			if not Game.current or not Game.current.get_script() or not str(Game.current.get_script().resource_path).ends_with("cup_screen.gd"):
				Game.new_cup("world", "THA")
				Game.show_screen("res://ui/cup_screen.gd")],
	]
	for v in DB.VENUES:
		out.append(["quick match at %s" % v[0], func(): Game.current.call("_play"), func():
			Game.show_screen("res://ui/quick_setup.gd").set("_venue", v[0])])
	out.append(["quit to the home screen", func(): Game.goto_menu()])
	return out


## The tap: what it does (in this frame, as a button's pressed does), then the frames until it has settled. prep: the
## screen the tap is on, shown first.
func _tap(what: String, act: Callable, prep := Callable()) -> Array:
	if prep.is_valid():
		await _frames(5)
		prep.call()
	await _frames(20)
	_draws.clear()
	Game.last_load = {}
	var t0 := Time.get_ticks_usec()
	act.call()
	var built := Time.get_ticks_usec()
	var ld := WsgLoading.current()
	var overlay := "yes" if ld != null and ld.is_inside_tree() and ld.parts().root.visible else "no"
	var smooth := 0
	var last := t0
	var longest := 0
	var first := -1
	var started := -1
	var settled := -1
	var bar := -1.0
	var up := 0
	var moved := 0
	while settled < 0 and Time.get_ticks_usec() - t0 < SETTLE_MAX * 1e6:
		await get_tree().process_frame
		if WsgLoading.busy():
			up += 1
			var b := WsgLoading.current().shown()
			var shots := OS.get_environment("LOAD_SHOTS")
			if shots != "" and (up == 1 or (bar < 0.33 and b >= 0.33) or (bar < 0.67 and b >= 0.67)):
				DirAccess.make_dir_recursive_absolute(shots)
				get_viewport().get_texture().get_image().save_jpg("%s/%s_%02d_%03d.jpg" % [shots, what.get_slice(" (", 0).replace(" ", "_").replace(":", ""), up, roundi(b * 100)])
			if b < bar - 1e-6:
				overlay = "BAR BACK"
			if b > bar + 1e-6:
				moved += 1
			bar = b
		elif started < 0:
			started = Time.get_ticks_usec()
		if _draws.is_empty():
			continue
		var now: int = _draws[_draws.size() - 1]
		if first < 0:
			first = now
		var ms := float(now - last) / 1000.0
		longest = maxi(longest, int(ms))
		last = now
		smooth = smooth + 1 if ms <= SETTLED_MS and started > 0 else 0
		if smooth >= 3:
			settled = now
		_draws.clear()
	await _frames(30)
	return [what, (built - t0) / 1000, overlay, (first - t0) / 1000, (started - t0) / 1000 if started > 0 else -1,
		(settled - t0) / 1000 if settled > 0 else -1, longest, "%d/%d" % [moved, up], Game.last_load.duplicate()]


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The button with this text, pressed (its handler runs now).
func _press(root: Node, text: String) -> void:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree():
			(b as Button).pressed.emit()
			return
	push_error("load_probe: no button %s" % text)
