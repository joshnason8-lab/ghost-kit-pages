class_name Sim
extends RefCounted
## A match played out in numbers, for the championship matches you do not play. Each chasing turn is a run of outs,
## each after a wait drawn from the rate a side of that rating gets them against that defence: about 1.3 outs a minute
## between equal sides, the rate of the 2025 and 2026 finals (docs/AI.md). Batches change as in a match, so the fast
## game's dream runs come out of the same clock. The laws (KhoRules) decide the rest: points an out, follow-on,
## extra innings and minimum chases.

const BASE_RATE := 1.3 / 60.0   # outs a second, equal sides


static func rate(att: float, def: float) -> float:
	return BASE_RATE * exp((att - def) / 30.0)


## One chasing turn: [outs, dream points to the defenders, seconds to the first out (-1 none)].
static func turn(rng: RandomNumberGenerator, fmt: int, length: float, att: float, def: float) -> Array:
	var r := rate(att, def)
	var t := 0.0
	var outs := 0
	var dream := 0
	var batch_t := 0.0
	var in_batch := 0
	var first := -1.0
	while true:
		var wait := -log(maxf(1e-6, rng.randf())) / r
		if t + wait > length:
			batch_t += length - t
			dream += KhoRules.dream_points(fmt, batch_t) - KhoRules.dream_points(fmt, batch_t - (length - t))
			break
		var before := KhoRules.dream_points(fmt, batch_t)
		batch_t += wait
		dream += KhoRules.dream_points(fmt, batch_t) - before
		t += wait
		outs += 1
		if first < 0.0:
			first = t
		in_batch += 1
		if in_batch == 3:
			in_batch = 0
			batch_t = 0.0
			t += 3.0   # the next batch comes on
	return [outs, dream, first]


## A whole match: the result in the match's own shape (score, winner, turns, follow_on).
static func play(home: String, away: String, fmt: int, length: float, women: bool, knockout: bool, seed_: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var teams := [home, away]
	var rat := [float(DB.team_rating(home, women)), float(DB.team_rating(away, women))]
	var first := rng.randi() % 2
	var order: Array = KhoRules.chase_order(first)
	var score := [0, 0]
	var turns: Array = []
	var follow := false
	var t := 0
	while t < order.size():
		var c := int(order[t])
		var r := turn(rng, fmt, length, rat[c] + rng.randf_range(-4, 4), rat[1 - c])
		score[c] += int(r[0]) * KhoRules.points_for_out(fmt)
		score[1 - c] += int(r[1])
		turns.append({"turn": t, "chaser": c, "points": int(r[0]) * KhoRules.points_for_out(fmt), "outs": r[0], "dream": r[1]})
		if t == 1 and KhoRules.can_follow_on(fmt, length, int(order[0]), score):
			follow = true
			order = KhoRules.chase_order(int(order[0]), true)
		if t < 3 and KhoRules.over_after(t, order, score):
			break
		t += 1
	var w := KhoRules.winner(score)
	var extra := 0
	var minc := false
	if w < 0 and knockout:
		extra = 1
		for c in [int(order[0]), 1 - int(order[0])]:
			var r2 := turn(rng, fmt, length, rat[c], rat[1 - c])
			score[c] += int(r2[0]) * KhoRules.points_for_out(fmt)
			score[1 - c] += int(r2[1])
		w = KhoRules.winner(score)
		while w < 0:
			minc = true
			var mt := [-1.0, -1.0]
			for c in 2:
				var r3 := turn(rng, fmt, length, rat[c], rat[1 - c])
				mt[c] = float(r3[2])
			w = KhoRules.min_chase_winner(mt)
	return {"teams": teams, "score": score, "winner": w, "turns": turns, "follow_on": follow, "extra": extra, "min_chase": minc}


## Group table points: 2 for a win, 1 for a tie, as the national championships' league stages give.
static func table_points(mine: int, theirs: int) -> int:
	if mine > theirs:
		return 2
	if mine == theirs:
		return 1
	return 0
