extends Node3D
## Officials on the rig: the referee side-stepping and jogging with the play while facing it, stopping, blowing the
## whistle and pointing; an umpire signalling a point, arm straight up from the side.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 --write-movie out.avi res://tests/media/officials_video.tscn -- <char dir> <tex dir>

var ref: WsgOfficial
var ump: WsgOfficial
var ball: MeshInstance3D
var cam: Camera3D
var t := 0.0
var vel := Vector3.ZERO
var label: Label
var done := {}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	WsgStage.build(self, 80.0)
	ref = WsgOfficial.new(WsgBody.load_character(a[0], "referee"), WsgStage.hero_material(a[1].path_join("referee_full.jpg")))
	add_child(ref)
	ref.position = Vector3(0, 0, 0)
	ump = WsgOfficial.new(WsgBody.load_character(a[0], "umpire"), WsgStage.hero_material(a[1].path_join("umpire_full.jpg")))
	add_child(ump)
	ump.position = Vector3(-14, 0, 6)
	ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	ball.mesh = sm
	add_child(ball)
	cam = Camera3D.new()
	cam.fov = 42
	add_child(cam)
	cam.current = true
	var cl := CanvasLayer.new()
	add_child(cl)
	label = Label.new()
	label.position = Vector2(20, 14)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	cl.add_child(label)


func _process(delta: float) -> void:
	t += delta
	# The play: up the pitch (+X... the referee keeps level with it, side-stepping then jogging).
	var bx := 6.0 * sin(t * 0.45) if t < 7.0 else 6.0 * sin(7.0 * 0.45)
	ball.position = Vector3(8.0, 0.4, bx)
	var want := Vector3.ZERO
	var what := ""
	if t < 7.0:
		var target_z := ball.position.z
		want = Vector3(0, 0, clampf((target_z - ref.position.z) * 1.5, -4.0, 4.0))
		what = "referee: keeping level with the play, facing it"
	vel = vel.move_toward(want, 6.0 * delta)
	ref.position += vel * delta
	ref.follow(delta, vel, ball.position, want)
	ump.follow(delta, Vector3.ZERO, ball.position if t < 10.5 else ump.position + Vector3(10, 0, -6))
	if t > 7.4 and not done.has("whistle"):
		done.whistle = true
		ref.signal_gesture("whistle")
	if t > 8.6 and not done.has("point"):
		done.point = true
		ref.signal_gesture("point", Vector3(-30, 1.0, 6))
	if t > 10.6 and not done.has("score"):
		done.score = true
		ump.signal_gesture("score")
	if t >= 7.0 and t < 8.6:
		what = "referee: whistle"
	elif t >= 8.6 and t < 10.6:
		what = "referee: points to the goal"
	elif t >= 10.6:
		what = "umpire: a point, arm straight up from the side"
	label.text = what
	var focus := ref.position + Vector3(0, 1.0, 0) if t < 10.3 else ump.position + Vector3(0, 1.1, 0)
	var want_cam := focus + (Vector3(5.0, 0.8, -2.5) if t < 10.3 else Vector3(4.0, 0.5, -1.0))
	cam.position = want_cam if t < 0.05 else cam.position.lerp(want_cam, 1.0 - exp(-delta * 2.5))
	cam.look_at(focus)
	if t > 13.5:
		get_tree().quit()
