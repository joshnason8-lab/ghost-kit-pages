extends Node3D
## Strips of the body in motion, for checking gaits, celebrations and officials' signals.
## Each row is one motion; columns are moments a few frames apart.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/motion_view.tscn -- /out/dir

const ROWS := [
	# [label, state, velocity in the body's frame (x right, z forward), extra]
	["run", "idle", Vector3(0, 0, 5.0), {}],
	["jog", "ready", Vector3(0, 0, 2.2), {}],
	["shuffle", "ready", Vector3(2.4, 0, 0), {}],
	["backpedal", "ready", Vector3(0, 0, -2.0), {}],
	["sit", "sit", Vector3.ZERO, {}],
	["fist", "celebrate", Vector3.ZERO, {"cele": 1}],
	["clap", "celebrate", Vector3.ZERO, {"cele": 2}],
	["point", "celebrate", Vector3.ZERO, {"cele": 4}],
	["sig_points", "signal", Vector3.ZERO, {"sig": 1}],
	["sig_bonus", "signal", Vector3.ZERO, {"sig": 2}],
	["sig_timeout", "signal", Vector3.ZERO, {"sig": 5}],
	["sig_end", "signal", Vector3.ZERO, {"sig": 7}],
]

var _athletes := []


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.16, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	add_child(env)
	var l := DirectionalLight3D.new()
	l.rotation = Vector3(deg_to_rad(-35), deg_to_rad(25), 0)
	add_child(l)
	var cam := Camera3D.new()
	cam.fov = 40
	add_child(cam)
	for r in ROWS:
		# Five copies at different moments of the cycle, viewed side-on.
		var row := []
		for k in 5:
			var a := Athlete.new()
			a.setup(DB.team("MUM").squad[0], 0, Color("12a4a7"), Color("f3efe6"), true)
			add_child(a)
			a.position = Vector3(k * 1.5 - 3.0, 0, 0)
			a.facing = Vector3(-1, 0, 0) if not (r[0] in ["shuffle", "fist", "clap", "point"] or r[1] == "signal") else Vector3(0, 0, 1)
			a.lock_facing = true
			a.set_state(r[1], 1000.0)
			a.cele_kind = int(r[3].get("cele", 0))
			a.sig_kind = int(r[3].get("sig", 0))
			var right := a.facing.cross(Vector3.UP)
			a.vel = right * r[2].x + a.facing * r[2].z
			a.set_process(false)
			row.append(a)
		# Warm each copy up to its own moment.
		for k in 5:
			var a: Athlete = row[k]
			for f in 30 + k * 4:
				a.st_t += 1.0 / 30.0
				a._pose(1.0 / 30.0)
				a.model._process(1.0 / 30.0)
			a.rotation.y = atan2(-a.facing.x, -a.facing.z)
		cam.position = Vector3(0, 1.0, 9.0)
		cam.look_at(Vector3(0, 0.9, 0))
		for f in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/motion_" + r[0] + ".png")
		for a in row:
			a.queue_free()
		await get_tree().process_frame
	get_tree().quit()
