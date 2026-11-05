extends TakrawNote
## The owner, 2026-10-25: "the judge sitting on the box looks awkward with his arms extended out, relax him."

const NOTE := {"id": "2026-10-25-referee-arms", "game": "sepak-takraw", "date": "2026-10-25", "version": "0.9.1",
	"words": "the judge sitting on the box looks awkward with his arms extended out, relax him."}


## The referee in his chair, over 40 s of play on Low (the game's body) and High (the shared foundation's, where its
## library is), keeps his arms relaxed: each upper arm at most 45 degrees out from hanging, except while he signals.
func check() -> void:
	for level in [Game.GFX_LOW, Game.GFX_HIGH]:
		var m := make_match({"seed": 3}, level)
		var ref: RealBody = m.officials[0]
		var offs: Officials = m.get("_officials")
		var one = offs.list.filter(func(o): return o.body == ref)[0]
		var st := {"worst": 0.0, "frames": 0}
		await play(m, 40.0, func(mm: Node):
			if float(one.sig_w) > 0.0:
				return   # (signalling: his arms are up on purpose)
			st.frames += 1
			var link: FoundationLink = ref.link
			if link and link.body and link.body.visible:
				var a := WsgNoteChecks.arms(link.body)
				st.worst = maxf(float(st.worst), maxf(float(a.Left[0]), float(a.Right[0])))
			else:
				var down := -ref.global_transform.basis.y.normalized()
				for s in ["l", "r"]:
					var up: Vector3 = (ref.bone_world("forearm_" + s) - ref.bone_world("upperarm_" + s)).normalized()
					st.worst = maxf(float(st.worst), rad_to_deg(up.angle_to(down))), level == Game.GFX_HIGH)
		var tag := "Low" if level == Game.GFX_LOW else "High"
		info("%s: the seated referee's upper arms at most %.0f degrees out from hanging (%d frames)" % [tag, st.worst, st.frames])
		expect(int(st.frames) > 100 and float(st.worst) <= 45.0, "%s: the seated referee's arms are out %.0f degrees from hanging" % [tag, st.worst])
		m.queue_free()
		await frame()
	await clean()
