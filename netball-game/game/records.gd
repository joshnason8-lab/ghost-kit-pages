class_name Records
extends RefCounted
## The record book, kept on the phone (Game.records): matches played, won and lost, goals, the biggest win, the most
## goals by one shooter in a match, and the cups won.


static func add_match(result: Dictionary) -> void:
	var r: Dictionary = Game.records
	var ut := int(result.get("user_team", -1))
	if ut < 0:
		return
	var score: Array = result.score
	r.played = int(r.get("played", 0)) + 1
	var won: bool = int(result.winner) == ut
	var drawn: bool = int(result.winner) < 0
	r.won = int(r.get("won", 0)) + (1 if won else 0)
	r.drawn = int(r.get("drawn", 0)) + (1 if drawn else 0)
	r.lost = int(r.get("lost", 0)) + (1 if not won and not drawn else 0)
	r.goals = int(r.get("goals", 0)) + int(score[ut])
	var margin := int(score[ut]) - int(score[1 - ut])
	if won and margin > int(r.get("best_margin", 0)):
		r.best_margin = margin
		r.best_win = "%s %d – %d %s" % [result.config.home, score[0], score[1], result.config.away]
	for id in result.stats:
		var s: Dictionary = result.stats[id]
		if int(s.team) == ut and int(s.goals) > int(r.get("top_shooter_goals", 0)):
			r.top_shooter_goals = int(s.goals)
			r.top_shooter = "%s (%s)" % [s.name, s.pos]
	Game.save_records()


static func add_cup(won: bool) -> void:
	var r: Dictionary = Game.records
	r.cups_played = int(r.get("cups_played", 0)) + 1
	if won:
		r.cups_won = int(r.get("cups_won", 0)) + 1
	Game.save_records()


static func add_league(won: bool) -> void:
	var r: Dictionary = Game.records
	r.seasons_played = int(r.get("seasons_played", 0)) + 1
	if won:
		r.titles_won = int(r.get("titles_won", 0)) + 1
	Game.save_records()
