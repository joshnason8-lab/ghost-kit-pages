extends TakrawNote
## The owner, 2026-10-21: "No timesouts needed, they didn't work anyway."

const NOTE := {"id": "2026-10-21-no-timeouts", "game": "sepak-takraw", "date": "2026-10-21", "version": "0.1.0",
	"words": "No timesouts needed, they didn't work anyway."}


## A match you play has no time-out: no state for one, and no button or word for one on its screen or its pause menu.
func check() -> void:
	var m := make_match({"user_team": 0, "demo": false})
	await play(m, 5.0)
	var keys: Array = (m.S as Dictionary).keys().map(func(k): return String(k).to_lower())
	expect(not keys.any(func(k: String) -> bool: return k.contains("time")), "the match has a time-out state: %s" % str(keys))
	m.set_paused(true)
	await frame()
	var words := []
	for n in m.find_children("*", "", true, false):
		if n is Button:
			words.append((n as Button).text.to_lower())
		elif n is Label:
			words.append((n as Label).text.to_lower())
	var hit := words.filter(func(w: String) -> bool: return w.contains("time-out") or w.contains("timeout") or w.contains("time out"))
	info("%d words on the match's screen and pause menu; time-outs: %s" % [words.size(), str(hit)])
	expect(hit.is_empty(), "a time-out on the match's screen: %s" % str(hit))
	m.set_paused(false)
	await clean()
