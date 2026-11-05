extends TakrawNote
## The owner, 2026-10-21: "no player names if they exist, no need we will simplify this a bit"

const NOTE := {"id": "2026-10-21-no-player-names", "game": "sepak-takraw", "date": "2026-10-21", "version": "0.2.0",
	"words": "no player names if they exist, no need we will simplify this a bit"}


## No player's name shown anywhere: not over the players, not on the match's screen, not in the squads of the
## setup, season and tournament screens (the players have none: a team is its name and crest).
func check() -> void:
	var named := 0
	for t in DB.countries_ranked(false) + DB.league_clubs("MY"):
		for pd in DB.squad(String(t), false):
			if String((pd as Dictionary).get("name", "")) != "":
				named += 1
	info("players with a name in the game's data: %d" % named)
	expect(named == 0, "%d players have names in the game's data" % named)
	var m := make_match({"user_team": 0, "demo": false})
	await play(m, 5.0)
	var labels := m.find_children("*", "Label3D", true, false).filter(func(l): return m.players_on(0).any(func(p): return (p as Node).is_ancestor_of(l)) or m.players_on(1).any(func(p): return (p as Node).is_ancestor_of(l)))
	expect(labels.is_empty(), "%d labels over the players" % labels.size())
	await clean()
