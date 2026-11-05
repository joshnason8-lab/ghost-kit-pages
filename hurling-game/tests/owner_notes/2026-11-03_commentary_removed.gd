extends WsgOwnerNote
## The owner, 2026-11-03 (Hurling 0.20.0): "Remove the commentary. We'll try it in a later iteration of the game."

const NOTE := {"id": "2026-11-03-commentary-removed", "game": "hurling", "date": "2026-11-03", "version": "Hurling 0.20.0", "words": "Remove the commentary. We'll try it in a later iteration of the game."}
const Kit := preload("res://tests/note_kit.gd")

## Off everywhere until the owner asks for it again: the switch is off, and a watched match, a quick match and the
## championship's have no commentators.
func check() -> void:
	var c: Dictionary = (load("res://game/match.gd") as Script).get_script_constant_map()
	expect(not bool(c.get("COMMENTARY", true)), "Match.COMMENTARY is on")
	for mode in ["watch", "quick", "championship"]:
		var m: Node = load("res://game/match.gd").new()
		m.config = {"home": "GAL", "away": "LIM", "venue": "county", "user_team": -1 if mode == "watch" else 0, "seed": 2, "length": 4.0, "mode": mode}
		tree.root.add_child(m)
		await Kit.frames(tree, 5)
		expect(m.commentary == null, "a %s match has the commentators" % mode)
		await Kit.done(tree, m)
