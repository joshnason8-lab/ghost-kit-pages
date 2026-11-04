extends WsgOwnerNote
## The owner, 2026-11-03 (Kho Kho Rush 0.11.1): "Crowd still looks like they are 'in' the seats."

const NOTE := {"id": "2026-11-03-crowd-in-seats", "game": "kho-kho", "date": "2026-11-03", "version": "Kho Kho Rush 0.11.1", "words": "Crowd still looks like they are 'in' the seats."}
const KK := preload("res://tests/note_kk.gd")


## Every ground's crowd (main and near side, Low and the rest), as the game draws it (the shared cards): every seated
## fan's hips on the seat, every one facing the play (WsgCrowdCards.audit).
func check() -> void:
	KK.prepare(tree)
	for pair in [["maidan", "village"], ["school", "school"], ["arena", "arena"], ["floodlit", "stadium"]]:
		var f := KhoRules.field(KhoRules.FAST if pair[1] == "arena" else KhoRules.CLASSIC)
		for low in [false, true]:
			for part in ["main", "near"]:
				var v := VenueCrowd.build(pair[1], f, low, part)
				var placed := v.place(7)
				var cards := WsgCrowdCards.new()
				tree.root.add_child(cards)
				cards.build(placed)
				var res: Dictionary = cards.audit(v, placed)
				for fl in res.fails:
					fail("%s %s%s: %s" % [pair[0], part, " (Low)" if low else "", fl])
				cards.queue_free()
