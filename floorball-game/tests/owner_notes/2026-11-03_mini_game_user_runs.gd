extends WsgOwnerNote
## The owner, 2026-11-03 (Floorball 0.9.6-beta).

const NOTE := {"id": "2026-11-03-mini-game-user-runs", "game": "floorball", "date": "2026-11-03", "version": "0.9.6-beta",
	"words": "MIni game have the user run, don't have the player automatically run toward the goal. That happens and I do nothing and the player plays on his own."}

const Lib := preload("res://tests/note_lib.gd")


## Penalty shots with the joystick left alone: the shooter does not move toward the goal (under 1 m over the shot's
## time), takes no shot of his own, and the shot ends (the ball must keep moving: stood still, it is over). Then pushed
## up, he skates in.
func check() -> void:
	var m: Node = (load(Lib.MATCH) as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": "arena", "user_team": 0, "mode": "practice", "practice": true, "period": 20.0, "seed": 7}
	Lib.host(tree).add_child(m)
	var start_x := INF
	var moved := 0.0
	var ended := false
	var shots_by_him := 0
	for f in 60 * 8:
		m.touch.joystick = Vector2.ZERO
		await tree.physics_frame
		var sh: Player = m._so.get("shooter")
		if String(m._so.get("stage", "")) == "run" and sh:
			if start_x == INF:
				start_x = sh.pos.x
			moved = maxf(moved, absf(sh.pos.x - start_x))
			if bool(m._so.get("shot", false)):
				shots_by_him += 1
		if start_x != INF and int(m._practice.get("shot", 0)) >= 1:
			ended = true
			break
	info("left alone: moved %.2f m toward the goal, %s" % [moved, "the shot over" if ended else "the shot still going"])
	expect(start_x != INF, "the shot never started")
	expect(moved < 1.0, "left alone, the shooter skated %.1f m in on his own" % moved)
	expect(shots_by_him == 0, "left alone, the shooter shot on his own")
	expect(ended, "left alone, the shot never ended")
	# Pushed up: he goes in.
	var x0 := INF
	var x1 := 0.0
	for f in 60 * 6:
		var st := String(m._so.get("stage", ""))
		m.touch.joystick = Vector2(0, -1) if st == "run" else Vector2.ZERO
		await tree.physics_frame
		var sh: Player = m._so.get("shooter")
		if st == "run" and sh:
			if x0 == INF:
				x0 = sh.pos.x
			x1 = maxf(x1, absf(sh.pos.x - x0))
	info("the joystick up: skated %.1f m in" % x1)
	expect(x1 > 5.0, "the joystick up: he skated only %.1f m in" % x1)
	await Lib.done(tree, m)
