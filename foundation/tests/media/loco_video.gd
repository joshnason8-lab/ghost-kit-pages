extends Node3D
## The locomotion test's path as a video: a hurler starting, running, cutting, stopping, running backwards,
## side-stepping and curving, the camera following at the side. Run with Godot's movie maker:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 --write-movie out.avi res://tests/media/loco_video.tscn -- [albedo.jpg] [plant 0/1]

const PATH := [
	[1.5, Vector2(0, 0), 0.0],
	[4.5, Vector2(0, 6.0), 0.0],
	[6.5, Vector2(6.0, 0), 90.0],
	[8.1, Vector2(0, 0), 90.0],
	[9.0, Vector2(0, 0), 90.0],
	[12.0, Vector2(-2.6, 0), 90.0],
	[13.4, Vector2(0, 0), 90.0],
	[15.9, Vector2(0, 3.0), 90.0],
	[17.4, Vector2(0, 0), 90.0],
]

var body: WsgBody
var loco: WsgLocomotor
var cam: Camera3D
var t := 0.0
var vel := Vector2.ZERO
var pos := Vector3.ZERO
var label: Label


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	WsgStage.build(self)
	var ch := WsgBody.load_character("res://tests/character", "hero")
	body = WsgBody.new(ch, WsgStage.hero_material(a[0] if a.size() > 0 else ""))
	add_child(body)
	loco = WsgLocomotor.attach(body)
	if a.size() > 1:
		loco.planter.enabled = a[1] == "1"
	cam = Camera3D.new()
	cam.fov = 40
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
	var spec: Array = PATH[-1]
	for p in PATH:
		if t < p[0]:
			spec = p
			break
	var want: Vector2 = spec[1]
	var facing := deg_to_rad(spec[2])
	if t < PATH[1][0] and t >= PATH[0][0]:
		facing = atan2(want.x, want.y)
	vel = vel.move_toward(want, (6.5 if want.length() > vel.length() else 9.0) * delta)
	pos += Vector3(vel.x, 0, vel.y) * delta
	body.position = pos
	loco.drive(delta, Vector3(vel.x, 0, vel.y), facing, Vector3(want.x, 0, want.y))
	var names := {0: "standing", 1: "starting", 2: "moving", 3: "cutting", 4: "stopping", 5: "turning", 6: "jumping", 7: "gesture"}
	label.text = "%s   %.1f m/s   %s" % [names.get(loco.state, ""), vel.length(), loco._shot if loco._w_shot > 0.5 else ""]
	var focus := pos + Vector3(0, 1.0, 0)
	var want_cam := focus + Vector3(-6.5, 1.6, 2.5)
	cam.position = want_cam if t == 0.0 else cam.position.lerp(want_cam, 1.0 - exp(-delta * 3.0))
	cam.look_at(focus)
	t += delta
	if t > PATH[-1][0] + 0.5:
		get_tree().quit()
