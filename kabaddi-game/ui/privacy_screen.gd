extends Control
## The privacy policy, in the game, with no connection needed: what this build does with information (nothing leaves
## the phone), the one permission it asks for, the date and a contact. The same policy is on the web; the link is there
## for those who want it. In English, as the Licences and Help pages are.

const CONTACT := "https://thekabaddipulse.com/contact/"
const UPDATED := "27 October 2026"

const TEXT := """[b]Kabaddi Raid privacy policy[/b]
Last updated %s. Kabaddi Raid is a kabaddi game for Android phones and tablets, made by Josh Nason.

[b]In short[/b]
Kabaddi Raid does not collect, send, share or sell any personal data. There is no account, no advertising, no analytics and no tracking. The Android app does not have permission to use the internet: everything you do in the game stays on your phone.

[b]What the game keeps, and where[/b]
In its own private storage on your phone, and nowhere else: your settings (language, sound and volume, vibration, graphics, camera, controls, difficulty) and your saved games (your League Season and your Nations Cup). Other apps cannot read them, they are not sent anywhere, and they are not part of your phone's cloud backup. Uninstalling the game deletes them; updating it keeps them.

[b]Permissions[/b]
The game asks for one permission: vibration, so the phone can buzz at a tackle or a point (you can turn it off in Settings). It does not ask to use the internet, your location, contacts, camera, microphone, photos or files. Everything the game shows, these pages included, comes with it.

[b]Links[/b]
A few buttons (View online on this page and on Help) open a page in your phone's web browser. The game sends nothing when you tap one; the page is covered by the policy of the site it is on.

[b]The browser version[/b]
A version of the game also runs in a web browser, at kabaddi-raid-beta.netlify.app. That page is served by Netlify, which keeps standard server logs (such as your IP address and browser type) under Netlify's privacy policy. The game sends nothing to us there either; its settings and saved games stay in your browser's storage on your device.

[b]Children[/b]
Kabaddi Raid is a sports game for players of all ages. It collects no personal information from anyone, children included.

[b]Changes[/b]
If this policy changes, the new version comes with the game and is posted online, with a new date. If the game ever starts to collect any data, the policy will say so before the update that does it is released.

[b]Contact[/b]
Questions about this policy or the game: %s""" % [UPDATED, CONTACT]


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("PRIVACY_POLICY"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	v.add_child(UI.scroll(col))
	var link := UI.button(tr("VIEW_ONLINE"), false, func(): OS.shell_open(Game.PRIVACY_URL))
	link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(link)
	col.add_child(UI.rich_text(TEXT, false, 18))
