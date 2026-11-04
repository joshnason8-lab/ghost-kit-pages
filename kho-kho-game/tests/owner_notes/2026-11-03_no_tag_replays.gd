extends WsgOwnerNote
## The owner, 2026-11-03 (Kho Kho Rush 0.12.1): "Get rid of the replays on tags. On low quality I feel like they will never look good."

const NOTE := {"id": "2026-11-03-no-tag-replays", "game": "kho-kho", "date": "2026-11-03", "version": "Kho Kho Rush 0.12.1", "words": "Get rid of the replays on tags. On low quality I feel like they will never look good."}
const KK := preload("res://tests/note_kk.gd")


## An out (a touch, a dive, a pole dive), with moments kept and a replay already due: none is shown for it.
func check() -> void:
	var m: Node = await KK.play(tree)
	for kind in [KhoRules.OUT_TOUCH, KhoRules.OUT_DIVE, KhoRules.OUT_POLE]:
		var rp := MatchReplay.new(m)
		m.add_child(rp)
		m.replay = rp
		rp.moment("pole_turn", m.active)
		rp.close()
		var d: Athlete = null
		for x in m.batch:
			if m.d_state.get(x, "") == "in":
				d = x
		if d == null:
			skip("no defender in to put out")
			return
		m._out(d, kind, m.active)
		expect(rp.moments.is_empty() and float(rp._due) < 0.0, "%s out: a replay still kept or due" % kind)
		for i in 90:
			await frame()
		expect(not rp.playing(), "%s out: a replay played" % kind)
		m.replay = null
		rp.queue_free()
	await KK.done(tree, m)
