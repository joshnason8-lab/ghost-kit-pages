extends TakrawNote
## The owner, 2026-11-03: "Still lots of gliding when getting the ball too."

const NOTE := {"id": "2026-11-03-glide-getting-ball", "game": "sepak-takraw", "date": "2026-11-03", "version": "0.15.1",
	"words": "Still lots of gliding when getting the ball too."}


## Getting to the ball for a touch - the chest, the head, the sila, the thigh - under 35% of the way slid along with
## him (0.15.2: 96-98%).
func check() -> void:
	var s: Array = await glide_share(["chest", "header", "sila", "thigh"])
	info("getting to the ball: %.0f%% of %.0f m slid" % [100.0 * float(s[0]), s[1]])
	expect(float(s[1]) > 3.0 and float(s[0]) < 0.35, "getting to the ball %.0f%% of %.0f m slid (under 35%%)" % [100.0 * float(s[0]), s[1]])
