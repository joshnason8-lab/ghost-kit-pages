extends WsgOwnerNote
## The owner, 2026-11-03 (Floorball 0.9.6-beta).

const NOTE := {"id": "2026-11-03-remove-timeout", "game": "floorball", "date": "2026-11-03", "version": "0.9.6-beta",
	"words": "Just get rid of the time out since it does nothing."}

const Lib := preload("res://tests/note_lib.gd")


## No time-out anywhere: the match has none to call, the pause menu offers none (in every language's words for it),
## the AI's coach calls none in a whole match played out.
func check() -> void:
	var m: Node = await Lib.live_match(tree, {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": 0, "seed": 4, "period": 4.0, "mode": "quick"})
	expect(not m.has_method("call_timeout") and not m.has_method("_take_timeout"), "the match still has a time-out to call")
	m.set_paused(true)
	await Lib.frames(tree, 2)
	var words := []
	for b in m.hud.find_children("*", "Button", true, false):
		words.append((b as Button).text)
	m.set_paused(false)
	info("the pause menu: %s" % [words])
	for w in words:
		expect(not String(w).to_lower().contains("time-out") and not String(w).to_lower().contains("timeout"), "the pause menu offers '%s'" % w)
	var logged := 0
	for e: Dictionary in m.rules.log:
		if String(e.get("kind", "")) == "timeout":
			logged += 1
	expect(logged == 0, "a time-out was taken")
	await Lib.done(tree, m)
