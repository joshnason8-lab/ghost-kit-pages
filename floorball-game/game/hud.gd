extends CanvasLayer
## What is on the screen in a match. The scoreboard as a floorball hall's shows it: the teams, the score, the period
## and the clock counting up through the period, and under each team its penalties with the player's number and the
## time left; the power-play strip when one team is short. The referees' calls as a card: the consequence first
## (FREE-HIT, 2 MINUTES ...), the offence and its rule under it (306). Goal banners, the interval, the penalty-shot
## competition's tally, the pause menu, hints, and the touch controls.
##
## A CanvasLayer does not take the window's theme: the root here sets it, so every label has the game's fonts.

var m: Node
var root: Control
var touch: TouchControls
var _names: Array = []
var _scores: Array = []
var _pen_rows: Array = []
var _period: Label
var _clock: Label
var _pp: Label
var _card: PanelContainer
var _card_title: Label
var _card_line: Label
var _card_t := 0.0
var _banner: Label
var _banner_sub: Label
var _banner_t := 0.0
var _hint: Label
var _hint_t := 0.0
var _coach: PanelContainer
var _coach_line: Label
var _coach_t := 0.0
var _coach_gap := 0.0
var _pause: Control
var _interval: Control
var _so: Label
var _dev: Label
var _board: PanelContainer
var _practice: PanelContainer
var _practice_end: Control
var _frames: PackedFloat32Array = []


func setup(p_match: Node) -> void:
	m = p_match
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.theme
	add_child(root)
	touch = TouchControls.new()
	root.add_child(touch)
	_scoreboard()
	_build_card()
	_build_banner()
	_build_coach()
	_hint = UI.label("", "HudLabel", 19)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -330
	_hint.offset_right = 330
	_hint.offset_top = -64
	_hint.offset_bottom = -24
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outline(_hint)
	_hint.modulate.a = 0.0
	root.add_child(_hint)
	_so = UI.label("", "ScoreLabel", 0)
	_so.add_theme_font_size_override("font_size", 34)
	_so.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_so.offset_top = 128
	_so.offset_left = -300
	_so.offset_right = 300
	_so.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_so.add_theme_color_override("font_color", Color.WHITE)
	_outline(_so)
	_so.visible = false
	root.add_child(_so)
	# Top right: the camera and pause.
	var tr_box := HBoxContainer.new()
	tr_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	var sm := UI.safe_margins(root, 24.0)
	tr_box.offset_right = -sm.z
	tr_box.offset_top = 18
	tr_box.offset_left = -200
	tr_box.alignment = BoxContainer.ALIGNMENT_END
	tr_box.add_theme_constant_override("separation", 12)
	root.add_child(tr_box)
	if not bool(m.config.get("practice", false)):   # penalty shots keep their own close camera
		tr_box.add_child(UI.round_button("camera", func(): m.cam.toggle(), 60))
	tr_box.add_child(UI.round_button("pause", func(): m.set_paused(not m.paused), 60))
	if bool(Game.settings.dev):
		_dev = UI.label("", "HudLabel", 15)
		_dev.position = Vector2(sm.x, 120)
		_outline(_dev)
		root.add_child(_dev)


static func _outline(l: Label) -> void:
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.85))


## The scoreboard: a dark bar top centre, like the hall's own board.
func _scoreboard() -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "DarkPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 10
	panel.offset_left = 0
	panel.offset_right = 0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	_board = panel
	if bool(m.config.get("practice", false)):
		panel.visible = false   # penalty-shot practice has its own panel (practice_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	panel.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var ids := [String(m.config.home), String(m.config.away)]
	for side in 2:
		var name_box := HBoxContainer.new()
		name_box.add_theme_constant_override("separation", 8)
		name_box.custom_minimum_size = Vector2(170, 0)
		name_box.alignment = BoxContainer.ALIGNMENT_END if side == 0 else BoxContainer.ALIGNMENT_BEGIN
		var flag := UI.badge(ids[side], Vector2(36, 24))
		flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nm := UI.label(ids[side], "ScoreLabel", 0)
		nm.add_theme_font_size_override("font_size", 34)
		nm.add_theme_color_override("font_color", Color.WHITE)
		var stripe := UI.swatch(m.kits[side][0], Vector2(6, 30))
		stripe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if side == 0:
			name_box.add_child(stripe)
			name_box.add_child(flag)
			name_box.add_child(nm)
		else:
			name_box.add_child(nm)
			name_box.add_child(flag)
			name_box.add_child(stripe)
		_names.append(nm)
		var sc := UI.label("0", "ScoreLabel", 0)
		sc.add_theme_font_size_override("font_size", 52)
		sc.add_theme_color_override("font_color", Color.WHITE)
		sc.custom_minimum_size = Vector2(44, 0)
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_scores.append(sc)
		if side == 0:
			row.add_child(name_box)
			row.add_child(sc)
			var mid := VBoxContainer.new()
			mid.add_theme_constant_override("separation", -6)
			mid.custom_minimum_size = Vector2(100, 0)
			_period = UI.label("1", "HudLabel", 15)
			_period.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_period.add_theme_color_override("font_color", Game.C_YELLOW)
			_clock = UI.label("00:00", "ScoreLabel", 0)
			_clock.add_theme_font_size_override("font_size", 36)
			_clock.add_theme_color_override("font_color", Color("ffcf4a"))
			_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_period)
			mid.add_child(_clock)
			row.add_child(mid)
		else:
			row.add_child(sc)
			row.add_child(name_box)
	# The penalties under each team, and the power play.
	var pens := HBoxContainer.new()
	pens.add_theme_constant_override("separation", 12)
	col.add_child(pens)
	for side in 2:
		var l := UI.label("", "HudLabel", 15)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if side == 0 else HORIZONTAL_ALIGNMENT_LEFT
		l.add_theme_color_override("font_color", Color("ff8a8a"))
		_pen_rows.append(l)
		pens.add_child(l)
		if side == 0:
			_pp = UI.label("", "HudLabel", 14)
			_pp.custom_minimum_size = Vector2(100, 0)
			_pp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_pp.add_theme_color_override("font_color", Game.C_YELLOW)
			pens.add_child(_pp)


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.theme_type_variation = "GlassPanel"
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_card.offset_top = 132
	_card.offset_left = -300
	_card.offset_right = 300
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_card.add_child(v)
	_card_title = UI.label("", "HeaderLabel", 40)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.shrink(_card_title, 40, 0.6)
	_card_line = UI.label("", "SubLabel", 19, Game.C_MUTED)
	_card_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_card_title)
	v.add_child(_card_line)
	_card.modulate.a = 0.0
	root.add_child(_card)


## The coach's notes for a first match: a note on the whiteboard's paper, bottom centre between the joystick and the
## buttons, so it never covers the scoreboard or a referee's call.
func _build_coach() -> void:
	_coach = PanelContainer.new()
	_coach.theme_type_variation = "GlassPanel"
	_coach.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	# A little left of the middle: the buttons' cluster reaches further in from the right than the joystick does.
	_coach.offset_left = -335
	_coach.offset_right = 165
	_coach.offset_bottom = -76
	_coach.offset_top = -76
	_coach.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_coach.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	_coach.add_child(v)
	var head := UI.label(tr("COACH"), "HeaderLabel", 26, Game.C_BLUE)
	v.add_child(head)
	_coach_line = UI.label("", "SubLabel", 19, Game.C_INK)
	_coach_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_coach_line.custom_minimum_size = Vector2(470, 0)
	v.add_child(_coach_line)
	_coach.modulate.a = 0.0
	_coach.visible = false
	root.add_child(_coach)


## A coach's tip (TIP_* key), each said once: Settings > Coach tips brings them all back. One at a time; a tip that
## comes while another shows waits for its moment to come again.
func coach(key: String) -> bool:
	if not bool(Game.settings.tips) or _coach_t > 0.0 or _coach_gap > 0.0 or key in Game.settings.tips_seen:
		return false
	Game.settings.tips_seen.append(key)
	if (Game.settings.tips_seen as Array).size() >= TIPS.size():
		Game.settings.tips = false
	Game.save_settings()
	_coach_line.text = tr(key)
	_coach.visible = true
	_coach_t = 7.0
	return true


func coach_showing() -> String:
	return _coach_line.text if _coach_t > 0.0 else ""


const TIPS := ["TIP_MOVE", "TIP_BALL", "TIP_DEFEND", "TIP_RESTART", "TIP_WHISTLE", "TIP_PENALTY", "TIP_GOAL"]


func _build_banner() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.offset_left = -560
	v.offset_right = 560
	v.offset_top = -120
	v.offset_bottom = 40
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner = UI.label("", "TitleLabel", 110, Color.WHITE)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 22)
	_banner.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.9))
	UI.shrink(_banner, 110, 0.5)
	_banner_sub = UI.label("", "SubLabel", 26, Color.WHITE)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outline(_banner_sub)
	v.add_child(_banner)
	v.add_child(_banner_sub)
	v.modulate.a = 0.0
	root.add_child(v)


## Called once a physics tick by the match: the fades count physics time (a slow frame runs several ticks).
func refresh() -> void:
	var dt := get_physics_process_delta_time()
	var r: Rules.State = m.rules
	var g: Array = r.goals
	for side in 2:
		_scores[side].text = str(int(g[side]))
		var bits := PackedStringArray()
		for p in r.penalties[side]:
			var num := _num(String(p.id), side)
			var left := int(ceil(float(p.left)))
			bits.append("#%s %d:%02d%s" % [num, left / 60, left % 60, "" if bool(p.running) else "*"])
		_pen_rows[side].text = "  ".join(bits)
	# In the interval the board still shows the period just played (the rules have moved on to the next).
	var shown: int = r.period - 1 if m.phase == "interval" and r.period > 1 else r.period
	_period.text = tr("OT_SHORT") if shown > Rules.PERIODS else tr("PERIOD_N").format({"n": shown})
	var c := int(r.clock)
	_clock.text = "%02d:%02d" % [c / 60, c % 60]
	var s0 := r.strength(0)
	var s1 := r.strength(1)
	_pp.text = "%d – %d" % [s0, s1] if s0 != s1 else ""
	# Fades.
	if _card_t > 0.0:
		_card_t -= dt
		_card.modulate.a = clampf(_card_t * 2.5, 0.0, 1.0)
	if _banner_t > 0.0:
		_banner_t -= dt
		(_banner.get_parent() as Control).modulate.a = clampf(_banner_t * 2.0, 0.0, 1.0)
	if _hint_t > 0.0:
		_hint_t -= dt
		_hint.modulate.a = clampf(_hint_t * 2.0, 0.0, 1.0)
	if _coach_t > 0.0:
		_coach_t -= dt
		_coach.modulate.a = clampf(_coach_t * 2.0, 0.0, 1.0)
		if _coach_t <= 0.0:
			_coach.visible = false
			_coach_gap = 1.5
	elif _coach_gap > 0.0:
		_coach_gap -= dt


## The developer overlay (seven taps on the version): real frame times, not physics ticks.
func _process(delta: float) -> void:
	if _dev:
		_frames.append(delta * 1000.0)
		if _frames.size() > 240:
			_frames = _frames.slice(_frames.size() - 240)
		var sorted := _frames.duplicate()
		sorted.sort()
		var n := sorted.size()
		var hitches := 0
		for f in _frames:
			if f > 50.0:
				hitches += 1
		_dev.text = "p50 %.1f ms · p95 %.1f · p99 %.1f · %d hitches · %d fps · draws %d" % [sorted[n / 2], sorted[int(n * 0.95)], sorted[mini(n - 1, int(n * 0.99))], hitches,
			Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)]


func _num(id: String, side: int) -> String:
	for p in m.squads[side]:
		if String(p.id) == id:
			return str(int(p.num))
	return "?"


## A referee's call: the consequence big, the offence and its rule under it; coloured for the team it goes to.
func call_card(title: String, line: String, team: int) -> void:
	_card_title.text = title.to_upper()
	_card_line.text = line
	_card_title.add_theme_color_override("font_color", Game.C_INK if team < 0 else (Game.C_BLUE if team == m.user_team or m.user_team < 0 and team == 0 else Game.C_RED))
	UI.refit(_card_title)
	_card_t = 2.6


func goal_banner(team: int, who: String, pp: bool) -> void:
	_banner.text = tr("GOAL")
	_banner_sub.text = DB.team_name(String(m.config.home if team == 0 else m.config.away)) + " · " + who + (" · " + tr("POWER_PLAY") if pp else "")
	UI.refit(_banner)
	_banner_t = 3.0


func banner(text: String) -> void:
	_banner.text = text
	_banner_sub.text = ""
	UI.refit(_banner)
	_banner_t = 2.2


func hint(text: String) -> void:
	_hint.text = text
	_hint_t = 2.4


func shootout(tally: Array) -> void:
	_so.visible = true
	var rows := PackedStringArray()
	for t in 2:
		var s := ""
		for k in (tally[t] as Array):
			s += "● " if k else "○ "
		rows.append(String(m.config.home if t == 0 else m.config.away) + "  " + s.strip_edges())
	_so.text = "   |   ".join(rows)


# ---------------------------------------------------------------- penalty-shot practice

## The practice's panel where the scoreboard was: the shot (3 of 10), the points, the best, a mark for each shot.
func practice_panel(p: Dictionary) -> void:
	if _practice == null:
		_practice = PanelContainer.new()
		_practice.theme_type_variation = "DarkPanel"
		_practice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_practice.offset_top = 10
		_practice.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_practice.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(_practice)
	for c in _practice.get_children():
		c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	_practice.add_child(row)
	var n := mini(int(p.shot), m.PRACTICE_SHOTS)
	row.add_child(UI.label(tr("PRACTICE_SHOT_N").format({"n": n, "of": m.PRACTICE_SHOTS}), "HudLabel", 20))
	var pts := UI.label(Game.plural("POINTS_N", int(p.points)), "ScoreLabel", 0)
	pts.add_theme_font_size_override("font_size", 34)
	pts.add_theme_color_override("font_color", Game.C_YELLOW)
	row.add_child(pts)
	var marks := ""
	for k in (p.marks as Array):
		marks += ("◆ " if int(k) == 2 else ("● " if int(k) == 1 else "○ "))
	for i in m.PRACTICE_SHOTS - (p.marks as Array).size():
		marks += "· "
	row.add_child(UI.label(marks.strip_edges(), "HudLabel", 20))
	if int(p.best) >= 0:
		row.add_child(UI.label(tr("PRACTICE_BEST_N").format({"n": int(p.best)}), "HudLabel", 18, Color(1, 1, 1, 0.7)))


## The end of the ten: the score, a word on it, the best (or a new best), Go again or Home.
func practice_end(points: int, best: int, new_best: bool) -> void:
	if _practice_end:
		_practice_end.queue_free()
	_practice_end = _overlay()
	var c: PanelContainer = _practice_end.get_meta("card")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	c.add_child(v)
	v.add_child(UI.label(tr("PRACTICE_OVER"), "HeaderLabel", 50))
	var big := UI.label(Game.plural("POINTS_N", points), "TitleLabel", 80, Game.C_MAGNET)
	v.add_child(big)
	var word := "PRACTICE_RATING_0" if points < 5 else ("PRACTICE_RATING_1" if points < 9 else ("PRACTICE_RATING_2" if points < 14 else "PRACTICE_RATING_3"))
	v.add_child(UI.wrap(tr(word), "SubLabel", 22))
	v.add_child(UI.label(tr("PRACTICE_NEW_BEST") if new_best else tr("PRACTICE_BEST_N").format({"n": best}), "SubLabel", 20,
		Game.C_GOLD if new_best else Game.C_MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var again := UI.button(tr("PRACTICE_AGAIN"), true, func():
		_practice_end.queue_free()
		_practice_end = null
		m.practice_restart())
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(again)
	var home := UI.button(tr("HOME"), false, func(): m.quit_to_menu())
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(home)


# ---------------------------------------------------------------- the interval, pause

## Between periods (201: a 10-minute interval, skipped here): the score so far and the shots, and Continue.
func interval(ended: int) -> void:
	if _interval:
		_interval.queue_free()
	_interval = _overlay()
	var c: PanelContainer = _interval.get_meta("card")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	c.add_child(v)
	var title := tr("END_OF_PERIOD_N").format({"n": ended}) if ended > 0 else tr("OVERTIME_NEXT")
	v.add_child(UI.label(title, "HeaderLabel", 50))
	var g: Array = m.rules.goals
	v.add_child(UI.label("%s  %d – %d  %s" % [DB.team_name(String(m.config.home)), int(g[0]), int(g[1]), DB.team_name(String(m.config.away))], "SubLabel", 26))
	var ts: Array = m.team_stats
	v.add_child(UI.label(tr("SHOTS_LINE").format({"a": int(ts[0].sog), "b": int(ts[1].sog)}), "MutedLabel", 19))
	v.add_child(UI.wrap(tr("INTERVAL_NOTE") if ended > 0 else tr("OVERTIME_NOTE"), "MutedLabel", 17))
	var b := UI.button(tr("CONTINUE"), true, func():
		_interval.queue_free()
		_interval = null
		m.continue_after_interval())
	v.add_child(b)


func _overlay() -> Control:
	var o := Control.new()
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.07, 0.1, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.add_child(center)
	var card := UI.card()
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	o.set_meta("card", card)
	root.add_child(o)
	UI.keep_on_screen(center)
	return o


func show_pause(on: bool) -> void:
	if _pause:
		_pause.queue_free()
		_pause = null
	touch.editing = false
	if not on:
		return
	_pause = _overlay()
	var c: PanelContainer = _pause.get_meta("card")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	c.add_child(v)
	v.add_child(UI.label(tr("PAUSED"), "HeaderLabel", 54))
	v.add_child(UI.button(tr("RESUME"), true, func(): m.set_paused(false)))
	if m.user_team >= 0 and not bool(m.config.get("practice", false)):
		var to_left: int = m.rules.timeouts[m.user_team]
		var tob := UI.button(tr("TIMEOUT_BTN") if to_left > 0 else tr("TIMEOUT_USED"), false, func():
			if m.call_timeout():
				hint(tr("TIMEOUT_CALLED"))
				m.set_paused(false))
		tob.disabled = to_left <= 0
		v.add_child(tob)
	if bool(m.config.get("practice", false)):
		v.add_child(UI.button(tr("PRACTICE_RESTART"), false, func():
			m.set_paused(false)
			m.practice_restart()))
	if m.user_team >= 0:
		v.add_child(UI.button(tr("MOVE_BUTTONS"), false, func(): _edit_buttons()))
	var snd := UI.button(tr("SOUND") + ": " + (tr("ON") if Game.settings.sound else tr("OFF")), false)
	snd.pressed.connect(func():
		Game.settings.sound = not Game.settings.sound
		Game.save_settings()
		if not Game.settings.sound:
			Sfx.stop_all()
		snd.text = tr("SOUND") + ": " + (tr("ON") if Game.settings.sound else tr("OFF")))
	v.add_child(snd)
	v.add_child(UI.button(tr("QUIT_MATCH"), false, func(): m.quit_to_menu()))


## Move buttons: the pause card gives way to the buttons themselves, to drag; Done saves.
func _edit_buttons() -> void:
	if _pause:
		_pause.queue_free()
		_pause = null
	touch.set_buttons(["SHOOT", "PASS", "SPRINT"])
	touch.editing = true
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.offset_top = 150
	bar.offset_left = -330
	bar.offset_right = 330
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 12)
	root.add_child(bar)
	var note := UI.label(tr("MOVE_BUTTONS_NOTE"), "HudLabel", 18)
	_outline(note)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(300, 0)
	bar.add_child(note)
	bar.add_child(UI.button(tr("RESET"), false, func(): touch.reset_places()))
	bar.add_child(UI.button(tr("DONE"), true, func():
		touch.editing = false
		bar.queue_free()
		m.set_paused(true)))


## The phone's back button: closes the button editing or the interval card first.
func on_back() -> bool:
	if touch.editing:
		touch.editing = false
		return false
	return false
