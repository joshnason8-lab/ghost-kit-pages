extends Node
## The bodies in a match, frame by frame, for checking by eye (the owner's notes of 0.8.6): the shooter facing the post,
## the ball in a holder's hands, players standing at ease, the umpires. Every frame saved as a PNG (OUT/<what>_NNNN.png)
## for a contact sheet or a clip (ffmpeg).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/body_view.tscn -- OUT [graphics 0-2] [what]
## what (all of them by default, comma separated):
##   hands   three holders up close, the match held still while each is seen from four sides (hands_*.png), and a
##           shooter at the top of her set (hands_shot_*.png)
##   shot    two shots, each from behind the shooter's shoulder with the post in view (shot_*.png), and the second
##           from the TV camera as well (shot_tv_*.png)
##   idle    a goal keeper and those near her standing about while play is up the court, up close (idle_*.png, 5 s)
##   umpire  an umpire up close as she follows play (ref_*.png, 4 s), and the TV camera (ref_tv_*.png)

var out := "/tmp/body_view"
var n := 0
var prefix := ""
var m: Match
var cam: Camera3D


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else out
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.auto_gfx = false
	Game.settings.graphics = int(a[1]) if a.size() > 1 else Game.GFX_LOW
	Game.settings.camera = Game.CAM_TV
	ToonBody.material(int(Game.settings.graphics) > Game.GFX_LOW)
	var what: Array = Array((a[2] if a.size() > 2 else "hands,shot,idle,umpire").split(","))
	get_tree().root.size = Vector2i(1280, 720)
	Game.start_match({"home": "AUS", "away": "NZL", "venue": "arena", "user_team": -1, "headless_hud": true, "seed": 7, "quarter": 15})
	m = Game.current
	if m.hud:
		m.hud.visible = false
	cam = Camera3D.new()
	cam.fov = 30
	m.add_child(cam)
	if "idle" in what:
		await _idle()
	if "umpire" in what:
		await _umpire()
	if "hands" in what:
		await _hands()
	if "shot" in what:
		await _shots()
	get_tree().quit()


## Runs the match unseen until cond() holds (or limit frames).
func _until(cond: Callable, limit := 3000) -> bool:
	RenderingServer.render_loop_enabled = false
	var ok := false
	for i in limit:
		await get_tree().process_frame
		if cond.call():
			ok = true
			break
	RenderingServer.render_loop_enabled = true
	return ok


func _save() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("%s_%04d.png" % [prefix, n]))
	n += 1


func _look(from: Vector3, at: Vector3) -> void:
	cam.make_current()
	cam.position = from
	cam.look_at(at)


func _idle() -> void:
	prefix = "idle"
	n = 0
	# The players walking to their spots for the centre pass, then waiting for the whistle.
	await _until(func(): return m.phase == "setup" and m.phase_t > 0.5, 600)
	# The goal keepers and defenders at the far end: standing about while the play is up the court.
	var c: Player = m.player_at(0, "GK")
	for f in 150:
		var at: Vector3 = c.global_position
		_look(at + Vector3(2.5 * signf(-at.x), 1.4, 3.6), at + Vector3(0, 0.9, 0))
		await get_tree().process_frame
		await _save()


func _umpire() -> void:
	prefix = "ref"
	n = 0
	await _until(func(): return m.phase == "live" and m.phase_t > 2.0, 900)
	var u: Umpire = m.umpires[0]
	for f in 120:
		var at: Vector3 = u.global_position
		var side := signf(at.z)
		_look(at + Vector3(-1.5, 1.4, -4.5 * side), at + Vector3(0, 0.9, 0))
		await get_tree().process_frame
		await _save()
	prefix = "ref_tv"
	n = 0
	m.cam.make_current()
	for f in 30:
		await get_tree().process_frame
		await _save()


func _hands() -> void:
	prefix = "hands"
	n = 0
	var seen := {}
	for k in 3:
		var ok := await _until(func(): return m.holder != null and not seen.has(m.holder) and m.holder.act == "hold" \
			and m.holder.act_t > 0.35 and m.holder.land_w < 0.05 and m.holder.has_ball(), 2400)
		if not ok:
			break
		var h: Player = m.holder
		seen[h] = true
		await _stills(h)
	prefix = "hands_shot"
	n = 0
	var ok := await _until(func(): return m.holder != null and m.holder.act == "shoot" and m.holder.act_t > 0.45 and m.holder.has_ball(), 6000)
	if ok:
		await _stills(m.holder)


## The match held still, a holder seen from four sides, close.
func _stills(h: Player) -> void:
	m.paused = true
	var at := h.hand_point()
	var f := Vector3(sin(h.body_yaw), 0, cos(h.body_yaw))
	var l := Vector3(f.z, 0, -f.x)
	for v in [f * 1.6 + l * 0.6 + Vector3(0, 0.35, 0), l * 1.7 + Vector3(0, 0.2, 0), -l * 1.5 + f * 0.8 + Vector3(0, 0.6, 0), f * 0.9 + Vector3(0, 1.0, 0)]:
		_look(at + v, at)
		await get_tree().process_frame
		await get_tree().process_frame
		await _save()
	m.paused = false


func _shots() -> void:
	for k in 2:
		var ok := await _until(func(): return m.holder != null and m.holder.act == "shoot" and m.holder.act_t < 0.1, 6000)
		if not ok:
			break
		var s: Player = m.holder
		prefix = "shot" if k == 0 else "shot_tv"
		n = 0
		var post := Court.goal_post(s.dir)
		var to := Vector3(post.x, 0, post.y) - s.global_position
		to.y = 0.0
		var d := to.normalized()
		var side := Vector3(d.z, 0, -d.x)
		for f in 40:
			if k == 0:
				_look(s.global_position - d * 3.2 + side * 1.6 + Vector3(0, 1.9, 0), s.global_position + d * 2.5 + Vector3(0, 1.4, 0))
			else:
				m.cam.make_current()
			await get_tree().process_frame
			await _save()
