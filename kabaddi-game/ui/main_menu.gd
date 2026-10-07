extends Control
## Title screen over a live 3D court.

var _cam: Camera3D
var _t := 0.0
var _showcase: Array = []


func _ready() -> void:
	UI.screen(self, true)
	Sfx.stop_all()
	_build_showcase()
	_build_ui()


func _build_showcase() -> void:
	if int(Game.settings.graphics) == Game.GFX_LOW:
		return
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.stretch_shrink = 1
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_2X
	svc.add_child(sv)
	var home := DB.team("MUM")
	var away := DB.team("CHD")
	var arena := Arena.new()
	sv.add_child(arena)
	arena.build("dome", home.c1, away.c1, tr("LEAGUE_NAME").to_upper())
	# A raider squaring up to three defenders.
	var r := Athlete.new()
	r.setup(home.squad[0], 0, home.c1, home.c2, false)
	sv.add_child(r)
	r.position = Vector3(0.3, 0, 1.2)
	r.facing = Vector3(0, 0, -1)
	r.set_state("raid")
	_showcase.append(r)
	var spots := [Vector3(-1.6, 0, -0.6), Vector3(0.0, 0, -1.4), Vector3(1.7, 0, -0.5)]
	for i in 3:
		var d := Athlete.new()
		d.setup(away.squad[6 + i], 1, away.c1, away.c2, false)
		sv.add_child(d)
		d.position = spots[i]
		d.facing = (r.position - d.position).normalized()
		d.set_state("ready")
		_showcase.append(d)
	_cam = Camera3D.new()
	_cam.fov = 45
	sv.add_child(_cam)
	_cam.current = true
	# Shade the left side so the menu reads clearly.
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var g := Gradient.new()
	g.set_color(0, Color(Game.C_BG, 0.96))
	g.set_color(1, Color(Game.C_BG, 0.0))
	g.add_point(0.45, Color(Game.C_BG, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _process(delta: float) -> void:
	_t += delta
	if _cam:
		var a := 0.9 + sin(_t * 0.15) * 0.35
		_cam.position = Vector3(sin(a) * 6.5, 2.1, cos(a) * 6.5)
		_cam.look_at(Vector3(-2.3, 1.0, 0.8), Vector3.UP)
		if _showcase.size() > 0:
			var r: Athlete = _showcase[0]
			# The raider feints left and right.
			r.position.x = 0.3 + sin(_t * 1.7) * 0.7
			r.vel = Vector3(cos(_t * 1.7) * 1.2, 0, 0)
			for i in range(1, _showcase.size()):
				var d: Athlete = _showcase[i]
				d.face_toward(r.position, delta)


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_theme_constant_override("margin_right", 48)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.custom_minimum_size = Vector2(520, 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(col)

	var eyebrow := UI.label(tr("LEAGUE_NAME").to_upper() + "  ·  " + tr("MENU_CUP").to_upper(), "EyebrowLabel")
	col.add_child(eyebrow)
	var title := UI.label(tr("GAME_TITLE"), "TitleLabel", 92)
	title.add_theme_color_override("font_color", Game.C_INK)
	col.add_child(title)
	var tag := UI.label(tr("TAGLINE"), "SubLabel", 26, Game.C_SAFFRON)
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	col.add_child(gap)

	col.add_child(_mode_card("MENU_QUICK", "MENU_QUICK_DESC", func(): Game.show_screen("res://ui/quick_setup.gd"), true))
	col.add_child(_mode_card("MENU_CUP", "MENU_CUP_DESC", func(): Game.show_screen("res://ui/cup_screen.gd")))
	col.add_child(_mode_card("MENU_CAREER", "MENU_CAREER_DESC", func(): Game.show_screen("res://ui/career_hub.gd")))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var s := UI.button(tr("MENU_SETTINGS"), false, func(): Game.show_screen("res://ui/settings_screen.gd"))
	s.custom_minimum_size = Vector2(200, 56)
	var h := UI.button(tr("MENU_HOWTO"), false, func(): Game.show_screen("res://ui/howto_screen.gd"))
	h.custom_minimum_size = Vector2(200, 56)
	row.add_child(s)
	row.add_child(h)
	col.add_child(row)

	var note := UI.label("v" + String(ProjectSettings.get_setting("application/config/version", "0.1")), "MutedLabel", 15)
	note.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	note.position = Vector2(-90, -34)
	add_child(note)


func _mode_card(title_key: String, desc_key: String, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(520, 96)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(Sfx.click)
	b.pressed.connect(cb)
	if primary:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(Game.C_PANEL, 0.92)
		sb.border_color = Game.C_SAFFRON
		sb.set_border_width_all(0)
		sb.border_width_left = 6
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override("normal", sb)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 26
	v.offset_top = 10
	v.offset_right = -20
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UI.label(tr(title_key), "HeaderLabel", 40)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d := UI.label(tr(desc_key), "MutedLabel", 18)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	v.add_child(d)
	b.add_child(v)
	return b
