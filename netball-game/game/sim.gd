class_name Sim
extends RefCounted
## A match played out in numbers, for the cup's other fixtures: goals quarter by quarter from the teams' ratings, at
## the real game's rate (about 55 goals a team in 60 minutes between equals; mismatches run to 100-30, as at the 2023
## world championship), with extra time when a winner is needed. docs/RULES.md "Numbers".


static func play(home: String, away: String, need_winner := false, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var ra := DB.team_rating(home)
	var rb := DB.team_rating(away)
	var diff := ra - rb
	var exp_a := clampf(54.0 + diff * 1.15, 18.0, 105.0)
	var exp_b := clampf(54.0 - diff * 1.15, 18.0, 105.0)
	var q_scores := []
	var score := [0, 0]
	for qn in 4:
		var a := _goals(exp_a / 4.0, rng)
		var b := _goals(exp_b / 4.0, rng)
		q_scores.append([a, b])
		score[0] += a
		score[1] += b
	if need_winner and score[0] == score[1]:
		# Extra time: two halves of 7 minutes, then on until one team leads by two.
		for h in 2:
			var a := _goals(exp_a * 7.0 / 60.0, rng)
			var b := _goals(exp_b * 7.0 / 60.0, rng)
			q_scores.append([a, b])
			score[0] += a
			score[1] += b
		if score[0] == score[1]:
			var a2 := 0
			var b2 := 0
			while absi(a2 - b2) < 2:
				if rng.randf() < exp_a / (exp_a + exp_b):
					a2 += 1
				else:
					b2 += 1
			q_scores.append([a2, b2])
			score[0] += a2
			score[1] += b2
	return {"home": home, "away": away, "score": score, "q_scores": q_scores,
		"winner": 0 if score[0] > score[1] else (1 if score[1] > score[0] else -1)}


static func _goals(mean: float, rng: RandomNumberGenerator) -> int:
	return maxi(0, roundi(rng.randfn(mean, sqrt(mean) * 0.9)))
