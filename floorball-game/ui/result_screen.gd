extends Control
## After the final horn: the result and the box score as a floorball match report has it. The score by period, the
## shots on goal and saves, the penalty minutes and power-play goals, face-offs won; every goal with its time,
## scorer and assist (one assist, as floorball records it) and whether on the power play; every penalty with its
## offence and rule; and the player of the match.

var result := {}


func setup(args: Dictionary) -> void:
	result = args.get("result", {})


func _ready() -> void:
	UI.screen(self)
	var cfg: Dictionary = result.get("config", {})
	var back := func():
		if String(cfg.get("mode", "quick")) == "cup":
			Game.show_screen("res://ui/cup_screen.gd")
		elif String(cfg.get("mode", "quick")) == "season":
			Game.show_screen("res://ui/season_screen.gd")
		else:
			Game.goto_menu()
	var v := UI.page(self, tr("FULL_TIME"), back, String(cfg.get("stage", "")))
	var g: Array = result.get("goals", [0, 0])
	var ids := [String(cfg.get("home", "SWE")), String(cfg.get("away", "FIN"))]
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	for side in 2:
		var nm := UI.fit(UI.label(DB.team_name(ids[side]), "HeaderLabel", 46), 1)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if side == 0 else HORIZONTAL_ALIGNMENT_LEFT
		var fl := UI.badge(ids[side], Vector2(54, 36))
		fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if side == 0:
			head.add_child(nm)
			head.add_child(fl)
			var sc := UI.label("%d – %d" % [int(g[0]), int(g[1])], "ScoreLabel", 0, Game.C_INK)
			sc.add_theme_font_size_override("font_size", 64)
			head.add_child(sc)
		else:
			head.add_child(fl)
			head.add_child(nm)
	var tag := ""
	if bool(result.get("so", false)):
		tag = tr("AFTER_SHOOTOUT")
	elif bool(result.get("ot", false)):
		tag = tr("AFTER_OT")
	var by_period := _by_period()
	var line := tr("PERIODS_LINE").format({"p": by_period})
	if tag != "":
		line += " · " + tag
	var pl := UI.label(line, "MutedLabel", 18)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(pl)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	cols.add_child(right)
	v.add_child(UI.scroll(cols))
	left.add_child(_team_stats(ids))
	left.add_child(_potm())
	right.add_child(_goals(ids))
	right.add_child(_penalties(ids))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	if String(cfg.get("mode", "quick")) == "quick":
		row.add_child(UI.button(tr("REMATCH"), false, func():
			var c: Dictionary = cfg.duplicate()
			c.erase("seed")
			Game.start_match(c)))
	row.add_child(UI.button(tr("CONTINUE"), true, back))


func _by_period() -> String:
	var per := {}
	var n := maxi(3, int(result.get("periods", 3)))
	for e in result.get("log", []):
		if String(e.kind) == "goal":
			var p := int(e.period)
			if not per.has(p):
				per[p] = [0, 0]
			per[p][int(e.team)] += 1
	var bits := PackedStringArray()
	for p in range(1, mini(n, 4) + 1):
		var x: Array = per.get(p, [0, 0])
		if p <= 3 or (x[0] + x[1]) > 0 or bool(result.get("ot", false)):
			bits.append("%d–%d" % [x[0], x[1]])
	return ", ".join(bits)


func _team_stats(ids: Array) -> PanelContainer:
	var sec: Array = UI.section(tr("BOX_SCORE"), "book")
	var ts: Array = result.get("team_stats", [{}, {}])
	var st: Dictionary = result.get("stats", {})
	var saves := [0, 0]
	var sa := [0, 0]
	var pim := [0, 0]
	for id in st:
		var s: Dictionary = st[id]
		saves[int(s.team)] += int(s.saves)
		sa[int(s.team)] += int(s.sa)
		pim[int(s.team)] += int(s.pim)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	grid.add_child(UI.label("", "EyebrowLabel"))
	for side in 2:
		grid.add_child(UI.label(ids[side], "EyebrowLabel", 16))
	var rows := [
		[tr("ST_SOG"), str(int(ts[0].get("sog", 0))), str(int(ts[1].get("sog", 0)))],
		[tr("ST_SHOTS"), str(int(ts[0].get("shots", 0))), str(int(ts[1].get("shots", 0)))],
		[tr("ST_SAVES"), _pct(saves[0], sa[0]), _pct(saves[1], sa[1])],
		[tr("ST_PIM"), str(pim[0]), str(pim[1])],
		[tr("ST_PPG"), str(int(ts[0].get("ppg", 0))), str(int(ts[1].get("ppg", 0)))],
		[tr("ST_FO"), str(int(ts[0].get("fo", 0))), str(int(ts[1].get("fo", 0)))],
		[tr("ST_BLOCKED"), str(int(ts[0].get("blocked", 0))), str(int(ts[1].get("blocked", 0)))],
	]
	for r in rows:
		var l := UI.fit(UI.label(r[0], "", 18), 2)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		grid.add_child(UI.label(r[1], "SubLabel", 18))
		grid.add_child(UI.label(r[2], "SubLabel", 18))
	sec[1].add_child(grid)
	return sec[0]


func _pct(a: int, b: int) -> String:
	if b <= 0:
		return "–"
	return "%d/%d (%d%%)" % [a, b, roundi(100.0 * a / b)]


func _name(id: String) -> String:
	var st: Dictionary = result.get("stats", {})
	if st.has(id):
		return "#%d %s" % [int(st[id].num), String(st[id].name)]
	return "–"


func _time(e: Dictionary) -> String:
	var t := int(e.get("t", 0))
	var p := int(e.get("period", 1))
	return "%s %02d:%02d" % [tr("OT_SHORT") if p > 3 else tr("PERIOD_N").format({"n": p}), t / 60, t % 60]


func _goals(ids: Array) -> PanelContainer:
	var sec: Array = UI.section(tr("GOALS"), "ball")
	var any := false
	for e in result.get("log", []):
		if String(e.kind) != "goal":
			continue
		any = true
		var bits := [_time(e), ids[int(e.team)], _name(String(e.get("scorer", ""))) if String(e.get("scorer", "")) != "" else tr("OWN_GOAL")]
		if String(e.get("assist", "")) != "":
			bits.append(tr("ASSIST_SHORT") + " " + _name(String(e.assist)))
		if bool(e.get("pp", false)):
			bits.append(tr("PP_SHORT"))
		if bool(e.get("sh", false)):
			bits.append(tr("SH_SHORT"))
		var l := UI.wrap(UI.bits(bits), "", 17)
		sec[1].add_child(l)
	if not any:
		sec[1].add_child(UI.label(tr("NO_GOALS"), "MutedLabel", 17))
	var so: Array = result.get("shootout", [[], []])
	if not (so[0] as Array).is_empty():
		var s := PackedStringArray()
		for t in 2:
			var marks := ""
			for k in so[t]:
				marks += "●" if k else "○"
			s.append("%s %s" % [ids[t], marks])
		sec[1].add_child(UI.label(tr("SHOOTOUT") + ": " + "  ".join(s), "SubLabel", 17))
	return sec[0]


func _penalties(ids: Array) -> PanelContainer:
	var sec: Array = UI.section(tr("PENALTIES"), "whistle")
	var any := false
	for e in result.get("log", []):
		if String(e.kind) != "penalty":
			continue
		any = true
		var mins = {"pen2": "2 min", "pen5": "5 min", "pen10": "10 min", "match": tr("MATCH_PEN")}.get(String(e.pen), "2 min")
		var why := String(e.get("offence", ""))
		var bits := [_time(e), ids[int(e.team)], _name(String(e.id)), mins]
		if why != "":
			bits.append("%s (%s)" % [tr("OFF_" + why.to_upper()), Rules.offence_rule(why)])
		sec[1].add_child(UI.wrap(UI.bits(bits), "", 17))
	if not any:
		sec[1].add_child(UI.label(tr("NO_PENALTIES"), "MutedLabel", 17))
	return sec[0]


func _potm() -> PanelContainer:
	var sec: Array = UI.section(tr("POTM"), "star")
	var id := String(result.get("potm", ""))
	var st: Dictionary = result.get("stats", {})
	if st.has(id):
		var s: Dictionary = st[id]
		sec[1].add_child(UI.fit(UI.label(_name(id), "SubLabel", 24, Game.C_BLUE), 2))
		var line := ""
		if String(s.role) == "G":
			line = tr("POTM_GK").format({"s": int(s.saves), "a": int(s.sa)})
		else:
			line = tr("POTM_LINE").format({"g": int(s.g), "a": int(s.a), "s": int(s.sog)})
		sec[1].add_child(UI.wrap(line, "MutedLabel", 17))
	return sec[0]
