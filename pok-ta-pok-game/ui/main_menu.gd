extends Control
## The home screen: a carved limestone stela. Its top carries the game's name; below, the ways to play are its glyph
## blocks, set in pairs of columns and read left to right, top to bottom, as Maya inscriptions are read. Each block
## is a cartouche with a sign drawn in code and its words under it. A stepped fret runs round the stone's edge. Behind
## it, on Medium and High graphics, a match goes on at the court (on Low, a still evening over a village court). The
## globe at the top changes the language; seven taps on the version, the developer's overlay.

const ATTRACT := [["ESC", "LLA", "village"], ["PIS", "VAL", "stone"], ["SAV", "QUE", "festival"], ["FLO", "COP", "night"],
	["VUN", "ROS", "village"], ["ORW", "PAL", "stone"]]

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
		"difficulty": 2, "length": 0}
	_sv.add_child(_match)


func _shade() -> void:
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.set_color(0, Color(Game.C_BG, 0.9))
	g.set_color(1, Color(Game.C_BG, 0.25))
	g.add_point(0.5, Color(Game.C_BG, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_ui() -> void:
	var margin := UI.frame(self, 30)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	var stela := Stela.new()
	stela.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stela.size_flags_stretch_ratio = 1.15
	stela.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(stela)
	var inner := MarginContainer.new()
	for k in ["margin_left", "margin_right"]:
		inner.add_theme_constant_override(k, 34)
	inner.add_theme_constant_override("margin_top", 22)
	inner.add_theme_constant_override("margin_bottom", 22)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stela.add_child(inner)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	inner.add_child(col)
	var title := UI.label(tr("GAME_TITLE").to_upper(), "LogoLabel", 60, Game.C_PRINT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 0)
	UI.shrink(title, 60, 0.6, 1)
	col.add_child(title)
	var tag := UI.label(tr("TAGLINE"), "SubLabel", 19, Color(Game.C_PRINT, 0.8))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(tag, 2)
	col.add_child(tag)
	# The glyph blocks, two columns.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(grid)
	var cup = Game.get_cup()
	var items := []
	if cup != null and not cup.done() and not cup.out:
		items.append(["continue", tr("MENU_CONTINUE"), Plural.word("CUP_STAGE_LINE", 1).format({"stage": tr(cup.stage_key())}), func(): Game.show_screen("res://ui/cup_screen.gd"), true])
	items.append(["play", tr("MENU_QUICK"), tr("MENU_QUICK_DESC"), func(): Game.show_screen("res://ui/quick_setup.gd"), items.is_empty()])
	items.append(["trophy", tr("MENU_CUP"), tr("MENU_CUP_DESC"), func(): Game.show_screen("res://ui/cup_screen.gd"), false])
	items.append(["eye", tr("MENU_WATCH"), tr("MENU_WATCH_DESC"), func(): Game.show_screen("res://ui/quick_setup.gd", {"watch": true}), false])
	items.append(["book", tr("MENU_HOWTO"), tr("MENU_HOWTO_DESC"), func(): Game.show_screen("res://ui/howto_screen.gd"), false])
	items.append(["gear", tr("MENU_SETTINGS"), tr("MENU_SETTINGS_DESC"), func(): Game.show_screen("res://ui/settings_screen.gd"), false])
	if items.size() % 2 == 1:
		items.insert(0, null)
		items.remove_at(0)
	for it in items:
		var b := _glyph(it[0], it[1], it[2], it[3], it[4])
		grid.add_child(b)
		_cards.append(b)
	# The right: the globe over the match, and the version.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(top)
	var lang := _lang_button()
	top.add_child(lang)
	_cards.append(lang)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(spacer)
	# The note and the version on a dark glass card, so they read over the match.
	var card := UI.card("GlassPanel")
	card.size_flags_horizontal = Control.SIZE_SHRINK_END
	card.custom_minimum_size = Vector2(300, 0)
	right.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	card.add_child(cv)
	var foot := UI.label(tr("MENU_FOOT"), "MutedLabel", 15, Game.C_INK)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.custom_minimum_size = Vector2(300, 0)
	UI.fit(foot, 3)
	cv.add_child(foot)
	var ver := UI.label("v" + String(ProjectSettings.get_setting("application/config/version", "0.1")), "MutedLabel", 15)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.mouse_filter = Control.MOUSE_FILTER_STOP
	ver.gui_input.connect(_on_version_input)
	cv.add_child(ver)


## A glyph block: a squared cartouche cut into the stone, its sign above its words.
func _glyph(kind: String, title: String, desc: String, cb: Callable, lit: bool) -> Button:
	var b := Button.new()
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 92)
	var stone := Color("cdbd9c") if not lit else Color("e2c98c")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(stone, 0.92)
	sb.set_corner_radius_all(22)
	sb.border_color = Color(Game.C_PRINT, 0.55)
	sb.set_border_width_all(3)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = stone.lightened(0.12)
	sbh.border_color = Game.C_MAGENTA
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb if Game.touch_ui else sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(k, 14)
	for k in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(k, 8)
	b.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(h)
	var ic := Icon.make(kind, 46, Game.C_PRINT if not lit else Game.C_MAGENTA)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var t := UI.label(title, "HeaderLabel", 26, Game.C_PRINT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fit(t, 2)
	v.add_child(t)
	var d := UI.label(desc, "", 15, Color(Game.C_PRINT, 0.78))
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fit(d, 2)
	v.add_child(d)
	var grow := func():
		b.custom_minimum_size.y = maxf(92.0, m.get_combined_minimum_size().y)
	m.minimum_size_changed.connect(grow)
	b.pressed.connect(func():
		Sfx.click()
		cb.call())
	return b


func _lang_button() -> Button:
	var b := Button.new()
	b.text = Game.language_names(Game.language())[0]
	b.icon = null
	b.custom_minimum_size = Vector2(0, 54)
	var ic := Icon.make("globe", 26, Game.C_SAFFRON)
	ic.position = Vector2(14, 14)
	ic.size = Vector2(26, 26)
	b.add_child(ic)
	b.add_theme_constant_override("h_separation", 8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.85)
	sb.set_corner_radius_all(999)
	sb.border_color = Color(1, 1, 1, 0.16)
	sb.set_border_width_all(1)
	sb.content_margin_left = 50
	sb.content_margin_right = 20
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Sfx.click()
		_open_language())
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
		tw.tween_interval(0.05 * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.3)


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


## The stela itself: limestone, lit from above, a stepped fret carved round its edge, weathered.
class Stela:
	extends Control

	static var _tex: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
		if _tex == null and ResourceLoader.exists("res://assets/env/surfaces/sandstone_blocks_albedo_512.jpg"):
			_tex = load("res://assets/env/surfaces/broken_wall_albedo_512.jpg")

	func _draw() -> void:
		var s := size
		var r := Rect2(Vector2.ZERO, s)
		# The stone: a pale limestone slab, its photographed grain faint under a warm wash.
		draw_rect(r, Color("d9c9a6"))
		if _tex:
			draw_texture_rect(_tex, r, true, Color(1.0, 0.96, 0.88, 0.35))
		var g := Gradient.new()
		g.set_color(0, Color(1, 0.95, 0.85, 0.25))
		g.set_color(1, Color(0.25, 0.18, 0.1, 0.35))
		# The fret: a band of stepped hooks round the edge, cut in (dark) with a lit edge.
		var band := 14.0
		var ink := Color(0.24, 0.17, 0.11, 0.75)
		var lit := Color(1, 0.97, 0.88, 0.5)
		draw_rect(Rect2(Vector2(band, band), s - Vector2(band, band) * 2.0), ink, false, 2.0)
		draw_rect(Rect2(Vector2(4, 4), s - Vector2(8, 8)), ink, false, 2.0)
		var step := 28.0
		var x := band + 6.0
		while x + step < s.x - band:
			_fret(Vector2(x, 4), step, band - 4, ink, lit, false)
			_fret(Vector2(x, s.y - band), step, band - 4, ink, lit, true)
			x += step
		var y := band + 6.0
		while y + step < s.y - band:
			_fret_v(Vector2(4, y), step, band - 4, ink)
			_fret_v(Vector2(s.x - band, y), step, band - 4, ink)
			y += step
		# A shadow at the bottom: it stands on the ground.
		draw_rect(Rect2(0, s.y - 5, s.x, 5), Color(0, 0, 0, 0.25))

	## One stepped hook (the xicalcoliuhqui motif shared across Mesoamerica): steps up, then a curl.
	func _fret(at: Vector2, w: float, h: float, ink: Color, _lit: Color, flip: bool) -> void:
		var k := -1.0 if flip else 1.0
		var base := at.y + (h if not flip else 0.0)
		var pts := PackedVector2Array([
			Vector2(at.x, base), Vector2(at.x, base - k * h * 0.33), Vector2(at.x + w * 0.2, base - k * h * 0.33),
			Vector2(at.x + w * 0.2, base - k * h * 0.66), Vector2(at.x + w * 0.4, base - k * h * 0.66),
			Vector2(at.x + w * 0.4, base - k * h), Vector2(at.x + w * 0.85, base - k * h),
			Vector2(at.x + w * 0.85, base - k * h * 0.3), Vector2(at.x + w * 0.6, base - k * h * 0.3),
			Vector2(at.x + w * 0.6, base - k * h * 0.6)])
		draw_polyline(pts, ink, 2.0, true)

	func _fret_v(at: Vector2, h: float, w: float, ink: Color) -> void:
		var pts := PackedVector2Array([
			Vector2(at.x, at.y), Vector2(at.x + w * 0.33, at.y), Vector2(at.x + w * 0.33, at.y + h * 0.2),
			Vector2(at.x + w * 0.66, at.y + h * 0.2), Vector2(at.x + w * 0.66, at.y + h * 0.4),
			Vector2(at.x + w, at.y + h * 0.4), Vector2(at.x + w, at.y + h * 0.85), Vector2(at.x + w * 0.3, at.y + h * 0.85),
			Vector2(at.x + w * 0.3, at.y + h * 0.6), Vector2(at.x + w * 0.6, at.y + h * 0.6)])
		draw_polyline(pts, ink, 2.0, true)
