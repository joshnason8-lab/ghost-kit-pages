class_name Records
extends RefCounted
## The record book: matches played and won, the biggest win, the most outs by one of your chasers in a match, the
## longest run by one of your defenders, and titles won. Kept on the phone (Game.RECORDS_PATH); nothing leaves it.


## Adds a match to the book. Returns the records it broke - a best that stood before and is beaten now (a first match
## sets the book, it breaks nothing) - as [record key, what was done, by whom].
static func add_match(result: Dictionary) -> Array:
	var broke := []
	var cfg: Dictionary = result.config
	var u := int(cfg.get("user_team", -1))
	if u < 0:
		return broke
	var r: Dictionary = Game.records
	r.played = int(r.get("played", 0)) + 1
	var w := int(result.winner)
	if w == u:
		r.won = int(r.get("won", 0)) + 1
		var margin := int(result.score[u]) - int(result.score[1 - u])
		if margin > int(r.get("best_margin", 0)):
			if int(r.get("best_margin", 0)) > 0:
				broke.append(["REC_BEST_MARGIN", margin, String(result.teams[1 - u])])
			r.best_margin = margin
			r.best_margin_vs = String(result.teams[1 - u])
	elif w < 0:
		r.tied = int(r.get("tied", 0)) + 1
	for id in result.stats:
		var st: Dictionary = result.stats[id]
		if int(st.side) != u:
			continue
		if int(st.outs) > int(r.get("most_outs", 0)):
			if int(r.get("most_outs", 0)) > 0:
				broke = broke.filter(func(b): return b[0] != "REC_MOST_OUTS")
				broke.append(["REC_MOST_OUTS", int(st.outs), String(st.name)])
			r.most_outs = int(st.outs)
			r.most_outs_by = String(st.name)
		var run := maxf(float(st.best_run), float(st.run))
		if run > float(r.get("longest_run", 0.0)):
			if float(r.get("longest_run", 0.0)) > 0.0:
				broke = broke.filter(func(b): return b[0] != "REC_LONGEST_RUN")
				broke.append(["REC_LONGEST_RUN", run, String(st.name)])
			r.longest_run = run
			r.longest_run_by = String(st.name)
	Game.save_records()
	return broke


static func add_title(kind: String) -> void:
	var r: Dictionary = Game.records
	var t: Dictionary = r.get("titles", {})
	t[kind] = int(t.get(kind, 0)) + 1
	r.titles = t
	Game.save_records()
