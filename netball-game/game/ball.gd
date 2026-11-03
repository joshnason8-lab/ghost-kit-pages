class_name Ball
extends Node3D
## The ball: a size 5 netball (690-710 mm round, so 0.112 m across the radius), panelled. It is held in a player's
## hands, in flight on a pass or a shot, loose (bouncing and rolling) or dead. Its position is written only in step(),
## once a frame.
##
## A flight is real projectile motion: gravity at 9.81 m/s² and nothing else (a netball's air drag over a pass is a few
## per cent of its speed), so the ball keeps its speed across the floor and falls as a ball falls. Each kind of throw
## is solved from where it leaves the hands to where it is caught (plan()), and its time follows from the distance and
## how that throw goes, never a fixed duration: a chest pass at 9-13 m/s across the floor (harder the longer it is), a
## long shoulder pass at 12-16; a lob up 1.6-2.8 m over the hands, hanging for over a second; a bounce pass down to the
## floor 62% of the way, off it at 80% of its speed across; a shot released at 48 degrees from the circle's edge,
## steeper nearer the post, dropping into the ring from at least 45 cm above it.

## The ball meets the floor: at, and how fast it came down (m/s). A bounce pass, a loose ball bouncing.
signal bounced(at: Vector3, speed: float)

const R := 0.112
const G := 9.81
const NET_DEPTH := 0.42      # the net hangs this far under the ring (Arena)

var state := "dead"          # held, flight, loose, dead
var holder: Player = null
var pos := Vector3(0, R, 0)
var vel := Vector3.ZERO
# A flight: from, to, how long, and its legs (one; two for a bounce pass), each [start time, p0, v0]: the parabola
# p0 + v0 s - g s²/2, s the time since that leg began.
var f_from := Vector3.ZERO
var f_to := Vector3.ZERO
var f_t := 0.0
var f_dur := 1.0
var f_legs: Array = []
var f_bounce := -1.0         # 0-1 of the flight's time when a bounce pass meets the floor, or -1
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


## The flight of a throw of `kind` (chest, shoulder, bounce, lob, shot) from `from` to `to`: {dur, legs, bounce}, as
## the header describes it.
static func plan(kind: String, from: Vector3, to: Vector3) -> Dictionary:
	var d := maxf(Vector2(to.x - from.x, to.z - from.z).length(), 0.01)
	match kind:
		"lob":
			# Up over the defender, 1.6-2.8 m over the hands (more for a longer one), and down onto the catch.
			var h := maxf(clampf(1.5 + 0.1 * d, 1.6, 2.8), to.y - from.y + 0.6)
			return _one(from, to, sqrt(2.0 * h / G) + sqrt(2.0 * (from.y + h - to.y) / G))
		"bounce":
			var vh := clampf(7.0 + 0.4 * d, 8.0, 10.0)
			var at := from.lerp(to, 0.62)
			at.y = R
			var t1 := 0.62 * d / vh
			var t2 := 0.38 * d / (vh * 0.8)
			return {"dur": t1 + t2, "legs": [_leg(from, at, t1, 0.0), _leg(at, to, t2, t1)], "bounce": t1 / (t1 + t2)}
		"shot":
			var dy := to.y - from.y
			var a := deg_to_rad(lerpf(58.0, 48.0, clampf((d - 1.0) / 3.9, 0.0, 1.0)))
			var lift := d * tan(a) - dy
			var t := 0.0
			if lift > 0.05:
				var v := sqrt(G * d * d / (2.0 * cos(a) * cos(a) * lift))
				var vy := v * sin(a)
				if from.y + vy * vy / (2.0 * G) - to.y >= 0.45:
					t = d / (v * cos(a))
			if t == 0.0:
				# Close in: high enough to drop in, its top 45 cm over the ring.
				t = sqrt(2.0 * maxf(to.y + 0.45 - from.y, 0.05) / G) + sqrt(2.0 * 0.45 / G)
			return _one(from, to, t)
		"shoulder":
			return _one(from, to, d / clampf(10.0 + 0.3 * d, 12.0, 16.0))
	return _one(from, to, d / clampf(8.5 + 0.4 * d, 9.0, 13.0))


static func _one(from: Vector3, to: Vector3, t: float) -> Dictionary:
	t = maxf(t, 0.05)
	return {"dur": t, "legs": [_leg(from, to, t, 0.0)], "bounce": -1.0}


## The parabola from a to b in t seconds under gravity, beginning t0 into the flight: [t0, a, its velocity at a].
static func _leg(a: Vector3, b: Vector3, t: float, t0: float) -> Array:
	t = maxf(t, 0.02)
	var v := (b - a) / t
	v.y += 0.5 * G * t
	return [t0, a, v]


## Where a flight puts the ball k (0-1) of the way through its time, and how fast it is going there.
static func plan_at(pl: Dictionary, k: float) -> Vector3:
	var lg := _leg_at(pl.legs, clampf(k, 0.0, 1.0) * float(pl.dur))
	var s := clampf(k, 0.0, 1.0) * float(pl.dur) - float(lg[0])
	return Vector3(lg[1]) + Vector3(lg[2]) * s + Vector3(0, -0.5 * G * s * s, 0)


static func plan_vel(pl: Dictionary, k: float) -> Vector3:
	var lg := _leg_at(pl.legs, clampf(k, 0.0, 1.0) * float(pl.dur))
	return Vector3(lg[2]) + Vector3(0, -G * (clampf(k, 0.0, 1.0) * float(pl.dur) - float(lg[0])), 0)


static func _leg_at(legs: Array, t: float) -> Array:
	var lg: Array = legs[0]
	for l: Array in legs:
		if t >= float(l[0]):
			lg = l
	return lg


## A pass or shot: a throw of `kind` from `from` to `to` (plan()). Returns its plan.
func throw(kind: String, from: Vector3, to: Vector3) -> Dictionary:
	var pl := plan(kind, from, to)
	holder = null
	state = "flight"
	f_from = from
	f_to = to
	f_t = 0.0
	f_dur = float(pl.dur)
	f_legs = pl.legs
	f_bounce = float(pl.bounce)
	_bounced = false
	pos = from
	_spin = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 8.0
	return pl


## Where the ball will be k (0-1) of the way along its flight.
func flight_at(k: float) -> Vector3:
	if f_legs.is_empty():
		return f_from.lerp(f_to, clampf(k, 0.0, 1.0))
	return plan_at({"dur": f_dur, "legs": f_legs}, k)


## How fast it is going k (0-1) of the way along its flight (m/s).
func flight_vel(k: float) -> Vector3:
	if f_legs.is_empty():
		return Vector3.ZERO
	return plan_vel({"dur": f_dur, "legs": f_legs}, k)


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
				bounced.emit(Vector3(pos.x, R, pos.z), absf(flight_vel(f_bounce - 0.001).y))
			_mesh.rotate(_spin.normalized() if _spin.length() > 0 else Vector3.RIGHT, _spin.length() * dt)
		"loose":
			vel.y -= G * dt
			# Through a net: the cords hold it back as it drops through, and steer it down the middle.
			for side: int in [-1, 1]:
				var rc := Court.ring_centre(side)
				var off := Vector2(pos.x - rc.x, pos.z - rc.z)
				if off.length() < Court.RING_R and pos.y < rc.y + 0.02 and pos.y > rc.y - NET_DEPTH:
					var hold := exp(-7.0 * dt)
					vel.x = vel.x * hold - off.x * 12.0 * dt
					vel.z = vel.z * hold - off.y * 12.0 * dt
					vel.y = maxf(vel.y, -1.7)
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
