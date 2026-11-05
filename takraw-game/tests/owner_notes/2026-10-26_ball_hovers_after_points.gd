extends TakrawNote
## The owner, 2026-10-26: "After points the ball seems to just hover in the air until the player gets to position,
## the player should grab the ball or have it with him. Noticed in doubles but check everywhere."

const NOTE := {"id": "2026-10-26-ball-hovers-after-points", "game": "sepak-takraw", "date": "2026-10-26", "version": "0.11.1",
	"words": "After points the ball seems to just hover in the air until the player gets to position, the player should grab the ball or have it with him. Noticed in doubles but check everywhere."}


## Between points (a regu, a doubles and a team event, at three venues), whenever the ball is off the floor it is
## moving or in someone's hands: never still in the air with nobody holding it. And it reaches the thrower each time.
func check() -> void:
	for run in [["doubles", "national"], ["regu", "park"], ["team", "beach"]]:
		var m := make_match({"event": run[0], "venue": run[1], "seed": 5})
		var st := {"between": 0, "hover": 0, "worst": 0, "now": 0, "was": Vector3.INF, "served": 0, "held_thrower": 0}
		await play(m, 120.0, func(mm: Node):
			var between: bool = int(mm.state) in [int(mm.S.DEAD), int(mm.S.BREAK), int(mm.S.SETUP)]
			var b: Ball = mm.ball
			var p := b.global_position
			var still: bool = st.was != Vector3.INF and p.distance_to(st.was) < 0.01
			st.was = p
			if int(mm.state) == int(mm.S.TOSS) and mm._thrower().carrying == false:
				st.served += 1
			if not between:
				st.now = 0
				return
			st.between += 1
			var held := false
			for side in 2:
				for pp in mm.players_on(side):
					held = held or (pp as Player).carrying
			if p.y > 0.25 and still and not held and not b.flying:
				st.hover += 1
				st.now += 1
				st.worst = maxi(int(st.worst), int(st.now))
			else:
				st.now = 0)
		info("%s at the %s: %d frames between points; the ball still in the air with nobody holding it %d frames (at most %d in a row)" % [
			run[0], run[1], st.between, st.hover, st.worst])
		expect(int(st.between) > 300, "%s: too little seen between points (%d frames)" % [run[0], st.between])
		expect(int(st.worst) <= 3, "%s at the %s: the ball hung still in the air for %d frames with nobody holding it" % [run[0], run[1], st.worst])
		m.queue_free()
		await frame()
	await clean()
