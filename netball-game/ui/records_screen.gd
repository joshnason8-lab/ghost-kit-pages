extends Control
## The record book: matches played, won, drawn and lost, goals, the biggest win, the best day by one shooter, and
## Nations Cups played and won.


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("MENU_RECORDS"), func(): Game.goto_menu())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	v.add_child(UI.scroll(col))
	var r: Dictionary = Game.records
	if int(r.get("played", 0)) == 0:
		col.add_child(UI.wrap(tr("RECORDS_EMPTY"), "MutedLabel", 20))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	for pair in [["REC_PLAYED", str(int(r.get("played", 0)))],
			["REC_RECORD", "%d · %d · %d" % [int(r.get("won", 0)), int(r.get("drawn", 0)), int(r.get("lost", 0))]],
			["REC_GOALS", str(int(r.get("goals", 0)))],
			["REC_BEST_WIN", String(r.get("best_win", "–"))],
			["REC_TOP_SHOOTER", "%s · %d" % [r.get("top_shooter", "–"), int(r.get("top_shooter_goals", 0))]],
			["REC_CUPS", "%d / %d" % [int(r.get("cups_won", 0)), int(r.get("cups_played", 0))]],
			["REC_TITLES", "%d / %d" % [int(r.get("titles_won", 0)), int(r.get("seasons_played", 0))]]]:
		grid.add_child(UI.label(tr(pair[0]), "MutedLabel", 19))
		# The value takes the rest of the row (without it the grid gave it no width at all: every value an ellipsis).
		var val := UI.fit(UI.label(pair[1], "SubLabel", 22))
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(val)
