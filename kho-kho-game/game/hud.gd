class_name MatchHud
extends CanvasLayer
## What is on the screen in a match. The scoreboard as a kho kho scoreboard reads: both sides' points, which side is
## chasing, the innings and the turn, the turn's clock running down; the batch on the field (three runners, lit while
## in) with how long it has been on, and in the fast game the dream run coming; the wazir and the power play. The
## umpires' calls (KHO!, OUT!, SKY DIVE!, the foul and what it was), the turn's start and end, the interval with the
## score by turn, the follow-on question, and the pause menu. Its root carries the game's theme: a CanvasLayer does
## not take the window's, and without it the text would fall back to a font with no Indian scripts (Kabaddi Raid).

var m   # the match
var root: Control
var controls: TouchControls
var _names: Array = []
var _pts: Array = []
var _chase_tag: Array = []
var _flags: Array = []
var _turn_l: Label
var _clock_l: Label
var _batch_l: Label
var _dots: Array = []
var _run_l: Label
var _run_bar: ProgressBar
var _pp_l: Label
var _call: Label
var _call_t := 0.0
var _foul_l: Label
var _foul_t := 0.0
var _curtain: ColorRect
var _card: PanelContainer
var _card_title: Label
var _card_sub: Label
var _interval: Control
var _pause: Control
var _follow: Control
var _pause_btn: Button
var _cam_btn: Button
var _layout_panel: Control   # Move buttons, opened from the pause menu


func _init(p_match) -> void:
	m = p_match
	layer = 10


func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.theme
	add_child(root)
	controls = TouchControls.new()
	root.add_child(controls)
	controls.visible = m.user >= 0
	_build_scoreboard()
	_build_batch()
	_call = UI.label("", "TitleLabel", 64, Game.C_SAFFRON)
	_call.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_call.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_call.offset_left = -520
	_call.offset_right = 520
	_call.offset_top = -170
	_call.offset_bottom = -70
	_call.add_theme_constant_override("outline_size", 18)
	_call.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.02, 0.95))
	_call.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.shrink(_call, 64, 0.5, 1)
	_call.modulate.a = 0.0
	root.add_child(_call)
	_foul_l = UI.label("", "SubLabel", 24, Game.C_INK)
	_foul_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_foul_l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_foul_l.offset_left = -360
	_foul_l.offset_right = 360
	_foul_l.offset_top = -120
	_foul_l.offset_bottom = -76
	_foul_l.add_theme_constant_override("outline_size", 10)
	_foul_l.add_theme_color_override("font_outline_color", Color(0.4, 0.04, 0.02, 0.95))
	_foul_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fit(_foul_l)
	_foul_l.modulate.a = 0.0
	root.add_child(_foul_l)
	_curtain = ColorRect.new()
	_curtain.color = Color(Game.C_BG, 1.0)
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_curtain)
	_build_card()
	# Pause, and beside it the camera (a tap moves to the next view at once, named as it changes): one pill, drawn
	# together, so the pair costs about what the pause button alone did (the Low budget's draw calls).
	var sm := UI.safe_margins(root, 18.0)
	var pill := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(Game.C_PANEL, 0.9)
	psb.set_corner_radius_all(28)
	psb.border_color = Color(1, 1, 1, 0.12)
	psb.set_border_width_all(1)
	pill.add_theme_stylebox_override("panel", psb)
	pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pill.offset_left = -122 - sm.z
	pill.offset_right = -sm.z
	pill.offset_top = 14
	pill.offset_bottom = 70
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pill.add_child(row)
	_cam_btn = _pill_button("camera_solid", func(): m.cycle_camera())
	_pause_btn = _pill_button("pause", func(): m.set_paused(true))
	row.add_child(_cam_btn)
	row.add_child(_pause_btn)
	root.add_child(pill)


## A button in the pause pill: the icon alone, the pill's panel behind it (a tap lights the icon).
func _pill_button(icon_kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(56, 56)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var ic := Icon.make(icon_kind, 26.0)
	ic.custom_minimum_size = Vector2.ZERO
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["offset_left", "offset_top"]:
		ic.set(side, 15.0)
	for side in ["offset_right", "offset_bottom"]:
		ic.set(side, -15.0)
	b.add_child(ic)
	b.button_down.connect(func(): ic.set_color(Game.C_SAFFRON))
	b.button_up.connect(func(): ic.set_color(Game.C_INK))
	b.pressed.connect(Sfx.click)
	b.pressed.connect(cb)
	return b


func _build_scoreboard() -> void:
	var bar := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.06, 0.05, 0.86)
	sb.set_corner_radius_all(10)
	sb.border_color = Color(Game.C_SAFFRON, 0.6)
	sb.border_width_bottom = 3
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", sb)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.offset_top = 10
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar.add_child(row)
	for side in 2:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		var flag := Crest.make(m.teams[side], 34)
		flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -6)
		var nm := UI.label(DB.team_name(m.teams[side]), "SubLabel", 19)
		nm.custom_minimum_size.x = 175
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if side == 0 else HORIZONTAL_ALIGNMENT_LEFT
		UI.fit(nm, 1, 0.7)
		var tag := UI.label(tr("CHASING"), "EyebrowLabel", 13, Game.C_SAFFRON)
		tag.horizontal_alignment = nm.horizontal_alignment
		UI.fit(tag)
		tag.custom_minimum_size.x = 175
		col.add_child(nm)
		col.add_child(tag)
		var pts := UI.label("0", "ScoreLabel", 0, Game.C_INK)
		pts.add_theme_font_size_override("font_size", 46)
		pts.custom_minimum_size.x = 58
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if side == 0:
			box.add_child(flag)
			box.add_child(col)
			box.add_child(pts)
		else:
			box.add_child(pts)
			box.add_child(col)
			box.add_child(flag)
		_names.append(nm)
		_pts.append(pts)
		_chase_tag.append(tag)
		_flags.append(flag)
		if side == 0:
			row.add_child(box)
			var mid := VBoxContainer.new()
			mid.add_theme_constant_override("separation", -4)
			mid.custom_minimum_size.x = 120
			_clock_l = UI.label("0:00", "ScoreLabel", 0, Game.C_GOLD)
			_clock_l.add_theme_font_size_override("font_size", 38)
			_clock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_turn_l = UI.label("", "EyebrowLabel", 13, Game.C_MUTED)
			_turn_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			UI.fit(_turn_l)
			mid.add_child(_clock_l)
			mid.add_child(_turn_l)
			row.add_child(mid)
		else:
			row.add_child(box)


func _build_batch() -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = "GlassPanel"
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var sm := UI.safe_margins(root, 18.0)
	p.offset_left = sm.x
	p.offset_top = 12
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.custom_minimum_size.x = 170
	p.add_child(v)
	_batch_l = UI.label("", "EyebrowLabel", 13, Game.C_MUTED)
	UI.fit(_batch_l)
	v.add_child(_batch_l)
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 6)
	for i in 3:
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(20, 20)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(d)
		_dots.append(d)
	_run_l = UI.label("", "SubLabel", 18, Game.C_INK)
	dots.add_child(_run_l)
	v.add_child(dots)
	_run_bar = ProgressBar.new()
	_run_bar.show_percentage = false
	_run_bar.custom_minimum_size = Vector2(150, 6)
	_run_bar.max_value = 180.0
	_run_bar.visible = m.fmt == KhoRules.FAST
	v.add_child(_run_bar)
	_pp_l = UI.label("", "EyebrowLabel", 13, Game.C_TEAL.lightened(0.3))
	UI.fit(_pp_l)
	v.add_child(_pp_l)


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.theme_type_variation = "CardPanel"
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.custom_minimum_size = Vector2(560, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_card.add_child(v)
	_card_title = UI.label("", "HeaderLabel", 40, Game.C_SAFFRON)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(_card_title, 2)
	_card_sub = UI.label("", "SubLabel", 22)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.fit(_card_sub, 2)
	v.add_child(_card_title)
	v.add_child(_card_sub)
	_card.modulate.a = 0.0
	root.add_child(_card)


func turn_name(t: int) -> String:
	if m.min_chase and t >= 6:
		return tr("MIN_CHASE")
	if t >= 4:
		return tr("EXTRA_INNINGS")
	return tr("INNINGS_TURN").format({"i": t / 2 + 1, "t": t % 2 + 1})


func on_turn_start() -> void:
	_curtain.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_curtain, "modulate:a", 0.0, 0.5)
	_card_title.text = turn_name(m.turn)
	_card_sub.text = tr("X_CHASES").format({"team": DB.team_name(m.teams[m.chasing])})
	UI.refit(_card_title)
	UI.refit(_card_sub)
	var tw2 := create_tween()
	tw2.tween_property(_card, "modulate:a", 1.0, 0.25)
	tw2.tween_interval(1.1)
	tw2.tween_property(_card, "modulate:a", 0.0, 0.35)
	_refresh()


func on_turn_end(reason: String) -> void:
	_card_title.text = tr("TURN_OVER") if reason != "min_chase" else tr("CALL_OUT")
	_card_sub.text = "%s %d · %d %s" % [DB.team_name(m.teams[0]), m.score[0], m.score[1], DB.team_name(m.teams[1])]
	UI.refit(_card_title)
	UI.refit(_card_sub)
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.8)
	tw.tween_property(_card, "modulate:a", 0.0, 0.3)
	controls.set_buttons([])


## A call: big in the middle for a moment. foul: on the bar at the foot of the screen instead, with what it was.
## A camera's name, as Settings shows it.
static func camera_name(mode: int) -> String:
	return TranslationServer.translate(["CAM_TV", "CAM_CLOSE", "CAM_POLE"][clampi(mode, 0, 2)])


func callout(text: String, col: Color, _at := Vector3.ZERO, foul := false) -> void:
	if foul:
		_foul_l.text = tr("FOUL") + " · " + text
		UI.refit(_foul_l)
		_foul_t = 2.2
		return
	_call.text = text
	_call.add_theme_color_override("font_color", col)
	UI.refit(_call)
	_call_t = 1.1
	_call.scale = Vector2(1.2, 1.2)
	_call.pivot_offset = _call.size * 0.5


func _process(delta: float) -> void:
	if _call_t > 0.0:
		_call_t -= delta
		_call.modulate.a = clampf(_call_t * 3.0, 0.0, 1.0)
		_call.scale = _call.scale.lerp(Vector2.ONE, minf(1.0, delta * 10.0))
	# The foul's bar: held while the foul stands, then fading; cleared once both are over (a foul put right after the
	# fade's time used to leave it on screen).
	_foul_t -= delta
	if m.chase.foul != "":
		_foul_l.modulate.a = 1.0
		if _foul_l.text == "":
			_foul_l.text = tr("FOUL") + " · " + tr("FOUL_" + String(m.chase.foul).to_upper())
	elif _foul_t > 0.0:
		_foul_l.modulate.a = clampf(_foul_t * 3.0, 0.0, 1.0)
	elif _foul_l.modulate.a > 0.0:
		_foul_l.modulate.a = 0.0
		_foul_l.text = ""
	_refresh()


func _refresh() -> void:
	for side in 2:
		_pts[side].text = str(m.score[side])
		_chase_tag[side].text = tr("CHASING") if side == m.chasing else tr("DEFENDING")
		_chase_tag[side].add_theme_color_override("font_color", Game.C_SAFFRON if side == m.chasing else Game.C_MUTED)
	var c := ceili(m.clock)
	_clock_l.text = "%d:%02d" % [c / 60, c % 60]
	_clock_l.add_theme_color_override("font_color", Game.C_DANGER if m.clock < 30.0 and m.phase == "play" else Game.C_GOLD)
	_turn_l.text = turn_name(m.turn)
	_batch_l.text = tr("BATCH_N").format({"n": m.batch_k + 1})
	for i in 3:
		var on := false
		if i < m.batch.size():
			on = m.d_state.get(m.batch[i], "") in ["in", "enter"]
		var col: Color = DB.kit(m.teams[m.defending()])[0]
		_dots[i].color = col if on else Color(1, 1, 1, 0.12)
	var bt := int(m.batch_time)
	_run_l.text = "%d:%02d" % [bt / 60, bt % 60]
	_run_bar.value = fmod(m.batch_time, 180.0) if m.batch_time < 180.0 else 180.0
	if m.powerplay_on:
		_pp_l.text = tr("POWERPLAY_ON")
	elif m.fmt == KhoRules.FAST and m.chase.wazir:
		_pp_l.text = tr("WAZIR_ACTIVE")
	else:
		_pp_l.text = ""


# ---------------------------------------------------------------- interval, follow-on, pause

func _overlay() -> Control:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Game.C_BG, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	root.add_child(o)
	return o


func _centre_card(o: Control, width := 640.0) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(c)
	var card := UI.card()
	card.custom_minimum_size = Vector2(width, 0)
	c.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	UI.keep_on_screen(c)
	return v


## Between turns: the score by turn so far, and Next turn.
func show_interval() -> void:
	_interval = _overlay()
	var v := _centre_card(_interval, 700.0)
	var t := UI.label(tr("INTERVAL"), "HeaderLabel", 38, Game.C_SAFFRON)
	UI.fit(t)
	v.add_child(t)
	v.add_child(score_by_turn(m))
	var next_key := "NEXT_TURN"
	v.add_child(UI.button(tr(next_key), true, func():
		_interval.queue_free()
		_interval = null
		m.next_turn()))


## The score by turn: a row a side, a column a turn (each side's chasing turns score for it), and the total.
static func score_by_turn(mm) -> GridContainer:
	var g := GridContainer.new()
	var n: int = maxi(4, mm.turns_log.size())
	g.columns = n + 2
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 6)
	g.add_child(UI.label("", "EyebrowLabel"))
	for i in n:
		var h := UI.label(TranslationServer.translate("TURN_SHORT").format({"n": i + 1}), "EyebrowLabel", 14, Game.C_MUTED)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.add_child(h)
	var tot := UI.label(TranslationServer.translate("TOTAL"), "EyebrowLabel", 14, Game.C_MUTED)
	g.add_child(tot)
	for side in 2:
		var nm := UI.label(DB.team_name(mm.teams[side]), "SubLabel", 20)
		nm.custom_minimum_size.x = 170
		UI.fit(nm)
		g.add_child(nm)
		for i in n:
			var txt := "·"
			if i < mm.turns_log.size():
				var tl: Dictionary = mm.turns_log[i]
				var pts := 0
				if int(tl.chaser) == side:
					pts += int(tl.points)
				elif int(tl.dream) > 0:
					pts += int(tl.dream)
				txt = str(pts) if int(tl.chaser) == side or int(tl.dream) > 0 else "–"
			var c := UI.label(txt, "", 20)
			c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			g.add_child(c)
		var s := UI.label(str(mm.score[side]), "ScoreLabel", 0, Game.C_GOLD)
		s.add_theme_font_size_override("font_size", 30)
		g.add_child(s)
	return g


## The first innings is over and you lead by enough: make them follow on?
func ask_follow_on() -> void:
	_follow = _overlay()
	var v := _centre_card(_follow, 640.0)
	var t := UI.label(tr("FOLLOW_ON_Q"), "HeaderLabel", 36, Game.C_SAFFRON)
	UI.fit(t, 2)
	v.add_child(t)
	v.add_child(UI.wrap(tr("FOLLOW_ON_NOTE").format({"n": KhoRules.follow_on_lead(m.fmt, m.turn_len)}), "MutedLabel", 18))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var yes := UI.button(tr("FOLLOW_ON_YES"), true, func():
		_follow.queue_free()
		m.choose_follow_on(true))
	var no := UI.button(tr("FOLLOW_ON_NO"), false, func():
		_follow.queue_free()
		m.choose_follow_on(false))
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes)
	row.add_child(no)
	v.add_child(row)


func show_pause(on: bool) -> void:
	if _pause and is_instance_valid(_pause):
		_pause.queue_free()
		_pause = null
	if _layout_panel and is_instance_valid(_layout_panel):
		# Resumed with Move buttons open: it closes with the pause menu (what was moved is kept as it is).
		controls.editing = false
		_layout_panel.queue_free()
		_layout_panel = null
	controls.enabled = not on
	if not on:
		return
	_pause = _overlay()
	var v := _centre_card(_pause, 560.0)
	var t := UI.label(tr("PAUSED"), "HeaderLabel", 40, Game.C_SAFFRON)
	UI.fit(t)
	v.add_child(t)
	v.add_child(UI.button(tr("RESUME"), true, func(): m.set_paused(false)))
	var cam_b := UI.button(tr("CAMERA_CHANGE") + ": " + camera_name(m._cam_mode), false)
	cam_b.pressed.connect(func():
		m.cycle_camera()
		cam_b.text = tr("CAMERA_CHANGE") + ": " + camera_name(m._cam_mode))
	v.add_child(cam_b)
	if m.user >= 0:
		v.add_child(UI.button(tr("MOVE_BUTTONS"), false, _move_buttons))
	var snd := UI.button(tr("SOUND") + ": " + (tr("ON") if Game.settings.sound else tr("OFF")), false)
	snd.pressed.connect(func():
		Game.settings.sound = not Game.settings.sound
		Game.save_settings()
		snd.text = tr("SOUND") + ": " + (tr("ON") if Game.settings.sound else tr("OFF"))
		if not Game.settings.sound:
			Sfx.stop_all())
	v.add_child(snd)
	v.add_child(UI.button(tr("QUIT_MATCH"), false, func(): m.quit_to_menu()))


## Move buttons from the pause menu: the buttons over the paused match, dragged where the thumb finds them.
func _move_buttons() -> void:
	_pause.visible = false
	var ids: Array = controls.ids.duplicate() if not controls.ids.is_empty() else ["KHO", "DIVE"]
	controls.set_buttons(ids)
	controls.enabled = true
	controls.editing = true
	var panel := ButtonLayoutPanel.new(controls, func():
		controls.editing = false
		# Back to the pause menu, if the match is still paused (it may have been resumed meanwhile, by Back).
		if _pause and is_instance_valid(_pause):
			controls.enabled = false
			_pause.visible = true
		else:
			controls.enabled = not m.paused)
	_layout_panel = panel
	root.add_child(panel)
