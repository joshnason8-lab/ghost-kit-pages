extends WsgOwnerNote
## The owner, 2026-10-29 (Floorball 0.8.2).

const NOTE := {"id": "2026-10-29-crowd-watching", "game": "floorball", "date": "2026-10-29", "version": "0.8.2",
	"words": "Make sure the crowd is actually watching the game."}

const Lib := preload("res://tests/note_lib.gd")


## Every venue, Low and Medium: every fan in the stands faces the play (the shared crowd's own audit: none further off
## the nearest play than it allows), and there are fans to see it.
func check() -> void:
	var keep: int = Game.settings.graphics
	for gfx in [Game.GFX_LOW, Game.GFX_MEDIUM]:
		Game.settings.graphics = gfx
		for venue in ["arena", "hall", "school"]:
			var a := Arena.new(venue, [Color.RED], [Color.BLUE])
			Lib.host(tree).add_child(a)
			await tree.process_frame
			if a.crowd == null:
				fail("graphics %d, %s: no crowd" % [gfx, venue])
				a.queue_free()
				continue
			var r: Dictionary = a.crowd.audit(a.crowd_venue, a.crowd_placed)
			info("graphics %d, %s: %d fans, the most any is turned from the play %.0f degrees" % [gfx, venue, r.cards, r.facing])
			expect(int(r.cards) > 20, "graphics %d, %s: only %d fans" % [gfx, venue, r.cards])
			for f in r.fails:
				if String(f).contains("facing"):
					fail("graphics %d, %s: %s" % [gfx, venue, f])
			a.queue_free()
			await tree.process_frame
	Game.settings.graphics = keep
