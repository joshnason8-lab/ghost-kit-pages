extends WsgOwnerNote
## The owner's request (relayed by the lead), 2026-11-02, after 0.8.3-beta: a match to watch, AI against AI.

const NOTE := {"id": "2026-11-02-watch-ai", "game": "netball", "date": "2026-11-02", "version": "0.8.3-beta",
	"words": "Watch AI"}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")


## The home screen has a Watch AI entry; it opens a team sheet and Watch starts an AI v AI match (nobody's controls,
## the broadcast camera, the scoreboard and clock); the speed chip and the pause menu run it at 1x and 2x (two of the
## match's own steps a frame: game time and the clock exactly twice as fast, the engine's time scale untouched) and
## back; pause holds it; a whole match reaches the result screen and counts in no records, cup or season; its words
## are in every language (test_runner _watch_ai). And in every venue a watched match runs at 2x: its clock twice as
## far in 30 frames as at 1x.
func check() -> void:
	var h: Node = await Harness.make(tree)
	await h._watch_ai()
	await Harness.into(self, h)
	h = await Harness.make(tree)
	for venue in ["arena", "hall", "outdoor"]:
		var m: Match = h._study_match(61, {"venue": venue, "watch": true, "mode": "watch"})
		await h._wait_live(m)
		var c0: float = m.clock
		for f in 30:
			await frame()
		var d1: float = m.clock - c0
		m.speed = 2
		c0 = m.clock
		for f in 30:
			await frame()
		var d2: float = m.clock - c0
		m.speed = 1
		info("%s: 30 frames are %.2f s of the match at 1x, %.2f s at 2x" % [venue, d1, d2])
		expect(d1 > 0.5 and absf(d2 - 2.0 * d1) < 0.1, "%s: 2x is not twice 1x (%.2f s, then %.2f s in 30 frames)" % [venue, d1, d2])
		expect(Engine.time_scale == 1.0, "%s: 2x touched the engine's time scale" % venue)
		m.queue_free()
		await frame()
		await frame()
	await Harness.done(h)
