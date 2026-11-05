class_name PlayerShadows
extends MultiMeshInstance3D
## Every man's shadow on the grass, on Medium and High: the grass is drawn unlit (Pitch), so the sun's own shadows do
## not fall on it, and without a shadow a man seems to hover and it is hard to judge where he stands. Each is a soft
## dark shape from his feet away from the sun, as long as the sun is low (a man's height over the tangent of its
## elevation, as in a summer's afternoon at Croke Park: long and hard), shorter and fainter when he is in the air; at
## night a short faint one under him (the floodlights from all round). One draw call for all of them; Low has none.
## (The owner: "player shadows".)

const MAX := 64
const STRENGTH := {"day": 0.42, "dusk": 0.36, "night": 0.22}

var m: Node
var _dir := Vector3(0, 0, 1)     # along the grass, away from the sun
var _len := 1.6                  # a standing man's shadow, m
var _sun := Vector3.ZERO         # the sun these were worked out for (the stadium sets its sky after we are made)


func _init(p_match: Node) -> void:
	m = p_match


func _aim() -> void:
	var st: Stadium = m.stadium
	var s := st.to_sun
	_sun = s
	_dir = Vector3(-s.x, 0, -s.z).normalized() if Vector2(s.x, s.z).length() > 0.05 else Vector3(0, 0, 1)
	var h := 1.8 * Player.DRAW_SCALE
	_len = clampf(h / maxf(tan(asin(clampf(s.y, 0.2, 1.0))), 0.3), 0.6, 3.6) if st.time != "night" else 0.9


func _ready() -> void:
	var st: Stadium = m.stadium
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := PlaneMesh.new()
	q.size = Vector2(1, 1)
	mm.mesh = q
	mm.instance_count = MAX
	mm.visible_instance_count = 0
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float strength = 0.4;
void fragment() {
	// x across the shadow, y from the feet (0) to its far end (1): a body's shape, broad at the shoulders' end and
	// soft at its edges, darkest at the feet.
	vec2 p = vec2(UV.x * 2.0 - 1.0, UV.y);
	float w = mix(0.55, 1.0, smoothstep(0.0, 0.35, p.y)) * mix(1.0, 0.7, smoothstep(0.6, 1.0, p.y));
	float a = (1.0 - smoothstep(0.55, 1.0, abs(p.x) / w)) * (1.0 - smoothstep(0.75, 1.0, p.y)) * smoothstep(0.0, 0.06, p.y);
	ALBEDO = vec3(0.02, 0.04, 0.02);
	ALPHA = a * strength * mix(1.0, 0.7, p.y);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("strength", STRENGTH.get(st.time, 0.4))
	material_override = mat
	# Its bounds: the whole ground (the instances move every frame).
	custom_aabb = AABB(Vector3(-120, -1, -90), Vector3(240, 4, 180))


func _process(_delta: float) -> void:
	if m.stadium.to_sun != _sun:
		_aim()
	var mm := multimesh
	var n := 0
	var side := _dir.cross(Vector3.UP)
	for pl in m.all_players() + m.officials.people + m._leaving:
		var p: Player = pl
		if n >= MAX or not is_instance_valid(p) or not p.visible:
			continue
		var at := p.global_position
		var lift := clampf(at.y / 1.5, 0.0, 1.0)
		var length := _len * (1.0 - 0.4 * lift)
		var width := 0.62 * (1.0 - 0.3 * lift)
		# The quad's x across the shadow, its z along it (UV.y runs with z), from the feet outward.
		var b := Basis(side * width, Vector3.UP, _dir * length)
		var c := Vector3(at.x, 0.02, at.z) + _dir * length * 0.5
		mm.set_instance_transform(n, Transform3D(b, c))
		n += 1
	mm.visible_instance_count = n
