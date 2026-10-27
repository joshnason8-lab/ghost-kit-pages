extends Control
## Help, in the game, with no connection needed: how to play in brief, the controls, the rules, the graphics levels and
## how to report a problem. How to Play (translated, with every move and rule) opens from here; the support page on the
## web is a link for those who want it. The text is in English, as the Licences and Privacy pages are.

const CONTACT := "https://thekabaddipulse.com/contact/"

const TEXT := """[b]Playing[/b]
Kabaddi is played by two teams of seven on a court split by a midline. Each turn one team sends a raider into the other half. He has to touch one or more defenders and get back over the midline before his breath (or the raid clock) runs out. Each defender he touches is out, and a point to his team. If the defenders stop him, by holding him until his breath runs out or pushing him out, he is out and they score.

[b]Raiding[/b]
Move with the stick on the left of the screen: put your thumb down anywhere there. Cross the baulk line, then touch a defender with Hand touch or Toe touch, or with a Kick behind you. Dodge, Dubki (ducking under linked hands) and Lion jump (over a dive) get you away from a tackle. If you are caught, Break free lights up: tap it to wrestle loose. Then get back over the midline.

[b]Defending[/b]
You control one defender at a time; tap another player, or Switch, to change. Hold the raider with Ankle hold, Thigh hold or Waist hold, or Dash him out of the court. Chain links you with a team-mate, for a chain tackle. Keep the raider from getting home.

[b]The rules in brief[/b]
A touched defender, or a stopped raider, is out. Each point a team scores brings one of its out players back, in the order they went out (revival). Putting the whole other team out wins two extra points, and they all come back (all out). After two empty raids in a row, the next raid must score or the raider is out (do or die). With six or more defenders on the mat, a raider who gets a foot over the bonus line, the other foot off the ground, wins a bonus point. Three raid rules, in Settings: the 30-second clock (the Pro rule), the cant on one breath (the raider chants by himself; sprinting and moves use breath), or the cant you tap yourself.

[b]The modes[/b]
Quick Match: two teams, one ground, play now. League Season: own a franchise, keep your best players, win the auction, then the league and the final. Nations Cup: pick a country and its squad of twelve, through the groups to the final.

[b]Controls[/b]
The buttons on the right change with what you are doing: raiding, defending or tackled. Settings has bigger buttons, Move buttons (drag each one to where your thumb finds it) and left-handed controls, which swap the sides. The pause button stops the match, with Move buttons in its menu as well.

[b]Graphics[/b]
Settings > Graphics has three levels. Low draws the least, for any phone: soft shadows under the players, no glow. Medium adds the sun's shadows, the sky's light, the surfaces' relief and sharper players, courts and crowd. High makes the sun's shadows sharper. Auto graphics (on unless you turn it off) lowers the level by itself if your phone cannot keep up, and says so. Frame rate trades smooth play against battery.

[b]Saves[/b]
Your settings, League Season and Nations Cup are kept on your phone. Updating the game keeps them; uninstalling it deletes them.

[b]Something not working?[/b]
Tell us through our contact page, %s, with your phone's model and what happened. A screenshot helps. To measure a problem for us: tap the version number on the home screen seven times to turn on the developer's overlay, play until it happens, tap Copy summary and paste it into your message. Seven more taps turn it off.""" % CONTACT


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("HELP_SUPPORT"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	v.add_child(UI.scroll(col))
	var links := HFlowContainer.new()
	links.add_theme_constant_override("h_separation", 10)
	links.add_theme_constant_override("v_separation", 10)
	links.add_child(UI.button(tr("HOW_TITLE"), true, func(): Game.show_screen("res://ui/howto_screen.gd", {"back": "res://ui/help_screen.gd"})))
	links.add_child(UI.button(tr("VIEW_ONLINE"), false, func(): OS.shell_open(Game.SUPPORT_URL)))
	col.add_child(links)
	col.add_child(UI.rich_text(TEXT, false, 18))
