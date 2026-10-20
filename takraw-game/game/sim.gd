class_name Sim
extends RefCounted
## Matches the player does not play, played out point by point from the teams' ratings: the same rules as a match
## played (Match), so the scores look like takraw's, and the points shared out among the players the way they win
## them (most kills to the strikers, aces to the tekong, blocks to the strikers).


## A match between home and away: {winner (0 home, 1 away), sets [a, b], set_scores [[a, b] ...], stats}.
static func play(home: String, away: String, women := false, best_of := 3, set_points := 15, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var ra := DB.team_rating(home, women)
	var rb := DB.team_rating(away, women)
	# The chance the home side wins a rally: a few rating points are worth a lot over a set.
	var p_home := clampf(0.5 + (ra - rb) * 0.011 + 0.01, 0.2, 0.8)
	var cap := 17 if set_points == 15 else 25
	var to_win := 2 if best_of >= 3 else 1
	var sets := [0, 0]
	var scores := []
	var stats := {}
	var lineups := [DB.regu(home, women), DB.regu(away, women)]
	for k in 2:
		for pd in lineups[k]:
			stats[pd.id] = {"kills": 0, "aces": 0, "blocks": 0, "digs": 0, "errors": 0, "serves": 0, "name": pd.short, "num": pd.num, "team": k}
	while sets[0] < to_win and sets[1] < to_win:
		var pts := [0, 0]
		while true:
			var w := 0 if rng.randf() < p_home else 1
			pts[w] += 1
			_credit(stats, lineups[w], w, rng)
			var a: int = pts[0]
			var b: int = pts[1]
			if ((a >= set_points or b >= set_points) and absi(a - b) >= 2) or a >= cap or b >= cap:
				break
		scores.append(pts)
		sets[0 if pts[0] > pts[1] else 1] += 1
	return {"winner": 0 if sets[0] > sets[1] else 1, "sets": sets, "set_scores": scores, "stats": stats, "home": home, "away": away}


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
