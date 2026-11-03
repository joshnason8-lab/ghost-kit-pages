extends WsgOwnerNote
## The owner, 2026-11-03, on 0.8.6-beta.

const NOTE := {"id": "2026-11-03-crowd-real-people", "game": "netball", "date": "2026-11-03", "version": "0.8.6-beta",
	"words": "The crowd isn't real people, why isn't that updated? That was supposed to be shared foundation too. Even on High in the outdoor court the crowd looks like simple shapes."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")
const Crowd3 := preload("res://tests/owner_notes/lib/crowd.gd")
const MIN_TRIS := 300       # a person (head, arms, legs), not a shape: a box figure is 12-100 triangles; the crowd's people ~450-500


## On Medium and High, in all three venues (the outdoor court above all): the crowd is the shared foundation's 3D
## people (WsgCrowd3D), each a modelled person of MIN_TRIS triangles or more, none left as a flat card, no people
## painted as standing rows onto a face; and nine in ten of everyone in the venue (the people painted on its stands
## counted too) are real 3D people.
func check() -> void:
	var h: Node = await Harness.make(tree)
	for g in [Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		for venue in ["outdoor", "arena", "hall"]:
			var r: Dictionary = await Crowd3.count(h, venue)
			var what := "%s, %s" % [["Low", "Medium", "High"][g], venue]
			info("%s: %s" % [what, Crowd3.line(r)])
			expect(int(r.real) > 0, "%s: no 3D people in the crowd" % what)
			expect(int(r.tris) >= MIN_TRIS, "%s: a person in the crowd is %d triangles - a simple shape" % [what, r.tris])
			expect(int(r.cards) == 0, "%s: %d of the crowd are flat cards" % [what, r.cards])
			expect(float(r.standing_m2) < 1.0, "%s: %.0f m² of people painted standing on a face" % [what, r.standing_m2])
			expect(float(r.share) >= 0.9, "%s: only %.0f%% of the crowd are real people (%d in 3D, about %d painted on the stands)" % [what,
				float(r.share) * 100.0, r.real, r.painted])
	await Harness.done(h)
