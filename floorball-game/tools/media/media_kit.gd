extends Node
## The media kit's pictures and footage, all from the game itself on High at 1920 x 1080 (tools/media/make_media_kit.sh
## runs it and cuts the trailer):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --fixed-fps 30 \
##     res://tools/media/media_kit.tscn -- <out dir> <menus|clips> [clip names]
## menus: every screen, clean, as PNG (<out>/menus/). clips: for each clip below, AI v AI with the scoreboard (no
## touch buttons), its moment found first by playing the match unrendered, then played again from the same seed and
## recorded around it: every frame as JPEG (<out>/frames/<clip>/), two stills as PNG (<out>/screenshots/). The game
## steps a fixed 1/30 s a frame (--fixed-fps 30), so the second playing is the first one's.

## event: "start" (from the first face-off), "goal" (the n-th), "save" (the n-th), "penalty" (the n-th).
## before, after: seconds recorded around it. stills: seconds from the moment, a PNG each.
const CLIPS := [
	{"name": "arena_goal", "venue": "arena", "home": "SWE", "away": "FIN", "seed": 21, "cam": 0, "event": "goal", "n": 1,
		"before": 6.0, "after": 4.0, "stills": [-1.2, 1.5]},
	{"name": "hall_goal_women", "venue": "hall", "home": "SUI", "away": "CZE", "women": true, "seed": 9, "cam": 0,
		"event": "goal", "n": 1, "before": 5.0, "after": 3.5, "stills": [-1.0, 2.0]},
	{"name": "school_goal_end", "venue": "school", "home": "LAT", "away": "SVK", "seed": 8, "cam": 2, "event": "goal",
		"n": 1, "before": 5.0, "after": 3.0, "stills": [-0.8, 1.2]},
	{"name": "arena_save_high", "venue": "arena", "home": "CZE", "away": "SWE", "seed": 33, "cam": 1, "event": "save",
		"n": 2, "before": 4.0, "after": 2.0, "stills": [-0.4, 1.0]},
	{"name": "hall_penalty", "venue": "hall", "home": "FIN", "away": "NOR", "seed": 14, "cam": 0, "event": "penalty",
		"n": 1, "before": 3.0, "after": 3.0, "stills": [0.6]},
	{"name": "arena_faceoff", "venue": "arena", "home": "SWE", "away": "SUI", "women": true, "seed": 5, "cam": 0,
		"event": "start", "n": 1, "before": 0.0, "after": 5.0, "stills": [1.5]},
]

const FPS := 30
const SEARCH_S := 1500.0   # the most game time searched for a moment (25 minutes)

var out := ""


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "/tmp/media"
	var part := a[1] if a.size() > 1 else "clips"
	var only := a.slice(2)
	get_tree().root.size = Vector2i(1920, 1080)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.auto_gfx = false
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	Game._size_theme()
	for d in ["menus", "screenshots", "frames"]:
		DirAccess.make_dir_recursive_absolute(out.path_join(d))
	await frames(4)
	if part == "menus":
		await _menus()
	else:
		# The first match a run plays goes its own way (something is set up once, in it); every one after it, from the
		# same seed, plays the same. So one is played first, unseen.
		RenderingServer.render_loop_enabled = false
		var w := _start(CLIPS[0])
		await frames(1)
		_dress(w, CLIPS[0])
		for i in 6000:
			await frames(1)
		Game.goto_menu()
		await frames(3)
		for c in CLIPS:
			if only.is_empty() or c.name in only:
				await _clip(c)
	get_tree().quit()


# ---------------------------------------------------------------- the footage

func _start(c: Dictionary) -> Node:
	seed(1000 + int(c.seed))
	Game.start_match({"home": c.home, "away": c.away, "venue": c.venue, "user_team": -1, "demo": true, "mode": "quick",
		"seed": c.seed, "period": 8.0, "women": c.get("women", false)})
	var m: Node = Game.current
	return m


## After the match is up: the scoreboard and banners as a match you play has them, without the touch buttons.
func _dress(m: Node, c: Dictionary) -> void:
	var hud: Node = load("res://game/hud.gd").new()
	m.add_child(hud)
	hud.setup(m)
	hud.touch.visible = false
	for ch in hud.root.get_children():
		if ch is HBoxContainer:   # the camera and pause buttons, top right
			ch.visible = false
	m.hud = hud
	m.cam.mode = int(c.cam)


## The interval's card waits for a tap in a match you play; here nobody taps, and the match goes on by itself.
func _tidy(m: Node) -> void:
	var card = m.hud.get("_interval") if m.hud else null
	if card and is_instance_valid(card):
		card.visible = false


## The frame (from the match's first) the clip's moment happens on, or -1.
func _moment(m: Node, c: Dictionary, f: int, st: Dictionary) -> bool:
	var hit := false
	match String(c.event):
		"start":
			hit = m.phase == "live" and st.get("prev", "") != "live"
		"goal":
			hit = m.phase == "goal" and st.get("prev", "") != "goal"
		"save":
			var s := 0
			for id in m.stats:
				s += int(m.stats[id].saves)
			hit = s > int(st.get("saves", 0))
			st.saves = s
		"penalty":
			var n := 0
			for e in m.rules.log:
				if String(e.kind) == "penalty":
					n += 1
			hit = n > int(st.get("pens", 0))
			st.pens = n
	st.prev = m.phase
	if hit:
		st.count = int(st.get("count", 0)) + 1
		return int(st.count) == int(c.get("n", 1))
	return false


func _clip(c: Dictionary) -> void:
	# 1. Played unrendered: when is the moment?
	RenderingServer.render_loop_enabled = false
	var m := _start(c)
	await frames(1)
	_dress(m, c)
	var st := {}
	var at := -1
	var f := 0
	while f < int(SEARCH_S * FPS) and is_instance_valid(m) and m.phase != "over":
		await frames(1)
		f += 1
		_tidy(m)
		if _moment(m, c, f, st):
			at = f
			break
	if at < 0:
		print("media: %s: no %s found" % [c.name, c.event])
		RenderingServer.render_loop_enabled = true
		return
	# 2. Again from the same seed, rendered around it.
	var first := maxi(1, at - int(float(c.before) * FPS))
	var last := at + int(float(c.after) * FPS)
	m = _start(c)
	await frames(1)
	_dress(m, c)
	st = {}
	var again := -1
	var dir := out.path_join("frames").path_join(c.name)
	DirAccess.make_dir_recursive_absolute(dir)
	var stills := {}
	for s in c.get("stills", []):
		stills[at + int(float(s) * FPS)] = true
	var k := 0
	f = 0
	while f < last:
		if f == first - 20:
			RenderingServer.render_loop_enabled = true   # a few frames to settle the camera's history
		await frames(1)
		f += 1
		_tidy(m)
		if _moment(m, c, f, st) and again < 0:
			again = f
		if f >= first:
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			if img.get_width() != 1920:
				img.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
			img.save_jpg(dir.path_join("%04d.jpg" % k), 0.95)
			k += 1
			if stills.has(f):
				img.save_png(out.path_join("screenshots").path_join("%s_%d.png" % [c.name, f - at]))
	var meta := FileAccess.open(dir.path_join("meta.json"), FileAccess.WRITE)
	meta.store_string(JSON.stringify({"event": at - first, "frames": k, "stills": c.get("stills", [])}))
	meta.close()
	print("media: %s: %s at frame %d (again at %d%s), %d frames from %d" % [c.name, c.event, at, again,
		"" if again == at else ": NOT THE SAME", k, first])
	Game.goto_menu()
	await frames(3)


# ---------------------------------------------------------------- the screens

func _menus() -> void:
	var n := [0]
	var menu := Game.show_screen("res://ui/main_menu.gd")
	await frames(240)
	await _shot(n, "home")
	menu._open_language()
	await frames(12)
	await _shot(n, "language")
	menu._picker.close()
	await frames(4)
	Game.show_screen("res://ui/quick_setup.gd")
	await frames(12)
	await _shot(n, "quick_match_setup")
	Game.delete_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(12)
	await _shot(n, "world_finals_pick")
	var cup = Game.new_cup("FIN", false)
	cup.sim_next()   # one round: the groups under way, your team still in it
	Game.save_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(12)
	await _shot(n, "world_finals_groups")
	Game.delete_cup()
	Game.delete_season()
	Game.show_screen("res://ui/season_screen.gd")
	await frames(12)
	await _shot(n, "season_pick")
	var season = Game.new_season("WLV", false)
	for i in 4:
		season.sim_next()
	Game.save_season()
	Game.show_screen("res://ui/season_screen.gd")
	await frames(12)
	await _shot(n, "season_table")
	Game.delete_season()
	var sets := Game.show_screen("res://ui/settings_screen.gd")
	await frames(12)
	await _shot(n, "settings")
	var sc := _scroller(sets)
	if sc:
		var page := 1
		while true:
			var before := sc.scroll_vertical
			sc.scroll_vertical += int(sc.size.y * 0.85)
			await frames(6)
			if sc.scroll_vertical == before:
				break
			page += 1
			await _shot(n, "settings_%d" % page)
	for tab in 3:
		Game.show_screen("res://ui/howto_screen.gd", {"tab": tab})
		await frames(12)
		await _shot(n, "how_to_play_%d" % (tab + 1))
	Game.show_screen("res://ui/button_layout_screen.gd")
	await frames(8)
	await _shot(n, "move_buttons")
	Game.start_match({"home": "SWE", "away": "FIN", "venue": "arena", "user_team": 0, "mode": "quick", "seed": 21, "period": 8.0})
	await frames(300)
	var m: Node = Game.current
	m.set_paused(true)
	await frames(8)
	await _shot(n, "pause")
	m.set_paused(false)
	Game.show_screen("res://ui/result_screen.gd", {"result": await _result(m)})
	await frames(12)
	await _shot(n, "result")
	Game.show_screen("res://ui/licences_screen.gd")
	await frames(90)
	await _shot(n, "licences")
	Game.show_screen("res://ui/help_screen.gd")
	await frames(8)
	await _shot(n, "help")
	Game.show_screen("res://ui/privacy_screen.gd")
	await frames(8)
	await _shot(n, "privacy")


func _scroller(n: Node) -> ScrollContainer:
	if n is ScrollContainer:
		return n
	for ch in n.get_children():
		var s := _scroller(ch)
		if s:
			return s
	return null


## A finished match's result, from a real match played to its end unseen (the box score as the game writes it).
func _result(m: Node) -> Dictionary:
	RenderingServer.render_loop_enabled = false
	m.speed_k = 1.0
	var guard := 0
	while is_instance_valid(m) and m == Game.current and m.phase != "over" and guard < 200000:
		if m.get("phase") == "interval" and m.has_method("continue_after_interval"):
			m.continue_after_interval()
		_auto(m)
		await frames(1)
		guard += 1
	RenderingServer.render_loop_enabled = true
	var r: Dictionary = m.result() if is_instance_valid(m) and m.has_method("result") else {}
	r["user_team"] = 0   # seen as the home side's player sees it
	return r


## Nobody holds the phone: your player is left to the AI like the rest.
func _auto(m: Node) -> void:
	if m.get("user_team") != -1:
		m.user_team = -1
		m.demo = true


func _shot(n: Array, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.get_width() != 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	n[0] += 1
	img.save_png(out.path_join("menus").path_join("%02d_%s.png" % [n[0], name]))
	print("media: menu ", name)


func frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame
