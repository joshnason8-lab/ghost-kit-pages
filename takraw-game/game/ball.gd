class_name Ball
extends Node3D
## The ball: a woven synthetic sphere, flying under gravity alone, so where it will be is known exactly (at(), and
## the time it reaches a height or crosses the net) and the players can plan their touches.

const G := 9.81
const RADIUS := 0.068     # 0.43 m round
const LOOK_SCALE := 1.7

var vel := Vector3.ZERO
var flying := false
var spin := Vector3.ZERO  # rad/s, for the look of it
var p_launch := Vector3.ZERO
var v_launch := Vector3.ZERO
var t_launch := 0.0
var _mesh: MeshInstance3D
var _shadow: MeshInstance3D
var _trail: Array[MeshInstance3D] = []
var _trail_on := 0.0

static var _tex: ImageTexture
static var _shadow_mat: StandardMaterial3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	sm.radial_segments = 16
	sm.rings = 10
	_mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.roughness = 0.8
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Drawn a little larger than it is, with a dark rim, so it reads on a phone from the broadcast camera's seat; it
	# flies, and is met, at its true size.
	_mesh.scale = Vector3.ONE * LOOK_SCALE
	add_child(_mesh)
	var rim := MeshInstance3D.new()
	rim.mesh = sm
	rim.scale = Vector3.ONE * 1.12
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.cull_mode = BaseMaterial3D.CULL_FRONT
	rm.albedo_color = Color(0.03, 0.05, 0.08)
	rim.material_override = rm
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.add_child(rim)
	_shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.34)
	q.orientation = PlaneMesh.FACE_Y
	_shadow.mesh = q
	_shadow.material_override = shadow_material()
	_shadow.top_level = true
	add_child(_shadow)
	_shadow.visible = not Engine.is_editor_hint()
	# A short trail of fading copies for a hard-hit ball (a spike), cheap enough for any phone.
	for i in 4:
		var t := MeshInstance3D.new()
		t.mesh = sm
		var tm := StandardMaterial3D.new()
		tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tm.albedo_color = Color(1.0, 0.85, 0.45, 0.35 - i * 0.07)
		t.material_override = tm
		t.top_level = true
		t.visible = false
		t.scale = Vector3.ONE * (0.9 - i * 0.15) * LOOK_SCALE
		add_child(t)
		_trail.append(t)


## The ball's look: the woven yellow of the synthetic ball with its twelve holes and twenty crossings, drawn once.
static func texture() -> ImageTexture:
	if _tex:
		return _tex
	var w := 128
	var h := 64
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var base := Color("f2c14e")
	for y in h:
		for x in w:
			var u := float(x) / w * TAU * 3.0
			var v := float(y) / h * PI * 3.0
			# Two sets of strips woven over each other, and the holes between them.
			var a := sin(u + v)
			var b := sin(u - v)
			var strip := maxf(absf(a), absf(b))
			var c := base
			if strip < 0.32:
				c = Color("6b3d10")          # a hole
			elif absf(a) > absf(b):
				c = base.lightened(0.08)
			else:
				c = base.darkened(0.12)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex


static func shadow_material() -> StandardMaterial3D:
	if _shadow_mat:
		return _shadow_mat
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			img.set_pixel(x, y, Color(0, 0, 0, clampf(1.0 - d, 0.0, 1.0) * 0.55))
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.albedo_texture = ImageTexture.create_from_image(img)
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_mat.render_priority = -1
	return _shadow_mat


## Sends the ball from p0 at velocity v at match time t0. Its flight is worked out from these (pos_at), not stepped,
## so where it will be is exactly where it goes.
func launch(p0: Vector3, v: Vector3, t0: float, trail := false) -> void:
	p_launch = p0
	v_launch = v
	t_launch = t0
	vel = v
	flying = true
	global_position = p0
	spin = Vector3(randf_range(-20, 20), randf_range(-10, 10), randf_range(-20, 20))
	_trail_on = 0.5 if trail else 0.0


func hold(p: Vector3) -> void:
	flying = false
	vel = Vector3.ZERO
	global_position = p


## Moves the ball to where its flight has it at match time t.
func update_to(t: float, dt: float) -> void:
	if flying:
		var k := t - t_launch
		global_position = Ball.pos_at(p_launch, v_launch, k)
		vel = v_launch + Vector3(0, -G * k, 0)
		_mesh.rotation += spin * dt


func _process(delta: float) -> void:
	var p := global_position
	_shadow.global_position = Vector3(p.x, 0.012, p.z)
	_shadow.scale = Vector3.ONE * clampf(1.0 - maxf(0.0, p.y) * 0.12, 0.45, 1.0)
	_trail_on = maxf(0.0, _trail_on - delta)
	for i in _trail.size():
		var t := _trail[i]
		t.visible = _trail_on > 0.0 and flying
		if t.visible:
			t.global_position = p - vel * (0.016 * (i + 1))


## Where the ball will be at match time t, if nothing touches it.
func at(t: float) -> Vector3:
	return Ball.pos_at(p_launch, v_launch, t - t_launch)


## When (match time) the ball comes down through height h, or -1.
func when_height(h: float) -> float:
	var k := Ball.fall_time(p_launch.y, v_launch.y, h)
	return t_launch + k if k >= 0.0 else -1.0


## When (match time) the ball crosses the net's plane, or -1.
func when_net() -> float:
	if absf(v_launch.x) < 0.001 or absf(p_launch.x) < 0.0001:
		return -1.0
	var k := -p_launch.x / v_launch.x
	return t_launch + k if k > 0.0 else -1.0


static func fall_time(y0: float, vy: float, h: float) -> float:
	# y0 + vy t - g/2 t^2 = h, the later root.
	var a := -0.5 * G
	var disc := vy * vy - 4.0 * a * (y0 - h)
	if disc < 0.0:
		return -1.0
	var t := (-vy - sqrt(disc)) / (2.0 * a)
	return t if t >= 0.0 else -1.0


## The launch velocity that carries a ball from p0 up to an apex at height apex_y and down through p1 (p1.y is the
## height it is met at). Returns [velocity, flight time].
static func solve_apex(p0: Vector3, p1: Vector3, apex_y: float) -> Array:
	apex_y = maxf(apex_y, maxf(p0.y, p1.y) + 0.05)
	var vy := sqrt(2.0 * G * (apex_y - p0.y))
	var t_up := vy / G
	var t_down := sqrt(2.0 * (apex_y - p1.y) / G)
	var t := t_up + t_down
	var flat := Vector3(p1.x - p0.x, 0, p1.z - p0.z) / t
	return [Vector3(flat.x, vy, flat.z), t]


## The launch velocity that carries a ball from p0 to p1 in exactly t seconds (a spike, driven down). Returns
## [velocity, t].
static func solve_time(p0: Vector3, p1: Vector3, t: float) -> Array:
	var v := (p1 - p0) / t + Vector3(0, 0.5 * G * t, 0)
	return [v, t]


## Where a ball launched from p0 at v is after t seconds.
static func pos_at(p0: Vector3, v: Vector3, t: float) -> Vector3:
	return p0 + v * t + Vector3(0, -0.5 * G * t * t, 0)
