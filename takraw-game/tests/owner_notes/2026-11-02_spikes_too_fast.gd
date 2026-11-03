extends TakrawNote
## The owner, 2026-11-02: "Some of the spikes are a bit too hard and fast, you can't even see the ball."

const NOTE := {"id": "2026-11-02-spikes-too-fast", "game": "sepak-takraw", "date": "2026-11-02", "version": "0.14.1",
	"words": "Some of the spikes are a bit too hard and fast, you can't even see the ball."}

## A real roll spike's 30 m/s (108 km/h) crossed the court in four or five frames; the game's spikes fly at
## Match.SPIKE_PACE of a real one's speed: at most 21.5 m/s (77 km/h).
const MOST := 21.5


## Every spike (roll, sunback, tapak, head) of three AI regu matches leaves the foot at MOST m/s or less: the fastest
## takes about 0.3 s to cross 6 m (a real one's speed: under 0.2 s).
func check() -> void:
	var speeds := []
	for run in [[7, "national"], [3, "park"], [11, "beach"]]:
		var m := make_match({"seed": run[0], "venue": run[1]})
		var seen := {"t": -1.0}
		await play(m, 150.0, func(mm: Node):
			var b: Ball = mm.ball
			if b.flying and not is_equal_approx(b.t_launch, float(seen.t)):
				seen.t = b.t_launch
				if String(mm.get("_attack_kind")) in ["roll", "sunback", "tapak", "head_spike"] and b.v_launch.length() > 12.0:
					speeds.append(b.v_launch.length()))
		m.queue_free()
		await frame()
	var top: float = speeds.max() if not speeds.is_empty() else 0.0
	info("%d spikes, the fastest %.1f m/s (%.0f km/h): 6 m in %.2f s" % [speeds.size(), top, top * 3.6, 6.0 / maxf(top, 0.1)])
	expect(speeds.size() >= 10, "only %d spikes seen" % speeds.size())
	expect(top <= MOST, "a spike left the foot at %.1f m/s (at most %.1f)" % [top, MOST])
	await clean()
