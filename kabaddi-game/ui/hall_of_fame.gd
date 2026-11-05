extends Control
## The League Season's hall of fame: every season's champions and award winners, the record book, and the
## all-time leading scorers.

const RECORDS := [
	["raid_match", "REC_RAID_MATCH"], ["tackle_match", "REC_TACKLE_MATCH"], ["score", "REC_SCORE"],
	["margin", "REC_MARGIN"], ["raid_season", "REC_RAID_SEASON"], ["tackle_season", "REC_TACKLE_SEASON"],
]

var season


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	season = Game.get_season()
	if season == null:
		Game.goto_menu()
		return
	var v := UI.page(self, tr("HALL_OF_FAME"), func(): Game.show_screen("res://ui/season_hub.gd"), tr("MENU_SEASON"))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	cols.add_child(_honours())
	cols.add_child(_record_book())
	cols.add_child(_all_time())


func _column(title: String, ratio: float) -> Array:
	var card := UI.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = ratio
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(UI.label(title.to_upper(), "EyebrowLabel", 15, Game.C_GOLD))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	v.add_child(UI.scroll(list))
	return [card, list]


func _honours() -> PanelContainer:
	var cl := _column(tr("ROLL_OF_HONOUR"), 1.1)
	var list: VBoxContainer = cl[1]
	if season.history.is_empty():
		list.add_child(UI.wrap(tr("HOF_EMPTY"), "MutedLabel", 16))
	var hist: Array = season.history.duplicate()
	hist.reverse()
	for h in hist:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 0)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		top.add_child(UI.label(tr("SEASON").format({"n": int(h.year)}).to_upper(), "EyebrowLabel", 14))
		var champ := String(h.get("champion", ""))
		if champ != "":
			top.add_child(Crest.make(champ, 24))
			top.add_child(UI.label(DB.team_name(champ), "SubLabel", 17, Game.C_GOLD if champ == season.team else Game.C_INK))
		box.add_child(top)
		var bits := [tr("YOUR_FINISH").format({"n": int(h.get("finish", 0))})]
		if String(h.get("goal", "")) != "":
			bits.append(tr("BOARD_GOAL_MET_SHORT") if bool(h.get("goal_met", false)) else tr("BOARD_GOAL_MISSED_SHORT"))
		box.add_child(UI.label(" · ".join(bits), "MutedLabel", 14))
		for pair in [["mvp", "ARJUNA_AWARD"], ["raider", "BEST_RAIDER"], ["defender", "BEST_DEFENDER"]]:
			var w: Dictionary = h.get(pair[0], {})
			if w.is_empty():
				continue
			var l := UI.label("%s: %s (%s)" % [tr(pair[1]), String(w.name), String(w.team)], "", 14, Game.C_SAFFRON if String(w.team) == season.team else Game.C_INK)
			UI.fit(l)
			box.add_child(l)
		list.add_child(box)
	return cl[0]


func _record_book() -> PanelContainer:
	var cl := _column(tr("RECORD_BOOK"), 1.0)
	var list: VBoxContainer = cl[1]
	for r in RECORDS:
		var rec: Dictionary = season.records.get(r[0], {})
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", -2)
		box.add_child(UI.label(tr(r[1]), "MutedLabel", 14))
		if rec.is_empty():
			box.add_child(UI.label("—", "SubLabel", 18))
		else:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.add_child(UI.label(str(int(rec.v)), "HeaderLabel", 32, Game.C_GOLD))
			var who := String(rec.get("name", ""))
			if who == "":
				who = DB.team_name(String(rec.team))
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", -3)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var wl := UI.label(who, "SubLabel", 16, Game.C_SAFFRON if String(rec.team) == season.team else Game.C_INK)
			UI.fit(wl)
			col.add_child(wl)
			var sub := [String(rec.team), tr("SEASON").format({"n": int(rec.year)})]
			if String(rec.get("team2", "")) != "":
				sub.insert(1, "%s %s" % [tr("VS"), String(rec.team2)])
			col.add_child(UI.label(" · ".join(sub), "MutedLabel", 13))
			row.add_child(col)
			box.add_child(row)
		list.add_child(box)
	return cl[0]


func _all_time() -> PanelContainer:
	var cl := _column(tr("ALL_TIME_SCORERS"), 1.0)
	var list: VBoxContainer = cl[1]
	var rows: Array = season.all_time(10)
	if rows.is_empty():
		list.add_child(UI.wrap(tr("HOF_EMPTY"), "MutedLabel", 16))
	for i in rows.size():
		var r: Dictionary = rows[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var n := UI.label(str(i + 1), "SubLabel", 16, Game.C_MUTED)
		n.custom_minimum_size = Vector2(22, 0)
		row.add_child(n)
		row.add_child(Crest.make(String(r.team), 24))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", -3)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := UI.label(String(r.name), "SubLabel", 15, Game.C_SAFFRON if String(r.team) == season.team else Game.C_INK)
		UI.fit(nm)
		col.add_child(nm)
		col.add_child(UI.label(tr("ALL_TIME_LINE").format({"raid": int(r.raid), "tackle": int(r.tackle), "n": int(r.seasons)}), "MutedLabel", 13))
		row.add_child(col)
		row.add_child(UI.label(str(int(r.raid) + int(r.tackle)), "HeaderLabel", 28, Game.C_GOLD))
		list.add_child(row)
	return cl[0]
