extends WsgOwnerNote
const NOTE := {"id": "2026-11-03-tag-vibration", "game": "kabaddi", "date": "2026-11-03", "version": "0.14.1-beta",
	"words": "On defense if you get tagged it should vibrate as well."}
const U := preload("res://tests/owner_note_util.gd")


func check() -> void:
	var m: Node = U.start(tree, {"first_raider": 1, "passive": true})
	await U.until_raid(tree, m)
	var me: Athlete = m.controlled
	expect(me != null and me != m.raider, "the player is not defending in this raid")
	var mates: Array = m.defenders().filter(func(a): return a != me)
	m.haptics.clear()
	m._touch(me)
	if not mates.is_empty():
		m._touch(mates[0])
	info("haptics on a tag on you, then on a team-mate: %s" % str(m.haptics))
	expect(m.haptics.size() >= 1 and m.haptics[0] == "touched", "no buzz when the raider tags you (%s)" % str(m.haptics))
	expect(Game.HAPTICS.has("touched") and Game.HAPTICS.touched[0] is Array, "the tag buzz is not a firm double knock")
	m.queue_free()
	await U.frames(tree, 2)
