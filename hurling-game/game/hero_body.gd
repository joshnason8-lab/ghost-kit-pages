class_name HeroBody
extends ToonBody
## A player drawn with the owner's model (assets/player, baked by tools/player): a textured hurler on the same
## seventeen bones as ToonBody, so every pose and move in player.gd plays on him unchanged, and the Mixamo clips
## (hero.json "clips") are poses on those bones too. One model for all thirty: the shader paints his county's
## colours over the kit's green and gold (the mask says where the jersey, the trim, the shorts and the skin are), the
## socks below the knee, and the kit's design (a hoop, a sash, the shoulders) from where each point sits at rest.
## Officials keep ToonBody.

const DIR := "res://assets/player/"

static var _datas := {}         # with the HD pack (true) or not -> the data
static var _meshes := []        # [hi, lo]
static var _ultra_meshes := []  # the HD pack's: the owner's model at full detail (the HD pack's ultra/player)
static var _ultra_shader: Shader
const ULTRA_DIR := "res://ultra/player/"
static var _shader: Shader
static var _tex := {}             # Medium or High (true) or Low -> [the albedo, the kit mask]
static var _mats := {}          # look key -> ShaderMaterial
static var _sticks := {}        # hurley, lod -> ArrayMesh
static var _q := {}             # clip -> its frames as Quaternions

var stick: MeshInstance3D


## The baked model's data (offsets, clips, the kit's mean colours), loaded once.
static func data() -> Dictionary:
	var u := Ultra.active()
	if not _datas.has(u):
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "hero.json"))
		# The walk and the jog from the CMU motion-capture library (tools/mocap), with the Mixamo clips; with the HD pack
		# the Mixamo clips at 60 frames a second (the HD pack's ultra/anim). The CMU gaits stay at 30: the game's strides
		# were measured on those, and at 60 the planted foot slides more (tests/test_runner.gd's foot-slide checks).
		var cmu: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "cmu.json"))
		d.clips.merge(cmu.clips)
		# A free from the ground (put down, the stance, the lift, the toss, the strike), from the owner's slow-motion video
		# (tools/mocap/free_clip.py).
		var free: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "free.json"))
		d.clips.merge(free.clips)
		if u:
			for f in ["hero60.json"]:
				var more: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://ultra/anim/" + f))
				d.clips.merge(more.clips, true)
		_datas[u] = d
	return _datas[u]


## A clip at t seconds (looped if loop): [each of ToonBody.BONES' turns as a Quaternion, the hips' lift (m)];
## between two frames each bone turns the short way.
static func clip_pose(name: String, t: float, loop := false) -> Array:
	var key := "%s|%s" % [name, Ultra.active()]
	if not _q.has(key):
		_q[key] = _frames(name)
	var frames: Array = _q[key]
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
	return [turns, lerpf(a[BONES.size()], b[BONES.size()], w), (a[BONES.size() + 1] as Vector2).lerp(b[BONES.size() + 1], w)]


## A clip's frames as Quaternions (the file keeps degrees), made once: [17 turns..., hips_y, travel] a frame.
static func _frames(name: String) -> Array:
	var out := []
	for fr: Dictionary in data().clips[name].frames:
		var row := []
		for bn in BONES:
			var e: Array = fr[bn[0]]
			row.append(turn(Vector3(e[0], e[1], e[2])))
		row.append(float(fr.hips_y))
		# The hips' travel over the ground (x across, z ahead), where a clip moves him (the free's step into the strike).
		row.append(Vector2(float(fr.get("hips_side", 0.0)), float(fr.get("hips_fwd", 0.0))))
		out.append(row)
	return out


## A pose's turn as a Quaternion, whether it is held as degrees (Euler YXZ) or already a Quaternion.
static func turn(v: Variant) -> Quaternion:
	if v is Quaternion:
		return v
	var e: Vector3 = v * (PI / 180.0)
	return Basis.from_euler(e, EULER_ORDER_YXZ).get_rotation_quaternion()


## The model's feet were bound pitched up at the ankle: in every pose the boots' toes pointed at the sky (the owner
## saw it). Each foot is turned down by this much (degrees, toes down), in every pose, so it stands flat.
static var foot_pitch := 32.0


func apply(p: Dictionary) -> void:
	super(p)
	if skeleton == null or foot_pitch == 0.0:
		return
	for b in [13, 16]:
		var q := skeleton.get_bone_pose_rotation(b)
		skeleton.set_bone_pose_rotation(b, q * Quaternion(Vector3.RIGHT, deg_to_rad(foot_pitch)))


func _offsets() -> Array:
	var off: Dictionary = data().offsets
	var out := []
	for b in BONES:
		var a: Array = off[b[0]]
		out.append(Vector3(a[0], a[1], a[2]))
	return out


## The meshes for this graphics level: on High with the HD pack the model at 23,000 triangles near and 12,000 further off (the
## renderer's own levels of detail below that), else the phone's 5,866 and 1,757.
static func _mesh_pair() -> Array:
	if Ultra.active():
		if _ultra_meshes.is_empty():
			_ultra_meshes = [_gripped(load(ULTRA_DIR + "hero_ultra_hi.res")), _gripped(load(ULTRA_DIR + "hero_ultra_lo.res"))]
		return _ultra_meshes
	if _meshes.is_empty():
		_meshes = [_gripped(load(DIR + "hero_hi.res")), _gripped(load(DIR + "hero_lo.res"))]
	return _meshes


## Where the hurley's handle passes through the right fist (the fingers curled round it: _gripped), from the wrist.
const GRIP := Vector3(0.056, -0.1, 0.0)
const GRIP_TILT := 20.0      # the fist's hole slants down toward the thumb, as the hurley does through it
const GRIP_R := 0.032        # the fingers' middle wraps round the handle at this distance
const GRIP_MAX := 3.2        # radians: as far as a fingertip curls, into the palm


func _grip() -> Vector3:
	return GRIP


## The model's hands made into fists round a hurley's handle. The model has no finger bones (its hands were made
## open, the fingers straight: holding the hurley they looked broken, the owner saw), so the fingers' points are bent
## in the mesh, once as it loads: each finger, from the knuckles, wrapped round the handle's line (a line across the
## palm in front of it, through GRIP), the way a bend wraps a strip round a rod. The thumb, on the palm's side of the
## line, is left where it is, alongside the handle. Both hands: the left holds the handle below the right.
static func _gripped(mesh: ArrayMesh) -> ArrayMesh:
	var a := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var ts: PackedFloat32Array = a[Mesh.ARRAY_TANGENT] if a[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var ws: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var off: Dictionary = data().offsets
	var chest := Vector3.ZERO
	for b in ["hips", "spine", "chest"]:
		chest += Vector3(off[b][0], off[b][1], off[b][2])
	for side in [["r", 10, 1.0], ["l", 7, -1.0]]:
		var wrist := chest
		for b in ["upperarm_", "forearm_", "hand_"]:
			var o: Array = off[b + side[0]]
			wrist += Vector3(o[0], o[1], o[2])
		var sx: float = side[2]
		var m := Vector3(sx, 0, 0)                          # from the palm toward the handle (inward, toward the body)
		var tilt := deg_to_rad(GRIP_TILT)
		var ax := Vector3(0, -sin(tilt), cos(tilt))         # the handle's line through the fist
		var down := Vector3(0, -cos(tilt), -sin(tilt))      # the fingers' way, square to it
		var turn_ax := (-m).cross(down).normalized()        # turning -m toward down: the fingers curling in
		var a0 := wrist + Vector3(GRIP.x * sx, GRIP.y, GRIP.z)
		for i in vs.size():
			var w := 0.0
			for j in 4:
				if bs[i * 4 + j] == side[1]:
					w += ws[i * 4 + j]
			if w <= 0.0:
				continue
			var rel := vs[i] - a0
			var along := rel.dot(ax)
			var q := rel - ax * along
			var s := q.dot(down)
			var n := -q.dot(m)
			if s <= 0.0 or n <= 0.004:
				continue
			var th := minf(s / GRIP_R, GRIP_MAX)
			var rot := Basis(turn_ax, th)
			var bent := a0 + ax * along + rot * (-m * n)
			vs[i] = vs[i].lerp(bent, w)
			ns[i] = ns[i].slerp((rot * ns[i]).normalized(), w).normalized() if ns[i].length() > 0.0 else ns[i]
			if ts.size() >= (i + 1) * 4:
				var tv := Vector3(ts[i * 4], ts[i * 4 + 1], ts[i * 4 + 2])
				tv = tv.lerp(rot * tv, w).normalized()
				ts[i * 4] = tv.x
				ts[i * 4 + 1] = tv.y
				ts[i * 4 + 2] = tv.z
	a[Mesh.ARRAY_VERTEX] = vs
	a[Mesh.ARRAY_NORMAL] = ns
	if ts.size() > 0:
		a[Mesh.ARRAY_TANGENT] = ts
	# Its levels of detail kept as they were (the index lists, by the edge length each is for).
	var lods := {}
	var sd := RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	var wide := vs.size() > 65535
	for l: Dictionary in sd.get("lods", []):
		var by: PackedByteArray = l.index_data
		var ix := PackedInt32Array()
		ix.resize(by.size() / (4 if wide else 2))
		for k in ix.size():
			ix[k] = by.decode_u32(k * 4) if wide else by.decode_u16(k * 2)
		lods[float(l.edge_length)] = ix
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], lods)
	out.custom_aabb = mesh.custom_aabb
	return out


func relook() -> void:
	if mesh_instance != null:
		mesh_instance.material_override = _material()


func _dress() -> void:
	mesh_instance.mesh = _mesh_pair()[1 if _lod > 0 else 0]
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
	return kit_material(look, _rest)


## The kit's material for a look (its colours and design), the design placed from a body's rest (chest and spine).
## The officials on the foundation wear it too, on the hurlers' model (FoundationLink).
static func kit_material(look: Dictionary, _rest: Dictionary) -> ShaderMaterial:
	var hd := int(Game.settings.graphics) > Game.GFX_LOW
	var ultra := Ultra.active()
	var lit := Ultra.lit()
	var key := "%s|%s|%s|%s|%s|%d|%s|%s|%s|%s" % [look.get("jersey"), look.get("trim"), look.get("shorts"), look.get("socks"),
		look.get("skin"), int(look.get("design", 0)), hd, ultra, lit, look.get("plain", false)]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	# The textures: 1024 (and the kit's mask at 512) on Low, 2048 (1024) on Medium and High, the model's own 4096
	# (2048) with the HD pack. Lit on High (on Vulkan); the cloth's weave with the HD pack.
	var tk: Variant = "ultra" if ultra else hd
	if not _tex.has(tk):
		_tex[tk] = [load(ULTRA_DIR + "hero_albedo_4k.jpg"), load(ULTRA_DIR + "hero_mask_2k.png")] if ultra \
			else [load(Game.hd(DIR + "hero_albedo.jpg")), load(Game.hd(DIR + "hero_mask.png"))]
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	if lit:
		if _ultra_shader == null:
			_ultra_shader = Shader.new()
			_ultra_shader.code = _ultra_code()
		mat.shader = _ultra_shader
	if ultra:
		mat.set_shader_parameter("detail_n", load(ULTRA_DIR + "cotton_jersey_nor_gl_2k.jpg"))
		mat.set_shader_parameter("detail_r", load(ULTRA_DIR + "cotton_jersey_rough_2k.jpg"))
	mat.set_shader_parameter("albedo", _tex[tk][0])
	mat.set_shader_parameter("kit", _tex[tk][1])
	var jersey: Color = look.get("jersey", Color("c8202f"))
	mat.set_shader_parameter("jersey", _v(jersey))
	mat.set_shader_parameter("trim", _v(look.get("trim", Color.WHITE)))
	mat.set_shader_parameter("shorts", _v(look.get("shorts", Color("f6f6f2"))))
	mat.set_shader_parameter("socks", _v(look.get("socks", jersey)))
	mat.set_shader_parameter("skin", _v(look.get("skin", Color("e8bc9a"))))
	mat.set_shader_parameter("design", int(look.get("design", 0)))
	mat.set_shader_parameter("plain", 1.0 if look.get("plain", false) else 0.0)
	var ref: Dictionary = data().ref
	for k in ["jersey", "trim", "shorts", "skin"]:
		var c: Array = ref[k]
		mat.set_shader_parameter("ref_" + k, Vector3(c[0], c[1], c[2]))
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
		mesh_instance.mesh = _mesh_pair()[1 if _lod > 0 else 0]


## A colour as the shader takes it: a plain Vector3 (a Color would be decoded to linear light by the Vulkan renderer,
## and the shader decodes its colours itself: game/shaders/look.gdshaderinc).
static func _v(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## High with the HD pack: the same kit and colours, lit by the scene's real light (the sun, the sky, the floodlights; shadows on
## him and from him): the kit knitted (Poly Haven's cotton_jersey scan, its relief and roughness, tiled small), with
## a cloth's sheen at the edges; the skin smoother, and warm where light comes through from behind.
static func _ultra_code() -> String:
	var c := SHADER.replace("render_mode unshaded, cull_back;", "render_mode cull_back;")
	# (The 4096 texture's light and dark in the skin, kept at half on the phones' smaller one, at a quarter here.)
	c = c.replace("clamp(lum(tex) / max(lum(from), 0.002), 0.0, 1.6), 0.5)", "clamp(lum(tex) / max(lum(from), 0.002), 0.0, 1.6), 0.25)")
	c = c.replace("uniform float shade = 0.72;", "uniform float shade = 0.72;\nuniform sampler2D detail_n : hint_normal, filter_linear_mipmap, repeat_enable;\nuniform sampler2D detail_r : hint_roughness_r, filter_linear_mipmap, repeat_enable;")
	var tail := c.substr(c.find("	// The relief: the baked normal"))
	tail = tail.substr(0, tail.find("}"))
	c = c.replace(tail, """	float cloth = clamp(m.r + m.g + m.b + leg, 0.0, 1.0);
	vec2 duv = UV * 36.0;
	ALBEDO = compat_to_scene(c);
	// The cloth's weave on the sculpt's relief.
	vec3 weave = mix(vec3(0.5, 0.5, 1.0), texture(detail_n, duv).rgb, cloth) * 2.0 - 1.0;
	vec2 bxy = mix(vec2(0.0), texture(nmap, UV).rg * 2.0 - 1.0, nmap_k);
	NORMAL_MAP = normalize(vec3(bxy + weave.xy, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.7;
	ROUGHNESS = mix(0.48, 0.78 + 0.18 * texture(detail_r, duv).r, cloth);
	SPECULAR = mix(0.4, 0.3, cloth);
	RIM = 0.3 * cloth;
	RIM_TINT = 0.6;
	BACKLIGHT = vec3(0.35, 0.12, 0.06) * m.a;
""")
	return c


## The kit's shader: the texture lit as the cel-shaded bodies are (a soft step from the sun, a rim), with the
## county's colours in place of the model's green, gold and white, scaled by the texture's own light and dark.
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://game/shaders/look.gdshaderinc"
uniform sampler2D albedo : filter_linear_mipmap;
uniform sampler2D kit : filter_linear_mipmap;
// (Colours and textures are read as written, the same on both renderers: look.gdshaderinc.)
uniform vec3 jersey;
uniform vec3 trim;
uniform vec3 shorts;
uniform vec3 socks;
uniform vec3 skin;
uniform vec3 ref_jersey;
uniform vec3 ref_trim;
uniform vec3 ref_shorts;
uniform vec3 ref_skin;
uniform int design = 0;
uniform float plain = 0.0;
uniform float chest_y = 1.3;
uniform float spine_y = 1.1;
uniform vec3 light_dir = vec3(0.35, 0.85, 0.4);
uniform float shade = 0.72;
// The sculpt's relief, baked from the HD model onto the body drawn (tools/blender): 0 none (the game's own body).
uniform sampler2D nmap : hint_normal, filter_linear_mipmap;
uniform float nmap_k = 0.0;
varying vec3 wn;
varying vec3 wt;
varying vec3 wb;
varying vec3 rp;
varying float leg;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
// The skin keeps the texture's light and dark, softened (the face, the hands). The kit is the county's colour and
// nothing else: the texture's creases and grime read as stains on it (the owner had them taken off).
vec3 paint(vec3 tex, vec3 to, vec3 from) { return to * mix(1.0, clamp(lum(tex) / max(lum(from), 0.002), 0.0, 1.6), 0.5); }

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wt = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz);
	wb = normalize((MODEL_MATRIX * vec4(BINORMAL, 0.0)).xyz);
	rp = vec3((COLOR.r - 0.5) * 1.6, COLOR.g * 2.0, (COLOR.b - 0.5) * 1.6);
	leg = COLOR.a;
}

void fragment() {
	vec3 t = texture(albedo, UV).rgb;
	vec4 m = texture(kit, UV);
	// Along the model's UV seams the mask thins and picks up the next piece of the atlas (a line of the shorts' white
	// across a jersey), and the model's own texture showed through as streaks: the strongest part wins (sharpened, so a
	// real edge between two parts stays soft) and a point that is mostly kit is wholly kit.
	float cover = m.r + m.g + m.b + m.a;
	vec4 w = pow(m, vec4(6.0));
	m = mix(m, w / max(w.r + w.g + w.b + w.a, 1e-6), smoothstep(0.2, 0.45, cover));
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
	c = mix(c, shirt, m.r);
	// An official's plain shirt: the hurlers' number and crest (printed in the texture, not the kit mask) under it.
	if (plain > 0.5 && leg < 0.5 && rp.y > 1.02 && rp.y < 1.5) { c = mix(shirt, c, m.a); }
	c = mix(c, trim, m.g);
	c = mix(c, shorts, m.b);
	c = mix(c, paint(t, skin, ref_skin), m.a);
	// The relief: the baked normal (its z rebuilt: a compressed normal map keeps x and y) on the surface's own.
	vec2 nxy = texture(nmap, UV).rg * 2.0 - 1.0;
	vec3 nt = vec3(nxy, sqrt(max(1.0 - dot(nxy, nxy), 0.0)));
	vec3 n = normalize(mix(normalize(wn), normalize(wt * nt.x + wb * nt.y + wn * nt.z), nmap_k));
	vec3 vn = normalize(mix(NORMAL, normalize(TANGENT * nt.x + BINORMAL * nt.y + NORMAL * nt.z), nmap_k));
	float d = dot(n, normalize(light_dir));
	float k = mix(shade, 1.0, smoothstep(-0.35, 0.3, d));
	float rim = pow(1.0 - clamp(dot(vn, VIEW), 0.0, 1.0), 3.0) * 0.18;
	ALBEDO = compat_to_scene(c * k + rim * 0.5);
}
"""
