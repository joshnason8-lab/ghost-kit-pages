extends WsgOwnerNote
const NOTE := {"id": "2026-11-02-tag-vibration-raider", "game": "kabaddi", "date": "2026-11-02", "version": "0.13.3-beta",
	"words": "tagging someone on Kabaddi should have a phone vibration"}
const U := preload("res://tests/owner_note_util.gd")


## Raiding, every tag the user's raider makes buzzes the phone.
func check() -> void:
	var m: Node = U.start(tree, {"first_raider": 0, "passive": true})
	await U.until_raid(tree, m)
	expect(m.raider == m.controlled, "the user is not raiding")
	var n := 0
	for d in m.defenders():
		m.haptics.clear()
		m._touch(d)
		n += 1
		expect(not m.haptics.is_empty(), "no buzz when the raider tags %s" % d.name)
	info("%d tags, each buzzed" % n)
	m.queue_free()
	await U.frames(tree, 2)
