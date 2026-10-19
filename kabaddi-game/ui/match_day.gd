extends Control
## Match day in the League Season: the preview (both sides' form, where they stand, the last meeting, the key
## battles, who the other side is missing) and your seven for the match, picked from the squad with each player's
## rating, form, fitness and any knock. Then play it or simulate it.

var season
var fixture: Dictionary
var opp := ""
var picked: Array = []      # pids
var _grid: GridContainer
var _count: Label
var _ratings: Label
var _play: Button
var _sim: Button
var _hint: Label


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	season = Game.get_season()
	if season == null or season.next_user_fixture() == null:
		Game.show_screen("res://ui/season_hub.gd")
		return
	fixture = season.next_user_fixture()
	opp = fixture.away if fixture.home == season.team else fixture.home
	for p in season.seven(season.team):
		picked.append(String(p.id))
	var stage := tr("MATCHDAY").format({"n": fixture.round}) if fixture.stage == "league" else _stage_name(String(fixture.stage))
	var v := UI.page(self, "%s %s %s" % [DB.team_name(season.team), tr("VS"), DB.team_name(opp)], _back, stage)
	var head: HBoxContainer = get_meta("header_right")
	var derby: String = season.derby_of(season.team, opp)
	if derby != "":
		head.add_child(UI.pill(tr(derby).to_upper(), Game.C_MAGENTA, true))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var prev := _preview()
	prev.size_flags_stretch_ratio = 0.68
	cols.add_child(prev)
	cols.add_child(_lineup())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	_hint = UI.label("", "MutedLabel", 16)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(_hint)
	_sim = UI.button(tr("SIM_MATCH"), false, _simulate)
	_sim.custom_minimum_size = Vector2(220, 66)
	foot.add_child(_sim)
	_play = UI.button(tr("PLAY_MATCH"), true, _start)
	_play.custom_minimum_size = Vector2(320, 70)
	foot.add_child(_play)
	v.add_child(foot)
	_refresh()


func _stage_name(st: String) -> String:
	match st:
		"eliminator":
			return tr("ELIMINATOR")
		"semi":
			return tr("SEMI_FINAL")
	return tr("FINAL")


func _back() -> void:
	_keep()
	Game.show_screen("res://ui/season_hub.gd")


func _keep() -> void:
	season.lineup = picked.duplicate() if picked.size() == 7 else []
	Game.save_season()


# ---------------------------------------------------------------- the preview

func _preview() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card := UI.card()
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	cv.add_child(UI.label(tr("FORM_GUIDE").to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
	var table: Array = season.standings()
	for id in [season.team, opp]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(Crest.make(id, 30))
		var nm := UI.label(DB.team_name(id), "SubLabel", 17, Game.C_SAFFRON if id == season.team else Game.C_INK)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.fit(nm)
		nm.custom_minimum_size = Vector2(90, 0)
		row.add_child(nm)
		var pos := 0
		for i in table.size():
			if table[i].id == id:
				pos = i + 1
		if fixture.stage == "league" and int(table[0].p) > 0:
			row.add_child(UI.label(tr("POSITION_N").format({"n": pos}), "MutedLabel", 15))
		var res: Array = season.team_form(id)
		if res.is_empty():
			row.add_child(UI.label("—", "MutedLabel", 15))
		for r in res:
			row.add_child(_result_chip(String(r)))
		cv.add_child(row)
	var last: Dictionary = season.last_meeting(season.team, opp)
	cv.add_child(UI.label(tr("LAST_MEETING").to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
	if last.is_empty():
		cv.add_child(UI.label(tr("FIRST_MEETING"), "MutedLabel", 16))
	else:
		var when := tr("SEASON").format({"n": int(last.year)}) + " · " + (tr("MATCHDAY").format({"n": int(last.round)}) if String(last.stage) == "league" else _stage_name(String(last.stage)))
		cv.add_child(UI.label(when, "MutedLabel", 15))
		var f := {"home": String(last.home), "away": String(last.away), "played": true, "score": [int(last.score[0]), int(last.score[1])]}
		cv.add_child(UI.fixture_line(self, f, season.team))
	cv.add_child(UI.label(tr("KEY_BATTLES").to_upper(), "EyebrowLabel", 14, Game.C_GOLD))
	for pair in season.key_battles(opp):
		if (pair[0] as Dictionary).is_empty() or (pair[1] as Dictionary).is_empty():
			continue
		cv.add_child(_battle(pair[0], pair[1]))
	var hurt := []
	for p in season.squads[opp]:
		if season.injured(p) > 0:
			hurt.append(String(p.name))
	if not hurt.is_empty():
		var hl := UI.label(tr("THEY_ARE_MISSING").format({"names": ", ".join(hurt)}), "MutedLabel", 15)
		hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(hl)
	v.add_child(UI.scroll(card))
	return v


func _result_chip(r: String) -> PanelContainer:
	var col := Game.C_GOOD if r == "W" else (Game.C_DANGER if r == "L" else Game.C_GOLD)
	var key: String = {"W": "RESULT_W", "L": "RESULT_L", "T": "RESULT_T"}[r]
	var p := UI.pill(tr(key), col, true)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## Their raider against your tackler (or yours against theirs): names, ratings and form either side.
func _battle(raider: Dictionary, tackler: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for i in 2:
		var p: Dictionary = raider if i == 0 else tackler
		var mine: bool = (season.squads[season.team] as Array).has(p)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -2)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := UI.label(String(p.name), "SubLabel", 16, Game.C_SAFFRON if mine else Game.C_INK)
		UI.fit(nm)
		if i == 1:
			nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(nm)
		var what := "%s %d" % [tr("ROLE_RAIDER") if i == 0 else tr("TACKLER"), DB.overall(p)]
		var wl := UI.label(what, "MutedLabel", 14)
		if i == 1:
			wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.add_child(wl)
		if i == 1:
			h.add_child(UI.label(tr("VS"), "EyebrowLabel", 14, Game.C_MAGENTA))
		h.add_child(box)
	return h


# ---------------------------------------------------------------- your seven

func _lineup() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_count = UI.label("", "EyebrowLabel", 15, Game.C_GOLD)
	top.add_child(_count)
	_ratings = UI.label("", "MutedLabel", 15)
	_ratings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_ratings)
	var best := UI.button(tr("BEST_SEVEN"), false, func():
		picked = []
		season.lineup = []
		for p in season.best_seven(season.team):
			picked.append(String(p.id))
		_refresh())
	best.custom_minimum_size = Vector2(0, 46)
	top.add_child(best)
	v.add_child(top)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	v.add_child(UI.scroll(_grid))
	return v


func _refresh() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var sq: Array = season.squads[season.team].duplicate()
	var order := {"raider": 0, "allrounder": 1, "defender": 2}
	sq.sort_custom(func(a, b): return order[a.role] < order[b.role] or (order[a.role] == order[b.role] and DB.overall(a) > DB.overall(b)))
	for p in sq:
		var pid := String(p.id)
		var out: int = season.injured(p)
		var info := {"selected": picked.has(pid), "form": season.form_of(p), "fit": season.fit(p), "injured": out, "dim": out > 0}
		_grid.add_child(PlayerCard.make(p, info, _toggle.bind(pid, out)))
	_count.text = tr("YOUR_SEVEN").format({"n": picked.size()}).to_upper()
	var mine := []
	for p in sq:
		if picked.has(String(p.id)):
			mine.append(p)
	var raiders := 0
	for p in mine:
		if String(p.role) != "defender":
			raiders += 1
	_ratings.text = tr("RATING_VS").format({"a": int(round(season._power(mine))), "b": season.rating(opp)})
	var ok := picked.size() == 7
	_play.disabled = not ok
	_sim.disabled = not ok
	if not ok:
		_hint.text = tr("PICK_SEVEN_HINT").format({"n": 7 - picked.size()}) if picked.size() < 7 else tr("PICK_SEVEN_TOO_MANY")
	elif raiders < 2:
		_hint.text = tr("FEW_RAIDERS_HINT")
	else:
		_hint.text = tr("LINEUP_HINT")


func _toggle(pid: String, out: int) -> void:
	if picked.has(pid):
		picked.erase(pid)
	elif out > 0:
		_hint.text = tr("PLAYER_INJURED_HINT")
		return
	elif picked.size() >= 7:
		_hint.text = tr("PICK_SEVEN_TOO_MANY")
		return
	else:
		picked.append(pid)
	_refresh()


func _start() -> void:
	_keep()
	Game.start_match(season.match_config(fixture))


func _simulate() -> void:
	_keep()
	season.simulate_user_match()
	Game.save_season()
	Game.show_screen("res://ui/season_hub.gd")
