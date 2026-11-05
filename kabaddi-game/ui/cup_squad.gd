extends Control
## The Nations Cup squad: twelve from the country's eighteen (the regulars and six uncapped youngsters), with at
## least three raiders and four defenders, and a captain among them.

var cup
var chosen: Array = []      # pids
var captain := ""
var _grid: GridContainer
var _summary: Label
var _cap_l: Label
var _go: Button
var _mode := 0              # 0 picking players, 1 picking the captain
var _hint: Label


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	cup = Game.get_cup()
	if cup == null:
		Game.show_screen("res://ui/cup_screen.gd")
		return
	for p in cup.squad:
		chosen.append(String(p.id))
	captain = cup.captain
	var v := UI.page(self, tr("CUP_SQUAD_PICK"), func():
		Game.delete_cup()
		Game.show_screen("res://ui/cup_screen.gd"), DB.team_name(cup.user))
	var head: HBoxContainer = get_meta("header_right")
	head.add_child(Crest.make(cup.user, 48))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.55
	cols.add_child(left)
	left.add_child(UI.wrap(tr("CUP_SQUAD_EXPLAIN").format({"r": Cup.MIN_RAIDERS, "d": Cup.MIN_DEFENDERS}), "", 18))
	left.add_child(UI.chips_row([tr("PICK_PLAYERS"), tr("PICK_CAPTAIN")], 0, func(i):
		_mode = i
		_hint.text = tr("PICK_CAPTAIN_HINT") if i == 1 else ""))
	_summary = UI.label("", "SubLabel", 19, Game.C_GOLD)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_summary)
	_cap_l = UI.label("", "SubLabel", 19)
	left.add_child(_cap_l)
	_hint = UI.label("", "MutedLabel", 16)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_hint)
	left.add_child(UI.button(tr("BEST_TWELVE"), false, func():
		chosen = []
		for p in cup.best_squad():
			chosen.append(String(p.id))
		if not chosen.has(captain):
			captain = chosen[0]
		_refresh()))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(sp)
	_go = UI.button(tr("START_TOURNAMENT"), true, _confirm)
	_go.custom_minimum_size = Vector2(0, 74)
	left.add_child(_go)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	var gs := UI.scroll(_grid)
	gs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(gs)
	_refresh()


func _players() -> Array:
	var out := []
	for p in cup.pool():
		if chosen.has(String(p.id)):
			out.append(p)
	return out


func _refresh() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var pool: Array = cup.pool().duplicate()
	var order := {"raider": 0, "allrounder": 1, "defender": 2}
	pool.sort_custom(func(a, b): return order[a.role] < order[b.role] or (order[a.role] == order[b.role] and DB.overall(a) > DB.overall(b)))
	for p in pool:
		var pid := String(p.id)
		var ln := PlayerCard.line(p)
		if int(String(pid).get_slice("_", 1)) >= 12:
			var pot := Scout.potential(p)
			ln += "\n" + tr("UNCAPPED") + " · " + tr("NYP_POTENTIAL_" + ("HIGH" if pot >= 0.75 else ("FAIR" if pot >= 0.5 else "LOW")))
		_grid.add_child(PlayerCard.make(p, {"selected": chosen.has(pid), "captain": pid == captain, "line": ln}, _toggle.bind(pid)))
	var players := _players()
	var counts := {"raider": 0, "allrounder": 0, "defender": 0}
	for p in players:
		counts[String(p.role)] += 1
	_summary.text = UI.bits([tr("CUP_SQUAD_COUNT").format({"n": players.size(), "r": counts.raider, "a": counts.allrounder, "d": counts.defender})])
	var cap := ""
	for p in players:
		if String(p.id) == captain:
			cap = String(p.name)
	_cap_l.text = tr("CAPTAIN_IS").format({"name": cap if cap != "" else "—"})
	var ok: bool = Cup.squad_ok(players) and cap != ""
	_go.disabled = not ok
	if not ok and _mode == 0:
		if players.size() != Cup.SQUAD_SIZE:
			_hint.text = tr("CUP_PICK_N").format({"n": Cup.SQUAD_SIZE - players.size()}) if players.size() < Cup.SQUAD_SIZE else tr("CUP_TOO_MANY")
		elif cap == "":
			_hint.text = tr("PICK_CAPTAIN_HINT")
		else:
			_hint.text = tr("CUP_SQUAD_RULE").format({"r": Cup.MIN_RAIDERS, "d": Cup.MIN_DEFENDERS})
	elif ok and _mode == 0:
		_hint.text = ""


func _toggle(pid: String) -> void:
	if _mode == 1:
		if chosen.has(pid):
			captain = pid
		else:
			_hint.text = tr("CAPTAIN_FROM_SQUAD")
			return
	elif chosen.has(pid):
		chosen.erase(pid)
		if captain == pid:
			captain = ""
	elif chosen.size() < Cup.SQUAD_SIZE:
		chosen.append(pid)
	else:
		_hint.text = tr("CUP_TOO_MANY")
		return
	_refresh()


func _confirm() -> void:
	cup.confirm_squad(_players(), captain)
	Game.save_cup()
	Game.show_screen("res://ui/cup_screen.gd")
