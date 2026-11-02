class_name RiggedBody
extends Node3D
## A realistic body (a rigged mesh made by tools/rig) that follows the code-built placeholder
## skeleton in HumanModel. The placeholder keeps animating as before, just hidden; every frame each
## bone of this mesh is turned to match the matching limb, torso or head of the placeholder. Kit
## colours come from regions painted by the rig tool or, for a textured model, from its kit map
## (tools/rig/kit_texture.py): the texture gives the face, skin and the kit's folds, and the team's
## colours replace the kit's own.
##
## There can be several bodies (assets/characters/bodies/, listed in bodies.json): each player gets
## the one nearest his skin tone and build, and officials get the referees'. Bodies are packed
## (.krb, tools/rig/pack_body.py); the older JSON form still loads.

const BODIES := "res://assets/characters/bodies/"
const SHADER := """
shader_type spatial;
uniform vec3 skin_col : source_color = vec3(0.78, 0.55, 0.4);
uniform vec3 jersey_col : source_color = vec3(0.1, 0.4, 0.8);
uniform vec3 shorts_col : source_color = vec3(0.05, 0.1, 0.16);
uniform vec3 hair_col : source_color = vec3(0.08, 0.06, 0.05);
varying vec3 region;
void vertex() {
	region = COLOR.rgb;   // one channel per region: jersey, shorts, hair; none = skin
}
void fragment() {
	vec3 c = skin_col;
	float rough = 0.6;
	float m = max(region.r, max(region.g, region.b));
	if (m > 0.5) {
		if (region.r >= m) { c = jersey_col; rough = 0.85; }
		else if (region.g >= m) { c = shorts_col; rough = 0.85; }
		else { c = hair_col; rough = 0.95; }
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	RIM = rough > 0.8 ? 0.5 : 0.25;
	RIM_TINT = 0.4;
}
"""
const SHADER_TEXTURED := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D kit_tex : filter_linear_mipmap, repeat_disable;   // r main, g trim, b shading / 2, a not skin
uniform vec3 skin_ratio = vec3(1.0);   // this player's skin over the texture's, in linear light
uniform bool skin_mask = false;        // the kit map's alpha is 0 on skin (older maps have none)
uniform vec3 jersey_col : source_color = vec3(0.1, 0.4, 0.8);
uniform vec3 shorts_col : source_color = vec3(0.05, 0.1, 0.16);
uniform vec3 trim_col : source_color = vec3(1.0);
uniform float recolour = 1.0;          // 0 keeps the texture's own clothes (referees)
uniform float sweat = 0.0;             // 0..1: skin shines more as he works (Athlete: from his energy)
varying vec3 region;
void vertex() {
	region = COLOR.rgb;   // r jersey, g shorts, b hair
}
void fragment() {
	vec3 t = texture(albedo_tex, UV).rgb;
	vec4 k = texture(kit_tex, UV);
	// Only skin takes the player's tone: shirts, shoes and hair keep theirs.
	float skin = skin_mask ? 1.0 - k.a : 1.0 - region.b;
	vec3 body = t * mix(vec3(1.0), skin_ratio, skin);
	// Sharp edges: a little kit bleeding in from a neighbouring piece of the texture (or a
	// little skin into the kit) is dropped.
	float amount = smoothstep(0.3, 0.7, k.r + k.g) * recolour;
	vec3 kit_col = (mix(jersey_col, shorts_col, region.g) * k.r + trim_col * k.g) / max(k.r + k.g, 0.001);
	ALBEDO = mix(body, kit_col * k.b * 2.0, amount);
	// Skin: a soft sheen, wetter as he sweats, and warm light carried through it where it is thin; cloth: matte, with
	// the sheen of a jersey at grazing angles. Both pick up the lights behind them at the edges. Hair, shoes and the
	// referees' clothes stay as they were.
	float bare = skin * (1.0 - amount);
	ROUGHNESS = mix(mix(0.6, mix(0.52, 0.34, sweat), bare), 0.86, amount);
	SPECULAR = mix(mix(0.35, 0.42 + 0.18 * sweat, bare), 0.28, amount);
	RIM = mix(0.15, 0.45, amount);
	RIM_TINT = mix(0.6, 0.3, amount);
	BACKLIGHT = vec3(0.32, 0.12, 0.07) * bare;
}
"""

static var _bodies := {}   # path -> the loaded body (see _load)
static var grounding := true   # put bodies on the floor (off only to compare, in tests/ground_check)
static var _index = null

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var material: ShaderMaterial
var mirror: ShaderMaterial    # the shared foundation's body drawn for this one (FoundationLink): sweat and detail too
var _sweat := 0.0
var body := {}        # the loaded body this one wears
var _bone := {}       # name -> index
var _parent := []     # index -> parent index
var _rest_head := []  # index -> rest position of the bone head (model space)
var _names := []      # index -> bone name
var _leg_bones := {}  # indices of the thighs, shins and feet: all that can touch the floor standing up
var _side_bones := {"l": {}, "r": {}}   # side -> indices of that leg's thigh, shin and foot
var _hidden_head := false
# Planted feet: a foot flat on the floor keeps its place in the world until it lifts (see _plant_feet).
const PLANT_DOWN := 0.03     # m: heel and toe this close to the floor and the foot is planted
const PLANT_SLIP := 0.2      # m: furthest a planted foot is held from where the motion puts it
const FLAT_EASE := 0.1       # s to lay a foot flat on the floor or let it go (_flatten)
const PLANT_TAKE := 0.1      # s to plant a foot that has come down (_plant_feet) ...
const PLANT_LET_GO := 0.08   # s ... and to let it go (_plant_feet, _release_plants)
const PLANT_SINK := 0.03     # m the planted feet may bring the hips down below where the motion has them (_ground)
const RUN_STATES := ["raid", "ready", "idle", "walk", "evade", "telegraph", "dodge"]   # on his feet, free to run (_ground)
const STEP_LIFT := 0.05      # m: a foot let go at the slip limit lifts this high as it steps on
const SWING_LIFT := 0.07     # m: a foot stepping on purpose (step) lifts this high as it comes through
const SETTLE_OFF := 0.12     # m: standing ready, a planted foot this far from where his stance has it steps there ...
const SETTLE_STEP := 0.28    # ... taking this long (s), ...
const SETTLE_LIFT := 0.06    # ... lifted this high (m), ...
const SETTLE_GAP := 0.2      # ... one foot at a time, this long (s) after the last (_plant_feet)
const SETTLE_STATES := ["ready", "idle"]   # standing (_ground)
const MAX_SINK := 0.3        # m the hips may come down for a held leg to reach its hold (_sink_to_hold) ...
const SINK_RISE := 2.5       # ... and m/s they come back up at, the hold let go (a foot torn out of the hands as he springs)
const SETTLE_DROP := 3.0     # m/s a body held by the leg it stood on comes down onto the other (_ground)
const RISE_MAX := 4.0        # m/s the body's middle may rise against its root, whatever lifts it (_limit_height) ...
const FALL_MAX := 5.0        # ... and come down
const TURN_MAX := 1200.0     # deg/s any bone of the drawn body may turn, whatever turns it (_limit_turns)
const BEND_MIN := 0.04       # m off straight an elbow must be to say which way it bends (_ik_two)
var _flat_w := {}            # side -> how far its foot is being laid flat, eased from frame to frame (_flatten)
var _plant := {}             # side -> [world position of the held sole point, how firmly held 0..1, which point,
                             #          let go at the slip limit (stepping)]
var _replant := {}           # side -> seconds before a foot let go at the slip limit may be held again
var _stepping := {}          # side -> [where the foot left the floor (world, the ankle), the clock then, how long the step
                             #          takes]: a step on purpose (step)
var _plant_t := -1.0         # the motion's clock at the last frame, for the time step
var _settle_wait := 0.0      # s before the next settling step may start (_plant_feet)
var settle_steps := 0        # settling steps taken, all told (for tests)
var _sunk := 0.0             # how far _sink_to_hold had the hips down last frame (skeleton space)
var _held_out := {}          # sides _held_legs left out of what he stands on last frame
var _rejoined := {}          # bones of a leg back in what he stands on this frame, let go of (_ground)
var _newly_held := {}        # sides newly left out of what he stands on this frame, held (_ground)
var _lifted := 0.0           # how far _ground still holds the hips up over the leg he now stands on (skeleton space)
var _standing := true        # on his feet, as far as what touches the floor goes (_ground)
var _mid_y := INF            # the body's middle's height last frame (skeleton space; _limit_height)
# Holds (see Grapple): hands reaching for a point on another player's body, and a foot kept where a
# defender holds it. hands_free is where this body's hands are before they reach (world, last frame).
var hand_target := {}        # side -> {model: HumanModel or null, part, offset (world), point (world, when model
                             #          is null), w, fade}
var foot_goal := {}          # side -> [world position of the ankle joint, weight, weight lost per second (0: held)]
var kick_goal := Vector3.INF # a kick reaching for a defender: where the toe goes (world; Match) ...
var kick_w := 0.0            # ... and how far into the reach it is, 0..1
var _kick_leg := ""          # the leg the kick goes out with (_reach_kick)
var hands_free := Vector3.INF
var _hand_t := -1.0
var _bend := {}              # hand -> which way its elbow bent last frame, reaching for a hold (skeleton space)
var _curl := {"l": 0.7, "r": 0.7}
var _turns := {}             # bone -> how it was turned last frame, as drawn (skeleton space; _limit_turns)
var _turn_t := -1.0
var limited := 0             # bones _limit_turns has held back, all told (for tests)


## The bodies on offer: [{file, kind ("player" or "referee"), build, skin}], from bodies.json.
static func bodies() -> Array:
	if _index == null:
		_index = []
		var path := BODIES + "bodies.json"
		if FileAccess.file_exists(path):
			var d = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Array:
				for e in d:
					if FileAccess.file_exists(BODIES + String(e.file)):
						_index.append(e)
	return _index


static func available() -> bool:
	return not bodies().is_empty()


## The bodies on show: the player bodies bodies.json marks "featured" (new ones to see in matches), in its order,
## which each side's first players wear in a match that asks for them (Match: config "featured", as Quick Match does).
static func featured() -> Array:
	var out := []
	for e in bodies():
		if String(e.kind) == "player" and bool(e.get("featured", false)):
			out.append(String(e.file))
	return out


## The body for a person: the nearest in skin tone and build among those of his kind, with a little
## of the seed so team-mates alike don't all look the same. Officials fall back to players' bodies. A body
## bodies.json marks "pick": false is only worn when it is featured.
static func pick(kind: String, skin: Color, build: float, seed: int) -> String:
	var options := bodies().filter(func(e): return String(e.kind) == kind and bool(e.get("pick", true)))
	if options.is_empty():
		options = bodies().filter(func(e): return String(e.kind) == "player" and bool(e.get("pick", true)))
	if options.is_empty():
		return ""
	var best := ""
	var best_score := INF
	for i in options.size():
		var e: Dictionary = options[i]
		var sk: Array = e.get("skin", [0.75, 0.55, 0.42])
		var tone := Color(float(sk[0]), float(sk[1]), float(sk[2]))
		var score := absf(tone.get_luminance() - skin.get_luminance()) * 2.0 + absf(float(e.get("build", 1.0)) - build) * 3.0
		score += float(hash(seed * 31 + i) % 1000) / 1000.0 * 0.25
		if score < best_score:
			best_score = score
			best = String(e.file)
	return best


static func _path(file: String) -> String:
	return BODIES + file


## Load a body once: its mesh, textures and the rest-pose measures used to drive it.
static func _load(file: String) -> Dictionary:
	if _bodies.has(file):
		return _bodies[file]
	var path := _path(file)
	var d := _read_krb(path) if path.ends_with(".krb") else _read_json(path)
	_bodies[file] = d
	if d.is_empty():
		push_warning("rigged body: could not read " + path)
		return d
	var verts: PackedVector3Array = d.verts
	d.shader = Shader.new()
	d.shader.code = SHADER_TEXTURED if d.get("albedo") else SHADER
	var j := {}
	for b in d.bones:
		j[b.name] = [_v(b.head), _v(b.tail)]
	var rest_dirs := {}
	for name in j:
		rest_dirs[name] = (j[name][1] - j[name][0]).normalized()
	var curl_axis := {}
	for b in d.bones:
		if b.has("palm") and String(b.name).begins_with("fingers_"):
			curl_axis[String(b.name).right(1)] = (rest_dirs[b.name] as Vector3).cross(_v(b.palm)).normalized()
	var across: Vector3 = j.upperarm_r[0] - j.upperarm_l[0]
	var hips_across: Vector3 = j.thigh_r[0] - j.thigh_l[0]
	var frames := {}
	frames["hips"] = _frame(rest_dirs.hips, hips_across)
	for name in ["spine", "chest", "neck", "head"]:
		frames[name] = _frame(rest_dirs[name], across)
	var leg := 0.0
	for s in ["l", "r"]:
		leg += (j["thigh_" + s][1] - j["thigh_" + s][0]).length() + (j["shin_" + s][1] - j["shin_" + s][0]).length() + j["foot_" + s][0].y
	d.leg_len = leg * 0.5
	# How far behind the chest bone the back surface is, along the rest chest's back axis.
	var chest: Basis = frames.chest
	var back: Vector3 = chest.z
	var best := 0.0
	var head_c: Vector3 = j.chest[0]
	for v in verts:
		var dv := v - head_c
		if absf(dv.dot(chest.y)) < 0.08 and absf(dv.dot(chest.x)) < 0.08:
			best = maxf(best, dv.dot(back))
	d.back_offset = back * (best + 0.012)
	d.stand_h = d.leg_len + (j.thigh_l[0].distance_to(j.hips[0]) * 0.3) + j.hips[0].distance_to(j.neck[0]) + j.neck[0].distance_to(j.head[1])
	d.rest_dirs = rest_dirs
	d.rest_frames = frames
	d.curl_axis = curl_axis
	_contacts(d, j)
	d.erase("verts")
	d.erase("top_bone")
	return d


## Points on the body's surface that can meet the floor, per bone, as offsets from the bone's head at rest:
## the furthest each way (front, back, sides, top, bottom) of the skin the bone carries, and on each foot its
## sole, heel to toe and side to side.
static func _contacts(d: Dictionary, _j: Dictionary) -> void:
	var verts: PackedVector3Array = d.verts
	var top: PackedInt32Array = d.get("top_bone", PackedInt32Array())
	d.contacts = []
	d.soles = {}
	if top.is_empty():
		return
	var nb: int = d.bones.size()
	var heads := []
	var feet := {}
	for bi in nb:
		heads.append(_v(d.bones[bi].head))
		if String(d.bones[bi].name).begins_with("foot_"):
			feet[bi] = String(d.bones[bi].name).right(1)
	# One pass: each bone's furthest skin along +-x, +-y, +-z and the eight diagonals between them, and
	# each foot's lowest skin.
	var dirs := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			for z in [-1.0, 1.0]:
				dirs.append(Vector3(x, y, z).normalized())
	var nd := dirs.size()
	var score := PackedFloat32Array()
	score.resize(nb * nd)
	score.fill(-INF)
	var best := PackedVector3Array()
	best.resize(nb * nd)
	var foot_low := {}
	for i in verts.size():
		var bi := top[i]
		var v := verts[i] - (heads[bi] as Vector3)
		for k in nd:
			var c: float = v.dot(dirs[k])
			if c > score[bi * nd + k]:
				score[bi * nd + k] = c
				best[bi * nd + k] = v
		if feet.has(bi):
			foot_low[bi] = minf(foot_low.get(bi, INF), verts[i].y)
	# The soles: the lowest skin of each foot at the heel, the toe and either side.
	var sole_score := {}
	var sole_best := {}
	for i in verts.size():
		var bi := top[i]
		if not feet.has(bi) or verts[i].y > float(foot_low[bi]) + 0.025:
			continue
		var v := verts[i] - (heads[bi] as Vector3)
		var c := [v.x, -v.x, -v.z, v.z]
		for k in 4:
			var key := bi * 4 + k
			if not sole_score.has(key) or c[k] > sole_score[key]:
				sole_score[key] = c[k]
				sole_best[key] = v
	for bi in nb:
		var pts := PackedVector3Array()
		for k in nd:
			if score[bi * nd + k] > -INF:
				pts.append(best[bi * nd + k])
		if feet.has(bi):
			var sole := PackedVector3Array()
			for k in 4:
				if sole_best.has(bi * 4 + k):
					sole.append(sole_best[bi * 4 + k])
			pts.append_array(sole)
			d.soles[feet[bi]] = [bi, sole]   # heel is index 3, toe index 2 (when every side was found)
		d.contacts.append(pts)


static func _texture_part(d: Dictionary, tex: Dictionary) -> void:
	if ResourceLoader.exists(String(tex.get("albedo", ""))) and ResourceLoader.exists(String(tex.get("kit", ""))):
		d.albedo = load(String(tex.albedo))
		d.kit = load(String(tex.kit))
		# The sharper albedo Medium and High wear (tools/rig/albedo_2k.py), loaded only when one of them first needs it.
		var hi := String(tex.albedo).replace("_albedo.", "_albedo_hi.")
		if hi != String(tex.albedo) and ResourceLoader.exists(hi):
			d.albedo_2k_path = hi
		var r: Array = tex.get("skin_ref", [1, 1, 1])
		d.skin_ref = Color(float(r[0]), float(r[1]), float(r[2]))
		d.skin_mask = bool(tex.get("skin_mask", false))


static func _build_mesh(d: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array,
		region: PackedByteArray, bones: PackedInt32Array, weights: PackedFloat32Array, idx: PackedInt32Array) -> void:
	var cols := PackedColorArray()
	cols.resize(verts.size())
	for i in verts.size():
		var r := region[i]
		cols[i] = Color(1.0 if r == 1 else 0.0, 1.0 if r == 2 else 0.0, 1.0 if r == 3 else 0.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	if d.get("albedo") and not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	d.mesh = mesh
	d.verts = verts
	# Each vertex's main bone, for the contact points (see _contacts).
	var top := PackedInt32Array()
	top.resize(verts.size())
	for i in verts.size():
		var best := 0
		for k in range(1, 4):
			if weights[i * 4 + k] > weights[i * 4 + best]:
				best = k
		top[i] = bones[i * 4 + best]
	d.top_bone = top


## The packed form (tools/rig/pack_body.py).
static func _read_krb(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_buffer(4).get_string_from_ascii() != "KRB1":
		return {}
	var meta = JSON.parse_string(f.get_buffer(f.get_32()).get_string_from_utf8())
	if not (meta is Dictionary):
		return {}
	var n := int(meta.vertices)
	var pad := func(x: int) -> int: return x + (4 - x % 4) % 4
	var pos := f.get_buffer(pad.call(n * 6))
	var nrm := f.get_buffer(pad.call(n * 3))
	var uvb := f.get_buffer(pad.call(n * 4)) if meta.has_uv else PackedByteArray()
	var bb := f.get_buffer(pad.call(n * 4))
	var wb := f.get_buffer(pad.call(n * 4))
	var region := f.get_buffer(pad.call(n))
	var u32 := bool(meta.index_u32)
	var ib := f.get_buffer(int(meta.indices) * (4 if u32 else 2))
	var lo := _v(meta.pos_min)
	var span := _v(meta.pos_span) / 65535.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(n)
	norms.resize(n)
	if meta.has_uv:
		uvs.resize(n)
	for i in n:
		verts[i] = lo + Vector3(pos.decode_u16(i * 6), pos.decode_u16(i * 6 + 2), pos.decode_u16(i * 6 + 4)) * span
		norms[i] = Vector3(nrm.decode_s8(i * 3), nrm.decode_s8(i * 3 + 1), nrm.decode_s8(i * 3 + 2)).normalized()
		if meta.has_uv:
			uvs[i] = Vector2(uvb.decode_u16(i * 4), uvb.decode_u16(i * 4 + 2)) / 65535.0
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(n * 4)
	weights.resize(n * 4)
	for i in n * 4:
		bones[i] = bb[i]
		weights[i] = wb[i] / 255.0
	var count := int(meta.indices)
	var idx := PackedInt32Array()
	idx.resize(count)
	# glTF and trimesh wind front faces counter-clockwise; Godot wants clockwise.
	for t in count / 3:
		for c in 3:
			var k = t * 3 + [0, 2, 1][c]
			idx[t * 3 + c] = ib.decode_u32(k * 4) if u32 else ib.decode_u16(k * 2)
	var d := {"bones": meta.bones, "height": float(meta.height)}
	_texture_part(d, meta.get("texture", {}))
	_build_mesh(d, verts, norms, uvs, region.slice(0, n), bones, weights, idx)
	return d


## The older JSON form.
static func _read_json(path: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return {}
	var vs: Array = data.vertices
	var ns: Array = data.normals
	var n := vs.size() / 3
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(n)
	norms.resize(n)
	for i in n:
		verts[i] = Vector3(vs[i * 3], vs[i * 3 + 1], vs[i * 3 + 2])
		norms[i] = Vector3(ns[i * 3], ns[i * 3 + 1], ns[i * 3 + 2])
	var uvs := PackedVector2Array()
	if data.has("uvs"):
		var us: Array = data.uvs
		uvs.resize(n)
		for i in n:
			uvs[i] = Vector2(us[i * 2], us[i * 2 + 1])
	var region := PackedByteArray()
	for r in data.region:
		region.append(int(r))
	var src: Array = data.indices
	var idx := PackedInt32Array()
	idx.resize(src.size())
	for t in src.size() / 3:
		idx[t * 3] = int(src[t * 3])
		idx[t * 3 + 1] = int(src[t * 3 + 2])
		idx[t * 3 + 2] = int(src[t * 3 + 1])
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for b in data.bones4:
		bones.append(int(b))
	for w in data.weights4:
		weights.append(float(w))
	var d := {"bones": data.bones, "height": float(data.height)}
	_texture_part(d, data.get("texture", {}))
	_build_mesh(d, verts, norms, uvs, region, bones, weights, idx)
	return d


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Orthonormal frame from a main axis (Y) and a sideways hint (X).
static func _frame(up: Vector3, side: Vector3) -> Basis:
	var y := up.normalized()
	var z := side.cross(y).normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


func setup(skin: Color, jersey: Color, shorts: Color, hair: Color, height: float, trim := Color.WHITE, file := "") -> void:
	body = _load(file)
	set_meta("file", file)
	if body.is_empty():
		return
	skeleton = Skeleton3D.new()
	add_child(skeleton)
	var skin_res := Skin.new()
	for b in body.bones:
		var i := skeleton.get_bone_count()
		skeleton.add_bone(String(b.name))
		_bone[String(b.name)] = i
		_names.append(String(b.name))
		if String(b.name).begins_with("shin_") or String(b.name).begins_with("foot_"):
			_leg_bones[i] = true
		for part in ["thigh_", "shin_", "foot_"]:
			for sd in ["l", "r"]:
				if String(b.name) == part + sd:
					_side_bones[sd][i] = true
		var p := int(b.parent)
		_parent.append(p)
		var head := _v(b.head)
		_rest_head.append(head)
		if p >= 0:
			skeleton.set_bone_parent(i, p)
			skeleton.set_bone_rest(i, Transform3D(Basis(), head - _rest_head[p]))
		else:
			skeleton.set_bone_rest(i, Transform3D(Basis(), head))
		skin_res.add_named_bind(String(b.name), Transform3D(Basis(), head).affine_inverse())
	skeleton.reset_bone_poses()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = body.mesh
	mesh_instance.skin = skin_res
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	material = ShaderMaterial.new()
	material.shader = body.shader
	material.set_shader_parameter("skin_col", skin)
	material.set_shader_parameter("jersey_col", jersey)
	material.set_shader_parameter("shorts_col", shorts)
	material.set_shader_parameter("hair_col", hair)
	if body.get("albedo"):
		material.set_shader_parameter("albedo_tex", albedo_for(body))
		material.set_shader_parameter("kit_tex", body.kit)
		material.set_shader_parameter("trim_col", trim)
		material.set_shader_parameter("skin_mask", body.get("skin_mask", false))
		# Referees come dressed for the job; only players wear their team's colours.
		var kind := "player"
		for e in bodies():
			if String(e.file) == file:
				kind = String(e.kind)
		material.set_shader_parameter("recolour", 0.0 if kind == "referee" else 1.0)
		var a := skin.srgb_to_linear()
		var b: Color = (body.skin_ref as Color).srgb_to_linear()
		material.set_shader_parameter("skin_ratio", Vector3(a.r / b.r, a.g / b.g, a.b / b.b))
	mesh_instance.material_override = material
	scale = Vector3.ONE * (height / float(body.stand_h))


## The shirt number, stuck to the back of the chest bone.
## A body's albedo at this graphics level: the 1536 px one on Medium and High where it has one, the 1K one on Low.
static func albedo_for(d: Dictionary) -> Texture2D:
	if Game.detail_textures() and d.has("albedo_2k_path"):
		if not d.has("albedo_2k"):
			d.albedo_2k = load(String(d.albedo_2k_path))
		return d.albedo_2k
	return d.get("albedo")


## The graphics level changed: wear the albedo for it (albedo_for).
func detail_changed() -> void:
	if material and body.get("albedo"):
		material.set_shader_parameter("albedo_tex", albedo_for(body))
		if mirror:
			mirror.set_shader_parameter("albedo_tex", albedo_for(body))


func add_number(n: int, col: Color, outline: Color) -> void:
	if skeleton == null:
		return
	var att := BoneAttachment3D.new()
	skeleton.add_child(att)
	att.bone_name = "chest"
	var lab := Label3D.new()
	lab.text = str(n)
	lab.font_size = 96
	lab.pixel_size = 0.0024
	lab.outline_size = 8
	lab.modulate = col
	lab.outline_modulate = outline
	lab.double_sided = false
	# The attachment sits at the bone head, turned with the bone; place the label on the
	# back surface in the rest pose's frame.
	var f: Basis = body.rest_frames.chest
	lab.transform = Transform3D(f, f * Vector3(0, 0.02, 0) + body.back_offset)
	att.add_child(lab)


## How wet his skin looks, 0..1 (SHADER_TEXTURED's sweat).
func set_sweat(v: float) -> void:
	if material and not is_equal_approx(_sweat, v):
		_sweat = v
		material.set_shader_parameter("sweat", v)
		if mirror:
			mirror.set_shader_parameter("sweat", v)


func set_head_visible(v: bool) -> void:
	_hidden_head = not v


## Turn every bone to match the placeholder body h (a HumanModel).
func drive(h: Node3D) -> void:
	if skeleton == null:
		return
	var inv := h.global_transform.affine_inverse()
	var g := {}
	# Torso and head: whole frames.
	g["hips"] = _match("hips", _basis_of(h.pelvis, inv))
	g["spine"] = _match("spine", _basis_of(h.spine, inv))
	g["chest"] = _match("chest", _basis_of(h.chest, inv))
	g["neck"] = _match("neck", _basis_of(h.neck, inv))
	g["head"] = _match("head", _basis_of(h.head, inv))
	# Limbs: swing each bone onto the placeholder limb's direction.
	for s in ["l", "r"]:
		var sh: Node3D = h.sh_l if s == "l" else h.sh_r
		var el: Node3D = h.el_l if s == "l" else h.el_r
		var hip: Node3D = h.hip_l if s == "l" else h.hip_r
		var kn: Node3D = h.kn_l if s == "l" else h.kn_r
		g["upperarm_" + s] = _swing("upperarm_" + s, inv * el.global_position - inv * sh.global_position, g)
		var fore := _basis_of(el, inv) * Vector3.DOWN
		g["forearm_" + s] = _swing("forearm_" + s, fore, g)
		g["hand_" + s] = _swing("hand_" + s, fore, g)
		g["thigh_" + s] = _swing("thigh_" + s, inv * kn.global_position - inv * hip.global_position, g)
		var kb := _basis_of(kn, inv)
		g["shin_" + s] = _swing("shin_" + s, kb * Vector3.DOWN, g)
		g["foot_" + s] = _swing("foot_" + s, kb * Vector3(0, -0.35, -1.0), g)
		if body.curl_axis.has(s):
			var axis: Vector3 = body.curl_axis[s]
			_curl[s] = lerpf(_curl[s], _finger_curl(h, s), 0.25)
			g["fingers_" + s] = g["hand_" + s] * Basis(axis, _curl[s] * (0.55 if _bone.has("fingertips_" + s) else 1.0))
			if _bone.has("fingertips_" + s):
				g["fingertips_" + s] = g["fingers_" + s] * Basis(axis, _curl[s] * 0.75)
	# Hips: the placeholder's pelvis, scaled to this body's legs, then the body put on the floor.
	var pel: Vector3 = inv * h.pelvis.global_position
	var k := float(body.leg_len) / maxf(0.5, h.leg_length())
	var hips := _ground(g, Vector3(pel.x * k, pel.y * k, pel.z * k), h)
	_reach_kick(g, hips)
	_reach_hands(g, hips, float(h._t))
	_limit_turns(g, float(h._t))
	for name in g:
		var i: int = _bone[name]
		var p: int = _parent[i]
		var local: Basis = g[name] if p < 0 else (g[_name_of(p)].inverse() * g[name])
		skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())
	skeleton.set_bone_pose_position(0, hips)
	if _hidden_head:
		skeleton.set_bone_pose_scale(_bone.head, Vector3.ONE * 0.001)
	else:
		skeleton.set_bone_pose_scale(_bone.head, Vector3.ONE)


## The last word on the pose: no bone of the drawn body turns faster than TURN_MAX, whatever turned it (a limb
## swung onto the placeholder's where its direction flips, a foot planted or let go, a hand reaching for a hold). A
## bone that would turn further in one frame goes as far as it may now and the rest of the way over the next
## frames, so nothing on screen snaps. The hand-made pose has a stage like it of its own (HumanModel._settle), but
## that comes before the limbs are swung onto this body and the feet and hands are placed.
func _limit_turns(g: Dictionary, now: float) -> void:
	var dt := clampf(now - _turn_t, 0.0, 0.1) if _turn_t >= 0.0 else 0.0
	_turn_t = now
	var cap := deg_to_rad(TURN_MAX) * dt
	for name in g:
		var b: Basis = g[name]
		var q := b.get_rotation_quaternion()
		if dt > 0.0 and _turns.has(name):
			var q0: Quaternion = _turns[name]
			var a := q0.angle_to(q)
			if a > cap:
				q = q0.slerp(q, cap / a)
				g[name] = Basis(q).scaled_local(b.get_scale())
				limited += 1
		_turns[name] = q


## Put the body on the floor: its lowest point (a sole standing, the back or a shoulder lying down) as high
## as the motion means it to be (h.air: off the floor in a jump or a running stride, else on it). Feet near
## the floor are laid flat on it, and a player standing still has his higher foot brought down onto it too.
## A foot a defender holds (foot_goal) is where the defender holds it, not something to stand on: the body
## stands on the other one, and the held leg reaches for the hold, in the air too.
## Returns the hips' position; turns the feet and legs in g.
func _ground(g: Dictionary, hips: Vector3, h: Node3D) -> Vector3:
	if not grounding or (body.get("contacts", []) as Array).is_empty():
		_mid_y = INF
		return hips
	var target := float(h.air) / scale.y
	var up: Vector3 = (g.get("chest", Basis()) as Basis) * (body.rest_dirs.chest as Vector3)
	# Standing (only the legs can be the lowest point) or not, with a gap between the two so a body bent right over
	# does not flip between them from one frame to the next (and jump up and down with it).
	if _standing:
		_standing = hips.y > 0.66 * float(body.leg_len) and up.y > 0.7
	else:
		_standing = hips.y > 0.74 * float(body.leg_len) and up.y > 0.8
	var standing := _standing
	# On his feet and free to move (running, stepping about, standing ready), the feet are laid flat as a runner's
	# (_flatten). Held, down or getting up, as they were before: a held raider's free foot stood on its toes, off the
	# floor four frames in five in a hold he drove against, and a raider caught by three at once, then taken down, had
	# his feet sliding 1.8 m/s.
	var ath := h.get_parent()
	var stride := 1.0 if ath == null or String(ath.get("state")) in RUN_STATES else 0.0
	var dt := clampf(float(h._t) - _plant_t, 0.0, 0.1) if _plant_t >= 0.0 else 0.0
	_plant_t = float(h._t)
	var held := _held_legs(dt)
	var low := _lowest(_fk(g, hips), standing, held)
	if not _rejoined.is_empty():
		# A leg let go of, back in what he stands on (it was left out of it while held): he comes up onto it no faster
		# than SINK_RISE (_sink_to_hold), the leg bending under him meanwhile, rather than in a frame. (Let go of as the
		# other is caught, in the same frame, there is nothing in what is left to stand on, and nothing to come up out
		# of: taken as a sink, that nothing was an endless one, and the body went off to infinity.)
		var back := _lowest(_fk(g, hips), standing, held.merged(_rejoined))
		if back != INF:
			_sunk = maxf(_sunk, back - low)
	# Held by the leg he was standing on (a back kick caught, say): he comes down onto the other leg no faster than
	# SETTLE_DROP, rather than dropping onto it in a frame.
	_lifted = maxf(0.0, _lifted - SETTLE_DROP / scale.y * dt)
	if not _newly_held.is_empty():
		var with := held.duplicate()
		for s in _newly_held:
			for b in _side_bones[s]:
				with.erase(b)
		var under := _lowest(_fk(g, hips), standing, with)
		if under != INF:
			_lifted = maxf(_lifted, low - under)
	hips.y += target - low + _lifted
	if target > 0.02:
		hips = _sink_to_hold(g, hips, target, dt)
		hips = _limit_height(g, hips, dt, false)
		# In the air: nothing to stand on. A foot laid flat or planted is let go of over a few frames, as it is
		# lifted off the floor standing: let go at once, every stride of a run turned the feet 40 degrees and more in
		# a frame as it left the floor and again as it landed.
		var fk_air := _fk(g, hips)
		for s in body.soles:
			_flatten(g, fk_air, s, dt, true, stride)
		_release_plants(g, _fk(g, hips), dt)
		_hold_feet(g, _fk(g, hips))
		return hips
	var fk := _fk(g, hips)
	for s in body.soles:
		_flatten(g, fk, s, dt, false, stride)
	# fk's bone positions still hold after laying the feet flat (only the feet turned, read from g below).
	var still := float(h.speed) < 1.2 and float(h.kick) + float(h.back_kick) + float(h.jump) + float(h.dubki) < 0.1
	if standing and still and held.is_empty():
		fk = _fk(g, hips)
		var lows := {}
		for s in body.soles:
			lows[s] = _sole_low(fk, s)
		if lows.size() == 2:
			var hi: String = "l" if lows.l > lows.r else "r"
			var d: float = absf(float(lows.l) - float(lows.r))
			if d > 0.005 and d < 0.12:
				_reach_down(g, fk, hi, d)
				fk = _fk(g, hips)
	# On his feet, crouched or not (lying, diving and sprawling are not): the feet are planted. On one leg, the
	# other held, he may be bent right over it and still be standing on it: judged by his hips, not his chest.
	var on_feet := up.y > 0.4
	if not on_feet and float(h.get("one_leg")) > 0.5:
		on_feet = ((g.get("hips", Basis()) as Basis) * (body.rest_dirs.hips as Vector3)).y > 0.5
	if on_feet and hips.y > 0.35 * float(body.leg_len):
		# Standing ready (not moving off, nothing holding him): a foot left out of place steps back under him.
		var settling := ath != null and String(ath.get("state")) in SETTLE_STATES and float(h.speed) < 0.35 \
			and held.is_empty() and foot_goal.is_empty()
		_plant_feet(g, fk, dt, settling)
	else:
		_release_plants(g, fk, dt)
	# Back on the floor after the feet were laid flat and planted, then down for a held leg to reach its hold,
	# and the held leg reaching for it last of all, so nothing moves it off the hold afterwards.
	var settle := target - _lowest(_fk(g, hips), standing, held) + _lifted
	if not _plant.is_empty() and foot_goal.is_empty() and _sunk <= 0.0:
		# A planted foot the leg no longer reaches from where the motion has the hips (left behind him as he runs
		# on) comes off the floor and is let go of (_plant_feet), rather than pull the hips down after it: they sank
		# up to 15 cm through every running stride and came back up in a frame as it left the floor.
		settle = maxf(settle, -PLANT_SINK / scale.y)
	hips = Vector3(hips.x, hips.y + settle, hips.z)
	if not foot_goal.is_empty() or _sunk > 0.0:
		hips = _sink_to_hold(g, hips, 0.0, dt)
	hips = _limit_height(g, hips, dt, standing)
	_hold_feet(g, _fk(g, hips))
	return hips


## The body's middle rises no faster than RISE_MAX and comes down no faster than FALL_MAX against the body's root,
## whatever moves it: the body set down on whatever is lowest (a dive coming down onto the chest as that goes lower
## than the feet), a clip blended in over a few frames (a get-up from the floor), a hold's sink, a spring out of a
## crouch. Each was a jump of the middle of 0.2 to 0.3 m in a frame, now spread over the frames a body would take.
## The middle is where anchor("waist") has it, most of the way from the hips up the spine: a trunk tipping over brings
## it down as well as the hips coming down (a dive going down, the hips held to FALL_MAX, still dropped it 0.2 m in a
## frame). Held down, a foot that would go through the floor is lifted out of it (the knee bends); held up, standing,
## a foot that was on the floor reaches down to it as far as the leg goes. Returns the hips.
func _limit_height(g: Dictionary, hips: Vector3, dt: float, standing: bool) -> Vector3:
	var fk := _fk(g, hips)
	var mid := hips.y
	if _bone.has("spine"):
		mid = lerpf(hips.y, (fk[0][_bone["spine"]] as Vector3).y, 0.7)
	if not is_finite(mid):
		# (Never, now that nothing above sends the hips off to infinity; were it to, he stays where he was.)
		hips.y = _mid_y if is_finite(_mid_y) else 0.0
		return hips
	var y := mid
	if _mid_y != INF and dt > 0.0:
		y = clampf(y, _mid_y - FALL_MAX / scale.y * dt, _mid_y + RISE_MAX / scale.y * dt)
	_mid_y = y
	if y == mid:
		return hips
	var was := {}
	for s in body.soles:
		was[s] = _sole_low(fk, s)
	var off := y - mid
	hips.y += off
	fk = _fk(g, hips)
	var down := PLANT_DOWN / scale.y
	for s in body.soles:
		if not (_bone.has("thigh_" + s) and _bone.has("shin_" + s) and _bone.has("foot_" + s)):
			continue
		if foot_goal.has(s) and float(foot_goal[s][1]) > 0.5:
			continue   # held: where the hold has it (_hold_feet)
		var now := float(was[s]) + off
		var lift := 0.0
		if now < 0.0:
			lift = -now
		elif off > 0.0 and standing and float(was[s]) < down:
			lift = -off
		if lift != 0.0:
			_ik_leg(g, fk, s, (fk[0][_bone["foot_" + s]] as Vector3) + Vector3(0.0, lift, 0.0))
			fk = _fk(g, hips)
	return hips


## A held foot the leg cannot reach from where the hips are: the hips come down until it can, as a person held
## by the ankle sinks on the other leg (no further than MAX_SINK). Standing, the free leg bends to keep its foot
## where it is on the floor; in the air (a hop, air above the floor), the free leg tucks up to stay off it, so
## a hop is as high as the held leg lets the hips go and no higher. The hold let go, the hips come back up no
## faster than SINK_RISE: he straightens as he springs or steps away, not in a frame. Returns the hips.
func _sink_to_hold(g: Dictionary, hips: Vector3, air: float, dt: float) -> Vector3:
	var inv := skeleton.global_transform.affine_inverse()
	var fk := _fk(g, hips)
	var drop := 0.0
	for s in foot_goal:
		var fg: Array = foot_goal[s]
		# A foot being let go of (its hold fading) pulls him down no further: the sink he had lets him up (below).
		if float(fg[1]) < 0.5 or (fg.size() > 2 and float(fg[2]) > 0.0) \
				or not (_bone.has("thigh_" + s) and _bone.has("shin_" + s) and _bone.has("foot_" + s)):
			continue
		var hip: Vector3 = fk[0][_bone["thigh_" + s]]
		var goal: Vector3 = inv * (fg[0] as Vector3)
		var l := ((_rest_head[_bone["thigh_" + s]] as Vector3).distance_to(_rest_head[_bone["shin_" + s]]) \
			+ (_rest_head[_bone["shin_" + s]] as Vector3).distance_to(_rest_head[_bone["foot_" + s]])) * 0.995
		var flat := Vector2(goal.x - hip.x, goal.z - hip.z).length()
		var dy := sqrt(maxf(0.0, l * l - flat * flat))
		drop = maxf(drop, hip.y - goal.y - dy)
	drop = minf(drop, MAX_SINK / scale.y)
	drop = maxf(drop, _sunk - SINK_RISE / scale.y * dt)
	_sunk = maxf(drop, 0.0)
	if drop <= 0.0:
		return hips
	var keep := {}
	for s in body.soles:
		if not (foot_goal.has(s) and float(foot_goal[s][1]) >= 0.5) and _bone.has("foot_" + s):
			# Where it is: on the floor it stays there; off it (the body lifted onto a leg back under him) it goes down
			# with the hips, as far as the floor.
			var at: Vector3 = fk[0][_bone["foot_" + s]]
			if air <= 0.0:
				at.y -= clampf(_sole_low(fk, s), 0.0, drop)
			keep[s] = at
	hips.y -= drop
	for s in keep:
		var fk2 := _fk(g, hips)
		if air <= 0.0:
			_ik_leg(g, fk2, s, keep[s])
		else:
			# In the air: the free foot tucks up rather than go down through the floor with the hips.
			var under := air * 1.2 - _sole_low(fk2, s)
			if under > 0.0:
				_ik_leg(g, fk2, s, (fk2[0][_bone["foot_" + s]] as Vector3) + Vector3(0.0, under, 0.0))
	return hips


## The bones of the leg a defender holds now (fading holds let go of over their fade), to leave out of what the
## body stands on. Both legs held, he stands on both: there is nothing else to stand on.
func _held_legs(dt: float) -> Dictionary:
	var out := {}
	var sides := {}
	for s in foot_goal.keys():
		var fg: Array = foot_goal[s]
		if fg.size() > 2 and float(fg[2]) > 0.0:
			fg[1] = float(fg[1]) - float(fg[2]) * dt
			if float(fg[1]) <= 0.0:
				foot_goal.erase(s)
				continue
		if float(fg[1]) > 0.5 and _side_bones.has(s):
			out.merge(_side_bones[s])
			sides[s] = true
	if sides.size() >= 2:
		out = {}
		sides = {}
	# A leg left out last frame and not now is back in what he stands on; one left out now and not then has just been
	# taken from under him (_ground).
	_rejoined = {}
	for s in _held_out:
		if not sides.has(s):
			_rejoined.merge(_side_bones[s])
	_newly_held = {}
	for s in sides:
		if not _held_out.has(s):
			_newly_held[s] = true
	_held_out = sides
	return out


## A foot a defender holds stays where he holds it: the leg reaches for it (two-bone IK), by the hold's weight.
func _hold_feet(g: Dictionary, fk: Array) -> void:
	if foot_goal.is_empty():
		return
	var inv := skeleton.global_transform.affine_inverse()
	for s in foot_goal:
		if not (_bone.has("thigh_" + s) and _bone.has("shin_" + s) and _bone.has("foot_" + s)):
			continue
		_plant.erase(s)
		var fg: Array = foot_goal[s]
		var ankle: Vector3 = fk[0][_bone["foot_" + s]]
		_ik_two(g, fk, "thigh_" + s, "shin_" + s, "foot_" + s, ankle.lerp(inv * (fg[0] as Vector3), clampf(float(fg[1]), 0.0, 1.0)))


## A foot on the floor stays where it is in the world while the body moves over it: the point of the sole
## touching the floor (heel, ball or toe) is held, and the leg reaches for it (two-bone IK on thigh and shin)
## instead of letting the motion slide it along. As the foot rolls onto another point (heel to toe), that
## point is held where it is, so the roll stays natural. The hold is firm at once (it starts where the foot
## touches down) and lets go over a few hundredths of a second as the foot lifts. A foot the motion would
## carry more than PLANT_SLIP away is let go and steps on with a small lift; one suddenly far away (a player
## placed somewhere new) is let go at once. With settle (standing ready), a foot SETTLE_OFF out of place steps back to
## where his stance has it, one foot at a time.
func _plant_feet(g: Dictionary, fk: Array, dt: float, settle := false) -> void:
	var xf := skeleton.global_transform
	var inv := xf.affine_inverse()
	# Heights from the lowest sole, which is where the floor ends up (the body is set down on it after
	# this): laying a foot flat can lift the whole sole before that. The feet's turn is read from g, as
	# fk was worked out before they were laid flat.
	var floor_y := INF
	for s in body.soles:
		if foot_goal.has(s) and float(foot_goal[s][1]) > 0.5:
			continue   # held: not what he stands on (as _ground leaves it out), wherever the motion has it; counted, a
			           # move that put the held foot lowest (a dubki's) had the free one off the floor, and not planted
		var fb: Basis = g.get("foot_" + s, fk[1][body.soles[s][0]])
		for q in (body.soles[s][1] as PackedVector3Array):
			floor_y = minf(floor_y, (fk[0][body.soles[s][0]] as Vector3).y + (fb * q).y)
	# Still being let down onto the free leg, the one he stood on just caught (_ground, _lifted): the floor is that far
	# below its foot yet, and the foot is planted when it gets there, not in the air.
	if is_finite(_lifted):
		floor_y -= _lifted
	var down := PLANT_DOWN / scale.y
	var slip := PLANT_SLIP / scale.y
	_settle_wait = maxf(0.0, _settle_wait - dt)
	if settle and _stepping.is_empty() and _settle_wait <= 0.0:
		# The foot furthest out of place, if out by SETTLE_OFF, steps to where his stance has it. A planted foot stays where
		# it came down until the motion carries it PLANT_SLIP away (a stride's worth), and standing ready after a shuffle or
		# a clip's weight shift a leg was left out to the side, straight, for as long as he stood there.
		var worst := ""
		var worst_off := SETTLE_OFF / scale.y
		for s in _plant:
			var st0: Array = _plant[s]
			if st0[3] or float(st0[1]) < 1.0 or not body.soles.has(s):
				continue   # stepping on already, or not yet firmly down
			var bi0: int = body.soles[s][0]
			var b0: Basis = g.get("foot_" + s, fk[1][bi0])
			var held0: Vector3 = (fk[0][bi0] as Vector3) + b0 * (body.soles[s][1] as PackedVector3Array)[int(st0[2])]
			var at0: Vector3 = inv * (st0[0] as Vector3)
			var off0 := Vector2(at0.x - held0.x, at0.z - held0.z).length()
			if off0 > worst_off:
				worst = s
				worst_off = off0
		if worst != "":
			step(worst, SETTLE_STEP, SETTLE_LIFT)
			_settle_wait = SETTLE_STEP + SETTLE_GAP
			settle_steps += 1
	for s in body.soles:
		if not (_bone.has("thigh_" + s) and _bone.has("shin_" + s) and _bone.has("foot_" + s)):
			continue
		if foot_goal.has(s) and float(foot_goal[s][1]) > 0.5:
			_plant.erase(s)   # held: where the hold has it (_hold_feet)
			_stepping.erase(s)
			continue
		var bi: int = body.soles[s][0]
		var b: Basis = g.get("foot_" + s, fk[1][bi])
		var pts: PackedVector3Array = body.soles[s][1]
		var ankle: Vector3 = fk[0][_bone["foot_" + s]]
		if _stepping.has(s):
			# Stepping on purpose: from where it left the floor to where the motion has it now, lifted on the way.
			# It comes up before it goes across and is over the spot before it comes down; that spot is kept where it is
			# on the floor as the foot comes down (following the motion down, a foot coming down while he moved on slid
			# along the floor into its plant).
			var sw: Array = _stepping[s]
			var p := clampf((_plant_t - float(sw[1])) / maxf(float(sw[2]), 0.01), 0.0, 1.0)
			var q := clampf((p - 0.2) / 0.6, 0.0, 1.0)
			var goal := (inv * (sw[0] as Vector3)).lerp(ankle, q * q * (3.0 - 2.0 * q))
			if q >= 1.0:
				if sw.size() < 5:
					sw.append(xf * goal)
				var spot := inv * (sw[4] as Vector3)
				goal = Vector3(spot.x, ankle.y, spot.z)   # along the floor where it was; as high as the motion has it
			goal.y += float(sw[3]) / scale.y * sin(PI * p)
			_ik_leg(g, fk, s, goal)
			if p >= 1.0:
				_stepping.erase(s)   # down: planted where it lands (below, next frame)
			continue
		var lo := INF
		var lo_i := 0
		for i in pts.size():
			var y := (fk[0][bi] as Vector3).y - floor_y + (b * pts[i]).y
			if y < lo:
				lo = y
				lo_i = i
		var st = _plant.get(s)
		_replant[s] = maxf(0.0, float(_replant.get(s, 0.0)) - dt)
		if lo < down and (st != null or float(_replant[s]) <= 0.0):
			if st == null:
				st = [xf * ((fk[0][bi] as Vector3) + b * pts[lo_i]), 1.0, lo_i, false]
				_plant[s] = st
			if not st[3]:
				st[1] = minf(1.0, float(st[1]) + dt / PLANT_TAKE)
		elif st != null:
			st[1] = float(st[1]) - dt / PLANT_LET_GO
		if st != null and st[3]:
			st[1] = float(st[1]) - dt / 0.12   # stepping on after being let go at the slip limit
		if st == null:
			continue
		if float(st[1]) <= 0.0:
			_plant.erase(s)
			continue
		var held: Vector3 = (fk[0][bi] as Vector3) + b * pts[int(st[2])]
		var at: Vector3 = inv * (st[0] as Vector3)
		var off := Vector3(at.x - held.x, 0.0, at.z - held.z)
		if off.length() > 3.0 * slip:
			_plant.erase(s)
			continue
		if off.length() > slip:
			# The motion carries this foot on while it stays down (a shuffle's trailing foot slides along
			# the floor in the clip): let it go and step, rather than drag it at the limit.
			off = off.normalized() * slip
			st[0] = xf * (held + off)
			if not st[3]:
				st[3] = true
				_replant[s] = 0.15
		if lo_i != int(st[2]) and lo < down:
			# Rolled onto another point of the sole: hold that one, where it is now.
			st[0] = xf * ((fk[0][bi] as Vector3) + b * pts[lo_i] + off)
			st[2] = lo_i
		var hold := float(st[1])
		if st[3]:
			# A step, not a slide: the foot comes up at once and only then swings across.
			hold = hold * hold * (3.0 - 2.0 * hold)
		var goal := ankle + off * hold
		if st[3]:
			goal.y += STEP_LIFT / scale.y * sin(PI * sqrt(clampf(1.0 - float(st[1]), 0.0, 1.0)))
		_ik_leg(g, fk, s, goal)


## The feet planted on the floor let go of over PLANT_LET_GO, still held where they were for that moment (along the
## floor), when the body is off the floor (a running stride's flight) or off its feet: let go at once, a foot held
## up to PLANT_SLIP from where the motion has it jumped there in a frame.
func _release_plants(g: Dictionary, fk: Array, dt: float) -> void:
	var inv := skeleton.global_transform.affine_inverse()
	for s in _plant.keys():
		var st: Array = _plant[s]
		st[1] = float(st[1]) - dt / PLANT_LET_GO
		if float(st[1]) <= 0.0 or not (_bone.has("thigh_" + s) and _bone.has("shin_" + s) and _bone.has("foot_" + s)):
			_plant.erase(s)
			continue
		var bi: int = body.soles[s][0]
		var b: Basis = g.get("foot_" + s, fk[1][bi])
		var held: Vector3 = (fk[0][bi] as Vector3) + b * (body.soles[s][1] as PackedVector3Array)[int(st[2])]
		var at: Vector3 = inv * (st[0] as Vector3)
		var off := Vector3(at.x - held.x, 0.0, at.z - held.z).limit_length(PLANT_SLIP / scale.y)
		_ik_leg(g, fk, s, (fk[0][_bone["foot_" + s]] as Vector3) + off * float(st[1]))


## A step the body takes on purpose (Grapple._steps, settling his feet standing ready): the foot s leaves the floor
## where it is and comes through to where the motion has it, over length s, lifted lift off the floor on the way, and is
## planted again where it lands.
func step(s: String, length: float, lift := SWING_LIFT) -> void:
	if not _bone.has("foot_" + s):
		return
	_plant.erase(s)
	_stepping[s] = [anchor("foot_" + s), _plant_t, length, lift]


## A point on the body as drawn now, in world space, for holds and contact checks: "hand_l"/"hand_r" (the
## middle of the grip), "ankle_l"/"ankle_r" (just above the ankle joint, where a hand closes round the
## leg), "shin_l"/"shin_r" (a hand's width higher), "foot_l"/"foot_r" (the ankle joint), "thigh_l"/"thigh_r"
## (mid thigh), "knee_l"/"knee_r" (just above the knee), "hip_l"/"hip_r" (the hip joint), "waist" (the small of
## the back). Bone poses are relative to the skeleton, so they are taken through its global transform.
func anchor(part: String) -> Vector3:
	if skeleton == null:
		return global_position
	var xf := skeleton.global_transform
	if part == "head":
		return xf * _bone_head("head") + Vector3(0, 0.2, 0)   # the top of his head, near enough, however he lies
	var side := part.substr(part.length() - 1)
	match part.substr(0, part.length() - 2) if part != "waist" else part:
		"hand":
			var wrist := _bone_head("hand_" + side)
			var tip := _bone_head("fingers_" + side) if _bone.has("fingers_" + side) else wrist
			if tip == wrist:
				var hb := skeleton.get_bone_global_pose(int(_bone["hand_" + side])).basis
				tip = wrist + hb * (body.rest_dirs["hand_" + side] as Vector3) * 0.08
			return xf * wrist.lerp(tip, 0.6)
		"foot":
			return xf * _bone_head("foot_" + side)
		"toe":
			# The tip of the sole (bones end at the ankle and the ball of the foot; the toes reach further).
			var sole: PackedVector3Array = body.soles[side][1] if body.soles.has(side) else PackedVector3Array()
			if sole.size() < 4:
				return xf * _bone_head("foot_" + side)
			var gp := skeleton.get_bone_global_pose(int(body.soles[side][0]))
			return xf * (gp.origin + gp.basis * sole[2])
		"ankle":
			return xf * _bone_head("foot_" + side).lerp(_bone_head("shin_" + side), 0.12)
		"shin":
			return xf * _bone_head("foot_" + side).lerp(_bone_head("shin_" + side), 0.35)
		"thigh":
			return xf * _bone_head("thigh_" + side).lerp(_bone_head("shin_" + side), 0.55)
		"knee":
			return xf * _bone_head("thigh_" + side).lerp(_bone_head("shin_" + side), 0.85)
		"hip":
			return xf * _bone_head("thigh_" + side)
		"shoulder":
			return xf * _bone_head("upperarm_" + side)
		"waist":
			return xf * _bone_head("hips").lerp(_bone_head("spine"), 0.7)
	return global_position


## Shoulder to the middle of the grip, arm straight (world).
func arm_length() -> float:
	if not (_bone.has("upperarm_l") and _bone.has("forearm_l") and _bone.has("hand_l")):
		return 0.6
	var a: Vector3 = _rest_head[_bone.upperarm_l]
	var b: Vector3 = _rest_head[_bone.forearm_l]
	var c: Vector3 = _rest_head[_bone.hand_l]
	return (a.distance_to(b) + b.distance_to(c)) * scale.y + _hand_len("l") * scale.y * 0.6


## Hip joint to ankle joint, leg straight (world).
func leg_reach() -> float:
	if not (_bone.has("thigh_l") and _bone.has("shin_l") and _bone.has("foot_l")):
		return 0.88
	var a: Vector3 = _rest_head[_bone.thigh_l]
	var b: Vector3 = _rest_head[_bone.shin_l]
	var c: Vector3 = _rest_head[_bone.foot_l]
	return (a.distance_to(b) + b.distance_to(c)) * scale.y


## How high the ankle joint is off the floor standing (world).
func ankle_height() -> float:
	if not _bone.has("foot_l"):
		return 0.08
	return (_rest_head[_bone["foot_l"]] as Vector3).y * scale.y


func _bone_head(name: String) -> Vector3:
	return skeleton.get_bone_global_pose(int(_bone[name])).origin


## Every bone's head position and orientation for the pose in g (bones not in g keep their parent's).
func _fk(g: Dictionary, hips: Vector3) -> Array:
	var n := _parent.size()
	var pos := []
	var rot := []
	pos.resize(n)
	rot.resize(n)
	for i in n:
		var p: int = _parent[i]
		if p < 0:
			pos[i] = hips
			rot[i] = g.get(_names[i], Basis())
		else:
			pos[i] = (pos[p] as Vector3) + (rot[p] as Basis) * ((_rest_head[i] as Vector3) - (_rest_head[p] as Vector3))
			rot[i] = g.get(_names[i], rot[p])
	return [pos, rot]


## The lowest of the contact points (standing: only the legs' and feet's), leaving out the bones in skip.
func _lowest(fk: Array, legs_only: bool, skip := {}) -> float:
	var low := INF
	var contacts: Array = body.contacts
	for i in contacts.size():
		if (legs_only and not _leg_bones.has(i)) or skip.has(i):
			continue
		var b: Basis = fk[1][i]
		var row := Vector3(b.x.y, b.y.y, b.z.y)
		var y: float = (fk[0][i] as Vector3).y
		for q in (contacts[i] as PackedVector3Array):
			low = minf(low, y + row.dot(q))
	return low


func _sole_low(fk: Array, s: String) -> float:
	var bi: int = body.soles[s][0]
	var b: Basis = fk[1][bi]
	var row := Vector3(b.x.y, b.y.y, b.z.y)
	var low := INF
	for q in (body.soles[s][1] as PackedVector3Array):
		low = minf(low, (fk[0][bi] as Vector3).y + row.dot(q))
	return low


## A foot near the floor turns about its ankle until its sole lies flat: heel level with toe, side with side.
func _flatten(g: Dictionary, fk: Array, s: String, dt: float, aloft := false, stride := 0.0) -> void:
	var sole: PackedVector3Array = body.soles[s][1]
	if sole.size() < 4 or not g.has("foot_" + s):
		return
	var bi: int = body.soles[s][0]
	var b: Basis = fk[1][bi]
	# How flat: by how near the floor the sole is (none in the air). Free (stride 1: on his feet and free to move), it
	# comes and goes over FLAT_EASE rather than in the frame the foot lands or leaves the floor; held, down or getting
	# up (stride 0), at once, as the foot is planted (eased there, a held raider's free foot rolled flat after it was
	# planted, its ankle sliding 0.4 m/s).
	var want := 0.0 if aloft else clampf(1.0 - _sole_low(fk, s) / 0.07, 0.0, 1.0)
	var ease := FLAT_EASE * clampf(stride * 2.0, 0.0, 1.0)
	var w := move_toward(float(_flat_w.get(s, want)), want, dt / ease) if dt > 0.0 and ease > 0.001 else want
	_flat_w[s] = w
	if w <= 0.0:
		return
	var along := b * (sole[2] - sole[3])    # heel to toe
	var across := b * (sole[0] - sole[1])   # left to right
	# Free, laid flat only from a little off flat (the body's proportions are not the clip's): a heel the motion lifts
	# on purpose (a running stride's push off, up to 60 degrees) or toes it lifts (landing on the heel) are left to it,
	# from 15 degrees off flat to none at 35. Laid flat from there, a foot pushing off came back to the motion's angle
	# 40 degrees and more in a frame as it left the floor, every stride. Held, down or getting up, a foot is laid flat
	# from up to 60 degrees off and left alone only nearly straight down (on its toes): laid flat from there, the way
	# it would lie flips end for end as it passes the vertical. (With the free window, a held raider's free foot stood
	# on its toes, off the floor four frames in five in a hold he drove against.)
	var lo := lerpf(0.2, 0.82, clampf(stride, 0.0, 1.0))
	var span := lerpf(0.3, 0.146, clampf(stride, 0.0, 1.0))
	w *= clampf((Vector2(along.x, along.z).length() / maxf(along.length(), 0.0001) - lo) / span, 0.0, 1.0)
	if w <= 0.0:
		return
	var turn := Quaternion.IDENTITY
	if Vector2(along.x, along.z).length() > 0.01:
		turn = Quaternion(along.normalized(), Vector3(along.x, 0.0, along.z).normalized())
	across = turn * across
	if Vector2(across.x, across.z).length() > 0.01:
		turn = Quaternion(across.normalized(), Vector3(across.x, 0.0, across.z).normalized()) * turn
	g["foot_" + s] = Basis(Quaternion.IDENTITY.slerp(turn, w)) * (g["foot_" + s] as Basis)


## Bring a foot down by d with the thigh and shin, keeping the knee bent the way it was.
func _reach_down(g: Dictionary, fk: Array, s: String, d: float) -> void:
	if not (_bone.has("thigh_" + s) and _bone.has("shin_" + s) and _bone.has("foot_" + s)):
		return
	_ik_leg(g, fk, s, (fk[0][_bone["foot_" + s]] as Vector3) - Vector3(0.0, d, 0.0))


## A kick reaching for a defender (kick_goal, kick_w): the leg the clip kicks with, the one it has further out from
## its hip, is turned at hip and knee so that the toe goes to him, as far as the leg reaches, over the kick's own
## curve; the foot turns with the shin. The clips kick one way with one leg; a defender anywhere else, the foot
## went past him or fell short of him, and the touch was given all the same (Match judged it by the distance between
## the two bodies).
func _reach_kick(g: Dictionary, hips: Vector3) -> void:
	if kick_w <= 0.0 or kick_goal == Vector3.INF or not body.soles.has("l") or not body.soles.has("r"):
		_kick_leg = ""
		return
	var fk := _fk(g, hips)
	if _kick_leg == "":
		var out := {}
		for s in ["l", "r"]:
			var hip: Vector3 = fk[0][_bone["thigh_" + s]]
			var ankle: Vector3 = fk[0][_bone["foot_" + s]]
			out[s] = Vector2(ankle.x - hip.x, ankle.z - hip.z).length() - _sole_low(fk, s)
		# Which leg is the clip's is plain once one is clearly out (or lifted) further than the other.
		if absf(float(out.l) - float(out.r)) < 0.1 and kick_w < 0.5:
			return
		_kick_leg = "l" if float(out.l) > float(out.r) else "r"
	var s := _kick_leg
	var sole: PackedVector3Array = body.soles[s][1]
	var ankle: Vector3 = fk[0][_bone["foot_" + s]]
	var bi: int = body.soles[s][0]
	var toe: Vector3 = (fk[0][bi] as Vector3) + (fk[1][bi] as Basis) * sole[2] if sole.size() >= 4 else ankle
	var want := toe.lerp(skeleton.global_transform.affine_inverse() * kick_goal, clampf(kick_w, 0.0, 1.0))
	var aim := ankle + (want - toe)
	# Twice: the foot turns with the shin, so after the first the toe is not where the ankle's goal meant it to be (up
	# to 0.1 m off, short of a defender's leg or past it), and the second takes up the difference.
	for i in 2:
		_ik_two(g, fk, "thigh_" + s, "shin_" + s, "foot_" + s, aim, ["foot_" + s])
		if i == 1 or sole.size() < 4:
			break
		fk = _fk(g, hips)
		aim += want - ((fk[0][bi] as Vector3) + (fk[1][bi] as Basis) * sole[2])


func _ik_leg(g: Dictionary, fk: Array, s: String, goal: Vector3) -> void:
	_ik_two(g, fk, "thigh_" + s, "shin_" + s, "foot_" + s, goal)


## Hands reaching for their targets (hand_target): each arm turned at shoulder and elbow so the middle of
## the grip lands on the target point, the hand and fingers turning with the forearm. A target that has
## been let go of fades out where it was. Also notes where the hands would be without reaching.
func _reach_hands(g: Dictionary, hips: Vector3, now: float) -> void:
	if hand_target.is_empty() or not (_bone.has("hand_l") and _bone.has("hand_r")):
		hands_free = Vector3.INF
		_bend.clear()
		return
	var dt := clampf(now - _hand_t, 0.0, 0.1) if _hand_t >= 0.0 else 0.0
	_hand_t = now
	var fk := _fk(g, hips)
	var xf := skeleton.global_transform
	var inv := xf.affine_inverse()
	hands_free = xf * (((fk[0][_bone.hand_l] as Vector3) + (fk[0][_bone.hand_r] as Vector3)) * 0.5)
	for s in hand_target.keys():
		var ht: Dictionary = hand_target[s]
		if float(ht.get("fade", 0.0)) > 0.0:
			ht.w = float(ht.w) - float(ht.fade) * dt
			if float(ht.w) <= 0.0:
				hand_target.erase(s)
				_bend.erase("hand_" + s)
				continue
		var goal_w: Vector3
		if ht.get("model") != null and is_instance_valid(ht.model):
			goal_w = (ht.model as HumanModel).anchor(String(ht.part)) + (ht.get("offset", Vector3.ZERO) as Vector3)
		elif ht.has("point"):
			goal_w = ht.point
		else:
			continue
		# Reaching last frame too, the arm starts from where it was drawn then, not from the hand-made pose, which does
		# not know where the hold is and can point the forearm nearly the other way. Turned from there by the shortest
		# way (_ik_two), a forearm 90-160 degrees off took a twist that flipped from frame to frame: the last pose
		# stage held the flips back (_limit_turns), and the hands were 0.2-0.3 m off a thigh they held for a few
		# frames, and a few centimetres off any hold all through. The hand keeps the pose's own bend at the wrist, and
		# the fingers their grip.
		var up_n: String = "upperarm_" + s
		var fo_n: String = "forearm_" + s
		# Where the pose has the hand: closing on a hold or letting go of it, the hand goes between there and the
		# hold, by how far the hold has closed. Between where it was drawn and the hold instead, a hand letting go
		# stayed on the hold all through the let-go and went back in a frame, and a helper's closed in half his time.
		var pose_wrist: Vector3 = fk[0][_bone["hand_" + s]]
		if _bend.has("hand_" + s) and _turns.has(up_n) and _turns.has(fo_n):
			var chain: Array[String] = [fo_n, "hand_" + s]
			for f in ["fingers_" + s, "fingertips_" + s]:
				if g.has(f):
					chain.append(f)
			var rel: Array[Basis] = []
			for i in range(1, chain.size()):
				rel.append((g[chain[i - 1]] as Basis).orthonormalized().inverse() * (g[chain[i]] as Basis))
			g[up_n] = Basis(_turns[up_n] as Quaternion).scaled_local((g[up_n] as Basis).get_scale())
			g[fo_n] = Basis(_turns[fo_n] as Quaternion).scaled_local((g[fo_n] as Basis).get_scale())
			for i in range(1, chain.size()):
				g[chain[i]] = (g[chain[i - 1]] as Basis).orthonormalized() * rel[i - 1]
			fk = _fk(g, hips)
		var wrist: Vector3 = fk[0][_bone["hand_" + s]]
		var hb: Basis = fk[1][_bone["hand_" + s]]
		var grip := wrist + hb * (body.rest_dirs["hand_" + s] as Vector3) * _hand_len(s) * 0.6
		var goal := (inv * goal_w) - (grip - wrist)
		var carry := ["hand_" + s]
		for f in ["fingers_" + s, "fingertips_" + s]:
			if g.has(f):
				carry.append(f)
		_ik_two(g, fk, up_n, fo_n, "hand_" + s, pose_wrist.lerp(goal, clampf(float(ht.w), 0.0, 1.0)), carry, "hand_" + s)


func _hand_len(s: String) -> float:
	if _bone.has("fingers_" + s):
		return ((_rest_head[_bone["fingers_" + s]] as Vector3) - (_rest_head[_bone["hand_" + s]] as Vector3)).length() * 1.6
	return 0.09 / scale.y


## Two-bone IK: turn the upper and lower bones so the end joint reaches `goal` (skeleton space), keeping
## the middle joint bent the way it was. The end bone keeps its own orientation (its basis in g is absolute)
## unless it is listed in carry, whose bones turn with the lower one. With keep (a hand reaching for a hold), the
## way the middle joint bends is remembered: folded right up or straight, the joint says nothing of which way it
## bends, and taken afresh it flipped the elbow from one side to the other.
func _ik_two(g: Dictionary, fk: Array, upper: String, lower: String, end: String, goal: Vector3, carry := [],
		keep := "") -> void:
	if not (g.has(upper) and g.has(lower)):
		return
	var hp: Vector3 = fk[0][_bone[upper]]
	var kp: Vector3 = fk[0][_bone[lower]]
	var ap: Vector3 = fk[0][_bone[end]]
	var l1 := hp.distance_to(kp)
	var l2 := kp.distance_to(ap)
	var to := goal - hp
	var dist := clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var u := to.normalized()
	var bend := (kp - hp) - u * (kp - hp).dot(u)
	if keep != "":
		var was: Vector3 = _bend.get(keep, Vector3.ZERO)
		was -= u * was.dot(u)   # the way it bent last frame, square to where it reaches now
		if bend.length() < BEND_MIN and was.length() > 0.3:
			bend = was
	bend = bend.normalized() if bend.length() > 0.0001 else Vector3.FORWARD
	if keep != "":
		_bend[keep] = bend
	var ca := clampf((l1 * l1 + dist * dist - l2 * l2) / (2.0 * l1 * dist), -1.0, 1.0)
	var knee := hp + (u * ca + bend * sqrt(1.0 - ca * ca)) * l1
	var ankle := hp + u * dist
	# Bases in g are whole (model space), so each bone turns from where it points to where it must.
	g[upper] = Basis(Quaternion((kp - hp).normalized(), (knee - hp).normalized())) * (g[upper] as Basis)
	var r2 := Basis(Quaternion((ap - kp).normalized(), (ankle - knee).normalized()))
	g[lower] = r2 * (g[lower] as Basis)
	for c in carry:
		if g.has(c):
			g[c] = r2 * (g[c] as Basis)


## How far the fingers curl at the knuckles, in radians: relaxed, open to reach or signal, a grip in holds
## and tackles, a fist to celebrate.
func _finger_curl(h: Node3D, s: String) -> float:
	var ath := h.get_parent()
	var st := String(ath.get("state")) if ath != null and ath.get("state") != null else ""
	match st:
		"holding", "held", "dive", "shove", "shoved":
			return 1.4
		"roar":
			return 1.9
		"celebrate":
			match int(h.cele):
				1, 5:
					return 1.9   # fist pump, chest thump
				2:
					return 0.15  # clap
				3:
					return 0.05 if s == "r" else 0.7   # high five
			return 0.3
		"signal", "slap":
			return 0.12
	if s == "r" and h.reach > 0.15:
		return lerpf(0.7, 0.05, clampf(h.reach, 0.0, 1.0))
	if h.ref_sig != 0:
		return 0.12
	return 0.7   # relaxed: a gentle curl


func _name_of(i: int) -> String:
	return skeleton.get_bone_name(i)


func _basis_of(n: Node3D, inv: Transform3D) -> Basis:
	return (inv.basis * n.global_transform.basis).orthonormalized()


## Global rotation that takes the rest frame of a torso bone onto the placeholder's frame.
func _match(name: String, target: Basis) -> Basis:
	return target * (body.rest_frames[name] as Basis).inverse()


## Global rotation that swings a limb bone onto dir from where its parent (already turned, in g) carries it: the
## shortest turn from the bone's rest direction, as the parent holds it, to dir. The bone keeps its parent's twist,
## an elbow or a knee folding about its own axis, and only a joint folded right back on itself, which none is, would
## leave the turn undecided. (Swung from the rest pose instead, a limb's twist flipped half a turn whenever it pointed
## near the opposite of its rest direction: a forearm across a body held round the middle, the foot of a man lying
## face down.)
func _swing(name: String, dir: Vector3, g: Dictionary) -> Basis:
	var parent: Basis = g.get(_name_of(_parent[_bone[name]]), Basis())
	var to := dir.normalized()
	if to.length_squared() < 0.5:
		return parent
	var from := (parent * (body.rest_dirs[name] as Vector3)).normalized()
	return Basis(Quaternion(from, to)) * parent
