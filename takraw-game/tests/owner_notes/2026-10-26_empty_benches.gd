extends TakrawNote
## The owner, 2026-10-26: "should there be substitutes that are sitting on the benches? The benches look weird empty."

const NOTE := {"id": "2026-10-26-empty-benches", "game": "sepak-takraw", "date": "2026-10-26", "version": "0.11.1",
	"words": "should there be substitutes that are sitting on the benches? The benches look weird empty."}


## At every venue, regu and doubles, on Low and High: each team has substitutes sitting on its bench, in its kit, off
## the court.
func check() -> void:
	for level in [Game.GFX_LOW, Game.GFX_HIGH]:
		for v in venues():
			for ev in ["regu", "doubles"]:
				var m := make_match({"venue": v, "event": ev}, level)
				await frame()
				var subs: Array = m.get("_subs")
				var ok := true
				for k in 2:
					for b in subs[k]:
						var p: Vector3 = (b as Node3D).global_position
						var hips: float = (b as RealBody).bone_world("hips").y
						ok = ok and absf(p.z) > Court.HALF_W + 0.5 and hips < 0.8   # (sitting: his hips on the bench, not standing at ~0.95 m)
				var n: Array = [(subs[0] as Array).size(), (subs[1] as Array).size()]
				expect(n[0] >= 1 and n[1] >= 1 and ok, "%s %s (%s): substitutes %s, seated off the court %s" % [v, ev, ["Low", "Medium", "High"][level], str(n), ok])
				m.queue_free()
		info("%s: every venue, regu and doubles: each bench has its substitutes, seated" % ["Low", "Medium", "High"][level])
	await clean()
