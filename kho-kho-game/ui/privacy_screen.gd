extends Control
## The privacy policy, in the game and offline (Settings > About): a summary in the player's language, then the full
## policy in English. It says what this build does: nothing collected, no ads, no analytics, no purchases, no internet
## permission (export_presets.cfg asks only for vibration). Change the date when the policy changes.

const UPDATED := "27 October 2026"

const POLICY := """[b]Kho Kho Rush: Privacy Policy[/b]
Last updated {date}.

Kho Kho Rush is a kho kho game for Android phones, made by Josh Nason. This policy says what the game does with your
  information. It is short, because the game does very little with it.

[b]The summary[/b]
Kho Kho Rush collects no personal data. There is no account, no sign-in, no server, no advertising, no analytics, no
  crash reporting and no in-app purchase.

[b]The internet[/b]
The game does not ask for permission to use the internet, so it cannot send anything anywhere. Everything it shows,
  this policy, the help and the licences included, is inside the game.

[b]What the game keeps on your phone[/b]
Your settings (language, graphics, frame rate, sound, controls, button places, difficulty) and your progress (the
  championship or league you are playing, and your record book). These are small files in the game's own private
  storage. Nobody else can read them, they are never sent anywhere, and uninstalling the game deletes them.

[b]Permissions[/b]
One: vibration, to buzz the phone when something happens to you in a match (you can turn it off in Settings). The
  game does not use your location, camera, microphone, contacts or files.

[b]Children[/b]
The game collects no information from anyone, children included.

[b]Changes[/b]
If this ever changes, the policy in the game will say so, and the date at the top will change.

[b]Contact[/b]
Questions about this policy: {email}."""


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("PRIVACY_POLICY"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	v.add_child(UI.scroll(col))
	var card := UI.card()
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var sum := UI.wrap(tr("PRIVACY_SUMMARY"), "", 19)
	sum.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(sum)
	col.add_child(card)
	var h := UI.wrap(tr("PRIVACY_FULL"), "SubLabel", 20)
	h.add_theme_color_override("font_color", Game.C_GOLD)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(h)
	var policy := LicencesScreen.reflow(POLICY).format({"date": UPDATED, "email": Game.CONTACT_EMAIL})
	col.add_child(LicencesScreen.text_block(policy, false, 17))
