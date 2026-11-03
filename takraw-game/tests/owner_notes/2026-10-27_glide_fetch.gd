extends TakrawNote
## The owner, 2026-10-27: "When the player goes to get the ball he glides backfor the most part instead of walking"

const NOTE := {"id": "2026-10-27-glide-fetch", "game": "sepak-takraw", "date": "2026-10-27", "version": "0.12.1",
	"words": "When the player goes to get the ball he glides backfor the most part instead of walking"}


## Walking between points - to the ball, back with it, to his place - his planted foot stays put: of the way walked,
## under a quarter slid along with him (0.15.2: 63%), and half the steps slip under 2 cm.
func check() -> void:
	var s: Array = await glide_share(["walk (between points)"])
	var st: Array = await step_slip("walk (between points)")
	info("walking between points: %.0f%% of %.0f m slid; half of %d steps slip under %.1f cm" % [100.0 * float(s[0]), s[1], st[1], 100.0 * float(st[0])])
	expect(float(s[1]) > 3.0 and float(s[0]) < 0.25, "walking between points %.0f%% of %.0f m slid (under 25%%)" % [100.0 * float(s[0]), s[1]])
	expect(int(st[1]) > 100 and float(st[0]) < 0.02, "walking between points, half the steps slip %.1f cm or more (under 2)" % (100.0 * float(st[0])))
