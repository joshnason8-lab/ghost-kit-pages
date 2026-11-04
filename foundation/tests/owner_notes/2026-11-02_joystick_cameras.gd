extends WsgOwnerNote
## The owner, 2026-11-02 (every game): "When switching to a camera angle that is not alongside the court the joystick movement is all wrong."

const NOTE := {"id": "2026-11-02-joystick-cameras", "game": "all", "date": "2026-11-02", "version": "every game", "words": "When switching to a camera angle that is not alongside the court the joystick movement is all wrong."}

## On every kind of camera a game has - alongside, high broadcast, end-on behind a goal, overhead (turned), from a
## corner, low behind the player - and with the body at the screen's centre, edges and corners, the stick pushed 8 ways
## moves the body the camera's way (WsgNoteChecks.stick_world, the mapping the games use or are checked against). And
## the check sees the fault the owner saw: a mapping fixed to the world (up the stick = up the court) fails it on every
## camera not alongside the court (end-on, overhead, corner, behind the player).
func check() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	tree.root.add_child(sv)
	var world := Node3D.new()
	sv.add_child(world)
	var cams := []
	for c in [["alongside", Vector3(0, 6, 22), Vector3(0, 0, 0)], ["broadcast high", Vector3(-4, 18, 30), Vector3(0, 0, 0)],
			["end-on", Vector3(-30, 5, 0), Vector3(0, 0, 0)], ["overhead", Vector3(0, 35, 0.01), Vector3(0, 0, 0)],
			["corner", Vector3(-22, 9, 18), Vector3(0, 0, 0)], ["behind the player", Vector3(3, 2.2, -8), Vector3(3, 1, 4)]]:
		var cam := Camera3D.new()
		cam.name = c[0]
		world.add_child(cam)
		cam.look_at_from_position(c[1], c[2], Vector3.UP if c[0] != "overhead" else Vector3.RIGHT)
		cams.append(cam)
	await frame()
	var fails_ok := WsgNoteChecks.joystick(func(st: Vector2, cam: Camera3D, at: Vector3) -> Vector3: return WsgNoteChecks.stick_world(st, cam, at), cams, 5.0)
	for f in fails_ok:
		fail(f)
	info("stick_world on %d cameras, 9 places on the screen, 8 ways: %s" % [cams.size(), "all on the camera's way" if fails_ok.is_empty() else "%d faults" % fails_ok.size()])
	var fixed := WsgNoteChecks.joystick(func(st: Vector2, _cam: Camera3D, _at: Vector3) -> Vector3: return Vector3(st.x, 0, st.y), cams)
	var caught := ", ".join(fixed.map(func(f: String) -> String: return f.get_slice("'", 1)))
	info("a mapping fixed to the world (the fault): caught on %s" % caught)
	for n in ["end-on", "overhead", "corner", "behind the player"]:
		expect(caught.contains(n), "the joystick check did not catch a world-fixed mapping on the %s camera" % n)
	# (Alongside and the high broadcast view - 7 degrees off alongside - a world-fixed mapping is right, as the owner found.)
	expect(not caught.contains("alongside") and not caught.contains("broadcast"), "the check failed a world-fixed mapping on an alongside camera, where it is right")
	sv.queue_free()
