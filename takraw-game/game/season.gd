class_name Season
extends RefCounted
## A league season, run the way the real league is run (DB.LEAGUES, docs/TAKRAW.md):
##  - "gp", Malaysia's Sepak Takraw League: a circuit of seven Grand Prix. Each is a tournament of its own: four groups
##    of three drawn afresh, the top two of each to the quarter-finals, then the semi-finals, the third place and the
##    final. A finish is worth points (DB.GP_POINTS); the most points after the last Grand Prix win the league, and the
##    last two are relegated. A season in Division 1 is one such tournament, played before the Premier season: its two
##    finalists go up, straight into that season's Premier League.
##  - "ties", the Takraw Thailand League: home and away, each fixture a tie of two regus (both played): 2 points for
##    winning both, 1 for one each. The champion is top of the table.
##  - "zones", Liga Sepak Takraw Indonesia: a round robin in your region; the top two of each of the five regions go to
##    the national finals (two groups of five, the semi-finals, the final).
## A season is a list of events (a Grand Prix, a region, the finals), each a list of stages (the groups, the
## quarter-finals ...), each a list of rounds of fixtures played together. Yours you play or let be played; the rest
## are played out (Sim) as you go.

var league := "MY"
var division := 1              # Malaysia: 1 the Premier League, 2 Division 1
var team := ""
var women := false
var year := 2026
var events: Array = []         # see _event()
var ev_i := 0
var premier: Array = []        # Malaysia: this season's Premier League
var div1: Array = []           # and Division 1, as it will be next season (the relegated two join it)
var standings := {}            # "gp": id -> {pts, titles, w, l}
var phase := "on"              # "on", "done"
var champion := ""
var relegated: Array = []
var promoted: Array = []
var recent: Array = []         # the last round's results
var player_stats := {}
var news: Array = []
var draw_seed := 0
var quiet := false             # played out unseen (Division 1 before your Premier season): no end-of-season business


static func create(league_id: String, team_id: String, p_women := false) -> Season:
	var s := Season.new()
	s.league = league_id
	s.team = team_id
	s.women = p_women and bool(DB.LEAGUES[league_id].get("women", false))
	s.year = int(DB.LEAGUES[league_id].get("year", 2026))
	s.draw_seed = hash(team_id) + Time.get_ticks_msec()
	match String(DB.LEAGUES[league_id].format):
		"gp":
			var top: Array = DB.league_clubs("MY", 1)
			var low: Array = DB.league_clubs("MY", 2)
			if team_id in top:
				s.premier = top
				s.div1 = low
				s._start_premier()
			else:
				# Division 1 of the first season: its clubs and the two the real one sent up this year (it is played
				# again, with you in it).
				var up: Array = DB.STL_PROMOTED
				s.premier = []
				for id in top:
					if not (id in up):
						s.premier.append(id)
				s.div1 = low + up
				s.division = 2
				s.events = [s._gp_event("DIV1", -1, s.div1)]
		"ties":
			s.events = [s._league_event(DB.league_clubs(league_id), true)]
		"zones":
			s.events = [s._zone_event(DB.zone_of(team_id))]
	s.news.append({"key": "NEWS_SEASON_START", "args": {}})
	s._settle()
	return s


static func from_dict(d: Dictionary) -> Season:
	var s := Season.new()
	for k in ["league", "division", "team", "women", "year", "events", "ev_i", "premier", "div1", "standings", "phase",
			"champion", "relegated", "promoted", "recent", "player_stats", "news", "draw_seed"]:
		if d.has(k):
			s.set(k, d[k])
	s.year = int(s.year)
	s.ev_i = int(s.ev_i)
	s.division = int(s.division)
	s.draw_seed = int(s.draw_seed)
	return s


func to_dict() -> Dictionary:
	return {"league": league, "division": division, "team": team, "women": women, "year": year, "events": events,
		"ev_i": ev_i, "premier": premier, "div1": div1, "standings": standings, "phase": phase, "champion": champion,
		"relegated": relegated, "promoted": promoted, "recent": recent, "player_stats": player_stats, "news": news,
		"draw_seed": draw_seed}


## The format the league is played in: "gp", "ties" or "zones".
func format() -> String:
	return String(DB.LEAGUES[league].format)


# ---------------------------------------------------------------- building the season

func _start_premier() -> void:
	division = 1
	standings = {}
	for id in premier:
		standings[id] = {"pts": 0, "titles": 0, "w": 0, "l": 0}
	for i in DB.STL_GPS.size():
		events.append(_gp_event("GP", i, premier))


## An event: {kind, name (a key), args, venue, arena, clubs, stages, stage_i, done, place {id: finish}, champion}.
func _event(kind: String, name: String, args: Dictionary, venue: String, arena: String, clubs: Array) -> Dictionary:
	return {"kind": kind, "name": name, "args": args, "venue": venue, "arena": arena, "clubs": clubs.duplicate(),
		"stages": [], "stage_i": 0, "done": false, "place": {}, "champion": ""}


## A Grand Prix (or Division 1, gp = -1): its draw, four groups of three, unseeded.
func _gp_event(kind: String, gp: int, clubs: Array) -> Dictionary:
	var ev: Dictionary
	if gp >= 0:
		var g: Array = DB.STL_GPS[gp]
		ev = _event("gp", "GP_HOST", {"h": g[0], "n": gp + 1, "of": DB.STL_GPS.size()}, String(g[3]), "%s, %s" % [g[2], g[1]], clubs)
	else:
		ev = _event("div1", "STL_DIV1", {}, "provincial", "", clubs)
	var rng := RandomNumberGenerator.new()
	rng.seed = draw_seed + gp * 7919 + year
	var pot := clubs.duplicate()
	for i in range(pot.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pot[i]
		pot[i] = pot[j]
		pot[j] = tmp
	var groups := []
	for g2 in 4:
		groups.append(pot.slice(g2 * 3, g2 * 3 + 3))
	ev.stages.append(_group_stage(groups, false))
	return ev


## A league round robin: home and away (twice) or once; Thai ties are two regus each.
func _league_event(clubs: Array, twice: bool) -> Dictionary:
	var ev := _event("league", String(DB.LEAGUES[league].name), {}, "", "", clubs)
	var rounds := _round_robin(clubs, false)
	if twice:
		for r in _round_robin(clubs, true):
			rounds.append(r)
	for r in rounds:
		for f in r:
			f.tie = league == "TH"
	ev.stages.append({"kind": "league", "key": "LEAGUE_STAGE", "groups": [clubs.duplicate()], "rounds": rounds, "round_i": 0})
	return ev


## Indonesia: your region's round robin.
func _zone_event(zone: String) -> Dictionary:
	var clubs: Array = []
	for z in DB.LEAGUES.ID.zones:
		if z[0] == zone:
			clubs = (z[1] as Array).duplicate()
	var ev := _event("zone", zone, {}, "provincial", "", clubs)
	ev.stages.append({"kind": "league", "key": "ZONE_STAGE", "groups": [clubs.duplicate()], "rounds": _round_robin(clubs, false), "round_i": 0})
	return ev


## Groups that play a round robin each, all the groups' first matches in the first round, and so on.
func _group_stage(groups: Array, _seeded: bool) -> Dictionary:
	var rounds := []
	for gi in groups.size():
		var rr := _round_robin(groups[gi], false)
		for ri in rr.size():
			while rounds.size() <= ri:
				rounds.append([])
			for f in rr[ri]:
				f.group = gi
				rounds[ri].append(f)
	return {"kind": "groups", "key": "GROUP_STAGE", "groups": groups, "rounds": rounds, "round_i": 0}


static func _fixture(home: String, away: String, tag := "") -> Dictionary:
	return {"home": home, "away": away, "played": false, "sets": [0, 0], "set_scores": [], "tag": tag, "group": -1,
		"tie": false, "regus": []}


## Every club against every other once (the circle method), home and away alternating; swapped: the return games.
func _round_robin(ids: Array, swapped: bool) -> Array:
	var t := ids.duplicate()
	if t.size() % 2 == 1:
		t.append("")
	var n := t.size()
	var out := []
	for r in n - 1:
		var games := []
		for i in n / 2:
			var a: String = t[i]
			var b: String = t[n - 1 - i]
			if a == "" or b == "":
				continue
			var home := a if (r + i) % 2 == 0 else b
			var away := b if home == a else a
			games.append(_fixture(away if swapped else home, home if swapped else away))
		out.append(games)
		var last: String = t.pop_back()
		t.insert(1, last)
	return out


# ---------------------------------------------------------------- where the season is

func event() -> Dictionary:
	return events[mini(ev_i, events.size() - 1)] if not events.is_empty() else {}


func stage() -> Dictionary:
	var ev := event()
	if ev.is_empty() or (ev.stages as Array).is_empty():
		return {}
	return ev.stages[mini(int(ev.stage_i), (ev.stages as Array).size() - 1)]


func _round() -> Array:
	var st := stage()
	if st.is_empty() or int(st.round_i) >= (st.rounds as Array).size():
		return []
	return st.rounds[int(st.round_i)]


## Your next match, or {} when you have none to play.
func next_fixture() -> Dictionary:
	if phase == "done":
		return {}
	for f in _round():
		if (f.home == team or f.away == team) and not f.played:
			return f
	return {}


## Where your next match is played.
func next_venue() -> String:
	var ev := event()
	if String(ev.get("venue", "")) != "":
		return String(ev.venue)
	var f := next_fixture()
	return DB.home_venue(String(f.get("home", team)))


## An event's title: "GP Perak", "Grand Prix 3 of 7: Melaka", "Division 1", "Sumatra" ...
static func title(ev: Dictionary, key := "") -> String:
	var a := {}
	for k in (ev.get("args", {}) as Dictionary):
		var v = ev.args[k]
		a[k] = int(v) if (v is float or v is int) else v
	return TranslationServer.translate(key if key != "" else String(ev.name)).format(a)


## For the home screen's Continue: the league and where it stands, briefly ("STL · GP Perak · Group stage").
func short_stage() -> String:
	if phase == "done":
		return TranslationServer.translate("SEASON_OVER")
	var ev := event()
	var st := stage()
	var where := Season.title(ev, "GP_HOST") if String(ev.kind) == "gp" else Season.title(ev)
	if String(ev.kind) == "league":
		where = TranslationServer.translate(String(DB.LEAGUES[league].name))
	var what: String = TranslationServer.translate(String(st.key)) if String(st.key) in ["GROUP_STAGE", "QUARTER_FINALS", "SEMI_FINALS", "FINALS"] \
		else TranslationServer.translate("ROUND_N_OF").format({"n": int(st.round_i) + 1, "of": (st.rounds as Array).size()})
	return "%s · %s" % [where, what]


## The eyebrow over the season screen: "Grand Prix 3 of 7 · Quarter-finals", "Round 5 of 14" ...
func stage_name() -> String:
	if phase == "done":
		return TranslationServer.translate("SEASON_OVER")
	var ev := event()
	var st := stage()
	var parts := []
	if String(ev.kind) == "gp":
		parts.append(Season.title(ev, "GP_N_OF"))
	elif String(ev.kind) == "zone":
		parts.append(TranslationServer.translate(String(ev.name)))
	elif String(ev.kind) == "finals":
		parts.append(TranslationServer.translate("LSI_FINALS"))
	elif String(ev.kind) == "div1":
		parts.append(TranslationServer.translate("STL_DIV1"))
	match String(st.get("key", "")):
		"GROUP_STAGE":
			parts.append(TranslationServer.translate("GROUP_STAGE"))
		"QUARTER_FINALS", "SEMI_FINALS", "FINALS":
			parts.append(TranslationServer.translate(String(st.key)))
		_:
			parts.append(TranslationServer.translate("ROUND_N_OF").format({"n": int(st.round_i) + 1, "of": (st.rounds as Array).size()}))
	return " · ".join(parts)


## The name of your next match's stage, for the match's intro card.
func match_stage() -> String:
	var ev := event()
	var name := stage_name()
	if String(ev.kind) == "gp":
		name = "%s · %s" % [Season.title(ev, "GP_HOST"), TranslationServer.translate(String(stage().key))]
	var f := next_fixture()
	if String(f.get("tag", "")) == "3P":
		name = TranslationServer.translate("THIRD_PLACE")
	elif String(f.get("tag", "")) == "F":
		name = TranslationServer.translate("FINAL")
	return name


# ---------------------------------------------------------------- playing it

## Your result comes in: the rest of the round is played, and the season moves on.
func record_user_result(result: Dictionary) -> void:
	var f := next_fixture()
	if f.is_empty():
		return
	_apply(f, result)
	_finish_round()


## Your match played for you, and the season on to your next one.
func sim_round() -> void:
	var f := next_fixture()
	if not f.is_empty():
		_apply(f, _sim(f))
	_finish_round()


## Plays out everything left without you (your club out of the tournament, or to see how it ends).
func sim_rest() -> void:
	var guard := 0
	while phase != "done" and guard < 500:
		guard += 1
		sim_round()


func _sim(f: Dictionary) -> Dictionary:
	if not bool(f.get("tie", false)):
		return Sim.play(f.home, f.away, women, 3, 15)
	# A Thai tie: both regus, the clubs' first and second.
	var won := [0, 0]
	var regus := []
	var scores := []
	var stats := {}
	for n in 2:
		var r := Sim.play(f.home, f.away, women, 3, 15, null, n)
		regus.append(r.sets)
		scores.append_array(r.set_scores)
		won[0 if int(r.sets[0]) > int(r.sets[1]) else 1] += 1
		stats.merge(r.stats)
	return {"sets": won, "set_scores": scores, "regus": regus, "stats": stats}


func _apply(f: Dictionary, r: Dictionary) -> void:
	f.played = true
	# A result from the match screen is from the home side's point of view, as the fixture is.
	f.sets = [int(r.sets[0]), int(r.sets[1])]
	f.set_scores = r.get("set_scores", [])
	if r.has("regus"):
		f.regus = r.regus
	elif r.has("tie"):
		f.regus = (r.tie as Dictionary).get("results", [])
		f.set_scores = (r.tie as Dictionary).get("set_scores", [])
	for id in r.get("stats", {}):
		var s: Dictionary = r.stats[id]
		var ps: Dictionary = player_stats.get(id, {"kills": 0, "blocks": 0, "aces": 0, "digs": 0, "name": s.get("name", "?"),
			"team": f.home if int(s.get("team", 0)) == 0 else f.away, "matches": 0})
		for k in ["kills", "blocks", "aces", "digs"]:
			ps[k] = int(ps[k]) + int(s.get(k, 0))
		ps.matches = int(ps.matches) + 1
		player_stats[id] = ps
	if f.home == team or f.away == team:
		var w: String = f.home if int(f.sets[0]) > int(f.sets[1]) else (f.away if int(f.sets[1]) > int(f.sets[0]) else "")
		news.append({"key": "NEWS_YOU_WON" if w == team else ("NEWS_YOU_DREW" if w == "" else "NEWS_YOU_LOST"),
			"args": {"o": f.away if f.home == team else f.home, "s": "%d-%d" % [maxi(f.sets[0], f.sets[1]), mini(f.sets[0], f.sets[1])]}})


## The rest of the round is played; then on through the rounds you are not in (out of a tournament, or a bye) to your
## next match, or to the season's end.
func _finish_round() -> void:
	for f in _round():
		if not f.played:
			_apply(f, _sim(f))
	recent = _round().duplicate(true)
	_step()
	_settle()


## The season on to where you have a match to play (or to its end).
func _settle() -> void:
	var guard := 0
	while phase != "done" and next_fixture().is_empty() and guard < 400:
		guard += 1
		var rnd := _round()
		if rnd.is_empty():
			_step()
			continue
		for f in rnd:
			if not f.played:
				_apply(f, _sim(f))
		_step()


## One step on: the next round; the next stage (drawn from the results) when a stage is done; the next event when an
## event is.
func _step() -> void:
	var ev := event()
	var st := stage()
	if ev.is_empty():
		phase = "done"
		return
	if not st.is_empty():
		var all_played := true
		for f in _round():
			all_played = all_played and bool(f.played)
		if all_played and int(st.round_i) < (st.rounds as Array).size():
			st.round_i = int(st.round_i) + 1
		if int(st.round_i) < (st.rounds as Array).size():
			return
	# The stage is over: the next one, or the event is.
	var nxt := _next_stage(ev)
	if not nxt.is_empty():
		ev.stages.append(nxt)
		ev.stage_i = (ev.stages as Array).size() - 1
		return
	_event_done(ev)
	ev_i += 1
	if ev_i >= events.size():
		_season_done()


## The stage after the one just finished, drawn from its results; {} when the event is over.
func _next_stage(ev: Dictionary) -> Dictionary:
	var st: Dictionary = ev.stages[int(ev.stage_i)]
	var kind := String(ev.kind)
	if kind in ["league", "zone"]:
		return {}
	match String(st.key):
		"GROUP_STAGE":
			var g: Array = st.groups
			var t := []
			for gi in g.size():
				t.append(group_table(st, gi))
			if g.size() == 4:
				# The quarter-finals: each group's winner against another's runner-up.
				return _ko_stage("QUARTER_FINALS", [[t[0][0].id, t[1][1].id, "QF1"], [t[1][0].id, t[0][1].id, "QF2"],
					[t[2][0].id, t[3][1].id, "QF3"], [t[3][0].id, t[2][1].id, "QF4"]])
			return _ko_stage("SEMI_FINALS", [[t[0][0].id, t[1][1].id, "SF1"], [t[1][0].id, t[0][1].id, "SF2"]])
		"QUARTER_FINALS":
			var w := _winners(st)
			return _ko_stage("SEMI_FINALS", [[w[0], w[2], "SF1"], [w[1], w[3], "SF2"]])
		"SEMI_FINALS":
			var w2 := _winners(st)
			var l2 := _losers(st)
			if kind == "finals":
				return _ko_stage("FINALS", [[w2[0], w2[1], "F"]])
			return _ko_stage("FINALS", [[l2[0], l2[1], "3P"], [w2[0], w2[1], "F"]])
	return {}


func _ko_stage(key: String, pairs: Array) -> Dictionary:
	var games := []
	for p in pairs:
		games.append(_fixture(String(p[0]), String(p[1]), String(p[2])))
	return {"kind": "ko", "key": key, "groups": [], "rounds": [games], "round_i": 0}


static func _winner(f: Dictionary) -> String:
	return String(f.home) if int(f.sets[0]) > int(f.sets[1]) else String(f.away)


static func _loser(f: Dictionary) -> String:
	return String(f.away) if int(f.sets[0]) > int(f.sets[1]) else String(f.home)


func _winners(st: Dictionary) -> Array:
	var out := []
	for f in st.rounds[0]:
		out.append(_winner(f))
	return out


func _losers(st: Dictionary) -> Array:
	var out := []
	for f in st.rounds[0]:
		out.append(_loser(f))
	return out


## An event is over: its finishes, and what they bring (Grand Prix points; promotion; the national finals).
func _event_done(ev: Dictionary) -> void:
	ev.done = true
	var kind := String(ev.kind)
	match kind:
		"gp", "div1":
			var place := {}
			var gs: Dictionary = ev.stages[0]
			for gi in (gs.groups as Array).size():
				var t := group_table(gs, gi)
				place[t[2].id] = "g1" if int(t[2].w) > 0 else "g0"
			for f in ev.stages[1].rounds[0]:
				place[_loser(f)] = "qf"
			for f in ev.stages[3].rounds[0]:
				place[_winner(f)] = "1" if f.tag == "F" else "3"
				place[_loser(f)] = "2" if f.tag == "F" else "4"
			ev.place = place
			for id in place:
				if place[id] == "1":
					ev.champion = id
			if kind == "gp":
				for id in place:
					var row: Dictionary = standings.get(id, {"pts": 0, "titles": 0, "w": 0, "l": 0})
					row.pts = int(row.pts) + int(DB.GP_POINTS[place[id]])
					if place[id] == "1":
						row.titles = int(row.titles) + 1
					standings[id] = row
				_count_wins(ev)
				news.append({"key": "NEWS_GP_WON", "args": {"t": ev.champion, "h": ev.args.h}})
			else:
				# Division 1: the two finalists go up, into this season's Premier League.
				promoted = []
				for id in place:
					if place[id] in ["1", "2"]:
						promoted.append(id)
				for id in promoted:
					premier.append(id)
					div1.erase(id)
				news.append({"key": "NEWS_PROMOTED", "args": {"a": promoted[0], "b": promoted[1]}})
				if team in promoted:
					_start_premier()   # on into the Premier League's Grand Prix, this season
		"zone":
			_build_finals(ev)
		"league", "finals":
			ev.champion = _event_champion(ev)


func _count_wins(ev: Dictionary) -> void:
	for st in ev.stages:
		for rnd in st.rounds:
			for f in rnd:
				if f.played:
					standings[_winner(f)].w = int(standings[_winner(f)].w) + 1
					standings[_loser(f)].l = int(standings[_loser(f)].l) + 1


func _event_champion(ev: Dictionary) -> String:
	if String(ev.kind) == "league":
		return String(table()[0].id)
	return _winner(ev.stages[(ev.stages as Array).size() - 1].rounds[0][0])


## Indonesia: the other regions are played out; the top two of each go to the national finals in Jakarta, the five
## winners spread over the two groups and no group with two clubs from one region.
func _build_finals(ev: Dictionary) -> void:
	var winners := []
	var seconds := []
	for z in DB.LEAGUES.ID.zones:
		var t: Array
		if String(z[0]) == String(ev.name):
			t = table_of(ev.stages[0])
		else:
			var other := _zone_event(String(z[0]))
			for rnd in other.stages[0].rounds:
				for f in rnd:
					_apply(f, _sim(f))
			t = table_of(other.stages[0])
		winners.append(t[0].id)
		seconds.append(t[1].id)
	var a := [winners[0], winners[2], winners[4], seconds[1], seconds[3]]
	var b := [winners[1], winners[3], seconds[0], seconds[2], seconds[4]]
	var fin := _event("finals", "LSI_FINALS", {}, "dome", "Jakarta", a + b)
	fin.stages.append(_group_stage([a, b], true))
	events.append(fin)
	if team in a or team in b:
		news.append({"key": "NEWS_QUALIFIED", "args": {}})


func _season_done() -> void:
	phase = "done"
	if quiet:
		return
	match format():
		"gp":
			if division == 1:
				var st := gp_table()
				champion = String(st[0].id)
				relegated = [String(st[st.size() - 1].id), String(st[st.size() - 2].id)]
				for id in relegated:
					premier.erase(id)
					div1.append(id)
				news.append({"key": "NEWS_RELEGATED", "args": {"a": relegated[0], "b": relegated[1]}})
			else:
				champion = String(events[0].champion)   # Division 1's champions (you did not go up)
				_quiet_premier()
		_:
			champion = String(events[events.size() - 1].champion)
	news.append({"key": "NEWS_CHAMPION", "args": {"t": champion}})
	if champion == team and (format() != "gp" or division == 1):
		Records.add_title("league_" + league, year)


## The Premier season you were not in, played out quietly: who it sends down to Division 1.
func _quiet_premier() -> void:
	var q := Season.new()
	q.league = league
	q.team = ""
	q.year = year
	q.draw_seed = draw_seed + 1
	q.premier = premier.duplicate()
	q.div1 = div1.duplicate()
	q._start_premier()
	q.sim_rest()
	relegated = q.relegated
	for id in relegated:
		premier.erase(id)
		div1.append(id)


# ---------------------------------------------------------------- tables

## A group's (or a league's) table: [{id, p, w, d, l, sd, pd, rd, pts}], best first. In a tie league (Thailand) the
## points are 2 a win and 1 a draw, in regus; elsewhere 1 a win (a group of three goes on wins, then sets, then points).
func group_table(st: Dictionary, gi: int) -> Array:
	return _table(st, st.groups[gi])


func table_of(st: Dictionary) -> Array:
	return _table(st, st.groups[0])


func _table(st: Dictionary, ids: Array) -> Array:
	var rows := {}
	for id in ids:
		rows[id] = {"id": id, "p": 0, "w": 0, "d": 0, "l": 0, "sd": 0, "pd": 0, "pts": 0}
	for rnd in st.rounds:
		for f in rnd:
			if not f.played or not rows.has(f.home) or not rows.has(f.away):
				continue
			var a: Dictionary = rows[f.home]
			var b: Dictionary = rows[f.away]
			var sa := int(f.sets[0])
			var sb := int(f.sets[1])
			a.p += 1
			b.p += 1
			if sa > sb:
				a.w += 1
				b.l += 1
			elif sb > sa:
				b.w += 1
				a.l += 1
			else:
				a.d += 1
				b.d += 1
			if bool(f.get("tie", false)):
				# Sets ± over both regus.
				for r in f.regus:
					a.sd += int(r[0]) - int(r[1])
					b.sd += int(r[1]) - int(r[0])
			else:
				a.sd += sa - sb
				b.sd += sb - sa
			for sc in f.set_scores:
				a.pd += int(sc[0]) - int(sc[1])
				b.pd += int(sc[1]) - int(sc[0])
	for id in rows:
		var r: Dictionary = rows[id]
		r.pts = int(r.w) * 2 + int(r.d) if league == "TH" else int(r.w) * (2 if format() == "zones" else 1)
	var out := rows.values()
	out.sort_custom(func(x, y):
		if x.pts != y.pts:
			return x.pts > y.pts
		if x.sd != y.sd:
			return x.sd > y.sd
		return x.pd > y.pd)
	return out


## The league table of a round-robin league (Thailand), or your region's (Indonesia).
func table() -> Array:
	for ev in events:
		if String(ev.kind) in ["league", "zone"]:
			return table_of(ev.stages[0])
	return []


## The STL standings: [{id, pts, titles, w, l}], most points first (then Grand Prix won, then matches won).
func gp_table() -> Array:
	var out := []
	for id in standings:
		var r: Dictionary = standings[id].duplicate()
		r.id = id
		out.append(r)
	out.sort_custom(func(x, y):
		if int(x.pts) != int(y.pts):
			return int(x.pts) > int(y.pts)
		if int(x.titles) != int(y.titles):
			return int(x.titles) > int(y.titles)
		return int(x.w) > int(y.w))
	return out


## Grand Prix played so far.
func gps_done() -> int:
	var n := 0
	for ev in events:
		if String(ev.kind) == "gp" and bool(ev.done):
			n += 1
	return n


## The last finished event (a Grand Prix, Division 1, your region), or {}.
func last_event() -> Dictionary:
	for i in range(mini(ev_i, events.size()) - 1, -1, -1):
		if bool(events[i].done):
			return events[i]
	return {}


## The season's best: [key, player stats] for the top spiker, blocker and server, and the most valuable player.
func awards() -> Array:
	var out := []
	for pair in [["AWARD_SPIKER", "kills"], ["AWARD_BLOCKER", "blocks"], ["AWARD_SERVER", "aces"]]:
		var best := {}
		for id in player_stats:
			var s: Dictionary = player_stats[id]
			if best.is_empty() or int(s[pair[1]]) > int(best[pair[1]]):
				best = s
		if not best.is_empty():
			out.append([pair[0], best, pair[1]])
	var mvp := {}
	var mv := -1.0
	for id in player_stats:
		var s: Dictionary = player_stats[id]
		var v := float(s.kills) + float(s.blocks) * 1.4 + float(s.aces) * 1.3 + float(s.digs) * 0.4 + (8.0 if String(s.team) == champion else 0.0)
		if v > mv:
			mv = v
			mvp = s
	if not mvp.is_empty():
		out.append(["AWARD_MVP", mvp, "kills"])
	return out


## A new season, a year on. Malaysia: the relegated two go down, Division 1's finalists come up (you play Division 1
## if your club went down, or never came up).
func next_season() -> Season:
	var s := Season.new()
	s.league = league
	s.team = team
	s.women = women
	s.year = year + 1
	s.draw_seed = draw_seed + 101
	match format():
		"gp":
			s.premier = premier.duplicate()
			s.div1 = div1.duplicate()
			if team in s.premier:
				# Division 1 is played before the season: its finalists join the Premier League.
				var q := Season.new()
				q.league = league
				q.year = s.year
				q.draw_seed = s.draw_seed
				q.quiet = true
				q.division = 2
				q.premier = s.premier.duplicate()
				q.div1 = s.div1.duplicate()
				q.events = [q._gp_event("DIV1", -1, q.div1)]
				q.sim_rest()
				s.premier = q.premier
				s.div1 = q.div1
				s.promoted = q.promoted
				s._start_premier()
			else:
				s.division = 2
				s.events = [s._gp_event("DIV1", -1, s.div1)]
		"ties":
			s.events = [s._league_event(DB.league_clubs(league), true)]
		"zones":
			s.events = [s._zone_event(DB.zone_of(team))]
	s.phase = "on"
	s.news = [{"key": "NEWS_SEASON_START", "args": {}}]
	s._settle()
	return s
