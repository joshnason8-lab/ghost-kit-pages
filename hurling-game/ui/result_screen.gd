extends Control
## After a match: who won, the sets, each player's spikes, blocks, aces and digs, the player of the match, and on to
## the next thing (the next regu of a team event, the season, the tournament, or home).

var result := {}
var tie := {}
var tie_done := false


func setup(args: Dictionary) -> void:
	result = args.get("result", {})
	tie = args.get("tie", {})
	tie_done = bool(args.get("tie_done", false))


func _ready() -> void:
	UI.screen(self)
	var cfg: Dictionary = result.get("config", {})
	var user := int(result.get("user_team", 0))
	var teams := [String(result.home), String(result.away)]
	var won := int(result.get("winner", 0)) == user
	var v := UI.page(self, tr("RESULT_WON") if won else tr("RESULT_LOST"), Callable(), String(cfg.get("stage", "")))
	var right: HBoxContainer = get_meta("header_right")
	var next := _next_button(cfg)
	right.add_child(next)
	set_meta("back", func(): next.pressed.emit())
	Sfx.react("cheer" if won else "applause", -6.0)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	v.add_child(UI.scroll(body))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	body.add_child(cols)

	# The score: each team, its sets, and the points in each set.
	var sc := UI.card()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(sc)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 10)
	sc.add_child(sv)
	var g := GridContainer.new()
	var set_scores: Array = result.get("set_scores", [])
	g.columns = 3 + set_scores.size()
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 8)
	for k in 2:
		var id := String(result.home if k == 0 else result.away)
		g.add_child(Crest.make(id, 40))
		var nm := UI.fit(UI.label(DB.team_name(id), "SubLabel", 24, Game.C_GOLD if k == int(result.winner) else Game.C_INK), 2)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.custom_minimum_size = Vector2(160, 0)
		g.add_child(nm)
		g.add_child(UI.label(str(int(result.sets[k])), "HeaderLabel", 54, Game.C_SAFFRON))
		for s in set_scores:
			var w: bool = int(s[k]) > int(s[1 - k])
			g.add_child(UI.label(str(int(s[k])), "SubLabel", 24, Game.C_INK if w else Game.C_MUTED))
	sv.add_child(g)
	if not tie.is_empty():
		var wins := [0, 0]
		for r in tie.results:
			wins[0 if int(r[0]) > int(r[1]) else 1] += 1
		var tl := UI.wrap(tr("TIE_SCORE").format({"a": wins[0], "b": wins[1]}) + ("  ·  " + tr("TIE_WON" if wins[user] > wins[1 - user] else ("TIE_DRAWN" if wins[0] == wins[1] else "TIE_LOST")) if tie_done else ""), "SubLabel", 22)
		tl.add_theme_color_override("font_color", Game.C_GOLD)
		sv.add_child(tl)
	var potm: Dictionary = result.get("potm", {})
	if not potm.is_empty():
		var pr := HBoxContainer.new()
		pr.add_theme_constant_override("separation", 12)
		pr.add_child(Icon.make("star", 30, Game.C_GOLD))
		var who := "%s · %s" % [tr("SHIRT_N").format({"n": int(potm.get("num", 0))}), DB.team_name(teams[int(potm.get("team", 0))])]
		var pl := UI.fit(UI.label(tr("PLAYER_OF_MATCH").format({"n": who}), "SubLabel", 22), 2)
		pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pr.add_child(pl)
		sv.add_child(pr)

	# The players' numbers.
	var st := UI.card()
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(st)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	st.add_child(tv)
	tv.add_child(UI.label(tr("MATCH_STATS").to_upper(), "EyebrowLabel", 16, Game.C_SAFFRON))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	for h in [tr("COL_PLAYER"), tr("COL_KILLS"), tr("COL_BLOCKS"), tr("COL_ACES"), tr("COL_DIGS")]:
		grid.add_child(UI.label(h, "EyebrowLabel"))
	var stats: Dictionary = result.get("stats", {})
	var ids := stats.keys()
	ids.sort_custom(func(a, b): return int(stats[a].team) < int(stats[b].team) or (int(stats[a].team) == int(stats[b].team) and int(stats[a].kills) > int(stats[b].kills)))
	for id in ids:
		var s: Dictionary = stats[id]
		var mine := int(s.team) == user
		var nm := UI.fit(UI.label("%s · %s" % [tr("SHIRT_N").format({"n": int(s.num)}), String(DB.team(teams[int(s.team)]).get("short", ""))], "", 18, Game.C_INK if mine else Game.C_MUTED))
		nm.custom_minimum_size = Vector2(170, 0)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(nm)
		for k in ["kills", "blocks", "aces", "digs"]:
			grid.add_child(UI.label(str(int(s[k])), "", 18, Game.C_INK if mine else Game.C_MUTED))
	tv.add_child(grid)


func _next_button(cfg: Dictionary) -> Button:
	if not tie.is_empty() and not tie_done:
		return UI.button(tr("NEXT_REGU"), true, func():
			var c := cfg.duplicate(true)
			c.tie = tie
			c.erase("lineup_0")
			c.erase("lineup_1")
			Game.start_match(c))
	match String(cfg.get("mode", "quick")):
		"season":
			return UI.button(tr("CONTINUE"), true, func(): Game.show_screen("res://ui/season_hub.gd"))
		"cup":
			return UI.button(tr("CONTINUE"), true, func(): Game.show_screen("res://ui/cup_screen.gd"))
	var row := UI.button(tr("REMATCH"), true, func():
		var c := cfg.duplicate(true)
		c.erase("tie")
		c.erase("stage_base")
		c.erase("lineup_0")
		c.erase("lineup_1")
		c.seed = randi()
		Game.start_match(c))
	if has_meta("header_right"):
		(get_meta("header_right") as HBoxContainer).add_child(UI.round_button("close", func(): Game.goto_menu(), 58))
	return row
