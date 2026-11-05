extends WsgOwnerNote
## The owner (relayed by the lead), 2026-11-03 (Hurling 0.23.1): "Practice graphics, the middle ground: full detail regardless of tier for the taker, the hurley, the sliotar and the posts; the crowd, the far stands, venue extras and effects follow the player's own tier."

const NOTE := {"id": "2026-11-03-practice-middle-ground", "game": "hurling", "date": "2026-11-03", "version": "Hurling 0.23.1", "words": "Practice graphics, the middle ground: full detail regardless of tier for the taker, the hurley, the sliotar and the posts; the crowd, the far stands, venue extras and effects follow the player's own tier."}
const Kit := preload("res://tests/note_kit.gd")

## Practice on Low keeps the player's Low (cards, no 3D fans), and the taker is at full detail (his full mesh, the
## kit's full look, his shadow), the posts drawn whole over the baked light.
func check() -> void:
	var keep = Game.settings.graphics
	Game.settings.graphics = Game.GFX_LOW
	var m: Node = await Kit.match(tree, {"mode": "practice", "user_team": 0, "seed": 3}, 20, true)
	var st: Stadium = m.stadium
	expect(int(Game.settings.graphics) == Game.GFX_LOW, "practice forced the graphics to level %d" % int(Game.settings.graphics))
	expect(st.crowd3d == null, "3D fans built on Low")
	var t: Player = m.taker
	expect(t.full_detail, "the taker is not at full detail")
	if t.link and t.link.body:
		var b: WsgBody = t.link.body
		expect(b._lod == 0 and b.full, "the taker's body is Low's light mesh")
	expect(m.shadows != null, "the taker casts no shadow")
	expect(not st.baked or st._posts != null, "the posts are not drawn over the baked light")
	await Kit.done(tree, m)
	Game.settings.graphics = keep
