class_name WsgTutorial
extends CanvasLayer
## Tutorial prompts, the same in every game (owner-approved item 8): a tip shown when its moment comes (show_when),
## gone when the player has done it (done_when) or taps Got it, and never shown again (kept in WsgSettings
## "tutorial_seen"); Skip tips turns them all off ("tutorial_off"). One at a time, at the top of the screen, themed.
##   var tips := WsgTutorial.new(theme); add_child(tips)
##   tips.add("move", "Drag on the left to run", func(): return match_started, func(): return player.moved > 3.0)
##   tips.add("tag", "Touch a defender, then run home", func(): return raid_started)

signal shown(id: String)
signal finished(id: String)

var theme_b: WsgBroadcastTheme
var tips: Array = []          # [{id, text, show, done}]
var current := ""
var _panel: PanelContainer
var _label: Label


func _init(p_theme: WsgBroadcastTheme = null) -> void:
	theme_b = p_theme if p_theme else WsgBroadcastTheme.default()
	name = "WsgTutorial"
	layer = 30
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", theme_b.style(theme_b.panel))
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)
	_label = theme_b.label("", theme_b.sub_size, theme_b.text)
	_label.custom_minimum_size = Vector2(320, 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_label)
	var ok := Button.new()
	ok.name = "GotIt"
	ok.text = tr("Got it")
	ok.custom_minimum_size = Vector2(80, 44)
	ok.pressed.connect(func(): _finish())
	row.add_child(ok)
	var skip := Button.new()
	skip.name = "SkipTips"
	skip.text = tr("Skip tips")
	skip.custom_minimum_size = Vector2(80, 44)
	skip.pressed.connect(func():
		WsgSettings.set_value("tutorial_off", true)
		_finish())
	row.add_child(skip)
	_panel.visible = false


## A tip: ID (kept once seen), TEXT, SHOW_WHEN() true when its moment has come, DONE_WHEN() true once the player has
## done it (default: Got it only).
func add(id: String, text: String, show_when: Callable, done_when := Callable()) -> void:
	tips.append({"id": id, "text": text, "show": show_when, "done": done_when})


static func seen(id: String) -> bool:
	return id in (WsgSettings.get_value("tutorial_seen", []) as Array)


## Shows every tip again (Settings > Help > Show tips again).
static func reset() -> void:
	WsgSettings.set_value("tutorial_seen", [])
	WsgSettings.set_value("tutorial_off", false)


func _process(_d: float) -> void:
	if bool(WsgSettings.get_value("tutorial_off", false)):
		_panel.visible = false
		current = ""
		return
	if current != "":
		var t: Dictionary = tips.filter(func(x: Dictionary) -> bool: return x.id == current)[0]
		if (t.done as Callable).is_valid() and (t.done as Callable).call():
			_finish()
		return
	for t: Dictionary in tips:
		if not seen(t.id) and (t.show as Callable).call():
			current = t.id
			_label.text = tr(t.text)
			_panel.visible = true
			shown.emit(t.id)
			return


func _finish() -> void:
	if current == "":
		return
	var s: Array = (WsgSettings.get_value("tutorial_seen", []) as Array).duplicate()
	if not s.has(current):
		s.append(current)
	WsgSettings.set_value("tutorial_seen", s)
	var id := current
	current = ""
	_panel.visible = false
	finished.emit(id)
