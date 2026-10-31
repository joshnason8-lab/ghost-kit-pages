extends "res://tests/screenshots.gd"
## The media kit's pictures (tools/media_kit/make_kit.py runs it): the game on High, in English, at 1920x1080.
## Needs a display (xvfb works):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 --resolution 1920x1080 \
##       res://tests/media.tscn -- OUT shots|menus
## "shots": raids on every ground with the HUD off, caught as they happen (a touch, a hold, an escape, the team
## celebrating a point), and two with the HUD on. "menus": every menu screen, named by screen.

const ACTION := ["touch", "hold", "escape", "takedown"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://media"
	var what: String = args[1] if args.size() > 1 else "shots"
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.auto_gfx = false
	Game.settings.dev = false
	Game.settings.language = "en"
	TranslationServer.set_locale("en")
	if what == "menus":
		Game.settings.auto_gfx = true   # Settings shows the game as it ships
		await _media_menus()
	else:
		await _media_shots()
	get_tree().quit(0)


# ---------------------------------------------------------------- the game being played

func _media_shots() -> void:
	var plans := [
		["dome", "MUM", "PAT", false], ["village", "HYD", "JAI", false], ["stadium", "IND", "IRN", false],
		["monsoon", "KOL", "CHE", false], ["beach", "BAN", "NEP", false], ["stadium", "KOR", "PAK", true],
		["dome", "DEL", "BLR", true]]
	var n := 0
	for p in plans:
		n = await _ground_shots(p[0], p[1], p[2], p[3], n)


## An AI match on one ground: a shot just after each kind of moment the first time it happens there, and the team
## celebrating its first point, until three are taken (one with the HUD on).
func _ground_shots(arena: String, home: String, away: String, hud: bool, n: int) -> int:
	Game.start_match({"home": home, "away": away, "arena": arena, "mode": "quick", "autoplay": true, "length": 1,
		"difficulty": 3})
	var m: Node = Game.current
	m.hud.visible = hud
	await frames(2)
	# Drawn without a GPU, High takes seconds a frame: the world is only drawn for the frames just before a shot.
	m.cam.cam.cull_mask = 0
	var pending := []   # [frame to shoot at, name]
	var seen := {}
	var state := {"frame": 0}
	m.game_event.connect(func(kind, info):
		if kind in ACTION and not seen.has(kind) and pending.size() < 2:
			seen[kind] = true
			pending.append([state.frame + (6 if kind == "touch" else 10), kind])
		elif kind == "raid_end" and not seen.has("celebrate") and (int(info.raid_pts) > 0 or int(info.def_pts) > 0):
			seen["celebrate"] = true
			pending.append([state.frame + 45, "celebrate"]))
	var taken := 0
	var want := 1 if hud else 3
	while taken < want and state.frame < 30 * 60 * 6:
		await get_tree().process_frame
		state.frame += 1
		m.hud.visible = hud
		m.cam.cam.cull_mask = 0xFFFFF if not pending.is_empty() and state.frame >= int(pending[0][0]) - 4 else 0
		if not pending.is_empty() and state.frame >= int(pending[0][0]):
			var p: Array = pending.pop_front()
			n += 1
			await shot("%02d_%s_%s%s" % [n, arena, p[1], "_hud" if hud else ""])
			taken += 1
	return n


# ---------------------------------------------------------------- the menus

func _media_menus() -> void:
	var n := [0]
	var take := func(name: String):
		n[0] += 1
		await shot("%02d_%s" % [n[0], name])
	var menu: Node = Game.show_screen("res://ui/main_menu.gd")
	await frames(2)
	_hide_version(menu)
	await frames(200)
	await take.call("home")
	menu._open_language()
	await frames(20)
	await take.call("language")
	Game.show_screen("res://ui/quick_setup.gd")
	await frames(30)
	await take.call("quick_match_teams_and_ground")
	await _pages("settings", "res://ui/settings_screen.gd", take)
	await _pages("how_to_play", "res://ui/howto_screen.gd", take)
	await _pages("help", "res://ui/help_screen.gd", take)
	await _pages("privacy_policy", "res://ui/privacy_screen.gd", take)
	await _pages("licences", "res://ui/licences_screen.gd", take)
	# League Season: picking a franchise, the auction, the season's hub.
	Game.delete_season()
	Game.show_screen("res://ui/season_hub.gd")
	await frames(20)
	await take.call("league_season_franchise")
	var se = Game.new_season("PAT")
	se.seed_value = 4242
	Game.save_season()
	Game.show_screen("res://ui/auction_screen.gd", {"mode": "owner"})
	await frames(150)
	await take.call("league_season_auction")
	var eng: AuctionEngine = se.make_auction()
	eng.resolve_all(false)
	se.finish_auction(eng)
	for i in 4:
		se.simulate_user_match()
	se.news_seen = se.news_n[0]
	Game.save_season()
	Game.show_screen("res://ui/season_hub.gd")
	await frames(40)
	await take.call("league_season_hub")
	Game.delete_season()
	# Nations Cup: picking a country, then the cup's hub.
	Game.delete_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(20)
	await take.call("nations_cup_country")
	var cup = Game.new_cup("IND")
	cup.confirm_squad(cup.best_squad(), String(cup.best_squad()[0].id))
	cup.simulate_user_match()
	cup.news_seen = cup.news_n[0]
	Game.save_cup()
	Game.show_screen("res://ui/cup_screen.gd")
	await frames(40)
	await take.call("nations_cup_hub")
	Game.delete_cup()
	# A match: the HUD in play, the pause menu, and Move buttons from it.
	Game.start_match({"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "control": "all", "length": 0,
		"difficulty": 1, "first_raider": 0, "passive": true})
	var m: Node = Game.current
	await frames(2)
	m.cam.cam.cull_mask = 0   # the walk-out, not drawn (see _ground_shots)
	var guard := 0
	while m.phase != "raid" and guard < 1200:
		await get_tree().process_frame
		guard += 1
	await frames(56)
	m.cam.cam.cull_mask = 0xFFFFF
	await frames(4)
	await take.call("match")
	m.set_paused(true)
	await frames(20)
	await take.call("pause")
	var mover = _button_with(m, tr("MOVE_BUTTONS"))
	if mover:
		_tap(mover)
		await frames(20)
		await take.call("move_buttons")
	# After a match: the result, its box score, the awards and a trophy.
	var rs := Game.show_screen("res://ui/result_screen.gd", {"result": load("res://tests/fit_audit.gd").sample_result()})
	await frames(20)
	await take.call("result")
	_tap((rs.get_meta("header_right") as Node).find_children("*", "Button", true, false)[1])
	await frames(10)
	await take.call("box_score")
	var sq: Array = DB.team("PAT").squad
	var aw := {"mvp": {"pid": sq[0].id, "name": sq[0].name, "team": "PAT", "raid": 212, "tackle": 14},
		"raider": {"pid": sq[0].id, "name": sq[0].name, "team": "PAT", "raid": 212, "tackle": 14},
		"defender": {"pid": "DEL_6", "name": DB.team("DEL").squad[6].name, "team": "DEL", "raid": 3, "tackle": 71}}
	Game.show_screen("res://ui/awards_screen.gd", {"awards": aw, "label": "Season 1", "mine": "PAT"})
	await frames(40)
	await take.call("season_awards")
	Game.show_screen("res://ui/trophy_screen.gd", {"team": "IND", "title": "Nations Cup", "back": "res://ui/main_menu.gd"})
	await frames(90)
	await take.call("trophy")


## A screen, and if it is longer than the screen, each further screenful as it scrolls down.
func _pages(name: String, path: String, take: Callable) -> void:
	var s: Node = Game.show_screen(path)
	await frames(30)
	await take.call(name)
	var sc: ScrollContainer = null
	for c in s.find_children("*", "ScrollContainer", true, false):
		var bar := (c as ScrollContainer).get_v_scroll_bar()
		if bar.max_value - bar.page > 40 and (sc == null or bar.max_value > sc.get_v_scroll_bar().max_value):
			sc = c
	if sc == null:
		return
	var bar := sc.get_v_scroll_bar()
	var part := 1
	while sc.scroll_vertical < bar.max_value - bar.page - 1 and part < 6:
		sc.scroll_vertical += int(bar.page * 0.9)
		part += 1
		await frames(6)
		await take.call("%s_%d" % [name, part])


func _button_with(root: Node, text: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree():
			return b
	return null


func _hide_version(menu: Node) -> void:
	for l in menu.find_children("*", "Label", true, false):
		if String(l.text).begins_with("v0."):
			l.modulate.a = 0.0
