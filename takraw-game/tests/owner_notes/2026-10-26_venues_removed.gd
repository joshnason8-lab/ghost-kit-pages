extends TakrawNote
## The owner, 2026-10-26: "Remove night market, template court venue and grand dome."

const NOTE := {"id": "2026-10-26-venues-removed", "game": "sepak-takraw", "date": "2026-10-26", "version": "0.11.1",
	"words": "Remove night market, template court venue and grand dome."}


## No venue anywhere is the night market, the temple court or the grand dome: not in the venues, the Quick match
## choices, a season's or a tournament's fixtures.
func check() -> void:
	var gone := ["night", "market", "temple", "dome"]
	var ids := venues()
	for v in DB.VENUES:
		for word in gone:
			expect(not String(v[0]).to_lower().contains(word) and not tr(String(v[1])).to_lower().contains(word),
				"a venue '%s' (%s) is still there" % [v[0], tr(String(v[1]))])
	Game.reset_settings_for_tests()
	var used := {}
	for lg in ["MY", "TH", "ID"]:
		Game.new_season(lg, String(DB.league_clubs(lg)[0]))
		for e in Game.season.events:
			used[String((e as Dictionary).get("venue", ""))] = true
	for kind in Cup.KINDS:
		Game.new_cup(kind, String((Cup.KINDS[kind].field as Array)[0]))
		used[String(Game.cup.venue())] = true
	for u in used:
		expect(u == "" or ids.has(u), "a season or tournament is played at '%s', not one of the venues" % u)
	info("%d venues (%s); fixtures at %s" % [ids.size(), ", ".join(ids), str(used.keys())])
	Game.delete_season()
	Game.delete_cup()
