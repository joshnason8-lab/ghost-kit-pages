extends WsgOwnerNote
## The owner, 2026-11-03, on 0.9.0-beta (after the ball's flight was put under gravity in 0.9.0).

const NOTE := {"id": "2026-11-03-passes-gravity", "game": "netball", "date": "2026-11-03", "version": "0.9.0-beta",
	"words": "Some times the passes are almost across the court and they just keep going, that seems unlikely. Like it will never succumb to gravity."}

const Passes := preload("res://tests/owner_notes/lib/passes.gd")
const Harness := preload("res://tests/owner_notes/lib/harness.gd")
const LONGEST := 2.0 * 30.5 / 3.0     # m: two thirds of the court (a pass over a whole third is not netball: R11)


## Every pass in AI matches in all three venues (a minute and a half of play each), as the ball really flew: none goes
## more than two thirds of the court (LONGEST) over the floor before it is caught or comes down; each one's height
## falls at g frame by frame (within 2%); none leaves the hands faster than 17.5 m/s; and a pass no one catches comes
## down to the floor in the time a ball dropped from its height takes (plus 0.2 s) and stops within 6 m of where it
## left the flight - it does not go on; and the ball, in no one's hands and in no throw (a whistle, a deflection, a
## loose ball), is never held up in the air: off the floor it falls at g.
func check() -> void:
	var h: Node = await Harness.make(tree)
	var hover := {}
	var passes: Array = await Passes.record(h, ["arena", "hall", "outdoor"], 2700, 51, hover)
	await Harness.done(h)
	var longest := 0.0
	var long_line := ""
	var loose := 0
	for p: Dictionary in passes:
		var what := Passes.line(p)
		var flat := float(p.get("flat", 0.0))
		if flat > longest:
			longest = flat
			long_line = what
		expect(flat <= LONGEST, "%s: almost across the court (more than %.1f m)" % [what, LONGEST])
		expect(float(p.g_worst) < 0.02 or int(p.frames) < 4, "%s: its height fell %.0f%% off gravity" % [what, float(p.g_worst) * 100.0])
		expect(float(p.speed) <= 17.5, "%s: thrown harder than a netballer throws" % what)
		if p.end == "loose" and not bool(p.get("picked", false)):
			loose += 1
			var h0: float = maxf(float(p.loose_at.y) - Ball.R, 0.0)
			var fall := sqrt(2.0 * h0 / Ball.G) + 0.2
			expect(float(p.floor_t) >= 0.0 and float(p.floor_t) <= fall, "%s, not caught: %s to come down from %.2f m (a dropped ball: %.2f s)" % [what,
				"%.2f s" % p.floor_t if float(p.floor_t) >= 0.0 else "never", h0, fall])
			expect(float(p.loose_flat) <= 6.0, "%s, not caught: it went on %.1f m" % [what, p.loose_flat])
	for venue in hover:
		var hv: Array = hover[venue]
		info("%s: the ball up in the air and not falling for %d frames at most%s" % [venue, hv[0], (" (%s)" % hv[1]) if int(hv[0]) > 0 else ""])
		expect(int(hv[0]) <= 2, "%s: the ball held up in the air, not falling, for %.1f s (%s)" % [venue, int(hv[0]) / 30.0, hv[1]])
	info("%d passes, %d not caught; the longest %.1f m (%s)" % [passes.size(), loose, longest, long_line])
	expect(passes.size() >= 40, "only %d passes seen" % passes.size())
