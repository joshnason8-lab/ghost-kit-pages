extends Node
## Frames of players running in an AI match, from the side and from the front-quarter, to judge the stride, the lean and
## the stick in the hands; a keeper close up too:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/player/run_view.tscn -- OUT_DIR [graphics]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp"
	get_tree().root.size = Vector2i(1280, 720)
	Game.main = self
	Game.settings.sound = false
	Game.settings.auto_gfx = false
	Game.settings.graphics = int(a[1]) if a.size() > 1 else Game.GFX_HIGH
	Game.start_match({"home": "SWE", "away": "FIN", "venue": "arena", "user_team": -1, "watch": true, "mode": "watch", "period": 20.0, "seed": 5})
	var m: Node = Game.current
	while m.phase != "live":
		await get_tree().physics_frame
	for i in 120:
		await get_tree().physics_frame
	m.hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 32.0
	add_child(cam)
	cam.make_current()
	var shots := 0
	for clip in 3:
		# The fastest outfield player now.
		var p: Player = null
		for t in 2:
			for q: Player in m.players[t]:
				if q.role != "G" and q.visible and (p == null or q.vel.length() > p.vel.length()) and (clip != 2 or q.pos.distance_to(Vector2(m.ball.pos.x, m.ball.pos.z)) > 7.0):
					p = q
		for f in 48:
			var at := Vector3(p.pos.x, 0.0, p.pos.y)
			var v := Vector3(p.vel.x, 0, p.vel.y)
			var fw := v.normalized() if v.length() > 0.5 else Vector3(p.dir().x, 0, p.dir().y)
			var side := Vector3(-fw.z, 0, fw.x)
			cam.global_position = at + (side * 4.2 + Vector3.UP * 1.0 if clip != 1 else fw * 3.2 + side * 2.0 + Vector3.UP * 1.3)
			cam.look_at(at + Vector3.UP * 0.85)
			await get_tree().physics_frame
			if f % 4 == 0:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out + "/run%d_%02d.png" % [clip, f / 4])
		for i in 90:
			await get_tree().physics_frame
	# A goalkeeper, front and side.
	var gk: Player = m.keeper(0)
	for k in 2:
		var at := Vector3(gk.pos.x, 0.0, gk.pos.y)
		var fw := Vector3(gk.dir().x, 0, gk.dir().y)
		cam.global_position = at + (fw * 3.4 if k == 0 else Vector3(-fw.z, 0, fw.x) * 3.4) + Vector3.UP * 1.1
		cam.look_at(at + Vector3.UP * 0.7)
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/keeper_%d.png" % k)
	get_tree().quit()
