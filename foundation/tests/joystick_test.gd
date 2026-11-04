extends SceneTree
## WsgNoteChecks.joystick's references: the camera's flat way (stick_world), the camera-to-body way and the
## screen-true way (Sepak Takraw's ray mapping: the stick's direction on the screen where the body is drawn, met with
## the floor) all pass on every kind of camera; a mapping fixed to the world still fails on every camera not
## alongside the court.
##   godot --headless --path . -s tests/joystick_test.gd


func _initialize() -> void:
	await process_frame
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	root.add_child(sv)
	var cams := []
	for c in [["alongside", Vector3(0, 6, 22), Vector3.ZERO], ["broadcast high", Vector3(-4, 18, 30), Vector3.ZERO],
			["end-on", Vector3(-30, 5, 0), Vector3.ZERO], ["overhead", Vector3(0, 35, 0.01), Vector3.ZERO],
			["corner", Vector3(-22, 9, 18), Vector3.ZERO], ["behind the player", Vector3(3, 2.2, -8), Vector3(3, 1, 4)]]:
		var cam := Camera3D.new()
		cam.name = c[0]
		sv.add_child(cam)
		cam.look_at_from_position(c[1], c[2], Vector3.UP if c[0] != "overhead" else Vector3.RIGHT)
		cams.append(cam)
	await process_frame
	var fails := []
	# The ray mapping: where the stick points on the screen, from where the body is drawn, met with the floor.
	var ray := func(st: Vector2, cam: Camera3D, at: Vector3) -> Vector3:
		var sp := cam.unproject_position(at) + st.normalized() * 40.0
		var o := cam.project_ray_origin(sp)
		var d := cam.project_ray_normal(sp)
		if d.y > -1e-3:
			return WsgNoteChecks.stick_world(st, cam, at)
		var p := o + d * ((0.0 - o.y) / d.y)
		return Vector3(p.x - at.x, 0, p.z - at.z).normalized()
	var r := WsgNoteChecks.joystick(ray, cams)
	print("the ray (screen-true) mapping: %s" % ("passes on all 6 cameras" if r.is_empty() else str(r)))
	if not r.is_empty():
		fails.append("the screen-true mapping fails: %s" % [r])
	var s := WsgNoteChecks.joystick(func(st: Vector2, cam: Camera3D, at: Vector3) -> Vector3: return WsgNoteChecks.stick_world(st, cam, at), cams)
	print("stick_world: %s" % ("passes on all 6 cameras" if s.is_empty() else str(s)))
	if not s.is_empty():
		fails.append("stick_world fails: %s" % [s])
	var fixed := WsgNoteChecks.joystick(func(st: Vector2, _c: Camera3D, _a: Vector3) -> Vector3: return Vector3(st.x, 0, st.y), cams)
	var caught := ", ".join(fixed.map(func(f: String) -> String: return f.get_slice("'", 1)))
	print("a world-fixed mapping: caught on %s" % caught)
	for n in ["end-on", "overhead", "corner", "behind the player"]:
		if not caught.contains(n):
			fails.append("a world-fixed mapping passes on the %s camera" % n)
	print("JOYSTICK TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)
