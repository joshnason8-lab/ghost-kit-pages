extends Node3D
## A close-up of the 3D crowd reacting to a score: a stand of seated fans (concrete steps, seats), the ball moving
## along the pitch in front of them, the pressure building, a score, the cheering and clapping, settling down.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 --write-movie out.avi res://tests/media/crowd_video.tscn

const ROWS := 9
const SEATS := 28
const STEP := Vector2(0.8, 0.42)     # row depth, rise (m)

var crowd: WsgCrowd3D
var cam: Camera3D
var ball: MeshInstance3D
var t := 0.0
var label: Label


func _ready() -> void:
	WsgStage.build(self, 80.0)
	# The stand: concrete steps rising away from the pitch (+Z is toward the pitch for the fans: they face -Z... here
	# the pitch is at -Z, so they face -Z).
	var spots := []
	var facings := []
	var steps := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in ROWS:
		var z := 2.0 + r * STEP.x
		var y := r * STEP.y
		_box(st, Vector3(-12, 0, z), Vector3(12, y + 0.02, z + STEP.x))
		# A seat at the back of each step (42 cm high), the fans' feet in front of it.
		_box(st, Vector3(-12, y, z + STEP.x * 0.62), Vector3(12, y + 0.42, z + STEP.x))
		for s in SEATS:
			spots.append(Vector3(-10.8 + s * 0.8 + (r % 2) * 0.2, y + 0.02, z + STEP.x * 0.62 - WsgCrowd3D.FEET_FORWARD + 0.12))
			facings.append(Vector3(0, 0, -1))
	steps.mesh = st.commit()
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.62, 0.62, 0.6)
	steps.material_override = cm
	add_child(steps)
	crowd = WsgCrowd3D.new()
	add_child(crowd)
	var n := crowd.build(spots, facings, 1.0, 7, true, 2, Vector3(0, 0, 0))
	crowd.set_teams(Color(0.05, 0.42, 0.18), Color(0.75, 0.62, 0.1))
	ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	ball.mesh = sm
	add_child(ball)
	cam = Camera3D.new()
	cam.fov = 45
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
	print("fans: ", n.size())


static func _box(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var m := BoxMesh.new()
	m.size = b - a
	var arr := m.get_mesh_arrays()
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.set_normal(ns[i])
		st.add_vertex(vs[i] + (a + b) * 0.5)


func _process(delta: float) -> void:
	t += delta
	# The ball: along the pitch in front of them, then a run toward the goal on the left, the score at 9 s.
	var bx := sin(t * 0.5) * 14.0 if t < 5.0 else lerpf(sin(2.5) * 14.0, -22.0, clampf((t - 5.0) / 4.0, 0.0, 1.0))
	ball.position = Vector3(bx, 0.5 + absf(sin(t * 2.0)) * 1.5, -12.0)
	crowd.watch_ball(ball.position)
	var what := "watching"
	if t < 5.0:
		WsgCrowd3D.set_tension(0.0)
		WsgCrowd3D.set_excite(0.0)
	elif t < 9.0:
		WsgCrowd3D.set_tension((t - 5.0) / 4.0 * 0.8)
		what = "pressure building"
	elif t < 14.0:
		WsgCrowd3D.set_tension(0.0)
		WsgCrowd3D.set_excite(1.0)
		what = "SCORE"
		if absf(t - 9.0) < delta:
			crowd.clap(2.6, 0.9, 7.0)
	else:
		WsgCrowd3D.set_excite(0.0)
		what = "settling, clapping"
	label.text = "%s   excitement %.2f" % [what, crowd.excite]
	var focus := Vector3(-2.0, 1.6, 4.5)
	cam.position = Vector3(3.5 - t * 0.25, 2.2, -4.0)
	cam.look_at(focus)
	if t > 20.0:
		get_tree().quit()
