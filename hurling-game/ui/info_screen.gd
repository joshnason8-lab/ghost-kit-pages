extends Control
## The privacy policy and the help page, in the game itself (from Settings > About): a card for each part, a heading
## and its text, in the player's language. {"page": "privacy"} or {"page": "help"}. The same words as the pages on
## the web (ash-and-leather/privacy.html and support.html), which the game no longer opens.

const PAGES := {
	"privacy": ["PRIVACY_POLICY", ["PRIV_SUMMARY", "PRIV_KEPT", "PRIV_HD", "PRIV_PERMS", "PRIV_CHILDREN", "PRIV_CHANGES",
		"PRIV_CONTACT"]],
	"help": ["HELP_SUPPORT", ["HELP_PLAYING", "HELP_RULES", "HELP_GRAPHICS", "HELP_SLOW", "HELP_BUTTONS", "HELP_INSTALL",
		"HELP_IRISH", "HELP_CONTACT"]],
}

var page := "privacy"


func setup(args: Dictionary) -> void:
	page = String(args.get("page", "privacy"))


func _ready() -> void:
	UI.screen(self)
	var p: Array = PAGES.get(page, PAGES.privacy)
	var v := UI.page(self, tr(p[0]), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	v.add_child(UI.scroll(col))
	if page == "privacy":
		col.add_child(UI.wrap(tr("PRIV_DATE"), "MutedLabel", 16))
	for k in p[1]:
		var card := UI.card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 4)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(c)
		var t := UI.label(tr(k), "SubLabel", 22, Game.C_GOLD)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.fit(t, 2)
		c.add_child(t)
		var d := UI.wrap(tr(k + "_TEXT"), "", 18)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(d)
		col.add_child(card)
