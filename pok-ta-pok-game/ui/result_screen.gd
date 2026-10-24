extends Control
## After the match: who won and how the count ended (the rayas as tally strokes, or the points; the ring if it came),
## then the box score: how each town won its rayas (the ball died in the other half, past the end, out, a touch, the
## ring), its strikes, dives and serves, the faults, the longest rally, and each player's line. The best on the court
## is named. The page scrolls from anywhere on it.

var r := {}


func setup(args: Dictionary) -> void:
	r = args.get("result", {})


func _ready() -> void:
	UI.screen(self)
	var cup := String(r.get("config", {}).get("mode", "")) == "cup"
	var v := UI.page(self, tr("RESULT"), func(): _leave(cup), String(r.get("config", {}).get("stage", "")))
	var right: HBoxContainer = get_meta("header_right")
	if not cup and int(r.get("user_team", -1)) >= 0:
		right.add_child(UI.button(tr("PLAY_AGAIN"), false, func(): Game.start_match(r.config)))
	var go := UI.button(tr("CONTINUE"), true, func(): _leave(cup))
	go.custom_minimum_size = Vector2(200, 64)
	right.add_child(go)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	v.add_child(UI.scroll(col))
	col.add_child(_headline())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	col.add_child(cols)
	cols.add_child(_team_box())
	cols.add_child(_player_box())
	var star := String(r.get("star", ""))
	if r.get("pstats", {}).has(star):
		var s: Dictionary = r.pstats[star]
		var line := UI.wrap(tr("BEST_ON_COURT").format({"name": String(s.name), "town": DB.short_name(String(r.home if int(s.team) == 0 else r.away))}), "SubLabel", 19)
		line.add_theme_color_override("font_color", Game.C_GOLD)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(line)


func _leave(cup: bool) -> void:
	if cup:
		Game.show_screen("res://ui/cup_screen.gd")
	else:
		Game.goto_menu()


func _headline() -> Control:
	var card := UI.card()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)
	var w := int(r.get("winner", -1))
	var c: Dictionary = r.get("count", {})
	var who := String(r.home if w == 0 else r.away) if w >= 0 else ""
	var title := UI.label(tr("WINS").format({"team": DB.short_name(who)}) if w >= 0 else tr("NO_RESULT"), "HeaderLabel", 44, Game.C_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.shrink(title, 44, 0.6, 1)
	v.add_child(title)
	var how := ""
	if bool(c.get("ring", false)):
		how = tr("RESULT_RING")
	elif String(c.get("rules", "ulama")) == Rules.CLASSIC:
		var pts: Array = c.get("points", [0, 0])
		how = tr("RESULT_POINTS").format({"a": DB.short_name(String(r.home)), "x": int(pts[0]), "b": DB.short_name(String(r.away)), "y": int(pts[1])})
	elif bool(r.get("timed", false)):
		how = Plural.word("RESULT_TIMED", int(c.get("rayas", 0))).format({"team": DB.short_name(who)})
	else:
		how = tr("RESULT_EIGHT")
	var sub := UI.label(how, "SubLabel", 20, Game.C_INK)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fit(sub, 2)
	v.add_child(sub)
	var meta := UI.label(UI.bits([tr("VENUE_" + String(r.get("config", {}).get("venue", "village")).to_upper()),
		Plural.word("MINUTES_PLAYED", roundi(float(r.get("minutes", 0.0)))), Plural.word("RAYAS_PLAYED", r.get("log", []).size())]), "MutedLabel", 16)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(meta)
	return card


## The towns side by side: each row a statistic.
func _team_box() -> Control:
	var sec: Array = UI.section(tr("BOX_SCORE"), "gavel")
	sec[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sec[0].mouse_filter = Control.MOUSE_FILTER_PASS
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 6)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sec[1].add_child(g)
	var ts: Array = r.get("tstats", [{}, {}])
	_cell(g, "", "")
	for id in [String(r.home), String(r.away)]:
		var h := UI.label(DB.short_name(id), "SubLabel", 16)
		h.custom_minimum_size = Vector2(124, 0)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.fit(h, 2)
		g.add_child(h)
	for row in [["BOX_RAYAS", "rayas"], ["BOX_DEAD", "dead"], ["BOX_END", "end"], ["BOX_WON_OUT", "won_out"], ["BOX_WON_TOUCH", "won_touch"],
			["BOX_RING", "ring"], ["BOX_STRIKES", "strikes"], ["BOX_DIVES", "dives"], ["BOX_SERVES", "serves"],
			["BOX_FAULT_TOUCH", "faults_touch"], ["BOX_FAULT_OUT", "faults_out"]]:
		_cell(g, tr(row[0]), "MutedLabel")
		for k in 2:
			_cell(g, str(int(ts[k].get(row[1], 0))) if ts.size() > k else "0", "")
	var lr := UI.label(tr("LONGEST_RALLY").format({"n": int(r.get("longest_rally", 0))}), "MutedLabel", 16)
	lr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sec[1].add_child(lr)
	return sec[0]


func _player_box() -> Control:
	var sec: Array = UI.section(tr("PLAYERS"), "people")
	sec[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sec[0].mouse_filter = Control.MOUSE_FILTER_PASS
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 4)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sec[1].add_child(g)
	for h in ["", tr("COL_STRIKES"), tr("COL_DIVES"), tr("COL_RAYAS"), tr("COL_FAULTS")]:
		_cell(g, h, "EyebrowLabel")
	var ps: Dictionary = r.get("pstats", {})
	for k in 2:
		for id in ps:
			var s: Dictionary = ps[id]
			if int(s.team) != k:
				continue
			var n := UI.label(String(s.name), "", 16, DB.team(String(r.home if k == 0 else r.away)).c1.lightened(0.35))
			n.custom_minimum_size = Vector2(120, 0)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
			UI.fit(n, 1)
			g.add_child(n)
			for key in ["strikes", "dives", "rayas", "faults"]:
				_cell(g, str(int(s.get(key, 0))), "")
	return sec[0]


func _cell(g: GridContainer, text: String, variation: String) -> void:
	var l := UI.label(text, variation, 16)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if variation == "MutedLabel":
		l.custom_minimum_size = Vector2(150, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.fit(l, 2)
	# Numbers and short headings take the room they need.
	g.add_child(l)
