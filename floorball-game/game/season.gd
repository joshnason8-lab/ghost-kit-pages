class_name Season
extends RefCounted
## The club season: the ten invented clubs (DB.CLUBS) in a single round robin, nine rounds, every club playing each
## other once, the way the Nordic leagues count a table: 3 points for a win in regulation time, 2 for a win in
## overtime or penalty shots, 1 for a loss in overtime or penalty shots, 0 for a loss in regulation. No league match
## is drawn: level after 60 minutes goes to overtime and penalty shots. The table is ordered by points, then goal
## difference, then goals scored. The top four play the semi-finals (1 v 4, 2 v 3, the better placed at home) and
## the winners the final, single matches, decided. A club that misses the top four ends its season with the league:
## the play-offs are simulated and the champion shown.

const STAGES := ["league", "sf", "final", "done"]
const ROUNDS := 9

var user := "FOX"
var women := false
var stage := "league"
var round := 0
var clubs := []             # the ten club ids
var fixtures := {}          # stage -> array of rounds -> array of {home, away, played, goals, ot, so, user}
var champion := ""
var runner_up := ""
var seed := 1


static func create(club: String, p_women := false, p_seed := -1) -> Season:
	var s := Season.new()
	s.user = club
	s.women = p_women
	s.seed = randi() if p_seed < 0 else p_seed
	s.clubs = DB.club_ids().duplicate()
	s.fixtures.league = round_robin(s.clubs, club, s.seed)
	return s


## Nine rounds of five, every pair once: the circle method (one club stays put, the others turn round it), home and
## away alternating so nobody is at home every week. The first round is shuffled by the seed.
static func round_robin(ids: Array, u: String, p_seed := 1) -> Array:
	var order: Array = ids.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var n := order.size()
	var rounds := []
	for r in n - 1:
		var rnd := []
		for k in n / 2:
			var a: String = order[k]
			var b: String = order[n - 1 - k]
			if (r + k) % 2 == 1:
				var t := a
				a = b
				b = t
			rnd.append(_fx(a, b, u))
		rounds.append(rnd)
		# Turn everyone but the first one place round.
		var last = order.pop_back()
		order.insert(1, last)
	return rounds


static func _fx(a: String, b: String, u: String) -> Dictionary:
	return {"home": a, "away": b, "played": false, "goals": [0, 0], "ot": false, "so": false, "user": a == u or b == u}


## Table points for one side of a played match: 3 a win in regulation, 2 a win after overtime or penalty shots, 1 a
## loss after them, 0 a loss in regulation.
static func points(f: Dictionary, side: int) -> int:
	var g: Array = f.goals
	var won := int(g[side]) > int(g[1 - side])
	var extra := bool(f.get("ot", false)) or bool(f.get("so", false))
	if won:
		return 2 if extra else 3
	return 1 if extra else 0


func knockout() -> bool:
	return true   # every match is decided, in the league too


func current_round() -> Array:
	var rs: Array = fixtures.get(stage, [])
	return rs[round] if round < rs.size() else []


## Your match in this round, or {} if you have none (out of the play-offs, or the season is over).
func user_fixture() -> Dictionary:
	for f in current_round():
		if bool(f.user) and not bool(f.played):
			return f
	return {}


## Plays every match of the round the user does not (or all of them, when include_user is true).
func sim_round(include_user := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + round * 101 + STAGES.find(stage) * 7919
	for f in current_round():
		if bool(f.played) or (bool(f.user) and not include_user):
			continue
		var r := Sim.play(f.home, f.away, women, true, rng)
		f.goals = r.goals
		f.ot = r.ot
		f.so = r.so
		f.played = true
	_advance()


## Your match's result, from the match.
func record_user_result(result: Dictionary) -> void:
	var f := user_fixture()
	if f.is_empty():
		return
	var g: Array = result.goals
	f.goals = [int(g[0]), int(g[1])]
	f.ot = bool(result.get("ot", false))
	f.so = bool(result.get("so", false))
	f.played = true
	sim_round()


## The next step when you simulate your own match (or have none): the rest of the round is simulated too.
func sim_next() -> void:
	if stage == "done":
		return
	sim_round(true)


func _advance() -> void:
	for f in current_round():
		if not bool(f.played):
			return
	round += 1
	var rs: Array = fixtures.get(stage, [])
	if round < rs.size():
		return
	round = 0
	match stage:
		"league":
			var t := table()
			fixtures.sf = [[_fx(t[0].id, t[3].id, user), _fx(t[1].id, t[2].id, user)]]
			stage = "sf"
		"sf":
			var w := []
			for f in fixtures.sf[0]:
				w.append(_winner_of(f))
			fixtures.final = [[_fx(w[0], w[1], user)]]
			stage = "final"
		"final":
			var f: Dictionary = fixtures.final[0][0]
			champion = _winner_of(f)
			runner_up = _loser_of(f)
			stage = "done"
	# Out of the play-offs (or never in them): the rest is played without you.
	if stage != "done" and stage != "league" and user_fixture().is_empty():
		sim_round(true)


static func _winner_of(f: Dictionary) -> String:
	return String(f.home) if int(f.goals[0]) > int(f.goals[1]) else String(f.away)


static func _loser_of(f: Dictionary) -> String:
	return String(f.away) if int(f.goals[0]) > int(f.goals[1]) else String(f.home)


## The league table: played, won in regulation, won after overtime or penalty shots, lost after them, lost in
## regulation, goals for and against, points; ordered by points, goal difference, goals scored.
func table() -> Array:
	var rows := {}
	for id in clubs:
		rows[id] = {"id": id, "p": 0, "w": 0, "otw": 0, "otl": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}
	for rnd in fixtures.get("league", []):
		for f in rnd:
			if not bool(f.played) or not rows.has(f.home) or not rows.has(f.away):
				continue
			var extra := bool(f.ot) or bool(f.so)
			for side in 2:
				var r: Dictionary = rows[f.home if side == 0 else f.away]
				var gf := int(f.goals[side])
				var ga := int(f.goals[1 - side])
				r.p += 1
				r.gf += gf
				r.ga += ga
				r.pts += points(f, side)
				if gf > ga:
					if extra:
						r.otw += 1
					else:
						r.w += 1
				elif extra:
					r.otl += 1
				else:
					r.l += 1
	return sort_rows(rows.values())


static func sort_rows(rows: Array) -> Array:
	rows.sort_custom(func(x, y):
		if x.pts != y.pts:
			return x.pts > y.pts
		if x.gf - x.ga != y.gf - y.ga:
			return x.gf - x.ga > y.gf - y.ga
		return x.gf > y.gf)
	return rows


## Where a club stands in the table (1-10).
func place(id: String) -> int:
	var t := table()
	for i in t.size():
		if String(t[i].id) == id:
			return i + 1
	return 0


## The last league round played, or -1.
func last_league_round() -> int:
	var rs: Array = fixtures.get("league", [])
	var last := -1
	for i in rs.size():
		var all := true
		for f in rs[i]:
			if not bool(f.played):
				all = false
		if all:
			last = i
	return last


## How the season ended for you: "champion", "final", "sf" or "missed" (out of the top four); "" while it goes on.
func user_finish() -> String:
	if stage != "done":
		return ""
	if champion == user:
		return "champion"
	if runner_up == user:
		return "final"
	for f in fixtures.get("sf", [[]])[0]:
		if bool(f.user):
			return "sf"
	return "missed"


func to_dict() -> Dictionary:
	return {"user": user, "women": women, "stage": stage, "round": round, "clubs": clubs, "fixtures": fixtures,
		"champion": champion, "runner_up": runner_up, "seed": seed}


static func from_dict(d: Dictionary) -> Season:
	var s := Season.new()
	s.user = String(d.get("user", "FOX"))
	s.women = bool(d.get("women", false))
	s.stage = String(d.get("stage", "league"))
	s.round = int(d.get("round", 0))
	s.clubs = d.get("clubs", DB.club_ids())
	s.fixtures = d.get("fixtures", {})
	s.champion = String(d.get("champion", ""))
	s.runner_up = String(d.get("runner_up", ""))
	s.seed = int(d.get("seed", 1))
	return s
