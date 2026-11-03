extends WsgOwnerNote
## The owner (relayed by the lead), 2026-11-02, on 0.8.4-beta.

const NOTE := {"id": "2026-11-02-joystick-cameras", "game": "netball", "date": "2026-11-02", "version": "0.8.4-beta",
	"words": "When switching to a camera angle that is not alongside the court, the joystick movement is all wrong."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")
const TOL := 10.0     # degrees on the screen
## WsgNoteChecks.joystick's bound for this game: it compares on the FLOOR against the camera's flat forward (or the
## way from the camera to the body), so on a perspective camera looking down a diagonal stick that is exactly right on
## the screen measures 26-39 degrees off it at the screen's edges (measured with a screen-exact mapping, 2026-11-03);
## a world-fixed mapping, the owner's fault, measures 90-180. 45 tells them apart; TOL holds the screen itself.
const WAY_TOL := 45.0


## The game's own mapping (CameraRig.court_dir: the stick's screen way laid onto the floor through the lens) on every
## camera the game has - the broadcast (TV), courtside (Low), and behind each goal (End, both ends) - each with the
## play at the left end, the middle, the right end and toward either side line (the camera follows the ball): with the
## body at the screen's centre, edges and corners, the stick pushed 8 ways goes the camera's way (WsgNoteChecks.joystick
## within WAY_TOL: a mapping fixed to the court fails it on every camera), and goes that way ON THE SCREEN within TOL (the body's step projected back through the
## camera: what the owner sees), at 16:9 and 20:9. Then in real matches with your thumb on the stick (test_runner _stick_camera: your
## player moved up, right, down, left on the TV, Low and both End cameras, and a camera cut easing the stick's way).
func check() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1600, 720)]:
		await _screen(size)
	# Real matches, your thumb on the stick, on each camera.
	var h: Node = await Harness.make(tree)
	await h._stick_camera()
	await Harness.into(self, h)


## At one screen shape (16:9, and 20:9 as the owner's Galaxy A16).
func _screen(size: Vector2i) -> void:
	var sv := SubViewport.new()
	sv.size = size
	tree.root.add_child(sv)
	var world := Node3D.new()
	sv.add_child(world)
	var rig := CameraRig.new()
	world.add_child(rig)
	await frame()
	var map := func(st: Vector2, _cam: Camera3D, at: Vector3) -> Vector3:
		var d: Vector2 = rig.court_dir(st, at)
		return Vector3(d.x, 0.0, d.y)
	var cams := [["TV", Game.CAM_TV, 1], ["Low", Game.CAM_LOW, 1], ["End (+x goal)", Game.CAM_END, 1], ["End (-x goal)", Game.CAM_END, -1]]
	var plays := [["play left", Vector2(-12.0, 0.0), -1], ["play centre", Vector2.ZERO, 1], ["play right", Vector2(12.0, 0.0), 1],
		["play near side", Vector2(4.0, 6.0), 1], ["play far side", Vector2(-4.0, -6.0), -1]]
	var spots := [Vector2(0.5, 0.5), Vector2(0.5, 0.1), Vector2(0.5, 0.9), Vector2(0.1, 0.5), Vector2(0.9, 0.5),
		Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.1, 0.9), Vector2(0.9, 0.9)]
	var sticks := [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for c: Array in cams:
		var worst_screen := 0.0
		var worst_what := ""
		for pl: Array in plays:
			rig.set_mode(int(c[1]))
			rig.end_dir = int(c[2])
			rig.track(pl[1], int(pl[2]), 1.0 / 30.0, true)
			rig.name = "%s, %s, %dx%d" % [c[0], pl[0], size.x, size.y]
			for f in WsgNoteChecks.joystick(map, [rig], WAY_TOL):
				fail(f)
			# On the screen: the body at each spot, a step along the mapping, projected back.
			for sp: Vector2 in spots:
				var px := sp * Vector2(sv.size)
				var o := rig.project_ray_origin(px)
				var d := rig.project_ray_normal(px)
				if d.y > -1e-3:
					continue
				var at := o + d * (-o.y / d.y)
				for st: Vector2 in sticks:
					var w: Vector3 = map.call(st, rig, at)
					if w.length() < 1e-4:
						fail("camera '%s': the stick %s does not move the body at %s" % [rig.name, st, sp])
						continue
					var moved := rig.unproject_position(at + w.normalized() * 0.3) - rig.unproject_position(at)
					var off := rad_to_deg(absf(angle_difference(moved.angle(), st.angle())))
					if off > worst_screen:
						worst_screen = off
						worst_what = "%s, the body at %s, stick %s" % [pl[0], sp, st]
		info("%dx%d, %s: on the screen %.1f deg off the stick at worst (%s)" % [size.x, size.y, c[0], worst_screen, worst_what])
		expect(worst_screen <= TOL, "%dx%d, camera %s: the body goes %.1f deg off the stick's way on the screen (%s)" % [size.x, size.y,
			c[0], worst_screen, worst_what])
	sv.queue_free()
	await frame()
