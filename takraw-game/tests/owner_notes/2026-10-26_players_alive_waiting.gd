extends TakrawNote
## The owner, 2026-10-26: "When the players are waiting for a serve or are watching a serve have them move a little,
## like they are prepping to play and are alive. Like a small sway, maybe mixamo has something."

const NOTE := {"id": "2026-10-26-players-alive-waiting", "game": "sepak-takraw", "date": "2026-10-26", "version": "0.11.1",
	"words": "When the players are waiting for a serve or are watching a serve have them move a little, like they are prepping to play and are alive. Like a small sway, maybe mixamo has something."}


## Waiting for the serve at their places (regu and doubles), the receivers and the servers' inside players are never
## still: over every second, the head moves at least 1.5 cm, a sway on their toes.
func check() -> void:
	for ev in ["regu", "doubles"]:
		var m := make_match({"event": ev, "seed": 4})
		var st := {"windows": 0, "still": 0, "runs": {}}
		await play(m, 90.0, func(mm: Node):
			if int(mm.state) != int(mm.S.SETUP):
				st.runs.clear()
				return
			var th: Player = mm._thrower()
			var srv: Player = mm._server()
			for side in 2:
				for pp in mm.players_on(side):
					var pl: Player = pp
					if pl == th or pl == srv or not mm._at_place(pl) or pl.vel.length() > 0.2:
						st.runs.erase(pl)
						continue
					var run: Array = st.runs.get(pl, [])
					run.append(pl.body.bone_world("head"))
					st.runs[pl] = run
					if run.size() >= 30:
						var lo := Vector3.INF
						var hi := -Vector3.INF
						for p in run:
							lo = lo.min(p)
							hi = hi.max(p)
						st.windows += 1
						if (hi - lo).length() < 0.015:
							st.still += 1
						st.runs[pl] = [])
		info("%s: %d one-second waits at their places, %d still" % [ev, st.windows, st.still])
		expect(int(st.windows) >= 10, "%s: only %d one-second waits seen" % [ev, st.windows])
		expect(int(st.still) == 0, "%s: %d one-second waits with the player stock still" % [ev, st.still])
		m.queue_free()
		await frame()
	await clean()
