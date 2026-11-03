extends WsgOwnerNote
## The owner, 2026-11-03, on 0.8.6-beta.

const NOTE := {"id": "2026-11-03-hands-on-ball", "game": "netball", "date": "2026-11-03", "version": "0.8.6-beta",
	"words": "Often times their hands aren't holding the ball, it looks like the forearms are holding the ball."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")


## Every frame the ball is held in AI matches in the arena and the sports hall (catching, holding, passing, shooting,
## landing), on Low (the game's own bodies: each palm's skin within 2 cm of the ball's surface, neither forearm inside
## the ball) and on Medium with the licensed clips (the shared foundation's body: each palm on the ball within 2 cm,
## its forearms clear of it), at least 200 frames held each (test_runner _shots_and_hands); and on Medium the ball
## drawn where the drawn hands hold it, both palms on it in nearly every held frame (test_runner _foundation).
func check() -> void:
	var h: Node = await Harness.make(tree)
	await h._shots_and_hands()
	await Harness.into_only(self, h, ["the ball in her hands"])
	if Harness.have_clips():
		h = await Harness.make(tree)
		FoundationLink.off = false
		await h._foundation(true)
		await Harness.into_only(self, h, ["palms on the ball", "where the drawn hands hold it"])
	else:
		info("(no licensed clips here: the foundation's hands not measured)")
