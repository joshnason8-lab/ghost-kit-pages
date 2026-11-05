extends Control
## The privacy policy (Settings > About), bundled with the game so it works offline. It says what this build does:
## no personal data, no ads or analytics, no internet permission, only vibration, and what stays on the phone.

const SECTIONS := ["PRIV_SUMMARY", "PRIV_INTERNET", "PRIV_KEPT", "PRIV_PERMS", "PRIV_CHILDREN", "PRIV_CHANGES", "PRIV_CONTACT"]
const Help := preload("res://ui/help_screen.gd")


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("PRIVACY_POLICY"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	v.add_child(UI.scroll(col))
	var date := UI.wrap(tr("PRIV_DATE"), "MutedLabel", 17)
	date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(date)
	for k in SECTIONS:
		col.add_child(Help.card(tr(k), tr(k + "_TEXT")))
