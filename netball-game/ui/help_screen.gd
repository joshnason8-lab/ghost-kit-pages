extends Control
## Help, in the game itself so it reads offline: the controls and the rules in brief (the How to Play words, in the
## player's language), the graphics levels, then what to do if something is wrong and how to report it (English).

const CONTACT := "joshnason8@gmail.com"

const REPORT := """[b]If something is wrong[/b]
The game runs slowly or the phone gets warm: Settings > Graphics > Low, and Frame rate > Battery saver. Budget phones
start on Low by themselves.

Words in your language look wrong: tell us the screen and what it says.

[b]Report a bug or ask a question[/b]
Email %s with your phone's make and model, the game's version (%s, shown in Settings > About) and what happened just
before. A screenshot helps."""

const CONTROLS := ["CTRL_MOVE", "CTRL_PASS", "CTRL_SHOOT", "CTRL_DEFEND", "CTRL_INTERCEPT", "CTRL_PLAY_AS"]
const RULES := ["RULES_GOAL", "RULES_CENTRE", "RULES_FOOTWORK", "RULES_THREE", "RULES_OBSTRUCTION", "RULES_OFFSIDE"]


const Licences := preload("res://ui/licences_screen.gd")


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("HELP_SUPPORT"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	var right: HBoxContainer = get_meta("header_right")
	right.add_child(UI.button(tr("MENU_HOWTO"), false, func(): Game.show_screen("res://ui/howto_screen.gd")))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	v.add_child(UI.scroll(col))
	var block := func(bb: String): col.add_child(Licences.text_block(bb))
	block.call(_section(tr("HOWTO_CONTROLS"), CONTROLS))
	block.call(_section(tr("HOWTO_RULES"), RULES))
	block.call("[b]%s[/b]\n%s · %s · %s\n%s\n%s" % [_p(tr("GRAPHICS")), _p(tr("GFX_LOW")), _p(tr("GFX_MEDIUM")),
		_p(tr("GFX_HIGH")), _p(tr("GFX_NOTE")), _p(tr("FPS_NOTE_SAVER").format({"n": Game.saver_cap(60)}))])
	block.call(Licences.flow(REPORT % [CONTACT, String(ProjectSettings.get_setting("application/config/version"))]))


## A heading, then each key's title in bold and its words.
func _section(title: String, keys: Array) -> String:
	var parts := PackedStringArray(["[b]%s[/b]" % _p(title)])
	for k in keys:
		parts.append("[b]%s[/b] %s" % [_p(tr(k)), _p(tr(k + "_TEXT"))])
	return "\n".join(parts)


static func _p(s: String) -> String:
	return s.replace("[", "[lb]")
