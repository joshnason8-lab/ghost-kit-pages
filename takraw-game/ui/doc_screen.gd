extends Control
## A page of text from Settings > About, in the game itself (it needs no internet): the privacy policy or the help.
## Each section a heading and its words, in the player's language. The help: playing, the rules in brief (How to
## Play's), what to change on a slow phone and what each graphics level does, and how to report a bug or write to us.
## Opened over Settings (from the home screen or over a paused match): back closes it.

const PRIVACY := [["PRIV_SUMMARY_T", "PRIV_SUMMARY"], ["PRIV_KEEP_T", "PRIV_KEEP"], ["PRIV_PERM_T", "PRIV_PERM"],
	["PRIV_CHILD_T", "PRIV_CHILD"], ["PRIV_CHANGE_T", "PRIV_CHANGE"], ["PRIV_CONTACT_T", "PRIV_CONTACT"]]
const HELP := [["HELP_PLAY_T", "HELP_PLAY"], ["HELP_SERVE_T", "HELP_SERVE"], ["HELP_ATTACK_T", "HELP_ATTACK"],
	["RULES_TOUCHES", "RULES_TOUCHES_TEXT"], ["RULES_SCORE", "RULES_SCORE_TEXT"], ["RULES_FAULTS", "RULES_FAULTS_TEXT"],
	["HELP_SLOW_T", "HELP_SLOW"], ["HELP_PHONE_T", "HELP_PHONE"], ["GRAPHICS", "HELP_GFX"], ["HELP_WORDS_T", "HELP_WORDS"],
	["HELP_CONTACT_T", "HELP_CONTACT"]]
const EMAIL := "joshnason8@gmail.com"
const UPDATED := "2026-10-26"   # the privacy policy's date (as takraw-smash/privacy.html has it)

var kind := "privacy"
var _back := Callable()


func setup(args: Dictionary) -> void:
	kind = String(args.get("kind", "privacy"))
	_back = args.get("back", Callable())


func _ready() -> void:
	UI.screen(self)
	var privacy := kind == "privacy"
	var v := UI.page(self, tr("PRIVACY_POLICY" if privacy else "HELP_SUPPORT"), _back, tr("SET_ABOUT"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	v.add_child(UI.scroll(col))
	if privacy:
		col.add_child(UI.wrap(tr("PRIV_UPDATED").format({"date": UPDATED}), "MutedLabel", 16))
	# The settings and buttons it names, as the game shows them in this language.
	var names := {"email": EMAIL}
	for k in ["settings:MENU_SETTINGS", "speed:GAME_SPEED", "slow:SPEED_SLOW", "assist:ASSIST", "full:ASSIST_FULL",
			"graphics:GRAPHICS", "auto:GFX_AUTO", "low:GFX_LOW", "medium:GFX_MEDIUM", "high:GFX_HIGH", "fps:FRAME_RATE",
			"saver:FPS_SAVER", "size:BUTTON_SIZE",
			"left:LEFT_HANDED", "serve:BTN_SERVE", "horse:BTN_HORSE", "feint:BTN_FEINT", "block:BTN_BLOCK"]:
		names[k.get_slice(":", 0)] = tr(k.get_slice(":", 1))
	for s in (PRIVACY if privacy else HELP):
		col.add_child(UI.label(tr(s[0]), "", 22, Game.C_INK))
		col.add_child(UI.wrap(tr(s[1]).format(names), "MutedLabel", 18))
	if not privacy:
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 10)
		row.add_theme_constant_override("v_separation", 10)
		row.add_child(UI.button(tr("MENU_HOWTO"), true, func(): _open_over("res://ui/howto_screen.gd")))
		row.add_child(UI.button(tr("HELP_EMAIL"), false, func(): OS.shell_open("mailto:" + EMAIL + "?subject=Sepak%20Takraw%20Unleashed")))
		col.add_child(row)


## Another page over this one (How to Play), back to this.
func _open_over(path: String) -> void:
	var s: Control = (load(path) as Script).new()
	var close := func(): s.queue_free()
	if s.has_method("setup"):
		s.setup({"back": close})
	add_child(s)
