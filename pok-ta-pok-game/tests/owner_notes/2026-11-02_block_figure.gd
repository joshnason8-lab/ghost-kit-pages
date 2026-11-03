extends WsgOwnerNote
## The owner, 2026-11-02 (Pok Ta Pok 0.6.0 on the A16): "the man doing the smoke ritual looks like a block figure"

const NOTE := {"id": "2026-11-02-block-figure", "game": "pok-ta-pok", "date": "2026-11-02", "version": "Pok Ta Pok 0.6.0 on the A16", "words": "the man doing the smoke ritual looks like a block figure"}


## The copal elder on the stone court, at every graphics level, through his offering: a skinned body, no primitive
## shapes standing in for him (WsgNoteChecks.block_figure), and he moves (walks from player to player).
func check() -> void:
	var keep := int(Game.settings.graphics)
	Game.settings.sound = false
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		var m: Node = (load("res://game/match.gd") as Script).new()
		m.config = {"home": "PIS", "away": "VAL", "venue": "stone", "rules": "classic", "user_team": -1, "seed": 2, "length": 0.0,
			"mode": "test", "difficulty": 1, "ritual": true}
		tree.root.add_child(m)
		for i in 3:
			await frame()
		if m.ritual == null:
			fail("level %d: no copal offering on the stone court" % g)
			m.queue_free()
			continue
		var elder: Node3D = m.ritual.elder
		var from := elder.global_position
		var worst := ""
		for i in 120:
			await frame()
			if m.ritual.done:
				break
			if i % 20 == 0:
				var b := WsgNoteChecks.block_figure(elder)
				if b != "" and worst == "":
					worst = b
		expect(worst == "", "level %d: the elder %s" % [g, worst])
		expect(elder.global_position.distance_to(from) > 0.5, "level %d: the elder never walks" % g)
		info("level %d: the elder skinned, walked %.1f m" % [g, elder.global_position.distance_to(from)])
		m.queue_free()
		await frame()
	Game.settings.graphics = keep
