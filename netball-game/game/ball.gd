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
## long shoulder pass at 11.5-16 (a 20 m one in the air about 1.4 s, its top 2 m and more over the hands); a lob up
## 1.6-2.8 m over the hands (higher still if a long one would otherwise cross the floor faster than FLAT_MAX), hanging
## for over a second; a bounce pass down to the floor 62% of the way, off it at 80% of its speed across; a shot
## released at 48 degrees from the circle's edge, steeper nearer the post, dropping into the ring from at least 45 cm
## above it. No throw crosses the floor faster than FLAT_MAX.
##
## A ball nobody catches goes on as it was going and falls: past the catch the flight's own parabola carries on, and
## a pass she does not reach, a deflection, a fumble, a rebound or a ball in the air when the whistle goes is let go
## loose (or dead) at the speed it had, gravity on it, to bounce and roll to a stop (_fall). Nothing moves the ball at
## a constant speed or holds it in the air.

## The ball meets the floor: at, and how fast it came down (m/s). A bounce pass, a loose ball bouncing.
signal bounced(at: Vector3, speed: float)

const R := 0.112
const G := 9.81
const NET_DEPTH := 0.42      # the net hangs this far under the ring (Arena)
const BOUNCE_E := 0.62       # how much of its speed down a ball keeps off the floor
const FLAT_MAX := 16.0       # m/s: the fastest any throw crosses the floor (an elite long pass is released at ~17-19)

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
var f_kind := ""             # the throw (a shot stops on the ring: Match takes it on from there)
var _bounced := false        # the bounce pass has hit the floor
var _moving := false         # dead, but still falling or rolling (Ball.dead)
var carrier: Player = null   # dead, in the hands of the player who had it when the whistle went (Ball.dead)
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
	carrier = null
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
			# (A long one goes higher, never faster across than FLAT_MAX.)
			while h < 12.0 and _lob_t(h, from, to) < d / FLAT_MAX:
				h += 0.1
			return _one(from, to, _lob_t(h, from, to))
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
			return _one(from, to, d / clampf(8.5 + 0.3 * d, 11.5, FLAT_MAX))
	return _one(from, to, d / clampf(8.5 + 0.4 * d, 9.0, 13.0))


static func _lob_t(h: float, from: Vector3, to: Vector3) -> float:
	return sqrt(2.0 * h / G) + sqrt(2.0 * maxf(from.y + h - to.y, 0.0) / G)


static func _one(from: Vector3, to: Vector3, t: float) -> Dictionary:
	t = maxf(t, maxf(0.05, Vector2(to.x - from.x, to.z - from.z).length() / FLAT_MAX))
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
	carrier = null
	holder = null
	state = "flight"
	f_from = from
	f_to = to
	f_t = 0.0
	f_dur = float(pl.dur)
	f_legs = pl.legs
	f_bounce = float(pl.bounce)
	f_kind = kind
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


## The flight's own parabola t seconds into it, carried on past its end (where nobody has caught it).
func _flight_pos(t: float) -> Vector3:
	var lg := _leg_at(f_legs, t)
	var s := t - float(lg[0])
	return Vector3(lg[1]) + Vector3(lg[2]) * s + Vector3(0, -0.5 * G * s * s, 0)


## How fast it is going now (m/s): in flight, on its parabola; loose or dead, as it moves; held, not at all.
func velocity() -> Vector3:
	match state:
		"flight":
			if f_legs.is_empty():
				return Vector3.ZERO
			var lg := _leg_at(f_legs, f_t)
			return Vector3(lg[2]) + Vector3(0, -G * (f_t - float(lg[0])), 0)
		"loose", "dead":
			return vel
	return Vector3.ZERO


## Let go loose, moving at v (a deflection, a rebound, a fumble).
func loose(at: Vector3, v: Vector3) -> void:
	carrier = null
	holder = null
	state = "loose"
	pos = at
	vel = v


## Out of play at `at`. moving: the whistle has gone with the ball in the air or rolling, and it goes on as it was
## going and falls (a dead ball still obeys gravity); by: it was in her hands, and stays there (she keeps it until
## she hands it on: toss); otherwise it is put there, still (a restart's spot). Never left hanging in the air.
func dead(at: Vector3, moving := false, by: Player = null) -> void:
	var v := velocity() if moving else Vector3.ZERO
	holder = null
	carrier = by
	state = "dead"
	pos = at
	vel = v
	_moving = moving and by == null


## A dead ball handed on: tossed from where it is to land at `to` (on the floor) in t seconds, under gravity; it
## bounces and rolls on from there (the player who had it gives it to the one taking the restart).
func toss(to: Vector3, t: float) -> void:
	t = maxf(t, 0.2)
	carrier = null
	holder = null
	state = "dead"
	vel = (to - pos) / t
	vel.y += 0.5 * G * t
	_moving = true


## The one place the ball's position changes, once a frame.
func step(dt: float) -> void:
	match state:
		"held":
			if holder:
				pos = holder.hand_point()
		"flight":
			f_t += dt
			# (A pass nobody has caught yet carries on along its parabola past the catch point, for the frame before
			# Match sees it arrive; a shot stops on the ring, where Match takes it on.)
			pos = _flight_pos(f_t) if f_kind != "shot" and not f_legs.is_empty() else flight_at(f_t / f_dur)
			if f_bounce > 0.0 and not _bounced and f_t / f_dur >= f_bounce:
				_bounced = true
				bounced.emit(Vector3(pos.x, R, pos.z), absf(flight_vel(f_bounce - 0.001).y))
			_mesh.rotate(_spin.normalized() if _spin.length() > 0 else Vector3.RIGHT, _spin.length() * dt)
		"loose":
			_fall(dt)
		"dead":
			if carrier and is_instance_valid(carrier):
				pos = carrier.hand_point()
			elif carrier:
				carrier = null
				_moving = true
			elif _moving:
				_fall(dt)
				_moving = pos.y > R + 0.001 or vel.length_squared() > 1e-6
	position = pos


## Loose (or dead and still moving): gravity, the nets, the floor.
func _fall(dt: float) -> void:
	var vy0 := vel.y
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
	# (Its height by the mean of its speed down over the step: exactly the parabola a flight would have drawn.)
	var was := pos
	pos += Vector3(vel.x, 0.5 * (vy0 + vel.y), vel.z) * dt
	if pos.y < R:
		# It met the floor during the step: where and when, exactly; off it from there for the rest of the step.
		var a := vy0 * vy0 + 2.0 * G * maxf(was.y - R, 0.0)
		var t := clampf((vy0 + sqrt(a)) / G, 0.0, dt) if vy0 < 0.0 or was.y > R else 0.0
		var hit := Vector3(was.x + vel.x * t, R, was.z + vel.z * t)
		var down := vy0 - G * t
		vel.x *= 0.9
		vel.z *= 0.9
		pos = hit
		if down < -0.6:
			bounced.emit(hit, -down)
			var up := -down * BOUNCE_E
			var rest := dt - t
			vel.y = up - G * rest
			pos += Vector3(vel.x * rest, maxf(0.0, (up - 0.5 * G * rest) * rest), vel.z * rest)
		else:
			vel.y = 0.0
			pos += Vector3(vel.x, 0.0, vel.z) * (dt - t)
	# Rolling on: the floor slows it.
	if pos.y <= R + 0.001:
		var flat := Vector2(vel.x, vel.z)
		flat = flat.move_toward(Vector2.ZERO, 2.5 * dt)
		vel.x = flat.x
		vel.z = flat.y
	_mesh.rotate(Vector3(vel.z, 0, -vel.x).normalized() if Vector2(vel.x, vel.z).length() > 0.01 else Vector3.RIGHT, Vector2(vel.x, vel.z).length() / R * dt)


func court_pos() -> Vector2:
	return Vector2(pos.x, pos.z)
