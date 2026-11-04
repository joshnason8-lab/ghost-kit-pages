class_name League
extends RefCounted
## The Club Season (the game's own league; every club invented, DB.CLUBS): eight clubs from four netball countries play
## each other once (seven rounds) or, home and away, twice (fourteen: the second round robin is the first again with
## home and away swapped). Two points for a win, one for a draw; clubs level on points are split by goal percentage.
## Then the top four go to the finals with a second chance for the top two, the page playoff netball leagues use:
## week 1 the major semi (first v second, its winner straight to the grand final) and the minor semi (third v fourth,
## its loser out); week 2 the preliminary final (the major semi's loser v the minor semi's winner); week 3 the grand
## final. Finals go to extra time if level. Seasons saved before the page playoff (no "finals_format") keep their
## single knockout: first v fourth and second v third, the winners in the grand final.

const ROUNDS := 7             # one round robin of the eight clubs; a home-and-away season plays it twice

var user := ""
var teams: Array = []
var fixtures: Array = []      # {home, away, round, played, score}
var finals: Array = []        # {stage, home, away, played, score, winner}; stage major_semi, minor_semi, prelim_final, grand_final (a knockout's: semi, grand_final)
var stage := "season"         # season, semis, prelim (the page playoff's week 2), final, done
var round := 0                # the round being played (0 .. rounds() - 1)
var champion := ""
var legs := 1                 # 1: single (7 rounds); 2: home and away (14 rounds)
var finals_format := "page"   # "page": the page playoff; "knockout": first v fourth, second v third (saves before it)
var rng := RandomNumberGenerator.new()


## p_seed: the season's draw and its other matches' results from this seed (the simulations' reproducible seasons);
## -1, a new one each time. p_legs: 1, each club plays each other once; 2, home and away.
static func create(club: String, p_seed := -1, p_legs := 1) -> League:
	var l := League.new()
	l.user = club
	l.legs = clampi(p_legs, 1, 2)
	l.rng.seed = p_seed if p_seed >= 0 else hash(club) + Time.get_ticks_msec()
	l.teams = DB.club_ids()
	# The draw from the season's own generator (Array.shuffle draws from the global one: not reproducible).
	for i in range(l.teams.size() - 1, 0, -1):
		var j := l.rng.randi_range(0, i)
		var t: String = l.teams[i]
		l.teams[i] = l.teams[j]
		l.teams[j] = t
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
	# Home and away: the second round robin is the first again, in the same order, with home and away swapped (seven
	# home matches each). It draws nothing from the generator, so a seed's single season is what it always was.
	if l.legs == 2:
		for i in l.fixtures.size():
			var f: Dictionary = l.fixtures[i]
			l.fixtures.append({"home": f.away, "away": f.home, "round": int(f.round) + n - 1, "played": false, "score": [0, 0]})
	return l


## The season's rounds: 7 single, 14 home and away.
func rounds() -> int:
	return ROUNDS * legs


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
		if round >= rounds():
			stage = "semis"
			var t := table()
			# The higher-placed club is at home.
			if finals_format == "page":
				finals = [_final("major_semi", t[0].id, t[1].id), _final("minor_semi", t[2].id, t[3].id)]
			else:
				finals = [_final("semi", t[0].id, t[3].id), _final("semi", t[1].id, t[2].id)]
		return
	for k in finals:
		if not k.played:
			var r := Sim.play(k.home, k.away, true, rng)
			k.played = true
			k.score = r.score
			k.winner = k.home if int(r.score[0]) > int(r.score[1]) else k.away
	if stage == "semis" and finals_format == "page":
		# Week 2, the preliminary final: the major semi's loser (first or second, so at home) v the minor semi's winner.
		stage = "prelim"
		finals.append(_final("prelim_final", loser(finals[0]), finals[1].winner))
	elif stage == "semis":
		stage = "final"
		finals.append(_final("grand_final", finals[0].winner, finals[1].winner))
	elif stage == "prelim":
		# Week 3, the grand final: the major semi's winner (at home) v the preliminary final's winner.
		stage = "final"
		finals.append(_final("grand_final", finals[0].winner, finals[2].winner))
	elif stage == "final":
		stage = "done"
		champion = finals.back().winner
		Records.add_league(champion == user)


static func _final(p_stage: String, home: String, away: String) -> Dictionary:
	return {"stage": p_stage, "home": home, "away": away, "played": false, "score": [0, 0], "winner": ""}


## A played final's loser.
static func loser(k: Dictionary) -> String:
	return String(k.away) if k.winner == k.home else String(k.home)


## Where the user's club is in the finals when it has no match to play: "missed" (not in them), "through" (won the
## major semi: the preliminary final is played first), "out" (lost a final that put it out); "" when it has a match,
## or the season is still in its rounds or over.
func user_wait() -> String:
	if stage == "season" or stage == "done" or not next_user_match().is_empty():
		return ""
	var in_finals := false
	for k in finals:
		if k.home == user or k.away == user:
			in_finals = true
	if not in_finals:
		return "missed"
	if finals_format == "page" and stage == "prelim" and finals[0].winner == user:
		return "through"
	return "out"


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
		"champion": champion, "rng_state": str(rng.state), "legs": legs, "finals_format": finals_format}


static func from_dict(d: Dictionary) -> League:
	var l := League.new()
	l.user = String(d.get("user", ""))
	l.teams = d.get("teams", [])
	l.fixtures = d.get("fixtures", [])
	l.finals = d.get("finals", [])
	l.stage = String(d.get("stage", "season"))
	l.round = int(d.get("round", 0))
	l.champion = String(d.get("champion", ""))
	# Saved before the home-and-away option and the page playoff: one round robin and the single knockout.
	l.legs = clampi(int(d.get("legs", 1)), 1, 2)
	l.finals_format = "page" if String(d.get("finals_format", "")) == "page" else "knockout"
	# Saved before 0.9.1 without the generator's state: a new one.
	if d.has("rng_state"):
		l.rng.state = String(d.rng_state).to_int()
	else:
		l.rng.randomize()
	for f in l.fixtures:
		f.round = int(f.round)
	return l
