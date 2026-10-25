extends Control
## The home screen: a match playing behind it (Medium and High graphics; a still court on Low), the game's name in
## English and in Thai script (ตะกร้อ), the language, the modes as big tiles, and a card to carry on a season or
## tournament.

const ATTRACT := [["THA", "MAS", "dome"], ["SPB", "NPT", "national"], ["VIE", "INA", "mall"], ["KLC", "SLA", "provincial"],
	["JPN", "KOR", "beach"], ["PHI", "LAO", "temple"], ["MYA", "IND", "street"], ["ACR", "PRE", "park"]]

var _sv: SubViewport
var _match: Node = null
var _pick := 0
var _title: Label
var _cards: Array = []
var _picker: LanguagePicker = null
var _ver_taps := 0
var _ver_last := 0


func _ready() -> void:
	UI.screen(self, true)
	Sfx.stop_all()
	_pick = randi() % ATTRACT.size()
	if int(Game.settings.graphics) != Game.GFX_LOW:
		var svc := SubViewportContainer.new()
		svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		svc.stretch = true
		svc.stretch_shrink = 2 if int(Game.settings.graphics) == Game.GFX_MEDIUM else 1
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
	if _match and is_instance_valid(_match):
		_match.queue_free()
	var a: Array = ATTRACT[_pick % ATTRACT.size()]
	_pick += 1
	_match = (load("res://game/match.gd") as Script).new()
	_match.config = {"home": a[0], "away": a[1], "venue": a[2], "mode": "quick", "user_team": -1, "demo": true,
		"attract": true, "sets": 1, "points": 15, "difficulty": 2}
	_match.finished.connect(func(_r): _start_attract.call_deferred())
	_sv.add_child(_match)


func _shade() -> void:
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.set_color(0, Color(Game.C_BG, 0.92))
	g.set_color(1, Color(Game.C_BG, 0.4))
	g.add_point(0.4, Color(Game.C_BG, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_ui() -> void:
	var margin := UI.frame(self, 44)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	margin.add_child(row)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 0.8
	row.add_child(col)
	var lang_row := HBoxContainer.new()
	col.add_child(lang_row)
	var lang := _link(Game.language_names(Game.language())[0], "globe", _open_language, 48)
	lang_row.add_child(lang)
	_cards.append(lang)
	var tsize := int(clampf(get_viewport_rect().size.x * 0.066, 78.0, 116.0))
	_title = UI.label(tr("GAME_TITLE"), "TitleLabel", tsize)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_title.add_theme_constant_override("outline_size", 10)
	# The display font (with its fallbacks for every script) leaves a wide gap between lines: a wrapped name sits close.
	var fs := Game.ts(tsize)
	_title.add_theme_constant_override("line_spacing", -roundi(Game.font_display.get_height(fs) - fs * 0.9))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)
	# The sport's name in Thai, where the game was born; in Thailand, its Malay name instead.
	var native := UI.label("ตะกร้อ" if not TranslationServer.get_locale().begins_with("th") else "SEPAK TAKRAW", "TitleLabel", 56, Game.C_SAFFRON)
	col.add_child(native)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var cont := _continue_card()
	if cont:
		col.add_child(cont)
		_cards.append(cont)
	var links := HFlowContainer.new()
	links.add_theme_constant_override("h_separation", 12)
	links.add_theme_constant_override("v_separation", 10)
	for item in [["MENU_HOWTO", "book", "res://ui/howto_screen.gd"], ["MENU_SETTINGS", "gear", "res://ui/settings_screen.gd"],
			["MENU_RECORDS", "trophy", "res://ui/records_screen.gd"]]:
		var path: String = item[2]
		var b := _link(tr(item[0]), item[1], func(): _go(path), 68, 26)
		links.add_child(b)
		_cards.append(b)
	col.add_child(links)
	var ver := UI.label("v" + String(ProjectSettings.get_setting("application/config/version", "0.1")), "MutedLabel", 14)
	ver.mouse_filter = Control.MOUSE_FILTER_STOP
	ver.gui_input.connect(_on_version_input)
	col.add_child(ver)

	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 14)
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.size_flags_stretch_ratio = 1.25
	row.add_child(tiles)
	var hero := UI.tile(tr("MENU_QUICK"), tr("MENU_QUICK_DESC"), Game.C_SAFFRON, "", func(): _go("res://ui/quick_setup.gd"), true,
		"spike", UI.pill(tr("PLAY").to_upper(), Game.C_SAFFRON, true))
	hero.size_flags_stretch_ratio = 0.9
	tiles.add_child(hero)
	_cards.append(hero)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.add_child(stack)
	for md in [["MENU_SEASON", "MENU_SEASON_DESC", "res://ui/season_hub.gd", Game.C_GOOD, "serve"],
			["MENU_CUP", "MENU_CUP_DESC", "res://ui/cup_screen.gd", Color("5aa9ff"), "block"]]:
		var path2: String = md[2]
		var t := UI.tile(tr(md[0]), tr(md[1]), md[3], "", func(): Game.show_screen(path2), false, md[4])
		stack.add_child(t)
		_cards.append(t)


func _continue_card() -> Control:
	var what := ""
	var path := ""
	var team := ""
	var s = Game.get_season()
	if s != null and String(s.phase) != "done":
		what = s.short_stage()
		path = "res://ui/season_hub.gd"
		team = s.team
	else:
		var c = Game.get_cup()
		if c != null and String(c.stage) != "done":
			what = "%s\u00a0· %s" % [c.title(), c.stage_name()]
			path = "res://ui/cup_screen.gd"
			team = c.user
	if path == "":
		return null
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 84)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.88)
	sb.set_corner_radius_all(16)
	sb.border_color = Color(Game.C_GOLD, 0.5)
	sb.set_border_width_all(1)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Game.C_PANEL_HI
	sbh.border_color = Game.C_GOLD
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_right = -16
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cr := Crest.make(team, 46)
	cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cr)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UI.label(tr("CONTINUE").to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
	var w := UI.fit(UI.label(what, "SubLabel", 22), 2)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(w)
	h.add_child(v)
	# As tall as its two lines need.
	var grow := func():
		b.custom_minimum_size.y = maxf(84.0, h.get_combined_minimum_size().y + 12.0)
	h.minimum_size_changed.connect(grow)
	var ic := Icon.make("play", 28, Game.C_GOLD)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	b.add_child(h)
	b.pressed.connect(Sfx.click)
	b.pressed.connect(func(): _go(path))
	return b


func _link(text: String, icon_kind: String, cb: Callable, height := 54, text_size := 20) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, height)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.7)
	sb.set_corner_radius_all(999)
	sb.border_color = Color(1, 1, 1, 0.1)
	sb.set_border_width_all(1)
	sb.content_margin_left = 18
	sb.content_margin_right = 20
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Game.C_PANEL_HI
	sbh.border_color = Game.C_SAFFRON
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", roundi(text_size * 0.45))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := roundi(height * 0.36)
	h.offset_left = pad - 2
	h.offset_right = -pad
	var ic := Icon.make(icon_kind, roundi(text_size * 1.2), Game.C_SAFFRON)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := UI.label(text, "SubLabel", text_size)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	b.add_child(h)
	# The button as wide as its icon and words (in the font and size they are drawn in), with room either side.
	var widen := func(): b.custom_minimum_size.x = h.get_combined_minimum_size().x + pad * 2 - 2
	h.minimum_size_changed.connect(widen)
	widen.call()
	b.pressed.connect(Sfx.click)
	b.pressed.connect(cb)
	return b


func _go(path: String) -> void:
	Game.show_screen(path)


func _open_language() -> void:
	if _picker and is_instance_valid(_picker):
		return
	_picker = LanguagePicker.new()
	_picker.picked.connect(func(): Game.goto_menu.call_deferred())
	add_child(_picker)


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
