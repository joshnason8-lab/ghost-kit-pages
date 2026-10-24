extends Control
## How to Play, in four parts: the game (the court, the teams, a goal, the centre pass, the quarters), the seven
## positions (each with a little court showing the areas she may go into), the rules the umpires call, and the
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
	var map := AreaMap.new()
	map.pos = pos
	map.custom_minimum_size = Vector2(0, 92)
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(map)
	return card


## A little court with the areas a position may enter lit in lime (her team attacking to the right).
class AreaMap:
	extends Control
	var pos := "C"

	func _draw() -> void:
		var w := minf(size.x, size.y * 2.0)
		var h := w * 0.5
		var o := Vector2((size.x - w) * 0.5, (size.y - h) * 0.5)
		var r := Rect2(o, Vector2(w, h))
		var allowed: Array = Rules.AREAS[pos]
		draw_rect(r, Color(Game.C_COURT, 0.6), true)
		var third := w / 3.0
		var cr := h * Court.CIRCLE_R / Court.WIDTH
		var lit := Color(Game.C_ACCENT, 0.75)
		# The thirds: defending (left), centre, attacking (right); each circle lit only if allowed.
		if Court.A_DEF_THIRD in allowed:
			draw_rect(Rect2(o, Vector2(third, h)), lit, true)
		if Court.A_CENTRE in allowed:
			draw_rect(Rect2(o + Vector2(third, 0), Vector2(third, h)), lit, true)
		if Court.A_ATT_THIRD in allowed:
			draw_rect(Rect2(o + Vector2(third * 2.0, 0), Vector2(third, h)), lit, true)
		var court_col := Color(Game.C_COURT, 1.0)
		for side in [-1, 1]:
			var c := o + Vector2(0.0 if side < 0 else w, h * 0.5)
			var area := Court.A_DEF_CIRCLE if side < 0 else Court.A_ATT_CIRCLE
			var pts := PackedVector2Array([c])
			for i in 25:
				var a := (-PI * 0.5 + PI * i / 24.0) if side < 0 else (PI * 0.5 + PI * i / 24.0)
				pts.append(c + Vector2(cos(a), sin(a)) * cr)
			draw_colored_polygon(pts, Color(Game.C_ACCENT, 0.95) if area in allowed else court_col)
			var arc := PackedVector2Array(pts.slice(1))
			draw_polyline(arc, Color.WHITE, 1.5, true)
		draw_rect(r, Color.WHITE, false, 2.0)
		for k in [1, 2]:
			draw_line(o + Vector2(third * k, 0), o + Vector2(third * k, h), Color.WHITE, 1.5)
		draw_arc(o + Vector2(w * 0.5, h * 0.5), maxf(2.0, h * 0.45 / Court.WIDTH), 0, TAU, 12, Color.WHITE, 1.5)
		# The goal she attacks.
		draw_circle(o + Vector2(w - 3.0, h * 0.5), 3.0, Game.C_CORAL)
