extends Node
## The media kit's trailer and stills, filmed from the game itself (tools/media/make_media_kit.sh runs this and cuts
## the result): a title card, six moments from real AI-v-AI matches in the five venues (a roll spike that scores, a
## serve, a block, a doubles rally, a kill in the gym, a celebration), captions over them, and an end card.
##   trailer: godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 --write-movie raw.avi
##            res://tools/media/trailer.tscn -- OUTDIR trailer        (vertical: --resolution 1080x1920 ... vertical)
##   stills:  godot --path . --rendering-driver opengl3 --resolution 1920x1080 res://tools/media/trailer.tscn -- OUTDIR stills
##   store:   the Play listing's screenshots and feature picture (tools/store/store_shots.tscn sets this mode)
##   menus:   every menu screen, in English (the same line as stills, with menus)
## Each moment is found first: its match is played on, unseen and unheard, within one frame until the touch comes and
## the point ends as wanted; then the same match (the same seed) is played again to a little before it, and filmed.

const FPS := 30.0
const DARK := Color("0c1a29")

# Where, who, the seed; the moment (a touch of this kind and move, in a rally that ended so: "" any); how long before
# the touch the shot starts and how long it runs; the camera; the caption.
const SHOTS := [
	{"name": "roll_spike", "venue": "national", "home": "THA", "away": "MAS", "event": "regu", "seed": 11,
		"kind": "attack", "move": "roll", "ends": "kill", "lead": 2.3, "len": 5.0, "camera": "broadcast",
		"caption": "Roll spikes, sunback spikes, horse-kick serves"},
	{"name": "serve", "venue": "beach", "home": "PHI", "away": "LAO", "event": "regu", "seed": 8,
		"kind": "serve", "move": "", "ends": "", "lead": 1.7, "len": 3.6, "camera": "server",
		"caption": "Five venues, from the national arena to the beach"},
	{"name": "block", "venue": "mall", "home": "MAS", "away": "THA", "event": "regu", "seed": 21,
		"kind": "attack", "move": "", "ends": "block", "lead": 1.8, "len": 4.0, "camera": "low",
		"caption": "Three touches a side, and a block at the net"},
	{"name": "doubles", "venue": "park", "home": "VIE", "away": "INA", "event": "doubles", "seed": 5,
		"kind": "attack", "move": "", "ends": "kill", "lead": 2.6, "len": 4.2, "camera": "side",
		"caption": "Regu, doubles and quadrant, for men and women"},
	{"name": "gym", "venue": "provincial", "home": "MYA", "away": "KOR", "event": "regu", "seed": 31,
		"kind": "attack", "move": "", "ends": "kill", "lead": 2.0, "len": 4.4, "camera": "end",
		"caption": "League seasons and international championships"},
	{"name": "celebration", "venue": "national", "home": "VIE", "away": "THA", "event": "regu", "seed": 17,
		"kind": "attack", "move": "", "ends": "kill", "lead": 0.5, "len": 3.6, "camera": "close",
		"caption": "Thirteen languages. Plays offline. No ads."},
]
# The vertical cut (15 s): three of them, shorter.
const VERTICAL := {"roll_spike": 4.0, "serve": 3.0, "celebration": 3.2}

var out := ""
var mode := "trailer"
var vertical := false
var m: Node = null
var cam: Camera3D
var _shot := {}
var _side := 0
var _dip: ColorRect
var _card: VBoxContainer
var _card_title: Label
var _card_sub: Label
var _cap_box: PanelContainer
var _caption: Label
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if out == "":   # (store_shots sets both before adding this)
		out = a[0] if a.size() > 0 else "/tmp/media"
		mode = a[1] if a.size() > 1 else "trailer"
	vertical = mode == "vertical"
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.reset_settings_for_tests()
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.sound = mode == "trailer" or mode == "vertical"
	Game.settings.language = "en"
	Game.settings.camera = Game.CAM_TV
	TranslationServer.set_locale("en")
	Game._size_theme()
	cam = Camera3D.new()
	add_child(cam)
	_overlay()
	if mode == "stills":
		await _stills()
	elif mode == "store":
		await _store()
	elif mode == "menus":
		await _menus()
	else:
		await _trailer()
	get_tree().quit()


# ---------------------------------------------------------------- the trailer

func _trailer() -> void:
	var shots := []
	for s in SHOTS:
		if not vertical:
			shots.append(s.duplicate())
		elif VERTICAL.has(s.name):
			var v: Dictionary = s.duplicate()
			v.len = VERTICAL[s.name]
			v.lead = minf(float(s.lead), float(v.len) * 0.5)
			shots.append(v)
	# The title over the dark, the first moment made ready under it.
	_dip.color.a = 1.0
	await _show_card("SEPAK TAKRAW UNLEASHED", "Sepak takraw for Android", 1.5 if vertical else 2.5, shots[0])
	for i in shots.size():
		var s: Dictionary = shots[i]
		if i > 0:
			await _fade(_dip, 0.0, 1.0, 0.2)
			_prepare(s)
		await _fade(_dip, 1.0, 0.0, 0.2)
		await _film(s)
	await _fade(_dip, 0.0, 1.0, 0.25)
	_clear_match()
	await _show_card("SEPAK TAKRAW UNLEASHED", "Coming soon to Google Play", 2.5 if vertical else 4.0, {})


## A card over the dark: the title and a line under it, faded in and out; next (if any) made ready behind it.
func _show_card(title: String, sub: String, secs: float, next: Dictionary) -> void:
	_card_title.text = title
	_card_sub.text = sub
	_card.modulate.a = 0.0
	_card.visible = true
	await _fade(_card, 0.0, 1.0, 0.4)
	if not next.is_empty():
		_prepare(next)
	await _wait(maxf(0.1, secs - 0.8))
	await _fade(_card, 1.0, 0.0, 0.4)
	_card.visible = false


## Films the shot: its camera following the play, the caption in for most of it.
func _film(s: Dictionary) -> void:
	var n := int(float(s.len) * FPS)
	_caption.text = String(s.caption)
	_cap_box.modulate.a = 0.0
	_cap_box.visible = true
	for f in n:
		var t := f / FPS
		var k := clampf((t - 0.4) / 0.3, 0.0, 1.0) * clampf((float(s.len) - 0.5 - t) / 0.3, 0.0, 1.0)
		_cap_box.modulate.a = k
		_hold()
		_aim(1.0 / FPS)
		await get_tree().process_frame
	_cap_box.visible = false


# ---------------------------------------------------------------- the stills

## The kit's stills: each moment at its touch (no captions), then the menus.
func _stills() -> void:
	_dip.color.a = 0.0
	var i := 1
	for s in SHOTS:
		var v: Dictionary = s.duplicate()
		v.lead = 0.08 if s.name != "celebration" else -1.6
		_prepare(v)
		for f in 3:
			_hold()
			_aim(1.0 / FPS, true)
			await get_tree().process_frame
		await _save("%02d_%s" % [i, s.name])
		i += 1
	_clear_match()
	Game.settings.sound = false
	Game.delete_season()
	Game.delete_cup()
	cam.current = false
	Game.show_screen("res://ui/main_menu.gd")
	await _wait(2.5)
	await _save("%02d_menu" % i)
	i += 1
	var se = Game.new_season("TH", "SPB")
	for r in 4:
		se.sim_round()
	Game.show_screen("res://ui/season_hub.gd")
	await _wait(0.6)
	await _save("%02d_league_season" % i)
	i += 1
	var cup = Game.new_cup("world", "MAS")
	cup.sim_next()
	cup.sim_next()
	Game.show_screen("res://ui/cup_screen.gd")
	await _wait(0.6)
	await _save("%02d_world_championship" % i)
	i += 1
	Game.show_screen("res://ui/howto_screen.gd")
	await _wait(0.6)
	await _save("%02d_how_to_play" % i)
	Game.delete_season()
	Game.delete_cup()


func _save(name: String, jpg := false) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	if jpg:
		img.save_jpg(out.path_join(name + ".jpg"), 0.9)
	else:
		img.save_png(out.path_join(name + ".png"))
	print("still ", name)


## Every screen of the game's menus, clean and in English, each a PNG named by the screen (and for a long one, the
## rest of it scrolled into view): the loading screen, the home screen and its language picker, Quick Match, League
## Season and International (before one is started, and under way), Records, Settings, How to Play's three tabs,
## Help, the privacy policy and the licences; a match, its pause menu and the pause menu's Settings; and a result.
func _menus() -> void:
	_dip.color.a = 0.0
	cam.current = false
	Game.settings.sound = true   # (as a player has it: Settings shows it on; nothing is recorded)
	Game.delete_season()
	Game.delete_cup()
	var loading: Node = (load("res://ui/loading_screen.gd") as Script).new()
	add_child(loading)
	await _wait(0.5)
	await _menu_shot("loading")
	loading.queue_free()
	Game.show_screen("res://ui/main_menu.gd")
	await _wait(2.5)
	await _menu_shot("home")
	Game.current._open_language()
	await _wait(0.6)
	await _menu_shot("language")
	Game.show_screen("res://ui/quick_setup.gd")
	await _wait(0.6)
	await _menu_shot("quick_match", true)
	Game.show_screen("res://ui/season_hub.gd")
	await _wait(0.6)
	await _menu_shot("league_season_new")
	var se = Game.new_season("TH", "SPB")
	for r in 4:
		se.sim_round()
	Game.show_screen("res://ui/season_hub.gd")
	await _wait(0.6)
	await _menu_shot("league_season", true)
	Game.show_screen("res://ui/cup_screen.gd")
	await _wait(0.6)
	await _menu_shot("international_new")
	var cup = Game.new_cup("world", "MAS")
	cup.sim_next()
	cup.sim_next()
	Game.show_screen("res://ui/cup_screen.gd")
	await _wait(0.6)
	await _menu_shot("international", true)
	Game.show_screen("res://ui/records_screen.gd")
	await _wait(0.6)
	await _menu_shot("records")
	Game.show_screen("res://ui/settings_screen.gd")
	await _wait(0.6)
	await _menu_shot("settings", true)
	for t in 3:
		Game.show_screen("res://ui/howto_screen.gd", {"tab": t})
		await _wait(0.6)
		await _menu_shot("how_to_play_" + ["rules", "controls", "moves"][t])
	Game.show_screen("res://ui/doc_screen.gd", {"kind": "help", "back": func(): pass})
	await _wait(0.6)
	await _menu_shot("help", true)
	Game.show_screen("res://ui/doc_screen.gd", {"kind": "privacy", "back": func(): pass})
	await _wait(0.6)
	await _menu_shot("privacy", true)
	Game.show_screen("res://ui/licences_screen.gd", {"back": func(): pass})
	await _wait(0.8)
	await _menu_shot("licences")
	# A match of yours: playing, paused, the pause menu's Settings.
	Game.start_match({"home": "THA", "away": "MAS", "venue": "national", "event": "regu", "sets": 3, "points": 15,
		"difficulty": 2, "mode": "quick", "user_team": 0, "women": false, "seed": 11})
	await _wait(4.0)
	await _menu_shot("match")
	var mt: Node = Game.current
	mt.set_paused(true)
	await _wait(0.6)
	await _menu_shot("pause")
	mt.hud.open_settings()
	await _wait(0.6)
	await _menu_shot("pause_settings")
	mt.hud.close_settings()
	mt.set_paused(false)
	# A result: an AI-v-AI match played to the end within a frame, shown as the winner's.
	Game.goto_menu()
	await _wait(0.3)
	var mm := _make({"home": "VIE", "away": "INA", "venue": "national", "event": "regu", "seed": 7, "sets": 1})
	var res := {"r": {}}
	mm.finished.connect(func(r): res.r = r)
	while int(mm.state) != int(mm.S.OVER):
		_step(mm)
	while res.r.is_empty():
		await get_tree().process_frame
	var r: Dictionary = res.r
	r.user_team = int(r.winner)
	mm.queue_free()
	Game.show_screen("res://ui/result_screen.gd", {"result": r})
	await _wait(0.8)
	await _menu_shot("result", true)
	Game.delete_season()
	Game.delete_cup()


var _n := 1

## The screen as it is; and if it scrolls, its last part too ("…_more").
func _menu_shot(name: String, more := false) -> void:
	await _save("%02d_%s" % [_n, name])
	_n += 1
	if not more or Game.current == null:
		return
	for sc in Game.current.find_children("*", "ScrollContainer", true, false):
		var bar := (sc as ScrollContainer).get_v_scroll_bar()
		if bar.max_value - bar.page > 40.0:
			(sc as ScrollContainer).scroll_vertical = int(bar.max_value)
			await _wait(0.3)
			await _save("%02d_%s_more" % [_n, name])
			_n += 1
			return


## The Play listing's eight screenshots (JPEG, the score showing as in a match) and the feature graphic's picture
## (the roll spike without it: tools/store/make_feature.py crops it), then the menus, the last in Thai.
func _store() -> void:
	_dip.color.a = 0.0
	var names := {"roll_spike": "01_roll_spike", "serve": "02_serve", "block": "03_mall", "doubles": "04_park"}
	for s in SHOTS:
		if not names.has(s.name):
			continue
		var v: Dictionary = s.duplicate()
		v.lead = 0.08
		_prepare(v)
		m.hud.visible = true
		for f in 3:
			_hold()
			_aim(1.0 / FPS, true)
			await get_tree().process_frame
		await _save(names[s.name], true)
		if s.name == "roll_spike":
			m.hud.visible = false
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_png(ProjectSettings.globalize_path("res://store/graphics/feature_src.png"))
	_clear_match()
	cam.current = false
	Game.settings.sound = false
	Game.delete_season()
	Game.delete_cup()
	Game.show_screen("res://ui/main_menu.gd")
	await _wait(2.5)
	await _save("05_menu", true)
	var se = Game.new_season("TH", "SPB")
	for r in 4:
		se.sim_round()
	Game.show_screen("res://ui/season_hub.gd")
	await _wait(0.6)
	await _save("06_season", true)
	var cup = Game.new_cup("world", "MAS")
	cup.sim_next()
	cup.sim_next()
	Game.show_screen("res://ui/cup_screen.gd")
	await _wait(0.6)
	await _save("07_world_cup", true)
	Game.settings.language = "th"
	TranslationServer.set_locale("th")
	Game._size_theme()
	Game.show_screen("res://ui/main_menu.gd")
	await _wait(2.5)
	await _save("08_thai", true)
	Game.delete_season()
	Game.delete_cup()


# ---------------------------------------------------------------- a moment, found and made ready

## The shot's match, played on to `lead` seconds before its moment: all within this one frame, unheard.
func _prepare(s: Dictionary) -> void:
	_shot = s
	AudioServer.set_bus_mute(0, true)
	var found := _find(s)
	_clear_match()
	seed(int(s.seed))
	m = _make(s)
	var t0 := maxf(0.0, float(found.t) - float(s.lead))
	while float(m.now) < t0:
		_step(m)
	_side = int(found.side)
	m.hud.visible = false
	m.controls.visible = false
	if String(s.venue) == "mall":
		Sfx.ambience("")   # the mall's chatter is CC BY-SA: kept out of the trailer, whose licence it would set
	_place_camera(s)
	AudioServer.set_bus_mute(0, false)
	print("shot %s: the moment at %.2f s (side %d), filmed from %.2f" % [s.name, float(found.t), _side, t0])


## Plays the shot's match until the moment comes (a touch of its kind and move, the point ending as it says); the
## match time of the touch and the side making it. Tries the next seeds if the first match has none in four minutes.
func _find(s: Dictionary) -> Dictionary:
	for attempt in 6:
		var sd: int = int(s.seed) + attempt * 100
		seed(sd)
		var mm := _make(s.merged({"seed": sd}, true))
		var cand := -1.0
		var side := 0
		var logged := 0
		var steps := int(240.0 * FPS)
		for i in steps:
			_step(mm)
			var p: Dictionary = mm.plan
			if cand < 0.0 and not p.is_empty() and String(p.kind) == String(s.kind) \
					and (String(s.move) == "" or String(p.get("move", "")) == String(s.move)) \
					and float(p.t) - float(mm.now) < 0.1 and p.get("player") != null:
				cand = float(p.t)
				side = int((p.player as Player).side)
				logged = mm.log.size()
				if String(s.ends) == "":
					break
			if cand >= 0.0 and mm.log.size() > logged:
				if String(mm.log[-1][1]).begins_with(String(s.ends)):
					break
				cand = -1.0
		mm.queue_free()
		remove_child(mm)
		if cand >= 0.0:
			s.seed = sd
			return {"t": cand, "side": side}
	push_error("trailer: no moment found for " + String(s.name))
	return {"t": 20.0, "side": 0}


func _make(s: Dictionary) -> Node:
	var mm: Node = (load("res://game/match.gd") as Script).new()
	mm.config = {"home": s.home, "away": s.away, "venue": s.venue, "event": s.event, "sets": int(s.get("sets", 3)), "points": 15,
		"user_team": -1, "demo": true, "seed": int(s.seed), "mode": "quick", "difficulty": 3}
	add_child(mm)
	return mm


func _step(mm: Node) -> void:
	mm._process(1.0 / FPS)
	mm.set("_start_replay_after", -1.0)   # no replays: the shot goes on as it was played


## Keeps the match from cutting to a replay while it is filmed.
func _hold() -> void:
	if m:
		m.set("_start_replay_after", -1.0)


func _clear_match() -> void:
	if m and is_instance_valid(m):
		m.queue_free()
		remove_child(m)
	m = null


# ---------------------------------------------------------------- the cameras

func _place_camera(s: Dictionary) -> void:
	var c := String(s.camera)
	cam.fov = 58.0 if vertical else 40.0
	if c in ["broadcast", "end", "side"] and not vertical:
		var rig: CameraRig = m.cam
		rig.mode = {"broadcast": Game.CAM_TV, "end": Game.CAM_END, "side": Game.CAM_SIDE}[c]
		rig.snap()
		rig.current = true
		return
	cam.current = true
	_aim(0.0, true)


## The shot's own camera, following the play smoothly (the game's cameras follow by themselves).
func _aim(dt: float, snap := false) -> void:
	if m == null or not cam.current:
		return
	var b: Vector3 = m.ball.global_position
	var c := String(_shot.get("camera", "low"))
	var sg := Court.sgn(_side)   # the side making the moment: x < 0 for side 0
	var pos := Vector3.ZERO
	var look := b
	match c:
		"server":
			# Low behind the server's shoulder, along the court toward the net.
			var srv: Player = m._server()
			pos = srv.position + Vector3(Court.sgn(srv.side) * 3.4, 1.5, -1.6)
			look = Vector3(0, 1.3, srv.position.z * 0.5) .lerp(b, 0.35)
		"low":
			# Low on the near side, off to the right of the assistant referee (he stands by the near post).
			pos = Vector3(clampf(b.x * 0.5, -1.5, 3.5) + 2.4, 1.35, -8.2)
			look = Vector3(b.x * 0.8, maxf(1.0, b.y * 0.7), 0.0)
		"close":
			# By the net on the near side, on the team that scored, as it celebrates.
			var mid := Vector3.ZERO
			for p in m.players_on(_side):
				mid += (p as Player).position
			mid /= maxf(1, m.players_on(_side).size())
			pos = Vector3(sg * 1.2, 1.55, -4.6)
			look = mid + Vector3(0, 1.1, 0)
		_:
			# (Vertical: the game's cameras are made for a wide picture) closer, high, following the ball.
			pos = Vector3(clampf(b.x * 0.6, -4.0, 4.0), 5.5, -10.5)
			look = Vector3(b.x * 0.8, 0.8 + b.y * 0.3, b.z * 0.3)
	if vertical and c in ["low", "server", "close"]:
		pos += (pos - look).normalized() * 1.2
	if snap:
		_cam_pos = pos
		_cam_look = look
	else:
		_cam_pos = _cam_pos.lerp(pos, minf(1.0, 3.0 * dt))
		_cam_look = _cam_look.lerp(look, minf(1.0, 5.0 * dt))
	cam.global_position = _cam_pos
	cam.look_at(_cam_look)


# ---------------------------------------------------------------- the overlay

func _overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_dip = ColorRect.new()
	_dip.color = Color(DARK, 0.0)
	_dip.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_dip)
	# The cards: the icon, the name, a line.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	_card = VBoxContainer.new()
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_theme_constant_override("separation", 18)
	_card.visible = false
	center.add_child(_card)
	var icon := TextureRect.new()
	icon.texture = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://store/graphics/icon-512.png")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(300, 300) if vertical else Vector2(260, 260)
	_card.add_child(icon)
	_card_title = Label.new()
	_card_title.add_theme_font_override("font", Game.font_display)
	_card_title.add_theme_font_size_override("font_size", 92 if vertical else 110)
	_card_title.add_theme_color_override("font_color", Color.WHITE)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if vertical:
		_card_title.autowrap_mode = TextServer.AUTOWRAP_WORD
		_card_title.custom_minimum_size = Vector2(900, 0)
	_card.add_child(_card_title)
	_card_sub = Label.new()
	_card_sub.add_theme_font_override("font", Game.font_bold)
	_card_sub.add_theme_font_size_override("font_size", 46)
	_card_sub.add_theme_color_override("font_color", Game.C_SAFFRON)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_card_sub)
	# The caption: a dark band low in the picture.
	_cap_box = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(DARK, 0.82)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.border_color = Game.C_SAFFRON
	sb.border_width_left = 8
	_cap_box.add_theme_stylebox_override("panel", sb)
	_cap_box.visible = false
	_cap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption = Label.new()
	_caption.add_theme_font_override("font", Game.font_display)
	_caption.add_theme_font_size_override("font_size", 64 if vertical else 58)
	_caption.add_theme_color_override("font_color", Color.WHITE)
	if vertical:
		_caption.autowrap_mode = TextServer.AUTOWRAP_WORD
		_caption.custom_minimum_size = Vector2(880, 0)
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap_box.add_child(_caption)
	layer.add_child(_cap_box)
	if vertical:
		_cap_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_cap_box.offset_left = -490
		_cap_box.offset_right = 490
		_cap_box.offset_top = -420
		_cap_box.offset_bottom = -240
	else:
		_cap_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_cap_box.offset_left = 90
		_cap_box.offset_top = -190
		_cap_box.offset_bottom = -90
		_cap_box.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _fade(node: CanvasItem, from: float, to: float, secs: float) -> void:
	var n := maxi(1, int(secs * FPS))
	for i in n:
		var k := float(i + 1) / n
		if node is ColorRect:
			(node as ColorRect).color.a = lerpf(from, to, k)
		else:
			node.modulate.a = lerpf(from, to, k)
		_hold()
		_aim(1.0 / FPS)
		await get_tree().process_frame


func _wait(secs: float) -> void:
	for i in maxi(1, int(secs * FPS)):
		_hold()
		_aim(1.0 / FPS)
		await get_tree().process_frame
