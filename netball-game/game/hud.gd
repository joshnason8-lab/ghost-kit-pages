class_name HUD
extends CanvasLayer
## What is on the screen over a match. The scoreboard as a netball broadcast shows it: both teams with their flags and
## scores, the quarter and the clock counting down, and an arrow to the team whose centre pass is next. The umpire's
## call (the infringement, the award and to whom), the bibs over players' heads, your player's ring, the 0.9 m ring
## round the landing foot of the player with the ball when you defend her, the three seconds running out round the
## ball, the Double Zone when it is live. And the overlays: a break between quarters (the quarter scores, team changes,
## Continue) and the pause menu.
##
## A CanvasLayer does not take the window's theme: the theme is set on its root Control (lesson 3 of Kabaddi Raid's
## betas), or its text falls back to a font with no glyphs for half the game's languages.

var m
var root: Control
var _overlay: Control         # bibs, rings: drawn under the panels
var _board: PanelContainer
var _score_l: Array = []
var _period_l: Label
var _clock_l: Label
var _cp_arrow: Array = []     # per team: the arrow by its name when its centre pass is next
var _dz: Label
var _call: PanelContainer
var _call_title: Label
var _call_line: Label
var _call_t := 0.0
var _break: Control = null
var _pause: Control = null
var _pause_btn: Button
var _controls: TouchControls = null
var _layout_panel: Control = null
var _me_ring := 0.0


func _init(p_match) -> void:
	m = p_match
	layer = 10


func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Game.theme
	add_child(root)
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	root.add_child(_overlay)
	_build_board()
	_build_call()
	m.game_event.connect(_on_event)
	if m.demo:
		_board.visible = not bool(m.config.get("attract", false))


func add_controls(c: TouchControls) -> void:
	_controls = c
	root.add_child(c)
	root.move_child(c, 1)
	# The pause button, top right, clear of the scoreboard and a camera cut-out.
	_pause_btn = UI.round_button("pause", func(): m.set_paused(true), 60)
	_pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var sm := UI.safe_margins(root, 22.0)
	_pause_btn.position = Vector2(root.size.x - sm.z - 60, sm.y)
	root.resized.connect(func():
		var s2 := UI.safe_margins(root, 22.0)
		_pause_btn.position = Vector2(root.size.x - s2.z - 60, s2.y))
	root.add_child(_pause_btn)


# ---------------------------------------------------------------- the scoreboard

func _build_board() -> void:
	_board = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.035, 0.11, 0.86)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	_board.add_theme_stylebox_override("panel", sb)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_board)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(h)
	for t in 2:
		var side := HBoxContainer.new()
		side.add_theme_constant_override("separation", 8)
		side.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var id: String = m.team_id(t)
		# The centre pass arrow: by the team whose centre pass is next, pointing at it.
		var arrow := Icon.make("back" if t == 1 else "next", 22, Game.C_ACCENT)
		arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_cp_arrow.append(arrow)
		var flag := UI.badge(id, Vector2(36, 24))
		flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var name_l := UI.label(DB.team_abbr(id), "HeaderLabel", 30)
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var sc := UI.label("0", "ScoreLabel", 0)
		sc.add_theme_font_size_override("font_size", 44)
		sc.custom_minimum_size = Vector2(52, 0)
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sc.add_theme_color_override("font_color", Game.C_INK)
		_score_l.append(sc)
		if t == 0:
			for c in [arrow, flag, name_l, sc]:
				side.add_child(c)
		else:
			for c in [sc, name_l, flag, arrow]:
				side.add_child(c)
		h.add_child(side)
		if t == 0:
			var mid := VBoxContainer.new()
			mid.add_theme_constant_override("separation", -6)
			mid.alignment = BoxContainer.ALIGNMENT_CENTER
			mid.custom_minimum_size = Vector2(92, 0)
			mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_period_l = UI.label("Q1", "EyebrowLabel", 15, Game.C_ACCENT)
			_period_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_clock_l = UI.label("15:00", "HeaderLabel", 30)
			_clock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_period_l)
			mid.add_child(_clock_l)
			_dz = UI.label("", "EyebrowLabel", 12, Game.C_GOLD)
			_dz.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.add_child(_dz)
			h.add_child(mid)
	_place_board()
	root.resized.connect(_place_board)


func _place_board() -> void:
	var sm := UI.safe_margins(root, 14.0)
	_board.position = Vector2((root.size.x - _board.size.x) * 0.5, sm.y)


func _process(delta: float) -> void:
	for t in 2:
		(_score_l[t] as Label).text = str(m.score[t])
	_period_l.text = period_name(m.q)
	var tl: float = m.time_left
	_clock_l.text = "%d:%02d" % [int(tl) / 60, int(tl) % 60] if tl < 1e6 else "—"
	var next_cp: int = Rules.centre_pass_team(m.cp_first, m.cp_n)
	for t in 2:
		(_cp_arrow[t] as Control).modulate.a = 1.0 if next_cp == t else 0.0
	_dz.text = tr("DZ_LIVE") if m.double_zone and Rules.double_zone_live(m.time_left, m.quarter_min) and m.q <= 6 else ""
	_place_board()
	if _call.visible:
		_call_t -= delta
		if _call_t <= 0.0:
			_call.visible = false
	if _controls:
		var want: Array = m.button_set()
		if want != _controls.ids and not _controls.editing:
			_controls.set_buttons(want)
		_controls.visible = not m.paused and m.phase != "break" and m.phase != "over" or _controls.editing
	_me_ring += delta
	_overlay.queue_redraw()


## The player you control changed (the HUD rings her; nothing else to do here yet).
func on_me(_pl: Player) -> void:
	_me_ring = 0.0


func period_name(q: int) -> String:
	if q <= 4:
		return tr("QUARTER_SHORT").format({"n": q})
	if q <= 6:
		return tr("EXTRA_TIME_SHORT").format({"n": q - 4})
	return tr("GOLDEN_TWO")


# ---------------------------------------------------------------- the umpire's call

func _build_call() -> void:
	_call = PanelContainer.new()
	_call.theme_type_variation = "GlassPanel"
	_call.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_call.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_call.visible = false
	root.add_child(_call)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_call.add_child(v)
	_call_title = UI.label("", "HeaderLabel", 30, Game.C_GOLD)
	_call_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_call_title)
	_call_line = UI.label("", "", 18)
	_call_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_call_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_call_line.custom_minimum_size = Vector2(380, 0)
	v.add_child(_call_line)


## Shows a call under the scoreboard for a moment.
func banner(title: String, line := "", secs := 2.2) -> void:
	_call_title.text = title
	_call_line.text = line
	_call_line.visible = line != ""
	_call.visible = true
	_call_t = secs
	_call.reset_size()
	_call.size.x = 0
	var sm := UI.safe_margins(root, 14.0)
	await get_tree().process_frame
	if is_instance_valid(_call):
		_call.position = Vector2((root.size.x - _call.size.x) * 0.5, sm.y + _board.size.y + 10.0)


func _on_event(kind: String, info: Dictionary) -> void:
	match kind:
		"call":
			var to := int(info.to)
			var what := tr("CALL_" + String(info.kind).to_upper())
			var award := tr("AWARD_" + String(info.award).to_upper())
			if bool(info.get("shot", false)):
				award = tr("AWARD_PENALTY_SHOT")
			banner(what, tr("AWARD_TO").format({"award": award, "team": DB.team_name(m.team_id(to))}))
		"advantage":
			banner(tr("CALL_ADVANTAGE"), tr("CALL_" + String(info.kind).to_upper()), 1.6)
		"goal":
			var v := int(info.value)
			banner(tr("GOAL_TWO") if v == 2 else tr("GOAL"), DB.team_name(m.team_id(int(info.team))), 1.6)
		"gain":
			if m.user_team >= 0:
				banner(tr("CALL_INTERCEPT") if String(info.how) == "intercept" else tr("CALL_GAIN"), "", 1.2)
		"period_end":
			pass


# ---------------------------------------------------------------- over the court

func _screen(p: Vector3) -> Vector2:
	var cam: Camera3D = m.cam
	if cam.is_position_behind(p):
		return Vector2(-9999, -9999)
	var k := root.size.x / maxf(1.0, float(root.get_viewport().get_visible_rect().size.x))
	return cam.unproject_position(p) * k


## A circle on the floor, as the camera sees it.
func _floor_ring(c: Vector2, r: float, col: Color, w := 3.0, seg := 28) -> void:
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a := TAU * i / seg
		pts.append(_screen(Vector3(c.x + cos(a) * r, 0.02, c.y + sin(a) * r)))
	_overlay.draw_polyline(pts, col, w, true)


func _draw_overlay() -> void:
	if m.phase == "break":
		return
	var font: Font = Game.font_bold
	var show_tags := int(Game.settings.tags) != 2 and not bool(m.config.get("attract", false))
	# Your player: a lime ring at her feet; the team-mate you would pass to, a dashed one.
	if m.me and m.user_team >= 0:
		_floor_ring(m.me.p, 0.62 + 0.04 * sin(_me_ring * 6.0), Game.C_ACCENT, 4.0)
		if m.me == m.holder:
			var t: Player = m.ai.user_target()
			if t:
				_floor_ring(t.p, 0.55, Color(Game.C_ACCENT, 0.55), 3.0)
	# Defending the player with the ball: the 0.9 m from her landing foot, green outside it, red inside.
	if m.me and m.holder and m.holder.team != m.user_team and m.user_team >= 0:
		var inside: bool = m.me.p.distance_to(m.holder.landing) < Court.DEFEND_DIST
		_floor_ring(m.holder.landing, Court.DEFEND_DIST, Color(Game.C_DANGER if inside else Game.C_GOOD, 0.85), 2.5)
	# The three seconds round the ball.
	if m.holder and m.hold_ready and m.phase == "live" and (m.user_team >= 0 or not m.demo):
		var c := _screen(m.holder.position + Vector3(0, float(m.holder.data.height) + 0.35, 0))
		var left: float = clampf(1.0 - m.hold_t / Rules.HOLD_LIMIT, 0.0, 1.0)
		var col := Game.C_GOOD.lerp(Game.C_DANGER, 1.0 - left)
		_overlay.draw_arc(c, 13.0, -PI / 2, -PI / 2 + TAU * left, 28, col, 4.0, true)
	if show_tags:
		var fs := Game.ts(15)
		for t in 2:
			for pl in m.players[t]:
				var at := _screen(pl.position + Vector3(0, float(pl.data.height) + 0.28, 0))
				if at.x < -100:
					continue
				var mine: bool = t == m.user_team
				var txt: String = pl.pos
				var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var col: Color = DB.team(m.team_id(t)).c1
				_overlay.draw_rect(Rect2(at - Vector2(w * 0.5 + 6, fs * 0.5 + 3), Vector2(w + 12, fs + 6)), Color(0.04, 0.03, 0.1, 0.62), true)
				_overlay.draw_rect(Rect2(at + Vector2(-w * 0.5 - 6, fs * 0.5 + 1), Vector2(w + 12, 2)), col, true)
				_overlay.draw_string(font, at + Vector2(-w * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
					Game.C_ACCENT if pl == m.me else (Game.C_INK if mine or m.user_team < 0 else Color(Game.C_INK, 0.8)))


# ---------------------------------------------------------------- the break between quarters

## The break after period q (next: the period that follows): the scores by quarter, the interval's real length
## counting down, team changes (substitutions are allowed at any interval, R3), and Continue.
func show_break(q: int, next: int) -> void:
	if m.demo:
		return
	hide_break()
	_break = Control.new()
	_break.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_break.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_break)
	var dim := ColorRect.new()
	dim.color = Color(Game.C_BG, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_break.add_child(dim)
	var margin := UI.frame(_break, 40.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	var mins := Rules.interval_after(q)
	var title := tr("HALF_TIME") if q == 2 else (tr("FULL_TIME_LEVEL") if q == 4 else tr("QUARTER_TIME_N").format({"n": q}))
	if q >= 5:
		title = tr("EXTRA_TIME_BREAK")
	var head := UI.label(title, "TitleLabel", 60)
	v.add_child(head)
	v.add_child(UI.wrap(tr("INTERVAL_NOTE").format({"min": int(mins), "next": period_name(next)}), "MutedLabel", 18))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := UI.card()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(score_table(m))
	cols.add_child(left)
	if m.user_team >= 0:
		var right := UI.card()
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right.add_child(_changes())
		cols.add_child(right)
	var go := UI.button(tr("CONTINUE"), true, func(): m.skip_break())
	go.custom_minimum_size = Vector2(320, 66)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(go)


func hide_break() -> void:
	if _break and is_instance_valid(_break):
		_break.queue_free()
	_break = null


## The score by period: a row per team, a column per quarter (and extra time), and the total.
static func score_table(mt) -> GridContainer:
	var g := GridContainer.new()
	var n: int = mt.q_scores.size()
	g.columns = n + 2
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 8)
	g.add_child(UI.label("", "EyebrowLabel"))
	for i in n:
		g.add_child(UI.label(_pname(i + 1), "EyebrowLabel"))
	g.add_child(UI.label(TranslationServer.translate("TOTAL").to_upper(), "EyebrowLabel"))
	for t in 2:
		var nm := HBoxContainer.new()
		nm.add_theme_constant_override("separation", 8)
		nm.add_child(UI.badge(mt.team_id(t), Vector2(30, 20)))
		nm.add_child(UI.label(DB.team_abbr(mt.team_id(t)), "SubLabel", 22))
		g.add_child(nm)
		for i in n:
			g.add_child(UI.label(str(mt.q_scores[i][t]), "", 22))
		g.add_child(UI.label(str(mt.score[t]), "SubLabel", 24, Game.C_ACCENT))
	return g


static func _pname(q: int) -> String:
	if q <= 4:
		return TranslationServer.translate("QUARTER_SHORT").format({"n": q})
	if q <= 6:
		return TranslationServer.translate("EXTRA_TIME_SHORT").format({"n": q - 4})
	return "+"


## Team changes at an interval: each position with the player in it; tap to bring on the next one from the bench who
## plays that position.
func _changes() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(UI.label(tr("TEAM_CHANGES"), "SubLabel", 22))
	v.add_child(UI.wrap(tr("TEAM_CHANGES_NOTE"), "MutedLabel", 15))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	var t: int = m.user_team
	for pl in m.players[t]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = "%s  %s" % [pl.pos, pl.data.name]
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var who: Player = pl
		b.pressed.connect(func():
			Sfx.click()
			if m.substitute(who):
				b.text = "%s  %s" % [who.pos, who.data.name])
		grid.add_child(b)
	return v


# ---------------------------------------------------------------- pause

func show_pause(on: bool) -> void:
	if _pause and is_instance_valid(_pause):
		_pause.queue_free()
		_pause = null
	if _pause_btn:
		_pause_btn.visible = not on
	if not on:
		return
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(Game.C_BG, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)
	var card := UI.card()
	card.custom_minimum_size = Vector2(460, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var t := UI.label(tr("PAUSED"), "TitleLabel", 60)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UI.label("%s %d – %d %s · %s %s" % [DB.team_abbr(m.team_id(0)), m.score[0], m.score[1], DB.team_abbr(m.team_id(1)),
		period_name(m.q), _clock_l.text], "MutedLabel", 18))
	v.add_child(UI.button(tr("RESUME"), true, func(): m.set_paused(false)))
	v.add_child(UI.button(tr("MOVE_BUTTONS"), false, _move_buttons))
	var quit := UI.button(tr("QUIT_MATCH"), false)
	quit.pressed.connect(func():
		if quit.has_meta("sure"):
			m.quit_to_menu()
		else:
			quit.set_meta("sure", true)
			quit.text = tr("QUIT_SURE"))
	v.add_child(quit)
	keep_pause_card(card)


func keep_pause_card(card: Control) -> void:
	UI.keep_on_screen(card)


## Move buttons from the pause menu: the match's own buttons, in editing mode, beside a card with Reset and Done.
func _move_buttons() -> void:
	if _controls == null:
		return
	show_pause(false)
	_pause_btn.visible = false
	_layout_panel = ButtonLayoutPanel.new(_controls, func():
		_layout_panel.queue_free()
		_layout_panel = null
		show_pause(true))
	root.add_child(_layout_panel)
