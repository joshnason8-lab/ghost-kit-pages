class_name Cup
extends RefCounted
## The World Finals: sixteen national teams as the World Championships are played (IFF format, docs/RULES.md,
## "Competition"). Groups A and B hold the eight best-ranked, C and D the next eight; each plays the other three in its
## group, two points a win, one a draw (a group match may be drawn). The top two of A and B go straight to the
## quarter-finals; the third and fourth of A and B meet the first and second of C and D in the play-offs for the
## other four places. Then quarter-finals, semi-finals, the bronze match and the final, each decided in overtime and
## penalty shots if level.

const STAGES := ["groups", "playoffs", "qf", "sf", "medals", "done"]

var user := "SWE"
var women := false
var stage := "groups"
var round := 0
var groups := []            # four arrays of team ids
var fixtures := {}          # stage -> array of rounds -> array of {home, away, played, goals, ot, so, user}
var medals := {}
var seed := 1


static func create(country: String, p_women := false) -> Cup:
	var c := Cup.new()
	c.user = country
	c.women = p_women
	c.seed = randi()
	var ids: Array = DB.team_ids()
	ids.sort_custom(func(a, b): return DB.rating(a, p_women) > DB.rating(b, p_women))
	var field: Array = ids.slice(0, 16)
	if not (country in field):
		field[15] = country
		field.sort_custom(func(a, b): return DB.rating(a, p_women) > DB.rating(b, p_women))
	# The seeding: the snake through the top eight for A and B, the next eight for C and D.
	c.groups = [[], [], [], []]
	for i in 8:
		c.groups[[0, 1, 1, 0][i % 4]].append(field[i])
	for i in 8:
		c.groups[[2, 3, 3, 2][i % 4]].append(field[8 + i])
	c.fixtures.groups = []
	var pairs := [[[0, 1], [2, 3]], [[0, 2], [1, 3]], [[0, 3], [1, 2]]]
	for r in 3:
		var rnd := []
		for g in c.groups:
			for p in pairs[r]:
				rnd.append(_fx(g[p[0]], g[p[1]], country))
		c.fixtures.groups.append(rnd)
	return c


static func _fx(a: String, b: String, u: String) -> Dictionary:
	return {"home": a, "away": b, "played": false, "goals": [0, 0], "ot": false, "so": false, "user": a == u or b == u}


func knockout() -> bool:
	return stage != "groups"


## The fixtures of the round being played.
func current_round() -> Array:
	var rs: Array = fixtures.get(stage, [])
	return rs[round] if round < rs.size() else []


## Your match in this round, or {} if you have none (out, or a bye).
func user_fixture() -> Dictionary:
	for f in current_round():
		if bool(f.user) and not bool(f.played):
			return f
	return {}


func still_in() -> bool:
	return stage != "done" and not user_fixture().is_empty()


## Plays every match of the round the user does not (or all of them, when user is true too).
func sim_round(include_user := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + round * 101 + STAGES.find(stage) * 7919
	for f in current_round():
		if bool(f.played) or (bool(f.user) and not include_user):
			continue
		var r := Sim.play(f.home, f.away, women, knockout(), rng)
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
	f.goals = result.goals
	f.ot = bool(result.get("ot", false))
	f.so = bool(result.get("so", false))
	f.played = true
	sim_round()


## The next step when the user has no match to play: the rest is simulated.
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
		"groups":
			var a := group_table(0)
			var b := group_table(1)
			var c := group_table(2)
			var d := group_table(3)
			fixtures.playoffs = [[_fx(a[2].id, d[1].id, user), _fx(a[3].id, c[0].id, user), _fx(b[2].id, c[1].id, user), _fx(b[3].id, d[0].id, user)]]
			fixtures.qf_direct = [a[0].id, a[1].id, b[0].id, b[1].id]
			stage = "playoffs"
		"playoffs":
			var w := _winners("playoffs")
			var q: Array = fixtures.qf_direct
			fixtures.qf = [[_fx(q[0], w[3], user), _fx(q[1], w[2], user), _fx(q[2], w[1], user), _fx(q[3], w[0], user)]]
			stage = "qf"
		"qf":
			var w := _winners("qf")
			fixtures.sf = [[_fx(w[0], w[3], user), _fx(w[1], w[2], user)]]
			stage = "sf"
		"sf":
			var w := _winners("sf")
			var l := _losers("sf")
			fixtures.medals = [[_fx(l[0], l[1], user), _fx(w[0], w[1], user)]]
			stage = "medals"
		"medals":
			var bronze: Dictionary = fixtures.medals[0][0]
			var final: Dictionary = fixtures.medals[0][1]
			medals = {"gold": _winner_of(final), "silver": _loser_of(final), "bronze": _winner_of(bronze), "fourth": _loser_of(bronze)}
			stage = "done"


func _winners(st: String) -> Array:
	var out := []
	for f in fixtures[st][0]:
		out.append(_winner_of(f))
	return out


func _losers(st: String) -> Array:
	var out := []
	for f in fixtures[st][0]:
		out.append(_loser_of(f))
	return out


static func _winner_of(f: Dictionary) -> String:
	return String(f.home) if int(f.goals[0]) > int(f.goals[1]) else String(f.away)


static func _loser_of(f: Dictionary) -> String:
	return String(f.away) if int(f.goals[0]) > int(f.goals[1]) else String(f.home)


## A group's table: played, won, drawn, lost, goals for and against, points (2 a win, 1 a draw); ties by goal
## difference, then goals scored.
func group_table(g: int) -> Array:
	var rows := {}
	for id in groups[g]:
		rows[id] = {"id": id, "p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}
	for rnd in fixtures.groups:
		for f in rnd:
			if not bool(f.played) or not rows.has(f.home):
				continue
			var h: Dictionary = rows[f.home]
			var a: Dictionary = rows[f.away]
			var gh := int(f.goals[0])
			var ga := int(f.goals[1])
			h.p += 1
			a.p += 1
			h.gf += gh
			h.ga += ga
			a.gf += ga
			a.ga += gh
			if gh > ga:
				h.w += 1
				h.pts += 2
				a.l += 1
			elif ga > gh:
				a.w += 1
				a.pts += 2
				h.l += 1
			else:
				h.d += 1
				a.d += 1
				h.pts += 1
				a.pts += 1
	var out: Array = rows.values()
	out.sort_custom(func(x, y):
		if x.pts != y.pts:
			return x.pts > y.pts
		if x.gf - x.ga != y.gf - y.ga:
			return x.gf - x.ga > y.gf - y.ga
		return x.gf > y.gf)
	return out


func user_group() -> int:
	for g in 4:
		if user in groups[g]:
			return g
	return 0


func to_dict() -> Dictionary:
	return {"user": user, "women": women, "stage": stage, "round": round, "groups": groups, "fixtures": fixtures, "medals": medals, "seed": seed}


static func from_dict(d: Dictionary) -> Cup:
	var c := Cup.new()
	c.user = String(d.get("user", "SWE"))
	c.women = bool(d.get("women", false))
	c.stage = String(d.get("stage", "groups"))
	c.round = int(d.get("round", 0))
	c.groups = d.get("groups", [])
	c.fixtures = d.get("fixtures", {})
	c.medals = d.get("medals", {})
	c.seed = int(d.get("seed", 1))
	return c
