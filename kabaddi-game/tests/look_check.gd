extends Node
## How each ground looks: the same seeded AI match on every ground, stopped at the same moments, each saved as the
## broadcast view the game shows and a close look at the raider and the defenders nearest him. Made to compare the
## look before and after a change, frame for frame (the match plays the same from its seed).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1493x720 --fixed-fps 30 \
##       res://tests/look_check.tscn -- OUTDIR [grounds=dome,stadium,village,monsoon,beach] [at=14,31] [gfx=1] [seed=1] [nobake]
## gfx is the graphics level (0 low, 1 medium as phones start, 2 high); nobake builds the grounds without their baked
## lighting (assets/grounds/). Prints each frame's draw time too.

var _out := "user://look"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	var grounds := ["dome", "stadium", "village", "monsoon", "beach"]
	var at := [14.0, 31.0]
	var s := 1
	Game.settings.graphics = Game.GFX_MEDIUM
	for a in args:
		var t := String(a)
		if t.begins_with("grounds="):
			grounds = Array(t.substr(8).split(","))
		elif t.begins_with("at="):
			at = []
			for x in t.substr(3).split(","):
				at.append(float(x))
		elif t.begins_with("gfx="):
			Game.settings.graphics = int(t.substr(4))
		elif t.begins_with("seed="):
			s = int(t.substr(5))
		elif t == "nobake":
			Arena.use_baked = false
	Game.main = self
	Game.settings.sound = false
	Game.settings.models = 1
	Game.settings.camera = Game.CAM_TV
	Game.apply_graphics(get_viewport())
	for g in grounds:
		await _ground(String(g), at, s)
	get_tree().quit()


func _ground(id: String, at: Array, s: int) -> void:
	# Begun once the frame steps are steady, as tests/match_record and tests/raid_audit do, so it plays the same.
	var run := 0
	for i in 60:
		await get_tree().process_frame
		run = run + 1 if is_equal_approx(get_process_delta_time(), 1.0 / 30.0) else 0
		if run >= 5:
			break
	seed(s)
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "MUM", "away": "DEL", "arena": id, "mode": "quick", "autoplay": true, "autoplay_no_report": true,
		"length": 0, "difficulty": 1, "seed": s}
	add_child(m)
	var f := 0
	var cost := []
	for t in at:
		while f < int(float(t) * 30.0):
			var t0 := Time.get_ticks_usec()
			await get_tree().process_frame
			cost.append(Time.get_ticks_usec() - t0)
			f += 1
		await _shot(m, "%s_%02d_tv" % [id, int(t)])
		await _close(m, "%s_%02d_close" % [id, int(t)])
	cost.sort()
	print("look_check %s: frame %.1f ms median, %.1f ms 90th percentile (software renderer)" % [id,
		cost[cost.size() / 2] / 1000.0, cost[int(cost.size() * 0.9)] / 1000.0])
	m.queue_free()
	await get_tree().process_frame


func _shot(_m: Node, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("look_check: ", name)


## The raider and whoever is nearest him, from 4 m off at chest height, without the HUD.
func _close(m: Node, name: String) -> void:
	var r: Node3D = m.raider if m.raider != null else m.athletes[0]
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	var side := Vector3(1, 0, 0.35).normalized()
	cam.global_position = r.global_position + side * 4.2 + Vector3(0, 1.45, 0)
	cam.look_at(r.global_position + Vector3(0, 0.95, 0), Vector3.UP)
	var was: Camera3D = get_viewport().get_camera_3d()
	cam.current = true
	var hud: CanvasLayer = m.get("hud")
	if hud:
		hud.visible = false
	await get_tree().process_frame
	await _shot(m, name)
	if hud:
		hud.visible = true
	if was:
		was.current = true
	cam.queue_free()
