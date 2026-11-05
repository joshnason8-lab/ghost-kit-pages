extends TakrawNote
## The owner, 2026-10-25: "there are 2 dots in the score, is that for timeouts? If so remove them if we're not doing
## timeouts."

const NOTE := {"id": "2026-10-25-score-dots", "game": "sepak-takraw", "date": "2026-10-25", "version": "0.9.1",
	"words": "there are 2 dots in the score, is that for timeouts? If so remove them if we’re not doing timeouts."}


## The scoreboard of a best-of-three match, from the start and after a set: each side's name, points and sets won in
## words - no dots or other marks in it.
func check() -> void:
	var m := make_match({"sets": 3, "points": 15, "seed": 2})
	await play(m, 600.0, func(mm: Node):
		if (mm.get("set_scores") as Array).size() >= 1:
			mm.set_meta("note_done", true))
	await frame()
	var marks := 0
	for s in m.hud.get("_score_l"):
		var d: Dictionary = s
		var panel: Node = d.panel
		# (Its marks: the crest, and the ball by the side that serves. Anything else drawn small is a dot.)
		for n in panel.find_children("*", "Control", true, false):
			if n == d.crest or n == d.serve or (d.crest as Node).is_ancestor_of(n) or (d.serve as Node).is_ancestor_of(n):
				continue
			if (n is TextureRect or n is ColorRect or n is Panel) and (n as Control).is_visible_in_tree() and (n as Control).size.x < 24.0:
				marks += 1
		for c in (d.sets as Node).get_children():
			if not c is Label:
				marks += 1
	info("after %d set(s): %d dots or marks in the scoreboard" % [(m.get("set_scores") as Array).size(), marks])
	expect(marks == 0, "%d dots or marks in the scoreboard" % marks)
	await clean()
