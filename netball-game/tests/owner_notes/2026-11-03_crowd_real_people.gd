extends WsgOwnerNote
## The owner, 2026-11-03, on 0.8.6-beta.
## 2026-11-03, the owner via the lead: full house; cut-outs allowed in the far tiers only. (17:03Z: "Full house" - every
## seat filled, 3D people in the rows nearest the court, person-shaped cut-out cards in the far tiers.)

const NOTE := {"id": "2026-11-03-crowd-real-people", "game": "netball", "date": "2026-11-03", "version": "0.8.6-beta",
	"words": "The crowd isn't real people, why isn't that updated? That was supposed to be shared foundation too. Even on High in the outdoor court the crowd looks like simple shapes."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")
const Crowd3 := preload("res://tests/owner_notes/lib/crowd.gd")
const MIN_TRIS := 300       # a person (head, arms, legs), not a shape: a box figure is 12-100 triangles; the crowd's people ~450-500
## The arena's near rows (its courtside stands and the bowl's 3D sections) on Medium and High: at least this many whole
## 3D people (measured 474 and 1,175 at 0.9.5, less a margin).
const ARENA_REAL := {1: 400, 2: 900}


## On Medium and High, in all three venues (the outdoor court above all): the crowd's near seats are the shared
## foundation's 3D people (WsgCrowd3D), each a modelled person of MIN_TRIS triangles or more; no card in any seat the
## level draws in 3D (the courtside stands, the bowl's near rows, a hall's stand, a park's crowd: cut-outs only in the
## arena bowl's far tiers); no people painted onto any face; and the arena holds at least ARENA_REAL 3D people.
func check() -> void:
	var h: Node = await Harness.make(tree)
	for g in [Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		WsgFoundation.tier = g      # (as the game sets it at start: the 3D crowd is built at most at the tier)
		for venue in ["outdoor", "arena", "hall"]:
			var r: Dictionary = await Crowd3.count(h, venue)
			var what := "%s, %s" % [["Low", "Medium", "High"][g], venue]
			info("%s: %s" % [what, Crowd3.line(r)])
			expect(int(r.real) > 0, "%s: no 3D people in the crowd" % what)
			expect(int(r.tris) >= MIN_TRIS, "%s: a person in the crowd is %d triangles - a simple shape" % [what, r.tris])
			expect(int(r.cards_near) == 0, "%s: %d flat cards in seats the level draws as 3D people (cut-outs belong in the far tiers only)" % [what, r.cards_near])
			if venue != "arena":
				expect(int(r.cards) == 0, "%s: %d of the crowd are flat cards (no far tiers here)" % [what, r.cards])
			else:
				expect(int(r.real) >= int(ARENA_REAL[g]), "%s: only %d 3D people in the near rows (at least %d)" % [what, r.real, ARENA_REAL[g]])
			expect(int(r.painted) == 0 and float(r.painted_m2) < 1.0, "%s: about %d people painted on the stands (%.0f m²)" % [what,
				r.painted, r.painted_m2])
	await Harness.done(h)
