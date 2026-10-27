class_name HeroBody
extends ToonBody
## A netball player drawn with the owner's model (assets/player, baked by tools/player): a textured player in a
## netball dress, on the same seventeen bones as ToonBody, so every pose in Poses plays on her unchanged, and the
## Mixamo clips (hero.json "clips": the model's own Walking and Running, and Fast_Run, the sprint shared with Hurling)
## are poses on those bones too. One model for all fourteen: the shader paints her team's colours over the dress's
## navy and the light blue of its panels (the mask says where the dress, the trim, the hair and the skin are), keeps
## the white of the socks and shoes, gives her own skin tone and hair, and paints the bib with her position's letters
## on the front and back of the chest from where each point sits at rest (UV2), so the bib costs no extra draw call
## and never comes off the body. Umpires keep ToonBody.

const DIR := "res://assets/player/"
## The bib, in the rest stance (m): its top and bottom against the chest joint, and its half width.
const BIB_TOP := 0.04
const BIB_BOTTOM := -0.185
const BIB_HALF := 0.118

static var _data := {}
static var _meshes := []        # [hi, lo]
static var _shader: Shader
static var _albedo: Texture2D
static var _kit: Texture2D
static var _albedo_hd: Texture2D   # Medium and High
static var _kit_hd: Texture2D
static var _letters: Texture2D
static var _mats := {}          # look key -> ShaderMaterial
static var _q := {}             # clip -> its frames as Quaternions
static var _mocap := {}         # motion-capture clip -> its frames, made once (mocap())
static var _mocap_src := {}


## The baked model's data (offsets, the torso, clips, the kit's mean colours), loaded once.
static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "hero.json"))
	return _data


## How long one cycle of a looped clip is (s).
static func cycle(name: String) -> float:
	var c: Dictionary = data().clips[name]
	return float(c.frames.size() - 1) / float(c.fps)


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


## A looped stride clip at a stride phase (0-1 a stride pair; the left thigh furthest forward at 1/4, as in
## Poses.run), so the clip's feet keep the pace the player's speed sets.
static func stride_pose(name: String, phase: float) -> Array:
	var c: Dictionary = data().clips[name]
	return clip_pose(name, float(c.left_forward) + (phase - 0.25) * cycle(name), true)


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


## The motion-capture clips (assets/player/mocap.json, from the CMU library by tools/player/cmu_bvh.py), loaded
## once: name -> {fps, frames: [17 turns as Quaternions, the hips' shift from rest (m)] a frame, plant: a letter a
## frame (l, r, b(oth) or -: the planted feet), travel: how far along her path she has come at each frame (m)}.
static func mocap(name: String) -> Dictionary:
	if not _mocap.has(name):
		if _mocap_src.is_empty():
			_mocap_src = JSON.parse_string(FileAccess.get_file_as_string(DIR + "mocap.json")).clips
		var c: Dictionary = _mocap_src[name]
		var frames := []
		for row: Array in c.frames:
			var fr := []
			for j in BONES.size():
				fr.append(turn(Vector3(row[j * 3], row[j * 3 + 1], row[j * 3 + 2])))
			var k := BONES.size() * 3
			fr.append(Vector3(row[k], row[k + 1], row[k + 2]))
			frames.append(fr)
		_mocap[name] = {"fps": float(c.fps), "frames": frames, "plant": String(c.plant),
			"travel": PackedFloat32Array(c.get("travel", [])), "turn": PackedFloat32Array(c.get("turn", [])),
			"plant_at": c.get("plant_at", {})}
	return _mocap[name]


## How long a motion-capture clip runs (s); a looped clip's cycle.
static func mocap_length(name: String) -> float:
	var c := mocap(name)
	return float(c.frames.size() - 1) / c.fps


## A motion-capture clip at t seconds (looped if loop): [the 17 turns, the hips' shift (Vector3, m)].
static func mocap_pose(name: String, t: float, loop := false) -> Array:
	var c := mocap(name)
	var frames: Array = c.frames
	var n := frames.size()
	var f := t * float(c.fps)
	f = fposmod(f, float(n - 1)) if loop else clampf(f, 0.0, float(n - 1))
	var i := mini(int(f), n - 2)
	var w := f - i
	var a: Array = frames[i]
	var b: Array = frames[i + 1]
	var turns := []
	turns.resize(BONES.size())
	for j in BONES.size():
		turns[j] = (a[j] as Quaternion).slerp(b[j], w)
	return [turns, (a[BONES.size()] as Vector3).lerp(b[BONES.size()], w)]


## The time (s) at which a clip has carried her d metres along her path (its travel), for playing a clip in step
## with how far the player has really gone, so her planted feet stay put.
static func mocap_time_at(name: String, d: float) -> float:
	var c := mocap(name)
	var tr: PackedFloat32Array = c.travel
	var n := tr.size()
	if n < 2 or d <= tr[0]:
		return 0.0
	for i in range(1, n):
		if tr[i] >= d:
			var w := (d - tr[i - 1]) / maxf(tr[i] - tr[i - 1], 0.0001)
			return (float(i - 1) + w) / c.fps
	return float(n - 1) / c.fps


## How far a clip carries her along her path, start to end (a cycle's stride, m of the model).
static func mocap_travel(name: String) -> float:
	var tr: PackedFloat32Array = mocap(name).travel
	return tr[tr.size() - 1] if tr.size() > 0 else 0.0


## How far along a clip's path she is when foot ("l" or "r") first comes down (m of the model).
static func mocap_plant_travel(name: String, foot: String) -> float:
	var c := mocap(name)
	var pl: String = c.plant
	var tr: PackedFloat32Array = c.travel
	for i in pl.length():
		if pl[i] == foot or pl[i] == "b":
			return tr[i] if i < tr.size() else 0.0
	return 0.0


## Where a landing's foot ("l" or "r") first comes down, against her position then: (to her left, ahead), m.
static func mocap_plant_at(name: String, foot: String) -> Vector2:
	var a: Array = mocap(name).plant_at.get(foot, [0.0, 0.0])
	return Vector2(a[0], a[1])


## How fast a clip carries her along her path (m/s of the model) once she is d metres along it.
static func mocap_speed(name: String, d: float) -> float:
	var c := mocap(name)
	var tr: PackedFloat32Array = c.travel
	for i in range(1, tr.size()):
		if tr[i] > d:
			return (tr[i] - tr[i - 1]) * c.fps
	return 0.0


## Where along a clip's path (m) it first goes no faster than spd (m/s of the model): where to come into a landing.
static func mocap_travel_at_speed(name: String, spd: float) -> float:
	var c := mocap(name)
	var tr: PackedFloat32Array = c.travel
	for i in range(1, tr.size()):
		if (tr[i] - tr[i - 1]) * c.fps <= spd:
			return tr[i - 1]
	return tr[tr.size() - 1] if tr.size() > 0 else 0.0


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
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	mesh_instance.mesh = _meshes[1 if low else 0]
	var mat := _material()
	# The outline as the umpires have it, on Medium and High (ToonBody.material switches it with theirs).
	mat.next_pass = ToonBody.material(not low).next_pass
	mesh_instance.material_override = mat


func _material() -> ShaderMaterial:
	var key := "%s|%s|%s|%s|%s|%s" % [look.get("dress"), look.get("trim"), look.get("bib"), look.get("skin"),
		look.get("hair"), look.get("pos", "")]
	# Medium and High: the model's texture at 2048 and its kit mask at 1024 (Game.HD_TEX); Low the 1024 and 512.
	var hd := Game.hd()
	if hd:
		key = "hd|" + key
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
		_albedo = load(DIR + "hero_albedo.jpg")
		_kit = load(DIR + "hero_mask.png")
		_letters = load("res://assets/ui/bib_letters.png")
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	if hd and _albedo_hd == null:
		_albedo_hd = Game.tex(DIR + "hero_albedo.jpg")
		_kit_hd = Game.tex(DIR + "hero_mask.png")
	mat.set_shader_parameter("albedo", _albedo_hd if hd else _albedo)
	mat.set_shader_parameter("kit", _kit_hd if hd else _kit)
	mat.set_shader_parameter("letters", _letters)
	mat.set_shader_parameter("dress", look.get("dress", Color("2f6fc4")))
	mat.set_shader_parameter("trim", look.get("trim", Color.WHITE))
	mat.set_shader_parameter("skin", look.get("skin", Color("c48f62")))
	mat.set_shader_parameter("hair", look.get("hair", Color("1a1410")))
	var bib: Color = look.get("bib", Color("f4f4f4"))
	mat.set_shader_parameter("bib", bib)
	mat.set_shader_parameter("ink", Color(0.07, 0.07, 0.09) if bib.get_luminance() > 0.5 else Color(0.97, 0.97, 0.97))
	mat.set_shader_parameter("letter", LETTERS.find(String(look.get("pos", ""))))
	var ref: Dictionary = data().ref
	for k in ["dress", "trim", "hair", "skin"]:
		var c: Array = ref[k]
		mat.set_shader_parameter("ref_" + k, Color(c[0], c[1], c[2]))
	var torso: Dictionary = data().torso
	var cy := float(torso.chest_y)
	mat.set_shader_parameter("bib_box", Vector4(BIB_HALF, cy + BIB_BOTTOM, cy + BIB_TOP, float(torso.mid_z)))
	_mats[key] = mat
	_also_outlined.append(mat)
	return mat


## The kit's shader: the texture lit as the cel-shaded umpires are (a soft step from the sun, a rim), with the team's
## colours in place of the model's navy and light blue, scaled by the texture's own light and dark; her skin tone
## and hair; and the bib, painted from the rest position (UV2: x, y; the vertex colour's blue: z, front or back).
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform sampler2D kit : filter_linear;   // no mipmaps: the atlas's small islands would run into each other far away
uniform sampler2D letters : source_color, filter_linear_mipmap;
uniform vec3 dress : source_color;
uniform vec3 trim : source_color;
uniform vec3 skin : source_color;
uniform vec3 hair : source_color;
uniform vec3 bib : source_color;
uniform vec3 ink : source_color;
uniform vec3 ref_dress : source_color;
uniform vec3 ref_trim : source_color;
uniform vec3 ref_hair : source_color;
uniform vec3 ref_skin : source_color;
uniform int letter = -1;
uniform vec4 bib_box = vec4(0.11, 1.17, 1.38, -0.044);   // half width, bottom, top, the torso's middle (z)
uniform vec3 light_dir = vec3(0.35, 0.85, 0.4);
uniform float shade = 0.72;
varying vec3 wn;
varying vec3 rp;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
// The texture's light and dark kept, but softened (an offset under both, so the flecks in a dark navy do not become
// stains on a light colour).
vec3 paint(vec3 tex, vec3 to, vec3 from) { return to * clamp((lum(tex) + 0.15) / (lum(from) + 0.15), 0.6, 1.3); }

void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	rp = vec3(UV2.x, UV2.y, (COLOR.b - 0.5) * 1.6);
}

void fragment() {
	vec3 t = texture(albedo, UV).rgb;
	vec4 m = texture(kit, UV);
	vec3 c = t;
	c = mix(c, paint(t, dress, ref_dress), m.r);
	c = mix(c, paint(t, trim, ref_trim), m.g);
	c = mix(c, paint(t, hair, ref_hair), m.b);
	c = mix(c, paint(t, skin, ref_skin), m.a);
	// The bib: a panel on the front and the back of the chest, her position's letters on it, the right way round
	// from whichever side she is seen.
	float hw = bib_box.x;
	if (abs(rp.x) < hw && rp.y > bib_box.y && rp.y < bib_box.z && m.a < 0.5) {
		float face = rp.z > bib_box.w ? 1.0 : -1.0;
		float u = (rp.x * face + hw) / (2.0 * hw);
		float v = (bib_box.z - rp.y) / (bib_box.z - bib_box.y);
		vec3 b = bib;
		if (letter >= 0) {
			float lu = clamp((u - 0.07) / 0.86, 0.0, 1.0);
			float lv = clamp((v - 0.05) / 0.9, 0.0, 1.0);
			float a = texture(letters, vec2((float(letter) + lu) / 7.0, lv)).a;
			b = mix(b, ink, a);
		}
		c = b;
	}
	float d = dot(normalize(wn), normalize(light_dir));
	float k = mix(shade, 1.0, smoothstep(-0.35, 0.3, d));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * 0.18;
	ALBEDO = c * k + rim * 0.5;
}
"""
