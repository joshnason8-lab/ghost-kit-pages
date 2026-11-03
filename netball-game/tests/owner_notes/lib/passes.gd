extends RefCounted
## Every pass in AI matches, as the ball really flew it frame by frame (for the owner's notes on the passes): its kind,
## where it left the hands and where it ended (caught, or on the floor), how far it went over the floor in the air,
## how fast it left the hands, how high it went over them, how long it was in the air, how its height fell frame to
## frame (the worst departure from gravity), and for a pass no one caught how long it took the ball to come down to
## the floor and how far it went on from there.

## AI matches in each of VENUES, FRAMES frames each (30 a second, as the game runs). Returns the passes. HOVER, if
## given, gets each venue's ball held up in the air: the longest run of frames the ball, in no one's hands and in no
## throw, was more than 15 cm off the floor and not falling as a ball falls (not in a net), and what the match was doing.
static func record(h: Node, venues: Array, frames: int, seed := 21, hover := {}) -> Array:
	var out := []
	var k := 0
	for venue in venues:
		var run := 0
		var worst := 0
		var worst_what := ""
		var ys: Array = []
		k += 1
		var m: Match = h._study_match(seed + k, {"venue": venue})
		await h._wait_live(m)
		var cur := {}
		var prev := Vector3.INF
		var prev2 := Vector3.INF
		for f in frames:
			await h.get_tree().process_frame
			var b: Ball = m.ball
			var at := b.position
			# Up in the air, in no hands and no throw: it must be falling at g (or in a net, which holds it back).
			ys.append(at.y)
			if ys.size() > 3:
				ys.pop_front()
			var free := b.state != "held" and b.state != "flight" and at.y > Ball.R + 0.15 and m.speed == 1
			for side: int in [-1, 1]:
				var rc := Court.ring_centre(side)
				if Vector2(at.x - rc.x, at.z - rc.z).length() < 0.6 and at.y > rc.y - 0.7:
					free = false
			if free and ys.size() == 3:
				var acc: float = (float(ys[2]) - 2.0 * float(ys[1]) + float(ys[0])) * 900.0
				if absf(acc + Ball.G) > Ball.G * 0.5:
					run += 1
					if run > worst:
						worst = run
						worst_what = "the ball %s, %.2f m up, the match %s %.1f s in, %s" % [b.state, at.y, m.phase, m.phase_t, m.restart.get("why", "")]
				else:
					run = 0
			else:
				run = 0
			var flying: bool = b.state == "flight" and m.pass_info.has("to") and m.speed == 1
			if flying and cur.is_empty():
				var v0 := b.flight_vel(0.0)
				cur = {"venue": venue, "kind": String(m.pass_info.kind), "from": b.f_from, "to": b.f_to, "plan_dur": b.f_dur,
					"speed": v0.length(), "across": Vector2(v0.x, v0.z).length(), "top": b.f_from.y, "air": 0.0,
					"g_worst": 0.0, "end": "", "frames": 0, "bounce": b.f_bounce > 0.0}
				prev = Vector3.INF
				prev2 = Vector3.INF
			if not cur.is_empty() and cur.end == "":
				if flying or b.state == "flight":
					cur.top = maxf(float(cur.top), at.y)
					cur.air = float(cur.air) + 1.0 / 30.0
					cur.frames = int(cur.frames) + 1
					# (Only while the flight is under way: past its time the ball waits at the catch.)
					var in_flight: bool = b.state == "flight" and b.f_t <= b.f_dur
					if in_flight and prev2 != Vector3.INF and not bool(cur.bounce):
						var a := (at.y - 2.0 * prev.y + prev2.y) * 900.0
						cur.g_worst = maxf(float(cur.g_worst), absf(a + Ball.G) / Ball.G)
					if in_flight:
						prev2 = prev
						prev = at
						cur.last = at
				else:
					# The flight is over: caught, or the ball goes on loose.
					cur.flat = Vector2(float(cur.last.x) - cur.from.x, float(cur.last.z) - cur.from.z).length() if cur.has("last") else 0.0
					if b.state == "held" and m.holder != null:
						cur.end = "caught"
						out.append(cur)
						cur = {}
					elif b.state == "loose":
						cur.end = "loose"
						cur.loose_at = at
						cur.loose_t = 0.0
						cur.floor_t = -1.0
						cur.loose_flat = 0.0
					else:
						cur.end = String(b.state)
						out.append(cur)
						cur = {}
			elif not cur.is_empty() and cur.end == "loose":
				cur.loose_t = float(cur.loose_t) + 1.0 / 30.0
				cur.loose_flat = Vector2(at.x - cur.loose_at.x, at.z - cur.loose_at.z).length()
				if float(cur.floor_t) < 0.0 and at.y <= Ball.R + 0.005:
					cur.floor_t = cur.loose_t
				if b.state != "loose" or float(cur.loose_t) > 4.0:
					# (Taken out of the air by a player before it came down: not a ball left to fall.)
					cur.picked = b.state != "loose" and float(cur.floor_t) < 0.0
					cur.stopped = b.state != "loose" or Vector2(b.vel.x, b.vel.z).length() < 0.05
					out.append(cur)
					cur = {}
		hover[venue] = [worst, worst_what]
		m.queue_free()
		await h.get_tree().process_frame
		await h.get_tree().process_frame
	return out


## A pass as one line.
static func line(p: Dictionary) -> String:
	return "%s, %s: %.1f m over the floor in %.2f s, left the hands at %.1f m/s (%.1f across), %.2f m over them at the top, %s" % [p.venue,
		p.kind, float(p.get("flat", 0.0)), float(p.air), float(p.speed), float(p.across), float(p.top) - p.from.y, p.end]
