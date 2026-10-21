class_name Records
extends RefCounted
## The record book: matches played and won, the biggest win, the most outs by one of your chasers in a match, the
## longest run by one of your defenders, and titles won. Kept on the phone (Game.RECORDS_PATH); nothing leaves it.


static func add_match(result: Dictionary) -> void:
	var cfg: Dictionary = result.config
	var u := int(cfg.get("user_team", -1))
	if u < 0:
		return
	var r: Dictionary = Game.records
	r.played = int(r.get("played", 0)) + 1
	var w := int(result.winner)
	if w == u:
		r.won = int(r.get("won", 0)) + 1
		var margin := int(result.score[u]) - int(result.score[1 - u])
		if margin > int(r.get("best_margin", 0)):
			r.best_margin = margin
			r.best_margin_vs = String(result.teams[1 - u])
	elif w < 0:
		r.tied = int(r.get("tied", 0)) + 1
	for id in result.stats:
		var st: Dictionary = result.stats[id]
		if int(st.side) != u:
			continue
		if int(st.outs) > int(r.get("most_outs", 0)):
			r.most_outs = int(st.outs)
			r.most_outs_by = String(st.name)
		var run := maxf(float(st.best_run), float(st.run))
		if run > float(r.get("longest_run", 0.0)):
			r.longest_run = run
			r.longest_run_by = String(st.name)
	Game.save_records()


static func add_title(kind: String) -> void:
	var r: Dictionary = Game.records
	var t: Dictionary = r.get("titles", {})
	t[kind] = int(t.get(kind, 0)) + 1
	r.titles = t
	Game.save_records()
