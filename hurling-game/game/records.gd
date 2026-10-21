class_name Records
extends RefCounted
## The record book (Game.records, saved): titles won, matches played and won, and the best single-match feats.


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
	# The best feats by your players in one match.
	for id in result.get("stats", {}):
		var s: Dictionary = result.stats[id]
		if int(s.get("team", -1)) != user:
			continue
		for k in ["kills", "blocks", "aces"]:
			var best: Dictionary = r.get("best_" + k, {})
			if int(s.get(k, 0)) > int(best.get("n", 0)):
				r["best_" + k] = {"n": int(s[k]), "num": int(s.get("num", 0)), "vs": String(result.away if user == 0 else result.home)}
	Game.save_records()
