extends Control
## Help, in the game and offline (Settings > About): how to play, the controls, the rules in brief (with a way to the
## full How to Play), the graphics levels, and how to get in touch or report a bug. It scrolls when dragged from
## anywhere on it, on its words too (the labels pass the touch through).

const CONTROLS := ["CTRL_CHASE", "CTRL_KHO", "CTRL_DIVE", "CTRL_POLE", "CTRL_DEFEND", "CTRL_ASSIST", "CTRL_KEYS"]
const RULES := ["RULES_KHO", "RULES_DIRECTION", "RULES_OUTS", "RULES_FOULS", "RULES_TURNS"]


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("HELP_SUPPORT"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	v.add_child(UI.scroll(col))
	col.add_child(_card(tr("HELP_PLAY"), [["", tr("HELP_PLAY_TEXT")]]))
	var ctrls := []
	for k in CONTROLS:
		ctrls.append([tr(k), tr(k + "_TEXT")])
	col.add_child(_card(tr("HOWTO_CONTROLS"), ctrls))
	var rules := []
	for k in RULES:
		rules.append([tr(k), tr(k + "_TEXT")])
	var rc := _card(tr("HELP_RULES"), rules)
	var all := UI.button(tr("HELP_ALL_RULES"), false, func(): Game.show_screen("res://ui/howto_screen.gd"))
	all.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rc.get_child(0).add_child(all)
	col.add_child(rc)
	col.add_child(_card(tr("HELP_GFX"), [["", tr("HELP_GFX_TEXT").format({"low": tr("GFX_LOW"), "med": tr("GFX_MEDIUM"),
		"high": tr("GFX_HIGH"), "auto": tr("GFX_AUTO"), "screen": tr("SET_DISPLAY")})]]))
	col.add_child(_card(tr("HELP_CONTACT"), [["", tr("HELP_CONTACT_TEXT").format({"email": Game.CONTACT_EMAIL,
		"v": String(ProjectSettings.get_setting("application/config/version"))})]]))


## A card: a heading, then each [title, text] (an empty title: the text alone).
func _card(heading: String, items: Array) -> PanelContainer:
	var card := UI.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	card.add_child(cv)
	var h := UI.wrap(heading, "SubLabel", 22)
	h.add_theme_color_override("font_color", Game.C_GOLD)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(h)
	for it in items:
		if String(it[0]) != "":
			var t := UI.wrap(String(it[0]), "", 19)
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cv.add_child(t)
		var b := UI.wrap(String(it[1]), "MutedLabel" if String(it[0]) != "" else "", 17)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(b)
	return card
