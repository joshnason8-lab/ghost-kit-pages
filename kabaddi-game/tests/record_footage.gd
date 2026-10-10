extends Node
## Records side-on broadcast footage of an AI match plus ground truth, for testing
## tools/mocap. Needs a display (xvfb works):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/record_footage.tscn -- /out/dir 450

var out := "user://footage"
var n_frames := 450


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		n_frames = int(args[1])
	DirAccess.make_dir_recursive_absolute(out.path_join("frames"))
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	Game.start_match({"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "autoplay": true, "length": 1, "difficulty": 1})
	var m: Node = Game.current
	m.hud.visible = false
	while m.phase != "raid":
		await get_tree().process_frame
	m.cam.mode = Game.CAM_TV
	for i in 40:
		await get_tree().process_frame
	# Fixed side-on camera: the pipeline assumes a still camera, like a tripod.
	m.cam.frozen = true
	var cam: Camera3D = m.cam.cam
	cam.global_position = Vector3(13.5, 7.5, 0.0)
	cam.look_at(Vector3(0, 0, 0), Vector3.UP)
	cam.fov = 58.0
	var truth := {"corners": [], "frames": []}
	# Field corners as the pipeline expects them: far-left, far-right, near-right, near-left.
	for c in [Vector3(-5, 0, -6.5), Vector3(-5, 0, 6.5), Vector3(5, 0, 6.5), Vector3(5, 0, -6.5)]:
		var p := cam.unproject_position(c)
		truth.corners.append([p.x, p.y])
	for i in n_frames:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_jpg(out.path_join("frames/%05d.jpg" % i), 0.92)
		var players := []
		for a in m.athletes:
			if a.on_mat:
				players.append({"team": a.team, "num": a.data.number, "x": a.position.x, "z": a.position.z, "raider": a == m.raider})
		truth.frames.append({"i": i, "phase": m.phase, "players": players})
		await get_tree().process_frame
	var f := FileAccess.open(out.path_join("truth.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(truth))
	get_tree().quit(0)
