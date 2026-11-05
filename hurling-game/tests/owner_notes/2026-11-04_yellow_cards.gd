extends WsgOwnerNote
## The owner, 2026-11-04 (Hurling 0.24.13, through the lead): "Follow the GAA Official Guide: caution every pull-down, trip and careless hurley, plus holding or charging on the second offence."

const NOTE := {"id": "2026-11-04-yellow-cards", "game": "hurling", "date": "2026-11-04", "version": "Hurling 0.24.13", "words": "Follow the GAA Official Guide: caution every pull-down, trip and careless hurley, plus holding or charging on the second offence."}
const Kit := preload("res://tests/note_kit.gd")


## In a match (senior county): a trip, a pull-down and a careless hurley are each a yellow card the first time (5.1,
## 5.2, 5.6); a hold is no card the first time and a yellow the second (5.10). Each foul on a man without the ball
## (no advantage), by a fresh man each time.
func check() -> void:
	var m: Node = await Kit.match(tree, {"seed": 7}, 3)
	var cases := [["FOUL_TRIP", 2, 1], ["FOUL_PULL_DOWN", 3, 1], ["FOUL_HURLEY", 4, 1], ["FOUL_HOLD_MAN", 5, 0]]
	for c in cases:
		var by: Player = m.player_by_num(1, int(c[1]))
		var on: Player = m.player_by_num(0, 13)
		m.phase = m.P.LIVE
		m.carrier = null
		m._aggressive_foul(by, on, String(c[0]), false)
		await Kit.frames(tree, 45)
		info("%s: %d yellow" % [c[0], by.yellows])
		expect(by.yellows == int(c[2]), "%s the first time: %d yellow cards (want %d)" % [c[0], by.yellows, int(c[2])])
	var holder: Player = m.player_by_num(1, 5)
	m.phase = m.P.LIVE
	m.carrier = null
	m._aggressive_foul(holder, m.player_by_num(0, 13), "FOUL_HOLD_MAN", false)
	await Kit.frames(tree, 45)
	expect(holder.yellows == 1, "holding the second time: %d yellow cards (want 1)" % holder.yellows)
	await Kit.done(tree, m)
