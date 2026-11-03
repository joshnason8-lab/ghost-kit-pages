extends WsgOwnerNote
## The owner, 2026-11-03 (Kho Kho Rush 0.12.1): "Sometimes the players are so close it's obvious there would be a tag but they just run right by. We need to fix that."

const NOTE := {"id": "2026-11-03-tags-run-by", "game": "kho-kho", "date": "2026-11-03", "version": "Kho Kho Rush 0.12.1", "words": "Sometimes the players are so close it's obvious there would be a tag but they just run right by. We need to fix that."}
const KK := preload("res://tests/note_kk.gd")


## A runner body to body with the chaser, at every difficulty: the touch slips no more than 6 times in 10; at arm's
## length the slips are seen (he twists away: the dodge).
func check() -> void:
	for diff in 4:
		var m: Node = await KK.play(tree, {"user_team": -1, "difficulty": diff, "seed": 11 + diff})
		var a: Athlete = m.active
		var d: Athlete = null
		for x in m.batch:
			if m.d_state.get(x, "") == "in":
				d = x
		var slips := 0
		var unseen := 0
		for t in 200:
			m._ai[d].erase("slip_until")
			d.act = ""
			d.position = a.position + Vector3(0.45 if t < 100 else 0.75, 0, 0)
			var s: bool = m._swerves(d, KhoRules.OUT_TOUCH)
			if t < 100 and s:
				slips += 1
			if t >= 100 and s and d.act != "dodge":
				unseen += 1
		info("difficulty %d: %d slips in 100 at contact" % [diff, slips])
		expect(slips <= 60, "difficulty %d: %d of 100 touches at contact slipped" % [diff, slips])
		expect(unseen == 0, "difficulty %d: %d slips at arm's length with no dodge to see" % [diff, unseen])
		await KK.done(tree, m)
