class_name Sliotar
extends Node3D
## The sliotar: a cork-cored ball in white leather with a raised rim, 69-72 mm across and 110-116 g (the 2022
## specification). It flies under gravity and air drag (fly), bounces on the grass and rolls to a stop, so where it
## will come down can be worked out ahead (predict, landing) and players can go for it. It is small and fast, so on a
## phone the HUD also marks it (a dot and its shadow on the grass); the mesh is drawn a little larger than it is.

const G := 9.81
const RADIUS := 0.0355
const MASS := 0.113
## Drag: a = K v^2, K = rho Cd A / 2m = 1.2 * 0.5 * pi * 0.0355^2 / (2 * 0.113) ~ 0.0105 per metre. A puck-out struck
## at 40 m/s carries 85-95 m with it, as long puck-outs do.
const K_DRAG := 0.0105
const RESTITUTION := 0.42     # the vertical bounce off firm grass
const ROLL_DECEL := 2.6       # m/s^2 on the ground
const LOOK_SCALE := 2.2

enum {FREE, HELD, ON_STICK, DEAD, OUT}   # OUT: dead, but still flying on (over the end line into a net)

## What stops a ball over the end line, set by the ground (Stadium.backstop): the goal's net (sloping back from the bar
## to the ground Pitch.NET_DEPTH behind the line) and, further back, the ball-stop net or the terrace: [distance behind the line, half its
## width, its height].
var backstop := Vector3(9.0, 24.0, 14.0)


var state := FREE
var vel := Vector3.ZERO
var holder: Node = null       # the Player holding it or carrying it on his hurley
var last_touch: Node = null   # the Player who last played it
var last_team := -1
var last_kind := ""           # how it was last played: "strike", "hand_pass", "kick", "puck_out", "free", "65",
                              # "sideline", "penalty", "deflect", "throw_in"
var spin := 0.0
var _mesh: MeshInstance3D
var _shadow: MeshInstance3D
var _prev := Vector3.ZERO

static var _mat: StandardMaterial3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	_mesh.mesh = sm
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.albedo_color = Color(0.98, 0.97, 0.92)
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.scale = Vector3.ONE * LOOK_SCALE
	add_child(_mesh)
	_shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	q.orientation = PlaneMesh.FACE_Y
	_shadow.mesh = q
	var shm := StandardMaterial3D.new()
	shm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shm.albedo_color = Color(0, 0, 0, 0.45)
	_shadow.material_override = shm
	_shadow.top_level = true
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)


## One step of flight from p with velocity v over dt: gravity and drag, then the ground. Returns [p, v, bounced].
static func fly(p: Vector3, v: Vector3, dt: float) -> Array:
	var bounced := false
	if p.y <= RADIUS + 0.001 and absf(v.y) < 0.6:
		# Rolling: friction slows it on the grass.
		v.y = 0.0
		p.y = RADIUS
		var hv := Vector3(v.x, 0, v.z)
		var sp := hv.length()
		if sp > 0.0:
			hv = hv / sp * maxf(0.0, sp - ROLL_DECEL * dt)
		v = hv
		p += v * dt
		return [p, v, false]
	var sp := v.length()
	var a := Vector3(0, -G, 0) - v * (K_DRAG * sp)
	v += a * dt
	p += v * dt
	if p.y < RADIUS:
		p.y = RADIUS
		if v.y < 0.0:
			v.y = -v.y * RESTITUTION
			v.x *= 0.72
			v.z *= 0.72
			bounced = true
	return [p, v, bounced]


## Where a ball from p with velocity v is after t seconds (stepped at 1/60 s).
static func predict(p: Vector3, v: Vector3, t: float) -> Vector3:
	var steps := int(ceil(t * 60.0))
	var dt := t / maxf(1, steps)
	for i in steps:
		var r := fly(p, v, dt)
		p = r[0]
		v = r[1]
	return p


## The path ahead: [[t, p, v], ...] every 1/30 s for up to max_t seconds, until it stops.
static func path(p: Vector3, v: Vector3, max_t := 6.0) -> Array:
	var out := [[0.0, p, v]]
	var dt := 1.0 / 30.0
	var t := 0.0
	while t < max_t:
		for i in 2:
			var r := fly(p, v, dt * 0.5)
			p = r[0]
			v = r[1]
		t += dt
		out.append([t, p, v])
		if p.y <= RADIUS + 0.001 and v.length() < 0.3:
			break
	return out


## Where and when it first comes down to height h (on its way down), or [] if it does not.
static func first_at_height(p: Vector3, v: Vector3, h: float, max_t := 6.0) -> Array:
	var prev := p
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < max_t:
		var r := fly(p, v, dt)
		prev = p
		p = r[0]
		v = r[1]
		t += dt
		if v.y < 0.0 and prev.y >= h and p.y < h:
			return [t, p, v]
		if p.y <= RADIUS + 0.001 and v.length() < 0.3:
			break
	return []


## The launch velocity that sends a ball from a to pass through b, at the given speed (the flatter of the two
## arcs, or the higher one when lob is true). Searched by angle, since drag has no closed form. [] if out of reach.
static func solve(a: Vector3, b: Vector3, speed: float, lob := false) -> Array:
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var dist := flat.length()
	if dist < 0.01:
		return [Vector3(0, speed, 0), 0.0]
	var dir := flat / dist
	var best := []
	var best_err := 1e9
	var angles := range(-5, 71, 1) if not lob else range(70, 9, -1)
	for deg in angles:
		var th := deg_to_rad(float(deg))
		var v := dir * cos(th) * speed + Vector3(0, sin(th) * speed, 0)
		var r := _height_at(a, v, dist, dir)
		if r.is_empty():
			continue
		var err := absf(float(r[0]) - b.y)
		if err < best_err:
			best_err = err
			best = [v, float(r[1])]
		if err < 0.15:
			break
	if best_err > 1.0:
		return []
	return best


## The height a ball reaches at horizontal distance dist along dir, and when: [] if it never gets there in the air.
static func _height_at(p: Vector3, v: Vector3, dist: float, dir: Vector3) -> Array:
	var start := p
	var dt := 1.0 / 60.0
	var t := 0.0
	var prev := p
	while t < 6.0:
		var r := fly(p, v, dt)
		prev = p
		p = r[0]
		v = r[1]
		t += dt
		var d := (p - start).dot(dir)
		if d >= dist:
			var pd := (prev - start).dot(dir)
			var k := (dist - pd) / maxf(0.0001, d - pd)
			return [lerpf(prev.y, p.y, k), t]
		if p.y <= RADIUS + 0.002 and bool(r[2]) == false and v.y == 0.0:
			return []
	return []


func launch(v: Vector3, by: Node, kind: String) -> void:
	state = FREE
	holder = null
	vel = v
	last_touch = by
	last_team = int(by.team) if by != null else -1
	last_kind = kind
	spin = v.length() * 3.0


func place(p: Vector3) -> void:
	state = DEAD
	holder = null
	vel = Vector3.ZERO
	global_position = Vector3(p.x, RADIUS, p.z)
	_prev = global_position


## Drawn at p, its shadow under it (a replay shows where it was).
func show_at(p: Vector3) -> void:
	global_position = p
	_shadow.global_position = Vector3(p.x, 0.015, p.z)
	_shadow.visible = true


## The match moves it: in flight, held, on a hurley or placed. Returns the crossing of an end or side line this step
## (prev and now), for the match to judge.
func step(dt: float) -> Array:
	_prev = global_position
	if state == FREE or state == OUT:
		var p := global_position
		var v := vel
		# Two half steps: a hard strike moves 0.8 m a frame at 60 fps.
		var bounced := false
		for i in 2:
			var r := fly(p, v, dt * 0.5)
			p = r[0]
			v = r[1]
			bounced = bounced or bool(r[2])
		vel = v
		global_position = p
		if state == OUT:
			_nets()
		if bounced and vel.length() > 3.0:
			Sfx.play("bounce", -14.0 + minf(8.0, vel.length() * 0.3), randf_range(0.95, 1.08))
	_mesh.rotate_x(spin * dt)
	_shadow.global_position = Vector3(global_position.x, 0.015, global_position.z)
	_shadow.visible = state == FREE or state == DEAD or state == OUT
	return [_prev, global_position]


## A dead ball flying on over the end line: into the goal's net if it went in under the bar (the net takes the pace
## off it and it drops), else on into the ball-stop net or the terrace behind, which stops it the same way.
func _nets() -> void:
	var p := global_position
	var s := signf(p.x)
	var past := absf(p.x) - Pitch.HALF_L
	var was := absf(_prev.x) - Pitch.HALF_L
	var in_mouth := absf(p.z) < Pitch.POST_GAP * 0.5 + 0.2 and p.y < Pitch.BAR_H + 0.2
	# The goal net slopes from the crossbar down to the ground NET_DEPTH behind the line.
	var depth := maxf(0.3, Pitch.NET_DEPTH * (1.0 - clampf(p.y / Pitch.BAR_H, 0.0, 1.0)))
	if in_mouth and past > depth and was <= depth + 0.6:
		_net_hit(s * (Pitch.HALF_L + depth))
	elif past > backstop.x and was <= backstop.x + 0.05 and absf(p.z) < backstop.y and p.y < backstop.z:
		_net_hit(s * (Pitch.HALF_L + backstop.x))


func _net_hit(x: float) -> void:
	Sfx.play("bounce", -16.0, 0.6)     # the soft thump of a net
	global_position.x = x
	vel = Vector3(-vel.x * 0.1, vel.y * 0.35, vel.z * 0.35)
	spin *= 0.3


func prev_pos() -> Vector3:
	return _prev


func on_ground() -> bool:
	return global_position.y <= RADIUS + 0.05


func speed() -> float:
	return vel.length()
