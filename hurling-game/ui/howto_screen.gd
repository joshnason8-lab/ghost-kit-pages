extends Control
## How to Play: the game's rules as the match plays them, the controls, and the officials' signals, in one page
## that scrolls when dragged anywhere on it (its words and pictures pass the touch to the scroll box).

const TABS := [
	["HOWTO_RULES", ["RULES_AIM", "RULES_SCORE", "RULES_TEAM", "RULES_TIME", "RULES_CARRY", "RULES_HANDPASS", "RULES_GROUND",
		"RULES_TACKLE", "RULES_FOULS", "RULES_CARDS", "RULES_PUCKOUT", "RULES_FREE", "RULES_65", "RULES_SIDELINE",
		"RULES_PENALTY", "RULES_DRAW", "RULES_HELMET"]],
	["HOWTO_CONTROLS", ["CTRL_MOVE", "CTRL_SWITCH", "CTRL_STRIKE", "CTRL_GOAL", "CTRL_PASS", "CTRL_SOLO", "CTRL_CATCH",
		"CTRL_PULL", "CTRL_TACKLE", "CTRL_RESTART", "CTRL_ASSIST"]],
	["HOWTO_OFFICIALS", ["SIG_POINT", "SIG_GOAL", "SIG_WIDE", "SIG_65", "SIG_FREE", "SIG_ADVANTAGE", "SIG_CARDS", "SIG_SIDELINE"]],
]

var _tab := 0
var _body: VBoxContainer
var _scroll: ScrollContainer


func setup(args: Dictionary) -> void:
	_tab = int(args.get("tab", 0))


func _ready() -> void:
	UI.screen(self)
	Game.settings.seen_howto = true
	Game.save_settings()
	var v := UI.page(self, tr("MENU_HOWTO"), func(): Game.goto_menu())
	var names := []
	for t in TABS:
		names.append(tr(t[0]))
	v.add_child(UI.chips(names, _tab, func(i):
		_tab = i
		_fill()))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_scroll = UI.scroll(_body)
	v.add_child(_scroll)
	_fill()


func _fill() -> void:
	for c in _body.get_children():
		c.queue_free()
	if _tab == 0:
		var pic := PitchDiagram.new()
		pic.custom_minimum_size = Vector2(0, 230)
		_body.add_child(pic)
	var keys: Array = TABS[_tab][1]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	_body.add_child(grid)
	for k in keys:
		var card := UI.card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(col)
		var t := UI.label(tr(k), "SubLabel", 22, Game.C_GOLD)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.fit(t, 2)
		col.add_child(t)
		var d := UI.wrap(tr(k + "_TEXT"), "", 18)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(d)
		grid.add_child(card)
	_scroll.scroll_vertical = 0
