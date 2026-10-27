extends Control
## Help, in the game itself (works offline): how to play, the controls, the rules in brief, the graphics levels, and
## how to report a problem. How to Play has the full controls, every rule with its number and the referees' signs, in
## every language; this page is in English, as the licences and the privacy policy are.

const HELP := """[b]Playing[/b]
You play one outfield player: the one with the yellow ring at his feet and the yellow arrow over his head. Your
team-mates and both goalkeepers play themselves. Matches have three periods; the team with more goals wins, with
overtime and penalty shots when a winner is needed.

[b]The controls[/b]
Move: put your left thumb anywhere on the left of the screen and slide it; the joystick appears under it.

With the ball: [b]Shoot[/b] (push the joystick up or down as you press to aim at a corner), [b]Pass[/b] (to the
team-mate the joystick points at), [b]Sprint[/b] (hold).

Without it: [b]Tackle[/b] plays your stick at the ball (from the front; from behind it is a free-hit or a penalty
to them), [b]Switch[/b] takes over the team-mate nearest the ball.

Your free-hits and hit-ins: the buttons become Shoot and Pass. Take it within about nine seconds.

Pause: the pause button at the top right, or the phone's Back button. The camera button changes the view.

Settings: button size, left-handed (swaps the sides), Move buttons (put each where your thumb wants it), game speed.

[b]The rules in brief[/b]
Five players and a goalkeeper a side, on a 40 x 20 m rink inside low boards. The ball may be played with the stick
below the knee, and stopped with the foot, but not kicked into the goal; no hitting, lifting or holding the other
player's stick, no pushing, no playing the ball lying down. Field players may not enter the goalkeeper area. Minor
offences give a free-hit; worse ones two minutes (or five) on the penalty bench, the team a player short. A team that
keeps the ball in its own half without trying to attack is warned for passive play. How to Play (home screen) has
every rule with its number and the referees' signs.

[b]Graphics[/b]
Settings > Graphics: [b]Low[/b] for older and budget phones (the game starts there on them), [b]Medium[/b] for most
phones, [b]High[/b] for recent ones (shadows, the sharpest textures, the fullest crowd). If a match runs slowly the
game lowers the level by itself and says so; Settings > Lower by itself if slow turns that off. Frame rate > Battery
saver runs cooler and longer.

[b]If something is wrong[/b]
Slow or warm: Graphics > Low and Frame rate > Battery saver. Buttons hard to reach: Button size, Left-handed, Move
buttons. A word wrong in your language: tell us the screen and what it says.

[b]Report a problem or ask a question[/b]
Email [b]joshnason8@gmail.com[/b] with your phone's model, its Android version, the graphics level and what happened
(a screenshot helps). The version is at the top of Settings > About.
"""


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("HELP_SUPPORT"), func(): Game.show_screen("res://ui/settings_screen.gd"), tr("SET_ABOUT"))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	v.add_child(UI.scroll(col))
	col.add_child(UI.button(tr("MENU_HOWTO"), false, func(): Game.show_screen("res://ui/howto_screen.gd")))
	col.add_child(UI.rich(UI.flow(HELP)))
	col.add_child(UI.wrap(tr("VERSION_N").format({"v": String(ProjectSettings.get_setting("application/config/version"))}), "MutedLabel", 15))
