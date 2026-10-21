class_name Pitch
extends RefCounted
## The field of play (Rule 1.1 of the playing rules, docs/RULES.md), in metres. x runs the length of the pitch, the
## goals on the end lines at x = -HALF_L and +HALF_L; z runs across it, the side lines at z = -HALF_W and +HALF_W; y
## is up. The camera's stand is on the +z side.

const LENGTH := 140.0         # 130-145 m in the rules
const WIDTH := 85.0           # 80-90 m
const HALF_L := LENGTH * 0.5
const HALF_W := WIDTH * 0.5

const POST_GAP := 6.5         # between the uprights, inside
const BAR_H := 2.5            # the crossbar's lower edge above the ground
const POST_H := 10.0          # uprights not less than 7 m above the ground (Rule 1.3); most grounds' are taller
const POST_W := 0.12          # the uprights' and the bar's width (5-12 cm square)
const NET_DEPTH := 2.0        # the goal net runs back about 1.5-2.5 m

const SMALL_W := 14.0         # the small rectangle: its sides 3.75 m outside each post, so 14 m wide
const SMALL_D := 4.5          # 4.5 m out from the end line
const LARGE_W := 19.0         # the large rectangle: its sides 6.25 m outside each post, so 19 m wide
const LARGE_D := 13.0         # 13 m out
const ARC_R := 13.0           # the semicircle on the 20 m line, radius 13 m from its centre

const LINES := [13.0, 20.0, 45.0, 65.0]   # each measured from the end line
const LINE_W := 0.1           # painted lines, 10 cm


## The goal team attacks has its line at end_x(team, half): team 0 attacks +x in the first half, -x in the second.
static func attack_dir(team: int, half: int) -> float:
	var d := 1.0 if team == 0 else -1.0
	return d if half % 2 == 1 else -d


static func goal_x(team: int, half: int) -> float:
	return HALF_L * attack_dir(team, half)


## Distance from the end line a team attacks (0 at its line, LENGTH at its own).
static func from_goal_line(p: Vector3, dir: float) -> float:
	return HALF_L - p.x * dir


## Is a point inside the field of play? The lines are part of it: a ball is out only when wholly over the line.
static func in_play(p: Vector3, r := 0.035) -> bool:
	return absf(p.x) <= HALF_L + r and absf(p.z) <= HALF_W + r


static func in_small_rect(p: Vector3, dir: float) -> bool:
	return from_goal_line(p, dir) <= SMALL_D and absf(p.z) <= SMALL_W * 0.5


static func in_large_rect(p: Vector3, dir: float) -> bool:
	return from_goal_line(p, dir) <= LARGE_D and absf(p.z) <= LARGE_W * 0.5


## The penalty spot: the centre of the 20 m line.
static func penalty_spot(dir: float) -> Vector3:
	return Vector3((HALF_L - 20.0) * dir, 0, 0)


## Where a ball crossing the end line at x = end (sign dir) between y and z scores: "goal", "point", or "" (wide or
## off a post: the posts and bar are 6.5 m apart and 2.5 m up, measured inside).
static func score_kind(cross: Vector3) -> String:
	if absf(cross.z) >= POST_GAP * 0.5:
		return ""
	if cross.y < BAR_H:
		return "goal"
	return "point"


## The end of the half-way line nearest a point, for a throw-in: the centre.
static func centre() -> Vector3:
	return Vector3.ZERO


## Clamps a point onto the field (a free awarded over a line is taken on it).
static func clamp_in(p: Vector3, inset := 0.0) -> Vector3:
	return Vector3(clampf(p.x, -HALF_L + inset, HALF_L - inset), 0.0, clampf(p.z, -HALF_W + inset, HALF_W - inset))


## The grass and its markings: the striped grass in one draw call, every painted line in one more.
static func build(time_of_day: String) -> Node3D:
	var root := Node3D.new()
	var grass := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(LENGTH + 40.0, WIDTH + 30.0)
	pm.subdivide_width = 0
	pm.subdivide_depth = 0
	grass.mesh = pm
	grass.material_override = grass_material(time_of_day)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(grass)
	var g := Geo.new()
	var white := Color(0.95, 0.95, 0.92)
	var y := 0.012
	var w := LINE_W
	# Side lines and end lines.
	g.floor_rect(-HALF_L - w, -HALF_W - w, HALF_L + w, -HALF_W, y, white)
	g.floor_rect(-HALF_L - w, HALF_W, HALF_L + w, HALF_W + w, y, white)
	g.floor_rect(-HALF_L - w, -HALF_W, -HALF_L, HALF_W, y, white)
	g.floor_rect(HALF_L, -HALF_W, HALF_L + w, HALF_W, y, white)
	# The halfway line (Rule 1.2).
	g.floor_rect(-w * 0.5, -HALF_W, w * 0.5, HALF_W, y, white)
	for s: float in [-1.0, 1.0]:
		var ex := HALF_L * s
		for d in LINES:
			var x: float = ex - float(d) * s
			g.floor_rect(minf(x, x - w * s), -HALF_W, maxf(x, x - w * s), HALF_W, y, white)
		# The small and large rectangles.
		_rect(g, ex, s, SMALL_W, SMALL_D, y, white)
		_rect(g, ex, s, LARGE_W, LARGE_D, y, white)
		# The semicircle on the 20 m line, outward from the goal.
		var c := Vector3(ex - 20.0 * s, y, 0)
		var a0 := PI * 0.5 if s > 0 else -PI * 0.5
		g.ring(c, ARC_R - w, ARC_R, a0, a0 + PI, white, 32)
		# The penalty mark.
		g.floor_rect(c.x - 0.25, -0.05, c.x + 0.25, 0.05, y + 0.001, white)
	var lines := g.commit(Geo.material(false))
	root.add_child(lines)
	return root


static func _rect(g: Geo, ex: float, s: float, wide: float, deep: float, y: float, col: Color) -> void:
	var hw := wide * 0.5
	var x1 := ex - deep * s
	var w := LINE_W
	g.floor_rect(minf(x1, x1 - w * s), -hw, maxf(x1, x1 - w * s), hw, y, col)
	g.floor_rect(minf(ex, x1), -hw - w, maxf(ex, x1), -hw, y, col)
	g.floor_rect(minf(ex, x1), hw, maxf(ex, x1), hw + w, y, col)


static var _grass := {}


## Grass mown in bands across the pitch, a little patchy, worn in the goalmouths; lit flat (the sun's direction is
## in the shader), so it costs one texture-free pass.
static func grass_material(time_of_day: String) -> ShaderMaterial:
	if _grass.has(time_of_day):
		return _grass[time_of_day]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 g1 = vec3(0.20, 0.42, 0.16);
uniform vec3 g2 = vec3(0.17, 0.36, 0.13);
uniform vec3 worn = vec3(0.36, 0.34, 0.20);
uniform float light = 1.0;
uniform float half_l = 70.0;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float band = step(0.5, fract(wp.x / 10.0));
	vec3 c = mix(g1, g2, band);
	float n = noise(wp.xz * 0.35) * 0.6 + noise(wp.xz * 2.1) * 0.4;
	c *= 0.9 + n * 0.2;
	float goal = min(length(wp.xz - vec2(half_l - 4.0, 0.0)), length(wp.xz - vec2(-half_l + 4.0, 0.0)));
	c = mix(c, worn, smoothstep(9.0, 2.0, goal) * 0.35 * n);
	c = mix(c, c * 0.8, smoothstep(half_l + 2.0, half_l + 9.0, abs(wp.x)));
	ALBEDO = c * light;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("half_l", HALF_L)
	var light: float = {"day": 1.0, "dusk": 0.78, "night": 0.86}.get(time_of_day, 1.0)
	m.set_shader_parameter("light", light)
	if time_of_day == "dusk":
		m.set_shader_parameter("g1", Vector3(0.22, 0.38, 0.15))
		m.set_shader_parameter("g2", Vector3(0.19, 0.33, 0.13))
	_grass[time_of_day] = m
	return m
