extends Control
## The home screen: a match day's printed programme. On the left its cover (the masthead, the game's name, the
## hurler striking under a setting sun); on the right its contents page, the ways to play listed as a programme
## lists the day's games. Behind it, on Medium and High graphics, a match at the parish field at dusk (on Low, a
## still picture of it). The globe at the top changes the language.

const ATTRACT := [["KIL", "TIP", "parish"], ["COR", "LIM", "county"], ["GAL", "CLA", "parish"], ["WAT", "DUB", "night"],
	["WEX", "OFF", "parish"], ["ANT", "LAO", "county"]]

var _sv: SubViewport
var _match: Node = null
var _pick := 0
var _cards: Array = []
var _picker: LanguagePicker = null
var _ver_taps := 0
var _ver_last := 0


func _ready() -> void:
	UI.screen(self, int(Game.settings.graphics) == Game.GFX_LOW)
	_pick = randi() % ATTRACT.size()
	if int(Game.settings.graphics) != Game.GFX_LOW:
		var svc := SubViewportContainer.new()
		svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		svc.stretch = true
		svc.stretch_shrink = 2
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(svc)
		_sv = SubViewport.new()
		_sv.own_world_3d = true
		_sv.audio_listener_enable_3d = false
		svc.add_child(_sv)
		_start_attract()
	_shade()
	_build_ui()
	if Game.loading:
		Game.loaded.connect(_animate_in, CONNECT_ONE_SHOT)
	else:
		_animate_in()


func _start_attract() -> void:
	var a: Array = ATTRACT[_pick % ATTRACT.size()]
	_pick += 1
	_match = (load("res://game/match.gd") as Script).new()
	_match.config = {"home": a[0], "away": a[1], "venue": a[2], "mode": "attract", "user_team": -1, "attract": true,
		"difficulty": 2, "length": 35}
	_sv.add_child(_match)


func _shade() -> void:
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.set_color(0, Color(Game.C_BG, 0.86))
	g.set_color(1, Color(Game.C_BG, 0.55))
	g.add_point(0.45, Color(Game.C_BG, 0.35))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_ui() -> void:
	var margin := UI.frame(self, 36)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	margin.add_child(row)
	row.add_child(_cover())
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	# The top line: the language, on the right.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(top)
	var lang := _lang_button()
	top.add_child(lang)
	_cards.append(lang)
	var rule := ColorRect.new()
	rule.color = Color(Game.C_GOLD, 0.5)
	rule.custom_minimum_size = Vector2(0, 2)
	right.add_child(rule)
	var cont := _continue_row()
	var items := [
		# The first row is lit: Continue when a championship is under way, else Throw-in.
		["1", tr("MENU_QUICK"), tr("MENU_QUICK_DESC"), func(): Game.show_screen("res://ui/quick_setup.gd"), cont == null],
		["2", tr("MENU_CHAMP"), tr("MENU_CHAMP_DESC"), func(): Game.show_screen("res://ui/champ_screen.gd"), false],
		["3", tr("MENU_WATCH"), tr("MENU_WATCH_DESC"), func(): Game.show_screen("res://ui/quick_setup.gd", {"watch": true}), false],
		["4", tr("MENU_PRACTICE"), tr("MENU_PRACTICE_DESC"), func(): Game.show_screen("res://ui/practice_screen.gd"), false],
		["5", tr("MENU_HOWTO"), tr("MENU_HOWTO_DESC"), func(): Game.show_screen("res://ui/howto_screen.gd"), false],
		["6", tr("MENU_SETTINGS"), tr("MENU_SETTINGS_DESC"), func(): Game.show_screen("res://ui/settings_screen.gd"), false],
	]
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(list)
	if cont != null:
		list.add_child(cont)
		_cards.append(cont)
	for it in items:
		var r := _row(it[0], it[1], it[2], it[3], it[4])
		list.add_child(r)
		_cards.append(r)
	var foot := HBoxContainer.new()
	right.add_child(foot)
	foot.alignment = BoxContainer.ALIGNMENT_END
	var ver := UI.label("v" + String(ProjectSettings.get_setting("application/config/version", "0.1")), "MutedLabel", 15)
	ver.mouse_filter = Control.MOUSE_FILTER_STOP
	ver.gui_input.connect(_on_version_input)
	foot.add_child(ver)


## The programme's cover, printed on cream paper: the masthead, the picture with the name over it.
func _cover() -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Game.C_PAPER
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(6, 8)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(clampf(get_viewport_rect().size.x * 0.34, 360.0, 470.0), 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	# The masthead: a red band, the programme's name in Irish and English.
	var band := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Game.C_MAGENTA
	bsb.content_margin_left = 18
	bsb.content_margin_right = 18
	bsb.content_margin_top = 8
	bsb.content_margin_bottom = 8
	band.add_theme_stylebox_override("panel", bsb)
	v.add_child(band)
	var bl := UI.label(tr("PROGRAMME").to_upper(), "EyebrowLabel", 16, Game.C_PAPER)
	UI.fit(bl, 1)
	band.add_child(bl)
	# The cover picture (the owner's artwork: a hurler in green striking at dusk), the game's name over its pale sky.
	var pic := Control.new()
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.custom_minimum_size = Vector2(0, 220)
	pic.clip_contents = true
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)
	var tex := TextureRect.new()
	tex.texture = load("res://assets/art/cover.jpg")
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.add_child(tex)
	var iv := VBoxContainer.new()
	iv.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	iv.offset_left = 16
	iv.offset_right = -16
	iv.offset_top = 10
	iv.add_theme_constant_override("separation", 0)
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.add_child(iv)
	var title := UI.label(tr("GAME_TITLE").to_upper(), "LogoLabel", 58, Game.C_PRINT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.shrink(title, 58, 0.6, 1)
	iv.add_child(title)
	var tag := UI.label(tr("TAGLINE"), "SubLabel", 19, Color(Game.C_PRINT, 0.8))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(tag, 2)
	iv.add_child(tag)
	_cards.append(card)
	return card


## A line of the contents: its number in the display face, the title and a line about it; the first one picked out.
func _row(num: String, title: String, desc: String, cb: Callable, lead := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 74)
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.78) if not lead else Color(Game.C_SAFFRON, 0.95)
	sb.set_corner_radius_all(6)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.border_width_bottom = 2
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Game.C_PANEL_HI if not lead else Game.C_SAFFRON.lightened(0.1)
	sbh.border_color = Game.C_GOLD
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var ink := Color("1d1307") if lead else Game.C_INK
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_right = -16
	h.add_theme_constant_override("separation", 16)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := UI.label(num, "ScoreLabel", 38, ink if lead else Game.C_GOLD)
	n.custom_minimum_size = Vector2(30, 0)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(n)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UI.label(title, "HeaderLabel", 30, ink)
	UI.shrink(t, 30, 0.7, 1)
	col.add_child(t)
	var d := UI.label(desc, "MutedLabel", 16, Color(ink, 0.75) if lead else Game.C_MUTED)
	UI.fit(d, 2)
	col.add_child(d)
	h.add_child(col)
	var ic := Icon.make("play", 24, ink if lead else Game.C_GOLD)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	b.add_child(h)
	var grow := func():
		b.custom_minimum_size.y = maxf(74.0, h.get_combined_minimum_size().y + 10.0)
	h.minimum_size_changed.connect(grow)
	b.pressed.connect(Sfx.click)
	b.pressed.connect(cb)
	return b


func _continue_row() -> Control:
	var c = Game.get_champ()
	if c == null or String(c.phase) == "done":
		return null
	var f: Dictionary = c.next_fixture()
	var what := tr(c.name_key())
	if not f.is_empty():
		what += " · " + tr(String(f.stage)) + " · " + DB.team_name(String(f.home)) + " " + tr("VS") + " " + DB.team_name(String(f.away))
	# A match left part-way: Continue carries on with it, from the minute it was left.
	var snap := Game.suspended_for(f)
	if not snap.is_empty():
		var sc: Array = snap.score
		what = tr("RESUME_LINE").format({"home": DB.short_name(String(f.home)), "away": DB.short_name(String(f.away)),
			"a": Rules.fmt(int(sc[0][0]), int(sc[0][1])), "b": Rules.fmt(int(sc[1][0]), int(sc[1][1])), "min": int(snap.get("minute", 0))})
		return _row("»", tr("CONTINUE"), what, func(): Game.resume_match(snap), true)
	return _row("»", tr("CONTINUE"), what, func(): Game.show_screen("res://ui/champ_screen.gd"), true)


func _lang_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 50)
	var name: String = Game.language_names(Game.language())[0]
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -14
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Icon.make("globe", 24, Game.C_SAFFRON)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := UI.label(name, "SubLabel", 19)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	b.add_child(h)
	b.custom_minimum_size.x = 12 + 24 + 8 + Game.font_bold.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, Game.ts(19)).x + 26
	b.pressed.connect(Sfx.click)
	b.pressed.connect(_open_language)
	return b


func _open_language() -> void:
	if _picker and is_instance_valid(_picker):
		return
	_picker = LanguagePicker.new()
	_picker.picked.connect(func(): Game.goto_menu.call_deferred())
	add_child(_picker)


## Back on the home screen closes the language picker if it is open (Game.go_back); else it quits.
func close_overlay() -> bool:
	if _picker and is_instance_valid(_picker):
		_picker.close()
		return true
	return false


func _animate_in() -> void:
	for i in _cards.size():
		var c: Control = _cards[i]
		c.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.04 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.25)


## Seven taps on the version turn the developer's overlay on or off.
func _on_version_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		var now := Time.get_ticks_msec()
		_ver_taps = _ver_taps + 1 if now - _ver_last < 600 else 1
		_ver_last = now
		if _ver_taps >= 7:
			_ver_taps = 0
			Game.settings.dev = not bool(Game.settings.dev)
			Game.save_settings()
			Sfx.click()
