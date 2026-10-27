extends Node
## A thumb on the match controls, headless: does the game play by touch the way a player would?
##   godot --headless --path . --fixed-fps 30 res://tests/user_bot.tscn -- MODE [minutes]
## play: the bot moves with the joystick toward where the ball will be met and taps HIP (or DIVE for a low ball) as
## it arrives, and SERVE when its side serves. It must strike the ball, win rayas by its own strikes, and the match
## must end. idle: nobody touches the screen; the match still plays on (serves go by themselves) and the user's
## player never strikes on his own. Exits 1 on failure.

var failures := 0


func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	Game.settings.coach = true
	Game.settings.assist = 0
	var args := OS.get_cmdline_user_args()
	var mode := String(args[0]) if args.size() > 0 else "play"
	var mins := float(args[1]) if args.size() > 1 else 3.0
	get_tree().root.size = Vector2i(1280, 720)
	for rules in ["ulama", "classic"]:
		Game.start_match({"home": "ESC", "away": "LLA", "venue": "village" if rules == "ulama" else "stone", "rules": rules, "user_team": 0,
			"seed": 21, "mode": "quick", "length": mins, "difficulty": 0})
		var m: Node = Game.current
		var frames := 0
		var taps := 0
		var mine := 0
		while is_instance_valid(m) and m.phase != m.P.OVER and frames < int(mins * 60.0 * 30.0 * 3.0):
			await get_tree().process_frame
			frames += 1
			if mode == "play":
				taps += _thumb(m)
		if not is_instance_valid(m):
			print("FAIL: the match went away")
			failures += 1
			continue
		var r: Dictionary = m.result()
		var p: Player = m.user_player
		var strikes := 0
		var my_rayas := 0
		for pl in m.teams[0].players:
			strikes += int(pl.stats.strikes) + int(pl.stats.dives)
			my_rayas += int(pl.stats.rayas)
		var serves := int(r.tstats[0].serves)
		print("%s %s: %d frames, phase %d, %d taps, user side strikes %d, rayas by them %d, serves %d, count %s" % [mode, rules, frames,
			m.phase, taps, strikes, my_rayas, serves, JSON.stringify(r.count)])
		if m.phase != m.P.OVER:
			print("FAIL: %s %s: the match did not end" % [mode, rules])
			failures += 1
		if serves < 1:
			print("FAIL: %s %s: the user's side never served" % [mode, rules])
			failures += 1
		if mode == "play" and strikes < 5:
			print("FAIL: %s %s: a thumb on HIP and DIVE struck the ball only %d times" % [mode, rules, strikes])
			failures += 1
		if mode == "play" and int(r.tstats[0].rayas) < 1:
			print("FAIL: %s %s: the user's side won no rayas" % [mode, rules])
			failures += 1
		if mode == "idle":
			# With no help and no thumb, the user's player plays nothing himself (his teammates still do).
			if int(p.stats.strikes) + int(p.stats.dives) > 0:
				print("FAIL: idle %s: the user's player struck the ball by himself" % rules)
				failures += 1
		Game.goto_menu()
		await get_tree().process_frame
	print("user_bot %s: %d failures" % [mode, failures])
	get_tree().quit(1 if failures > 0 else 0)


## One frame of a thumb: steer toward the AI's plan for the user's player, and tap at the moment.
func _thumb(m: Node) -> int:
	var hud = m.hud
	var taps := 0
	if m.phase == m.P.SERVE and m.serve_team == 0 and "SERVE" in hud.touch.ids:
		if randi() % 20 == 0:
			hud.touch._fire("SERVE")
			taps += 1
		return taps
	if not m.is_live():
		hud.touch.joystick = Vector2.ZERO
		return 0
	var ai: TeamAI = m.teams[0].ai
	var p: Player = m.user_player
	if ai.taker != p or ai.intercept.is_empty():
		hud.touch.joystick = Vector2.ZERO
		return 0
	var to: Vector3 = ai.intercept.stand - p.global_position
	to.y = 0.0
	if to.length() > 0.25:
		# The joystick in screen terms: from the camera's right and forward.
		var b: Basis = m.cam.camera.global_transform.basis
		var right := Vector3(b.x.x, 0, b.x.z).normalized()
		var fwd := Vector3(-b.z.x, 0, -b.z.z).normalized()
		var d := to.normalized() * clampf(to.length() / 1.5, 0.3, 1.0)
		hud.touch.joystick = Vector2(d.dot(right), -d.dot(fwd))
	else:
		hud.touch.joystick = Vector2.ZERO
	var t: float = ai.intercept.t
	if t <= float(ai.intercept.lead) + 0.02 and not p.busy():
		hud.touch._fire("HIP" if ai.intercept.kind == "hip" else "DIVE")
		taps += 1
	return taps
