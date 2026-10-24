class_name Ball
extends Node3D
## The ball: a size 5 netball (690-710 mm round, so 0.112 m across the radius), panelled. It is held in a player's
## hands, in flight on a pass or a shot (a path solved from where it leaves the hands to where it is caught), loose
## (bouncing and rolling) or dead. Its position is written only in step(), once a frame.

## The ball meets the floor: at, and how fast it came down (m/s). A bounce pass, a loose ball bouncing.
signal bounced(at: Vector3, speed: float)

const R := 0.112
const G := 9.81

var state := "dead"          # held, flight, loose, dead
var holder: Player = null
var pos := Vector3(0, R, 0)
var vel := Vector3.ZERO
# A flight: from, to, how long, where the bounce is (a bounce pass), how high it goes.
var f_from := Vector3.ZERO
var f_to := Vector3.ZERO
var f_t := 0.0
var f_dur := 1.0
var f_apex := 0.0
var f_bounce := -1.0         # 0-1 along the flight where a bounce pass hits the floor, or -1
var _bounced := false        # the bounce pass has hit the floor
var _mesh: MeshInstance3D
var _spin := Vector3.ZERO

static var _tex: ImageTexture


## The ball's panels: white with a lime and violet band, drawn once.
static func texture() -> ImageTexture:
	if _tex:
		return _tex
	var w := 128
	var h := 64
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := float(x) / w
			var v := float(y) / h
			var c := Color("f4f2ea")
			var band := absf(v - 0.5)
			if band < 0.07:
				c = Color("c8f03c")
			elif band < 0.1:
				c = Color("3a2f6e")
			# Panel seams.
			if fposmod(u * 6.0, 1.0) < 0.03:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = R
	s.height = R * 2.0
	s.radial_segments = 16
	s.rings = 8
	_mesh.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.roughness = 0.8
	_mesh.material_override = m
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func hold(p: Player) -> void:
	holder = p
	state = "held"
	vel = Vector3.ZERO


## A pass or shot from `from` to `to`, taking dur seconds, rising apex metres over the straight line between them at
## its middle. bounce: 0-1 along the way where a bounce pass meets the floor (-1 none).
func throw(from: Vector3, to: Vector3, dur: float, apex: float, bounce := -1.0) -> void:
	holder = null
	state = "flight"
	f_from = from
	f_to = to
	f_t = 0.0
	f_dur = maxf(0.05, dur)
	f_apex = apex
	f_bounce = bounce
	_bounced = false
	pos = from
	_spin = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 8.0


## Where the ball will be k (0-1) of the way along its flight.
func flight_at(k: float) -> Vector3:
	k = clampf(k, 0.0, 1.0)
	if f_bounce > 0.0:
		var b := Vector3(f_from.lerp(f_to, f_bounce).x, R, f_from.lerp(f_to, f_bounce).z)
		if k < f_bounce:
			return f_from.lerp(b, k / f_bounce)
		var k2 := (k - f_bounce) / (1.0 - f_bounce)
		var q := b.lerp(f_to, k2)
		q.y += 4.0 * 0.35 * k2 * (1.0 - k2)
		return q
	var q := f_from.lerp(f_to, k)
	q.y += 4.0 * f_apex * k * (1.0 - k)
	return q


func flight_left() -> float:
	return maxf(0.0, f_dur - f_t)


## Let go loose, moving at v (a deflection, a rebound, a fumble).
func loose(at: Vector3, v: Vector3) -> void:
	holder = null
	state = "loose"
	pos = at
	vel = v


func dead(at: Vector3) -> void:
	holder = null
	state = "dead"
	pos = at
	vel = Vector3.ZERO


## The one place the ball's position changes, once a frame.
func step(dt: float) -> void:
	match state:
		"held":
			if holder:
				pos = holder.hand_point()
		"flight":
			f_t += dt
			pos = flight_at(f_t / f_dur)
			if f_bounce > 0.0 and not _bounced and f_t / f_dur >= f_bounce:
				_bounced = true
				bounced.emit(Vector3(pos.x, R, pos.z), f_from.distance_to(f_to) / f_dur)
			_mesh.rotate(_spin.normalized() if _spin.length() > 0 else Vector3.RIGHT, _spin.length() * dt)
		"loose":
			vel.y -= G * dt
			pos += vel * dt
			if pos.y < R:
				pos.y = R
				if vel.y < -0.6:
					bounced.emit(pos, -vel.y)
					vel.y = -vel.y * 0.62
				else:
					vel.y = 0.0
				vel.x *= 0.9
				vel.z *= 0.9
			# Rolling on: the floor slows it.
			if pos.y <= R + 0.001:
				var flat := Vector2(vel.x, vel.z)
				flat = flat.move_toward(Vector2.ZERO, 2.5 * dt)
				vel.x = flat.x
				vel.z = flat.y
			_mesh.rotate(Vector3(vel.z, 0, -vel.x).normalized() if Vector2(vel.x, vel.z).length() > 0.01 else Vector3.RIGHT, Vector2(vel.x, vel.z).length() / R * dt)
	position = pos


func court_pos() -> Vector2:
	return Vector2(pos.x, pos.z)
