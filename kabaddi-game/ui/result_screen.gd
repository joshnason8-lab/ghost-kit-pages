extends Control
## Full-time scorecard: the summary, and each side's box score; then back to whichever mode the match came from.

## The box score's columns after the player: the heading's key and the number each shows (Match.BOX).
const BOX_COLS := [["BOX_PTS", "pts"], ["STAT_RAID_PTS", "raid"], ["BOX_RAIDS", "raids"], ["BOX_RAIDS_OK", "raids_ok"],
	["BOX_EMPTY", "empty"], ["STAT_TACKLE_PTS", "tackle"], ["BOX_TRIES", "tries"]]

var result := {}
var _summary: Control
var _box: Control
var _box_body: VBoxContainer   # the side on show's table, made again when the other side is picked


func setup(args: Dictionary) -> void:
	result = args.get("result", {})


func _ready() -> void:
	UI.screen(self)
	Sfx.stop_all()
	var cfg: Dictionary = result.get("config", {})
	var mode := String(cfg.get("mode", "quick"))
	var v := UI.page(self, tr("FULL_TIME"), Callable(), tr("SCORECARD"))
	var has_box: bool = result.get("box", []).size() == 2
	if has_box:
		# The summary and the box score, as tabs beside the title.
		(get_meta("header_right") as Container).add_child(UI.chips_row([tr("SUMMARY"), tr("BOX_SCORE")], 0, func(i):
			_summary.visible = i == 0
			_box.visible = i == 1))
	_summary = _build_summary(mode)
	v.add_child(_summary)
	if has_box:
		_box = _build_box()
		_box.visible = false
		v.add_child(_box)

	var go := UI.button(tr("CONTINUE"), true, _continue.bind(mode))
	go.custom_minimum_size = Vector2(340, 72)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(go)


## The two sides and their scores, where the points came from, and the player of the match.
func _build_summary(mode: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var s: Array = result.score
	var w := int(result.winner)

	# The two sides with their scores, the winner lit.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	for t in 2:
		var id: String = result.home if t == 0 else result.away
		head.add_child(_side(id, int(s[t]), t == w, t == 1))
		if t == 0:
			var dash := UI.label("–", "TitleLabel", 80, Game.C_MUTED)
			dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(dash)
	v.add_child(head)
	var verdict := tr("MATCH_TIED") if w < 0 else tr("TEAM_WINS").format({"team": DB.team_name(result.home if w == 0 else result.away)})
	var vl := UI.label(verdict, "HeaderLabel", 40, Game.C_GOLD)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(vl)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	# Where the points came from, side by side.
	var bd: Array = result.breakdown
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.4
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	var c0: Color = DB.team(result.home).c1
	var c1: Color = DB.team(result.away).c1
	for line in [["STAT_RAID_PTS", "raid"], ["STAT_TACKLE_PTS", "tackle"], ["STAT_ALL_OUT_PTS", "allout"], ["STAT_EXTRA_PTS", "extra"]]:
		var a0 := int(bd[0][line[1]])
		var a1 := int(bd[1][line[1]])
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 12)
		var n0 := UI.label(str(a0), "SubLabel", 22)
		n0.custom_minimum_size = Vector2(44, 0)
		n0.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(n0)
		r.add_child(_bar(a0, maxi(1, maxi(a0, a1)), c0.lightened(0.2), true))
		var mid := UI.label(tr(line[0]), "MutedLabel", 17)
		mid.custom_minimum_size = Vector2(170, 0)
		mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(mid)
		r.add_child(_bar(a1, maxi(1, maxi(a0, a1)), c1.lightened(0.2), false))
		var n1 := UI.label(str(a1), "SubLabel", 22)
		n1.custom_minimum_size = Vector2(44, 0)
		r.add_child(n1)
		cv.add_child(r)
	row.add_child(card)
	# Player of the match.
	var mvp: Dictionary = result.get("mvp", {})
	if String(mvp.get("name", "")) != "":
		var mc := PanelContainer.new()
		mc.theme_type_variation = "CardPanel"
		mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mc.clip_contents = true
		var mh := HBoxContainer.new()
		mh.add_theme_constant_override("separation", 12)
		mc.add_child(mh)
		var art := TextureRect.new()
		art.texture = UI.art("celebrate")   # arms up, in its own blue
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(110, 120)
		mh.add_child(art)
		var mv := VBoxContainer.new()
		mv.alignment = BoxContainer.ALIGNMENT_CENTER
		mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mv.add_child(UI.label(tr("PLAYER_OF_MATCH").to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
		var nm := UI.label(String(mvp.name), "HeaderLabel", 34)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mv.add_child(nm)
		var line := "%s · %d %s" % [DB.team_name(mvp.team), int(mvp.pts), tr("POINTS_TOTAL")]
		if int(mvp.get("number", 0)) > 0:
			line = "#%d · %s" % [int(mvp.number), line]   # the number on his tag in the match
		mv.add_child(UI.label(line, "MutedLabel", 17))
		var his := _box_row(String(mvp.get("pid", "")))
		if not his.is_empty():
			# His numbers: what his raids and tackles came to.
			mv.add_child(UI.fit(UI.label(_numbers(his), "MutedLabel", 16, Game.C_GOLD), 2))
		mh.add_child(mv)
		row.add_child(mc)
	if mode == "career":
		var cs: Dictionary = result.get("career_stats", {})
		var cl := UI.label("%s: %d · %s: %d" % [tr("STAT_RAID_PTS"), int(cs.get("raid", 0)), tr("STAT_TACKLE_PTS"), int(cs.get("tackle", 0))], "SubLabel", 22, Game.C_GOLD)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cl)
	return v


## Each side's box score, one side at a time: every player's points, raids and tackles.
func _build_box() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var s: Array = result.score
	var sides := []
	for t in 2:
		sides.append("%s  %d" % [DB.team_name(result.home if t == 0 else result.away), int(s[t])])
	v.add_child(UI.chips_row(sides, 0, _fill_box))
	var card := UI.card()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box_body = VBoxContainer.new()
	_box_body.add_theme_constant_override("separation", 10)
	card.add_child(UI.scroll(_box_body))
	v.add_child(card)
	_fill_box(0)
	return v


func _fill_box(t: int) -> void:
	for c in _box_body.get_children():
		c.queue_free()
	var rows: Array = result.box[t]
	var mvp_pid := String(result.get("mvp", {}).get("pid", ""))
	var g := GridContainer.new()
	g.columns = 2 + BOX_COLS.size()
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 12)
	g.add_child(_head("#", 38))
	var ph := _head(tr("BOX_PLAYER"), 0)
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(ph)
	for c in BOX_COLS:
		g.add_child(_head(tr(c[0]), 100))
	var sums := {}
	for r in rows:
		var star: bool = String(r.pid) == mvp_pid
		var col := Game.C_GOLD if star else Game.C_INK
		g.add_child(_cell(str(int(r.number)) if int(r.number) > 0 else "", Game.C_MUTED))
		var who := HBoxContainer.new()
		who.add_theme_constant_override("separation", 6)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if star:
			who.add_child(Icon.make("crown", 22, Game.C_GOLD))   # the player of the match
		var nm := UI.fit(UI.label(String(r.name), "SubLabel" if star else "", 22, col))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_child(nm)
		g.add_child(who)
		for c in BOX_COLS:
			var n := _stat(r, String(c[1]))
			sums[c[1]] = int(sums.get(c[1], 0)) + n
			g.add_child(_cell(str(n), col, c[1] == "pts"))
	# The side's line: its points as scored (all outs and extras too), the rest added up.
	var bd: Dictionary = result.breakdown[t]
	sums["pts"] = int(result.score[t])
	sums["raid"] = int(bd.raid)
	sums["tackle"] = int(bd.tackle)
	g.add_child(_cell("", Game.C_MUTED))
	var tl := UI.fit(UI.label(tr("BOX_TEAM"), "SubLabel", 22, Game.C_SAFFRON))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(tl)
	for c in BOX_COLS:
		var k: String = c[1]
		var txt := str(int(sums.get(k, 0)))
		if k == "raids_ok" and int(sums.get("raids", 0)) > 0:
			txt += " (%d%%)" % roundi(100.0 * int(sums.raids_ok) / int(sums.raids))   # the side's raid success rate
		g.add_child(_cell(txt, Game.C_SAFFRON, true))
	_box_body.add_child(g)
	var note := UI.wrap(tr("BOX_NOTE").format({"n": int(bd.allout) + int(bd.extra)}), "MutedLabel", 16)
	_box_body.add_child(note)


func _head(text: String, w: float) -> Label:
	var l := UI.label(text, "EyebrowLabel", 15)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	if w > 0.0:
		l.custom_minimum_size.x = w
	return UI.fit(l, 2)


func _cell(text: String, col: Color, bold := false) -> Label:
	var l := UI.label(text, "SubLabel" if bold else "", 22, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## One of a box score row's numbers: its points, or a number it keeps.
func _stat(r: Dictionary, k: String) -> int:
	return int(r.raid) + int(r.tackle) if k == "pts" else int(r.get(k, 0))


func _box_row(pid: String) -> Dictionary:
	for side in result.get("box", []):
		for r in side:
			if String(r.pid) == pid:
				return r
	return {}


## "Raid points 8 · 6 of 9 raids successful · Tackle points 2 · 2 of 3 tackles successful": what a player's points
## came from, raiding and tackling (a side he scored nothing on is left out).
func _numbers(r: Dictionary) -> String:
	var parts := []
	if int(r.raid) > 0:
		parts.append("%s %d" % [tr("STAT_RAID_PTS"), int(r.raid)])
		parts.append(tr("BOX_RAIDS_OF").format({"ok": int(r.raids_ok), "n": int(r.raids)}))
	if int(r.tackle) > 0:
		parts.append("%s %d" % [tr("STAT_TACKLE_PTS"), int(r.tackle)])
		parts.append(tr("BOX_TRIES_OF").format({"ok": int(r.tackle), "n": maxi(int(r.tries), int(r.tackle))}))
	return UI.bits(parts)


func _side(id: String, score: int, won: bool, right: bool) -> PanelContainer:
	var t := DB.team(id)
	var c1: Color = t.c1
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(c1.darkened(0.7).lerp(Game.C_PANEL, 0.3), 0.95)
	sb.set_corner_radius_all(20)
	sb.border_color = Game.C_GOLD if won else Color(c1, 0.6)
	sb.set_border_width_all(2 if won else 0)
	sb.border_width_bottom = 6
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.alignment = BoxContainer.ALIGNMENT_END if right else BoxContainer.ALIGNMENT_BEGIN
	p.add_child(h)
	var crest := Crest.make(id, 84)
	crest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nm := UI.label(DB.team_name(id), "HeaderLabel", 34)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
	var sc := UI.label(str(score), "TitleLabel", 96, Game.C_SAFFRON if won else Game.C_INK)
	if right:
		h.add_child(sc)
		h.add_child(nm)
		h.add_child(crest)
	else:
		h.add_child(crest)
		h.add_child(nm)
		h.add_child(sc)
	return p


func _bar(v: int, most: int, col: Color, flip: bool) -> Control:
	var bar := ProgressBar.new()
	bar.max_value = most
	bar.value = v
	bar.show_percentage = false
	bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN if flip else ProgressBar.FILL_BEGIN_TO_END
	bar.custom_minimum_size = Vector2(0, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	fill.set_corner_radius_all(99)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _continue(mode: String) -> void:
	match mode:
		"cup":
			Game.show_screen("res://ui/cup_screen.gd")
		"career":
			Game.show_screen("res://ui/career_hub.gd")
		"season":
			Game.show_screen("res://ui/season_hub.gd")
		_:
			Game.goto_menu()
