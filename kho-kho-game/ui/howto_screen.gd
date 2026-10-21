extends Control
## How to Play, in three parts: the rules (the field, the sides, the kho, the active chaser's rules, outs, fouls, the
## turns and the score, the two rule books), the controls, and the moves and tactics fans know by name. It scrolls when
## dragged from anywhere on it, on its words too (DragScroll; the labels pass the touch through).

var _tab := 0
var _body: VBoxContainer

const TABS := [
	["HOWTO_RULES", ["RULES_FIELD", "RULES_SIDES", "RULES_KHO", "RULES_DIRECTION", "RULES_OUTS", "RULES_FOULS", "RULES_TURNS",
		"RULES_FOLLOW_ON", "RULES_FAST", "RULES_OFFICIALS"]],
	["HOWTO_CONTROLS", ["CTRL_CHASE", "CTRL_KHO", "CTRL_DIVE", "CTRL_POLE", "CTRL_DEFEND", "CTRL_ASSIST", "CTRL_KEYS"]],
	["HOWTO_MOVES", ["MOVE_CHAIN", "MOVE_RING", "MOVE_KHO_CHAIN", "MOVE_SKY_DIVE", "MOVE_POLE_DIVE", "MOVE_WAZIR", "MOVE_DREAM"]],
]


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
	_body.add_theme_constant_override("separation", 14)
	v.add_child(UI.scroll(_body))
	_fill()


func _fill() -> void:
	for c in _body.get_children():
		c.queue_free()
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(grid)
	for key in TABS[_tab][1]:
		var card := UI.card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 6)
		card.add_child(cv)
		var t := UI.wrap(tr(key), "SubLabel", 22)
		t.add_theme_color_override("font_color", Game.C_GOLD)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(t)
		var body := UI.wrap(tr(key + "_TEXT"), "", 18)
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(body)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(card)

