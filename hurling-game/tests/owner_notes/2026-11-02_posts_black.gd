extends WsgOwnerNote
## The owner (relayed by the lead), 2026-11-02 (Hurling 0.18.0): "goal posts turned black"

const NOTE := {"id": "2026-11-02-posts-black", "game": "hurling", "date": "2026-11-02", "version": "Hurling 0.18.0", "words": "goal posts turned black"}
const Kit := preload("res://tests/note_kit.gd")

## On every level whose light is baked (Low and Medium), the goals are drawn again white over the baked light (the
## thin posts' patches of the light map came out black); High lights them itself.
func check() -> void:
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM]:
		var keep = Game.settings.graphics
		Game.settings.graphics = g
		for v in ["parish", "county", "stadium"]:
			var m: Node = await Kit.match(tree, {"mode": "quick", "user_team": 0, "venue": v}, 3)
			var st: Stadium = m.stadium
			var ok: bool = not st.baked or (st._posts != null and st._posts.is_inside_tree() and st._posts.visible and st._posts.mesh != null)
			info("level %d, %s: baked %s, posts drawn over it %s" % [g, v, st.baked, st._posts != null])
			expect(ok, "level %d, %s: the posts under the baked light only (black)" % [g, v])
			await Kit.done(tree, m)
		Game.settings.graphics = keep
