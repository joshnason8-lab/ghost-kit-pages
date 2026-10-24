class_name Sim
extends RefCounted
## A match the game does not show, decided by numbers: goals for each side drawn from the teams' ratings, about ten a
## match between them as at the World Championships (10.2 a game at the 2016 men's), more one-sided the further apart
## the ratings are; overtime (10 minutes, the first goal wins) and penalty shots when a winner is needed.

## {goals: [a, b], winner, ot, so}
static func play(a: String, b: String, women := false, knockout := false, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var ra := DB.rating(a, women)
	var rb := DB.rating(b, women)
	var la := 5.1 * exp((ra - rb) / 22.0)
	var lb := 5.1 * exp((rb - ra) / 22.0)
	var g := [_poisson(la, rng), _poisson(lb, rng)]
	var ot := false
	var so := false
	if g[0] == g[1] and knockout:
		ot = true
		# Ten minutes of sudden victory: a goal in it about half the time, by the better side more often.
		if rng.randf() < 0.55:
			g[0 if rng.randf() < la / (la + lb) else 1] += 1
		else:
			so = true
			g[0 if rng.randf() < 0.5 + (ra - rb) / 200.0 else 1] += 1   # a shootout win counts one goal (204)
	return {"goals": g, "winner": 0 if g[0] > g[1] else (1 if g[1] > g[0] else -1), "ot": ot, "so": so}


static func _poisson(l: float, rng: RandomNumberGenerator) -> int:
	var lim := exp(-l)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= lim:
			return k
		k += 1
	return k
