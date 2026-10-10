extends Node3D
## Every realistic body side by side, for checking new ones: full figure from the front, a raid stance from
## three quarters, the face, and the right hand gripping, one column per body in bodies.json.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 384x384 res://tests/body_gallery.tscn -- /out.png

const CELL := 384


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.16, 0.24)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-35), deg_to_rad(25), 0)
	add_child(light)
	var cam := Camera3D.new()
	add_child(cam)
	var bodies := RiggedBody.bodies()
	Game.settings.models = 1
	# state, celebration, camera fov, camera offset, look-at offset (from the feet, or the hand or head)
	var shots := [["idle", 0, 32.0, Vector3(0, 1.0, -4.4), Vector3(0, 0.95, 0), ""],
		["raid", 0, 32.0, Vector3(2.6, 1.3, -3.2), Vector3(0, 0.8, 0), ""],
		["idle", 0, 22.0, Vector3(0.25, 0.05, -1.0), Vector3.ZERO, "head"],
		["holding", 0, 30.0, Vector3(0.35, 0.1, -0.55), Vector3.ZERO, "hand_r"]]
	var sheet := Image.create(CELL * bodies.size(), CELL * shots.size(), false, Image.FORMAT_RGB8)
	for b in bodies.size():
		var data: Dictionary = DB.team("MUM").squad[b].duplicate(true)
		data["body"] = String(bodies[b].file)
		# The skin tone the game would give this body (it picks bodies by tone).
		var sk: Array = bodies[b].get("skin", [0.75, 0.55, 0.42])
		var lum := Color(float(sk[0]), float(sk[1]), float(sk[2])).get_luminance()
		var best := 0
		for t in DB.SKIN_TONES.size():
			if absf(Color(DB.SKIN_TONES[t]).get_luminance() - lum) < absf(Color(DB.SKIN_TONES[best]).get_luminance() - lum):
				best = t
		data["skin"] = best
		var team := 2 if String(bodies[b].kind) == "referee" else 0
		var a := Athlete.new()
		a.setup(data, team, Color("12a4a7"), Color("f3efe6"), true)
		add_child(a)
		a.facing = Vector3(0, 0, -1)
		for i in shots.size():
			var s: Array = shots[i]
			a.cele_kind = s[1]
			a.set_state(s[0], 1000.0)
			a.st_t = 500.0
			for k in 40:
				await get_tree().process_frame
			var target: Vector3 = a.global_position + s[4]
			var rig: RiggedBody = a.model.rig
			if s[5] != "" and rig and rig._bone.has(s[5]):
				target = rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(rig._bone[s[5]]).origin
				if s[5] == "head":
					target += Vector3(0, 0.08, 0)
			cam.fov = s[2]
			cam.position = target + s[3]
			cam.look_at(target)
			for k in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(CELL, CELL)
			sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i(b * CELL, i * CELL))
		a.queue_free()
		await get_tree().process_frame
	sheet.save_png(out)
	get_tree().quit()
