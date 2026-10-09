extends Control
## How to play: topics down the left, and for each a page of short sections with bold
## headings and one point per line, the moves picked out in bold.

const TOPICS := [
	{"title": "HT_RAIDING", "icon": "play", "pose": "quick", "sections": [
		["H_RAID", "HOW_RAID"], ["MOVES", "HOW_MOVES"], ["H_BONUS", "HOW_BONUS"]]},
	{"title": "HT_CANT", "icon": "mic", "pose": "cup", "sections": [
		["RULE_CANT_AUTO", "RULE_BREATH_NOTE"], ["RULE_CANT_VOICE", "RULE_VOICE_NOTE"],
		["RULE_CANT_TAP", "RULE_TAP_NOTE"], ["RULE_CLOCK", "RULE_CLOCK_NOTE"]]},
	{"title": "HT_DEFENDING", "icon": "people", "pose": "defend", "sections": [
		["HUD_DEFEND", "HOW_DEFEND"], ["DEF_SKILLS", "HOW_STYLES"], ["BTN_CHAIN", "HOW_CHAIN"], ["BTN_SWITCH", "HOW_SWITCH"]]},
	{"title": "HT_RULES", "icon": "whistle", "pose": "howto", "sections": [
		["LOBBY", "HOW_LINES"], ["H_REVIVAL", "HOW_REVIVE"], ["H_ALL_OUT", "HOW_ALLOUT"], ["HUD_DOD", "HOW_DOD"],
		["FIVE_SECONDS", "HOW_FIVE"], ["CARDS", "HOW_CARDS"]]},
	{"title": "HT_MATCH", "icon": "trophy", "pose": "league", "sections": [
		["TEAM_ENERGY", "HOW_ENERGY"], ["GOLDEN_RAID", "HOW_TIEBREAK"], ["MILESTONES", "HOW_MILESTONES"]]},
	{"title": "HT_CONTROLS", "icon": "gear", "pose": "dubki", "sections": [
		["HT_CONTROLS", "HOW_CONTROLS"]]},
]
const BOLD_TERMS := ["BTN_CANT", "BTN_TOUCH", "BTN_LEG", "BTN_DODGE", "BTN_DUBKI", "BTN_JUMP", "BTN_ANKLE", "BTN_THIGH",
	"BTN_WAIST", "BTN_DASH", "BTN_CHAIN", "BTN_SWITCH"]

var _tabs: Array = []
var _page: VBoxContainer
var _art: TextureRect
var _title: Label
var _cur := 0


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("HOW_TITLE"), func(): Game.goto_menu())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)

	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	tabs.custom_minimum_size = Vector2(270, 0)
	row.add_child(tabs)
	for i in TOPICS.size():
		var b := _tab(i)
		tabs.add_child(b)
		_tabs.append(b)

	var card := PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	row.add_child(card)
	var stack := Control.new()
	card.add_child(stack)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.anchor_left = 0.68
	_art.anchor_top = 0.05
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.modulate = Color(Game.C_SAFFRON, 0.16)
	stack.add_child(_art)
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("separation", 6)
	stack.add_child(inner)
	_title = UI.label("", "HeaderLabel", 48, Game.C_SAFFRON)
	inner.add_child(_title)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 18)
	inner.add_child(UI.scroll(_page))
	_show(0)
	Game.settings.seen_howto = true
	Game.save_settings()


func _tab(i: int) -> Button:
	var t: Dictionary = TOPICS[i]
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 62)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = tr(String(t.title))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Game.C_PANEL, 0.7)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 58
	var on: StyleBoxFlat = sb.duplicate()
	on.bg_color = Color(Game.C_SAFFRON, 0.2)
	on.border_color = Game.C_SAFFRON
	on.border_width_left = 4
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", on)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_font_override("font", Game.font_bold)
	b.add_theme_font_size_override("font_size", 21)
	var ic := Icon.make(String(t.icon), 26, Game.C_GOLD)
	ic.position = Vector2(18, 18)
	ic.size = Vector2(26, 26)
	b.add_child(ic)
	b.pressed.connect(func():
		Sfx.click()
		_show(i))
	return b


func _show(i: int) -> void:
	_cur = i
	for k in _tabs.size():
		(_tabs[k] as Button).set_pressed_no_signal(k == i)
	var t: Dictionary = TOPICS[i]
	_title.text = tr(String(t.title))
	_art.texture = UI.pose(String(t.pose))
	for c in _page.get_children():
		c.queue_free()
	for sec in t.sections:
		_page.add_child(_section(tr(sec[0]), tr(sec[1])))


func _section(head: String, body: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(UI.label(head, "SubLabel", 24, Game.C_GOLD))
	for line in _points(body):
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 12)
		var dot := UI.swatch(Game.C_SAFFRON, Vector2(6, 6))
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var dot_box := MarginContainer.new()
		dot_box.add_theme_constant_override("margin_top", 13)
		dot_box.add_child(dot)
		r.add_child(dot_box)
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.add_theme_font_override("normal_font", Game.font_body)
		rt.add_theme_font_override("bold_font", Game.font_bold)
		rt.add_theme_font_size_override("normal_font_size", 20)
		rt.add_theme_font_size_override("bold_font_size", 20)
		rt.add_theme_color_override("default_color", Game.C_INK)
		rt.text = _bold(line)
		r.add_child(rt)
		v.add_child(r)
	return v


## One point per sentence, without a leading "Heading:" (the section shows it already).
func _points(body: String) -> Array:
	var text := body.strip_edges()
	var colon := text.find(":")
	if colon > 0 and colon < 32 and text.find(".") > colon:
		text = text.substr(colon + 1).strip_edges()
		text = text.substr(0, 1).to_upper() + text.substr(1)
	var out := []
	var cur := ""
	var i := 0
	while i < text.length():
		var ch := text[i]
		cur += ch
		var end := ch in [".", "!", "?", "।"]
		if end and (i + 1 >= text.length() or text[i + 1] == " "):
			# "30-second" style numbers aside, a full stop then a space ends a point.
			out.append(cur.strip_edges())
			cur = ""
		i += 1
	if cur.strip_edges() != "":
		out.append(cur.strip_edges())
	return out


## Pick out the button names in bold.
func _bold(line: String) -> String:
	var s := line.replace("[", "(").replace("]", ")")
	for k in BOLD_TERMS:
		var term := tr(k)
		if term.length() > 2 and s.find(term) >= 0:
			s = s.replace(term, "[b]" + term + "[/b]")
	return s
