extends WsgOwnerNote
## The owner, 2026-11-04 (Hurling 0.24.13, through the lead): "Temporary subs for blood and head injuries: YES. Use the rules as you found them: no time limit and not counted. Injuries become a match event, so keep them rare and realistic, with an owner note and an AI sub."

const NOTE := {"id": "2026-11-04-temp-subs", "game": "hurling", "date": "2026-11-04", "version": "Hurling 0.24.13", "words": "Temporary subs for blood and head injuries: YES. Use the rules as you found them: no time limit and not counted. Injuries become a match event, so keep them rare and realistic, with an owner note and an AI sub."}
const Kit := preload("res://tests/note_kit.gd")


## In a match: a man hurt (blood) goes off at the next break and the manager's temporary substitute comes on for him -
## not counted among the five - and he comes back once treated; injuries are rare (Match.INJURY_P: a few hundredths of
## the hard falls).
func check() -> void:
	expect(Match_INJURY_P() > 0.0 and Match_INJURY_P() <= 0.05, "injuries are not rare: %.2f of hard falls" % Match_INJURY_P())
	var m: Node = await Kit.match(tree, {"seed": 7}, 3)
	var slot: Player = m.player_by_num(1, 7)
	var man := String(slot.data.id)
	var left: int = m.subs_left(1)
	m.carrier = null
	m.hurt(slot, "blood")
	m._run_temp()
	info("on for %s: %s" % [man, slot.data.id])
	expect(String(slot.data.id) != man, "the hurt man was not replaced at the break")
	expect(m.subs_left(1) == left, "the temporary substitute counted among the five")
	m.watch += 8.0 * 60.0
	m._run_temp()
	expect(String(slot.data.id) == man, "treated, he did not come back on")
	expect(m.subs_left(1) == left, "his coming back counted among the five")
	await Kit.done(tree, m)


static func Match_INJURY_P() -> float:
	return float(load("res://game/match.gd").get_script_constant_map().get("INJURY_P", 1.0))
