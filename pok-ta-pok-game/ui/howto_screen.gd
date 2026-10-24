extends Control
## How to Play: the game's rules as the match plays them, the controls, the judges' calls, and the game's story, in
## one page that scrolls when dragged anywhere on it (its words and pictures pass the touch to the scroll box).

const TABS := [
	["HOWTO_RULES", ["RULES_AIM", "RULES_COURT", "RULES_BALL", "RULES_HIP", "RULES_RAYA", "RULES_COUNT", "RULES_URRIA",
		"RULES_FAULTS", "RULES_SERVE", "RULES_TIME", "RULES_CLASSIC", "RULES_RING"]],
	["HOWTO_CONTROLS", ["CTRL_MOVE", "CTRL_HIP", "CTRL_DIVE", "CTRL_AIM", "CTRL_SERVE", "CTRL_READ", "CTRL_ASSIST", "CTRL_KEYS"]],
	["HOWTO_JUDGES", ["SIG_RAYA", "SIG_FAULT", "SIG_COUNT", "SIG_URRIA"]],
	["HOWTO_STORY", ["STORY_OLD", "STORY_ULAMA", "STORY_REVIVAL", "STORY_WORDS", "STORY_RESPECT"]],
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
		var pics := HBoxContainer.new()
		pics.add_theme_constant_override("separation", 14)
		pics.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for r in [Rules.ULAMA, Rules.CLASSIC]:
			var pic := CourtDiagram.new()
			pic.custom_minimum_size = Vector2(0, 190)
			pic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pic.set_court(r, Color("b8352b"), Color("2f5d8a"))
			pics.add_child(pic)
		_body.add_child(pics)
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
