extends WsgOwnerNote
## The owner, 2026-11-03 (Kho Kho Rush 0.12.3): "These games live in a world of reality. There will NEVER be a time when a player or referee should walk through a table or bench etc."

const NOTE := {"id": "2026-11-03-walk-through-props", "game": "kho-kho", "date": "2026-11-03", "version": "Kho Kho Rush 0.12.3", "words": "These games live in a world of reality. There will NEVER be a time when a player or referee should walk through a table or bench etc."}
const KK := preload("res://tests/note_kk.gd")


## A minute and a half of AI play at every ground (outs walking to their benches, umpires, the next batch): no body
## ever more than 2 cm inside a pole, the table, a bench, a barricade or anything else solid.
func check() -> void:
	for venue in ["maidan", "school", "arena", "floodlit"]:
		var m: Node = await KK.play(tree, {"user_team": -1, "venue": venue, "turn_len": 60.0, "format": KhoRules.FAST if venue == "arena" else KhoRules.CLASSIC})
		var solid: WsgSolidProps = m.arena.solid
		var worst := 0.0
		var where := ""
		for i in 2700:
			await frame()
			for a in m.everyone():
				var pen: Array = solid.penetration(a.position, Athlete.BODY_R)
				if float(pen[0]) > worst:
					worst = float(pen[0])
					where = "%s in %s" % [String(a.data.get("name", a.name)), str(pen[1])]
		info("%s: deepest any body went into a prop: %.3f m" % [venue, worst])
		expect(worst <= 0.02, "%s: %s, %.2f m deep" % [venue, where, worst])
		await KK.done(tree, m)
