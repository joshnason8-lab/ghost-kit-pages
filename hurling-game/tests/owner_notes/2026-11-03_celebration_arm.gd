extends WsgOwnerNote
## The owner, 2026-11-03 (Hurling 0.21.0): "After the score there is an awkward closeup of the player who scored moving his hand around, find a different celebration that one makes the arm look broken."

const NOTE := {"id": "2026-11-03-celebration-arm", "game": "hurling", "date": "2026-11-03", "version": "Hurling 0.21.0", "words": "After the score there is an awkward closeup of the player who scored moving his hand around, find a different celebration that one makes the arm look broken."}
const Kit := preload("res://tests/note_kit.gd")
const HELD := [0.5, 1.8]     # s of the 2.2: the arms up and held (raised by 0.4, lowered from 1.87)

## The scorer's celebration, every frame as drawn: both arms up and held (no hand waving about: while they
## are held up, each hand moves under 6 cm a frame), and no elbow bent the wrong way (more than 3 degrees past straight).
func check() -> void:
	var m: Node = await Kit.match(tree, {"mode": "test", "seed": 3}, 40)
	m.set_process(false)       # (the scorer held to his celebration: the match's brains would have him off after the ball)
	var pl: Player = m.player_by_num(0, 11)
	pl.visible_on_screen = true
	pl.set_pose_rate(1)
	pl.vel = Vector3.ZERO
	var st := {"frames": 0, "up": 0, "move": 0.0, "bend": 0.0, "last": []}
	var cb := Kit.watch(pl.link.body, func(b: WsgBody) -> void:
		if pl.action != "celebrate":
			return
		st.frames += 1
		var hands := [b.bone_world("LeftHand").origin, b.bone_world("RightHand").origin]
		var head: float = b.bone_world("Head").origin.y
		if float((hands[0] as Vector3).y) > head and float((hands[1] as Vector3).y) > head:
			st.up += 1
			if not (st.last as Array).is_empty() and pl.action_t > HELD[0] and pl.action_t < HELD[1]:
				for i in 2:
					st.move = maxf(st.move, (hands[i] as Vector3).distance_to(st.last[i]))
		st.last = hands
		for side in ["Left", "Right"]:
			st.bend = minf(st.bend, Kit.bend(b, side + "Arm", side + "ForeArm", side + "Hand", Vector3.DOWN if side == "Left" else Vector3.UP)))
	pl.play("celebrate")
	var t := 0.0
	while t <= float(Player.ACTIONS.celebrate[0]):
		pl.action_t = t
		pl.animate(float(m.now) + t)
		await Kit.frames(tree, 1)
		t += 1.0 / 30.0
	Kit.unwatch(pl.link.body, cb)
	info("%d frames drawn, both hands over the head in %d; the most a raised hand moved in a frame %.1f cm; an elbow's most backwards %.1f degrees" % [st.frames, st.up, st.move * 100.0, -st.bend])
	expect(st.frames > 20 and st.up > st.frames / 2, "the arms are not up and held (%d of %d frames)" % [st.up, st.frames])
	expect(st.move < 0.06, "a raised hand waves about: %.1f cm in a frame" % (st.move * 100.0))
	expect(st.bend >= -3.0, "an elbow bent %.1f degrees the wrong way" % -st.bend)
	await Kit.done(tree, m)
