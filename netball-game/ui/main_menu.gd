extends Control
## The home screen, laid out as a netball court seen from above. Its three thirds are the ways in: the centre third,
## with the centre circle where every passage of play starts, is Quick Match; one goal third the Nations Cup; the
## other How to Play. Over the court hangs the bib rail: the seven bibs, GS to GK, the way into the game itself:
## tap one to play that position all match, or Team to play whoever has the ball. A real match plays behind it all
## (Medium and High graphics; the still court on Low). The globe changes the language; seven taps on the version
## turn the developer overlay on.

const ATTRACT := [["AUS", "NZL", "arena"], ["ENG", "JAM", "arena"], ["RSA", "MWI", "outdoor"], ["UGA", "TGA", "hall"],
	["SCO", "WAL", "hall"], ["SGP", "MAS", "arena"], ["FIJ", "SAM", "outdoor"], ["ZIM", "ZAM", "outdoor"]]

var _sv: SubViewport
var _match: Node = null
var _pick := 0
var _picker: LanguagePicker = null
var _ver_taps := 0
var _ver_last := 0
var _bibs: Array = []
var _bib_note: Label
var _content: Control
var _ver: Label


func _ready() -> void:
	UI.screen(self, true)
	Sfx.stop_all()
	_pick = randi() % ATTRACT.size()
	if int(Game.settings.graphics) != Game.GFX_LOW:
		var svc := SubViewportContainer.new()
		svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		svc.stretch = true
		svc.stretch_shrink = 2
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(svc)
		_sv = SubViewport.new()
		_sv.own_world_3d = true
		_sv.audio_listener_enable_3d = false
		svc.add_child(_sv)
		_start_attract()
	_shade()
	_build_ui()
	if Game.loading:
		Game.loaded.connect(_animate_in, CONNECT_ONE_SHOT)
	else:
		_animate_in()


func _start_attract() -> void:
	if _match and is_instance_valid(_match):
		_match.queue_free()
	var a: Array = ATTRACT[_pick % ATTRACT.size()]
	_pick += 1
	_match = (load("res://game/match.gd") as Script).new()
	_match.config = {"home": a[0], "away": a[1], "venue": a[2], "mode": "quick", "user_team": -1, "demo": true,
		"attract": true, "quarter": 3, "difficulty": 2}
	_match.finished.connect(func(_r): _start_attract.call_deferred())
	_sv.add_child(_match)


func _shade() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(Game.C_BG, 0.55 if _sv else 0.0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _build_ui() -> void:
	var margin := UI.frame(self, 34.0)
	_content = margin
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)
	# The top row: the game's name, and the globe, records and settings.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -10)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	tv.add_child(UI.label(tr("MENU_EYEBROW").to_upper(), "EyebrowLabel", 16, Game.C_ACCENT))
	var title := UI.label(tr("GAME_TITLE"), "TitleLabel", 74)
	UI.shrink(title, 74, 0.6)
	tv.add_child(title)
	var globe := UI.round_button("globe", _open_language, 58)
	globe.tooltip_text = tr("LANGUAGE")
	top.add_child(globe)
	top.add_child(UI.round_button("trophy", func(): _go("res://ui/records_screen.gd"), 58))
	top.add_child(UI.round_button("gear", func(): _go("res://ui/settings_screen.gd"), 58))
	# The bib rail.
	v.add_child(_bib_rail())
	# The court: three thirds.
	var court := HBoxContainer.new()
	court.add_theme_constant_override("separation", 0)
	court.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(court)
	var cup = Game.get_cup()
	var cup_desc := tr("MENU_CUP_DESC")
	if cup and cup.stage != "done":
		cup_desc = tr("MENU_CUP_CONTINUE")
	# The left goal third holds the two competitions, one above the other.
	var lg = Game.get_league()
	var league_desc := tr("MENU_LEAGUE_CONTINUE") if lg and lg.stage != "done" else tr("MENU_LEAGUE_DESC")
	var comps := VBoxContainer.new()
	comps.add_theme_constant_override("separation", 0)
	comps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	comps.add_child(CourtThird.make(tr("MENU_CUP"), cup_desc, "goal_left_top", func(): _go("res://ui/cup_screen.gd")))
	comps.add_child(CourtThird.make(tr("MENU_LEAGUE"), league_desc, "goal_left_bottom", func(): _go("res://ui/league_screen.gd")))
	court.add_child(comps)
	court.add_child(CourtThird.make(tr("MENU_QUICK"), tr("MENU_QUICK_DESC"), "centre", func(): _go("res://ui/quick_setup.gd")))
	court.add_child(CourtThird.make(tr("MENU_HOWTO"), tr("MENU_HOWTO_DESC"), "goal_right", func(): _go("res://ui/howto_screen.gd")))
	# The version: seven taps turn the developer overlay on or off.
	var ver := UI.label(tr("VERSION_N").format({"v": String(ProjectSettings.get_setting("application/config/version"))}), "MutedLabel", 14)
	ver.mouse_filter = Control.MOUSE_FILTER_STOP
	ver.gui_input.connect(_on_version_input)
	ver.size_flags_horizontal = Control.SIZE_SHRINK_END
	v.add_child(ver)
	_ver = ver


## The seven bibs on their rail, and Team: who you play as.
func _bib_rail() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var lab := UI.label(tr("PLAY_AS").to_upper(), "EyebrowLabel", 15)
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lab.custom_minimum_size = Vector2(0, 0)
	row.add_child(lab)
	var team_on := int(Game.settings.control) == Game.CONTROL_TEAM
	var team_b := BibButton.make("TEAM", tr("BIB_TEAM"), team_on, func(): _pick_bib(""))
	row.add_child(team_b)
	_bibs.append(team_b)
	for pos in Rules.POSITIONS:
		var on: bool = not team_on and String(Game.settings.bib) == pos
		var b := BibButton.make(pos, pos, on, _pick_bib.bind(pos))
		row.add_child(b)
		_bibs.append(b)
	_bib_note = UI.label(_bib_text(), "MutedLabel", 16)
	UI.fit(_bib_note, 1)
	box.add_child(_bib_note)
	return box


func _bib_text() -> String:
	if int(Game.settings.control) == Game.CONTROL_TEAM:
		return tr("BIB_TEAM_NOTE")
	return tr("POS_NAME_" + String(Game.settings.bib)) + " · " + tr("POS_ROLE_" + String(Game.settings.bib))


func _pick_bib(pos: String) -> void:
	Sfx.click()
	if pos == "":
		Game.settings.control = Game.CONTROL_TEAM
	else:
		Game.settings.control = Game.CONTROL_BIB
		Game.settings.bib = pos
	Game.save_settings()
	for b in _bibs:
		b.on = (b.code == "TEAM" and pos == "") or b.code == pos
		b.queue_redraw()
	_bib_note.text = _bib_text()


## Back (the phone's button, or Esc): closes the language picker if it is open, else leaves the game. In a browser
## there is nothing to leave to: quitting would freeze the page (playtest), so Esc on the home screen does nothing.
func on_back() -> void:
	if _picker and is_instance_valid(_picker):
		_picker.close()
		return
	if quits_on_back():
		get_tree().quit()


static func quits_on_back() -> bool:
	return not OS.has_feature("web")


func _go(path: String) -> void:
	Game.show_screen(path)


func _open_language() -> void:
	if _picker and is_instance_valid(_picker):
		return
	_picker = LanguagePicker.new()
	_picker.picked.connect(func(): Game.goto_menu.call_deferred())
	add_child(_picker)


func _animate_in() -> void:
	if not is_instance_valid(_content):
		return
	_content.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_content, "modulate:a", 1.0, 0.35)


func _on_version_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var now := Time.get_ticks_msec()
	_ver_taps = _ver_taps + 1 if now - _ver_last < 700 else 1
	_ver_last = now
	if _ver_taps >= 7:
		_ver_taps = 0
		Game.settings.dev = not bool(Game.settings.dev)
		Game.save_settings()
		_ver.text = tr("DEV_ON") if Game.settings.dev else tr("DEV_OFF")
		Sfx.play("whistle", -10.0)
