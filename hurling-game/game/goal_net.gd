class_name GoalNet
extends MeshInstance3D
## The goals' nets: a fine diamond mesh of white cord (hurling's is about 10 cm), from the crossbar back and down to
## the ground NET_DEPTH behind the line, the back sagging a little between the posts and the sides drawn in; each
## panel cut into small squares so it can move. A sliotar into the net pushes it out where it hit, and the net
## shakes and settles (ripple). The cords drawn in the shader, crisp near and fading to a fine grey far off.
## (The owner: "Make the goal net look better too it's too plain.")

const CELL := 0.1              # the mesh's diamonds, cord centre to cord centre (m)
const CORD := 0.012            # a cord's thickness (m)
const STEP := 0.25             # the panels' squares (m)

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform vec3 hit_pos = vec3(0.0, -100.0, 0.0);
uniform vec3 hit_dir = vec3(0.0);
uniform float hit_age = 100.0;
uniform float cell = 0.1;
uniform float cord = 0.012;
uniform float light = 1.0;       // 1 by day, lower at dusk and under lights

varying float shade;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(w, hit_pos);
	// Pushed out where the sliotar hit, then shaking back: strongest at the spot, gone a metre and a half off.
	float env = exp(-d * d / 0.45) * exp(-hit_age * 2.6);
	float wave = cos(hit_age * 15.0 - d * 5.0);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(hit_dir * 0.45 * env * (0.65 + 0.35 * wave), 0.0)).xyz;
	// Lit a little from above, darker where it gathers at the ground.
	shade = mix(0.72, 1.0, clamp(w.y / 2.5, 0.0, 1.0));
}

void fragment() {
	// A diamond mesh: the cords run at 45 degrees across the panel.
	vec2 q = vec2(UV.x + UV.y, UV.x - UV.y) * 0.70710678 / cell;
	vec2 f = abs(fract(q) - 0.5);
	float dist = min(0.5 - f.x, 0.5 - f.y);   // to the nearer cord, in cells
	float w = cord / cell * 0.5;
	vec2 fw = fwidth(q);
	float aa = max(fw.x, fw.y);
	float line = 1.0 - smoothstep(w, w + aa, dist);
	// Far off, the diamonds too fine for the screen: the cords' share of the net, as a light grey.
	float far = smoothstep(0.25, 0.7, aa);
	float a = mix(line, cord / cell * 2.2, far);
	// The knots, where the cords cross, a touch thicker.
	float knot = 1.0 - smoothstep(w * 1.6, w * 1.6 + aa, length(vec2(0.5) - f));
	a = max(a, knot * (1.0 - far));
	ALBEDO = vec3(0.95, 0.95, 0.93) * shade * light;
	ALPHA = clamp(a * 0.95, 0.0, 1.0);
}
"""

var _mat: ShaderMaterial
var _age := 100.0


## Both goals' nets, at the end lines x = -half_l and +half_l. time: "day", "dusk" or "night" (how bright).
func build(half_l: float, time: String) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: float in [-1.0, 1.0]:
		_goal(st, half_l * s, s)
	mesh = st.commit()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("cell", CELL)
	_mat.set_shader_parameter("cord", CORD)
	_mat.set_shader_parameter("light", 0.8 if time == "night" else (0.88 if time == "dusk" else 1.0))
	material_override = _mat
	set_process(false)


## One goal's net: the back from the bar down to the ground behind, sagging out a little between the posts, and the
## two sides, each a grid of small squares (u across, v down), its UV in metres along the net for the cords.
func _goal(st: SurfaceTool, x: float, s: float) -> void:
	var hz := Pitch.POST_GAP * 0.5
	var back := x + Pitch.NET_DEPTH * s
	var slope := Vector2(Pitch.NET_DEPTH, Pitch.BAR_H).length()
	var nu := ceili(Pitch.POST_GAP / STEP)
	var nv := ceili(slope / STEP)
	var grid := []
	for j in nv + 1:
		var row := []
		var v := float(j) / nv
		for i in nu + 1:
			var u := float(i) / nu
			var z := lerpf(-hz, hz, u)
			var p := Vector3(lerpf(x, back, v), lerpf(Pitch.BAR_H, 0.0, v), z)
			# The sag: out and down most in the middle of the panel, none at its edges.
			var sag := sin(PI * v) * (0.55 + 0.45 * sin(PI * u))
			p += Vector3(s * 0.22 * sag, -0.1 * sag * sin(PI * u), 0)
			row.append([p, Vector2(z, v * slope)])
		grid.append(row)
	_grid(st, grid)
	# The sides: between the post and the slope down to the back corner (v down the post, u back from it).
	for zs: float in [-1.0, 1.0]:
		var side := []
		var n := ceili(Pitch.BAR_H / STEP)
		var m := ceili(Pitch.NET_DEPTH / STEP)
		for j in n + 1:
			var row := []
			var v := float(j) / n
			var y := lerpf(Pitch.BAR_H, 0.0, v)
			for i in m + 1:
				var u := float(i) / m
				# Out from the post as far as the slope reaches at this height (none at the top).
				var reach := Pitch.NET_DEPTH * v
				var p := Vector3(x + s * reach * u, y, hz * zs)
				p.z += zs * 0.06 * sin(PI * u) * sin(PI * v)
				row.append([p, Vector2(reach * u, y)])
			side.append(row)
		_grid(st, side)


func _grid(st: SurfaceTool, g: Array) -> void:
	for j in g.size() - 1:
		for i in (g[j] as Array).size() - 1:
			var a: Array = g[j][i]
			var b: Array = g[j][i + 1]
			var c: Array = g[j + 1][i + 1]
			var d: Array = g[j + 1][i]
			for v: Array in [a, b, c, a, c, d]:
				st.set_uv(v[1])
				st.add_vertex(v[0])


## A sliotar into the net at pos, travelling vel: the net pushed out there, shaking as it settles.
func ripple(pos: Vector3, vel: Vector3) -> void:
	_age = 0.0
	_mat.set_shader_parameter("hit_pos", pos)
	_mat.set_shader_parameter("hit_dir", Vector3(vel.x, vel.y * 0.3, vel.z).normalized() if vel.length() > 0.1 else Vector3.ZERO)
	_mat.set_shader_parameter("hit_age", 0.0)
	set_process(true)


func _process(dt: float) -> void:
	_age += dt
	_mat.set_shader_parameter("hit_age", _age)
	if _age > 3.0:
		set_process(false)
