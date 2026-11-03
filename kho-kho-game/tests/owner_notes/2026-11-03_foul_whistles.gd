extends WsgOwnerNote
## The owner, 2026-11-03 (Kho Kho Rush 0.12.1): "When crossing the foul line the whistles go nuts until you go back, is that supposed to be like that?"

const NOTE := {"id": "2026-11-03-foul-whistles", "game": "kho-kho", "date": "2026-11-03", "version": "Kho Kho Rush 0.12.1", "words": "When crossing the foul line the whistles go nuts until you go back, is that supposed to be like that?"}
const KK := preload("res://tests/note_kk.gd")


## A foul that stands for 10 s: the umpire calls it, then reminds - at most 6 whistles in those 10 s (it was 31).
func check() -> void:
	var m: Node = await KK.play(tree)
	m._on_foul(KhoRules.FOUL_LATE_KHO if "FOUL_LATE_KHO" in KhoRules else "late_kho")
	m.chase.foul = "turned back"
	var calls := 2   # the call itself: two blasts
	var last: float = m._foul_whistle
	for i in 300:
		m.chase.foul = "turned back"
		await frame()
		if float(m._foul_whistle) > last + 0.5:
			calls += 1
		last = m._foul_whistle
	info("%d whistles in 10 s of a foul standing" % calls)
	expect(calls <= 6, "%d whistles in 10 s while a foul stands" % calls)
	m.chase.foul = ""
	await KK.done(tree, m)
