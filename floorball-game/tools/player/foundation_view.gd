extends Node
## Close-ups of the shared foundation's bodies in an AI match (FoundationLink): a player running with his stick (from
## the side and the front), a shot's follow-through, a goalkeeper's save, a referee:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/player/foundation_view.tscn -- OUT_DIR [graphics]
## Each still is taken with the match paused at the moment. Prints the fists' distance from the shaft's axis.

var m: Node
var cam: Camera3D
var out := "/tmp"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "/tmp"
	get_tree().root.size = Vector2i(1280, 720)
	Game.main = self
	Game.settings.sound = false
	Game.settings.auto_gfx = false
	Game.settings.graphics = int(a[1]) if a.size() > 1 else Game.GFX_HIGH
	Game.start_match({"home": "SWE", "away": "FIN", "venue": "arena", "user_team": -1, "watch": true, "seed": 5, "period": 20.0})
	m = Game.current
	cam = Camera3D.new()
	cam.fov = 32.0
	add_child(cam)
	for q: Player in m.everyone():
		if q.link:
			q.link.measure = true
	for i in 240:
		await get_tree().physics_frame
	if m.hud:
		m.hud.visible = false
		if m.hud.get("root"):
			m.hud.root.visible = false
	# Running with the stick: the fastest skater with no move of his own.
	var p: Player = await _wait(func(q: Player): return q.role in ["C", "F", "D"] and q.act == "" and q.vel.length() > 4.0 and q.windup <= 0.0, 2000)
	if p:
		await _shoot(p, "run_side", Vector3(0.0, 1.0, 3.2), 0.9)
		await _shoot(p, "run_front", Vector3(3.2, 1.1, 0.4), 0.9)
		await _shoot(p, "run_hands", Vector3(0.9, 0.35, 0.7), -1.0, 30.0)
	p = await _wait(func(q: Player): return q.act == "shoot" and q.act_t > q.act_len * 0.62, 6000)
	if p:
		await _shoot(p, "shot_follow", Vector3(1.2, 1.2, 3.0), 0.9)
		await _shoot(p, "shot_follow_front", Vector3(3.2, 1.2, -0.6), 0.9)
	p = await _wait(func(q: Player): return q.role == "G" and q.act.begins_with("save") and q.act_t > q.act_len * 0.3, 8000)
	if p:
		await _shoot(p, "keeper_save", Vector3(3.4, 1.0, 0.6), 0.6)
		await _shoot(p, "keeper_save_side", Vector3(0.4, 1.0, 3.2), 0.6)
	var r: Player = m.refs[0]
	await _shoot(r, "referee", Vector3(3.0, 1.2, 1.0), 1.0)
	r = await _wait(func(q: Player): return q.role == "R" and q.act.begins_with("signal_") and q.act_t > 0.5, 8000)
	if r:
		await _shoot(r, "referee_signal", Vector3(3.4, 1.3, 0.8), 1.1)
	get_tree().quit()


func _wait(cond: Callable, limit: int) -> Player:
	m.set_paused(false)
	for i in limit:
		for q: Player in m.everyone():
			if q.visible and cond.call(q):
				m.set_paused(true)
				if m.hud:
					m.hud.show_pause(false)
				return q
		await get_tree().physics_frame
	print("foundation_view: not seen in time")
	return null


## A still of p from offset (his frame: x ahead, z to his left... y up), looking at his height y_at.
func _shoot(p: Player, name: String, off: Vector3, y_at: float, fov := 32.0) -> void:
	cam.fov = fov
	cam.make_current()
	var f := Vector3(p.dir().x, 0, p.dir().y)
	var l := Vector3(f.z, 0, -f.x)
	var at := Vector3(p.pos.x, 0, p.pos.y)
	var look := at + Vector3.UP * y_at
	if y_at < 0.0 and p.link and p.link.stick:
		# (The hands: the top fist on the shaft.)
		var sx := p.link.stick.global_transform
		look = sx.origin + (sx.basis * Vector3.DOWN).normalized() * 0.12
		at = look - Vector3.UP * 1.0
	cam.global_position = at + f * off.x + Vector3.UP * off.y + l * off.z
	cam.look_at(look)
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/%s.png" % name)
	var msg := "%s: %s act=%s mode=%s" % [name, p.role, p.act, p.link.mode if p.link else "-"]
	if p.link and p.link.stick and p.link.stick.visible:
		for s in [p.link.top, p.link.low]:
			msg += " %s fist off the shaft %.1f cm, %.1f cm down it" % [s, float(p.link.last_fists.get(s, -1.0)) * 100.0, float(p.link.last_fists.get(s + "_along", -1.0)) * 100.0]
	print(msg)
