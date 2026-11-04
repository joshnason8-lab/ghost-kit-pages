extends TakrawNote
## The owner, 2026-11-02: "When the player is going back to his position from getting the ball he is gliding and not
## moving his legs."

const NOTE := {"id": "2026-11-02-glide-back-to-place", "game": "sepak-takraw", "date": "2026-11-02", "version": "0.14.1",
	"words": "When the player is going back to his position from getting the ball he is gliding and not moving his legs."}


## Between points, a regu and a doubles match: over every half second a player walks (over 0.8 m/s, on the ground),
## his legs move - the gap between his feet changes by 8 cm or more - whatever move of his is playing (picking the
## ball up, lobbing it to the thrower, a cheer).
func check() -> void:
	var st := {"walks": 0}
	var glides := []
	for ev in ["regu", "doubles"]:
		var m := make_match({"event": ev, "seed": 7})
		var runs := {}
		await play(m, 150.0, func(mm: Node):
			if not int(mm.state) in [int(mm.S.SETUP), int(mm.S.DEAD), int(mm.S.BREAK)]:
				runs.clear()
				return
			for side in 2:
				for pp in mm.players_on(side):
					var pl: Player = pp
					if pl.vel.length() <= 0.8 or absf(pl.body.position.y) > 0.02:
						runs.erase(pl)
						continue
					var ft: Array = pl.body.feet()   # (as drawn)
					var fl: Vector3 = ft[0]
					var fr: Vector3 = ft[2]
					var run: Array = runs.get(pl, [])
					run.append([Vector2(fl.x - fr.x, fl.z - fr.z).length(), pl.move])
					runs[pl] = run
					if run.size() >= 15:
						var gaps: Array = run.map(func(e): return float(e[0]))
						if float(gaps.max()) - float(gaps.min()) < 0.08:
							glides.append(String(run[7][1]))
						else:
							st.walks += 1
						runs[pl] = [])
		m.queue_free()
		await frame()
	info("between points: %d half-second walks, %d with the legs still" % [int(st.walks) + glides.size(), glides.size()])
	expect(int(st.walks) >= 30, "only %d half-second walks seen" % st.walks)
	expect(glides.is_empty(), "%d half-second walks with the legs still (moves playing: %s)" % [glides.size(), glides])
	await clean()
