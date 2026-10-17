extends Control
## Training Ground: the lessons down the left; on the right the selected move acted out on a
## loop, what the lesson asks of you, and Start.

var _rows := {}
var _demo: MoveDemo
var _title: Label
var _role: PanelContainer
var _steps: VBoxContainer
var _done_l: Label
var _cur := ""


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("MENU_TRAINING"), func(): Game.goto_menu(), tr("TRAINING_EYEBROW"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)

	# The lessons, raiding then defending.
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	var done: Array = Game.settings.get("tutorial_done", [])
	var last_raid := true
	list.add_child(UI.label(tr("HT_RAIDING").to_upper(), "EyebrowLabel", 14, Game.C_SAFFRON))
	for l in Tutorial.LESSONS:
		if bool(l.raid) != last_raid:
			last_raid = bool(l.raid)
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 6)
			list.add_child(gap)
			list.add_child(UI.label(tr("HT_DEFENDING").to_upper(), "EyebrowLabel", 14, Game.C_MAGENTA.lightened(0.2)))
		var b := _lesson_row(l, done.has(l.id))
		list.add_child(b)
		_rows[String(l.id)] = b
	var sc := UI.scroll(list)
	sc.custom_minimum_size = Vector2(330, 0)
	sc.size_flags_horizontal = Control.SIZE_FILL
	row.add_child(sc)

	# The selected lesson.
	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(card)
	var cv := HBoxContainer.new()
	cv.add_theme_constant_override("separation", 18)
	card.add_child(cv)
	var stage := SubViewportContainer.new()
	stage.stretch = true
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_stretch_ratio = 1.3
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(stage)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_2X if int(Game.settings.graphics) != Game.GFX_LOW else Viewport.MSAA_DISABLED
	stage.add_child(sv)
	_demo = MoveDemo.new()
	sv.add_child(_demo)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_child(info)
	_role = PanelContainer.new()
	_role.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info.add_child(_role)
	_title = UI.label("", "HeaderLabel", 44)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_title)
	_steps = VBoxContainer.new()
	_steps.add_theme_constant_override("separation", 10)
	info.add_child(_steps)
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(sp)
	_done_l = UI.label("", "SubLabel", 18, Game.C_GOOD)
	info.add_child(_done_l)
	var go := UI.button(tr("TUT_START"), true, func(): Game.start_match(Tutorial.match_config(_cur)))
	go.custom_minimum_size = Vector2(0, 72)
	info.add_child(go)

	# Start on the first lesson not yet done.
	var first: String = Tutorial.LESSONS[0].id
	for l in Tutorial.LESSONS:
		if not done.has(l.id):
			first = l.id
			break
	_select(first)


func _lesson_row(l: Dictionary, done: bool) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = tr(String(l.title))
	var accent := Game.C_SAFFRON if l.raid else Game.C_MAGENTA
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.7)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 48
	var on: StyleBoxFlat = sb.duplicate()
	on.bg_color = Color(accent, 0.2)
	on.border_color = accent
	on.border_width_left = 4
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", on)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_size_override("font_size", 19)
	var ic := Icon.make("check" if done else "play", 22, Game.C_GOOD if done else Color(accent, 0.8))
	ic.position = Vector2(14, 15)
	ic.size = Vector2(22, 22)
	b.add_child(ic)
	var id: String = l.id
	b.pressed.connect(func():
		Sfx.click()
		_select(id))
	return b


func _select(id: String) -> void:
	_cur = id
	for k in _rows:
		(_rows[k] as Button).set_pressed_no_signal(k == id)
	var l := Tutorial.lesson_by_id(id)
	_title.text = tr(String(l.title))
	for c in _role.get_children():
		c.queue_free()
	var pill := UI.pill((tr("ROLE_RAIDER") if l.raid else tr("HUD_DEFEND")).to_upper(), Game.C_SAFFRON if l.raid else Game.C_MAGENTA)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_role.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_role.add_child(pill)
	for c in _steps.get_children():
		c.queue_free()
	var rule := int(Game.settings.get("raid_rule", 2))
	if id == "cant" and rule == 0:
		rule = 2
	var n := 1
	for st in l.steps:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		var num := UI.label(str(n), "HeaderLabel", 30, Game.C_SAFFRON)
		num.custom_minimum_size = Vector2(26, 0)
		num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(num)
		var t := UI.wrap(tr(Tutorial.step_key(String(st[0]), rule)), "", 19)
		h.add_child(t)
		_steps.add_child(h)
		n += 1
	var done: Array = Game.settings.get("tutorial_done", [])
	_done_l.text = tr("TUT_DONE") if done.has(id) else ""
	_demo.show_lesson(id)
