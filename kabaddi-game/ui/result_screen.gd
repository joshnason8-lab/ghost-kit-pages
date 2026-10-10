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
		art.texture = UI.pose("cup")
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(90, 0)
		art.modulate = Color(Game.C_GOLD, 0.6)
		mh.add_child(art)
		var mv := VBoxContainer.new()
		mv.alignment = BoxContainer.ALIGNMENT_CENTER
		mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mv.add_child(UI.label(tr("PLAYER_OF_MATCH").to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
		var nm := UI.label(String(mvp.name), "HeaderLabel", 34)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mv.add_child(nm)
		mv.add_child(UI.label("%s · %d %s" % [DB.team_name(mvp.team), int(mvp.pts), tr("POINTS_TOTAL")], "MutedLabel", 17))
		mh.add_child(mv)
		row.add_child(mc)
	if mode == "career":
		var cs: Dictionary = result.get("career_stats", {})
		var cl := UI.label("%s: %d · %s: %d" % [tr("STAT_RAID_PTS"), int(cs.get("raid", 0)), tr("STAT_TACKLE_PTS"), int(cs.get("tackle", 0))], "SubLabel", 22, Game.C_GOLD)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cl)

	var go := UI.button(tr("CONTINUE"), true, _continue.bind(mode))
	go.custom_minimum_size = Vector2(340, 72)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(go)


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
