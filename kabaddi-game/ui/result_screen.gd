extends Control
## Full-time scorecard, then back to whichever mode the match came from.

var result := {}


func setup(args: Dictionary) -> void:
	result = args.get("result", {})


func _ready() -> void:
	UI.screen(self)
	Sfx.stop_all()
	var cfg: Dictionary = result.get("config", {})
	var mode := String(cfg.get("mode", "quick"))
	var v := UI.page(self, tr("FULL_TIME"), Callable(), tr("SCORECARD"))
	var s: Array = result.score
	var w := int(result.winner)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 36)
	for t in 2:
		var id: String = result.home if t == 0 else result.away
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var sw := UI.swatch(DB.team(id).c1, Vector2(160, 8))
		col.add_child(sw)
		var nm := UI.label(DB.team_name(id), "SubLabel", 26)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(nm)
		var sc := UI.label(str(s[t]), "TitleLabel", 110, Game.C_SAFFRON if t == w else Game.C_INK)
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(sc)
		head.add_child(col)
		if t == 0:
			head.add_child(UI.label("–", "TitleLabel", 80, Game.C_MUTED))
	v.add_child(head)
	var verdict := tr("MATCH_TIED") if w < 0 else tr("TEAM_WINS").format({"team": DB.team_name(result.home if w == 0 else result.away)})
	var vl := UI.label(verdict, "HeaderLabel", 44)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(vl)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bd: Array = result.breakdown
	for row in [["STAT_RAID_PTS", "raid"], ["STAT_TACKLE_PTS", "tackle"], ["STAT_ALL_OUT_PTS", "allout"], ["STAT_EXTRA_PTS", "extra"]]:
		var a := UI.label(str(int(bd[0][row[1]])), "SubLabel", 24)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		a.custom_minimum_size = Vector2(80, 0)
		var mid := UI.label(tr(row[0]), "MutedLabel", 20)
		mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mid.custom_minimum_size = Vector2(260, 0)
		var b := UI.label(str(int(bd[1][row[1]])), "SubLabel", 24)
		grid.add_child(a)
		grid.add_child(mid)
		grid.add_child(b)
	v.add_child(grid)

	var mvp: Dictionary = result.get("mvp", {})
	if String(mvp.get("name", "")) != "":
		var ml := UI.label("%s: %s (%s) · %d" % [tr("PLAYER_OF_MATCH"), mvp.name, DB.team_name(mvp.team), int(mvp.pts)], "MutedLabel", 20)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(ml)
	if mode == "career":
		var cs: Dictionary = result.get("career_stats", {})
		var cl := UI.label("%s: %d · %s: %d" % [tr("STAT_RAID_PTS"), int(cs.get("raid", 0)), tr("STAT_TACKLE_PTS"), int(cs.get("tackle", 0))], "SubLabel", 22, Game.C_GOLD)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var go := UI.button(tr("CONTINUE"), true, _continue.bind(mode))
	go.custom_minimum_size = Vector2(320, 70)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(go)


func _continue(mode: String) -> void:
	match mode:
		"cup":
			Game.show_screen("res://ui/cup_screen.gd")
		"career":
			Game.show_screen("res://ui/career_hub.gd")
		_:
			Game.goto_menu()
