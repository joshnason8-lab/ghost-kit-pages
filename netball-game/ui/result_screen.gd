extends Control
## Full time: the result, the score by quarter, the player of the match, and the box score for each team (goals from
## attempts and the shooting percentage, feeds, goal assists, centre pass receives, gains, intercepts, deflections,
## rebounds, penalties and turnovers: the numbers netball's broadcasters show).

var result := {}


func setup(args: Dictionary) -> void:
	result = args.get("result", {})


func _ready() -> void:
	UI.screen(self)
	if Game.test_quarter_s > 0.0 and OS.has_feature("web"):
		JavaScriptBridge.eval("window.cpn = {phase: 'result'}")
	var cfg: Dictionary = result.get("config", {})
	var cup: bool = String(cfg.get("mode", "quick")) in ["cup", "league"]
	var hub := "res://ui/league_screen.gd" if String(cfg.get("mode", "")) == "league" else "res://ui/cup_screen.gd"
	var v := UI.page(self, _headline(), func(): Game.show_screen(hub) if cup else Game.goto_menu(),
		String(cfg.get("stage", tr("FULL_TIME"))))
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	v.add_child(UI.scroll(body))
	# The score, big, with the flags; then the quarters.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(top)
	var score: Array = result.get("score", [0, 0])
	for t in 2:
		var id := String(cfg.get("home" if t == 0 else "away", ""))
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var flag := UI.badge(id, Vector2(84, 56))
		flag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(flag)
		var nm := UI.label(DB.team_name(id), "SubLabel", 22)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nm)
		col.custom_minimum_size = Vector2(220, 0)
		var sc := UI.label(str(score[t]), "TitleLabel", 92)
		if int(result.get("winner", -1)) == t:
			sc.add_theme_color_override("font_color", Game.C_ACCENT)
		if t == 0:
			top.add_child(col)
			top.add_child(sc)
			var dash := UI.label("–", "TitleLabel", 70, Game.C_MUTED)
			top.add_child(dash)
		else:
			top.add_child(sc)
			top.add_child(col)
	var qcard := UI.card()
	qcard.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	qcard.add_child(_quarters())
	body.add_child(qcard)
	var potm := String(result.get("potm", ""))
	if potm != "" and result.stats.has(potm):
		var s: Dictionary = result.stats[potm]
		var pc := UI.card()
		var ph := HBoxContainer.new()
		ph.add_theme_constant_override("separation", 12)
		pc.add_child(ph)
		ph.add_child(Icon.make("star", 34, Game.C_GOLD))
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 0)
		pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ph.add_child(pv)
		pv.add_child(UI.label(tr("PLAYER_OF_MATCH").to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
		pv.add_child(UI.fit(UI.label("%s · %s · %s" % [s.name, s.pos, DB.team_name(String(cfg.get("home" if int(s.team) == 0 else "away", "")))], "SubLabel", 22)))
		body.add_child(pc)
	for t in 2:
		body.add_child(_box(t))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	if cup:
		row.add_child(UI.button(tr("CONTINUE"), true, func(): Game.show_screen(hub)))
	else:
		row.add_child(UI.button(tr("REMATCH"), false, func():
			var c := cfg.duplicate()
			c.erase("seed")
			Game.start_match(c)))
		row.add_child(UI.button(tr("HOME"), true, func(): Game.goto_menu()))


func _headline() -> String:
	var w := int(result.get("winner", -1))
	var ut := int(result.get("user_team", -1))
	if w < 0:
		return tr("RESULT_DRAW")
	if ut >= 0:
		return tr("RESULT_WIN") if w == ut else tr("RESULT_LOSS")
	var cfg: Dictionary = result.get("config", {})
	return tr("RESULT_WINS").format({"team": DB.team_name(String(cfg.get("home" if w == 0 else "away", "")))})


func _quarters() -> GridContainer:
	var qs: Array = result.get("q_scores", [])
	var cfg: Dictionary = result.get("config", {})
	var g := GridContainer.new()
	g.columns = qs.size() + 2
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 6)
	g.add_child(UI.label("", "EyebrowLabel"))
	for i in qs.size():
		g.add_child(UI.label(HUD._pname(i + 1), "EyebrowLabel"))
	g.add_child(UI.label(tr("TOTAL").to_upper(), "EyebrowLabel"))
	for t in 2:
		g.add_child(UI.label(DB.team_abbr(String(cfg.get("home" if t == 0 else "away", ""))), "SubLabel", 20))
		for i in qs.size():
			g.add_child(UI.label(str(qs[i][t]), "", 20))
		g.add_child(UI.label(str(result.score[t]), "SubLabel", 22, Game.C_ACCENT))
	return g


## One team's box score: a row a player who took the court.
func _box(t: int) -> PanelContainer:
	var cfg: Dictionary = result.get("config", {})
	var card := UI.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UI.badge(String(cfg.get("home" if t == 0 else "away", "")), Vector2(36, 24)))
	head.add_child(UI.label(DB.team_name(String(cfg.get("home" if t == 0 else "away", ""))), "SubLabel", 22))
	v.add_child(head)
	var cols := [["", "pos"], ["", "name"], ["BOX_G", "goals"], ["BOX_PCT", "pct"], ["BOX_FEEDS", "feeds"],
		["BOX_ASSISTS", "assists"], ["BOX_CPR", "cpr"], ["BOX_GAINS", "gains"], ["BOX_INT", "intercepts"],
		["BOX_DEF", "deflections"], ["BOX_REB", "rebounds"], ["BOX_PEN", "penalties"], ["BOX_TO", "turnovers"]]
	var g := GridContainer.new()
	g.columns = cols.size()
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 4)
	for c in cols:
		g.add_child(UI.label(tr(c[0]) if c[0] != "" else "", "EyebrowLabel", 13))
	var rows := []
	for id in result.stats:
		var s: Dictionary = result.stats[id]
		if int(s.team) == t and (int(s.passes) + int(s.attempts) + int(s.gains) + int(s.cpr) + int(s.penalties) > 0 or String(s.pos) != ""):
			rows.append(s)
	rows.sort_custom(func(a, b): return Rules.POSITIONS.find(String(a.pos)) < Rules.POSITIONS.find(String(b.pos)))
	for s in rows:
		for c in cols:
			var k: String = c[1]
			var txt := ""
			match k:
				"pos":
					txt = String(s.pos)
				"name":
					txt = String(s.name)
				"goals":
					txt = "%d/%d" % [int(s.goals), int(s.attempts)] if int(s.attempts) > 0 else "–"
				"pct":
					txt = "%d%%" % roundi(100.0 * float(s.goals) / float(s.attempts)) if int(s.attempts) > 0 else "–"
				_:
					txt = str(int(s[k]))
			var l := UI.label(txt, "SubLabel" if k == "pos" else "", 16, Game.C_ACCENT if k == "pos" else Game.C_INK)
			if k == "name":
				UI.fit(l)
				l.custom_minimum_size = Vector2(150, 0)
			g.add_child(l)
	v.add_child(g)
	return card
