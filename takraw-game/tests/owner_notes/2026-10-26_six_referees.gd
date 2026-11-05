extends TakrawNote
## The owner, 2026-10-26: "Six referees sitting around looks creepy lets have the middle two and one on each end off to
## the side. Don't have the end ones sitting. have them standing and react some to the shots, like getting out of the
## way if the ball goes near them. Make them seem like they are judging."

const NOTE := {"id": "2026-10-26-six-referees", "game": "sepak-takraw", "date": "2026-10-26", "version": "0.11.1",
	"words": "Six referees sitting around looks creepy lets have the middle two and one on each end off to the side. Don't have the end ones sitting. have them standing and react some to the shots, like getting out of the way if the ball goes near them. Make them seem like they are judging."}


## At every venue: four officials - the referee in his chair at the middle, the assistant at the other post, and a line
## judge standing off each end, out to the side - and a ball coming at a line judge has him step out of its way. Their
## heads follow the ball (judging).
func check() -> void:
	for v in venues():
		var m := make_match({"venue": v, "seed": 3})
		await frame()
		var offs: Officials = m.get("_officials")
		var sitting := offs.list.filter(func(o): return not o.standing).size()
		var judges := offs.list.filter(func(o): return o.judge)
		var ends := judges.filter(func(o): return o.standing and absf(o.body.global_position.x) > Court.HALF)
		var mid := offs.list.filter(func(o): return absf(o.body.global_position.x) < 1.5)
		info("%s: %d officials, %d sitting, %d line judges standing at the ends, %d at the middle" % [v, offs.list.size(), sitting, ends.size(), mid.size()])
		expect(offs.list.size() == 4 and sitting == 1 and ends.size() == 2 and mid.size() == 2,
			"%s: %d officials, %d sitting, %d judges standing at the ends, %d at the middle (want 4, 1, 2, 2)" % [v, offs.list.size(), sitting, ends.size(), mid.size()])
		# A ball coming at each line judge, chest high: he steps out of its way within 0.7 s.
		for o in ends:
			var at: Vector3 = o.body.global_position + Vector3(0, 1.2, 0)
			var from := at + Vector3(-signf(at.x) * 6.0, 0.3, -1.0)
			var stepped := 0.0
			for i in 21:
				var t := i * DT
				var p := from.lerp(at, minf(1.0, t / 0.6))
				offs.tick(DT, p, true)
				stepped = maxf(stepped, (o.off_to as Vector3).length())
			expect(stepped > 0.6, "%s: a ball coming at a line judge, he steps only %.2f m out of its way" % [v, stepped])
		m.queue_free()
		await frame()
	await clean()
