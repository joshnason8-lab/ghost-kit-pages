extends WsgOwnerNote
## The owner, 2026-11-02 (Floorball 0.9.2-beta).

const NOTE := {"id": "2026-11-02-goal-camera-joystick", "game": "floorball", "date": "2026-11-02", "version": "0.9.2-beta",
	"words": "If you switch to the camera view for from the angle of the goal the movement goes all wrong on the joystick."}

const Lib := preload("res://tests/note_lib.gd")


## Every camera the match has (the broadcast view, the high view, behind the goal), your player at the screen's centre,
## edges and corners, the stick pushed 8 ways: he goes the camera's way (WsgNoteChecks.joystick, within 25 degrees),
## through the game's own mapping (Match.joy()).
func check() -> void:
	var m: Node = await Lib.live_match(tree, {"home": "SWE", "away": "FIN", "venue": "hall", "user_team": 0, "seed": 4, "period": 4.0, "mode": "quick"})
	m.set_physics_process(false)
	if m.user_player == null:
		m._set_user(m.skaters(0)[0])
	var map := func(st: Vector2, _cam: Camera3D, at: Vector3) -> Vector3:
		m.user_player.pos = Vector2(at.x, at.z)
		m.touch.joystick = st
		m._ease_joy(1.0)
		var w: Vector2 = m.joy()
		return Vector3(w.x, 0.0, w.y)
	for mode in [Game.CAM_TV, Game.CAM_HIGH, Game.CAM_END]:
		m.cam.mode = mode
		for i in 90:
			await tree.process_frame
		var fails: Array = WsgNoteChecks.joystick(map, [m.cam])
		info("camera %d: %s" % [mode, "the stick's way at all 9 places, 8 ways" if fails.is_empty() else "%d faults" % fails.size()])
		for f in fails:
			fail("camera %d: %s" % [mode, f])
	m.touch.joystick = Vector2.ZERO
	m.cam.mode = Game.CAM_TV
	m.set_physics_process(true)
	await Lib.done(tree, m)
