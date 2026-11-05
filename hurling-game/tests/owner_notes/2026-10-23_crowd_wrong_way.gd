extends WsgOwnerNote
## The owner, 2026-10-23 (Hurling 0.4.0): "the crowd to the near side is looking the wrong direction"

const NOTE := {"id": "2026-10-23-crowd-wrong-way", "game": "hurling", "date": "2026-10-23", "version": "Hurling 0.4.0", "words": "the crowd to the near side is looking the wrong direction"}
const Kit := preload("res://tests/note_kit.gd")

## At every ground the 3D crowd built as a match builds it (High) and audited (WsgCrowdVenue.audit): every fan facing
## the play (within 35 degrees), none backwards, soles on the steps, none sunk into a seat or a row.
func check() -> void:
	if not WsgCrowd3D.available():
		skip("no licensed crowd here")
		return
	var keep = Game.settings.graphics
	Game.settings.graphics = Game.GFX_HIGH
	for v in ["parish", "county", "stadium"]:
		var m: Node = await Kit.match(tree, {"mode": "quick", "user_team": 0, "venue": v}, 3)
		var st: Stadium = m.stadium
		if st.crowd3d == null:
			fail("%s: no 3D crowd on High" % v)
		else:
			var a := WsgCrowdVenue.audit(st.crowd3d, st.venue, 0)
			for f in a.fails:
				fail("%s: %s" % [v, f])
			var worst := 0.0
			var back := 0
			for s in a.sections:
				worst = maxf(worst, float(a.sections[s].facing))
				back += int(a.sections[s].backwards)
			info("%s: %d sections, facing within %.0f degrees, %d backwards, %d fails" % [v, a.sections.size(), worst, back, a.fails.size()])
		await Kit.done(tree, m)
	Game.settings.graphics = keep
