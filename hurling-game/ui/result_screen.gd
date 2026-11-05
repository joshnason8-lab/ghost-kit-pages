extends Control
## After the final whistle, the way the paper reports a game the next morning: the result in big type (winner,
## goals-points and the total), "after extra time" or the penalties if it came to that; the scorers for each side
## in the papers' style ("S. Ó Briain 0-7 (0-5f, 0-1 '65')"); the box score of the match (scores from play and from
## placed balls, wides, frees, 65s, puck-outs, cards); the player of the match; on to the next thing.

var result := {}


func setup(args: Dictionary) -> void:
	result = args.get("result", {})


func _ready() -> void:
	UI.screen(self)
	var cfg: Dictionary = result.get("config", {})
	var user := int(result.get("user_team", -1))
	var ids := [String(result.home), String(result.away)]
	var w := int(result.get("winner", -1))
	var title := tr("RESULT_DRAW") if w < 0 else (tr("RESULT_WON") if w == user else (tr("RESULT_LOST") if user >= 0 else tr("FULL_TIME")))
	var v := UI.page(self, title, Callable(), String(cfg.get("stage", "")))
	var right: HBoxContainer = get_meta("header_right")
	var next := _next_button(cfg)
	right.add_child(next)
	set_meta("back", func(): next.pressed.emit())
	Sfx.react("cheer" if w == user and user >= 0 else "applause", -6.0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	v.add_child(UI.scroll(body))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	body.add_child(cols)
	# The report: on newspaper paper.
	var paper := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Game.C_PAPER
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	paper.add_theme_stylebox_override("panel", sb)
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.size_flags_stretch_ratio = 1.3
	cols.add_child(paper)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	paper.add_child(pv)
	var sc: Array = result.get("score", [[0, 0], [0, 0]])
	for k in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(Colours.make(ids[k], 40))
		var nm := UI.label(DB.team_name(ids[k]), "HeaderLabel", 36, Game.C_PRINT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.shrink(nm, 36, 0.6, 1)
		row.add_child(nm)
		var s := UI.label(Rules.fmt(int(sc[k][0]), int(sc[k][1])), "ScoreLabel", 44, Game.C_MAGENTA if k == w else Game.C_PRINT)
		row.add_child(s)
		var t := UI.label("(%d)" % Rules.total(int(sc[k][0]), int(sc[k][1])), "SubLabel", 22, Color(Game.C_PRINT, 0.6))
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(t)
		pv.add_child(row)
	if w >= 0:
		var margin := absi(Rules.total(int(sc[0][0]), int(sc[0][1])) - Rules.total(int(sc[1][0]), int(sc[1][1])))
		if margin > 0:
			pv.add_child(_ink(tr("WON_BY").format({"team": DB.team_name(ids[w]), "margin": Plural.word("MARGIN", margin)}), "SubLabel", 19))
	var so: Dictionary = result.get("shootout", {})
	if not so.is_empty():
		pv.add_child(_ink(tr("AFTER_PENS").format({"a": int(so.goals[0]), "b": int(so.goals[1])}), "SubLabel", 19))
	elif bool(result.get("extra_time", false)):
		pv.add_child(_ink(tr("AFTER_ET"), "SubLabel", 19))
	var rule := ColorRect.new()
	rule.color = Color(Game.C_PRINT, 0.35)
	rule.custom_minimum_size = Vector2(0, 2)
	pv.add_child(rule)
	pv.add_child(_ink(tr("SCORERS").to_upper(), "EyebrowLabel", 15, Color(Game.C_PRINT, 0.7)))
	for k in 2:
		var line := _scorers(k)
		var l := _ink("[b]%s:[/b] %s" % [DB.team_name(ids[k]), line if line != "" else tr("NO_SCORERS")], "", 17)
		pv.add_child(l)
	var star := String(result.get("star", ""))
	if star != "":
		var pd := _player(star)
		if not pd.is_empty():
			pv.add_child(_ink("[b]%s[/b] %s (%s)" % [tr("PLAYER_OF_MATCH"), DB.player_name(pd), DB.team_name(String(pd.team))], "", 17))
	# The box score.
	var box := UI.card()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(box)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	box.add_child(bv)
	bv.add_child(UI.label(tr("MATCH_STATS").to_upper(), "EyebrowLabel", 16, Game.C_SAFFRON))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 5)
	g.add_child(UI.label("", "EyebrowLabel"))
	for k in 2:
		var hn := UI.label(DB.short_name(ids[k]), "SubLabel", 19)
		hn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(hn)
	var ts: Array = result.get("tstats", [{}, {}])
	var rows := [["STAT_SCORES_PLAY", "scores_play"], ["STAT_SCORES_PLACED", "scores_placed"], ["STAT_SHOTS", "shots"],
		["STAT_WIDES", "wides"], ["STAT_FREES", "frees"], ["STAT_65S", "s65"], ["STAT_SIDELINES", "sidelines"],
		["STAT_PUCKOUTS", "puckouts"], ["STAT_YELLOW", "yellow"], ["STAT_BLACK", "black"], ["STAT_RED", "red"]]
	for r in rows:
		var lab := UI.label(tr(r[0]), "", 17, Game.C_MUTED)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.fit(lab, 2)
		g.add_child(lab)
		for k in 2:
			var n := UI.label(str(int((ts[k] as Dictionary).get(r[1], 0))), "SubLabel", 18)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			n.custom_minimum_size = Vector2(56, 0)
			g.add_child(n)
	bv.add_child(g)


func _ink(text: String, variation: String, size: int, col := Game.C_PRINT) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.add_theme_font_override("normal_font", Game.font_bold if variation != "" else Game.font_body)
	rt.add_theme_font_override("bold_font", Game.font_bold)
	rt.add_theme_font_size_override("normal_font_size", Game.ts(size))
	rt.add_theme_font_size_override("bold_font_size", Game.ts(size))
	rt.add_theme_color_override("default_color", col)
	rt.text = text
	return rt


func _player(id: String) -> Dictionary:
	var team := id.split("_")[0]
	for p in DB.squad(team):
		if String(p.id) == id:
			return p
	return {}


## The scorers, as the papers print them: most first, each with goals-points and what came from frees and 65s.
func _scorers(k: int) -> String:
	var ps: Dictionary = result.get("pstats", {})
	var list := []
	for id in ps:
		var s: Dictionary = ps[id]
		if int(s.team) == k and int(s.goals) + int(s.points) > 0:
			list.append([id, s])
	list.sort_custom(func(a, b): return int(a[1].goals) * 3 + int(a[1].points) > int(b[1].goals) * 3 + int(b[1].points))
	var parts := []
	for e in list:
		var s: Dictionary = e[1]
		var pd := _player(String(e[0]))
		var name := DB.player_name(pd, true) if not pd.is_empty() else String(e[0])
		var extra := ""
		if int(s.free_g) + int(s.free_p) > 0:
			extra = " (%s%s)" % [Rules.fmt(int(s.free_g), int(s.free_p)), tr("FREES_SHORT")]
		parts.append("%s %s%s" % [name, Rules.fmt(int(s.goals), int(s.points)), extra])
	return ", ".join(parts)


func _next_button(cfg: Dictionary) -> Button:
	match String(cfg.get("mode", "quick")):
		"champ":
			return UI.button(tr("CONTINUE"), true, func(): Game.show_screen("res://ui/champ_screen.gd"))
	return UI.button(tr("HOME"), true, func(): Game.goto_menu())
