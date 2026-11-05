extends TakrawNote
## The owner, 2026-10-22: "No need to have the numbers over the characters in game its just in the way."

const NOTE := {"id": "2026-10-22-numbers-over-players", "game": "sepak-takraw", "date": "2026-10-22", "version": "0.3.0",
	"words": "No need to have the numbers over the characters in game its just in the way."}


## In a match you play and one you watch: nothing written over the players - no 3D label or sprite on any player, and
## no label on the screen that follows one.
func check() -> void:
	for cfg in [{"user_team": 0, "demo": false}, {"user_team": -1}]:
		var m := make_match(cfg)
		await play(m, 10.0)
		var over := 0
		for side in 2:
			for pp in m.players_on(side):
				over += (pp as Node).find_children("*", "Label3D", true, false).size()
				over += (pp as Node).find_children("*", "Sprite3D", true, false).size()
		var nums := 0
		for l in m.hud.find_children("*", "Label", true, false):
			var t := (l as Label).text.strip_edges()
			if t.is_valid_int() and l.get_parent() and not _in_score(m, l):
				nums += 1
		info("%s: %d labels over the players, %d numbers on the screen outside the score" % ["you play" if cfg.user_team == 0 else "watched", over, nums])
		expect(over == 0, "%d labels or sprites over the players" % over)
		m.queue_free()
		await frame()
	await clean()


## Whether label L is part of the scoreboard (its points and sets are numbers, rightly).
static func _in_score(m: Node, l: Node) -> bool:
	for s in m.hud.get("_score_l"):
		if (s as Dictionary).get("panel") and (s.panel as Node).is_ancestor_of(l):
			return true
	return false
