extends Control
## How to Play, in three parts: the rules (the court, the serve, three touches, the score, the faults), the controls,
## and the moves fans know by name.

var _tab := 0
var _back := Callable()   # back to whatever opened it over itself (the help); else the home screen
var _body: VBoxContainer

const TABS := [
	["HOWTO_RULES", ["RULES_COURT", "RULES_PLAYERS", "RULES_SERVE", "RULES_TOUCHES", "RULES_SCORE", "RULES_FAULTS", "RULES_CHALLENGE"]],
	["HOWTO_CONTROLS", ["CTRL_TIMING", "CTRL_MOVE", "CTRL_SERVE", "CTRL_PASS", "CTRL_SET", "CTRL_SPIKE", "CTRL_BLOCK", "CTRL_ASSIST", "CTRL_KEYS"]],
	["HOWTO_MOVES", ["MOVE_SILA", "MOVE_KUDA", "MOVE_HORSE", "MOVE_ROLL", "MOVE_SUNBACK", "MOVE_TAPAK", "MOVE_HEADER", "MOVE_FEINT", "MOVE_BLOCK"]],
]


func setup(args: Dictionary) -> void:
	_tab = int(args.get("tab", 0))
	_back = args.get("back", Callable())


func _ready() -> void:
	UI.screen(self)
	Game.settings.seen_howto = true
	Game.save_settings()
	var v := UI.page(self, tr("MENU_HOWTO"), _back if _back.is_valid() else func(): Game.goto_menu())
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
		cv.add_child(t)
		cv.add_child(UI.wrap(tr(key + "_TEXT"), "", 18))
		grid.add_child(card)

