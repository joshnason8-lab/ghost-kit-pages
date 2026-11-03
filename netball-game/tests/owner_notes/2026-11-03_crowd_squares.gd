extends WsgOwnerNote
## The owner, 2026-11-03, on 0.9.0-beta (after the crowd placement of 0.9.0: the arena's bowl still painted).
## 2026-11-03, the owner via the lead: full house; cut-outs allowed in the far tiers only. (17:03Z: "Full house" - every
## seat filled, 3D people in the rows nearest the court, person-shaped cut-out cards in the far tiers.)

const NOTE := {"id": "2026-11-03-crowd-squares", "game": "netball", "date": "2026-11-03", "version": "0.9.0-beta",
	"words": "Most of the crowd is still just squares, needs to be actual people."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")
const Crowd3 := preload("res://tests/owner_notes/lib/crowd.gd")
## The arena bowl's seats in the broadcast camera's view with someone in them (3D or a cut-out), Medium and High.
const FULL := 0.9


## Everyone in each venue's crowd, how they are drawn: whole 3D people, person-shaped cards, or painted onto the stands
## as squares of colour (the stand shader's people: estimated from the painted area, a seat each 0.5 m²). On every
## level, in every venue: no one painted. On Medium and High: no card where the level draws 3D people (the courtside
## stands, the bowl's near rows: cut-outs only in the far tiers), and the arena a full house - at least FULL of the
## bowl's seats in the broadcast camera's view filled. On Low (cards everywhere) the numbers are printed.
func check() -> void:
	var h: Node = await Harness.make(tree)
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		for venue in ["arena", "hall", "outdoor"]:
			var r: Dictionary = await Crowd3.count(h, venue)
			var what := "%s, %s" % [["Low", "Medium", "High"][g], venue]
			info("%s: %s" % [what, Crowd3.line(r)])
			expect(int(r.painted) == 0 and float(r.painted_m2) < 1.0, "%s: about %d people painted on the stands as squares (%.0f m²)" % [what,
				r.painted, r.painted_m2])
			if g == Game.GFX_LOW:
				continue
			expect(int(r.cards_near) == 0, "%s: %d cut-outs where the level draws 3D people" % [what, r.cards_near])
			if venue == "arena":
				expect(int(r.seats_view) > 0 and float(r.full_view) >= FULL, "%s: not a full house - %d of the bowl's %d seats in view filled (%.0f%%)" % [what,
					r.filled_view, r.seats_view, float(r.full_view) * 100.0])
	await Harness.done(h)
