extends WsgOwnerNote
## The owner, 2026-11-02 (Kho Kho Rush 0.11.1): "The runner can run through the kneeling players like they are ghosts."

const NOTE := {"id": "2026-11-02-kneeling-ghosts", "game": "kho-kho", "date": "2026-11-02", "version": "Kho Kho Rush 0.11.1", "words": "The runner can run through the kneeling players like they are ghosts."}
const KK := preload("res://tests/note_kk.gd")


## A minute of AI play at two grounds: no defender's middle ever closer than 0.55 m to a kneeling chaser's.
func check() -> void:
	for venue in ["school", "arena"]:
		var m: Node = await KK.play(tree, {"user_team": -1, "venue": venue, "format": KhoRules.FAST if venue == "arena" else KhoRules.CLASSIC})
		var closest := INF
		for i in 1800:
			await frame()
			if m.phase != "play":
				continue
			for d in m.batch:
				if m.d_state.get(d, "") != "in" or not m._solid(d):
					continue
				for q in m.squares:
					if q == null or q == m.active or q.act != "sit":
						continue
					closest = minf(closest, Vector2(d.position.x - q.position.x, d.position.z - q.position.z).length())
		info("%s: closest a runner came to a kneeling chaser: %.2f m" % [venue, closest])
		expect(closest >= 0.55, "%s: a runner %.2f m from a kneeling chaser's middle (through him)" % [venue, closest])
		await KK.done(tree, m)
