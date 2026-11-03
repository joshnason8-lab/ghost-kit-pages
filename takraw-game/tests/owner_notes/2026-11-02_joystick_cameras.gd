extends TakrawNote
## The owner, 2026-11-02, for every game: "When switching to a camera angle that is not alongside the court the
## joystick movement is all wrong."

const NOTE := {"id": "2026-11-02-joystick-cameras", "game": "sepak-takraw", "date": "2026-11-02", "version": "0.14.3",
	"words": "When switching to a camera angle that is not alongside the court the joystick movement is all wrong."}


## At every venue, on each of the match's cameras (broadcast, side on, behind your end), with the player at the
## screen's centre, edges and corners, the stick pushed 8 ways moves him the camera's way (WsgNoteChecks.joystick, 25
## degrees) through the game's own mapping (CameraRig.stick_world: Match._cam_dir).
func check() -> void:
	var map := func(st: Vector2, cam: Camera3D, at: Vector3) -> Vector3: return CameraRig.stick_world(st, cam, at)
	for v in venues():
		var m := make_match({"venue": v, "user_team": 0, "demo": false})
		await frame()
		var cams := cameras(m)
		await frame()
		var fails := WsgNoteChecks.joystick(map, cams, 25.0)
		info("%s: %d cameras, %s" % [v, cams.size(), "the stick the camera's way on all" if fails.is_empty() else "%d faults" % fails.size()])
		for f in fails:
			fail("%s: %s" % [v, f])
		# And a world-fixed mapping (the fault) is caught on the end camera.
		var fixed := WsgNoteChecks.joystick(func(st: Vector2, _c: Camera3D, _a: Vector3) -> Vector3: return Vector3(st.x, 0, st.y), cams, 25.0)
		expect(fixed.any(func(f: String) -> bool: return f.contains("'end'")), "%s: the check did not catch a world-fixed stick on the end camera" % v)
	await clean()
