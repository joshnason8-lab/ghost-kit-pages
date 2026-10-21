extends Control
## The home screen: the coach's whiteboard standing on the left of a sports hall, a match going on behind it on the
## rink (two national teams, the AI on both sides: user_team -1, so nothing buzzes and nothing is recorded). On the
## board: the game's name in marker, a rink sketched with a team's magnets moving through a 2-1-2, and the notes to
## pick from: Quick match, World Finals, How to Play, Settings. The globe, top right, changes the language.

var _picker: LanguagePicker = null
var _demo: Node = null


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self, false)
	_start_demo()
	# The board: a whiteboard panel over the left of the screen.
	var board := Control.new()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.anchor_right = 0.64
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	var bd := Backdrop.new()
	board.add_child(bd)
	var margin := UI.frame(board, 34.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -14)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	var title := UI.label(tr("GAME_TITLE"), "TitleLabel", 92, Game.C_BLUE)
	UI.shrink(title, 92, 0.6)
	tv.add_child(title)
	var sub := UI.label(tr("GAME_TAGLINE"), "SubLabel", 19, Game.C_MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(sub)
	var sketch := RinkSketch.new()
	sketch.custom_minimum_size = Vector2(0, 150)
	sketch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sketch)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	v.add_child(grid)
	var cup = Game.get_cup()
	var cup_desc := tr("CUP_DESC") if cup == null else tr("CUP_CONTINUE").format({"team": DB.team_name(cup.user)})
	grid.add_child(UI.note(tr("MENU_QUICK"), tr("MENU_QUICK_DESC"), Game.C_BLUE, func(): Game.show_screen("res://ui/quick_setup.gd"), true))
	grid.add_child(UI.note(tr("MENU_CUP"), cup_desc, Game.C_RED, func(): Game.show_screen("res://ui/cup_screen.gd"), true))
	grid.add_child(UI.note(tr("MENU_HOWTO"), tr("MENU_HOWTO_DESC"), Game.C_GREEN, func(): Game.show_screen("res://ui/howto_screen.gd")))
	grid.add_child(UI.note(tr("MENU_SETTINGS"), tr("MENU_SETTINGS_DESC"), Game.C_INK, func(): Game.show_screen("res://ui/settings_screen.gd")))
	# Top right, over the hall: the language and what is on the rink.
	var tr_box := VBoxContainer.new()
	tr_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var sm := UI.safe_margins(self, 26.0)
	tr_box.offset_right = -sm.z
	tr_box.offset_top = 22
	tr_box.offset_left = -360
	tr_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	tr_box.add_theme_constant_override("separation", 8)
	add_child(tr_box)
	var lang_row := HBoxContainer.new()
	lang_row.alignment = BoxContainer.ALIGNMENT_END
	lang_row.add_theme_constant_override("separation", 10)
	tr_box.add_child(lang_row)
	var ln := UI.label(Game.language_names(Game.language())[0], "SubLabel", 20, Color.WHITE)
	UI.outline(ln)
	ln.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lang_row.add_child(ln)
	lang_row.add_child(UI.round_button("globe", _open_language, 58))
	if _demo:
		var live := UI.label(tr("LIVE_ON_RINK").format({"a": DB.team_name(String(_demo.config.home)), "b": DB.team_name(String(_demo.config.away))}), "HudLabel", 16)
		live.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		live.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.outline(live)
		tr_box.add_child(live)
	if not bool(Game.settings.seen_howto):
		Game.settings.seen_howto = true
		Game.save_settings()


## The match behind the board: two teams from the heartland, the AI on both sides, a short period, looping.
func _start_demo() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pairs := [["SWE", "FIN"], ["SUI", "CZE"], ["FIN", "CZE"], ["SWE", "SUI"], ["LAT", "SVK"], ["NOR", "DEN"], ["GER", "SWE"]]
	var pair: Array = pairs[rng.randi() % pairs.size()]
	var s: Script = load("res://game/match.gd")
	_demo = s.new()
	_demo.config = {"home": pair[0], "away": pair[1], "venue": ["arena", "hall"][rng.randi() % 2], "user_team": -1, "demo": true,
		"period": 3.0, "seed": rng.randi(), "mode": "demo", "women": rng.randf() < 0.4}
	add_child(_demo)
	_demo.finished.connect(func(_r):
		if is_instance_valid(self) and is_inside_tree():
			_demo.queue_free()
			_start_demo())


func _open_language() -> void:
	if _picker and is_instance_valid(_picker):
		return
	_picker = LanguagePicker.new()
	_picker.picked.connect(func(): Game.goto_menu.call_deferred())
	add_child(_picker)


func _exit_tree() -> void:
	if _demo and is_instance_valid(_demo):
		_demo.queue_free()
