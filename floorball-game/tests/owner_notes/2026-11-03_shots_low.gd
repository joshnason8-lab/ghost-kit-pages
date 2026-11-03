extends WsgOwnerNote
## The owner, 2026-11-03 (Floorball 0.9.6-beta).

const NOTE := {"id": "2026-11-03-shots-low", "game": "floorball", "date": "2026-11-03", "version": "0.9.6-beta",
	"words": "All shots on goal are towards the ground, the ball doesn't lift much. When you're running and plan to shoot the joystick position should factor in to where the ball goes height wise. Unless you have a better idea."}

const Lib := preload("res://tests/note_lib.gd")


## Your shots from 4 to 16 m, the joystick toward the goal, centred and away: aimed by the joystick (high just under
## the bar, mid, low), each arrives at the goal line at the height it was aimed (within 10 cm) - shots aimed high come
## in high, not along the floor. Struck by the game's own shoot() and flown by the game's own Ball.
func check() -> void:
	var m: Node = await Lib.live_match(tree, {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": 0, "seed": 4, "period": 4.0, "mode": "quick"})
	var p: Player = m.skaters(0)[0]
	var a: float = m.attack_dir(0)
	var g := Vector2(Rules.GOAL_LINE * a, 0.0)
	var worst := 0.0
	var highs := []
	for d: float in [4.0, 8.0, 12.0, 16.0]:
		for push: float in [1.0, 0.0, -1.0]:
			m.set_physics_process(false)
			p.respawn(g - Vector2(a * d, 0.0))
			m.ball.release()
			m.ball.carrier = p
			m.ball.pos = Vector3(p.pos.x + a * 0.5, Ball.R, p.pos.y)
			m.ball.live = true
			m.ball.in_goal = 0
			var want: float = m.shot_height(Vector2(a * push, 0.0), g - p.pos)
			m.shoot(p, Vector3(g.x, want, 0.3))
			var b: Ball = m.ball
			var guard := 0
			while (b.pos.x - g.x) * a < 0.0 and guard < 600:
				b.step(1.0 / 60.0)
				guard += 1
			var arrive := b.pos.y
			worst = maxf(worst, absf(arrive - want))
			if push > 0.5:
				highs.append(snappedf(arrive, 0.01))
	m.set_physics_process(true)
	info("toward the goal, the shot arrives at %s m (the bar at %.2f m); worst off its aim %.2f m" % [highs, Rules.GOAL_H, worst])
	expect(worst <= 0.1, "a shot arrived %.2f m off the height it was aimed at" % worst)
	for h: float in highs:
		expect(h >= 0.8, "the joystick toward the goal: the shot came in at %.2f m, not high" % h)
	expect(m.shot_height(Vector2(-1, 0), Vector2(1, 0)) < 0.2, "the joystick away from the goal does not keep it low")
	await Lib.done(tree, m)
