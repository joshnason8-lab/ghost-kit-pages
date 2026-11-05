extends Control
## Help (Settings > About): how to play in a few lines, the controls, the rules in brief, what the graphics levels do,
## and how to reach the maker with a bug. Bundled with the game, so it works offline; How to Play has the rest.

const SECTIONS := ["HELP_PLAY", "CTRL_MOVE", "CTRL_HIP", "CTRL_DIVE", "CTRL_AIM", "CTRL_SERVE", "HELP_RULES", "HELP_GFX",
	"HELP_CONTACT"]


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("HELP_SUPPORT"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	v.add_child(UI.scroll(col))
	for k in SECTIONS:
		col.add_child(card(tr(k), _names(tr(k + "_TEXT"))))
	var full := UI.button(tr("MENU_HOWTO"), false, func(): Game.show_screen("res://ui/howto_screen.gd"))
	full.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(full)


## The texts name buttons and settings as the game shows them in the player's language.
func _names(s: String) -> String:
	return s.format({"hip": tr("CTRL_HIP"), "dive": tr("CTRL_DIVE"), "settings": tr("MENU_SETTINGS"),
		"graphics": tr("GRAPHICS"), "auto": tr("GFX_AUTO"), "about": tr("SET_ABOUT"), "howto": tr("MENU_HOWTO")})


## A heading and its text on a card; a drag that starts on it reaches the scroll box.
static func card(title: String, text: String) -> Control:
	var c := UI.card()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(col)
	var t := UI.label(title, "SubLabel", 22, Game.C_GOLD)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.fit(t, 2)
	col.add_child(t)
	var d := UI.wrap(text, "", 18)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(d)
	return c
