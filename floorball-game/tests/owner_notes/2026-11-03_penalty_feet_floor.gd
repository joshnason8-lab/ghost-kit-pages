extends WsgOwnerNote
## The owner, 2026-11-03 (Floorball 0.9.6-beta).

const NOTE := {"id": "2026-11-03-penalty-feet-floor", "game": "floorball", "date": "2026-11-03", "version": "0.9.6-beta",
	"words": "Regression. the player on the penalty mini games feet are under the floor."}

const Lib := preload("res://tests/note_lib.gd")


## Penalty shots, at Low, Medium and High: through the walk in, the skate in, the shot and the pull-up after it, the
## shooter's and the goalkeeper's every ankle and toe at least at its standing height over the floor (FloorLegs: the
## legs bent where the game's pose on the shared rig's longer legs would put a foot through it), measured on the bodies
## as drawn.
func check() -> void:
	if not Lib.have_foundation():
		skip("no licensed clips here: the shared foundation's bodies are not drawn")
		return
	var keep: int = Game.settings.graphics
	for gfx in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = gfx
		var m: Node = (load(Lib.MATCH) as Script).new()
		m.config = {"home": "SWE", "away": "FIN", "venue": "arena", "user_team": 0, "mode": "practice", "practice": true, "period": 20.0, "seed": 3}
		Lib.host(tree).add_child(m)
		var worst := 0.0
		var before := 0.0
		var stages := {}
		for f in 60 * 12:
			var st := String(m._so.get("stage", ""))
			m.touch.joystick = Vector2(0, -1) if st == "run" else Vector2.ZERO
			if st == "run" and float(m._so.get("t", 0.0)) > 1.6 and not bool(m._so.get("shot", false)):
				m._on_action("SHOOT")
			await tree.process_frame
			for p in [m._so.get("shooter"), m.keeper(1)]:
				if p == null or not (p as Player).visible or (p as Player).link == null or (p as Player).link.floor_legs == null:
					continue
				var fl: FloorLegs = (p as Player).link.floor_legs
				worst = maxf(worst, fl.worst)
				before = maxf(before, fl.lacked)
				stages[st] = true
		info("graphics %d (%s): a foot under its standing height by at most %.3f m (the game's pose alone: %.3f m)" % [gfx, ", ".join(stages.keys()), worst, before])
		expect(worst < 0.01, "graphics %d: a foot %.3f m under the floor" % [gfx, worst])
		await Lib.done(tree, m)
	Game.settings.graphics = keep
