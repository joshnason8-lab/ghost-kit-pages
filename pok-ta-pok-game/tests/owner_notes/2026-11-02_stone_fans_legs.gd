extends WsgOwnerNote
## The owner, 2026-11-02 (Pok Ta Pok 0.6.0 on the A16): "stone court some fans legs are hidden"

const NOTE := {"id": "2026-11-02-stone-fans-legs", "game": "pok-ta-pok", "date": "2026-11-02", "version": "Pok Ta Pok 0.6.0 on the A16", "words": "stone court some fans legs are hidden"}


## On both stone courts (day and night) every fan, 3D and the Low cards, is measured where the game puts them
## (Venue.crowd_venue): feet on their terrace, nobody inside a step or the coping, facing the play (WsgCrowdVenue.audit).
func check() -> void:
	if not WsgCrowd3D.available():
		skip("no licensed crowd here")
		return
	for id in ["stone", "night"]:
		var venue: WsgCrowdVenue = Venue.crowd_venue(id)
		var crowd := WsgCrowd3D.new()
		tree.root.add_child(crowd)
		crowd.build_venue(venue, 2, venue.play_centre, 1.0, 7)
		var res: Dictionary = WsgCrowdVenue.audit(crowd, venue, 0)
		var cards := WsgCrowdCards.new()
		tree.root.add_child(cards)
		cards.build(crowd.placed, PackedInt32Array(), 7)
		var low: Dictionary = cards.audit(venue, crowd.placed)
		for f in res.fails:
			fail("%s: %s" % [id, f])
		for f in low.fails:
			fail("%s (Low cards): %s" % [id, f])
		for sname in res.sections:
			var s: Dictionary = res.sections[sname]
			info("%s %-12s %4d fans  feet %+.3f..%+.3f  inside %.3f  facing <= %2.0f deg" % [id, sname, s.fans, s.feet[0], s.feet[1], s.inside, s.facing])
			expect(float(s.inside) <= 0.02, "%s %s: fans %.3f m inside a step or the coping" % [id, sname, s.inside])
		expect(int(res.fans) > 100, "%s: only %d fans" % [id, int(res.fans)])
		crowd.free()
		cards.free()
