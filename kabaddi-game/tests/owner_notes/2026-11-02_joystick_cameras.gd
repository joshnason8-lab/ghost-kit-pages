extends WsgOwnerNote
const NOTE := {"id": "2026-11-02-joystick-cameras", "game": "kabaddi", "date": "2026-11-02", "version": "0.14.0-beta",
	"words": "the joystick doesn't go the way you push it (the lead's record; fixed in 0.14.1: up the stick is up the screen where the player stands, every camera)"}
const U := preload("res://tests/owner_note_util.gd")


## The stick pushed eight ways with the player at nine places on the screen, on each of the game's cameras (behind the
## player, broadcast), as the match sets them: camera-relative within 25 degrees.
func check() -> void:
	var m: Node = U.start(tree, {"first_raider": 0, "passive": true})
	await U.until_raid(tree, m)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	tree.root.add_child(vp)
	var cams := []
	for mode in [Game.CAM_THIRD, Game.CAM_TV]:
		m.cam.mode = mode
		for i in 45:
			m.cam.follow(m, 1.0 / 30.0)
		var c := Camera3D.new()
		c.fov = m.cam.cam.fov
		vp.add_child(c)
		c.global_transform = m.cam.cam.global_transform
		cams.append(c)
	await tree.process_frame
	for f in WsgNoteChecks.joystick(Callable(CameraRig, "stick_to_world"), cams):
		fail(f)
	info("%d cameras, 8 ways at 9 places each" % cams.size())
	vp.queue_free()
	m.queue_free()
	await U.frames(tree, 2)
