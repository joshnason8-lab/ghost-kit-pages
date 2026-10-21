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
var coach: Coach = null           # the first match's tips (Coach.wanted)
var _whistled := false
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
	if Coach.wanted(m):
		coach = Coach.new(m)
		root.add_child(coach)
	m.game_event.connect(_on_event)
	if m.demo:
		_board.visible = not bool(m.config.get("attract", false))


func add_controls(c: TouchControls) -> void:
	_controls = c
	root.add_child(c)
	root.move_child(c, 1)
	# The pause button, top right, clear of the scoreboard and a camera cut-out.
	_pause_btn = UI.round_button("pause", func(): m.set_paused(true), 60)
	# Anchored to the top right corner (not placed by size: the HUD has no size yet when the match is built).
	_pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_place_pause()
	root.resized.connect(_place_pause)
	root.add_child(_pause_btn)


func _place_pause() -> void:
	var sm := UI.safe_margins(root, 22.0)
	_pause_btn.offset_left = -sm.z - 60
	_pause_btn.offset_right = -sm.z
	_pause_btn.offset_top = sm.y
	_pause_btn.offset_bottom = sm.y + 60


## For the tests: where the pause button is.
func pause_button() -> Button:
	return _pause_btn


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
		_controls.visible = not m.paused and not (m.phase in ["break", "over", "timeout", "injury"]) or _controls.editing
	if coach:
		coach.step(delta, _whistled)
		_whistled = false
		_place_coach()
	_me_ring += delta
	_overlay.queue_redraw()


## The coach's tip: at the bottom, between the stick and the buttons; above the umpire's call if both show.
func _place_coach() -> void:
	if not coach.visible:
		return
	var sm := UI.safe_margins(root, 14.0)
	var w := minf(root.size.x * 0.40, 600.0)   # clear of the stick and of the buttons at normal size
	coach.custom_minimum_size.x = w
	coach.size = Vector2(w, 0)
	coach.position = Vector2((root.size.x - w) * 0.5, root.size.y - sm.w - coach.get_combined_minimum_size().y - 8.0)
	coach.visible = not (m.phase in ["break", "over", "timeout", "injury"]) and not m.paused


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
			_whistled = true
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
		"warning":
			banner(tr("CALL_WARNING"), tr("SANCTION_LINE").format({"pos": info.by, "team": DB.team_name(m.team_id(int(info.team)))}), 2.0)
		"escalate":
			banner(tr("CALL_ESCALATE"), tr("SANCTION_LINE").format({"pos": info.by, "team": DB.team_name(m.team_id(int(info.team)))}), 1.8)
		"advance":
			banner(tr("CALL_ADVANCE"), tr("SANCTION_LINE").format({"pos": info.by, "team": DB.team_name(m.team_id(int(info.team)))}), 1.8)
		"ordered_off":
			banner(tr("CALL_ORDERED_OFF"), tr("SANCTION_LINE").format({"pos": info.by, "team": DB.team_name(m.team_id(int(info.team)))}), 2.6)
		"suspension":
			banner(tr("CALL_SUSPENSION"), tr("SANCTION_LINE").format({"pos": info.by, "team": DB.team_name(m.team_id(int(info.team)))}), 2.4)
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
	if m.phase in ["break", "timeout", "injury"]:
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
		var tags := []
		for t in 2:
			for pl in m.players[t]:
				var at := _screen(pl.position + Vector3(0, float(pl.data.height) + 0.28, 0))
				if at.x < -100:
					continue
				var w := font.get_string_size(pl.pos, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				tags.append({"pl": pl, "rect": Rect2(at - Vector2(w * 0.5 + 6, fs * 0.5 + 3), Vector2(w + 12, fs + 6)), "w": w})
		var rects := []
		for tg in tags:
			rects.append(tg.rect)
		rects = declutter(rects)
		for i in tags.size():
			var pl: Player = tags[i].pl
			var r: Rect2 = rects[i]
			var mine: bool = pl.team == m.user_team
			var col: Color = DB.team(m.team_id(pl.team)).c1
			_overlay.draw_rect(r, Color(0.04, 0.03, 0.1, 0.62), true)
			_overlay.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), col, true)
			_overlay.draw_string(font, r.position + Vector2(6, 3 + fs * 0.86), pl.pos, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				Game.C_ACCENT if pl == m.me else (Game.C_INK if mine or m.user_team < 0 else Color(Game.C_INK, 0.8)))


## Name tags that would overlap (two players side by side, a defender on her attacker) are stacked: each one that
## meets a tag already placed moves up above it. Tags lower on the screen (nearer the camera) keep their places.
static func declutter(rects: Array) -> Array:
	var order := range(rects.size())
	order.sort_custom(func(a, b): return rects[a].position.y > rects[b].position.y)
	var out := rects.duplicate()
	var placed: Array[Rect2] = []
	for i in order:
		var r: Rect2 = out[i]
		var moved := true
		var guard := 0
		while moved and guard < 14:
			moved = false
			guard += 1
			for p in placed:
				if r.grow(-1.0).intersects(p):
					r.position.y = p.position.y - r.size.y - 2.0
					moved = true
		out[i] = r
		placed.append(r)
	return out


# ---------------------------------------------------------------- the break between quarters

## The break after period q (next: the period that follows): the scores by quarter, the interval's real length
## counting down, team changes (substitutions are allowed at any interval, R3), and Continue.
func show_break(q: int, next: int, timeout_team := -1) -> void:
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
	if q == -2:
		v.add_child(UI.label(tr("INJURY_HELD"), "TitleLabel", 60))
		v.add_child(UI.wrap(tr("INJURY_NOTE").format({"team": DB.team_name(m.team_id(timeout_team))}), "MutedLabel", 18))
	elif timeout_team >= 0:
		v.add_child(UI.label(tr("TIME_OUT_CALLED").format({"team": DB.team_name(m.team_id(timeout_team))}), "TitleLabel", 60))
		v.add_child(UI.wrap(tr("TIME_OUT_NOTE"), "MutedLabel", 18))
	else:
		var mins := Rules.interval_after(q)
		var title := tr("HALF_TIME") if q == 2 else (tr("FULL_TIME_LEVEL") if q == 4 else tr("QUARTER_TIME_N").format({"n": q}))
		if q >= 5:
			title = tr("EXTRA_TIME_BREAK")
		v.add_child(UI.label(title, "TitleLabel", 60))
		v.add_child(UI.wrap(tr("INTERVAL_NOTE").format({"min": int(mins), "next": period_name(next)}), "MutedLabel", 18))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := UI.card()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 18)
	lv.add_child(score_table(m))
	lv.add_child(team_stats(m))
	left.add_child(lv)
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


## The teams' match so far, side by side: goals from attempts, feeds, gains, intercepts, penalties, turnovers.
static func team_stats(mt) -> GridContainer:
	var keys := [["BOX_G", ""], ["BOX_PCT", ""], ["BOX_FEEDS", "feeds"], ["BOX_GAINS", "gains"], ["BOX_INT", "intercepts"],
		["BOX_PEN", "penalties"], ["BOX_TO", "turnovers"]]
	var sum := [{}, {}]
	for id in mt.stats:
		var s: Dictionary = mt.stats[id]
		for k in s:
			if typeof(s[k]) == TYPE_INT and k != "team":
				sum[s.team][k] = int(sum[s.team].get(k, 0)) + int(s[k])
	var g := GridContainer.new()
	g.columns = keys.size() + 1
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 8)
	g.add_child(UI.label("", "EyebrowLabel"))
	for k in keys:
		g.add_child(UI.label(TranslationServer.translate(k[0]).to_upper(), "EyebrowLabel"))
	for t in 2:
		g.add_child(UI.label(DB.team_abbr(mt.team_id(t)), "SubLabel", 20))
		var goals := int(sum[t].get("goals", 0))
		var att := int(sum[t].get("attempts", 0))
		g.add_child(UI.label("%d/%d" % [goals, att], "", 20))
		g.add_child(UI.label("%d" % roundi(100.0 * goals / att) if att > 0 else "–", "", 20))
		for k in keys.slice(2):
			g.add_child(UI.label(str(int(sum[t].get(k[1], 0))), "", 20))
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
	grid.columns = 1   # a row each: the position, who plays it and who would come on
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	var t: int = m.user_team
	for pl in m.players[t]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = _change_text(pl)
		b.disabled = m.next_on(pl) < 0
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var who: Player = pl
		b.pressed.connect(func():
			Sfx.click()
			if m.substitute(who):
				b.text = _change_text(who)
				b.disabled = m.next_on(who) < 0)
		grid.add_child(b)
	return v


## A change button's words: the position, who plays it now and who would come on ("GS  Hannah Rowe  ›  Amy Lee").
func _change_text(pl: Player) -> String:
	var i: int = m.next_on(pl)
	if i < 0:
		return "%s  %s" % [pl.pos, pl.data.name]
	return "%s  %s  ›  %s" % [pl.pos, pl.data.name, String(m.bench[pl.team][i].name)]


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
	if m.can_timeout(m.user_team):
		v.add_child(UI.button(tr("TIME_OUT_N").format({"n": int(m.timeouts[m.user_team])}), false, func():
			m.set_paused(false)
			m.call_timeout(m.user_team)))
	if m.rolling and m.user_team >= 0:
		v.add_child(UI.button(tr("TEAM_CHANGES"), false, func():
			show_pause(false)
			_pause_btn.visible = false
			_rolling_changes()))
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


## Rolling substitutions (the league option): team changes from the pause menu, at any time.
func _rolling_changes() -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(Game.C_BG, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var card := UI.card()
	card.custom_minimum_size = Vector2(620, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(_changes())
	v.add_child(UI.button(tr("DONE"), true, func():
		layer.queue_free()
		show_pause(true)))
	UI.keep_on_screen(card)


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
