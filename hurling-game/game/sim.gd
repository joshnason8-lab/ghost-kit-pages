class_name Sim
extends RefCounted
## Matches the player does not play (the rest of a championship round), played out from the teams' ratings into
## scores that look like hurling's: in the 2026 championship about 77 shots a game, 60% of them scored, so a side
## scores 20-35 points' worth, two goals a game between them on average (docs/AI.md). Scorers are shared out the way
## they are in real games: the free-taker gets most, the forwards the rest, now and then a midfielder or a
## half-back.


## {score: [[g, p], [g, p]], winner (0 home, 1 away, -1 a draw), scorers: {player id: [g, p]}}. knockout: a draw goes
## to extra time, then penalties.
static func play(home: String, away: String, rng: RandomNumberGenerator = null, knockout := false) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var ra := DB.team_rating(home)
	var rb := DB.team_rating(away)
	var score := [[0, 0], [0, 0]]
	var scorers := {}
	for k in 2:
		var mine := ra if k == 0 else rb
		var theirs := rb if k == 0 else ra
		var edge := (mine - theirs) * 0.28 + (0.6 if k == 0 else 0.0)
		var pts := maxi(8, roundi(rng.randfn(23.0 + edge, 3.8)))
		var goals := _poisson(rng, clampf(1.15 + edge * 0.05, 0.3, 2.6))
		score[k] = [goals, pts]
		_share(String([home, away][k]), goals, pts, scorers, rng)
	var et := false
	var pens := []
	var winner := _winner(score)
	if winner < 0 and knockout:
		et = true
		for k in 2:
			var add := rng.randi_range(1, 5)
			score[k][1] += add
			_share(String([home, away][k]), 0, add, scorers, rng)
		winner = _winner(score)
		if winner < 0:
			var g := [0, 0]
			var t := [0, 0]
			var k := 0
			while Rules.shootout_winner(g, t) < 0:
				t[k] += 1
				if rng.randf() < 0.62:
					g[k] += 1
				k = 1 - k
			pens = g
			winner = Rules.shootout_winner(g, t)
	return {"score": score, "winner": winner, "scorers": scorers, "home": home, "away": away, "extra_time": et, "pens": pens}


static func _winner(score: Array) -> int:
	var a := Rules.total(score[0][0], score[0][1])
	var b := Rules.total(score[1][0], score[1][1])
	return 0 if a > b else (1 if b > a else -1)


static func _poisson(rng: RandomNumberGenerator, mean: float) -> int:
	var l := exp(-mean)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= l:
			return k
		k += 1
	return k


static func _share(team: String, goals: int, pts: int, scorers: Dictionary, rng: RandomNumberGenerator) -> void:
	var starters := DB.starters(team)
	var ft := DB.free_taker(team)
	var weights := []
	for p in starters:
		var w := 0.0
		match int(p.line):
			DB.POS_FF:
				w = 3.0
			DB.POS_HF:
				w = 2.6
			DB.POS_MF:
				w = 1.0
			DB.POS_HB:
				w = 0.35
			_:
				w = 0.02
		if p.id == ft.id:
			w += 6.0
		weights.append(w)
	for i in goals + pts:
		var is_goal := i < goals
		var pick := _pick(weights, rng, is_goal, starters)
		var id := String(starters[pick].id)
		var s: Array = scorers.get(id, [0, 0])
		s[0 if is_goal else 1] += 1
		scorers[id] = s


static func _pick(weights: Array, rng: RandomNumberGenerator, goal: bool, starters: Array) -> int:
	var total := 0.0
	for i in weights.size():
		total += float(weights[i]) * (2.0 if goal and int(starters[i].line) == DB.POS_FF else 1.0)
	var r := rng.randf() * total
	for i in weights.size():
		r -= float(weights[i]) * (2.0 if goal and int(starters[i].line) == DB.POS_FF else 1.0)
		if r <= 0.0:
			return i
	return weights.size() - 1
