extends Control
## Nations Cup hub: pick a country, follow the groups, play or simulate your matches.


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var cup = Game.get_cup()
	if cup == null:
		_pick_country()
	else:
		_hub(cup)


func _pick_country() -> void:
	var v := UI.page(self, tr("CUP_PICK"), func(): Game.goto_menu(), tr("MENU_CUP"))
	v.add_child(UI.team_grid(self, DB.country_ids, 4, func(id):
		Game.new_cup(id)
		Game.show_screen("res://ui/cup_screen.gd")))


func _hub(cup) -> void:
	var v := UI.page(self, tr("MENU_CUP"), func(): Game.goto_menu(), cup.stage_name())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 26)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)

	# Left: groups.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for g in ["A", "B"]:
		var c := UI.card()
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		cv.add_child(UI.label(tr("GROUP").format({"g": g}), "SubLabel", 22, Game.C_SAFFRON))
		cv.add_child(UI.table(self, cup.standings(g), cup.user))
		c.add_child(cv)
		left.add_child(c)
	left.add_child(UI.label(tr("QUALIFY_NOTE"), "MutedLabel", 17))
	cols.add_child(UI.scroll(left))

	# Right: next match and fixtures.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	right.custom_minimum_size = Vector2(470, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var next = cup.next_user_fixture()
	var card := UI.card()
	var cv2 := VBoxContainer.new()
	cv2.add_theme_constant_override("separation", 12)
	card.add_child(cv2)
	if cup.stage == "done":
		var champ := UI.wrap(tr("CUP_WINNER").format({"team": DB.team_name(cup.champion)}), "HeaderLabel", 40)
		champ.add_theme_color_override("font_color", Game.C_GOLD if cup.champion == cup.user else Game.C_INK)
		cv2.add_child(champ)
		if cup.champion == cup.user:
			cv2.add_child(UI.button(tr("SEE_TROPHY"), false, func(): Game.show_screen("res://ui/trophy_screen.gd", {"team": cup.user, "title": tr("MENU_CUP"), "back": "res://ui/cup_screen.gd"})))
		cv2.add_child(UI.button(tr("CUP_RESTART"), true, func():
			Game.delete_cup()
			Game.show_screen("res://ui/cup_screen.gd")))
	elif next != null:
		cv2.add_child(UI.label(_stage_label(next).to_upper(), "EyebrowLabel"))
		cv2.add_child(UI.fixture_line(self, next, cup.user))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var play := UI.button(tr("PLAY_MATCH"), true, func(): _play(cup, next))
		play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sim := UI.button(tr("SIM_MATCH"), false, func():
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			var mine: String = cup.user
			var opp: String = next.away if next.home == mine else next.home
			var sc := DB.simulate(DB.team_rating(DB.team(mine).squad), DB.team_rating(DB.team(opp).squad), rng, next.stage != "group")
			cup.record_user_result({"score": sc})
			Game.save_cup()
			Game.show_screen("res://ui/cup_screen.gd"))
		row.add_child(play)
		row.add_child(sim)
		cv2.add_child(row)
	else:
		cv2.add_child(UI.label(tr("ELIMINATED"), "HeaderLabel", 40, Game.C_MAGENTA))
		cv2.add_child(UI.button(tr("SIM_MATCH"), true, func():
			cup.sim_everything_left()
			Game.save_cup()
			Game.show_screen("res://ui/cup_screen.gd")))
	right.add_child(card)

	var fx := VBoxContainer.new()
	fx.add_theme_constant_override("separation", 6)
	var last_stage := ""
	for f in cup.fixtures:
		var key := "%s%s" % [f.stage, f.round]
		if key != last_stage:
			last_stage = key
			fx.add_child(UI.label(_stage_label(f).to_upper(), "EyebrowLabel", 14))
		fx.add_child(UI.fixture_line(self, f, cup.user))
	right.add_child(UI.scroll(fx))
	cols.add_child(right)


func _stage_label(f: Dictionary) -> String:
	match String(f.stage):
		"semi":
			return tr("SEMI_FINAL")
		"final":
			return tr("FINAL")
	return "%s · %s" % [tr("GROUP").format({"g": f.group}), tr("MATCHDAY").format({"n": f.round})]


func _play(cup, f: Dictionary) -> void:
	var opp: String = f.away if f.home == cup.user else f.home
	var arenas := ["stadium", "dome", "stadium", "monsoon", "stadium"]
	Game.start_match({
		"home": cup.user, "away": opp, "arena": arenas[int(f.round) - 1] if f.stage == "group" else "stadium",
		"mode": "cup", "control": "all", "length": int(Game.settings.length),
		"difficulty": int(Game.settings.difficulty), "knockout": f.stage != "group",
	})
