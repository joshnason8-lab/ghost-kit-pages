extends Control
## How to Play, in four parts: the game (the court, the teams, a goal, the centre pass, the quarters), the seven
## positions (each with a court showing where she plays: PositionCourt), the rules the umpires call, and the
## controls. Every page scrolls when dragged from anywhere on it, its words and pictures included (DragScroll).

var _tab := 0
var _body: VBoxContainer

const TABS := [
	["HOWTO_GAME", ["RULES_COURT", "RULES_TEAMS", "RULES_GOAL", "RULES_CENTRE", "RULES_TIME", "RULES_EXTRA"]],
	["HOWTO_POSITIONS", []],
	["HOWTO_RULES", ["RULES_FOOTWORK", "RULES_THREE", "RULES_OBSTRUCTION", "RULES_CONTACT", "RULES_OFFSIDE",
		"RULES_THIRD", "RULES_SHORT", "RULES_OUT", "RULES_PENALTIES", "RULES_ADVANTAGE", "RULES_SANCTIONS", "RULES_DZ"]],
	["HOWTO_CONTROLS", ["CTRL_MOVE", "CTRL_PASS", "CTRL_SHOOT", "CTRL_DEFEND", "CTRL_INTERCEPT", "CTRL_PLAY_AS", "CTRL_KEYS"]],
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
	if _tab == 1:
		for pos in Rules.POSITIONS:
			grid.add_child(_position_card(pos))
		return
	for key in TABS[_tab][1]:
		grid.add_child(_card(tr(key), tr(key + "_TEXT")))


func _card(title: String, text: String) -> PanelContainer:
	var card := UI.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)
	var t := UI.wrap(title, "SubLabel", 22)
	t.add_theme_color_override("font_color", Game.C_GOLD)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(t)
	var body := UI.wrap(text, "", 18)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(body)
	return card


func _position_card(pos: String) -> PanelContainer:
	var card := _card(pos + " · " + tr("POS_NAME_" + pos), tr("POS_ROLE_" + pos) + "\n" + tr("POS_AREAS_" + pos))
	var cv: VBoxContainer = card.get_child(0)
	cv.add_child(PositionCourt.make(pos))
	return card
