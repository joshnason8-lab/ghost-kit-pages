extends Node
## A thumb on the controls, through the touch buttons' own signal and the joystick's value, as a player's would be:
##   godot --headless --path . --fixed-fps 30 res://tests/user_bot.tscn -- [idle|play] [minutes]
## play: run at the ball, take what is offered (catch, lift, tackle), strike for the posts when in range, solo when
## the steps run out. It must get the ball, take shots and score. idle: hands off; the match must still finish, and
## your side must not score from anything you did not press (only the computer's teammates' play).
## Exits 1 if not.

var mode := "play"
var minutes := 8.0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		mode = a[0]
	if a.size() > 1:
		minutes = float(a[1])
	Game.main = self
	Game.settings.sound = false
	Game.settings.assist = 0 if mode == "play" else 1
	get_tree().root.size = Vector2i(1280, 720)
	Game.start_match({"home": "LIM", "away": "WAT", "venue": "county", "user_team": 0, "seed": 21, "length": minutes,
		"mode": "quick", "difficulty": 1})
	var m: Node = Game.current
	var presses := {}
	var frames := 0
	var user_shots := 0
	# Hands off, the user's own restarts each wait eight seconds before they are taken for him: room for those.
	while m.phase != m.P.OVER and frames < int(minutes * 60.0 * 30.0 * 2.5):
		await get_tree().process_frame
		frames += 1
		if mode == "idle":
			continue
		var ids: Array = m.controls.ids
		var a_pl: Player = m.active
		if a_pl == null:
			continue
		# The joystick: toward the ball, or toward the goal with it.
		var target: Vector3 = m.ball.global_position
		if a_pl == m.carrier:
			target = Vector3(Pitch.HALF_L * m.dir(0), 0, 0)
		var to := target - a_pl.global_position
		var j := Vector2(to.x, to.z).normalized() if Vector2(to.x, to.z).length() > 1.0 else Vector2.ZERO
		m.controls.joystick = j
		if frames % 6 != 0 or ids.is_empty():
			continue
		var press := ""
		for want in ["GOAL", "STRIKE", "CATCH", "LIFT", "TACKLE", "LONG"]:
			if want in ids:
				press = want
				break
		if press == "STRIKE" and a_pl == m.carrier:
			var dist := Pitch.from_goal_line(a_pl.global_position, m.dir(0))
			if dist > 55.0:
				press = "SOLO" if "SOLO" in ids and m.carry_of(a_pl).steps >= 3 else ""
		if press == "GOAL" and Pitch.from_goal_line(a_pl.global_position, m.dir(0)) > 18.0:
			press = "STRIKE"
		if press != "":
			if press in ["STRIKE", "GOAL"]:
				user_shots += 1
			presses[press] = int(presses.get(press, 0)) + 1
			m.controls.action.emit(press)
	var s: Array = m.score
	print("user_bot %s: %s v %s, presses %s, %d frames" % [mode, Rules.fmt(s[0][0], s[0][1]), Rules.fmt(s[1][0], s[1][1]), JSON.stringify(presses), frames])
	var ok: bool = m.phase == m.P.OVER
	if mode == "play":
		ok = ok and int(presses.get("CATCH", 0)) + int(presses.get("LIFT", 0)) > 3 and user_shots > 2 and Rules.total(s[0][0], s[0][1]) > 0
	if not ok:
		print("FAIL: user_bot %s" % mode)
	get_tree().quit(0 if ok else 1)
