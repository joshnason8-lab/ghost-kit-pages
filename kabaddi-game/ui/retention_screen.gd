extends Control
## Retentions: before the auction you keep up to six of your squad. Each costs his category's price and a premium,
## so a star costs more to keep than he might fetch, and every player you let go goes under the hammer (with your
## Final Bid Match card to win one back).

var season
var kept: Array = []        # pids
var _grid: GridContainer
var _purse: Label
var _summary: Label
var _needs: Label


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	season = Game.get_season()
	if season == null:
		Game.goto_menu()
		return
	kept = season.retained.duplicate() if season.retain_done else season.default_retained()
	var v := UI.page(self, tr("RETENTIONS"), func(): Game.show_screen("res://ui/season_hub.gd"), tr("SEASON").format({"n": season.year}))
	var head: HBoxContainer = get_meta("header_right")
	head.add_child(_purse_card())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.6
	cols.add_child(left)
	left.add_child(UI.wrap(tr("RETAIN_EXPLAIN").format({"n": Season.RETAIN_MAX}), "", 18))
	_summary = UI.label("", "SubLabel", 20, Game.C_GOLD)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_summary)
	_needs = UI.label("", "MutedLabel", 16)
	_needs.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_needs)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UI.button(tr("KEEP_BEST_SIX"), false, func():
		kept = season.default_retained()
		_refresh()))
	row.add_child(UI.button(tr("KEEP_NONE"), false, func():
		kept = []
		_refresh()))
	left.add_child(row)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)
	var go := UI.button(tr("TO_WAR_ROOM"), true, _confirm)
	go.custom_minimum_size = Vector2(0, 74)
	left.add_child(go)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	var gs := UI.scroll(_grid)
	gs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(gs)
	_refresh()


func _purse_card() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.9)
	sb.set_corner_radius_all(14)
	sb.border_color = Color(Game.C_GOLD, 0.45)
	sb.set_border_width_all(1)
	sb.content_margin_left = 14
	sb.content_margin_right = 16
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	col.add_child(UI.label(tr("AUCTION_PURSE").to_upper(), "EyebrowLabel", 13, Game.C_GOLD))
	_purse = UI.label("", "SubLabel", 22)
	col.add_child(_purse)
	p.add_child(col)
	return p


func _kept_players() -> Array:
	var out := []
	for p in season.squads[season.team]:
		if kept.has(String(p.id)):
			out.append(p)
	return out


func _refresh() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var sq: Array = season.squads[season.team].duplicate()
	sq.sort_custom(func(a, b): return DB.overall(a) > DB.overall(b))
	for p in sq:
		var pid := String(p.id)
		var pts := ""
		var ls: Dictionary = season.last_stats.get(pid, {})
		if not ls.is_empty():
			pts = " · " + tr("PTS_LAST_SEASON").format({"n": int(ls.raid) + int(ls.tackle)})
		var info := {"selected": kept.has(pid), "price": Game.fmt_money(Season.retain_cost(p)), "line": PlayerCard.line(p) + pts}
		_grid.add_child(PlayerCard.make(p, info, _toggle.bind(pid)))
	var mine := _kept_players()
	var cost := 0.0
	for p in mine:
		cost += Season.retain_cost(p)
	_purse.text = Game.fmt_money(season.purse_with(mine))
	_summary.text = tr("RETAIN_SUMMARY").format({"n": mine.size(), "max": Season.RETAIN_MAX, "price": Game.fmt_money(cost)})
	_needs.text = tr("THEN_NEED").format({"needs": Scout.needs_text(Scout.needs(mine))})


func _toggle(pid: String) -> void:
	if kept.has(pid):
		kept.erase(pid)
	elif kept.size() < Season.RETAIN_MAX:
		kept.append(pid)
	else:
		_summary.text = tr("RETAIN_FULL").format({"n": Season.RETAIN_MAX})
		return
	_refresh()


func _confirm() -> void:
	season.retained = kept.duplicate()
	season.retain_done = true
	Game.save_season()
	Game.show_screen("res://ui/war_room.gd")
