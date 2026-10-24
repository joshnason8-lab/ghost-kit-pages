class_name Sim
extends RefCounted
## A match the player does not see (the other games of a cup round), played raya by raya through the real count
## (Rules): each raya goes to a side with a chance from the two sides' strength, so the count rises and falls, urria
## and all, just as in a played match.

static func play(home: String, away: String, rules := Rules.ULAMA, seed_ := 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ if seed_ != 0 else hash(home + away + str(Time.get_ticks_usec()))
	var c := Rules.Count.new(rules, String(Game.settings.get("urria", "3_7")))
	var p := clampf(0.5 + (DB.strength(home) - DB.strength(away)) * 0.9, 0.25, 0.75)
	var n := 0
	while c.winner < 0 and n < 2000:
		n += 1
		if rules == Rules.CLASSIC and rng.randf() < 0.004:
			Rules.award_ring(c, 0 if rng.randf() < p else 1)
			break
		Rules.award(c, 0 if rng.randf() < p else 1)
	if c.winner < 0:
		c.winner = 0 if rng.randf() < p else 1
	return {"winner": c.winner, "count": c.to_dict(), "rayas": n}
