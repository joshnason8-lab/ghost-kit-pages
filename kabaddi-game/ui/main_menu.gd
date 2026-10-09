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
	# Darken the left so the title reads, lightly everywhere else so the tiles do.
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.set_color(0, Color(Game.C_BG, 0.92))
	g.set_color(1, Color(Game.C_BG, 0.45))
	g.add_point(0.38, Color(Game.C_BG, 0.55))
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
	var margin := UI.frame(self, 44)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	margin.add_child(row)

	# Left: the title, and the small links at the foot.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 0.8
	row.add_child(col)
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, 18)
	col.add_child(top)
	col.add_child(UI.label(tr("LEAGUE_NAME").to_upper() + "  ·  " + tr("MENU_CUP").to_upper(), "EyebrowLabel", 16, Game.C_SAFFRON))
	_title = UI.label(tr("GAME_TITLE"), "TitleLabel", 112)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_constant_override("line_spacing", -30)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)
	_hi = UI.label("कबड्डी", "TitleLabel", 64, Game.C_SAFFRON)
	if TranslationServer.get_locale().begins_with("hi") or TranslationServer.get_locale().begins_with("mr"):
		_hi.text = "KABADDI"
	col.add_child(_hi)
	col.add_child(UI.label(tr("TAGLINE"), "SubLabel", 26, Game.C_GOLD))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var cont := _continue_card()
	if cont:
		col.add_child(cont)
		_cards.append(cont)
	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", 12)
	for item in [["MENU_HOWTO", "book", "res://ui/howto_screen.gd"], ["MENU_SETTINGS", "gear", "res://ui/settings_screen.gd"]]:
		var path: String = item[2]
		var b := _link(tr(item[0]), item[1], func(): _go(path))
		links.add_child(b)
		_cards.append(b)
	col.add_child(links)
	var ver := UI.label("v" + String(ProjectSettings.get_setting("application/config/version", "0.1")), "MutedLabel", 14)
	col.add_child(ver)

	# Right: the modes, as big tiles.
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 14)
	tiles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.size_flags_stretch_ratio = 1.25
	row.add_child(tiles)
	var hero := UI.tile(tr("MENU_QUICK"), tr("MENU_QUICK_DESC"), Game.C_SAFFRON, "quick", func(): _go("res://ui/quick_setup.gd"), true)
	var play_tag := UI.pill(tr("PLAY").to_upper(), Game.C_SAFFRON, true)
	play_tag.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	play_tag.position = Vector2(64, -52)
	hero.add_child(play_tag)
	hero.size_flags_stretch_ratio = 0.9
	tiles.add_child(hero)
	_cards.append(hero)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles.add_child(stack)
	for md in [["MENU_SEASON", "MENU_SEASON_DESC", "res://ui/season_hub.gd", Game.C_GOOD, "league"],
			["MENU_CUP", "MENU_CUP_DESC", "res://ui/cup_screen.gd", Color("5aa9ff"), "cup"],
			["MENU_TRAINING", "TRAINING_EYEBROW", "res://ui/tutorial_menu.gd", Game.C_MAGENTA.lightened(0.1), "dubki"]]:
		var path2: String = md[2]
		var t := UI.tile(tr(md[0]), tr(md[1]), md[3], md[4], func(): _go(path2))
		stack.add_child(t)
		_cards.append(t)


## Pick up where you left off: a season or cup in progress.
func _continue_card() -> Control:
	var what := ""
	var path := ""
	var team := ""
	var s = Game.get_season()
	if s != null and String(s.phase) != "done":
		what = "%s · %s" % [tr("MENU_SEASON"), tr("SEASON").format({"n": s.year})]
		path = "res://ui/season_hub.gd"
		team = s.team
	else:
		var c = Game.get_cup()
		if c != null and String(c.stage) != "done":
			what = "%s · %s" % [tr("MENU_CUP"), c.stage_name()]
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
	v.add_child(UI.label(what, "SubLabel", 22))
	h.add_child(v)
	var ic := Icon.make("play", 28, Game.C_GOLD)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	b.add_child(h)
	b.pressed.connect(Sfx.click)
	b.pressed.connect(func(): _go(path))
	return b


## A quiet text link with an icon, for How to play and Settings.
func _link(text: String, icon_kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 54)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.75)
	sb.set_corner_radius_all(99)
	sb.content_margin_left = 54
	sb.content_margin_right = 22
	sb.border_color = Color(1, 1, 1, 0.1)
	sb.set_border_width_all(1)
	var sbh: StyleBoxFlat = sb.duplicate()
	sbh.bg_color = Game.C_PANEL_HI
	sbh.border_color = Game.C_SAFFRON
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.text = text
	var ic = Icon.make(icon_kind, 26, Game.C_GOLD)
	ic.position = Vector2(18, 14)
	ic.size = Vector2(26, 26)
	b.add_child(ic)
	b.pressed.connect(Sfx.click)
	b.pressed.connect(cb)
	return b


func _go(path: String) -> void:
	if _match and is_instance_valid(_match):
		_match.queue_free()
		_match = null
	Sfx.stop_all()
	Game.show_screen(path)


func _animate_in() -> void:
	_title.pivot_offset = Vector2(0, 70)
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
