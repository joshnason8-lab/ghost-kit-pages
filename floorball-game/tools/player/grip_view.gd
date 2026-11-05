extends Node
## Close-ups of a player holding his stick (the hands round the shaft, the blade), from the front, the side and behind,
## standing and in a penalty shot's run-in:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/player/grip_view.tscn -- OUT_DIR [graphics]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp"
	get_tree().root.size = Vector2i(1280, 720)
	Game.main = self
	Game.settings.sound = false
	Game.settings.auto_gfx = false
	Game.settings.graphics = int(a[1]) if a.size() > 1 else Game.GFX_HIGH
	Game.start_match({"home": "SWE", "away": "FIN", "venue": "arena", "user_team": 0, "mode": "practice", "practice": true, "period": 20.0, "seed": 3})
	var m: Node = Game.current
	for i in 30:
		await get_tree().physics_frame
	while String(m._so.get("stage", "")) != "run":
		await get_tree().physics_frame
	var sh: Player = m._so.shooter
	var cam := Camera3D.new()
	cam.fov = 35.0
	add_child(cam)
	cam.make_current()
	m.hud.visible = false
	m.hud.root.visible = false
	var views := {"front": Vector3(1.3, 1.15, 0.3), "right": Vector3(0.15, 1.05, 1.3), "left": Vector3(0.15, 1.05, -1.3),
		"back": Vector3(-1.2, 1.35, 0.35), "blade": Vector3(0.75, 0.3, 0.75), "above": Vector3(0.5, 1.9, 0.2)}
	if sh.link:
		sh.link.measure = true
		await get_tree().physics_frame
	m.set_paused(true)
	if m.hud:
		m.hud.show_pause(false)
	for k in views:
		var o: Vector3 = views[k]
		var f := Vector3(sh.dir().x, 0, sh.dir().y)
		var r := Vector3(-f.z, 0, f.x)
		var at := Vector3(sh.pos.x, 0, sh.pos.y)
		cam.global_position = at + f * o.x + Vector3.UP * o.y + r * o.z
		cam.look_at(at + f * 0.3 + Vector3.UP * (0.8 if k != "blade" else 0.05) + r * 0.15)
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/grip_%s.png" % k)
	# The blade, close: from the side, the front and above.
	var bf: Vector2 = sh.blade_floor()
	var bp := Vector3(bf.x, 0.04, bf.y)
	var fw := Vector3(sh.dir().x, 0, sh.dir().y)
	var rt := Vector3(-fw.z, 0, fw.x)
	var bv := {"blade_side_a": rt * 0.6 + Vector3.UP * 0.15, "blade_side_b": -rt * 0.6 + Vector3.UP * 0.15, "blade_front": fw * 0.6 + Vector3.UP * 0.15, "blade_top": Vector3.UP * 0.7 + fw * 0.05}
	for k in bv:
		cam.global_position = bp + bv[k]
		cam.look_at(bp, Vector3.UP if k != "blade_top" else fw)
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/%s.png" % k)
	# Each hand, close.
	if sh.link:
		await _link_hands(sh, cam, out)
		get_tree().quit()
		return
	var rig: RiggedBody = sh.body.rig
	var sx: Transform3D = sh.body.stick_transform()
	var inv_k := 1.0 / rig._k
	var top: Vector3 = sx.origin * inv_k
	var down := -sx.basis.y.normalized()
	for sd in ["l", "r"]:
		var h: int = rig._arm[sd][2]
		var gp := rig.skeleton.get_bone_global_pose(h)
		var c: Vector3 = gp.origin + gp.basis.orthonormalized() * (rig._fist[sd][1] as Vector3)
		var rel := c - top
		var dist := (rel - down * rel.dot(down)).length()
		print("fist %s: along %.1f off-shaft %.1f (skeleton units), want %.1f" % [sd, rel.dot(down), dist, float(sh.body.stick_hands().get(sd, -1)) * inv_k])
	for side in ["Right", "Left"]:
		var hb := rig.skeleton.find_bone("mixamorig_%sHand" % side)
		var hp: Vector3 = rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(hb).origin
		for j in 2:
			var f := Vector3(sh.dir().x, 0, sh.dir().y)
			var r := Vector3(-f.z, 0, f.x)
			cam.global_position = hp + (f * 0.45 + Vector3.UP * 0.12 if j == 0 else r * 0.45 * (1.0 if side == "Right" else -1.0) + Vector3.UP * 0.1)
			cam.look_at(hp)
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out + "/hand_%s_%d.png" % [side, j])
	get_tree().quit()


## The hands close when the shared foundation draws him (FoundationLink): each fist on the shaft, from the front and
## the side; the fists' distance from the shaft's axis as measured when he was last posed.
func _link_hands(sh: Player, cam: Camera3D, out: String) -> void:
	var lk: FoundationLink = sh.link
	for k in lk.last_fists:
		print("link %s: %s" % [k, lk.last_fists[k]])
	var sx := lk.stick.global_transform
	var down := (sx.basis * Vector3.DOWN).normalized()
	var spacing := float(sh.body.stick_hands().values().max()) - float(sh.body.stick_hands().values().min())
	for side in [lk.top, lk.low]:
		var hp := sx.origin + down * (FoundationLink.TOP_AT + (spacing if side == lk.low else 0.0))
		for j in 2:
			var f := Vector3(sh.dir().x, 0, sh.dir().y)
			var r := Vector3(-f.z, 0, f.x)
			cam.global_position = hp + (f * 0.45 + Vector3.UP * 0.12 if j == 0 else r * 0.45 * (1.0 if side == "Right" else -1.0) + Vector3.UP * 0.1)
			cam.look_at(hp)
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out + "/hand_%s_%d.png" % [side, j])
