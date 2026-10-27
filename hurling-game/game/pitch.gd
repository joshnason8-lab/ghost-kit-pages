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
	var y := 0.03   # above the grass by enough that the far lines never fight it for depth (Vulkan: dashes at 12 mm)
	var w := drawn_line_w()
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


## How wide the lines are drawn: 10 cm, as painted; on Low (three-quarter resolution, no smoothing) 18 cm, or the
## far lines break up into dashes. Where the lines are, for the rules, does not change.
static func drawn_line_w() -> float:
	return LINE_W * (1.8 if int(Game.settings.graphics) == Game.GFX_LOW else 1.0)


static func _rect(g: Geo, ex: float, s: float, wide: float, deep: float, y: float, col: Color) -> void:
	var hw := wide * 0.5
	var x1 := ex - deep * s
	var w := drawn_line_w()
	g.floor_rect(minf(x1, x1 - w * s), -hw, maxf(x1, x1 - w * s), hw, y, col)
	g.floor_rect(minf(ex, x1), -hw - w, maxf(ex, x1), -hw, y, col)
	g.floor_rect(minf(ex, x1), hw, maxf(ex, x1), hw + w, y, col)


static var _grass := {}


## The pitch's grass: the photo-scanned mown grass (Poly Haven's grass_ground, two sizes over each other so it never
## repeats), coloured the game's greens and mown in bands across the pitch; worn grass (sparse_grass) along the
## touchlines and behind the end lines, withered grass in the goalmouths and the small rectangle. Unlit, the time
## of day's light in the colour (as the players are); on Medium and High the scan's normal map catches the sun.
## Low draws the grass and the bands only (two texture reads a pixel).
static func grass_material(time_of_day: String) -> ShaderMaterial:
	return _grass_material(time_of_day)


## High's grass (on Vulkan), from the same shader: lit (the sun's and the floodlights' light and the stands' and
## players' shadows fall on it), the scan's normal (the HD pack's 4K and its roughness, else the 2K in the game), the stripes crossed by a diagonal cut as at Croke Park,
## and wear in the middle where the throw-ins and the midfield battles are.
static func _ultra_grass(code: String) -> String:
	code = code.replace("render_mode unshaded, cull_back;", "render_mode cull_back;")
	code = code.replace("uniform float light = 1.0;", "uniform float light = 1.0;\nuniform sampler2D rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;")
	code = code.replace("		c *= 0.9 + 0.2 * clamp(dot(normalize(vec3(n.x, n.z * 2.0, -n.y)), normalize(sun)), 0.0, 1.0);\n",
		"		c *= 1.0 + 0.06 * (step(0.5, fract((wp.x + wp.z) / 14.0)) - 0.5);\n"
		+ "		float mid = smoothstep(14.0, 3.0, length(wp.xz)) * smoothstep(0.3, 0.7, texture(sparse, wp.xz / 23.0).rgb.r);\n"
		+ "		c = mix(c, c * 0.82 + vec3(0.03, 0.025, 0.0), mid * 0.5);\n")
	code = code.replace("	ALBEDO = compat_to_scene(c * light);",
		"	ALBEDO = compat_to_scene(c) * 1.15;\n	NORMAL_MAP = texture(grass_n, uv).rgb;\n	NORMAL_MAP_DEPTH = 0.8;\n"
		+ "	ROUGHNESS = 0.75 + 0.25 * texture(rough, uv).r;\n	SPECULAR = 0.3;")
	return code


static func _grass_material(time_of_day: String) -> ShaderMaterial:
	var g := int(Game.settings.graphics)
	var ultra := Ultra.lit()
	var pack := Ultra.active()
	var key := "%s|%d|%s|%s" % [time_of_day, g, ultra, pack]
	if _grass.has(key):
		return _grass[key]
	var sh := Shader.new()
	var code := """
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://game/shaders/look.gdshaderinc"
uniform sampler2D grass : filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D sparse : filter_linear_mipmap, repeat_enable;
uniform sampler2D withered : filter_linear_mipmap, repeat_enable;
uniform bool detail = true;
uniform vec3 g1 = vec3(0.20, 0.42, 0.16);
uniform vec3 g2 = vec3(0.17, 0.36, 0.13);
uniform vec3 worn = vec3(0.36, 0.34, 0.20);
uniform float light = 1.0;
uniform vec3 sun = vec3(0.4, 0.8, 0.45);
uniform float half_l = 70.0;
uniform float half_w = 42.5;
varying vec3 wp;
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
// A scan's mean brightness: its smallest mip level (1 x 1).
float mean_lum(sampler2D s) { return max(lum(textureLod(s, vec2(0.5), 10.0).rgb), 0.002); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = wp.xz / 2.7;
	vec3 t = mix(texture(grass, uv).rgb, texture(grass, wp.xz / 9.7 + vec2(0.37, 0.61)).rgb, 0.45);
	float GRASS_LUM = mean_lum(grass);
	float band = step(0.5, fract(wp.x / 10.0));
	vec3 green = mix(g1, g2, band);
	// The scan's light and dark in the game's green, a little of its own colour kept.
	float k = lum(t) / GRASS_LUM;
	vec3 c = mix(green * k, t * (lum(green) / GRASS_LUM), 0.22);
	float goal = min(length(wp.xz - vec2(half_l - 3.5, 0.0)), length(wp.xz - vec2(-half_l + 3.5, 0.0)));
	if (detail) {
		// Worn along the touchlines and outside the field.
		float edge = max(smoothstep(half_w - 1.0, half_w + 3.0, abs(wp.z)), smoothstep(half_l + 0.5, half_l + 4.0, abs(wp.x)));
		vec3 s = texture(sparse, wp.xz / 3.1).rgb;
		float SPARSE_LUM = mean_lum(sparse);
		c = mix(c, mix(green * 0.85, s * (lum(green) / SPARSE_LUM) * 0.9, 0.35) * (lum(s) / SPARSE_LUM), edge * 0.55);
		// Withered in the goalmouth, where the keeper and the backs stand.
		vec3 w = texture(withered, wp.xz / 2.3).rgb;
		float mouth = smoothstep(8.5, 2.0, goal) * smoothstep(0.25, 0.65, texture(withered, wp.xz / 17.0).rgb.r);
		c = mix(c, w * (lum(green) * 1.15 / mean_lum(withered)), mouth * 0.6);
		vec3 n = texture(grass_n, uv).rgb * 2.0 - 1.0;
		c *= 0.9 + 0.2 * clamp(dot(normalize(vec3(n.x, n.z * 2.0, -n.y)), normalize(sun)), 0.0, 1.0);
	} else {
		c = mix(c, worn, smoothstep(9.0, 2.0, goal) * 0.3);
	}
	c = mix(c, c * 0.8, smoothstep(half_l + 2.0, half_l + 9.0, abs(wp.x)));
	ALBEDO = compat_to_scene(c * light);
}
"""
	if ultra:
		code = _ultra_grass(code)
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("half_l", HALF_L)
	m.set_shader_parameter("half_w", HALF_W)
	m.set_shader_parameter("detail", g > Game.GFX_LOW)
	m.set_shader_parameter("grass", load(Game.hd("res://assets/env/ground/grass_ground_albedo_1k.jpg")))
	if g > Game.GFX_LOW:
		m.set_shader_parameter("grass_n", load(Game.hd("res://assets/env/ground/grass_ground_normal_1k.jpg")))
		m.set_shader_parameter("sparse", load(Game.hd("res://assets/env/ground/sparse_grass_albedo_1k.jpg")))
		m.set_shader_parameter("withered", load(Game.hd("res://assets/env/ground/withered_grass_albedo_1k.jpg")))
	var light: float = {"day": 1.0, "dusk": 0.78, "night": 0.86}.get(time_of_day, 1.0)
	m.set_shader_parameter("light", light)
	if ultra:
		m.set_shader_parameter("light", 1.0)
	if pack:
		m.set_shader_parameter("grass", load("res://ultra/ground/grass_ground_albedo_4k.jpg"))
		m.set_shader_parameter("grass_n", load("res://ultra/ground/grass_ground_normal_4k.jpg"))
		m.set_shader_parameter("rough", load("res://ultra/ground/grass_ground_rough_4k.jpg"))
	if time_of_day == "dusk":
		m.set_shader_parameter("g1", Vector3(0.22, 0.38, 0.15))
		m.set_shader_parameter("g2", Vector3(0.19, 0.33, 0.13))
	_grass[key] = m
	return m
