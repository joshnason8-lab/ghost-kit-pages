extends Control
## The home screen: a match going on in the hall, full screen (two national teams, the AI on both sides: a demo, so
## nothing buzzes and nothing is recorded), darkened on the left where the menu stands over it. There, the game's name
## in the slanted headline face, and the ways to play as tiles: Quick match, World Finals, Club season, Penalty shots,
## Watch a match, How to play. Top right, over the hall: Settings and the language.

var _picker: LanguagePicker = null
var _demo: Node = null


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self, false)
	Renderer.started()
	_start_demo()
	# The shade: the hall darkened under the menu, fading out toward the play.
	var shade := Control.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(func():
		var w := shade.size.x
		var h := shade.size.y
		var steps := 24
		for i in steps:
			var x0 := w * 0.64 * i / steps
			var x1 := w * 0.64 * (i + 1) / steps
			var t := float(i) / steps
			var a := 0.94 if t < 0.55 else 0.94 * (1.0 - (t - 0.55) / 0.45)
			shade.draw_rect(Rect2(x0, 0, x1 - x0 + 1, h), Color(Game.C_BG, a))
		shade.draw_rect(Rect2(0, h * 0.86, w, h * 0.14), Color(0, 0, 0, 0.25)))
	add_child(shade)
	var board := Control.new()
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.anchor_right = 0.56
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	var margin := UI.frame(board, 34.0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -18)
	v.add_child(tv)
	var words := tr("GAME_TITLE").split(" ", false, 1)
	var t1 := UI.label(words[0].to_upper(), "TitleLabel", 88, Game.C_INK)
	UI.shrink(t1, 88, 0.6)
	tv.add_child(t1)
	if words.size() > 1:
		var t2 := UI.label(words[1].to_upper(), "TitleLabel", 88, Game.C_MAGNET)
		UI.shrink(t2, 88, 0.6)
		tv.add_child(t2)
	var sub := UI.label(tr("GAME_TAGLINE"), "SubLabel", 18, Game.C_MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.custom_minimum_size = Vector2(0, 4)
	v.add_child(gap)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var cup = Game.get_cup()
	var cup_desc := tr("CUP_DESC") if cup == null else tr("CUP_CONTINUE").format({"team": DB.team_name(cup.user)})
	var season = Game.get_season()
	var season_desc := tr("SEASON_DESC") if season == null else tr("CUP_CONTINUE").format({"team": DB.team_name(season.user)})
	grid.add_child(UI.note(tr("MENU_QUICK"), tr("MENU_QUICK_DESC"), Game.C_BLUE, func(): Game.show_screen("res://ui/quick_setup.gd")))
	grid.add_child(UI.note(tr("MENU_CUP"), cup_desc, Game.C_GOLD, func(): Game.show_screen("res://ui/cup_screen.gd")))
	grid.add_child(UI.note(tr("MENU_SEASON"), season_desc, Game.C_MAGNET, func(): Game.show_screen("res://ui/season_screen.gd")))
	grid.add_child(UI.note(tr("MENU_SHOOTOUT"), tr("MENU_SHOOTOUT_DESC"), Game.C_CYAN, func(): Game.show_screen("res://ui/quick_setup.gd", {"shootout": true})))
	grid.add_child(UI.note(tr("MENU_WATCH"), tr("MENU_WATCH_DESC"), Game.C_GREEN, func(): Game.show_screen("res://ui/quick_setup.gd", {"watch": true})))
	grid.add_child(UI.note(tr("MENU_HOWTO"), tr("MENU_HOWTO_DESC"), Game.C_RED, func(): Game.show_screen("res://ui/howto_screen.gd")))
	# Top right, over the hall: the language and what is on the rink.
	var tr_box := VBoxContainer.new()
	tr_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var sm := UI.safe_margins(self, 26.0)
	tr_box.offset_right = -sm.z
	tr_box.offset_top = 22
	tr_box.offset_left = -420
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
	lang_row.add_child(UI.round_button("gear", func(): Game.show_screen("res://ui/settings_screen.gd"), 58))
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
	_demo.config = {"home": pair[0], "away": pair[1], "venue": ["arena", "hall"][rng.randi() % 2], "user_team": -1, "demo": true, "menu": true,
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
