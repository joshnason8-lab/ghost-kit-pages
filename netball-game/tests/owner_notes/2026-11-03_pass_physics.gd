extends WsgOwnerNote
## The owner, 2026-11-03, on 0.8.6-beta.

const NOTE := {"id": "2026-11-03-pass-physics", "game": "netball", "date": "2026-11-03", "version": "0.8.6-beta",
	"words": "The pass speed doesn't look very natural, the lobs especially. Check the physics of the ball movement."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")
const Passes := preload("res://tests/owner_notes/lib/passes.gd")


## Every kind of throw over its range of lengths, as planned (test_runner _ball_flight: gravity at 9.81 m/s² and a
## constant speed across the floor; a chest pass 8-14 m/s, a shoulder pass 11-17.5, a lob 1.5-3 m over the hands
## and 1-1.7 s in the air, slower across than a chest pass, a bounce pass off the floor, shots at 45-55 degrees), and
## frame by frame in a match (_ball_in_play); then every pass in AI matches in all three venues as the ball flew it:
## each falls at g (within 2%), leaves the hands no faster than 17.5 m/s (a netballer's hardest throw), and each lob
## goes up 1.5 m or more over the hands and hangs a second or more (within a frame).
func check() -> void:
	var h: Node = await Harness.make(tree)
	h._ball_flight()
	await h._ball_in_play()
	var passes: Array = await Passes.record(h, ["arena", "hall", "outdoor"], 1800)
	await Harness.into(self, h)
	var kinds := {}
	for p: Dictionary in passes:
		var k: String = p.kind
		kinds[k] = int(kinds.get(k, 0)) + 1
		var what := Passes.line(p)
		expect(float(p.g_worst) < 0.02 or int(p.frames) < 4, "%s: it fell %.0f%% off gravity" % [what, float(p.g_worst) * 100.0])
		expect(float(p.speed) <= 17.5, "%s: thrown harder than a netballer throws" % what)
		if k == "lob" and int(p.frames) >= 20:
			expect(float(p.top) - p.from.y >= 1.5 and float(p.air) >= 0.95, "%s: a lob that does not go up and hang" % what)
	info("%d passes in three venues: %s" % [passes.size(), kinds])
	expect(passes.size() >= 30, "only %d passes seen" % passes.size())
	expect(kinds.size() >= 3, "only these kinds of pass seen: %s" % [kinds])
