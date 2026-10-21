extends Control
## The record book: matches played, won and tied, the biggest win, the most outs by one of your chasers, your longest
## defence, and the championships won.


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("RECORDS_TITLE"), func(): Game.goto_menu())
	var r: Dictionary = Game.records
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	v.add_child(UI.scroll(col))
	if int(r.get("played", 0)) == 0:
		col.add_child(UI.wrap(tr("REC_NONE"), "MutedLabel", 20))
		return
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 30)
	g.add_theme_constant_override("v_separation", 12)
	col.add_child(g)
	var rows := [
		[tr("REC_PLAYED"), str(int(r.get("played", 0)))],
		[tr("REC_WON"), str(int(r.get("won", 0)))],
		[tr("REC_TIED"), str(int(r.get("tied", 0)))],
	]
	if r.has("best_margin"):
		rows.append([tr("REC_BEST_MARGIN"), UI.bits([tr("POINTS_N").format({"n": int(r.best_margin)}), tr("VS") + " " + DB.team_name(String(r.best_margin_vs))])])
	if r.has("most_outs"):
		rows.append([tr("REC_MOST_OUTS"), UI.bits([str(int(r.most_outs)), String(r.most_outs_by)])])
	if r.has("longest_run"):
		var s := int(r.longest_run)
		rows.append([tr("REC_LONGEST_RUN"), UI.bits(["%d:%02d" % [s / 60, s % 60], String(r.longest_run_by)])])
	var titles: Dictionary = r.get("titles", {})
	for k in titles:
		rows.append([tr("REC_TITLES") + " · " + tr("CUP_WORLD" if k == "world" else "CUP_NATIONAL"), str(int(titles[k]))])
	for row in rows:
		var a := UI.label(String(row[0]), "", 20, Game.C_MUTED)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UI.fit(a, 2)
		g.add_child(a)
		var b := UI.label(String(row[1]), "SubLabel", 22, Game.C_GOLD)
		UI.fit(b, 2)
		b.custom_minimum_size.x = 260
		g.add_child(b)
