extends TakrawNote
## The owner, 2026-10-24: "The ball has no movement in the air, it should spin or rotate"

const NOTE := {"id": "2026-10-24-ball-spin", "game": "sepak-takraw", "date": "2026-10-24", "version": "0.5.2",
	"words": "The ball has no movement in the air, it should spin or rotate"}


## In AI play, every frame the ball flies it turns: its drawn mesh's rotation changes from one flying frame to the next.
func check() -> void:
	var m := make_match({"seed": 8})
	var st := {"flying": 0, "still": 0, "was": Basis()}
	await play(m, 90.0, func(mm: Node):
		var b: Ball = mm.ball
		var mesh: Node3D = b.get("_mesh")
		if not b.flying or mesh == null:
			st.was = Basis()
			return
		var now := mesh.global_transform.basis
		if st.was != Basis():
			st.flying += 1
			if now.is_equal_approx(st.was):
				st.still += 1
		st.was = now)
	info("%d flying frames, %d without a turn" % [st.flying, st.still])
	expect(int(st.flying) > 300, "only %d flying frames seen" % st.flying)
	expect(float(st.still) <= 0.02 * float(st.flying), "the ball did not turn in %d of %d flying frames" % [st.still, st.flying])
	await clean()
