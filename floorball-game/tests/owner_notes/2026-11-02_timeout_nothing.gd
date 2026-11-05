extends WsgOwnerNote
## The owner, 2026-11-02 (Floorball 0.9.2-beta). (Answered 2026-11-03 by removing it: "Just get rid of the time out
## since it does nothing.")

const NOTE := {"id": "2026-11-02-timeout-nothing", "game": "floorball", "date": "2026-11-02", "version": "0.9.2-beta",
	"words": "Click timeout pretty much does nothing."}

const Lib := preload("res://tests/note_lib.gd")


## No time-out button that does nothing: none in the pause menu, nothing in the match to call.
func check() -> void:
	var m: Node = await Lib.live_match(tree, {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": 0, "seed": 4, "period": 4.0, "mode": "quick"})
	m.set_paused(true)
	await Lib.frames(tree, 2)
	var found := []
	for b in m.hud.find_children("*", "Button", true, false):
		var t := String((b as Button).text).to_lower()
		if t.contains("time-out") or t.contains("timeout"):
			found.append(t)
	m.set_paused(false)
	expect(found.is_empty(), "the pause menu has a time-out button: %s" % [found])
	expect(not m.has_method("call_timeout"), "the match still answers a time-out call")
	await Lib.done(tree, m)
