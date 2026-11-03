extends WsgOwnerNote
## The owner, 2026-11-02 (Floorball 0.9.2-beta).

const NOTE := {"id": "2026-11-02-goalie-glide", "game": "floorball", "date": "2026-11-02", "version": "0.9.2-beta",
	"words": "The goalie is not on skates he shouldn't glide."}

const Lib := preload("res://tests/note_lib.gd")


## The goalkeeper moving across his goal, 1, 2 and 3 m: down on his knees he goes in pushes (between them nearly still:
## the slowest stretch under 45% of the fastest), not a steady glide; up on his feet he steps - a planted foot stays
## where it was set down (under 5 mm a frame) and never both feet are off at once.
func check() -> void:
	var m: Node = await Lib.live_match(tree, {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": -1, "demo": true, "seed": 5, "period": 4.0})
	m.set_physics_process(false)
	var gk: Player = m.keeper(0)
	var a: float = m.attack_dir(0)
	var x := -Rules.GOAL_LINE * a + a * 0.6
	for kneel in [true, false]:
		# (He goes down when the ball is in front of his goal, up in his crouch when it is far off.)
		m.ball.release()
		m.ball.set_spot(Vector2(x + a * (5.0 if kneel else 25.0), 0.0) if kneel else Vector2.ZERO)
		for span: float in [1.0, 2.0, 3.0]:
			gk.respawn(Vector2(x, -span * 0.5))
			for f in 40:
				gk.want_vel = Vector2.ZERO
				gk.step(1.0 / 60.0)
				await tree.process_frame
			var moves := []
			var slid := 0
			var both_up := 0
			var frames := 0
			var prev := {}
			for f in 240:
				gk.want_vel = Vector2(0, 1.6)
				gk.want_face = PI if a > 0.0 else 0.0
				var p0 := gk.pos
				gk.step(1.0 / 60.0)
				await tree.process_frame
				moves.append(gk.pos.distance_to(p0) * 60.0)
				var kf: Dictionary = gk.get("_kf")
				if not kneel and kf.has("l") and kf.has("r"):
					frames += 1
					var up := 0
					for side in ["l", "r"]:
						var e: Array = kf[side]
						if float(e[2]) >= 0.0:
							up += 1
						elif prev.has(side) and Vector2((e[0] as Vector3).x - (prev[side] as Vector3).x, (e[0] as Vector3).z - (prev[side] as Vector3).z).length() > 0.005:
							slid += 1
						prev[side] = e[0]
					if up == 2:
						both_up += 1
				if gk.pos.y > span * 0.5:
					break
			var hi := 0.0
			var lo := INF
			for s: float in moves.slice(10):
				hi = maxf(hi, s)
				lo = minf(lo, s)
			if kneel:
				expect(float(gk.get("_kneel")) > 0.9, "the ball in front of his goal, he is not down on his knees")
				info("on his knees over %.0f m: %.2f to %.2f m/s" % [span, lo, hi])
				expect(hi > 0.0 and lo < hi * 0.45, "on his knees over %.0f m he glides (%.2f to %.2f m/s)" % [span, lo, hi])
			else:
				info("on his feet over %.0f m: a planted foot slid in %d frames, both feet up in %d, of %d" % [span, slid, both_up, frames])
				expect(frames > 0, "on his feet: no footwork measured")
				expect(slid == 0, "on his feet over %.0f m a planted foot slid in %d frames" % [span, slid])
				expect(both_up == 0, "on his feet over %.0f m both feet were off the floor at once in %d frames" % [span, both_up])
	m.set_physics_process(true)
	await Lib.done(tree, m)
