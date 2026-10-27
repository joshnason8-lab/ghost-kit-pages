extends Control
## The privacy policy, in the game itself (works offline), true to this build: no personal data collected, no
## account, no ads, no analytics, no internet permission. docs/PRIVACY.md is the same text, for the store listing.

const POLICY := """[b]Floorball Unleashed: privacy policy[/b]
Last updated 27 October 2026. Floorball Unleashed is made by Josh Nason.

[b]In short[/b]
The game collects no personal data. It has no account and no sign-in, no advertising, no analytics or tracking, and
no in-app purchases, and it does not send anything anywhere.

[b]The internet[/b]
The game does not ask for permission to use the internet (Android's INTERNET permission is off in this build), so it
cannot connect to anything: everything it shows, these pages included, is inside the game.

[b]What stays on your phone[/b]
Your settings (language, graphics, sound, controls, where you put the buttons, difficulty), your World Finals and your
club season in progress, and your record of results. They are small files in the game's own private storage on your phone. Nobody else can read
them, they are never sent anywhere, and uninstalling the game deletes them.

[b]Permissions[/b]
One: vibration, to buzz the phone when something happens to you in a match (your goal, a whistle against you). Turn
it off in Settings > Vibration. The game does not use your location, camera, microphone, contacts or files.

[b]Children[/b]
The game collects no information from anyone, children included.

[b]Changes[/b]
If this ever changes, this page and the date above will change with the game's next version, before the game does
anything new with your information.

[b]Contact[/b]
Questions about privacy: joshnason8@gmail.com.
"""


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("PRIVACY_POLICY"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	v.add_child(UI.scroll(col))
	col.add_child(UI.rich(UI.flow(POLICY)))
