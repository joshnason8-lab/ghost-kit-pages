extends TakrawNote
## The owner, 2026-10-25: "make sure in game the fans are looking at the game."

const NOTE := {"id": "2026-10-25-fans-watch-game", "game": "sepak-takraw", "date": "2026-10-25", "version": "0.9.1",
	"words": "make sure in game the fans are looking at the game."}


## At every venue, at every graphics level, every fan faces the play (the shared crowd's audit, WsgCrowdCards.audit:
## within its facing limit of the court) - none turned away, none side on.
func check() -> void:
	for v in venues():
		for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
			Game.settings.graphics = g
			var a := Arena.new(v, false, [Color("ff8a1f")])
			tree.root.add_child(a)
			await frame()
			if not expect(a.crowd != null and a.crowd.cards != null, "%s: no crowd" % v):
				a.queue_free()
				continue
			var res: Dictionary = a.crowd.cards.audit(Arena.crowd_venue(v), a.crowd.places)
			var facing_fails: Array = (res.fails as Array).filter(func(f: String) -> bool: return f.contains("facing") or f.contains("backwards"))
			if g == Game.GFX_LOW:
				info("%s: %d fans, at most %.0f degrees off the play" % [v, a.crowd.cards.placed_cards.size(), float(res.facing)])
			expect(facing_fails.is_empty(), "%s (graphics %d): %s" % [v, g, str(facing_fails)])
			a.queue_free()
			await frame()
