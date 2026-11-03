extends WsgOwnerNote
## The owner, 2026-11-03, on 0.8.6-beta (Medium and High: the shared foundation's bodies).

const NOTE := {"id": "2026-11-03-floating-legs", "game": "netball", "date": "2026-11-03", "version": "0.8.6-beta",
	"words": "Players floating around and not moving legs, thought that was fixed in shared foundation."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")


## The shared foundation's bodies (Medium, with the licensed clips), each move on its own (test_runner
## _foundation_steps: jogging to sprinting, side-stepping, defending, passing and catching on the run, the ball behind
## her, pulling up: a drawn foot on the floor moves under 5 cm, four steps or more each) and every player and umpire in
## AI matches in two venues; the same matches on High (its nearest 22 posed every frame); and Low's own bodies in their
## matches (test_runner _gait_in_match): no planted foot skating, everyone stepping as she runs.
func check() -> void:
	var h: Node = await Harness.make(tree)
	Game.settings.graphics = Game.GFX_LOW
	for mc: Array in [["arena", 6], ["hall", 9]]:
		await h._gait_in_match(mc[0], mc[1])
	if not Harness.have_clips():
		await Harness.into(self, h)
		skip("no licensed clip library here: the shared foundation's bodies (Medium and High) not measured")
		return
	await h._foundation_steps()
	FoundationLink.off = false
	Game.settings.graphics = Game.GFX_HIGH
	for mc: Array in [["outdoor", 7], ["arena", 8]]:
		var before: int = h.failed.size()
		await h._foundation_match(mc[0], mc[1])
		for i in range(before, h.failed.size()):
			h.failed[i] = "High: " + String(h.failed[i])
	await Harness.into(self, h)
