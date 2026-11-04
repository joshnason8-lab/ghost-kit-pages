extends WsgOwnerNote
## The owner, 2026-10-29 (Floorball 0.8.2).

const NOTE := {"id": "2026-10-29-watch-ai-match", "game": "floorball", "date": "2026-10-29", "version": "0.8.2",
	"words": "Have a watch an AI match like the other games."}

const Lib := preload("res://tests/note_lib.gd")


## Watch a match, from its own screen's button: a match starts with nobody yours (both teams the AI's), and plays (the
## ball moves, the clock runs).
func check() -> void:
	Lib.host(tree)
	Game.show_screen("res://ui/quick_setup.gd", {"watch": true})
	await Lib.frames(tree, 3)
	var go: Button = null
	for b in Game.current.find_children("*", "Button", true, false):
		if (b as Button).text == tr("WATCH_GO"):
			go = b
	if not expect(go != null, "no Watch button on the Watch a match screen"):
		return
	go.pressed.emit()
	var guard := 0
	while (Game.current == null or Game.current.get_script().resource_path != Lib.MATCH or String(Game.current.phase) != "live") and guard < 60 * 30:
		await tree.process_frame
		guard += 1
	var m: Node = Game.current
	if not expect(m != null and m.get_script().resource_path == Lib.MATCH, "Watch did not start a match"):
		return
	var clock: float = m.rules.clock
	var b0: Vector2 = m.ball.floor_pos()
	# (Up to 15 s of play for the clock to run and the ball to move, not a fixed 5 s: the watched match is not seeded,
	# and one began with a stoppage - the clock 1 s on, the ball 0.8 m - in the first 5 s.)
	for i in 60 * 15:
		await tree.physics_frame
		if i >= 300 and float(m.rules.clock) != clock and m.ball.floor_pos().distance_to(b0) > 1.0:
			break
	info("watched: nobody yours (%d), the clock %.1f to %.1f s, the ball moved %.1f m" % [m.user_team, clock, m.rules.clock, m.ball.floor_pos().distance_to(b0)])
	expect(int(m.user_team) == -1, "the watched match has a team of yours")
	expect(float(m.rules.clock) != clock, "the watched match's clock does not run")
	expect(m.ball.floor_pos().distance_to(b0) > 1.0, "nothing moves in the watched match")
	await Lib.done(tree, m)
	Game.current = null
