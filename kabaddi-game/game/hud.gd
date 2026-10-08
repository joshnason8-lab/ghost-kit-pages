class_name MatchHud
extends CanvasLayer
## Broadcast-style scoreboard, raid clock, on-mat dots, event banners, struggle meter,
## pause menu, and the touch controls.

var m  # Match
var controls: TouchControls
var root: Control
var score_l: Array[Label] = []
var name_l: Array[Label] = []
var dots: Array = []
var clock_l: Label
var half_l: Label
var raid_l: Label
var raid_clock_l: Label
var dod_l: Label
var struggle: ProgressBar
var struggle_box: Control
var chant_l: Label
var breath_box: Control
var breath_bar: ProgressBar
var objective: PanelContainer
var objective_title: Label
var objective_text: Label
var hint_l: Label
var banner_l: Label
var events_box: VBoxContainer
var intro_panel: PanelContainer
var pause_panel: PanelContainer
var cam_btn: Button
var _chant_on := false
var _t := 0.0
var _hint_t := 0.0


class MatDots extends Control:
	var team_color := Color.WHITE
	var total := 7
	var on := 7
	var right_align := false

	func _draw() -> void:
		var r := 6.0
		var gap := 17.0
		var w := (total - 1) * gap
		for i in total:
			var x := (size.x - w - r) + i * gap if right_align else r + i * gap
			var c := Vector2(x, size.y * 0.5)
			var lit := i < on if not right_align else i >= total - on
			if lit:
				draw_circle(c, r, team_color)
				draw_arc(c, r, 0, TAU, 16, Color(1, 1, 1, 0.5), 1.0, true)
			else:
				draw_arc(c, r - 0.5, 0, TAU, 16, Color(1, 1, 1, 0.25), 1.5, true)


func setup(p_match) -> void:
	m = p_match
	layer = 5
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_scoreboard()
	_build_center()
	controls = TouchControls.new()
	root.add_child(controls)
	_build_pause()


func _label(text: String, variation := "", size := 0, color := Color(0, 0, 0, 0)) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_scoreboard() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-330, 10)
	top.custom_minimum_size = Vector2(660, 0)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	for t in 2:
		var panel := PanelContainer.new()
		panel.theme_type_variation = "GlassPanel"
		panel.custom_minimum_size = Vector2(230, 84)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var stripe: Control
		if DB.team(m.teams[t].id).kind == "country":
			stripe = UI.badge(String(m.teams[t].id), Vector2(42, 28))
			stripe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		else:
			var cr := ColorRect.new()
			cr.color = m.teams[t].kit
			cr.custom_minimum_size = Vector2(8, 0)
			stripe = cr
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := _label(String(m.teams[t].id), "SubLabel", 24)
		name_l.append(nm)
		var dot := MatDots.new()
		dot.custom_minimum_size = Vector2(124, 18)
		dot.team_color = m.teams[t].kit if m.teams[t].kit.get_luminance() > 0.3 else m.teams[t].trim
		dot.right_align = t == 1
		dots.append(dot)
		col.add_child(nm)
		col.add_child(dot)
		var sc := _label("0", "ScoreLabel", 56)
		score_l.append(sc)
		if t == 0:
			row.add_child(stripe)
			row.add_child(col)
			row.add_child(sc)
		else:
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(sc)
			row.add_child(col)
			row.add_child(stripe)
		top.add_child(panel)
		if t == 0:
			var mid := PanelContainer.new()
			mid.theme_type_variation = "GlassPanel"
			mid.custom_minimum_size = Vector2(170, 84)
			mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var mc := VBoxContainer.new()
			mc.alignment = BoxContainer.ALIGNMENT_CENTER
			mc.add_theme_constant_override("separation", 0)
			half_l = _label("", "EyebrowLabel", 15)
			half_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			clock_l = _label("3:00", "HeaderLabel", 40)
			clock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mc.add_child(half_l)
			mc.add_child(clock_l)
			mid.add_child(mc)
			top.add_child(mid)

	# Raid strip under the scoreboard.
	var strip := HBoxContainer.new()
	strip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	strip.position = Vector2(-300, 102)
	strip.custom_minimum_size = Vector2(600, 0)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 14)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(strip)
	raid_l = _label("", "SubLabel", 22)
	raid_clock_l = _label("30", "HeaderLabel", 46, Game.C_SAFFRON)
	dod_l = _label(tr("HUD_DOD").to_upper(), "EyebrowLabel", 16, Game.C_DANGER)
	strip.add_child(raid_l)
	strip.add_child(raid_clock_l)
	strip.add_child(dod_l)

	hint_l = _label("", "", 21, Game.C_INK)
	hint_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_l.position = Vector2(-380, 160)
	hint_l.custom_minimum_size = Vector2(760, 0)
	hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint_l.add_theme_constant_override("outline_size", 6)
	root.add_child(hint_l)


func _build_center() -> void:
	events_box = VBoxContainer.new()
	events_box.set_anchors_preset(Control.PRESET_CENTER)
	events_box.position = Vector2(-400, -120)
	events_box.custom_minimum_size = Vector2(800, 0)
	events_box.alignment = BoxContainer.ALIGNMENT_CENTER
	events_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(events_box)

	banner_l = _label("", "TitleLabel", 96)
	banner_l.set_anchors_preset(Control.PRESET_CENTER)
	banner_l.position = Vector2(-500, -70)
	banner_l.custom_minimum_size = Vector2(1000, 0)
	banner_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	banner_l.add_theme_constant_override("outline_size", 14)
	banner_l.visible = false
	root.add_child(banner_l)

	struggle_box = VBoxContainer.new()
	struggle_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	struggle_box.position = Vector2(-160, -96)
	struggle_box.custom_minimum_size = Vector2(320, 0)
	struggle_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sl := _label(tr("EV_HOLD").trim_suffix("!"), "EyebrowLabel", 15, Game.C_MAGENTA)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	struggle = ProgressBar.new()
	struggle.custom_minimum_size = Vector2(320, 14)
	struggle.max_value = 1.0
	struggle.step = 0.001
	struggle.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Game.C_MAGENTA
	fill.set_corner_radius_all(99)
	struggle.add_theme_stylebox_override("fill", fill)
	struggle_box.add_child(sl)
	struggle_box.add_child(struggle)
	struggle_box.visible = false
	root.add_child(struggle_box)

	chant_l = _label(tr("HUD_CHANT"), "SubLabel", 22, Game.C_GOLD)
	chant_l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	chant_l.position = Vector2(-250, -52)
	chant_l.custom_minimum_size = Vector2(500, 0)
	chant_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chant_l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	chant_l.add_theme_constant_override("outline_size", 6)
	chant_l.visible = false
	root.add_child(chant_l)

	# Breath for the cant: tap Cant on the beat to keep it up.
	breath_box = VBoxContainer.new()
	breath_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	breath_box.position = Vector2(-170, -140)
	breath_box.custom_minimum_size = Vector2(340, 0)
	breath_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := _label(tr("HUD_BREATH").to_upper(), "EyebrowLabel", 15, Game.C_GOLD)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	breath_bar = ProgressBar.new()
	breath_bar.custom_minimum_size = Vector2(340, 14)
	breath_bar.max_value = 1.0
	breath_bar.step = 0.001
	breath_bar.show_percentage = false
	breath_box.add_child(bl)
	breath_box.add_child(breath_bar)
	breath_box.visible = false
	root.add_child(breath_box)

	# Tutorial objective.
	objective = PanelContainer.new()
	objective.theme_type_variation = "GlassPanel"
	objective.set_anchors_preset(Control.PRESET_TOP_LEFT)
	objective.position = Vector2(20, 120)
	objective.custom_minimum_size = Vector2(380, 0)
	objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ov := VBoxContainer.new()
	objective_title = _label("", "SubLabel", 22, Game.C_SAFFRON)
	objective_text = _label("", "", 19)
	objective_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_text.custom_minimum_size = Vector2(350, 0)
	ov.add_child(objective_title)
	ov.add_child(objective_text)
	objective.add_child(ov)
	objective.visible = false
	root.add_child(objective)


func _build_pause() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.theme_type_variation = "CardPanel"
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.custom_minimum_size = Vector2(420, 0)
	pause_panel.position = Vector2(-210, -170)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pause_panel.add_child(v)
	var title := _label(tr("PAUSED"), "HeaderLabel")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var resume := Button.new()
	resume.text = tr("RESUME")
	resume.theme_type_variation = "PrimaryButton"
	resume.pressed.connect(func(): m.set_paused(false))
	v.add_child(resume)
	cam_btn = Button.new()
	cam_btn.pressed.connect(func():
		m.cam.mode = (m.cam.mode + 1) % 3
		Game.settings.camera = m.cam.mode
		Game.save_settings()
		_update_cam_btn())
	v.add_child(cam_btn)
	var quit := Button.new()
	quit.text = tr("QUIT_MATCH")
	quit.pressed.connect(func(): m.quit_match())
	v.add_child(quit)
	pause_panel.visible = false
	root.add_child(pause_panel)


func _update_cam_btn() -> void:
	cam_btn.text = "%s: %s" % [tr("CAMERA"), tr(["CAM_THIRD", "CAM_FIRST", "CAM_TV"][m.cam.mode])]


func show_pause(p: bool) -> void:
	_update_cam_btn()
	pause_panel.visible = p
	controls.enabled = not p
	controls.visible = not p


func show_intro(home: String, away: String, arena_name: String) -> void:
	intro_panel = PanelContainer.new()
	intro_panel.theme_type_variation = "GlassPanel"
	intro_panel.set_anchors_preset(Control.PRESET_CENTER)
	intro_panel.custom_minimum_size = Vector2(760, 0)
	intro_panel.position = Vector2(-380, -110)
	intro_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	intro_panel.add_child(v)
	var e := _label(arena_name.to_upper(), "EyebrowLabel", 18)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t := _label("%s  %s  %s" % [home, tr("VS"), away], "HeaderLabel", 52)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(e)
	v.add_child(t)
	root.add_child(intro_panel)


func on_raid_setup() -> void:
	if intro_panel:
		intro_panel.queue_free()
		intro_panel = null
	banner_l.visible = false


func set_objective(title: String, text: String) -> void:
	objective.visible = title != ""
	objective_title.text = title
	objective_text.text = text


func cant_feedback(kind: String) -> void:
	controls.flash(kind)
	if kind == "perfect" and m.raider:
		var l := Label3D.new()
		l.text = tr("HUD_KABADDI_WORD")
		l.font = Game.font_display
		l.font_size = 64
		l.pixel_size = 0.004
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.modulate = Game.C_GOLD
		l.outline_size = 12
		l.outline_modulate = Color(0, 0, 0, 0.8)
		m.add_child(l)
		l.global_position = m.raider.global_position + Vector3(randf_range(-0.3, 0.3), 2.1, 0)
		var tw := l.create_tween()
		tw.tween_property(l, "position:y", l.position.y + 0.6, 0.6)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
		tw.tween_callback(l.queue_free)


func hint(text: String) -> void:
	hint_l.text = text
	hint_l.modulate.a = 1.0
	_hint_t = 5.0


func chant(on: bool) -> void:
	_chant_on = on


func banner(text: String) -> void:
	banner_l.text = text
	banner_l.visible = true
	banner_l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(banner_l, "modulate:a", 1.0, 0.3)


func event(text: String, color: Color, small := false) -> void:
	if text == "":
		return
	var l := _label(text, "TitleLabel", 44 if small else 72, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", 12)
	l.pivot_offset = Vector2(400, 40)
	l.scale = Vector2(0.6, 0.6)
	events_box.add_child(l)
	while events_box.get_child_count() > 3:
		events_box.get_child(0).queue_free()
		events_box.remove_child(events_box.get_child(0))
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.3)
	tw.tween_property(l, "modulate:a", 0.0, 0.35)
	tw.tween_callback(l.queue_free)


func float_points(a: Node3D, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = Game.font_display
	l.font_size = 120
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Game.C_SAFFRON
	l.outline_size = 18
	l.outline_modulate = Color(0, 0, 0, 0.8)
	m.add_child(l)
	l.global_position = a.global_position + Vector3(0, 2.2, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y + 1.0, 1.0)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.4)
	tw.tween_callback(l.queue_free)


## A shout above a player's head, like "Pakad!".
func bubble(a: Node3D, text: String, color := Color.WHITE) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = Game.font_display
	l.font_size = 88
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = color
	l.outline_size = 16
	l.outline_modulate = Color(0, 0, 0, 0.85)
	m.add_child(l)
	l.global_position = a.global_position + Vector3(randf_range(-0.2, 0.2), 2.35, 0)
	l.scale = Vector3.ONE * 0.6
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y + 0.5, 1.1)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tw.tween_callback(l.queue_free)


func refresh() -> void:
	var dt := get_process_delta_time()
	_t += dt
	for t in 2:
		score_l[t].text = str(m.teams[t].score)
		dots[t].on = m.on_mat(t).size()
		dots[t].queue_redraw()
	clock_l.text = m.clock_text()
	var half_txt: String = tr("HUD_DOD") if m.golden else tr("HUD_HALF").format({"n": m.half})
	if m.clock_speed > 1.0 and not m.golden:
		half_txt += "  ·  %d×" % int(m.clock_speed)
	half_l.text = half_txt.to_upper()
	var raiding_now: bool = m.phase in ["setup", "raid"]
	raid_l.visible = raiding_now
	raid_clock_l.visible = m.phase == "raid"
	dod_l.visible = raiding_now and m.raid.get("dod", false)
	if raiding_now and m.raider:
		var mine: bool = m.raider == m.controlled
		raid_l.text = tr("HUD_YOUR_RAID") if mine else tr("HUD_RAIDING").format({"team": String(m.teams[m.raiding].id)})
		raid_l.add_theme_color_override("font_color", Game.C_SAFFRON if m.raiding == 0 else Game.C_MAGENTA.lightened(0.2))
	if m.phase == "raid":
		var rt := int(ceil(maxf(0.0, m.raid.t)))
		raid_clock_l.text = str(rt)
		raid_clock_l.add_theme_color_override("font_color", Game.C_DANGER if rt <= 5 else Game.C_SAFFRON)
	var holders: Array = m.raid.get("holders", [])
	struggle_box.visible = m.phase == "raid" and holders.size() > 0
	if struggle_box.visible:
		struggle.value = m.raid.progress
	chant_l.visible = _chant_on and m.phase == "raid"
	var tapping: bool = m.phase in ["raid", "setup"] and m.raid.get("cant_tap", false)
	breath_box.visible = tapping and m.phase == "raid"
	if breath_box.visible:
		breath_bar.value = float(m.raid.breath)
		var low: bool = float(m.raid.breath) < 0.3
		var sb := StyleBoxFlat.new()
		sb.bg_color = Game.C_DANGER if low else Game.C_GOLD
		sb.set_corner_radius_all(99)
		breath_bar.add_theme_stylebox_override("fill", sb)
	controls.cant_mode = tapping
	if m.phase == "raid":
		var ph = fmod(float(m.raid.beat_t), m.BEAT) / m.BEAT
		controls.beat_k = ph
	controls.chain_on = m.controlled != null and m.controlled.chain_partner != null
	var hint_now := ""
	if m.phase == "raid" and m.controlled and m.difficulty <= 1:
		hint_now = m.escape_hint() if m.raider == m.controlled else m.defend_hint()
	if hint_now != controls.read_hint:
		controls.read_hint = hint_now
		controls.queue_redraw()
	if chant_l.visible:
		chant_l.modulate.a = 0.55 + 0.45 * absf(sin(_t * 3.3))
	if _hint_t > 0.0:
		_hint_t -= dt
		hint_l.modulate.a = clampf(_hint_t, 0.0, 1.0)
	var ctx := "none"
	if m.phase == "intro":
		ctx = "intro"
	elif m.phase in ["raid", "setup"] and m.controlled and m.controlled.on_mat:
		ctx = "raid" if m.controlled == m.raider else "defend"
	controls.set_context(ctx)
