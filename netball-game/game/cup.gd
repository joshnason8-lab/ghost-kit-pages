class_name Cup
extends RefCounted
## The Nations Cup (the game's own competition; no real one's name): eight national teams, two pools of four played
## round robin, the top two of each to the semi-finals, then the final and the bronze-medal match, as world netball
## championships finish. Two points for a win and one for a draw; teams level on points are split by goal
## percentage (goals for divided by goals against, times 100), as netball's tables are. Knockout matches go to extra
## time if level.

const POOL_SIZE := 4

var user := ""
var teams: Array = []
var pools: Array = [[], []]
var fixtures: Array = []      # pool games: {home, away, pool, round, played, score}
var knockout: Array = []      # {stage: "semi"|"final"|"bronze", home, away, played, score, winner}
var stage := "pools"          # pools, semis, finals, done
var round := 0                # the pool round being played (0-2)
var medals := {}
var rng := RandomNumberGenerator.new()


static func create(country: String) -> Cup:
	var c := Cup.new()
	c.user = country
	c.rng.seed = hash(country) + Time.get_ticks_msec()
	# The user's team and the seven nearest it in the ranking, so every pool is a contest.
	var ids: Array = DB.team_ids()
	ids.sort_custom(func(a, b): return absf(DB.team_rating(a) - DB.team_rating(country)) < absf(DB.team_rating(b) - DB.team_rating(country)))
	c.teams = ids.slice(0, 8)
	if not (country in c.teams):
		c.teams[7] = country
	c.teams.sort_custom(func(a, b): return DB.team_rating(a) > DB.team_rating(b))
	# Seeded pools: 1, 4, 5, 8 and 2, 3, 6, 7.
	for i in 8:
		c.pools[[0, 1, 1, 0, 0, 1, 1, 0][i]].append(c.teams[i])
	var order := [[0, 1, 2, 3], [0, 2, 1, 3], [0, 3, 1, 2]]
	for p in 2:
		for r in 3:
			var o: Array = order[r]
			c.fixtures.append({"home": c.pools[p][o[0]], "away": c.pools[p][o[1]], "pool": p, "round": r, "played": false, "score": [0, 0]})
			c.fixtures.append({"home": c.pools[p][o[2]], "away": c.pools[p][o[3]], "pool": p, "round": r, "played": false, "score": [0, 0]})
	return c


## The user's next match: {home, away, stage, need_winner}, or {} when they are out or it is over.
func next_user_match() -> Dictionary:
	if stage == "pools":
		for f in fixtures:
			if int(f.round) == round and not f.played and (f.home == user or f.away == user):
				return {"home": f.home, "away": f.away, "stage": "POOL_N", "n": int(f.pool) + 1, "need_winner": false}
		return {}
	for k in knockout:
		if not k.played and (k.home == user or k.away == user):
			return {"home": k.home, "away": k.away, "stage": String(k.stage).to_upper(), "need_winner": true}
	return {}


## The user's match is over: record it, play the rest of the round, move on.
func record_user_result(result: Dictionary) -> void:
	var h := String(result.config.home)
	var a := String(result.config.away)
	_record(h, a, result.score)
	advance()


func _record(h: String, a: String, score: Array) -> void:
	if stage == "pools":
		for f in fixtures:
			if not f.played and f.home == h and f.away == a:
				f.played = true
				f.score = [int(score[0]), int(score[1])]
				return
	for k in knockout:
		if not k.played and k.home == h and k.away == a:
			k.played = true
			k.score = [int(score[0]), int(score[1])]
			k.winner = h if int(score[0]) > int(score[1]) else a
			return


## Plays every other fixture of the current round (or stage), then moves the cup on.
func advance() -> void:
	if stage == "pools":
		for f in fixtures:
			if int(f.round) == round and not f.played:
				var r := Sim.play(f.home, f.away, false, rng)
				f.played = true
				f.score = r.score
		round += 1
		if round >= 3:
			stage = "semis"
			var a := pool_table(0)
			var b := pool_table(1)
			knockout = [
				{"stage": "semi", "home": a[0].id, "away": b[1].id, "played": false, "score": [0, 0], "winner": ""},
				{"stage": "semi", "home": b[0].id, "away": a[1].id, "played": false, "score": [0, 0], "winner": ""},
			]
		return
	for k in knockout:
		if not k.played:
			var r := Sim.play(k.home, k.away, true, rng)
			k.played = true
			k.score = r.score
			k.winner = k.home if int(r.score[0]) > int(r.score[1]) else k.away
	if stage == "semis":
		stage = "finals"
		var s1: Dictionary = knockout[0]
		var s2: Dictionary = knockout[1]
		var l1: String = s1.away if s1.winner == s1.home else s1.home
		var l2: String = s2.away if s2.winner == s2.home else s2.home
		knockout.append({"stage": "bronze", "home": l1, "away": l2, "played": false, "score": [0, 0], "winner": ""})
		knockout.append({"stage": "final", "home": s1.winner, "away": s2.winner, "played": false, "score": [0, 0], "winner": ""})
	elif stage == "finals":
		stage = "done"
		var fin: Dictionary = knockout[3]
		var br: Dictionary = knockout[2]
		medals = {"gold": fin.winner, "silver": fin.away if fin.winner == fin.home else fin.home, "bronze": br.winner}
		Records.add_cup(medals.gold == user)


## Plays the user's match too (Simulate), then moves on.
func sim_next() -> void:
	var nm := next_user_match()
	if not nm.is_empty():
		var r := Sim.play(nm.home, nm.away, bool(nm.need_winner), rng)
		_record(nm.home, nm.away, r.score)
	advance()


## A pool's table: rows {id, p, w, d, l, gf, ga, pct, pts}, by points then goal percentage.
func pool_table(p: int) -> Array:
	var rows := {}
	for id in pools[p]:
		rows[id] = {"id": id, "p": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pct": 0.0, "pts": 0}
	for f in fixtures:
		if int(f.pool) != p or not f.played:
			continue
		var s: Array = f.score
		for side in 2:
			var id: String = f.home if side == 0 else f.away
			var r: Dictionary = rows[id]
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
	return {"user": user, "teams": teams, "pools": pools, "fixtures": fixtures, "knockout": knockout, "stage": stage,
		"round": round, "medals": medals}


static func from_dict(d: Dictionary) -> Cup:
	var c := Cup.new()
	c.user = String(d.get("user", ""))
	c.teams = d.get("teams", [])
	c.pools = d.get("pools", [[], []])
	c.fixtures = d.get("fixtures", [])
	c.knockout = d.get("knockout", [])
	c.stage = String(d.get("stage", "pools"))
	c.round = int(d.get("round", 0))
	c.medals = d.get("medals", {})
	c.rng.randomize()
	for f in c.fixtures:
		f.round = int(f.round)
		f.pool = int(f.pool)
	return c
