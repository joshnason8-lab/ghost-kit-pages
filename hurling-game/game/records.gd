class_name Records
extends RefCounted
## The record book (Game.records, saved): titles won, matches played and won, the biggest win and the best scoring
## feats by your players in one match.


static func add_title(key: String, year: int) -> void:
	var titles: Array = Game.records.get("titles", [])
	titles.append({"key": key, "year": year})
	Game.records.titles = titles
	Game.save_records()


static func add_match(result: Dictionary) -> void:
	var user := int(result.get("user_team", -1))
	if user < 0:
		return
	var r := Game.records
	r.played = int(r.get("played", 0)) + 1
	if int(result.winner) == user:
		r.won = int(r.get("won", 0)) + 1
	var sc: Array = result.score
	var margin := Rules.total(sc[user][0], sc[user][1]) - Rules.total(sc[1 - user][0], sc[1 - user][1])
	if margin > int(r.get("best_margin", 0)):
		r.best_margin = margin
		r.best_margin_vs = String(result.away if user == 0 else result.home)
	for id in result.get("pstats", {}):
		var s: Dictionary = result.pstats[id]
		if int(s.get("team", -1)) != user:
			continue
		var tot := int(s.goals) * 3 + int(s.points)
		if tot > int(r.get("best_tally", 0)):
			r.best_tally = tot
			r.best_tally_line = Rules.fmt(int(s.goals), int(s.points))
	Game.save_records()
