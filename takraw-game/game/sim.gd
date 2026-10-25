class_name Sim
extends RefCounted
## Matches the player does not play, played out point by point from the teams' ratings: the same rules as a match
## played (Match), so the scores look like takraw's, and the points shared out among the players the way they win
## them (most kills to the strikers, aces to the tekong, blocks to the strikers).


## A match between home and away: {winner (0 home, 1 away), sets [a, b], set_scores [[a, b] ...], stats}. regu_no:
## a club's second regu (a Thai league tie's), from the players its first did not use.
static func play(home: String, away: String, women := false, best_of := 3, set_points := 15, rng: RandomNumberGenerator = null,
		regu_no := 0) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var lineups := [_lineup(home, women, regu_no), _lineup(away, women, regu_no)]
	var p_home := rally_chance(lineups[0], lineups[1])
	var cap := 17 if set_points == 15 else 25
	var to_win := 2 if best_of >= 3 else 1
	var sets := [0, 0]
	var scores := []
	var stats := {}
	for k in 2:
		for pd in lineups[k]:
			stats[pd.id] = {"kills": 0, "aces": 0, "blocks": 0, "digs": 0, "errors": 0, "serves": 0, "num": pd.num, "pos": pd.pos, "team": k}
	while sets[0] < to_win and sets[1] < to_win:
		var pts := [0, 0]
		while true:
			pts[rally(stats, lineups, p_home, rng)] += 1
			var a: int = pts[0]
			var b: int = pts[1]
			if ((a >= set_points or b >= set_points) and absi(a - b) >= 2) or a >= cap or b >= cap:
				break
		scores.append(pts)
		sets[0 if pts[0] > pts[1] else 1] += 1
	return {"winner": 0 if sets[0] > sets[1] else 1, "sets": sets, "set_scores": scores, "stats": stats, "home": home, "away": away}


## The chance the home lineup wins a rally against the away one: a few rating points are worth a lot over a set.
static func rally_chance(home: Array, away: Array) -> float:
	return clampf(0.5 + (_rating(home) - _rating(away)) * 0.011 + 0.01, 0.2, 0.8)


## One rally of a played-out match: who wins it (0 home, 1 away), the point credited to one of their players.
static func rally(stats: Dictionary, lineups: Array, p_home: float, rng: RandomNumberGenerator) -> int:
	var w := 0 if rng.randf() < p_home else 1
	_credit(stats, lineups[w], w, rng)
	return w


static func _lineup(id: String, women: bool, regu_no: int) -> Array:
	var skip := []
	for n in regu_no:
		for pd in DB.regu(id, women, 3, skip):
			skip.append(pd.id)
	return DB.regu(id, women, 3, skip)


static func _rating(lineup: Array) -> float:
	var total := 0.0
	for pd in lineup:
		total += DB.overall(pd)
	return total / maxf(1.0, lineup.size())


static func _credit(stats: Dictionary, lineup: Array, _team: int, rng: RandomNumberGenerator) -> void:
	var r := rng.randf()
	var role := DB.POS_STRIKER
	var key := "kills"
	if r < 0.08:
		role = DB.POS_TEKONG
		key = "aces"
	elif r < 0.18:
		role = DB.POS_STRIKER
		key = "blocks"
	elif r < 0.3:
		return   # the other side's error
	for pd in lineup:
		if int(pd.pos) == role:
			stats[pd.id][key] += 1
			return
	stats[lineup[0].id][key] += 1


## Table points for a result in sets: a 2-0 win 3, 2-1 win 2, 1-2 loss 1, 0-2 loss 0 (a one-set match: 3 and 0).
static func table_points(won: int, lost: int) -> int:
	if won > lost:
		return 3 if lost == 0 else 2
	return 1 if won > 0 else 0
