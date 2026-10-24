extends Control
## Settings, grouped into cards: the game, the raid rule, the screen, sound and controls.

const RULE_KEYS := ["RULE_CLOCK", "RULE_CANT_TAP", "RULE_CANT_AUTO"]
const RULE_NOTES := ["RULE_CLOCK_NOTE", "RULE_TAP_NOTE", "RULE_BREATH_NOTE"]

var _rule_note: Label
var _fps_note: Label


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
	var codes := [""]   # "" follows the phone
	for pair in Game.LANGUAGES:
		codes.append(pair[0])
		names.append(pair[1])
	game[1].add_child(UI.field(tr("LANGUAGE"), UI.chips(names, codes.find(String(Game.settings.language)), func(i):
		Game.set_language(codes[i])
		# Rebuild so every label picks up the new language.
		Game.show_screen("res://ui/settings_screen.gd"))))
	game[1].add_child(UI.difficulty_field(self))
	game[1].add_child(UI.field(tr("MATCH_LENGTH"), UI.chips([tr("LENGTH_SHORT"), tr("LENGTH_MEDIUM"), tr("LENGTH_FULL")], int(Game.settings.length), func(i):
		Game.settings.length = i
		Game.save_settings())))

	# The raid rule, with what each one means.
	var rule: Array = UI.section(tr("RAID_RULE"), "whistle")
	left.add_child(rule[0])
	var rnames := []
	for k in RULE_KEYS:
		rnames.append(tr(k))
	var cur := clampi(int(Game.settings.get("raid_rule", 2)), 0, 2)
	rule[1].add_child(UI.chips(rnames, cur, func(i):
		Game.settings.raid_rule = i
		Game.save_settings()
		_rule_note.text = tr(RULE_NOTES[i])))
	_rule_note = UI.wrap(tr(RULE_NOTES[cur]), "MutedLabel", 17)
	rule[1].add_child(_rule_note)
	left.move_child(rule[0], 0)   # the raid rule matters most: put it first

	# The screen.
	var disp: Array = UI.section(tr("SET_DISPLAY"), "display")
	right.add_child(disp[0])
	disp[1].add_child(UI.field(tr("GRAPHICS"), UI.chips([tr("GFX_LOW"), tr("GFX_MEDIUM"), tr("GFX_HIGH")], int(Game.settings.graphics), func(i):
		Game.settings.graphics = i
		Game.save_settings())))
	disp[1].add_child(_toggle("auto_gfx", "GFX_AUTO"))
	# Frame rate: the battery saver, Smooth (60, or as near as the screen shows evenly) and the screen's own rate.
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
		shown = fps_opts.size() - 1   # Smooth on a screen it does not divide evenly is the screen's own rate
	disp[1].add_child(UI.field(tr("FRAME_RATE"), UI.chips(fps_names, shown, func(i):
		Game.settings.fps = fps_opts[i]
		Game.save_settings()
		Game.apply_frame_rate()
		_fps_note.text = _fps_text(fps_opts[i], smooth, hz))))
	_fps_note = UI.wrap(_fps_text(fps_opts[shown], smooth, hz), "MutedLabel", 17)
	disp[1].add_child(_fps_note)
	if RiggedBody.available():
		disp[1].add_child(UI.field(tr("SET_MODELS"), UI.chips([tr("MODELS_CLASSIC"), tr("MODELS_REAL")], int(Game.settings.get("models", 1)), func(i):
			Game.settings.models = i
			Game.save_settings())))
	var cams := [Game.CAM_TV, Game.CAM_THIRD]   # the broadcast camera first: it is the default
	disp[1].add_child(UI.field(tr("CAMERA"), UI.chips([tr("CAM_TV"), tr("CAM_THIRD")], maxi(0, cams.find(int(Game.settings.camera))), func(i):
		Game.settings.camera = cams[i]
		Game.save_settings())))
	# Who is who in a match: tags over the players' heads.
	disp[1].add_child(UI.field(tr("PLAYER_TAGS"), UI.chips([tr("TAGS_KEY"), tr("TAGS_ALL"), tr("OFF")], clampi(int(Game.settings.get("tags", 0)), 0, 2), func(i):
		Game.settings.tags = i
		Game.save_settings())))

	# Sound and controls.
	var snd: Array = UI.section(tr("SET_SOUND_CONTROLS"), "sound")
	right.add_child(snd[0])
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 36)
	row.add_theme_constant_override("v_separation", 14)
	for key in ["sound", "music", "vibration", "left_handed"]:
		row.add_child(_toggle(key, {"sound": "SOUND", "music": "MUSIC", "vibration": "VIBRATION", "left_handed": "LEFT_HANDED"}[key]))
	snd[1].add_child(row)
	# How loud each is: the players and officials, the crowd and the ground, the menus' music.
	var vols := HFlowContainer.new()
	vols.add_theme_constant_override("h_separation", 36)
	vols.add_theme_constant_override("v_separation", 14)
	for k in ["fx", "crowd", "music"]:
		vols.add_child(UI.field(tr({"fx": "VOL_EFFECTS", "crowd": "VOL_CROWD", "music": "MUSIC"}[k]), _volume(k)))
	snd[1].add_child(vols)
	# The match buttons: bigger, and where the thumb finds them (ui/button_layout.gd).
	snd[1].add_child(UI.field(tr("BUTTON_SIZE"), UI.chips([tr("SIZE_NORMAL"), tr("SIZE_LARGE"), tr("SIZE_XL")],
		int(Game.settings.btn_size), func(i):
			Game.settings.btn_size = i
			Game.save_settings())))
	var move := UI.button(tr("MOVE_BUTTONS"), false, func(): Game.show_screen("res://ui/button_layout.gd"))
	move.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	snd[1].add_child(move)

	# About: the version, the privacy policy and help (on the web, in the phone's browser), and the licences.
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


## What a frame rate choice means on this phone's screen (of HZ refreshes a second).
func _fps_text(opt: int, smooth: int, hz: int) -> String:
	match opt:
		Game.FPS_SAVER:
			return tr("FPS_NOTE_SAVER").format({"n": Game.saver_cap(hz)})
		Game.FPS_SMOOTH:
			return tr("FPS_NOTE_SMOOTH").format({"n": smooth, "hz": hz})
	return tr("FPS_NOTE_MAX").format({"hz": hz})


## A volume slider (0..100) for one of Sfx.BUSES: heard as it moves, kept when let go.
func _volume(key: String) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = int(Game.settings.get("vol_" + key, 100))
	s.custom_minimum_size = Vector2(240, 50)
	s.value_changed.connect(func(v):
		Game.settings["vol_" + key] = int(v)
		Sfx.apply_volumes())
	s.drag_ended.connect(func(_changed):
		Game.save_settings()
		if key == "fx":
			Sfx.click())
	return s


## On and Off side by side (on one line: under a short title like Sound they wrapped, Off below On).
func _toggle(key: String, title_key: String) -> VBoxContainer:
	return UI.field(tr(title_key), UI.chips_row([tr("ON"), tr("OFF")], 0 if Game.settings[key] else 1, func(i):
		Game.settings[key] = i == 0
		Game.save_settings()
		if key == "sound" and i == 1:
			Sfx.stop_all()
		if key in ["sound", "music"]:
			Sfx.music(true)))   # on again, or faded out if now off
