class_name WsgWatchSetup
extends Control
## Watch AI, the same in every game (owner-approved item 8): the home screen's entry (entry_button()) opens this - the
## two sides and the venue picked - and Watch starts the game's AI-v-AI match, which the game shows with WsgSpectator
## (the broadcast camera, pause, 1x/2x, Exit, and a Skip button over each replay).
##   var b := WsgWatchSetup.entry_button(theme); menu.add_child(b)
##   b.pressed.connect(func():
##       var w := WsgWatchSetup.new(theme, team_names, venue_names); add_child(w)
##       w.watch.connect(func(home, away, venue): w.queue_free(); start_watch(home, away, venue))
##       w.closed.connect(w.queue_free))

signal watch(home: int, away: int, venue: int)
signal closed

var theme_b: WsgBroadcastTheme
var home: OptionButton
var away: OptionButton
var venue: OptionButton
var go: Button


static func entry_button(p_theme: WsgBroadcastTheme = null) -> Button:
	var t := p_theme if p_theme else WsgBroadcastTheme.default()
	var b := Button.new()
	b.name = "WatchAI"
	b.text = TranslationServer.translate("Watch AI")
	b.custom_minimum_size = Vector2(160, 52)
	b.add_theme_font_size_override("font_size", t.sub_size)
	b.add_theme_color_override("font_color", t.text)
	b.add_theme_stylebox_override("normal", t.style(t.panel))
	b.add_theme_stylebox_override("pressed", t.style(t.accent.darkened(0.3)))
	return b


func _init(p_theme: WsgBroadcastTheme = null, teams: Array = [], venues: Array = []) -> void:
	theme_b = p_theme if p_theme else WsgBroadcastTheme.default()
	name = "WsgWatchSetup"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", theme_b.style(theme_b.panel))
	add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	col.add_child(theme_b.label(tr("Watch AI"), theme_b.title_size, theme_b.accent))
	home = _pick(col, tr("Home"), teams, 0)
	away = _pick(col, tr("Away"), teams, mini(1, teams.size() - 1))
	venue = _pick(col, tr("Venue"), venues, 0)
	var row := HBoxContainer.new()
	col.add_child(row)
	go = Button.new()
	go.text = tr("Watch")
	go.custom_minimum_size = Vector2(120, 52)
	go.pressed.connect(func(): watch.emit(home.selected, away.selected, venue.selected))
	row.add_child(go)
	var bk := Button.new()
	bk.text = tr("Back")
	bk.custom_minimum_size = Vector2(96, 52)
	bk.pressed.connect(func(): closed.emit())
	row.add_child(bk)


func _pick(parent: Control, label: String, items: Array, sel: int) -> OptionButton:
	parent.add_child(theme_b.label(label, theme_b.sub_size, theme_b.sub_text))
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(280, 48)
	for it in items:
		o.add_item(str(it))
	if items.size() > 0:
		o.select(clampi(sel, 0, items.size() - 1))
	parent.add_child(o)
	return o
