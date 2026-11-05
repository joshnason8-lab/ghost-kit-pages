extends WsgOwnerNote
const NOTE := {"id": "2026-11-03-crowd-in-seats", "game": "kabaddi", "date": "2026-11-03", "version": "0.14.1-beta",
	"words": "The crowd is still \"in the seats\""}
const U := preload("res://tests/owner_note_util.gd")


## Every ground's crowd as the game builds it, at Low, Medium and High: every card and every 3D fan seated on their
## seat (not in it), soles on the floor, facing the play (WsgCrowdVenue.audit and the cards' own).
func check() -> void:
	U.host(tree)
	var was := int(Game.settings.graphics)
	for gfx in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = gfx
		WsgFoundation.tier = gfx
		for id in ["dome", "stadium", "village", "monsoon", "beach"]:
			var ar := Arena.new()
			Game.main.add_child(ar)
			ar.build(id, Color.RED, Color.BLUE, "TEST")
			await U.frames(tree, 1)
			var cards: Dictionary = ar.crowd_cards.audit(ar.crowd_venue, ar.crowd_placed) if ar.crowd_cards != null else {"cards": 0, "fails": []}
			var fans: Dictionary = WsgCrowdVenue.audit(ar.crowd3d, ar.crowd_venue, 0) if ar.crowd3d != null else {"fans": 0, "fails": []}
			info("%s at %s: %d cards, %d 3D fans" % [id, ["Low", "Medium", "High"][gfx], cards.cards, fans.fans])
			expect(cards.cards + fans.fans > 20, "%s at %s: no crowd" % [id, gfx])
			for f in cards.fails + fans.fails:
				fail("%s at %s: %s" % [id, ["Low", "Medium", "High"][gfx], f])
			ar.queue_free()
			await U.frames(tree, 1)
	Game.settings.graphics = was
	WsgFoundation.tier = was
