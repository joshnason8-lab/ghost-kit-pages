extends Control
## Title screen. A real AI match plays behind the menu from the broadcast camera, the title
## slams in, and the modes slide up.

const ATTRACT_PAIRS := [["MUM", "CHD"], ["IND", "IRN"], ["PAT", "BLR"], ["KOL", "JAI"], ["KOR", "PAK"]]
const ATTRACT_GROUNDS := ["dome", "stadium", "village", "monsoon", "beach"]

var _sv: SubViewport
var _match: Node = null
var _pick := 0
var _title: Label
var _hi: Label
var _cards: Array = []
var _t := 0.0


func _ready() -> void:
	UI.screen(self, true)
	Sfx.stop_all()
	_pick = randi() % ATTRACT_PAIRS.size()
	if int(Game.settings.graphics) != Game.GFX_LOW:
		var svc := SubViewportContainer.new()
		svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		svc.stretch = true
		svc.stretch_shrink = 2 if int(Game.settings.graphics) == Game.GFX_MEDIUM else 1
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(svc)
		_sv = SubViewport.new()
		_sv.own_world_3d = true
		svc.add_child(_sv)
		_start_attract()
	_shade()
	_build_ui()
	_animate_in()
	Sfx.crowd(0.3)


func _start_attract() -> void:
	if _match and is_instance_valid(_match):
		_match.queue_free()
	var pair: Array = ATTRACT_PAIRS[_pick % ATTRACT_PAIRS.size()]
	var ground: String = ATTRACT_GROUNDS[_pick % ATTRACT_GROUNDS.size()]
	_pick += 1
	var s: Script = load("res://game/match.gd")
	_match = s.new()
	_match.config = {"home": pair[0], "away": pair[1], "arena": ground, "mode": "quick", "autoplay": true,
		"attract": true, "length": 0, "difficulty": 2}
	_match.finished.connect(func(_r): _start_attract.call_deferred())
	_sv.add_child(_match)


func _shade() -> void:
	# Darken the left so the menu reads, and the bottom for the footer.
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.set_color(0, Color(Game.C_BG, 0.95))
	g.set_color(1, Color(Game.C_BG, 0.05))
	g.add_point(0.42, Color(Game.C_BG, 0.78))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.add_theme_constant_override("margin_right", 40)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(560, 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(col)

	col.add_child(UI.label(tr("LEAGUE_NAME").to_upper() + "  ·  " + tr("MENU_CUP").to_upper(), "EyebrowLabel"))
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 18)
	_title = UI.label(tr("GAME_TITLE"), "TitleLabel", 100)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_title.add_theme_constant_override("outline_size", 10)
	title_row.add_child(_title)
	_hi = UI.label("कबड्डी", "TitleLabel", 54, Game.C_SAFFRON)
	_hi.size_flags_vertical = Control.SIZE_SHRINK_END
	if TranslationServer.get_locale().begins_with("hi") or TranslationServer.get_locale().begins_with("mr"):
		_hi.text = "KABADDI"
	title_row.add_child(_hi)
	col.add_child(title_row)
	col.add_child(UI.label(tr("TAGLINE"), "SubLabel", 24, Game.C_GOLD))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	col.add_child(gap)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	var modes := [
		["MENU_QUICK", "MENU_QUICK_DESC", "res://ui/quick_setup.gd", Game.C_SAFFRON],
		["MENU_SEASON", "MENU_SEASON_DESC", "res://ui/season_hub.gd", Game.C_GOOD],
		["MENU_CUP", "MENU_CUP_DESC", "res://ui/cup_screen.gd", Color("5aa9ff")],
		["MENU_CAREER", "MENU_CAREER_DESC", "res://ui/career_hub.gd", Game.C_MAGENTA],
	]
	for md in modes:
		var c := _mode_card(md[0], md[1], md[2], md[3])
		grid.add_child(c)
		_cards.append(c)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for item in [["MENU_TRAINING", "res://ui/tutorial_menu.gd"], ["MENU_SETTINGS", "res://ui/settings_screen.gd"], ["MENU_HOWTO", "res://ui/howto_screen.gd"]]:
		var path: String = item[1]
		var b := UI.button(tr(item[0]), false, func(): _go(path))
		b.custom_minimum_size = Vector2(178, 54)
		row.add_child(b)
		_cards.append(b)
	col.add_child(row)

	var note := UI.label("v" + String(ProjectSettings.get_setting("application/config/version", "0.1")), "MutedLabel", 15)
	note.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	note.position = Vector2(-90, -34)
	add_child(note)


func _go(path: String) -> void:
	if _match and is_instance_valid(_match):
		_match.queue_free()
		_match = null
	Sfx.stop_all()
	Game.show_screen(path)


func _mode_card(title_key: String, desc_key: String, path: String, accent: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(274, 118)
	b.pressed.connect(Sfx.click)
	b.pressed.connect(func(): _go(path))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.88)
	sb.border_color = accent
	sb.border_width_top = 4
	sb.set_corner_radius_all(12)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Color(Game.C_PANEL_HI, 0.95)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_top = 6
	v.offset_bottom = -6
	v.offset_right = -12
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UI.label(tr(title_key), "HeaderLabel", 33)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d := UI.label(tr(desc_key), "MutedLabel", 15)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	v.add_child(d)
	b.add_child(v)
	return b


func _animate_in() -> void:
	_title.pivot_offset = Vector2(0, 60)
	_title.scale = Vector2(1.6, 1.6)
	_title.modulate.a = 0.0
	_hi.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hi, "modulate:a", 1.0, 0.4)
	for i in _cards.size():
		var c: Control = _cards[i]
		c.modulate.a = 0.0
		var tc := create_tween()
		tc.tween_interval(0.25 + i * 0.07)
		tc.tween_property(c, "modulate:a", 1.0, 0.3)


func _process(delta: float) -> void:
	_t += delta
	if _hi:
		_hi.modulate = Color(1, 1, 1, _hi.modulate.a).lerp(Color(1.25, 1.1, 0.9, _hi.modulate.a), 0.5 + 0.5 * sin(_t * 2.6))
