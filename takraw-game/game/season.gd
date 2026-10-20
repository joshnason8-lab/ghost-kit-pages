class_name Season
extends RefCounted
## A league season with your club: every club plays every other once, then the top four play the Final Four
## (semi-finals, first against fourth and second against third, and a final). The table: 3 points for a 2-0 win, 2
## for a 2-1, 1 for a 1-2 loss; level teams split on wins, then sets, then points. The awards at the end: the best
## spiker, the best blocker, the best server and the most valuable player; titles go in the record book.

var league := "MY"
var team := ""
var women := false
var year := 2027
var round := 0                 # the next round to play (0-based)
var rounds: Array = []         # each round: [{home, away, played, sets, set_scores}]
var phase := "regular"         # "regular", "semis", "final", "done"
var playoff: Array = []        # the Final Four's fixtures
var champion := ""
var player_stats := {}         # player id -> {kills, blocks, aces, digs, name, team}
var news: Array = []           # headlines, newest last


static func create(league_id: String, team_id: String, p_women := false) -> Season:
	var s := Season.new()
	s.league = league_id
	s.team = team_id
	s.women = p_women
	s.rounds = s._round_robin(DB.league_clubs(league_id))
	s.news.append({"key": "NEWS_SEASON_START", "args": {"l": league_id}})
	return s


static func from_dict(d: Dictionary) -> Season:
	var s := Season.new()
	for k in ["league", "team", "women", "year", "round", "rounds", "phase", "playoff", "champion", "player_stats", "news"]:
		if d.has(k):
			s.set(k, d[k])
	s.year = int(s.year)
	s.round = int(s.round)
	return s


func to_dict() -> Dictionary:
	return {"league": league, "team": team, "women": women, "year": year, "round": round, "rounds": rounds,
		"phase": phase, "playoff": playoff, "champion": champion, "player_stats": player_stats, "news": news}


## Every club against every other once (the circle method), home and away alternating.
func _round_robin(ids: Array) -> Array:
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
			games.append({"home": home, "away": away, "played": false, "sets": [0, 0], "set_scores": []})
		out.append(games)
		# Rotate everyone but the first.
		var last: String = t.pop_back()
		t.insert(1, last)
	return out


## Your next match, or {} when you have none to play.
func next_fixture() -> Dictionary:
	if phase == "regular" and round < rounds.size():
		for f in rounds[round]:
			if (f.home == team or f.away == team) and not f.played:
				return f
	if phase == "semis" or phase == "final":
		for f in playoff:
			if (f.home == team or f.away == team) and not f.played:
				return f
	return {}


func stage_name() -> String:
	match phase:
		"regular":
			return TranslationServer.translate("ROUND_N_OF").format({"n": mini(round + 1, rounds.size()), "of": rounds.size()})
		"semis":
			return TranslationServer.translate("SEMI_FINALS")
		"final":
			return TranslationServer.translate("FINAL")
	return TranslationServer.translate("SEASON_OVER")


## Your result comes in: the rest of the round is played, and the season moves on.
func record_user_result(result: Dictionary) -> void:
	var f := next_fixture()
	if f.is_empty():
		return
	_apply(f, result)
	_play_rest()
	_advance()


## The rest of the round (or of the playoffs' stage) without you.
func _play_rest() -> void:
	var list: Array = rounds[round] if phase == "regular" and round < rounds.size() else playoff
	for f in list:
		if not f.played:
			_apply(f, Sim.play(f.home, f.away, women, 3, 15))


## The season moves on once a round is done; your club out of the playoffs, they are played for you.
func _advance() -> void:
	match phase:
		"regular":
			var done := true
			for f in rounds[round]:
				done = done and bool(f.played)
			if done:
				round += 1
			if round >= rounds.size():
				var tbl := table()
				phase = "semis"
				playoff = [
					{"home": tbl[0].id, "away": tbl[3].id, "played": false, "sets": [0, 0], "set_scores": [], "stage": "SF1"},
					{"home": tbl[1].id, "away": tbl[2].id, "played": false, "sets": [0, 0], "set_scores": [], "stage": "SF2"}]
				news.append({"key": "NEWS_FINAL_FOUR", "args": {"a": tbl[0].id, "b": tbl[1].id, "c": tbl[2].id, "d": tbl[3].id}})
				if next_fixture().is_empty():
					_play_rest()
					_advance()
		"semis":
			if bool(playoff[0].played) and bool(playoff[1].played):
				var w1: String = playoff[0].home if int(playoff[0].sets[0]) > int(playoff[0].sets[1]) else playoff[0].away
				var w2: String = playoff[1].home if int(playoff[1].sets[0]) > int(playoff[1].sets[1]) else playoff[1].away
				playoff.append({"home": w1, "away": w2, "played": false, "sets": [0, 0], "set_scores": [], "stage": "F"})
				phase = "final"
				if next_fixture().is_empty():
					_play_rest()
					_advance()
		"final":
			var fin: Dictionary = playoff[2]
			if bool(fin.played):
				champion = fin.home if int(fin.sets[0]) > int(fin.sets[1]) else fin.away
				phase = "done"
				news.append({"key": "NEWS_CHAMPION", "args": {"t": champion}})
				if champion == team:
					Records.add_title("league_" + league, year)


## Plays the rest of the season for you (from the season screen: when you only want the playoffs, or to see how it
## ends).
func sim_round() -> void:
	var f := next_fixture()
	if not f.is_empty():
		_apply(f, Sim.play(f.home, f.away, women, 3, 15))
	_play_rest()
	_advance()


func _apply(f: Dictionary, r: Dictionary) -> void:
	f.played = true
	# A result from the match screen is from the home side's point of view, as the fixture is.
	f.sets = [int(r.sets[0]), int(r.sets[1])]
	f.set_scores = r.get("set_scores", [])
	for id in r.get("stats", {}):
		var s: Dictionary = r.stats[id]
		var ps: Dictionary = player_stats.get(id, {"kills": 0, "blocks": 0, "aces": 0, "digs": 0, "name": s.get("name", "?"),
			"team": f.home if int(s.get("team", 0)) == 0 else f.away, "matches": 0})
		for k in ["kills", "blocks", "aces", "digs"]:
			ps[k] = int(ps[k]) + int(s.get(k, 0))
		ps.matches = int(ps.matches) + 1
		player_stats[id] = ps
	var w: String = f.home if int(f.sets[0]) > int(f.sets[1]) else f.away
	if f.home == team or f.away == team:
		news.append({"key": "NEWS_YOU_WON" if w == team else "NEWS_YOU_LOST", "args": {"o": f.away if f.home == team else f.home,
			"s": "%d-%d" % [maxi(f.sets[0], f.sets[1]), mini(f.sets[0], f.sets[1])]}})


## The table: [{id, p, w, l, sd, pd, pts}], best first.
func table() -> Array:
	var rows := {}
	for id in DB.league_clubs(league):
		rows[id] = {"id": id, "p": 0, "w": 0, "l": 0, "sd": 0, "pd": 0, "pts": 0}
	for rnd in rounds:
		for f in rnd:
			if not f.played:
				continue
			var a: Dictionary = rows[f.home]
			var b: Dictionary = rows[f.away]
			var sa: int = f.sets[0]
			var sb: int = f.sets[1]
			a.p += 1
			b.p += 1
			if sa > sb:
				a.w += 1
				b.l += 1
			else:
				b.w += 1
				a.l += 1
			a.sd += sa - sb
			b.sd += sb - sa
			for sc in f.set_scores:
				a.pd += int(sc[0]) - int(sc[1])
				b.pd += int(sc[1]) - int(sc[0])
			a.pts += Sim.table_points(sa, sb)
			b.pts += Sim.table_points(sb, sa)
	var out := rows.values()
	out.sort_custom(func(x, y):
		if x.pts != y.pts:
			return x.pts > y.pts
		if x.w != y.w:
			return x.w > y.w
		if x.sd != y.sd:
			return x.sd > y.sd
		return x.pd > y.pd)
	return out


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


## A new season: the same league and club, the year on.
func next_season() -> Season:
	var s := Season.create(league, team, women)
	s.year = year + 1
	return s
