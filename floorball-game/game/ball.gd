class_name Ball
extends Node3D
## The floorball: a hollow plastic sphere, 72 mm across with 26 holes, about 23 g (IFF Material Regulations). So light
## and so holed that the air takes its speed quickly: a slap shot leaves the blade at 30-45 m/s and has lost a third of
## that by the goal; a pass dies on the floor in a few seconds.
##
## This node is the only thing that writes the ball's position. A carrier's blade pulls it along (carry()); a shot or
## pass sets its velocity (strike()); the rest is flight, the floor, the boards and the goals.

signal out_of_play(exit: Vector2)          # over the boards (504)
signal crossed_goal_line(end: int, from_front: bool)
signal hit(what: String, speed: float)     # "board", "post", "net", "floor" for the sounds

const R := 0.036
const G := 9.81
const DRAG := 0.05          # per metre: 0.5 * rho * Cd * A / m, Cd 0.5 for the holed ball (fast to slow down)
const ROLL := 0.9           # rolling deceleration on a sports floor, m/s2
const FLOOR_E := 0.45       # how much of its fall a bounce keeps
const BOARD_E := 0.62
const NET_DAMP := 0.15

var pos := Vector3(0, R, 0)
var vel := Vector3.ZERO
var carrier = null          # Player dribbling it, or null
var held_by = null          # a goalkeeper holding it
var last_player = null      # who played it last
var last_team := -1
var last_how := "stick"     # stick, kick, body, head, hand, gk_throw, deflect_defender
var in_goal := 0            # the end whose net holds it (after a goal), or 0
var tries := {}             # players who have had their one try at it since it was last struck (match._pickups)
var live := true            # in play: out-of-play and goal-line checks run
var _carry_target := Vector3.ZERO
var _mesh: MeshInstance3D
var _shadow: MeshInstance3D
var _halo: MeshInstance3D
var _streak: MeshInstance3D
var _spin := Vector3.ZERO
const SHOW_K := 1.8         # the ball is drawn this much bigger than it is: 72 mm is 3 pixels from the broadcast camera
                            # on a 720p phone (the physics keep its real size)

static var _ring_tex: ImageTexture

static var _tex: ImageTexture
static var _holed: ShaderMaterial
var show_k := SHOW_K        # how much bigger it is drawn: SHOW_K for the match cameras, near life size up close


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = R
	s.height = R * 2.0
	var hi := int(Game.settings.graphics) >= Game.GFX_HIGH
	s.radial_segments = 32 if hi else 12
	s.rings = 16 if hi else 6
	_mesh.mesh = s
	if hi:
		_mesh.material_override = holed_material()
	else:
		var m := StandardMaterial3D.new()
		m.albedo_texture = texture()
		m.roughness = 0.4
		_mesh.material_override = m
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.scale = Vector3.ONE * show_k
	add_child(_mesh)
	# A bright ring on the floor round the ball, so the eye finds it in a crowd of sticks and legs.
	_halo = MeshInstance3D.new()
	var hq := PlaneMesh.new()
	hq.size = Vector2(0.62, 0.62)
	_halo.mesh = hq
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_texture = ring_texture()
	hm.albedo_color = Color(1.0, 0.93, 0.35, 0.9)
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.no_depth_test = false
	_halo.material_override = hm
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	# A short streak behind a fast ball (a shot), pointing back along its flight.
	_streak = MeshInstance3D.new()
	var sq := BoxMesh.new()
	sq.size = Vector3(0.05, 0.05, 1.0)
	_streak.mesh = sq
	var sm2 := StandardMaterial3D.new()
	sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm2.albedo_color = Color(1, 1, 1, 0.45)
	sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_streak.material_override = sm2
	_streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streak.visible = false
	add_child(_streak)
	# A soft dark spot on the floor under it, so its height reads from the broadcast camera.
	_shadow = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(0.09, 0.09)
	_shadow.mesh = q
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0, 0, 0, 0.45)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow.material_override = sm
	add_child(_shadow)
	_place()


## The halo's ring: a soft bright band, clear in the middle.
static func ring_texture() -> ImageTexture:
	if _ring_tex:
		return _ring_tex
	var n := 64
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var r := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - absf(r - 0.78) / 0.16, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	img.generate_mipmaps()
	_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex


## High: the ball as it is up close (a penalty shot's camera): white plastic, its 26 holes cut through it (11 mm
## across, spread evenly), the inside of the shell seen through them, a slight rim round each.
static func holed_material() -> ShaderMaterial:
	if _holed:
		return _holed
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
#include "res://game/shaders/look.gdshaderinc"
uniform vec3 holes[26];
varying vec3 lp;
void vertex() { lp = normalize(VERTEX); }
void fragment() {
	vec3 n = normalize(lp);
	float best = -1.0;
	for (int i = 0; i < 26; i++) {
		best = max(best, dot(n, holes[i]));
	}
	float ang = acos(clamp(best, -1.0, 1.0));
	if (ang < 0.15) {
		discard;
	}
	if (FRONT_FACING) {
		float rim = 1.0 - smoothstep(0.15, 0.24, ang);
		ALBEDO = compat_to_scene(mix(vec3(0.96, 0.965, 0.95), vec3(0.72, 0.73, 0.74), rim * 0.6));
		ROUGHNESS = 0.32;
		SPECULAR = 0.55;
	} else {
		ALBEDO = compat_to_scene(vec3(0.55, 0.56, 0.57));   // the inside of the shell
		ROUGHNESS = 0.8;
	}
}
"""
	_holed = ShaderMaterial.new()
	_holed.shader = sh
	var pts := PackedVector3Array()
	var golden := PI * (3.0 - sqrt(5.0))
	for i in 26:
		var y := 1.0 - (i + 0.5) / 26.0 * 2.0
		var r := sqrt(1.0 - y * y)
		pts.append(Vector3(cos(golden * i) * r, y, sin(golden * i) * r))
	_holed.set_shader_parameter("holes", pts)
	return _holed


## The ball's skin: white, its 26 holes as dark dots.
static func texture() -> ImageTexture:
	if _tex:
		return _tex
	var img := Image.create_empty(64, 32, false, Image.FORMAT_RGB8)
	img.fill(Color("f6f7f4"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	for i in 26:
		var c := Vector2(rng.randf() * 64.0, 3.0 + rng.randf() * 26.0)
		for y in range(-2, 3):
			for x in range(-2, 3):
				if Vector2(x, y).length() <= 1.8:
					img.set_pixel(posmod(int(c.x) + x, 64), clampi(int(c.y) + y, 0, 31), Color("3b4048"))
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex


func floor_pos() -> Vector2:
	return Vector2(pos.x, pos.z)


func speed() -> float:
	return vel.length()


## Put it somewhere still (a face-off, a free-hit's spot). Only while play is stopped.
func set_spot(p: Vector2) -> void:
	pos = Vector3(p.x, R, p.y)
	vel = Vector3.ZERO
	carrier = null
	held_by = null
	in_goal = 0
	_place()


## A player's blade has it: each frame it is drawn toward target (on the blade), quickly but not in one frame.
func carry(by, target: Vector3) -> void:
	carrier = by
	held_by = null
	_carry_target = target


func release() -> void:
	carrier = null


## A goalkeeper catches it: it sits in his hands (target) until he throws it.
func hold(by, target: Vector3) -> void:
	held_by = by
	carrier = null
	_carry_target = target


## A stick or foot plays it: velocity v, by player p of team t, how.
func strike(v: Vector3, p, t: int, how := "stick") -> void:
	carrier = null
	held_by = null
	vel = v
	last_player = p
	last_team = t
	last_how = how
	tries = {}
	_spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * v.length()


func step(dt: float) -> void:
	if held_by != null:
		pos = pos.lerp(_carry_target, minf(1.0, 18.0 * dt))
		vel = Vector3.ZERO
		_place()
		return
	if carrier != null:
		# Drawn to the blade: a stiff spring, so it follows a dribble's side to side but never jumps.
		var want := _carry_target
		want.y = R
		var to := want - pos
		var v := to * 22.0
		if v.length() > 14.0:
			v = v.normalized() * 14.0
		vel = v
		pos += vel * dt
		pos.y = R
		_collide_boards()
		_place()
		return
	var sp := vel.length()
	# The air: a drag that grows as the square of the speed.
	if sp > 0.01:
		vel -= vel * DRAG * sp * dt
	if pos.y > R + 0.002 or vel.y > 0.0:
		vel.y -= G * dt
	else:
		# Rolling on the floor.
		var h := Vector2(vel.x, vel.z)
		var hs := h.length()
		if hs > 0.0:
			h = h.normalized() * maxf(0.0, hs - ROLL * dt)
			vel.x = h.x
			vel.z = h.y
	var prev := pos
	pos += vel * dt
	if pos.y < R:
		pos.y = R
		if vel.y < -0.6:
			hit.emit("floor", -vel.y)
			vel.y = -vel.y * FLOOR_E
			vel.x *= 0.92
			vel.z *= 0.92
		else:
			vel.y = 0.0
	if in_goal != 0:
		_in_net()
	else:
		_collide_goals(prev)
		_collide_boards()
	_place()
	if sp > 0.5:
		_mesh.rotate(_spin.normalized() if _spin.length() > 0.01 else Vector3.UP, sp * dt / R * 0.5)


func _place() -> void:
	position = pos
	if _mesh:
		_mesh.scale = Vector3.ONE * show_k
	if _shadow:
		_shadow.global_position = Vector3(pos.x, 0.004, pos.z)
		var k := clampf(1.0 - pos.y * 0.5, 0.3, 1.0)
		_shadow.scale = Vector3(k, 1, k) * SHOW_K
	if _halo:
		_halo.global_position = Vector3(pos.x, 0.006, pos.z)
		_halo.visible = in_goal == 0
	if _streak:
		var sp := vel.length()
		_streak.visible = sp > 12.0 and carrier == null and held_by == null
		if _streak.visible:
			var l := clampf(sp * 0.035, 0.3, 1.4)
			var back := -vel.normalized()
			_streak.global_position = pos + back * l * 0.5
			_streak.look_at(pos + vel, Vector3.UP if absf(back.y) < 0.95 else Vector3.RIGHT)
			_streak.scale = Vector3(1, 1, l)


func _collide_boards() -> void:
	var p := floor_pos()
	if Rules.in_rink(p, R):
		return
	if pos.y > Rules.BOARD_H + R and live:
		# Over the boards: out of play (504). The hit-in goes to where it left the rink.
		live = false
		out_of_play.emit(p)
		return
	var c: Array = Rules.board_contact(p)
	var n: Vector2 = c[1]
	var back: Vector2 = c[0] + n * (R + 0.001)
	pos.x = back.x
	pos.z = back.y
	var v2 := Vector2(vel.x, vel.z)
	var vn := v2.dot(n)
	if vn < 0.0:
		var vt := v2 - n * vn
		v2 = vt * 0.88 - n * vn * BOARD_E
		vel.x = v2.x
		vel.z = v2.y
		if -vn > 1.2:
			hit.emit("board", -vn)


## The goal frames: posts and crossbar bounce it; it passes the goal line between them, under the bar, into the net
## (crossed_goal_line); the net's back and sides from outside, and the frame's outside, turn it away.
func _collide_goals(prev: Vector3) -> void:
	for end: int in [-1, 1]:
		var gx := Rules.GOAL_LINE * end
		var hw := Rules.GOAL_W * 0.5
		# Posts: vertical cylinders at (gx, +-hw).
		for side: float in [-1.0, 1.0]:
			var post := Vector2(gx, hw * side)
			var d := Vector2(pos.x, pos.z) - post
			var rr := R + 0.024
			if d.length() < rr and pos.y < Rules.GOAL_H + R:
				var n := d.normalized()
				pos.x = post.x + n.x * rr
				pos.z = post.y + n.y * rr
				var v2 := Vector2(vel.x, vel.z)
				var vn := v2.dot(n)
				if vn < 0.0:
					v2 -= n * vn * 1.7
					vel.x = v2.x
					vel.z = v2.y
					hit.emit("post", -vn)
		# Crossbar.
		if absf(pos.z) < hw and absf(pos.x - gx) < R + 0.024 and absf(pos.y - Rules.GOAL_H) < R + 0.024:
			vel.y = -absf(vel.y) * 0.6 if pos.y < Rules.GOAL_H else absf(vel.y) * 0.6
			vel.x = -vel.x * 0.6
			hit.emit("post", vel.length())
		# Through the goal mouth: past the goal line, between the posts, under the bar.
		var was_in := prev.x * end < Rules.GOAL_LINE + R
		var now_in := pos.x * end >= Rules.GOAL_LINE + R
		if was_in and now_in and absf(pos.z) < hw - R * 0.5 and pos.y < Rules.GOAL_H - R * 0.5 and live:
			in_goal = end
			crossed_goal_line.emit(end, true)
			return
		# The goal's outside: its sides and back push it away.
		var lx := (pos.x - gx) * end
		if lx > -0.01 and lx < Rules.GOAL_D + R and absf(pos.z) < hw + R and pos.y < Rules.GOAL_H * (1.0 - lx / Rules.GOAL_D * 0.9) + R:
			var plx := (prev.x - gx) * end
			if absf(prev.z) >= hw + R * 0.5:
				pos.z = (hw + R) * signf(pos.z)
				vel.z = -vel.z * 0.4
			elif plx >= Rules.GOAL_D:
				pos.x = gx + (Rules.GOAL_D + R) * end
				vel.x = -vel.x * 0.4
			else:
				vel.y = absf(vel.y) * 0.3 + 0.5


## In the net: it slows and stays inside the frame.
func _in_net() -> void:
	var end := in_goal
	var gx := Rules.GOAL_LINE * end
	vel *= 1.0 - NET_DAMP
	var lx := (pos.x - gx) * end
	if lx > Rules.GOAL_D - R:
		pos.x = gx + (Rules.GOAL_D - R) * end
		vel.x = -vel.x * 0.2
		hit.emit("net", vel.length())
	if lx < R:
		pos.x = gx + R * end
		vel.x = 0.0
	var hw := Rules.GOAL_W * 0.5 - R
	if absf(pos.z) > hw:
		pos.z = hw * signf(pos.z)
		vel.z = -vel.z * 0.2
	var top := Rules.GOAL_H * (1.0 - clampf(lx / Rules.GOAL_D, 0.0, 1.0) * 0.85)
	if pos.y > top:
		pos.y = top
		vel.y = 0.0


## Where it will be in t seconds if nothing touches it (a quick estimate for the AI: drag and roll, no boards).
func predict(t: float) -> Vector2:
	var p := floor_pos()
	var v := Vector2(vel.x, vel.z)
	var dt := 0.05
	var s := 0.0
	while s < t:
		var sp := v.length()
		if sp < 0.05:
			break
		v -= v * DRAG * sp * dt
		v = v.normalized() * maxf(0.0, v.length() - ROLL * dt)
		p += v * dt
		s += dt
	return p
