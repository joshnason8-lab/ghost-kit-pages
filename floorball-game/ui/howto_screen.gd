extends Control
## How to Play: three tabs on the board. Controls (the joystick and the buttons, with and without the ball); The
## rules (floorball's laws as the game plays them, each with its rule number); The referees' signs (each drawn, with
## what it means). Every tab scrolls when dragged anywhere on it, on its words and pictures too: nothing on the page
## takes the touch (the words are Labels and drawings that ignore the mouse; DragScroll does the rest).

const RULES := [["RULE_RINK", "101-105"], ["RULE_TEAMS", "301-302"], ["RULE_TIME", "201"], ["RULE_FACEOFF", "501, 503"],
	["RULE_HITIN", "504-505"], ["RULE_FREEHIT", "506-507"], ["RULE_STICK", "507.1-507.4"], ["RULE_BODY", "507.5-507.11"],
	["RULE_GK", "303, 507.15-507.18"], ["RULE_GKAREA", "507.12"], ["RULE_GOALS", "701-703"], ["RULE_PENALTIES", "601-614"],
	["RULE_PP", "604"], ["RULE_PENSHOT", "508-510"], ["RULE_OT", "203-204"], ["RULE_ADVANTAGE", "602"]]
const SIGNS := ["free_hit", "hit_in", "advantage", "delayed", "goal", "no_goal", "pen2", "pen5", "pen10", "penalty_shot", "face_off", "timeout"]

var _tab := 0


func setup(args: Dictionary) -> void:
	_tab = int(args.get("tab", 0))


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("MENU_HOWTO"), func(): Game.goto_menu())
	var tabs := UI.chips([tr("HOWTO_CONTROLS"), tr("HOWTO_RULES"), tr("HOWTO_SIGNS")], _tab, func(i):
		Game.show_screen("res://ui/howto_screen.gd", {"tab": i}))
	v.add_child(tabs)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	v.add_child(UI.scroll(col))
	match _tab:
		0:
			_controls(col)
		1:
			_rules(col)
		_:
			_signs(col)


func _item(col: Container, title: String, body: String, tag := "") -> void:
	var c := UI.card()
	var vv := VBoxContainer.new()
	vv.add_theme_constant_override("separation", 4)
	c.add_child(vv)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var t := UI.label(title, "SubLabel", 22, Game.C_BLUE)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if tag != "":
		var p := UI.pill(tr("RULE_N").format({"n": tag}), Game.C_MUTED)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(p)
	vv.add_child(h)
	vv.add_child(UI.wrap(body, "", 18))
	col.add_child(c)


func _controls(col: Container) -> void:
	col.add_child(UI.wrap(tr("HOWTO_INTRO"), "MutedLabel", 18))
	for k in ["CTRL_MOVE", "CTRL_SHOOT", "CTRL_PASS", "CTRL_SPRINT", "CTRL_TACKLE", "CTRL_SWITCH", "CTRL_RESTART", "CTRL_SHOOTOUT", "CTRL_PAUSE"]:
		_item(col, tr(k), tr(k + "_BODY"))


func _rules(col: Container) -> void:
	col.add_child(UI.wrap(tr("RULES_INTRO"), "MutedLabel", 18))
	for r in RULES:
		_item(col, tr(r[0]), tr(r[0] + "_BODY"), r[1])


func _signs(col: Container) -> void:
	col.add_child(UI.wrap(tr("SIGNS_INTRO"), "MutedLabel", 18))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	col.add_child(grid)
	for s in SIGNS:
		var c := UI.card()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		c.add_child(h)
		var fig := SignFigure.new()
		fig.kind = s
		fig.custom_minimum_size = Vector2(84, 110)
		h.add_child(fig)
		var vv := VBoxContainer.new()
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vv.add_theme_constant_override("separation", 2)
		var t := UI.label(tr("SIGN_" + s.to_upper()), "SubLabel", 20, Game.C_BLUE)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vv.add_child(t)
		vv.add_child(UI.wrap(tr("SIGN_" + s.to_upper() + "_BODY"), "", 16))
		h.add_child(vv)
		grid.add_child(c)


## A referee drawn in marker, showing a sign: the arms as the IFF's signs have them.
class SignFigure:
	extends Control
	var kind := "free_hit"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := size
		var ink := Game.C_INK
		var head := Vector2(s.x * 0.5, s.y * 0.16)
		var neck := Vector2(s.x * 0.5, s.y * 0.27)
		var hip := Vector2(s.x * 0.5, s.y * 0.6)
		var sh_l := neck + Vector2(-s.x * 0.12, s.y * 0.03)
		var sh_r := neck + Vector2(s.x * 0.12, s.y * 0.03)
		draw_circle(head, s.y * 0.08, Color(ink, 0.9))
		# The referee's yellow shirt.
		draw_line(neck, hip, Game.C_YELLOW.darkened(0.15), s.x * 0.2)
		draw_line(neck, hip, ink, 2.0)
		draw_line(hip, hip + Vector2(-s.x * 0.12, s.y * 0.36), ink, 4.0)
		draw_line(hip, hip + Vector2(s.x * 0.12, s.y * 0.36), ink, 4.0)
		var arm := s.y * 0.3
		var down_l := sh_l + Vector2(-s.x * 0.04, arm)
		var down_r := sh_r + Vector2(s.x * 0.04, arm)
		var l := down_l
		var r := down_r
		match kind:
			"free_hit":
				r = sh_r + Vector2(arm, 0)
			"hit_in":
				r = sh_r + Vector2(arm * 0.85, arm * 0.5)
			"advantage":
				r = sh_r + Vector2(arm * 0.75, -arm * 0.65)
			"delayed":
				r = sh_r + Vector2(0, -arm)
			"goal":
				r = sh_r + Vector2(arm * 0.95, arm * 0.2)
			"no_goal":
				l = sh_l + Vector2(-arm, 0)
				r = sh_r + Vector2(arm, 0)
			"pen2", "pen5":
				r = sh_r + Vector2(arm * 0.15, -arm)
			"pen10":
				l = sh_l + Vector2(-arm * 0.15, -arm)
				r = sh_r + Vector2(arm * 0.15, -arm)
			"penalty_shot":
				l = sh_l + Vector2(arm * 0.6, -arm * 0.75)
				r = sh_r + Vector2(-arm * 0.6, -arm * 0.75)
			"face_off":
				r = sh_r + Vector2(arm * 0.6, arm * 0.8)
			"timeout":
				l = sh_l + Vector2(arm * 0.9, -arm * 0.2)
				r = sh_r + Vector2(0, -arm * 0.95)
		draw_line(sh_l, l, ink, 4.0)
		draw_line(sh_r, r, ink, 4.0)
		draw_circle(l, 3.5, ink)
		draw_circle(r, 3.5, ink)
		if kind == "pen2" or kind == "pen5":
			var f := Game.font_score
			draw_string(f, r + Vector2(6, 4), "2" if kind == "pen2" else "5", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Game.C_RED)
		if kind == "goal" or kind == "penalty_shot" or kind == "face_off":
			draw_circle(Vector2(s.x * 0.9, s.y * 0.96), 4.0, Game.C_BLUE)
