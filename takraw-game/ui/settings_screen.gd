extends Control
## Settings, grouped into cards: the game, the screen, sound and controls, and about.

var _fps_note: Label
var _assist_note: Label


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
	var akeys := ["ASSIST_OFF", "ASSIST_RUN", "ASSIST_FULL"]
	_assist_note = UI.wrap(tr(akeys[int(Game.settings.assist)] + "_NOTE"), "MutedLabel", 17)
	game[1].add_child(UI.field(tr("ASSIST"), UI.chips([tr("ASSIST_OFF"), tr("ASSIST_RUN"), tr("ASSIST_FULL")], int(Game.settings.assist), func(i):
		Game.settings.assist = i
		Game.save_settings()
		_assist_note.text = tr(akeys[i] + "_NOTE"))))
	game[1].add_child(_assist_note)

	# The screen.
	var disp: Array = UI.section(tr("SET_DISPLAY"), "display")
	right.add_child(disp[0])
	disp[1].add_child(UI.field(tr("GRAPHICS"), UI.chips([tr("GFX_LOW"), tr("GFX_MEDIUM"), tr("GFX_HIGH")], int(Game.settings.graphics), func(i):
		Game.settings.graphics = i
		Game.save_settings())))
	disp[1].add_child(UI.wrap(tr("GFX_NOTE"), "MutedLabel", 17))
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
	_fps_note = UI.wrap(_fps_text(fps_opts[shown], smooth, hz), "MutedLabel", 17)
	disp[1].add_child(_fps_note)
	disp[1].add_child(UI.field(tr("CAMERA"), UI.chips([tr("CAM_TV"), tr("CAM_END")], int(Game.settings.camera), func(i):
		Game.settings.camera = i
		Game.save_settings())))
	disp[1].add_child(UI.field(tr("PLAYER_TAGS"), UI.chips([tr("TAGS_KEY"), tr("TAGS_ALL"), tr("OFF")], int(Game.settings.tags), func(i):
		Game.settings.tags = i
		Game.save_settings())))

	# Sound and controls.
	var snd: Array = UI.section(tr("SET_SOUND_CONTROLS"), "sound")
	left.add_child(snd[0])
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 36)
	row.add_theme_constant_override("v_separation", 14)
	for key in ["sound", "music", "vibration", "left_handed"]:
		row.add_child(_toggle(key, {"sound": "SOUND", "music": "MUSIC", "vibration": "VIBRATION", "left_handed": "LEFT_HANDED"}[key]))
	snd[1].add_child(row)
	snd[1].add_child(UI.field(tr("BUTTON_SIZE"), UI.chips([tr("SIZE_NORMAL"), tr("SIZE_LARGE"), tr("SIZE_XL")], int(Game.settings.btn_size), func(i):
		Game.settings.btn_size = i
		Game.save_settings())))

	# About.
	var about: Array = UI.section(tr("SET_ABOUT"), "book")
	right.add_child(about[0])
	about[1].add_child(UI.label(tr("VERSION_N").format({"v": String(ProjectSettings.get_setting("application/config/version"))}), "MutedLabel", 17))
	var links := HFlowContainer.new()
	links.add_theme_constant_override("h_separation", 10)
	links.add_theme_constant_override("v_separation", 10)
	links.add_child(UI.button(tr("PRIVACY_POLICY"), false, func(): OS.shell_open(Game.PRIVACY_URL)))
	links.add_child(UI.button(tr("HELP_SUPPORT"), false, func(): OS.shell_open(Game.SUPPORT_URL)))
	links.add_child(UI.button(tr("LICENCES"), false, func(): Game.show_screen("res://ui/licences_screen.gd")))
	about[1].add_child(links)


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
		Game.save_settings()
		if key == "sound" and i == 1:
			Sfx.stop_all()
		if key in ["sound", "music"]:
			Sfx.music(true)))
