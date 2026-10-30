extends Node3D
## The foundation pilot, filmed: Hurling Heroes' own players, officials and ground, with and without the shared
## foundation (WSG_OFF=1: as the game is today), for the before / after / side-by-side videos.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 --write-movie out.avi res://tests/foundation_pilot.tscn -- <part>
## part: "run" (a hurler starting, running, cutting, stopping, running backwards), "crowd" (a close-up of the
## crowd reacting to a score), "official" (an umpire signalling a point).

const PATH := [
	[1.2, Vector3(0, 0, 0), "standing"],
	[4.2, Vector3(0, 0, 7.5), "starting, running"],
	[6.0, Vector3(7.5, 0, 0), "cutting left"],
	[7.6, Vector3(0, 0, 0), "stopping"],
	[8.4, Vector3(0, 0, 0), "standing"],
	[11.2, Vector3(-2.6, 0, 0), "running backwards"],
	[12.6, Vector3(0, 0, 0), "stopping"],
]

var part := "run"
var stadium: Stadium
var cam: Camera3D
var hurler: Player
var ump: Player
var ball: MeshInstance3D
var t := 0.0
var label: Label
var done := {}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	part = a[0] if a.size() > 0 else "run"
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	stadium = Stadium.new("county", [Color("1f6b35"), Color("f2c230")], [Color("c8102e"), Color("ffffff")])
	add_child(stadium)
	cam = Camera3D.new()
	cam.fov = 38
	add_child(cam)
	cam.current = true
	var t_kil := DB.team("KIL")
	var look := {"skin": Color("e8bc9a"), "hair": Color("4a3221"), "jersey": t_kil.c1, "trim": t_kil.c2,
		"shorts": Color("f6f6f2"), "socks": t_kil.c1, "helmet": t_kil.c2, "design": int(t_kil.design), "height": 1.82,
		"kind": "player"}
	hurler = Player.new({"num": 11, "line": 3, "speed": 80}, 0, look)
	hurler.position = Vector3(-6, 0, -6)
	add_child(hurler)
	var uk := {"kind": "umpire", "jersey": Color("f4f4f0"), "trim": Color("f4f4f0"), "skin": Color("e8bc9a"),
		"hair": Color("6a6a6a"), "height": 1.76}
	ump = Player.new({"num": 0, "line": -1}, -1, uk, "umpire")
	ump.position = Vector3(-Pitch.HALF_L + 0.5, 0, 4.5)
	ump.yaw = PI * 0.5
	add_child(ump)
	ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	ball.mesh = sm
	add_child(ball)
	var cl := CanvasLayer.new()
	add_child(cl)
	label = Label.new()
	label.position = Vector2(24, 18)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 7)
	cl.add_child(label)


func _process(delta: float) -> void:
	t += delta
	var now := t
	var tag := "AFTER: the shared foundation" if FoundationLink.enabled() else "BEFORE: the game today"
	if OS.has_environment("FILM_TAG"):
		tag = OS.get_environment("FILM_TAG")
	match part:
		"run":
			var spec: Array = PATH[-1]
			for p in PATH:
				if t < p[0]:
					spec = p
					break
			hurler.want_vel = spec[1]
			hurler.face_to = hurler.position + Vector3(10, 0, 0) if spec[2] == "running backwards" or spec[2] == "stopping" and t > 11.0 else Vector3.ZERO
			hurler.integrate(delta, now)
			hurler.animate(now)
			label.text = "%s     %s   %.1f m/s" % [tag, spec[2], hurler.vel.length()]
			var focus := hurler.position + Vector3(0, 1.0, 0)
			var want_cam := focus + Vector3(-1.5, 1.2, 8.5)
			cam.position = want_cam if t < 0.05 else cam.position.lerp(want_cam, 1.0 - exp(-delta * 2.5))
			cam.look_at(focus)
			ump.animate(now)
			if t > PATH[-1][0] + 0.8:
				get_tree().quit()
		"crowd":
			# The far stand, close: the ball worked toward the posts, the pressure building, a point, the cheer.
			var bx := lerpf(10.0, -Pitch.HALF_L + 18.0, clampf((t - 1.0) / 5.0, 0.0, 1.0))
			ball.position = Vector3(bx, 1.0 + absf(sin(t * 3.0)), -10.0)
			stadium.crowd3d.watch_ball(ball.position) if stadium.crowd3d else null
			var what := "watching"
			if t < 6.0:
				WsgCrowd3D.set_tension(clampf((t - 2.0) / 4.0, 0.0, 1.0))
				what = "the pressure building" if t > 2.0 else "watching"
			elif t < 10.0:
				WsgCrowd3D.set_tension(0.0)
				Crowd.set_excite(1.0)
				what = "A POINT"
			else:
				Crowd.set_excite(0.0)
				what = "settling"
			label.text = "%s     the crowd: %s" % [tag, what]
			cam.look_at_from_position(Vector3(-28.0 + t * 0.4, 6.0, -Pitch.HALF_W + 6.0), Vector3(-34.0 + t * 0.4, 5.0, -Pitch.HALF_W - 14.0))
			if t > 14.0:
				get_tree().quit()
		"seats":
			# Close on the far stand's seats: the fans sitting, up for a score, and down again.
			Crowd.set_excite(1.0 if t > 3.0 and t < 7.0 else 0.0)
			label.text = "%s     the crowd in their seats" % tag
			cam.look_at_from_position(Vector3(-4.0 + t * 0.25, 3.6, -Pitch.HALF_W - 1.5), Vector3(-9.0 + t * 0.25, 2.4, -Pitch.HALF_W - 11.0))
			if t > 11.0:
				get_tree().quit()
		"hand":
			# Close on the hurley hand: standing, then running.
			hurler.want_vel = Vector3.ZERO if t < 1.5 else Vector3(0, 0, 5.0)
			hurler.integrate(delta, now)
			hurler.animate(now)
			label.text = "%s     the hurley in the hand" % tag
			var hand: Vector3 = hurler.link.body.bone_world("RightHand").origin if hurler.link else hurler.body.bone_world("hand_r")
			cam.look_at_from_position(hand + Vector3(1.6, 0.4, 0.6), hand)
			if t > 3.0:
				get_tree().quit()
		"arm":
			# The hurley arm from the side: jogging, then sprinting.
			hurler.want_vel = Vector3(0, 0, 3.5 if t < 3.0 else 7.5)
			hurler.integrate(delta, now)
			hurler.animate(now)
			label.text = "%s     the hurley arm, %.1f m/s" % [tag, hurler.vel.length()]
			var focus := hurler.position + Vector3(0, 1.1, 0)
			cam.look_at_from_position(focus + Vector3(-3.2, 0.1, 0.4), focus)
			if t > 5.0:
				get_tree().quit()
		"official":
			# The umpire at the posts: a point is scored, he signals it.
			if t > 1.5 and not done.has("sig"):
				done.sig = true
				ump.play("sig_point")
			ump.integrate(delta, now)
			ump.animate(now)
			label.text = "%s     the umpire signals a point" % tag
			var focus := ump.position + Vector3(0, 1.3, 0)
			cam.look_at_from_position(focus + Vector3(5.5, 0.3, 2.5), focus)
			if t > 5.5:
				get_tree().quit()
