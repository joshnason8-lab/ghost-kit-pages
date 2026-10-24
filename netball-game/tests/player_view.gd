extends Node3D
## The players' model up close (game/hero_body.gd), saved as PNGs for checking by eye:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/player_view.tscn -- OUT_DIR [graphics 0-2]
## lineup.png: a player of each of four teams from the front, the back and the side, standing ready, holding the
## ball, catching high (close1.png, close2.png: nearer); run_<speed>.png: one stride pair of the run at walking,
## jogging and sprinting speeds in eight stills, the clips as the match lays them over her pose.
## With "moves" after the graphics level: the motion-capture moves as the match plays them (move_*.png: the side-step
## marking and leading, the landing from a jog and a sprint); with "clips:a,b" the stored clips themselves (clip_*.png).

const TEAMS := ["AUS", "ENG", "NZL", "MWI"]


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "user://player_view"
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = int(a[1]) if a.size() > 1 else Game.GFX_HIGH
	ToonBody.material(int(Game.settings.graphics) > Game.GFX_LOW)
	get_tree().root.size = Vector2i(1920, 1080)
	if a.size() > 2 and String(a[2]).begins_with("clips:"):
		_backdrop()
		for c in String(a[2]).substr(6).split(","):
			await _raw_strip(out, c)
		get_tree().quit()
		return
	if a.size() > 2 and String(a[2]) == "moves":
		_backdrop()
		await _moves(out)
		get_tree().quit()
		return
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("3b6f8f")
	env.environment = e
	add_child(env)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("c9a46c")
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mesh.material_override = fm
	add_child(floor_mesh)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 34
	# The lineup: four teams, each seen from the front, the back and the side, then holding and catching.
	var ps := []
	var x := -8.4
	for ti in TEAMS.size():
		var sq: Array = DB.squad(TEAMS[ti])
		for v in 4:
			var pl := Player.new(0, sq[(ti * 2 + v) % 7], ToonBody.LETTERS[(ti * 2 + v) % 7])
			add_child(pl)
			pl.position = Vector3(x, 0, 0)
			pl.rotation.y = [0.0, PI, PI * 0.5, 0.3][v]
			x += 1.1
			ps.append(pl)
	await get_tree().process_frame
	for i in ps.size():
		var pl: Player = ps[i]
		var pose: Dictionary = [Poses.ready(0.9), Poses.ready(0.9), Poses.ready(0.9), Poses.hold() if i % 8 == 3 else Poses.catch_(1.0, 1.0)][i % 4]
		pl.body.apply(pose)
	cam.position = Vector3(0, 1.3, 15.5)
	cam.look_at(Vector3(0, 0.95, 0))
	await _shot(out, "lineup")
	for ti in 2:
		cam.position = Vector3(-6.75 + ti * 8.8, 1.1, 4.6)
		cam.look_at(cam.position + Vector3(0, -0.15, -4.6))
		await _shot(out, "close%d" % (ti + 1))
	for pl in ps:
		pl.queue_free()
	# The run: walking (1.4 m/s), jogging (3.5) and sprinting (6.8), one stride pair in eight stills, side on.
	ps = []
	var sq2: Array = DB.squad("ENG")
	for i in 8:
		var pl := Player.new(0, sq2[i % 7], ToonBody.LETTERS[i % 7])
		add_child(pl)
		pl.position = Vector3(-6.3 + i * 1.8, 0, 0)
		pl.rotation.y = PI * 0.5
		ps.append(pl)
	await get_tree().process_frame
	cam.position = Vector3(0, 1.2, 15.0)
	cam.look_at(Vector3(0, 0.8, 0))
	for spd: float in [1.4, 3.5, 6.8]:
		for i in 8:
			var pl: Player = ps[i]
			pl.stride_phase = i / 8.0
			pl.clip_body = 1.0
			pl.clip_arms = 1.0
			pl.body.apply(pl._with_clips(Poses.run(pl.stride_phase, spd), spd))
		await _shot(out, "run_%.1f" % spd)
	get_tree().quit()


func _backdrop() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("3b6f8f")
	env.environment = e
	add_child(env)
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_mesh.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("c9a46c")
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mesh.material_override = fm
	add_child(floor_mesh)
	# A grid of thin lines every 0.5 m, so a sliding foot shows against the floor.
	for i in range(-40, 41):
		for axis in 2:
			var ln := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.006, 0.002, 40.0) if axis == 0 else Vector3(40.0, 0.002, 0.006)
			ln.mesh = bm
			var lm := StandardMaterial3D.new()
			lm.albedo_color = Color("a07f4c")
			lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ln.material_override = lm
			ln.position = Vector3(i * 0.5, 0.001, 0) if axis == 0 else Vector3(0, 0.001, i * 0.5)
			add_child(ln)


## A motion-capture clip as it is stored (assets/player/mocap.json), in eight stills from the side and from the front,
## each still placed where the clip's travel has carried her, so planted feet should line up on the grid.
func _raw_strip(out: String, clip: String) -> void:
	var c := HeroBody.mocap(clip)
	var length := HeroBody.mocap_length(clip)
	var sq: Array = DB.squad("ENG")
	var n := 10
	for view in 2:
		var ps := []
		for i in n:
			var pl := Player.new(0, sq[i % 7], ToonBody.LETTERS[i % 7])
			add_child(pl)
			ps.append(pl)
		await get_tree().process_frame
		var cam := Camera3D.new()
		add_child(cam)
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 2.6
		get_tree().root.size = Vector2i(2400, 520)
		for i in n:
			var pl: Player = ps[i]
			pl.body.scale = Vector3.ONE
			var t := length * float(i) / float(n - 1)
			var ps_: Array = HeroBody.mocap_pose(clip, t)
			var pose := {}
			for j in ToonBody.BONES.size():
				pose[ToonBody.BONES[j][0]] = ps_[0][j]
			var sh: Vector3 = ps_[1]
			pose.hips_x = sh.x
			pose.hips_y = sh.y
			pose.hips_fwd = sh.z
			pl.body.apply(pose)
			var tr := 0.0
			var trv: PackedFloat32Array = c.travel
			if trv.size() > 1:
				var f := t * float(c.fps)
				var k := mini(int(f), trv.size() - 2)
				tr = lerpf(trv[k], trv[k + 1], f - k)
			var turn := 0.0
			var tu: PackedFloat32Array = c.turn
			if tu.size() > 1:
				var f2 := t * float(c.fps)
				var k2 := mini(int(f2), tu.size() - 2)
				turn = deg_to_rad(lerpf(tu[k2], tu[k2 + 1], f2 - k2))
			pl.rotation.y = turn
			# Side view: stills spread along x, her path along z (seen from +x); front: along x, seen from +z.
			if view == 0:
				pl.position = Vector3(0, 0, 0) + Vector3(0, 0, tr) + Vector3(0, 0, -float(i) * 1.1 + 5.0)
			else:
				pl.position = Vector3(float(i) * 1.1 - 5.0, 0, tr)
		cam.size = 3.2
		if view == 0:
			cam.position = Vector3(30, 1.0, 0)
			cam.look_at(Vector3(0, 1.0, 0))
		else:
			cam.position = Vector3(0, 1.0, 30)
			cam.look_at(Vector3(0, 1.0, 0))
		cam.size = 2.4
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		await _shot(out, "clip_%s_%s" % [clip, ["side", "front"][view]])
		for pl in ps:
			pl.queue_free()
		cam.queue_free()
		await get_tree().process_frame


## The motion-capture moves as the match plays them (Player.advance, frame by frame at 30 fps): the side-step while
## marking, and landings with the ball from a jog and from a sprint. Ten stills of each, from the side and the front,
## spread out along the strip; slide_<name>.txt gives how far each planted foot moved on the floor.
func _moves(out: String) -> void:
	var sq: Array = DB.squad("ENG")
	var scenes := {
		"slide": {"speed": 3.0, "dir": Vector2(1, 0), "frames": 60, "from": 30, "act": "mark"},
		"slide_run": {"speed": 3.0, "dir": Vector2(-1, 0), "frames": 60, "from": 30, "act": "run"},
		"land_jog": {"speed": 3.5, "dir": Vector2(0, 1), "frames": 50, "from": 26, "catch": 30, "foot": "l"},
		"land_sprint": {"speed": 6.5, "dir": Vector2(0, 1), "frames": 50, "from": 26, "catch": 30, "foot": "r"},
	}
	for sname: String in scenes:
		var sc: Dictionary = scenes[sname]
		var n := 10
		var total := int(sc.frames)
		var from := int(sc.from)
		for view in 2:
			var ps := []
			for i in n:
				var pl := Player.new(0, sq[3], "C")
				add_child(pl)
				ps.append(pl)
			await get_tree().process_frame
			for i in n:
				var pl: Player = ps[i]
				pl.fenced = false
				var upto := from + int(float(total - from) * float(i) / float(n - 1))
				var dir: Vector2 = sc.dir
				pl.place(Vector2.ZERO, 0.0 if sname.begins_with("slide") else atan2(dir.x, dir.y))
				pl.vel = dir * float(sc.speed)
				for f in upto:
					if sc.has("catch") and f == int(sc.catch):
						pl.stopped = true
						pl.set_act("hold")
						pl.start_landing(String(sc.foot))
					elif not sc.has("catch") or f < int(sc.catch):
						pl.set_act(String(sc.get("act", "run")))
						pl.target = pl.p + dir * 5.0
						pl.want_speed = float(sc.speed)
						pl.look_on = sname.begins_with("slide")
						pl.look_at_p = pl.p + Vector2(0, 10)
					pl.advance(1.0 / 30.0)
				# Spread along the strip: across for the side view's path (z), along x for the front view's.
				var spread := float(i) * 1.15 - 5.2
				pl.position += Vector3(0, 0, -spread) if view == 0 else Vector3(spread, 0, 0)
			var cam := Camera3D.new()
			add_child(cam)
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.keep_aspect = Camera3D.KEEP_HEIGHT
			cam.size = 2.4
			get_tree().root.size = Vector2i(2400, 520)
			var mid: Vector3 = ps[n / 2].position
			if view == 0:
				cam.position = Vector3(30, 1.0, mid.z)
			else:
				cam.position = Vector3(mid.x, 1.0, 30)
			cam.look_at(Vector3(mid.x if view == 1 else 0.0, 1.0, mid.z if view == 0 else 0.0))
			await _shot(out, "move_%s_%s" % [sname, ["side", "front"][view]])
			for pl in ps:
				pl.queue_free()
			cam.queue_free()
			await get_tree().process_frame


func _shot(out: String, name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved ", name)
