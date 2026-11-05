extends TakrawNote
## The owner, 2026-11-03: "When a player is prepping to block he is in a folded position and glides around its awkward"

const NOTE := {"id": "2026-11-03-block-folded", "game": "sepak-takraw", "date": "2026-11-03", "version": "0.15.1",
	"words": "When a player is prepping to block he is in a folded position and glides around its awkward"}


## A blocker on his way along the net (over 0.5 m/s, before he jumps) is upright - his hips at least 85% of their
## standing height - and his planted foot stays put (getting to a block: under 35% of the way slid; 0.15.2: 99%).
## Two regu matches.
func check() -> void:
	var st := {"low": INF, "frames": 0}
	for sd in [7, 3]:
		var m := make_match({"seed": sd})
		var stand := {}
		await play(m, 150.0, func(mm: Node):
			var b: Dictionary = mm.block
			if b.is_empty() or b.has("jump_t"):
				return
			var pl: Player = b.player
			if not stand.has(pl):
				stand[pl] = pl.body.bone_world("hips").y   # (planned as he stands: his standing height)
			if pl.vel.length() > 0.5 and absf(pl.body.position.y) < 0.02 and pl.move == "":
				st.frames += 1
				st.low = minf(float(st.low), pl.body.bone_world("hips").y / maxf(float(stand[pl]), 0.01)))
		m.queue_free()
		await frame()
	var s: Array = await glide_share(["block"])
	var low_most: float = st.low
	var frames_moving: int = st.frames
	info("blockers on their way along the net: %d frames, hips at least %.0f%% of standing; %.0f%% of %.0f m slid" % [
		frames_moving, 100.0 * low_most, 100.0 * float(s[0]), s[1]])
	expect(frames_moving > 20, "only %d frames of a blocker on his way seen" % frames_moving)
	expect(low_most > 0.85, "a blocker on his way along the net is folded down to %.0f%% of his standing height" % (100.0 * low_most))
	expect(float(s[1]) > 3.0 and float(s[0]) < 0.35, "getting to a block %.0f%% of %.0f m slid (under 35%%)" % [100.0 * float(s[0]), s[1]])
	await clean()
