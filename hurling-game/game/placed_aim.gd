class_name PlacedAim
extends Node3D
## Your free, 65 or penalty at the posts, as a test of timing: the camera low behind the taker, looking at the goal,
## and a target going round in front of it, through the net, out wide, up through the posts above the bar and out
## the other side. SHOOT stops it, and that is where the sliotar goes (match.gd strikes it there, near enough). The
## target hurries through the goal (a small space, with a keeper in it) and lingers between the posts above the bar
## (a big one), and goes round faster the further out the free is.
## (The owner: "When a penalty is in range of trying to score points have the camera be ground level beyond the
## shooter. There will be a simple button that says shoot. But it's about timing.")

const CENTRE_Y := 3.2          # the middle of the target's round, above the ground (m)
const RADIUS_Z := 6.4          # across: out past each upright (the uprights are 3.25 m from the middle)
const RADIUS_Y := 2.9          # up and down: from 0.3 m (in the net) to 6.1 m (well over the bar)
const SLOW_POSTS := 0.55       # its speed between the posts above the bar, against wide
const FAST_GOAL := 1.9         # and in the goal

signal shot(target: Vector3)
signal done                    # the shot has been seen: back to the match camera

const WATCH := 2.6             # seconds the low camera stays on the flight after the strike
const WAIT := 12.0             # left this long, it stops by itself

var goal_x := 0.0              # the goal line it is in front of
var dir := 1.0                 # the way the taker shoots
var angle := 0.0
var period := 2.6              # seconds for one round, wide all the way
var stopped := false
var camera: Camera3D
var _ring: MeshInstance3D
var _mat: StandardMaterial3D
var _t := 0.0
var _hold := 0.0


## Set up for a taker standing at stand over the ball at spot, shooting toward d (+1 toward +x). skill 0-1 (his
## free-taking) slows it a little.
func setup(spot: Vector3, stand: Vector3, d: float, skill: float, rng: RandomNumberGenerator) -> void:
	dir = d
	goal_x = Pitch.HALF_L * d
	var dist := absf(goal_x - spot.x)
	# Faster from further out: a round of 2.9 s from 14 m, 1.8 s from 65 m; a good free-taker's a little slower.
	period = lerpf(2.9, 1.8, clampf((dist - 14.0) / 51.0, 0.0, 1.0)) * lerpf(0.9, 1.12, clampf(skill, 0.0, 1.0))
	angle = rng.randf() * TAU
	# The camera: low, eight metres behind the taker and a metre to his side, looking past his shoulder at the goal
	# (right behind him, his back hid it); the goal framed at any distance (closer frees wider).
	var to_goal := Vector3(goal_x - stand.x, 0, -stand.z).normalized()
	var side := Vector3(-to_goal.z, 0, to_goal.x)
	# The side of him away from the ball: he is framed at the edge, the ball and the goal clear.
	var away := -signf(side.dot(spot - stand)) if (spot - stand).length() > 0.2 else 1.0
	camera = Camera3D.new()
	add_child(camera)
	camera.near = 0.2
	camera.far = 900.0
	camera.global_position = Vector3(stand.x, 0, stand.z) - to_goal * 8.0 + side * away * 1.25 + Vector3(0, 1.0, 0)
	camera.look_at(Vector3(goal_x, CENTRE_Y + 0.6, 0))
	var reach := Vector2(goal_x, 0).distance_to(Vector2(camera.global_position.x, camera.global_position.z))
	camera.fov = clampf(rad_to_deg(2.0 * atan(6.5 / reach)), 17.0, 36.0)
	camera.make_current()
	# The target: a ring that always faces the camera, about as big on the screen from any distance.
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.billboard_keep_scale = true
	_ring = MeshInstance3D.new()
	_ring.mesh = _ring_mesh(0.5, 0.3)
	_ring.material_override = _mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_ring.scale = Vector3.ONE * clampf(reach * 0.034, 0.7, 2.4)
	# A white edge round it, to read against the crowd and the sky.
	var edge_mat: StandardMaterial3D = _mat.duplicate()
	edge_mat.albedo_color = Color(1, 1, 1, 0.95)
	edge_mat.render_priority = -1
	var edge := MeshInstance3D.new()
	edge.mesh = _ring_mesh(0.6, 0.24)
	edge.material_override = edge_mat
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.add_child(edge)
	_place()


## Where the target is now, on the goal line (world space).
func target() -> Vector3:
	return Vector3(goal_x, CENTRE_Y + sin(angle) * RADIUS_Y, cos(angle) * RADIUS_Z * dir)


## What the target is over: "goal" (in the net, under the bar between the posts), "point" (over the bar between
## them, as high as it goes) or "wide".
static func zone(p: Vector3) -> String:
	if absf(p.z) > Pitch.POST_GAP * 0.5 - 0.1:
		return "wide"
	return "goal" if p.y < Pitch.BAR_H - 0.12 else "point"


func _process(dt: float) -> void:
	_t += dt
	if not stopped and _t > WAIT:
		stop()
	if stopped:
		_hold += dt
		# A beat, the target flashing where it stopped, then gone as he strikes; the camera stays on the flight.
		_mat.albedo_color.a = 0.6 + 0.4 * absf(sin(_hold * 18.0))
		_ring.visible = _hold < 0.5
		if _hold > 0.35 + WATCH:
			set_process(false)
			done.emit()
		return
	var z := zone(target())
	var k := SLOW_POSTS if z == "point" else (FAST_GOAL if z == "goal" else 1.0)
	angle = fmod(angle + TAU / period * k * dt, TAU)
	_place()


func _place() -> void:
	var p := target()
	_ring.global_position = p
	match zone(p):
		"point":
			_mat.albedo_color = Color(Game.C_GOLD, 0.95)
		"goal":
			_mat.albedo_color = Color(0.35, 0.9, 0.45, 0.95)
		_:
			_mat.albedo_color = Color(0.95, 0.3, 0.25, 0.9)


## SHOOT: the target stops; shot is sent with it after a beat.
func stop() -> Vector3:
	if stopped:
		return target()
	stopped = true
	var p := target()
	get_tree().create_timer(0.35).timeout.connect(func(): shot.emit(p))
	return p


## A flat ring of inner radius r_in, outer r (a quad strip), with a dot in the middle.
static func _ring_mesh(r: float, r_in: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 40
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0), sin(a0), 0)
		var p1 := Vector3(cos(a1), sin(a1), 0)
		st.add_vertex(p0 * r_in)
		st.add_vertex(p0 * r)
		st.add_vertex(p1 * r)
		st.add_vertex(p0 * r_in)
		st.add_vertex(p1 * r)
		st.add_vertex(p1 * r_in)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(p0 * 0.09)
		st.add_vertex(p1 * 0.09)
	return st.commit()
