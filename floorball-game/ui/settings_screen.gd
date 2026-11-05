extends Control
## Settings, as cards on the board: the game, the screen, sound and controls, and about.

var _fps_note: Label
var _ver_taps := 0
var _ver_last := 0


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("MENU_SETTINGS"), func(): Game.goto_menu())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 20)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 20)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	cols.add_child(right)
	v.add_child(UI.scroll(cols))

	# The game.
	var game: Array = UI.section(tr("SET_GAME"), "flag")
	left.add_child(game[0])
	var names := [tr("LANG_PHONE")]
	var codes := [""]
	for pair in Game.LANGUAGES:
		codes.append(pair[0])
		names.append(pair[1])
	game[1].add_child(UI.field(tr("LANGUAGE"), UI.chips(names, codes.find(String(Game.settings.language)), func(i):
		Game.set_language(codes[i])
		Game.show_screen("res://ui/settings_screen.gd"))))
	game[1].add_child(UI.difficulty_field(self))
	game[1].add_child(UI.field(tr("GAME_SPEED"), UI.chips([tr("SPEED_STEADY"), tr("SPEED_REAL")], int(Game.settings.get("game_speed", 0)), func(i):
		Game.settings.game_speed = i
		Game.save_settings())))
	game[1].add_child(UI.wrap(tr("SPEED_NOTE"), "MutedLabel", 16))
	game[1].add_child(_toggle("auto_switch", "AUTO_SWITCH"))
	game[1].add_child(UI.wrap(tr("AUTO_SWITCH_NOTE"), "MutedLabel", 16))
	game[1].add_child(_toggle("tips", "SET_TIPS"))

	# The screen.
	var disp: Array = UI.section(tr("SET_DISPLAY"), "display")
	right.add_child(disp[0])
	disp[1].add_child(UI.field(tr("GRAPHICS"), UI.chips([tr("GFX_LOW"), tr("GFX_MEDIUM"), tr("GFX_HIGH")], int(Game.settings.graphics), func(i):
		Game.settings.graphics = i
		Game.save_settings())))
	disp[1].add_child(_toggle("auto_gfx", "AUTO_GFX"))
	disp[1].add_child(UI.wrap(tr("GFX_NOTE"), "MutedLabel", 16))
	var hz := Game.screen_hz()
	var smooth := Game.smooth_cap(hz)
	var fps_opts := [Game.FPS_SAVER]
	var fps_names := [tr("FPS_SAVER")]
	if smooth > 0 and smooth < hz:
		fps_opts.append(Game.FPS_SMOOTH)
		fps_names.append(tr("FPS_N").format({"n": smooth}))
	fps_opts.append(Game.FPS_MAX)
	fps_names.append(tr("FPS_MAX_N").format({"n": hz}))
	var shown := fps_opts.find(int(Game.settings.get("fps", Game.FPS_SMOOTH)))
	if shown < 0:
		shown = fps_opts.size() - 1
	disp[1].add_child(UI.field(tr("FRAME_RATE"), UI.chips(fps_names, shown, func(i):
		Game.settings.fps = fps_opts[i]
		Game.save_settings()
		Game.apply_frame_rate()
		_fps_note.text = _fps_text(fps_opts[i], smooth, hz))))
	_fps_note = UI.wrap(_fps_text(fps_opts[shown], smooth, hz), "MutedLabel", 16)
	disp[1].add_child(_fps_note)
	var cams := [Game.CAM_TV, Game.CAM_HIGH, Game.CAM_END]
	disp[1].add_child(UI.field(tr("CAMERA"), UI.chips([tr("CAM_TV"), tr("CAM_HIGH"), tr("CAM_END")], maxi(0, cams.find(int(Game.settings.camera))), func(i):
		Game.settings.camera = cams[i]
		Game.save_settings())))

	# Sound and controls.
	var snd: Array = UI.section(tr("SET_SOUND_CONTROLS"), "sound")
	left.add_child(snd[0])
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 30)
	row.add_theme_constant_override("v_separation", 14)
	for key in ["sound", "music", "vibration", "left_handed"]:
		row.add_child(_toggle(key, {"sound": "SOUND", "music": "MUSIC", "vibration": "VIBRATION", "left_handed": "LEFT_HANDED"}[key]))
	snd[1].add_child(row)
	snd[1].add_child(UI.field(tr("BUTTON_SIZE"), UI.chips([tr("SIZE_NORMAL"), tr("SIZE_LARGE"), tr("SIZE_XL")], int(Game.settings.btn_size), func(i):
		Game.settings.btn_size = i
		Game.save_settings())))
	snd[1].add_child(UI.button(tr("MOVE_BUTTONS"), false, func(): Game.show_screen("res://ui/button_layout_screen.gd")))

	# About.
	var about: Array = UI.section(tr("SET_ABOUT"), "book")
	right.add_child(about[0])
	var ver := UI.label(tr("VERSION_N").format({"v": String(ProjectSettings.get_setting("application/config/version"))}), "MutedLabel", 17)
	ver.mouse_filter = Control.MOUSE_FILTER_STOP
	ver.gui_input.connect(_ver_tap)
	about[1].add_child(ver)
	about[1].add_child(UI.wrap(tr("ABOUT_DISCLAIMER"), "MutedLabel", 15))
	var links := HFlowContainer.new()
	links.add_theme_constant_override("h_separation", 10)
	links.add_theme_constant_override("v_separation", 10)
	# Each a page in the game itself: they work offline (the game has no internet permission).
	links.add_child(UI.button(tr("LICENCES"), false, func(): Game.show_screen("res://ui/licences_screen.gd")))
	links.add_child(UI.button(tr("HELP_SUPPORT"), false, func(): Game.show_screen("res://ui/help_screen.gd")))
	links.add_child(UI.button(tr("PRIVACY_POLICY"), false, func(): Game.show_screen("res://ui/privacy_screen.gd")))
	about[1].add_child(links)
	if bool(Game.settings.dev):
		about[1].add_child(UI.label(tr("DEV_ON"), "MutedLabel", 15, Game.C_RED))


## Seven taps on the version turn the developer's overlay (frame times, hitches, draw calls) on or off.
func _ver_tap(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var now := Time.get_ticks_msec()
		_ver_taps = _ver_taps + 1 if now - _ver_last < 600 else 1
		_ver_last = now
		if _ver_taps >= 7:
			_ver_taps = 0
			Game.settings.dev = not bool(Game.settings.dev)
			Game.save_settings()
			Game.show_screen("res://ui/settings_screen.gd")


func _fps_text(opt: int, smooth: int, hz: int) -> String:
	match opt:
		Game.FPS_SAVER:
			return tr("FPS_NOTE_SAVER").format({"n": Game.saver_cap(hz)})
		Game.FPS_SMOOTH:
			return tr("FPS_NOTE_SMOOTH").format({"n": smooth, "hz": hz})
	return tr("FPS_NOTE_MAX").format({"hz": hz})


func _toggle(key: String, title_key: String) -> VBoxContainer:
	return UI.field(tr(title_key), UI.chips_row([tr("ON"), tr("OFF")], 0 if Game.settings[key] else 1, func(i):
		Game.settings[key] = i == 0
		if key == "tips":
			Game.settings.tips_seen = []
		Game.save_settings()
		if key == "sound" and i == 1:
			Sfx.stop_all()
		if key in ["sound", "music"]:
			Sfx.music(true)))
