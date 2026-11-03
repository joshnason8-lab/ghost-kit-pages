extends WsgOwnerNote
## The owner (relayed by the lead to every game), 2026-11-03, on the slow phone.

const NOTE := {"id": "2026-11-03-loading-frozen", "game": "netball", "date": "2026-11-03", "version": "0.9.0-beta (every game)",
	"words": "When you click start game there is a loading delay … long enough on the slow phone that users might think the game has frozen. We either need a little load screen or load bar by the start buttons."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")


## Every Start button - Quick Match's Play, Watch AI's Watch, the Nations Cup's and the Club Season's Play, the result
## screen's Rematch - on every graphics level: the tap puts the loading overlay up in its own frame (a bar, a spinner,
## the game's words) and turns the screen's buttons off; a second tap or Back starts nothing; the bar only moves forward
## and reaches the end; the match takes the screen's place and plays (test_runner _loading_overlay); no screen starts a
## match without it.
func check() -> void:
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		var h: Node = await Harness.make(tree)
		Game.settings.graphics = g
		var before: int = h.failed.size()
		await h._loading_overlay()
		for i in range(before, h.failed.size()):
			h.failed[i] = "%s: %s" % [["Low", "Medium", "High"][g], h.failed[i]]
		info("%s: %d checks" % [["Low", "Medium", "High"][g], h.checks])
		await Harness.into(self, h)
