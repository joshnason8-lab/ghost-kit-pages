extends Control
## The privacy policy, in the game itself so it reads offline: what this build does with the player's information
## (nothing leaves the phone), its permissions, the date and who to ask. In English, as written, like the licences.

const UPDATED := "27 October 2026"
const CONTACT := "joshnason8@gmail.com"

const POLICY := """[b]Netball Unleashed: privacy policy[/b]
Last updated %s. Netball Unleashed is published by Josh Nason.

[b]The summary[/b]
The game collects no personal data. There is no account, no sign-in, no server, no analytics, no advertising and no
in-app purchases.

[b]Internet[/b]
The Android game does not have the internet permission, so it cannot send or receive anything. Everything it needs
(the licences, this policy and the help) is inside the game.

[b]What the game keeps on your phone[/b]
Your settings (language, graphics, sound, controls, where you moved the buttons, difficulty) and your progress (the
Nations Cup or Club Season you are playing and your record book). They are small files in the game's own private
storage on your phone. Nobody else can read them, they are never sent anywhere, and uninstalling the game deletes them.

[b]Permissions[/b]
One: vibration, to buzz the phone when your player catches the ball, makes an intercept or your team scores (Settings
turns it off). The game does not use your location, camera, microphone, contacts or files.

[b]Children[/b]
The game collects no information from anyone, children included.

[b]Changes[/b]
If this ever changes, a new version of the game will say so here first, with a new date.

[b]Contact[/b]
Questions: %s."""


const Licences := preload("res://ui/licences_screen.gd")


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("PRIVACY_POLICY"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	v.add_child(UI.scroll(col))
	col.add_child(Licences.text_block(Licences.flow(POLICY % [UPDATED, CONTACT])))
