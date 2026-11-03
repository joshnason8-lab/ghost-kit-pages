extends TakrawNote
## The owner, 2026-10-26: "On a good ace the ball rolls through the walls out of bounds, it should bounce off."

const NOTE := {"id": "2026-10-26-ace-through-walls", "game": "sepak-takraw", "date": "2026-10-26", "version": "0.11.1",
	"words": "On a good ace the ball rolls through the walls out of bounds, it should bounce off."}


## At every venue, a ball sent hard along the floor at each wall (or board, or fence) comes back off it; and in AI play
## (a regu at each venue) the ball never leaves the venue's walls (Ball.bounds).
func check() -> void:
	for v in venues():
		var m := make_match({"venue": v, "seed": 6})
		var b: Ball = m.ball
		var r: Rect2 = b.bounds
		var c := r.get_center()
		for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			b.global_position = Vector3(c.x, Ball.RADIUS, c.y)
			b.flying = false
			b.loose = true
			b.vel = Vector3(dir.x, 0.0, dir.y) * 25.0
			var out := false
			var back := false
			for i in 150:
				b._step_loose(DT)
				var p := b.global_position
				out = out or not _inside(r, p)
				back = back or Vector2(b.vel.x, b.vel.z).dot(dir) < 0.0
			expect(not out and back, "%s: a ball rolled at the %s wall %s" % [v, {Vector2.RIGHT: "+x", Vector2.LEFT: "-x", Vector2.UP: "-z", Vector2.DOWN: "+z"}[dir], "went through it" if out else "did not come back off it"])
		m.queue_free()
		m = make_match({"venue": v, "seed": 6})
		var st := {"out": 0}
		await play(m, 60.0, func(mm: Node):
			var p: Vector3 = mm.ball.global_position
			if not _inside(mm.ball.bounds, p):
				st.out += 1)
		info("%s: walls %s; in play the ball outside them %d frames" % [v, str(r), st.out])
		expect(int(st.out) == 0, "%s: in play the ball was outside the venue's walls %d frames" % [v, st.out])
		m.queue_free()
		await frame()
	await clean()


## Inside the walls: the side walls exactly; at the ends, over a low board, as far as the stand behind it (Ball).
static func _inside(r: Rect2, p: Vector3) -> bool:
	return p.x >= r.position.x - 0.01 and p.x <= r.end.x + 0.01 and p.z >= r.position.y - 0.55 and p.z <= r.end.y + 0.55
