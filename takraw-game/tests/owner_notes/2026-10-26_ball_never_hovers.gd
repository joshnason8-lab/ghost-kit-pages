extends TakrawNote
## The owner, 2026-10-26: "Never have the ball just hovering in the air, it happens a lot."

const NOTE := {"id": "2026-10-26-ball-never-hovers", "game": "sepak-takraw", "date": "2026-10-26", "version": "0.11.1",
	"words": "Never have the ball just hovering in the air, it happens a lot."}


## All match long (rallies, points, serves; a regu at every venue), the ball off the floor is always moving, or in a
## player's hands, or held at a touch: never still in the air with no one at it for more than three frames.
func check() -> void:
	for v in venues():
		var m := make_match({"venue": v, "seed": 9})
		var st := {"frames": 0, "worst": 0, "now": 0, "was": Vector3.INF, "where": ""}
		await play(m, 90.0, func(mm: Node):
			st.frames += 1
			var b: Ball = mm.ball
			var p := b.global_position
			var still: bool = st.was != Vector3.INF and p.distance_to(st.was) < 0.01
			st.was = p
			var near := INF
			for side in 2:
				for pp in mm.players_on(side):
					var pl: Player = pp
					if pl.carrying:
						near = 0.0
					near = minf(near, p.distance_to(pl.body.bone_world("hand_r")))
					near = minf(near, p.distance_to(pl.body.bone_world("foot_r")))
					near = minf(near, p.distance_to(pl.body.bone_world("foot_l")))
			if p.y > 0.25 and still and not b.flying and near > 0.35:
				st.now += 1
				if int(st.now) > int(st.worst):
					st.worst = st.now
					st.where = "state %d at %s" % [int(mm.state), str(p.snapped(Vector3.ONE * 0.01))]
			else:
				st.now = 0)
		info("%s: %d frames, the ball still in the air with nobody at it at most %d frames in a row %s" % [v, st.frames, st.worst, st.where])
		expect(int(st.worst) <= 3, "%s: the ball hung still in the air %d frames in a row (%s)" % [v, st.worst, st.where])
		m.queue_free()
		await frame()
	await clean()
