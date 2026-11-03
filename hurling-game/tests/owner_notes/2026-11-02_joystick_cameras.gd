extends WsgOwnerNote
## The owner, 2026-11-02 (every game (Hurling 0.20)): "When switching to a camera angle that is not alongside the court the joystick movement is all wrong."

const NOTE := {"id": "2026-11-02-joystick-cameras", "game": "hurling", "date": "2026-11-02", "version": "every game (Hurling 0.20)", "words": "When switching to a camera angle that is not alongside the court the joystick movement is all wrong."}
const Kit := preload("res://tests/note_kit.gd")

## Hurling's own stick mapping (Match._cam_dir) on every camera it has - the broadcast, the high one, behind the goal -
## and two more (overhead, turned; low behind a player): pushed 8 ways with the man at 9 places on the screen, he goes
## the camera's way (WsgNoteChecks.joystick, within 25 degrees).
func check() -> void:
	var m: Node = await Kit.match(tree, {"mode": "quick", "user_team": 0, "seed": 3}, 10)
	m.set_process(false)
	var cams := []
	for c in [["broadcast", Game.CAM_TV], ["high", Game.CAM_HIGH], ["behind the goal", Game.CAM_END]]:
		m.cam.mode = c[1]
		m.cam.snap(m)
		var cam := Camera3D.new()
		cam.name = c[0]
		m.add_child(cam)
		cam.global_transform = m.cam.camera.global_transform
		cam.fov = m.cam.camera.fov
		cams.append(cam)
	for c in [["overhead, turned", Vector3(0, 35, 0), Vector3(0, 0, 0.01)], ["behind a player", Vector3(-10, 2.2, 3), Vector3(5, 1, 0)]]:
		var cam := Camera3D.new()
		cam.name = c[0]
		m.add_child(cam)
		cam.look_at_from_position(c[1], c[2], Vector3.UP if c[0] != "overhead, turned" else Vector3(1, 0, 1).normalized())
		cams.append(cam)
	var map := func(st: Vector2, cam: Camera3D, at: Vector3) -> Vector3:
		cam.make_current()
		m._stick_off = 0.0
		m._stick_t = 1.0
		return m._cam_dir(st, at)
	await Kit.frames(tree, 1)
	var fs := WsgNoteChecks.joystick(map, cams)
	for f in fs:
		fail(f)
	info("%d cameras, 9 places, 8 ways: %s" % [cams.size(), "all the camera's way" if fs.is_empty() else "%d faults" % fs.size()])
	await Kit.done(tree, m)
