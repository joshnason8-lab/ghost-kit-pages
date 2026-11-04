extends WsgOwnerNote
## The owner, 2026-11-02 (Kho Kho Rush 0.11.1): "When changing to the pole view the joystick movement is wrong."

const NOTE := {"id": "2026-11-02-pole-view-joystick", "game": "kho-kho", "date": "2026-11-02", "version": "Kho Kho Rush 0.11.1", "words": "When changing to the pole view the joystick movement is wrong."}
const KK := preload("res://tests/note_kk.gd")


## Every camera (the broadcast, the close one, behind the pole), the stick pushed 8 ways with the body at 9 places on
## the screen: the body goes the way the stick points, as the screen shows it (WsgNoteChecks.joystick, within 25 deg).
func check() -> void:
	var m: Node = await KK.play(tree)
	var cams: Array = []
	for mode in [Game.CAM_TV, Game.CAM_CLOSE, Game.CAM_POLE]:
		m._cam_mode = mode
		for i in 12:
			m._camera(1.0 / 30.0)
			await frame()
		var c := Camera3D.new()
		c.name = ["broadcast", "close", "behind the pole"][mode]
		c.fov = m.cam.fov
		tree.root.add_child(c)
		c.global_transform = m.cam.global_transform
		cams.append(c)
	var map := func(st: Vector2, cam: Camera3D, at: Vector3) -> Vector3:
		var ax: Array = KK.MatchScript.stick_map_at(cam, at)
		var w: Vector2 = (ax[0] as Vector2) * st.x + (ax[1] as Vector2) * st.y
		return Vector3(w.x, 0.0, w.y)
	for f in WsgNoteChecks.joystick(map, cams):
		fail(f)
	for c in cams:
		c.queue_free()
	await KK.done(tree, m)
