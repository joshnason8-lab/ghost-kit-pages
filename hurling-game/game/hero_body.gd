class_name HeroBody
extends ToonBody
## A player drawn with the owner's model (assets/player, baked by tools/player): a textured hurler on the same
## seventeen bones as ToonBody, so every pose and move in player.gd plays on him unchanged, and the Mixamo clips
## (hero.json "clips") are poses on those bones too. One model for all thirty: the shader paints his county's
## colours over the kit's green and gold (the mask says where the jersey, the trim, the shorts and the skin are), the
## socks below the knee, and the kit's design (a hoop, a sash, the shoulders) from where each point sits at rest.
## Officials keep ToonBody.

const DIR := "res://assets/player/"

static var _data := {}
static var _meshes := []        # [hi, lo]
static var _shader: Shader
static var _albedo: Texture2D
static var _kit: Texture2D
static var _mats := {}          # look key -> ShaderMaterial
static var _sticks := {}        # hurley, lod -> ArrayMesh
static var _q := {}             # clip -> its frames as Quaternions

var stick: MeshInstance3D


## The baked model's data (offsets, clips, the kit's mean colours), loaded once.
static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "hero.json"))
	return _data


## A clip at t seconds (looped if loop): [each of ToonBody.BONES' turns as a Quaternion, the hips' lift (m)];
## between two frames each bone turns the short way.
static func clip_pose(name: String, t: float, loop := false) -> Array:
	if not _q.has(name):
		_q[name] = _frames(name)
	var frames: Array = _q[name]
	var n := frames.size()
	var f := t * float(data().clips[name].fps)
	f = fposmod(f, float(n - 1)) if loop else clampf(f, 0.0, float(n - 1))
	var i := mini(int(f), n - 2)
	var w := f - i
	var a: Array = frames[i]
	var b: Array = frames[i + 1]
	var turns := []
	turns.resize(BONES.size())
	for j in BONES.size():
		turns[j] = (a[j] as Quaternion).slerp(b[j], w)
	return [turns, lerpf(a[BONES.size()], b[BONES.size()], w)]


## A clip's frames as Quaternions (the file keeps degrees), made once: [17 turns..., hips_y] a frame.
static func _frames(name: String) -> Array:
	var out := []
	for fr: Dictionary in data().clips[name].frames:
		var row := []
		for bn in BONES:
			var e: Array = fr[bn[0]]
			row.append(turn(Vector3(e[0], e[1], e[2])))
		row.append(float(fr.hips_y))
		out.append(row)
	return out


## A pose's turn as a Quaternion, whether it is held as degrees (Euler YXZ) or already a Quaternion.
static func turn(v: Variant) -> Quaternion:
	if v is Quaternion:
		return v
	var e: Vector3 = v * (PI / 180.0)
	return Basis.from_euler(e, EULER_ORDER_YXZ).get_rotation_quaternion()


func _offsets() -> Array:
	var off: Dictionary = data().offsets
	var out := []
	for b in BONES:
		var a: Array = off[b[0]]
		out.append(Vector3(a[0], a[1], a[2]))
	return out


func _dress() -> void:
	if _meshes.is_empty():
		_meshes = [load(DIR + "hero_hi.res"), load(DIR + "hero_lo.res")]
	mesh_instance.mesh = _meshes[1 if _lod > 0 else 0]
	mesh_instance.material_override = _material()
	# The hurley: built in code as ToonBody's, on the same skeleton (a second, small draw).
	stick = MeshInstance3D.new()
	var key := "%d|%d" % [int(look.get("hurley", 1)), _lod]
	if not _sticks.has(key):
		var m := MeshBuilder.new()
		m.seg_k = 1.0 if _lod == 0 else 0.6
		_hurley(m)
		_sticks[key] = m.commit()
	stick.mesh = _sticks[key]
	stick.material_override = material(false)
	stick.cast_shadow = mesh_instance.cast_shadow
	skeleton.add_child(stick)
	stick.skeleton = NodePath("..")


func _material() -> ShaderMaterial:
	var key := "%s|%s|%s|%s|%s|%d" % [look.get("jersey"), look.get("trim"), look.get("shorts"), look.get("socks"),
		look.get("skin"), int(look.get("design", 0))]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
		_albedo = load(DIR + "hero_albedo.jpg")
		_kit = load(DIR + "hero_mask.png")
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("albedo", _albedo)
	mat.set_shader_parameter("kit", _kit)
	var jersey: Color = look.get("jersey", Color("c8202f"))
	mat.set_shader_parameter("jersey", jersey)
	mat.set_shader_parameter("trim", look.get("trim", Color.WHITE))
	mat.set_shader_parameter("shorts", look.get("shorts", Color("f6f6f2")))
	mat.set_shader_parameter("socks", look.get("socks", jersey))
	mat.set_shader_parameter("skin", look.get("skin", Color("e8bc9a")))
	mat.set_shader_parameter("design", int(look.get("design", 0)))
	var ref: Dictionary = data().ref
	for k in ["jersey", "trim", "shorts", "skin"]:
		var c: Array = ref[k]
		mat.set_shader_parameter("ref_" + k, Color(c[0], c[1], c[2]))
	# Where the kit's design goes, from the skeleton at rest: the hoop round the chest, the sash from the right
	# shoulder to the left hip, the shoulders.
	mat.set_shader_parameter("chest_y", float(_rest.chest.y))
	mat.set_shader_parameter("spine_y", float(_rest.spine.y))
	_mats[key] = mat
	return mat


func set_lod(l: int) -> void:
	if l == _lod:
		return
	_lod = l
	if mesh_instance != null:
		mesh_instance.mesh = _meshes[1 if _lod > 0 else 0]


## The kit's shader: the texture lit as the cel-shaded bodies are (a soft step from the sun, a rim), with the
## county's colours in place of the model's green, gold and white, scaled by the texture's own light and dark.
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform sampler2D kit : filter_linear_mipmap;
uniform vec3 jersey : source_color;
uniform vec3 trim : source_color;
uniform vec3 shorts : source_color;
uniform vec3 socks : source_color;
uniform vec3 skin : source_color;
uniform vec3 ref_jersey : source_color;
uniform vec3 ref_trim : source_color;
uniform vec3 ref_shorts : source_color;
uniform vec3 ref_skin : source_color;
uniform int design = 0;
uniform float chest_y = 1.3;
uniform float spine_y = 1.1;
uniform vec3 light_dir = vec3(0.35, 0.85, 0.4);
uniform float shade = 0.72;
varying vec3 wn;
varying vec3 rp;
varying float leg;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
// The texture's light and dark kept, but softened: the model's creases read as stains on a light colour.
vec3 paint(vec3 tex, vec3 to, vec3 from) { return to * mix(1.0, clamp(lum(tex) / max(lum(from), 0.002), 0.0, 1.6), 0.5); }

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	rp = vec3((COLOR.r - 0.5) * 1.6, COLOR.g * 2.0, (COLOR.b - 0.5) * 1.6);
	leg = COLOR.a;
}

void fragment() {
	vec3 t = texture(albedo, UV).rgb;
	vec4 m = texture(kit, UV);
	vec3 shirt = jersey;
	if (leg > 0.5) {
		shirt = socks;
	} else if (design == 1 && abs(rp.y - (chest_y - 0.02)) < 0.065) {
		shirt = trim;
	} else if (design == 2) {
		vec2 a = vec2(-0.16, chest_y + 0.12);
		vec2 b = vec2(0.15, spine_y - 0.12);
		vec2 ab = b - a;
		float h = clamp(dot(rp.xy - a, ab) / dot(ab, ab), 0.0, 1.0);
		if (length(rp.xy - a - ab * h) < 0.06) { shirt = trim; }
	} else if (design == 3 && rp.y > chest_y + 0.06 && abs(rp.x) > 0.1) {
		shirt = trim;
	}
	vec3 c = t;
	c = mix(c, paint(t, shirt, ref_jersey), m.r);
	c = mix(c, paint(t, trim, ref_trim), m.g);
	c = mix(c, paint(t, shorts, ref_shorts), m.b);
	c = mix(c, paint(t, skin, ref_skin), m.a);
	float d = dot(normalize(wn), normalize(light_dir));
	float k = mix(shade, 1.0, smoothstep(-0.35, 0.3, d));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * 0.18;
	ALBEDO = c * k + rim * 0.5;
}
"""
