class_name Ball
extends Node3D
## The ball: a woven synthetic sphere, flying under gravity alone, so where it will be is known exactly (at(), and
## the time it reaches a height or crosses the net) and the players can plan their touches. Once a rally is over it
## is loose: it falls, bounces, rolls to a stop and comes off the venue's walls and boards (bounds), stepped frame by
## frame, until a player picks it up (carried: it goes where his hands are).

const G := 9.81
const RADIUS := 0.068     # 0.43 m round
const LOOK_SCALE := 1.7
const MODEL := "res://assets/models/ball.glb"
const MODEL_RADIUS := 0.93   # the model's size

var vel := Vector3.ZERO
var flying := false
var spin_axis := Vector3.RIGHT   # the ball turns about this (world space), spin_rate rad/s: for the look of it
var spin_rate := 0.0
var p_launch := Vector3.ZERO
var v_launch := Vector3.ZERO
var t_launch := 0.0
var loose := false          # the rally is over: bouncing and rolling by itself
var bounds := Rect2(-12.0, -9.0, 24.0, 18.0)   # x and z the walls and boards keep it within (Arena.bounds)
var soft := false           # on sand: it hardly bounces and stops soon
var _mesh: MeshInstance3D
var _shadow: MeshInstance3D
var _trail: Array[MeshInstance3D] = []
var _trail_on := 0.0

static var _shadow_mat: StandardMaterial3D
static var _model: Mesh
static var _model_mat: StandardMaterial3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = model()
	_mesh.material_override = model_material()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Drawn a little larger than it is, so it reads on a phone from the broadcast camera's seat; it flies, and is met,
	# at its true size.
	_mesh.scale = Vector3.ONE * LOOK_SCALE * RADIUS / MODEL_RADIUS
	add_child(_mesh)
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	sm.radial_segments = 12
	sm.rings = 6
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


## The ball's model: woven strips with the holes between them.
static func model() -> Mesh:
	if _model == null:
		var scene: Node = (load(MODEL) as PackedScene).instantiate()
		_model = (scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
		scene.free()
	return _model


static func model_material() -> StandardMaterial3D:
	if _model_mat == null:
		_model_mat = StandardMaterial3D.new()
		_model_mat.albedo_texture = load("res://assets/models/ball.jpg")
		_model_mat.roughness = 0.55
		_model_mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # through a hole, the inside of the far side
	return _model_mat


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
	loose = false
	p_launch = p0
	v_launch = v
	t_launch = t0
	vel = v
	flying = true
	global_position = p0
	# Kicked, it turns over the way it goes (mostly topspin, now and then back), a little off square, faster the
	# harder it was hit (kept slow enough that its weave doesn't seem to stand still).
	var flat := Vector3(v.x, 0, v.z)
	var axis := flat.cross(Vector3.UP).normalized() if flat.length() > 0.2 else Vector3.RIGHT
	axis = axis.rotated(Vector3.UP, randf_range(-0.5, 0.5)) + Vector3(0, randf_range(-0.35, 0.35), 0)
	spin_axis = axis.normalized()
	spin_rate = clampf(v.length() * 0.8, 5.0, 16.0) * (1.0 if randf() < 0.75 else -1.0)
	_trail_on = 0.5 if trail else 0.0


func hold(p: Vector3) -> void:
	flying = false
	loose = false
	vel = Vector3.ZERO
	global_position = p


## The rally is over (at match time t): from here it goes where it was going by itself (falls, bounces, rolls),
## never left hanging in the air.
func set_loose(t: float) -> void:
	if flying:
		var k := t - t_launch
		global_position = Ball.pos_at(p_launch, v_launch, k)
		vel = v_launch + Vector3(0, -G * k, 0)
	flying = false
	loose = true


## Moves the ball to where its flight has it at match time t; loose, a step of its bounces and roll.
func update_to(t: float, dt: float) -> void:
	if loose:
		_step_loose(dt)
		return
	if flying:
		var k := t - t_launch
		global_position = Ball.pos_at(p_launch, v_launch, k)
		vel = v_launch + Vector3(0, -G * k, 0)
		turn(dt)
		# Down on the floor (the rally is over by now): from here it bounces and rolls by itself.
		if global_position.y < RADIUS and vel.y < 0.0:
			global_position.y = RADIUS
			flying = false
			loose = true
			_floor_bounce()


signal bounced(at: Vector3, speed: float)   # off the floor or a wall, after a rally: for its sound

const BOUNCE := 0.5         # how much of its speed into the floor it bounces back with (sand: far less)
const ROLL_DRAG := 1.6      # m/s each second rolling on a court (sand: far more)


## Loose: gravity, the floor, the walls; rolling, it slows and turns over as it goes. Small steps, so a fast ball
## can't pass through a wall in one frame.
func _step_loose(dt: float) -> void:
	var n := maxi(1, ceili(dt / 0.01))
	var h := dt / float(n)
	for i in n:
		var p := global_position
		if p.y > RADIUS + 0.0005 or vel.y > 0.0:
			vel.y -= G * h
			p += vel * h
			if p.y <= RADIUS:
				p.y = RADIUS
				global_position = p
				_floor_bounce()
				p = global_position
		else:
			var flat := Vector2(vel.x, vel.z)
			var sp := maxf(0.0, flat.length() - ROLL_DRAG * (4.0 if soft else 1.0) * h)
			flat = flat.normalized() * sp if sp > 0.0 else Vector2.ZERO
			vel = Vector3(flat.x, 0.0, flat.y)
			p += vel * h
		# The walls and boards: off them, with most of its speed lost.
		var hit := 0.0
		if p.x < bounds.position.x + RADIUS or p.x > bounds.end.x - RADIUS:
			p.x = clampf(p.x, bounds.position.x + RADIUS, bounds.end.x - RADIUS)
			hit = absf(vel.x)
			vel.x = -vel.x * 0.4
			vel.z *= 0.8
		if p.y <= RADIUS + 0.4 and (p.z < bounds.position.y + RADIUS or p.z > bounds.end.y - RADIUS):
			p.z = clampf(p.z, bounds.position.y + RADIUS, bounds.end.y - RADIUS)
			hit = maxf(hit, absf(vel.z))
			vel.z = -vel.z * 0.4
			vel.x *= 0.8
		elif p.z < bounds.position.y - 0.5 or p.z > bounds.end.y + 0.5:
			p.z = clampf(p.z, bounds.position.y - 0.5, bounds.end.y + 0.5)   # (over a low board: it stops at the stand)
			hit = maxf(hit, absf(vel.z))
			vel.z = -vel.z * 0.3
		global_position = p
		if hit > 1.0:
			bounced.emit(p, hit)
	# Rolling: it turns over the way it goes.
	var flat_v := Vector3(vel.x, 0, vel.z)
	if flat_v.length() > 0.05 and global_position.y <= RADIUS + 0.01:
		spin_axis = Vector3.UP.cross(flat_v).normalized()
		spin_rate = flat_v.length() / (RADIUS * LOOK_SCALE)
	elif global_position.y <= RADIUS + 0.01:
		spin_rate = 0.0
	turn(dt)


func _floor_bounce() -> void:
	var into := -vel.y
	var up := into * BOUNCE * (0.35 if soft else 1.0)
	vel = Vector3(vel.x * (0.45 if soft else 0.78), up if up > 0.5 else 0.0, vel.z * (0.45 if soft else 0.78))
	if into > 1.2:
		bounced.emit(global_position, into)


## Loose and come to rest on the floor (or carried, or held).
func settled() -> bool:
	return not flying and (not loose or (global_position.y <= RADIUS + 0.01 and vel.length() < 0.05))


## Turns the ball by its spin over dt (s): in flight, and in a replay.
func turn(dt: float) -> void:
	if spin_rate != 0.0:
		_mesh.global_rotate(spin_axis, spin_rate * dt)


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
