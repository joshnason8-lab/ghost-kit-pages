extends TakrawNote
## The lead, 2026-11-03, for the owner: the mixed quadrant (the SEA Games' and the King's Cup's open event) - "add an
## owner-note test that a mixed line-up plays a full match".

const NOTE := {"id": "2026-11-03-mixed-quadrant", "game": "sepak-takraw", "date": "2026-11-03", "version": "0.15.15",
	"words": "Mixed quadrant: a mixed line-up plays a full match (the lead's request for the owner)."}


## A mixed quadrant, on Low and on High: four a side on court, two men and two women each (their own bodies), the
## women in the feeder's and a striker's places, the net at the men's height; played on to its end, a side winning the
## set, both sides scoring.
func check() -> void:
	for g in [Game.GFX_LOW, Game.GFX_HIGH]:
		var m := make_match({"event": "mixed", "sets": 1, "points": 15, "seed": 6}, g)
		await play(m, 1500.0)
		var lvl: String = ["Low", "Medium", "High"][g]
		for side in 2:
			var ps: Array = m.players_on(side)
			var women: int = ps.filter(func(p): return (p as Player).body.women).size()
			expect(ps.size() == 4 and women == 2, "%s: side %d plays %d on court, %d of them women (want 4 and 2)" % [lvl, side, ps.size(), women])
			var feeder: Player = (ps.filter(func(p): return (p as Player).role == DB.POS_FEEDER) + [null])[0]
			expect(feeder != null and feeder.body.women, "%s: side %d's feeder is a woman" % [lvl, side])
		expect(is_equal_approx(float(m.arena.net_top), Court.NET_M), "%s: the net at %.2f m (the men's %.2f)" % [lvl, float(m.arena.net_top), Court.NET_M])
		var over := int(m.state) == int(m.S.OVER)
		var sc: Array = m.set_scores[0] if not (m.set_scores as Array).is_empty() else [m.points[0], m.points[1]]
		info("%s: %s, set %d-%d" % [lvl, "played to its end" if over else "NOT over", int(sc[0]), int(sc[1])])
		expect(over, "%s: the mixed quadrant did not finish in 25 minutes of play" % lvl)
		expect(maxi(int(sc[0]), int(sc[1])) >= 15 and mini(int(sc[0]), int(sc[1])) > 0, "%s: the set ended %d-%d" % [lvl, int(sc[0]), int(sc[1])])
		m.queue_free()
		await frame()
	await clean()
