extends Control
## The record book: matches played and won, titles and medals won, and your players' best matches.


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("MENU_RECORDS"), func(): Game.goto_menu())
	var r: Dictionary = Game.records
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	v.add_child(UI.scroll(cols))
	var left: Array = UI.section(tr("RECORDS_CAREER"), "star")
	cols.add_child(left[0])
	left[1].add_child(UI.label(tr("RECORDS_PLAYED").format({"n": int(r.get("played", 0))}), "SubLabel", 22))
	left[1].add_child(UI.label(tr("RECORDS_WON").format({"n": int(r.get("won", 0))}), "SubLabel", 22))
	for k in ["kills", "blocks", "aces"]:
		var b: Dictionary = r.get("best_" + k, {})
		if not b.is_empty():
			left[1].add_child(UI.wrap(tr("RECORDS_BEST_" + k.to_upper()).format({"n": int(b.n), "p": tr("SHIRT_N").format({"n": int(b.get("num", 0))}), "t": DB.team_name(String(b.vs))}), "", 18))
	var right: Array = UI.section(tr("RECORDS_TITLES"), "trophy")
	cols.add_child(right[0])
	var titles: Array = r.get("titles", [])
	if titles.is_empty():
		right[1].add_child(UI.wrap(tr("RECORDS_NONE"), "MutedLabel", 18))
	for t in titles:
		var key := String(t.key)
		var name := tr(DB.LEAGUES[key.substr(7)].name) if key.begins_with("league_") else tr(String(Cup.KINDS.get(key.substr(4), {}).get("name", key)))
		right[1].add_child(UI.label("%s · %d" % [name, int(t.year)], "SubLabel", 20))
