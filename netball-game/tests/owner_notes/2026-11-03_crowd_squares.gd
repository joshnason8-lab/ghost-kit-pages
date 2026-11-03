extends WsgOwnerNote
## The owner, 2026-11-03, on 0.9.0-beta (after the crowd placement of 0.9.0: the arena's bowl still painted).

const NOTE := {"id": "2026-11-03-crowd-squares", "game": "netball", "date": "2026-11-03", "version": "0.9.0-beta",
	"words": "Most of the crowd is still just squares, needs to be actual people."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")
const Crowd3 := preload("res://tests/owner_notes/lib/crowd.gd")


## Everyone in each venue's crowd, how they are drawn: whole 3D people, flat cards, or painted onto the stands as
## squares of colour (the arena's bowl, both tiers, all round: estimated from its painted area, a seat each 0.5 m²
## at the venue's density). On Medium and High, in every venue, at least nine in ten are real 3D people (most of the
## crowd squares is the owner's fault); on Low (cards on the courtside stands, the painted bowl kept for the frame
## time) the numbers are printed.
func check() -> void:
	var h: Node = await Harness.make(tree)
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		for venue in ["arena", "hall", "outdoor"]:
			var r: Dictionary = await Crowd3.count(h, venue)
			var what := "%s, %s" % [["Low", "Medium", "High"][g], venue]
			info("%s: %s" % [what, Crowd3.line(r)])
			if g == Game.GFX_LOW:
				continue
			expect(float(r.share) >= 0.9, "%s: most of the crowd squares - %.0f%% real people (%d in 3D, %d cards, about %d painted on the stands)" % [what,
				float(r.share) * 100.0, r.real, r.cards, r.painted])
	await Harness.done(h)
