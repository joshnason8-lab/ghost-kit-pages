extends Control
## The home screen. Behind it the AI plays a match on one of the grounds. Over it the game's name with the sport's
## name in Devanagari (खो-खो), the language button (a globe), and the menu: one row of buttons along the bottom. A
## card carries on a championship in progress.

const ATTRACT := [["MAH", "ODI", "maidan", 0], ["IND", "NEP", "arena", 1], ["KAR", "KER", "floodlit", 0], ["RSA", "SRI", "arena", 1],
	["TEL", "DEL", "school", 0], ["BAN", "ENG", "floodlit", 1], ["WBE", "GUJ", "maidan", 0], ["KEN", "IRN", "arena", 1]]

const ITEMS := [
	["quick", "MENU_QUICK", "play"],
	["cup", "MENU_CUP", "trophy"],
	["watch", "MENU_WATCH", "camera"],
	["howto", "MENU_HOWTO", "book"],
	["records", "MENU_RECORDS", "star"],
	["settings", "MENU_SETTINGS", "gear"],
]

var _sv: SubViewport
var _match: Node = null
var _pick := 0
var _picker: LanguagePicker = null
var _row: HBoxContainer
var _fade: Array = []


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self, true)
	Sfx.stop_all()
	_pick = randi() % ATTRACT.size()
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	# A smaller picture behind the menu on Low and Medium: it is only a backdrop.
	svc.stretch_shrink = 2 if int(Game.settings.graphics) <= Game.GFX_MEDIUM else 1
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
	_match.config = {"home": a[0], "away": a[1], "venue": a[2], "format": a[3], "mode": "quick", "user_team": -1,
		"attract": true, "turn_len": 150.0, "difficulty": 2, "seed": randi()}
	_match.finished.connect(func(_r): _start_attract.call_deferred())
	_sv.add_child(_match)


func _shade() -> void:
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.set_color(0, Color(Game.C_BG, 0.85))
	g.set_color(1, Color(Game.C_BG, 0.25))
	g.add_point(0.55, Color(Game.C_BG, 0.35))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0.6, 0.6)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_ui() -> void:
	var margin := UI.frame(self, 36)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	margin.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	col.add_child(top)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", -10)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(head)
	var tsize := int(clampf(get_viewport_rect().size.x * 0.064, 70.0, 104.0))
	var title := UI.label(tr("GAME_TITLE"), "TitleLabel", tsize)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	title.add_theme_constant_override("outline_size", 10)
	UI.fit(title)
	head.add_child(title)
	var native := UI.label("खो-खो", "TitleLabel", 44, Game.C_SAFFRON)
	head.add_child(native)
	var tag := UI.label(tr("TAGLINE"), "SubLabel", 22, Game.C_GOLD)
	UI.fit(tag)
	head.add_child(tag)
	_fade.append(head)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_child(right)
	var lang := _pill(Game.language_names(Game.language())[0], "globe", _open_language)
	lang.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(lang)
	_fade.append(lang)
	var cont := _continue_card()
	if cont:
		right.add_child(cont)
		_fade.append(cont)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 12)
	for it in ITEMS:
		_row.add_child(_menu_button(String(it[0]), tr(String(it[1])), String(it[2])))
	col.add_child(_row)
	_fade.append(_row)
	var ver := UI.label("v" + String(ProjectSettings.get_setting("application/config/version", "0.1")), "MutedLabel", 13)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(ver)


func _on_pick(id: String) -> void:
	match id:
		"quick":
			Game.show_screen("res://ui/match_setup.gd")
		"cup":
			Game.show_screen("res://ui/cup_screen.gd")
		"watch":
			Game.show_screen("res://ui/match_setup.gd", {"watch": true})
		"howto":
			Game.show_screen("res://ui/howto_screen.gd")
		"records":
			Game.show_screen("res://ui/records_screen.gd")
		"settings":
			Game.show_screen("res://ui/settings_screen.gd")


## A menu button: the icon over the words, all six the same width in one row.
func _menu_button(id: String, text: String, icon_kind: String) -> Button:
	var b := Button.new()
	b.name = id
	b.theme_type_variation = "LaneButton"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 104)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Icon.make(icon_kind, 30, Game.C_SAFFRON)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := UI.label(text, "SubLabel", 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fit(l, 2)
	v.add_child(l)
	b.add_child(v)
	b.pressed.connect(Sfx.click)
	b.pressed.connect(_on_pick.bind(id))
	return b


func _continue_card() -> Control:
	var c = Game.get_cup()
	if c == null or String(c.stage) == "done" or String(c.stage) == "out":
		return null
	var b := Button.new()
	b.theme_type_variation = "LaneButton"
	b.custom_minimum_size = Vector2(300, 70)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -12
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cr := Crest.make(c.user, 40)
	cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cr)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var e := UI.label(tr("CONTINUE").to_upper(), "EyebrowLabel", 13, Game.C_GOLD)
	UI.fit(e)
	v.add_child(e)
	var w := UI.fit(UI.label("%s · %s" % [c.title(), c.stage_name()], "SubLabel", 19), 2)
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(w)
	h.add_child(v)
	b.add_child(h)
	var grow := func():
		b.custom_minimum_size.y = maxf(70.0, h.get_combined_minimum_size().y + 10.0)
	h.minimum_size_changed.connect(grow)
	b.pressed.connect(Sfx.click)
	b.pressed.connect(func(): Game.show_screen("res://ui/cup_screen.gd"))
	return b


func _pill(text: String, icon_kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "LaneButton"
	b.custom_minimum_size = Vector2(0, 54)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -16
	var ic := Icon.make(icon_kind, 24, Game.C_SAFFRON)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := UI.label(text, "SubLabel", 20)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(l)
	b.add_child(h)
	b.custom_minimum_size.x = 14 + 24 + 10 + Game.font_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Game.ts(20)).x + 32
	b.pressed.connect(Sfx.click)
	b.pressed.connect(cb)
	return b


func _open_language() -> void:
	if _picker and is_instance_valid(_picker):
		return
	_picker = LanguagePicker.new()
	_picker.picked.connect(func(): Game.goto_menu.call_deferred())
	add_child(_picker)


func _animate_in() -> void:
	for i in _fade.size():
		var c: Control = _fade[i]
		c.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.06 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.3)
