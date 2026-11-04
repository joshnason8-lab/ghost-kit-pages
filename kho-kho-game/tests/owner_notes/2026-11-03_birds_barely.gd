extends WsgOwnerNote
## The owner, 2026-11-03 (Kho Kho Rush 0.12.1): "Quiet the birds way more they are annoying, it should be barely noticable."

const NOTE := {"id": "2026-11-03-birds-barely", "game": "kho-kho", "date": "2026-11-03", "version": "Kho Kho Rush 0.12.1", "words": "Quiet the birds way more they are annoying, it should be barely noticable."}
const KK := preload("res://tests/note_kk.gd")


## The school's birds: at most -24 dB (barely there), and quieter than every other ground's own sound.
func check() -> void:
	var amb: Dictionary = Sfx.AMBIENCE
	var birds: float = amb.school[1]
	info("birds %.0f dB" % birds)
	expect(birds <= -24.0, "the birds at %.0f dB" % birds)
	for k in amb:
		if k != "school":
			expect(birds < float(amb[k][1]), "the birds (%.0f dB) as loud as the %s's %s (%.0f dB)" % [birds, k, amb[k][0], amb[k][1]])
