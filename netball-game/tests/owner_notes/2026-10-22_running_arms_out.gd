extends WsgOwnerNote
## The owner, 2026-10-22, on 0.2.x (round three: the code-built run held its arms out).

const NOTE := {"id": "2026-10-22-running-arms-out", "game": "netball", "date": "2026-10-22", "version": "0.2.x",
	"words": "Use the running .FBX from the other games in development, the running with the arms out looks awkward."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")


## The run is the one the other games use: the sprint is the owner's Mixamo Fast_Run shared with Hurling (its left
## thigh forward a quarter of the way through the stride), and on Medium and High with the licensed clips the shared
## foundation draws every player and umpire on the shared rig. And nobody runs with her arms out, on any level: the
## game's own bodies (Low; Medium too) running at 3.5, 6.8 and 7.2 m/s, marking sideways, defending, backing off and
## with the ball behind her, umpires at both paces, and every runner in two AI matches - elbows bent 45-125 degrees,
## hands within 12 cm of the shoulder across her, the upper arm within 30 degrees of her side (test_runner
## _gait_steps); the foundation's bodies on Medium and High running, marking and defending with elbows bent 45 degrees
## or more and never an A- or T-pose.
func check() -> void:
	var lf := HeroBody.stride_pose("Fast_Run", 0.25)
	var lt: Vector3 = (lf[0][ToonBody.BONES.map(func(b): return b[0]).find("thigh_l")] as Quaternion) * Vector3.DOWN
	expect(lt.z > 0.25, "the sprint is not the shared Fast_Run (the left thigh at the stride's quarter: %.2f forward)" % lt.z)
	var h: Node = await Harness.make(tree)
	await h._gait_steps()
	if Harness.have_clips():
		var sq: Array = DB.squad("NZL")
		for g in [Game.GFX_MEDIUM, Game.GFX_HIGH]:
			Game.settings.graphics = g
			FoundationLink.off = false
			for case: Array in [["run", 3.5, 0.0], ["run", 6.8, 0.0], ["mark", 4.0, 1.0], ["defend", 3.0, 0.0], ["run", 3.0, -1.0]]:
				var pl := Player.new(0, sq[2], "WA")
				h.add_child(pl)
				await frame()
				var what := "%s, the foundation's player %s at %.1f m/s" % [["Low", "Medium", "High"][g], case[0], case[1]]
				if not expect(pl.link != null, "%s: not drawn by the shared foundation (the clips are here)" % what):
					pl.queue_free()
					continue
				pl.fenced = false
				pl.place(Vector2.ZERO, 0.0)
				var st := [0.0, 0, ""]
				pl.link.body.posed.connect(func():
					var a := WsgNoteChecks.arms(pl.link.body)
					st[0] += (float(a.Left[1]) + float(a.Right[1])) * 0.5
					st[1] += 1
					var tp := WsgNoteChecks.t_or_a_pose(pl.link.body)
					if tp != "":
						st[2] = tp)
				var go := Vector2(1, 0) if float(case[2]) > 0.0 else Vector2(0, 1)
				for f in 120:
					pl.set_act(case[0])
					pl.target = pl.p + go * 8.0
					pl.want_speed = case[1]
					pl.look_on = float(case[2]) != 0.0
					pl.look_at_p = pl.p + Vector2(0, 10) if float(case[2]) > 0.0 else pl.p - go * 10.0
					pl.advance(1.0 / 30.0)
					await frame()
					if f == 30:
						st[0] = 0.0
						st[1] = 0
				var elbow: float = float(st[0]) / maxf(1.0, st[1])
				info("%s: elbows %.0f deg on average over %d poses%s" % [what, elbow, st[1], (", " + String(st[2])) if st[2] != "" else ""])
				expect(int(st[1]) > 40 and elbow >= 45.0, "%s: the arms nearly straight (elbows %.0f deg)" % [what, elbow])
				expect(st[2] == "", "%s: %s" % [what, st[2]])
				pl.queue_free()
				await frame()
	else:
		info("(no licensed clips here: the foundation's bodies not measured)")
	await Harness.into(self, h)
