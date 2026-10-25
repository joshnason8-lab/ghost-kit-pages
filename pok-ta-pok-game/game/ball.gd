class_name Ball
extends Node3D
## The ball: solid natural rubber, about 3.6 kg and 19 cm across (docs/RULES.md, "The ball": 3-4 kg and under 20 cm in
## every source on the hip game). Heavy: it flies on low arcs, thuds down and bounces only a little on packed earth,
## more on stone; rolling, the earth slows it quickly. The match steps it (step) at a fixed rate; the AI looks ahead
## with the same physics (predict), so what a player reads is what the ball does.

const RADIUS := 0.095
const MASS := 3.6
const GRAVITY := 9.81
## Air drag, 0.5 * rho * Cd * A / m: a 3.6 kg ball loses little to the air (half a metre a second, a second, at 15 m/s).
const DRAG := 0.5 * 1.2 * 0.47 * PI * RADIUS * RADIUS / MASS
## How much of its speed into a surface comes back (the coefficient of restitution), and how much along it is kept.
## Measured values for heavy solid rubber were not found (docs/RULES.md); these are chosen so a ball dropped from hip
## height on earth comes back to about 15 cm, on stone to about 30 cm.
# Packed earth deadens the heavy ball (ulama in Sinaloa); on the smooth plastered stone of the Yucatán courts it comes up
# lively, to knee or hip height, and is played off the bounce, as in the games played there today.
const BOUNCE := {"earth": 0.42, "stone": 0.68, "talud": 0.62, "wall": 0.66, "end_wall": 0.64, "ring": 0.5}
const KEEP := {"earth": 0.78, "stone": 0.86, "talud": 0.8, "wall": 0.85, "end_wall": 0.85, "ring": 0.7}
## Rolling resistance, as a slowing in m/s per second: packed earth, then stone.
const ROLL_DECEL := {"earth": 1.5, "stone": 0.7}
const DEAD_SPEED := 0.35      # rolling slower than this the ball has as good as stopped (R8)

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var grounded := false         # rolling on the floor (no longer bouncing)
var floor_kind := "earth"
var court: Court
var last_team := -1           # the side that last played it
var last_player = null        # who (a Player)
var held := false             # in the server's hand
var spin := Vector3.ZERO      # how the ball is drawn turning (looks only)
var _mesh: MeshInstance3D
var _shadow: MeshInstance3D


func setup(p_court: Court, p_floor: String) -> void:
	court = p_court
	floor_kind = p_floor
	_mesh = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = RADIUS
	s.height = RADIUS * 2.0
	s.radial_segments = 16 if int(Game.settings.graphics) > Game.GFX_LOW else 12
	s.rings = 8
	_mesh.mesh = s
	_mesh.material_override = material()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	# A soft shadow on the ground under it (every level): it shows how high the ball is, which is the whole game.
	_shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	q.orientation = PlaneMesh.FACE_Y
	_shadow.mesh = q
	_shadow.material_override = shadow_material()
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)
	# A faint pale ring round the ball, turned to the camera: a dark rubber ball over dark earth, small on a phone's
	# screen, would otherwise be lost (the dusk court above all). It thins as the ball comes near the camera.
	_halo = MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(RADIUS * 2.0 * HALO, RADIUS * 2.0 * HALO)
	_halo.mesh = hq
	_halo.material_override = halo_material()
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.add_child(_halo)


const HALO := 2.6             # the halo's size, in ball diameters
var _halo: MeshInstance3D
static var _halo_mat: ShaderMaterial


static func halo_material() -> ShaderMaterial:
	if _halo_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float halo = 2.6;
void vertex() {
	// Face the camera, whatever the ball's spin.
	vec3 c = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 r = INV_VIEW_MATRIX[0].xyz;
	vec3 u = INV_VIEW_MATRIX[1].xyz;
	vec3 w = c + (r * VERTEX.x + u * VERTEX.y) * s;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0 * halo;   // 1.0 at the ball's edge
	float near = clamp((length(CAMERA_POSITION_WORLD - NODE_POSITION_WORLD) - 4.0) / 10.0, 0.0, 1.0);
	float ring = smoothstep(1.05, 1.25, d) * (1.0 - smoothstep(1.35, 1.9, d));
	ALBEDO = vec3(1.0, 0.95, 0.85);
	ALPHA = ring * 0.55 * near;
}
"""
		_halo_mat = ShaderMaterial.new()
		_halo_mat.shader = sh
		_halo_mat.set_shader_parameter("halo", HALO)
	return _halo_mat


static var _mat: StandardMaterial3D
static var _shadow_mat: ShaderMaterial


## Natural rubber, dark and a little glossy where hands and hips have polished it.
static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color("2a211b")
		_mat.roughness = 0.5
		_mat.metallic_specular = 0.45
		_mat.rim_enabled = true
		_mat.rim = 0.5
		_mat.rim_tint = 0.4
	return _mat


static func shadow_material() -> ShaderMaterial:
	if _shadow_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float strength = 0.5;
void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	ALBEDO = vec3(0.0);
	ALPHA = clamp(1.0 - d, 0.0, 1.0) * clamp(1.0 - d, 0.0, 1.0) * strength;
}
"""
		_shadow_mat = ShaderMaterial.new()
		_shadow_mat.shader = sh
	return _shadow_mat


## One step of dt seconds. Returns what happened in it: [{"kind": "bounce"|"roll"|"ring"|"out"|"end", ...}].
func step(dt: float) -> Array:
	if held:
		return []
	var events := []
	var r := simulate(self, dt, court, floor_kind, events)
	pos = r
	return events


## The physics, shared by the real ball and the look-ahead: moves state b (anything with pos, vel, grounded) on by dt,
## adding what happened to events. Returns the new position.
static func simulate(b: Object, dt: float, c: Court, floor_k: String, events: Array) -> Vector3:
	var p: Vector3 = b.pos
	var v: Vector3 = b.vel
	var was_grounded: bool = b.grounded
	if b.grounded:
		# Rolling: the floor slows it; a ball rolling slowly enough has stopped.
		var sp := Vector2(v.x, v.z).length()
		var dec: float = ROLL_DECEL.get("stone" if c.classic() else floor_k, 1.2) * dt
		if sp <= dec:
			v = Vector3.ZERO
		else:
			var k := (sp - dec) / sp
			v = Vector3(v.x * k, 0.0, v.z * k)
		p += v * dt
		var fy := c.floor_y(p.x, p.z)
		if fy > 0.001:
			# Rolled onto the talud: it climbs it, rolling up and back.
			b.grounded = false
			p.y = fy + RADIUS
	else:
		var sp := v.length()
		v += (Vector3(0, -GRAVITY, 0) - v * sp * DRAG) * dt
		var a := p
		p += v * dt
		var ring := c.through_ring(a, p, RADIUS)
		if ring != 0:
			events.append({"kind": "ring", "side": ring, "pos": p})
		# The floor.
		var fy := c.floor_y(p.x, p.z)
		if p.y < fy + RADIUS and fy <= 0.001:
			p.y = RADIUS
			var kind := "stone" if c.classic() else floor_k
			var vin := -v.y
			if vin > 0.0:
				v.y = vin * float(BOUNCE.get(kind, 0.45))
				var keep: float = KEEP.get(kind, 0.8)
				v.x *= keep
				v.z *= keep
				events.append({"kind": "bounce", "surface": kind, "pos": p, "speed": vin})
			if v.y < 0.9:
				v.y = 0.0
				b.grounded = true
	# The talud, the walls, the rings' stone.
	for _i in 2:
		var hit := c.contact(p, RADIUS)
		if hit.is_empty():
			break
		var n: Vector3 = hit[0]
		p += n * float(hit[1])
		var vn := v.dot(n)
		if vn < 0.0:
			var kind: String = hit[2]
			var vt := v - n * vn
			v = vt * float(KEEP.get(kind, 0.8)) - n * vn * float(BOUNCE.get(kind, 0.5))
			if b.grounded and n.y < 0.5:
				v.y = 0.0
			if absf(vn) > 0.4:
				events.append({"kind": "bounce", "surface": kind, "pos": p, "speed": -vn})
	if b.grounded and not was_grounded:
		events.append({"kind": "roll", "pos": p})
	if c.out_side(p, RADIUS, b.grounded or p.y < RADIUS + 0.02):
		events.append({"kind": "out", "pos": p})
	var e := c.past_end(p, RADIUS, b.grounded or p.y < RADIUS + 0.02)
	if e != 0:
		events.append({"kind": "end", "side": e, "pos": p})
	b.vel = v
	return p


func dead() -> bool:
	return grounded and Vector2(vel.x, vel.z).length() < DEAD_SPEED


## Puts it in play from p with velocity v, by team t (player pl).
func launch(p: Vector3, v: Vector3, t: int, pl = null) -> void:
	held = false
	pos = p
	vel = v
	grounded = false
	last_team = t
	last_player = pl
	if p.y <= RADIUS + 0.01 and absf(v.y) < 0.01:
		grounded = true


## Where the ball will be at each step of dt for n steps (the AI's reading of it): [Vector3, grounded (bool),
## time (s)] each, stopping early at an end, out or a stop.
func predict(n: int, dt := 1.0 / 30.0) -> Array:
	var s := _Probe.new()
	s.pos = pos
	s.vel = vel
	s.grounded = grounded
	var out := []
	var t := 0.0
	for i in n:
		var ev := []
		s.pos = simulate(s, dt, court, floor_kind, ev)
		t += dt
		out.append([s.pos, s.grounded, t])
		var stop := false
		for e in ev:
			if e.kind in ["out", "end"]:
				stop = true
		if stop or (s.grounded and Vector2(s.vel.x, s.vel.z).length() < DEAD_SPEED):
			break
	return out


class _Probe:
	extends RefCounted
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var grounded := false


## Draws it where it is (the match calls this once a frame, after the steps).
func show_at(p: Vector3, dt: float) -> void:
	global_position = p
	var h := Vector2(vel.x, vel.z)
	if h.length() > 0.05:
		var axis := Vector3(h.y, 0, -h.x).normalized()
		_mesh.rotate(axis, h.length() / RADIUS * dt)
	if _shadow:
		var fy := court.floor_y(p.x, p.z) if court else 0.0
		_shadow.global_position = Vector3(p.x, fy + 0.012, p.z)
		var hgt := maxf(0.0, p.y - fy - RADIUS)
		_shadow.scale = Vector3.ONE * (0.55 + hgt * 0.18)
		_shadow.visible = fy < 0.01
		(_shadow.material_override as ShaderMaterial).set_shader_parameter("strength", clampf(0.6 - hgt * 0.08, 0.15, 0.6))
