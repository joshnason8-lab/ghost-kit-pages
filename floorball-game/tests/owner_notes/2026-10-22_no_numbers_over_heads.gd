extends WsgOwnerNote
## The owner, 2026-10-22 (Floorball 0.1).

const NOTE := {"id": "2026-10-22-no-numbers-over-heads", "game": "floorball", "date": "2026-10-22", "version": "0.1",
	"words": "No need for the number of the player over the heads."}

const Lib := preload("res://tests/note_lib.gd")


## A match you play and a match you watch: no text over any player's head that is a number or a name - only your
## own player's small marker arrow.
func check() -> void:
	for user in [0, -1]:
		var m: Node = await Lib.live_match(tree, {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": user, "demo": user < 0, "seed": 4, "period": 4.0, "mode": "quick"})
		var labels := []
		for p: Player in m.everyone():
			for l in p.find_children("*", "Label3D", true, false):
				var t := String((l as Label3D).text).strip_edges()
				if t != "" and t != "▼" and (l as Label3D).is_visible_in_tree():
					labels.append(t)
		info("%s: text over heads %s" % ["your match" if user == 0 else "a match watched", labels if not labels.is_empty() else "none (your marker only)"])
		expect(labels.is_empty(), "text over players' heads: %s" % [labels])
		await Lib.done(tree, m)
