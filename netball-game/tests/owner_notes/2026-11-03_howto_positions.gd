extends WsgOwnerNote
## The owner, 2026-11-03, on 0.8.6-beta.

const NOTE := {"id": "2026-11-03-howto-positions", "game": "netball", "date": "2026-11-03", "version": "0.8.6-beta",
	"words": "In the how to play positions section the court graphics don't show the positions, its just the same image over and over."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")


## All seven positions' courts on How to Play's positions page (test_runner _howto_positions): each lights exactly
## the areas the rules give her (Rules.AREAS) and dims the rest, her bib and her opposite number's stand onside in
## them and apart, her team's way is shown, no two positions' courts are alike, and the page draws the seven. In a
## window (not headless) the pictures themselves are rendered and read: each third and circle lit or dimmed as her
## areas say, and every pair of the 21 differs.
func check() -> void:
	var h: Node = await Harness.make(tree)
	await h._howto_positions()
	if DisplayServer.get_name() == "headless":
		info("(headless: the courts measured by their layout; run in a window to read their pixels)")
	await Harness.into(self, h)
