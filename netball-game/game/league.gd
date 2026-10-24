class_name League
extends RefCounted
## The Club Season (the game's own league; every club invented, DB.CLUBS): eight clubs from four netball countries play
## each other once, then the top four go to the finals, as the professional leagues finish: first plays fourth and
## second plays third in the semi-finals, the winners meet in the grand final. Two points for a win, one for a draw;
## clubs level on points are split by goal percentage. Finals go to extra time if level.

const ROUNDS := 7

var user := ""
var teams: Array = []
var fixtures: Array = []      # {home, away, round, played, score}
var finals: Array = []        # {stage: "semi"|"grand_final", home, away, played, score, winner}
var stage := "season"         # season, semis, final, done
var round := 0                # the round being played (0-6)
var champion := ""
var rng := RandomNumberGenerator.new()


static func create(club: String) -> League:
	var l := League.new()
	l.user = club
	l.rng.seed = hash(club) + Time.get_ticks_msec()
	l.teams = DB.club_ids()
	l.teams.shuffle()
	# A round robin by the circle method: one club stays put, the others turn round it a place each round.
	var n := l.teams.size()
	var ring: Array = l.teams.duplicate()
	for r in n - 1:
		for i in n / 2:
			l.fixtures.append({"home": ring[i], "away": ring[n - 1 - i], "round": r, "played": false, "score": [0, 0]})
		ring.insert(1, ring.pop_back())
	# Home matches shared out: each match goes to the club with fewer home matches so far (three or four each).
	var homes := {}
	for f in l.fixtures:
		if int(homes.get(f.away, 0)) < int(homes.get(f.home, 0)):
			var t: String = f.home
			f.home = f.away
			f.away = t
		homes[f.home] = int(homes.get(f.home, 0)) + 1
	return l


## The user's next match: {home, away, stage, n, need_winner}, or {} when they are out or it is over.
func next_user_match() -> Dictionary:
	if stage == "season":
		for f in fixtures:
			if int(f.round) == round and not f.played and (f.home == user or f.away == user):
				return {"home": f.home, "away": f.away, "stage": "ROUND_N", "n": round + 1, "need_winner": false}
		return {}
	for k in finals:
		if not k.played and (k.home == user or k.away == user):
			return {"home": k.home, "away": k.away, "stage": String(k.stage).to_upper(), "need_winner": true}
	return {}


func record_user_result(result: Dictionary) -> void:
	_record(String(result.config.home), String(result.config.away), result.score)
	advance()


func _record(h: String, a: String, score: Array) -> void:
	if stage == "season":
		for f in fixtures:
			if not f.played and f.home == h and f.away == a:
				f.played = true
				f.score = [int(score[0]), int(score[1])]
				return
	for k in finals:
		if not k.played and k.home == h and k.away == a:
			k.played = true
			k.score = [int(score[0]), int(score[1])]
			k.winner = h if int(score[0]) > int(score[1]) else a
			return


## Plays the rest of the round (or the finals stage), then moves the season on.
func advance() -> void:
	if stage == "season":
		for f in fixtures:
			if int(f.round) == round and not f.played:
				var r := Sim.play(f.home, f.away, false, rng)
				f.played = true
				f.score = r.score
		round += 1
		if round >= ROUNDS:
			stage = "semis"
			var t := table()
			# The higher-placed club is at home.
			finals = [
				{"stage": "semi", "home": t[0].id, "away": t[3].id, "played": false, "score": [0, 0], "winner": ""},
				{"stage": "semi", "home": t[1].id, "away": t[2].id, "played": false, "score": [0, 0], "winner": ""},
			]
		return
	for k in finals:
		if not k.played:
			var r := Sim.play(k.home, k.away, true, rng)
			k.played = true
			k.score = r.score
			k.winner = k.home if int(r.score[0]) > int(r.score[1]) else k.away
	if stage == "semis":
		stage = "final"
		finals.append({"stage": "grand_final", "home": finals[0].winner, "away": finals[1].winner, "played": false,
			"score": [0, 0], "winner": ""})
	elif stage == "final":
		stage = "done"
		champion = finals[2].winner
		Records.add_league(champion == user)


## Plays the user's match too (Simulate), then moves on.
func sim_next() -> void:
	var nm := next_user_match()
	if not nm.is_empty():
		var r := Sim.play(nm.home, nm.away, bool(nm.need_winner), rng)
		_record(nm.home, nm.away, r.score)
	advance()


## The ladder: rows {id, p, w, d, l, gf, ga, pct, pts}, by points then goal percentage.
func table() -> Array:
	var rows := {}
	for id in teams:
		rows[id] = {"id": id, "p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pct": 0.0, "pts": 0}
	for f in fixtures:
		if not f.played:
			continue
		var s: Array = f.score
		for side in 2:
			var r: Dictionary = rows[f.home if side == 0 else f.away]
			var gf := int(s[side])
			var ga := int(s[1 - side])
			r.p += 1
			r.gf += gf
			r.ga += ga
			if gf > ga:
				r.w += 1
				r.pts += 2
			elif gf == ga:
				r.d += 1
				r.pts += 1
			else:
				r.l += 1
	var out := rows.values()
	for r in out:
		r.pct = 100.0 * float(r.gf) / maxf(1.0, float(r.ga))
	out.sort_custom(func(x, y): return x.pts > y.pts or (x.pts == y.pts and x.pct > y.pct))
	return out


func to_dict() -> Dictionary:
	return {"user": user, "teams": teams, "fixtures": fixtures, "finals": finals, "stage": stage, "round": round,
		"champion": champion}


static func from_dict(d: Dictionary) -> League:
	var l := League.new()
	l.user = String(d.get("user", ""))
	l.teams = d.get("teams", [])
	l.fixtures = d.get("fixtures", [])
	l.finals = d.get("finals", [])
	l.stage = String(d.get("stage", "season"))
	l.round = int(d.get("round", 0))
	l.champion = String(d.get("champion", ""))
	l.rng.randomize()
	for f in l.fixtures:
		f.round = int(f.round)
	return l
