extends TakrawNote
## The lead, 2026-11-03, for the owner: the mixed quadrant (the SEA Games' and the King's Cup's open event) - "add an
## owner-note test that a mixed line-up plays a full match". The lead, 2026-11-04: the owner confirmed the format (two
## men and two women a side, the 1.52 m net) and wants it in the league season and the international cups too - "extend
## the mixed-quadrant owner note to cover a season fixture and a cup match".

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
	await _season()
	await _cup()
	await clean()


## A mixed season: every fixture a mixed quadrant (the Thai league's too: one match, not a tie of two regus), your
## fixture played as the season's Play builds it, its result taken into the season, the round's other fixtures played
## out with mixed line-ups, and the season saved and read back as mixed.
func _season() -> void:
	var th := Season.create("TH", "SPB", false, "mixed")
	var ties := 0
	for st in th.event().stages:
		for rnd in st.rounds:
			for f in rnd:
				ties += 1 if bool(f.get("tie", false)) else 0
	expect(ties == 0, "season: the Thai league's mixed season has %d fixtures as ties of two regus (want 0: one mixed quadrant each)" % ties)
	var s := Season.create("MY", "PRK", true, "mixed")
	expect(s.match_event == "mixed" and not s.women, "season: created as %s (women %s), not the mixed quadrant" % [s.match_event, s.women])
	var f := s.next_fixture()
	expect(not f.is_empty(), "season: no fixture to play")
	if f.is_empty():
		return
	var r := await _play_fixture("season", f.home, f.away, s.next_venue(), "season fixture")
	var before := (s.player_stats as Dictionary).size()
	s.record_user_result(r)
	expect(bool(f.played) and int(f.sets[0]) + int(f.sets[1]) > 0, "season: the fixture played is not in the season (%s)" % [f.sets])
	var women := (s.player_stats as Dictionary).keys().filter(func(id): return String(id).contains("|w_")).size()
	info("season: %s %d-%d %s recorded; %d players with stats (%d before), %d of them women" % [f.home, int(f.sets[0]), int(f.sets[1]), f.away,
		(s.player_stats as Dictionary).size(), before, women])
	expect(women >= 4, "season: only %d women in the season's stats after a round (each mixed side has two)" % women)
	var back := Season.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	expect(back.match_event == "mixed", "season: saved and read back as %s" % back.match_event)


## A mixed cup where the event is really played (the Southeast Asian Championship, as the SEA Games have it; not the
## World Championship): your group match played as the cup's Play builds it and taken into the cup, which goes on.
func _cup() -> void:
	expect(Cup.create("world", "THA", false, "mixed").event == "regu", "cup: the World Championship took the mixed quadrant (it has none)")
	var c := Cup.create("sea", "THA", true, "mixed")
	expect(c.event == "mixed" and not c.women, "cup: created as %s (women %s), not the mixed quadrant" % [c.event, c.women])
	var f := c.next_fixture()
	expect(not f.is_empty(), "cup: no fixture to play")
	if f.is_empty():
		return
	var r := await _play_fixture("cup", f.home, f.away, c.venue(), "cup match")
	c.record_user_result(r)
	expect(bool(f.played) and int(f.sets[0]) + int(f.sets[1]) > 0, "cup: the match played is not in the cup (%s)" % [f.sets])
	var others := (c.fixtures as Array).filter(func(x): return bool(x.played) and x.home != c.user and x.away != c.user).size()
	info("cup: %s %d-%d %s recorded; %d other matches played out; title '%s'" % [f.home, int(f.sets[0]), int(f.sets[1]), f.away, others, c.title()])
	expect(others > 0, "cup: the group went no further after your match")
	expect(Cup.from_dict(JSON.parse_string(JSON.stringify(c.to_dict()))).event == "mixed", "cup: saved and read back not mixed")


## A season's or a cup's match as its Play button builds it (mode, event, venue, the women flag off), on Low, one set to
## keep the note short; played to its end with two men and two women a side; the result as the match reports it.
func _play_fixture(mode: String, home: String, away: String, venue: String, what: String) -> Dictionary:
	var m := make_match({"home": home, "away": away, "venue": venue, "event": "mixed", "mode": mode, "women": false,
		"sets": 1, "points": 15, "seed": 6}, Game.GFX_LOW)
	await play(m, 1500.0)
	for side in 2:
		var ps: Array = m.players_on(side)
		var women: int = ps.filter(func(p): return (p as Player).body.women).size()
		expect(ps.size() == 4 and women == 2, "%s: side %d plays %d on court, %d of them women (want 4 and 2)" % [what, side, ps.size(), women])
	var over := int(m.state) == int(m.S.OVER)
	expect(over, "%s: the mixed quadrant did not finish in 25 minutes of play" % what)
	var sets: Array = (m.sets as Array).duplicate()
	var r := {"config": m.config, "winner": 0 if int(sets[0]) > int(sets[1]) else 1, "sets": sets,
		"set_scores": (m.set_scores as Array).duplicate(true), "home": home, "away": away, "stats": (m.stats as Dictionary).duplicate(true)}
	m.queue_free()
	await frame()
	return r
