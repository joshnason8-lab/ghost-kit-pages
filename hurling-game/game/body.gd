class_name ToonBody
extends Node3D
## A player built in code: a skinned mesh on a Skeleton3D, in the illustrated style of the concept art (chunky
## shapes, flat colours, cel shading, a dark outline), posed each frame from the joint angles in pose (Moves).
## One mesh, one skeleton, so one draw call a player (two with the outline). The bones follow the usual humanoid
## names, so a Meshy model rigged to the same names can take this body's place (docs/MESHY_BRIEF.md).
##
## Local space: the player faces +Z, his left is +X, the soles of his feet at y = 0. Every bone's rest rotation is
## the identity, so a pose is just each bone's rotation in degrees (x: pitch, y: twist, z: roll):
##   legs and arms hang down: a negative x swings them forward, a positive x back; a positive x on a shin or
##   forearm bends the knee or elbow; a positive z lifts the left arm or leg out to the side (negative for the right);
##   a positive x on the spine, chest or head leans forward; hips_x tips the whole body (negative: over backwards).

const BONES := [
	# name, parent, offset from the parent at rest
	["hips", -1, Vector3(0, 0.95, 0)],
	["spine", 0, Vector3(0, 0.12, 0)],
	["chest", 1, Vector3(0, 0.2, 0)],
	["neck", 2, Vector3(0, 0.21, 0)],
	["head", 3, Vector3(0, 0.07, 0)],
	["upperarm_l", 2, Vector3(0.2, 0.16, 0)],
	["forearm_l", 5, Vector3(0, -0.28, 0)],
	["hand_l", 6, Vector3(0, -0.25, 0)],
	["upperarm_r", 2, Vector3(-0.2, 0.16, 0)],
	["forearm_r", 8, Vector3(0, -0.28, 0)],
	["hand_r", 9, Vector3(0, -0.25, 0)],
	["thigh_l", 0, Vector3(0.1, -0.05, 0)],
	["shin_l", 11, Vector3(0, -0.44, 0)],
	["foot_l", 12, Vector3(0, -0.42, 0)],
	["thigh_r", 0, Vector3(-0.1, -0.05, 0)],
	["shin_r", 14, Vector3(0, -0.44, 0)],
	["foot_r", 15, Vector3(0, -0.42, 0)],
]

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var look := {}          # skin, jersey, shorts, trim, shoe, hair, band (Colors), hair_style (int), height (m)
var pose := {}          # bone name -> Vector3 degrees (or a Quaternion: the clips); plus "hips_y" (m above rest), "hips_x"/"hips_z" handled as bones, "hips_side"/"hips_fwd" (m, the hips moved over the ground)
var _idx := {}
var _rest := {}         # bone -> rest position (model space)
var _hips := Vector3.ZERO

static var _toon_mat: ShaderMaterial
static var _outline_mat: ShaderMaterial
static var _cache := {}  # look key -> ArrayMesh (players who look alike share a mesh)


func _init(p_look := {}) -> void:
	look = p_look


func _ready() -> void:
	skeleton = Skeleton3D.new()
	add_child(skeleton)
	var off := _offsets()
	var acc := {}
	for i in BONES.size():
		var b: Array = BONES[i]
		skeleton.add_bone(b[0])
		_idx[b[0]] = i
		if int(b[1]) >= 0:
			skeleton.set_bone_parent(i, int(b[1]))
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, off[i]))
		skeleton.set_bone_pose_position(i, off[i])
		acc[b[0]] = (acc[BONES[int(b[1])][0]] if int(b[1]) >= 0 else Vector3.ZERO) + off[i]
	_rest = acc
	_hips = off[0]
	var h := float(look.get("height", 1.78))
	scale = Vector3.ONE * (h / 1.80)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	_dress()


## Each bone's offset from its parent at rest (HeroBody: the owner's model's own).
func _offsets() -> Array:
	return BONES.map(func(b): return b[2])


## The mesh and its material.
## The materials again for the graphics level now (it was lowered mid-match: Match.lower_graphics).
func relook() -> void:
	if mesh_instance != null:
		mesh_instance.material_override = material(int(Game.settings.graphics) > Game.GFX_LOW)


func _dress() -> void:
	mesh_instance.mesh = _mesh()
	mesh_instance.material_override = material(int(Game.settings.graphics) > Game.GFX_LOW)


## The shared cel-shaded material (with its outline pass on Medium and High).
static func material(outline: bool) -> ShaderMaterial:
	if _toon_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://game/shaders/look.gdshaderinc"
uniform vec3 light_dir = vec3(0.35, 0.85, 0.4);
uniform float shade = 0.72;
varying vec3 wn;
void vertex() { wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	float d = dot(normalize(wn), normalize(light_dir));
	float k = d > 0.15 ? 1.0 : (d > -0.35 ? mix(shade, 1.0, 0.45) : shade);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * 0.18;
	vec3 c = pow(COLOR.rgb, vec3(2.2));   // the parts' colours are sRGB
	ALBEDO = compat_to_scene(c * k + rim * 0.5);
}
"""
		_toon_mat = ShaderMaterial.new()
		_toon_mat.shader = sh
		var osh := Shader.new()
		osh.code = """
shader_type spatial;
render_mode unshaded, cull_front;
uniform float width = 0.014;
void vertex() { VERTEX += NORMAL * width; }
void fragment() { ALBEDO = vec3(0.004, 0.006, 0.01); }
"""
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = osh
	if outline:
		if _toon_mat.next_pass == null:
			_toon_mat.next_pass = _outline_mat
	else:
		_toon_mat.next_pass = null
	return _toon_mat


func bone(name: String) -> int:
	return int(_idx.get(name, -1))


## Where a bone is now, in world space (a foot, the head: where the ball is met).
func bone_world(name: String) -> Vector3:
	var i := bone(name)
	if i < 0 or skeleton == null:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin


## Puts the skeleton in the pose (bone -> degrees), with hips_y lifting the body (m).
func apply(p: Dictionary) -> void:
	pose = p
	if skeleton == null:
		return
	for i in BONES.size():
		var n: String = BONES[i][0]
		var e: Variant = p.get(n, Vector3.ZERO)
		if e is Quaternion:
			skeleton.set_bone_pose_rotation(i, e)
		else:
			skeleton.set_bone_pose_rotation(i, Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)), EULER_ORDER_YXZ).get_rotation_quaternion())
	skeleton.set_bone_pose_position(0, _hips + Vector3(float(p.get("hips_side", 0.0)), float(p.get("hips_y", 0.0)), float(p.get("hips_fwd", 0.0))))


# ---------------------------------------------------------------- the mesh

func _key() -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%d|%d|%s|%d|%d" % [look.get("skin"), look.get("jersey"), look.get("shorts"),
		look.get("trim"), look.get("socks"), look.get("hair"), look.get("helmet"), int(look.get("hair_style", 0)),
		int(look.get("design", 0)), look.get("kind", "player"), int(look.get("hurley", 1)), int(_lod)]


## The level of detail: 0 full, 1 the far one (fewer sides to every part, no face guard bars, no ears), about a
## third of the triangles. Low graphics draws everyone at 1.
var _lod := 0


func set_lod(l: int) -> void:
	_lod = l


func _mesh() -> ArrayMesh:
	var key := _key()
	if _cache.has(key):
		return _cache[key]
	var m := MeshBuilder.new()
	m.seg_k = 1.0 if _lod == 0 else 0.6
	var skin: Color = look.get("skin", Color("e8c0a0"))
	var jersey: Color = look.get("jersey", Color("c8202f"))
	var shorts: Color = look.get("shorts", Color("ffffff"))
	var trim: Color = look.get("trim", Color.WHITE)
	var socks: Color = look.get("socks", jersey)
	var shoe := Color("15161a")
	var hair: Color = look.get("hair", Color("3a2a1c"))
	var helmet: Color = look.get("helmet", Color("1a1a1a"))
	var kind := String(look.get("kind", "player"))
	var design := int(look.get("design", 0))
	var coat := kind == "umpire"
	var r := _rest
	# Torso: the jersey from the hips to the shoulders; an umpire's long white coat down to the knees.
	var lower := jersey if design != 3 else jersey
	m.capsule(r.hips + Vector3(0, -0.02, 0), r.spine + Vector3(0, 0.06, 0), 0.17, 0.165, lower, bone("hips"), Vector3(1.0, 1, 0.72))
	var chest_col := jersey
	m.capsule(r.spine, r.chest + Vector3(0, 0.12, 0), 0.165, 0.2, chest_col, bone("spine"), Vector3(1.0, 1, 0.66))
	m.capsule(r.chest + Vector3(0, 0.04, 0), r.neck - Vector3(0, 0.02, 0), 0.2, 0.12, jersey, bone("chest"), Vector3(1.05, 1, 0.66))
	match design:
		1:   # a hoop round the chest
			m.band(r.chest + Vector3(0, 0.03, 0), 0.205, 0.138, 0.11, trim, bone("chest"))
		2:   # a sash from the right shoulder to the left hip, front and back
			for k in 4:
				var t := float(k) / 3.0
				var c: Vector3 = (r.chest as Vector3).lerp(r.spine, t) + Vector3(lerpf(-0.13, 0.12, t), 0.1 - t * 0.12, 0)
				m.sphere(c + Vector3(0, 0, 0.115), Vector3(0.07, 0.06, 0.03), trim, bone("chest" if t < 0.5 else "spine"))
				m.sphere(c + Vector3(0, 0, -0.115), Vector3(0.07, 0.06, 0.03), trim, bone("chest" if t < 0.5 else "spine"))
		_:
			pass
	if coat:
		m.capsule(r.hips + Vector3(0, 0.05, 0), r.hips + Vector3(0, -0.52, 0), 0.2, 0.24, Color("f4f4f0"), bone("hips"), Vector3(1.0, 1, 0.8))
	# Collar and the neck.
	m.capsule(r.neck - Vector3(0, 0.03, 0), r.neck + Vector3(0, 0.01, 0), 0.085, 0.085, trim, bone("chest"))
	m.capsule(r.neck, r.head + Vector3(0, 0.04, 0), 0.06, 0.06, skin, bone("neck"))
	# Head; a player's helmet with its face guard; an official's hair (or a cap for an umpire).
	var hc: Vector3 = r.head + Vector3(0, 0.13, 0.0)
	m.sphere(hc, Vector3(0.115, 0.13, 0.12), skin, bone("head"))
	if kind == "player":
		m.sphere(hc + Vector3(0, 0.03, -0.01), Vector3(0.14, 0.135, 0.145), helmet, bone("head"), 0.35)
		# The guard: bars from the brow to the chin, in front of the face.
		var bars := [-0.06, 0.0, 0.06] if _lod == 0 else [0.0]
		for bx in bars:
			m.capsule(hc + Vector3(bx, 0.04, 0.142), hc + Vector3(bx * 0.8, -0.1, 0.122), 0.007, 0.007, Color("c9ccd1"), bone("head"), Vector3.ONE, 4)
		if _lod == 0:
			m.capsule(hc + Vector3(-0.1, -0.02, 0.11), hc + Vector3(0.1, -0.02, 0.11), 0.007, 0.007, Color("c9ccd1"), bone("head"), Vector3.ONE, 4)
	elif coat:
		m.sphere(hc + Vector3(0, 0.05, -0.005), Vector3(0.128, 0.1, 0.132), Color("f4f4f0"), bone("head"), 0.45)
		m.capsule(hc + Vector3(0, 0.05, 0.08), hc + Vector3(0, 0.05, 0.17), 0.08, 0.06, Color("f4f4f0"), bone("head"), Vector3(1.0, 1, 0.2))
	else:
		m.sphere(hc + Vector3(0, 0.035, -0.012), Vector3(0.122, 0.115, 0.125), hair, bone("head"), 0.15)
	if _lod == 0:
		for sx: float in [-1.0, 1.0]:
			m.sphere(hc + Vector3(0.045 * sx, 0.005, 0.105), Vector3(0.016, 0.022, 0.012), Color("1a1410"), bone("head"))
	# Arms: short sleeves (long white sleeves on an umpire), then skin.
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		var sh: Vector3 = r["upperarm_" + side]
		var el: Vector3 = r["forearm_" + side]
		var wr: Vector3 = r["hand_" + side]
		var sleeve := Color("f4f4f0") if coat else jersey
		m.sphere(sh + Vector3(-0.01 * s, -0.02, 0), Vector3(0.085, 0.085, 0.085), sleeve, bone("upperarm_" + side))
		m.capsule(sh + Vector3(0, -0.02, 0), sh.lerp(el, 0.5), 0.075, 0.068, sleeve, bone("upperarm_" + side))
		m.capsule(sh.lerp(el, 0.45), el, 0.055, 0.05, sleeve if coat else skin, bone("upperarm_" + side))
		m.capsule(el, wr, 0.05, 0.042, sleeve if coat else skin, bone("forearm_" + side))
		m.sphere(wr + Vector3(0, -0.05, 0.005), Vector3(0.045, 0.06, 0.035), skin, bone("hand_" + side))
		# Legs: shorts to mid-thigh, skin, the county socks to below the knee, boots.
		var hp: Vector3 = r["thigh_" + side]
		var kn: Vector3 = r["shin_" + side]
		var an: Vector3 = r["foot_" + side]
		var legwear := Color("1a1a1a") if kind != "player" else shorts
		m.capsule(hp + Vector3(0, 0.04, 0), hp.lerp(kn, 0.48), 0.1, 0.085, legwear, bone("thigh_" + side))
		m.capsule(hp.lerp(kn, 0.45), kn, 0.08, 0.07, skin if kind == "player" else legwear, bone("thigh_" + side))
		m.capsule(kn, kn.lerp(an, 0.25), 0.07, 0.065, skin if kind == "player" else legwear, bone("shin_" + side))
		m.capsule(kn.lerp(an, 0.2), an + Vector3(0, 0.02, 0), 0.066, 0.05, socks if kind == "player" else Color("1a1a1a"), bone("shin_" + side))
		m.capsule(an + Vector3(0, -0.005, -0.04), an + Vector3(0, -0.01, 0.15), 0.055, 0.05, shoe, bone("foot_" + side), Vector3(1.0, 0.75, 1))
	if kind == "player":
		_hurley(m)
	var mesh := m.commit()
	_cache[key] = mesh
	return mesh


## The hurley, in the right hand: the handle in the fist, the shaft down and forward, the bas (the flat, curved
## blade) at its foot. 34 inches (0.86 m), the ash's colour.
func _hurley(m: MeshBuilder) -> void:
	var ash := Color("d8b27a")
	var hh: Vector3 = _rest.hand_r + _grip()
	var dir := HURLEY_DIR
	var length := 0.86 if int(look.get("hurley", 1)) == 1 else 0.9
	var foot := hh + dir * length
	m.capsule(hh - dir * 0.08, hh + dir * (length * 0.62), 0.017, 0.02, ash, bone("hand_r"), Vector3(1.0, 1, 0.7), 6)
	m.capsule(hh + dir * (length * 0.62), foot, 0.03, 0.055, ash.lightened(0.05), bone("hand_r"), Vector3(0.32, 1, 1.0), 8)
	# The grip tape on the handle.
	m.capsule(hh - dir * 0.08, hh + dir * 0.14, 0.021, 0.021, Color("2a2a2a"), bone("hand_r"), Vector3(1, 1, 1), 6)


## The hurley's line from the right hand at rest (the arm hanging): down and well forward.
const HURLEY_DIR := Vector3(0.05, -0.62, 0.78)


## Where the hurley's handle passes through the right fist, from the wrist at rest.
func _grip() -> Vector3:
	return Vector3(0, -0.06, 0.01)


## Where the bas is now, in world space: what meets the sliotar.
func bas_world() -> Vector3:
	var i := bone("hand_r")
	if i < 0 or skeleton == null:
		return global_position
	var t := skeleton.global_transform * skeleton.get_bone_global_pose(i)
	var hh: Vector3 = _rest.hand_r + _grip()
	var rest_hand: Vector3 = _rest.hand_r
	return t * ((hh - rest_hand) + HURLEY_DIR.normalized() * 0.78)


## Builds a skinned mesh out of rounded parts, each part rigidly on one bone, coloured by vertex.
class MeshBuilder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var idx := PackedInt32Array()
	var seg_k := 1.0

	func _vert(p: Vector3, n: Vector3, c: Color, b: int) -> void:
		verts.append(p)
		normals.append(n.normalized())
		colors.append(c)
		bones.append_array([b, 0, 0, 0])
		weights.append_array([1.0, 0.0, 0.0, 0.0])

	## A rounded, tapered tube from a to b (radius ra at a, rb at b), squashed by squash across its width.
	func capsule(a: Vector3, b: Vector3, ra: float, rb: float, c: Color, bone: int, squash := Vector3.ONE, seg := 10) -> void:
		seg = maxi(4, roundi(seg * seg_k))
		var axis := (b - a)
		var length := axis.length()
		if length < 0.0001:
			return
		var up := axis / length
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var fwd := side.cross(up).normalized()
		# Rings: a cap at a (3 rings), the tube, a cap at b (3 rings).
		var rings := []   # [centre, radius, normal tilt]
		for k: float in [3, 2, 1]:
			var ang := PI * 0.5 * float(k) / 3.0
			rings.append([a - up * ra * sin(ang) * 0.85, ra * cos(ang), -sin(ang)])
		rings.append([a, ra, 0.0])
		rings.append([b, rb, 0.0])
		for k: float in [1, 2, 3]:
			var ang := PI * 0.5 * float(k) / 3.0
			rings.append([b + up * rb * sin(ang) * 0.85, rb * cos(ang), sin(ang)])
		var base := verts.size()
		for ring in rings:
			for i in seg:
				var t := TAU * float(i) / seg
				var dir := (side * cos(t) * squash.x + fwd * sin(t) * squash.z)
				var rad: float = ring[1]
				var p: Vector3 = ring[0] + dir * maxf(rad, 0.002)
				var n := dir.normalized() * (1.0 - absf(float(ring[2]))) + up * float(ring[2])
				_vert(p, n, c, bone)
		for r in rings.size() - 1:
			for i in seg:
				var i2 := (i + 1) % seg
				var a0 := base + r * seg + i
				var a1 := base + r * seg + i2
				var b0 := base + (r + 1) * seg + i
				var b1 := base + (r + 1) * seg + i2
				idx.append_array([a0, b0, a1, a1, b0, b1])
		# Close the ends.
		var first := verts.size()
		_vert(rings[0][0] - up * 0.0, -up, c, bone)
		var last := verts.size()
		_vert(rings[rings.size() - 1][0], up, c, bone)
		for i in seg:
			var i2 := (i + 1) % seg
			idx.append_array([first, base + i, base + i2])
			var top := base + (rings.size() - 1) * seg
			idx.append_array([last, top + i2, top + i])

	## An ellipsoid at centre with radii r. cut keeps only the part above that fraction of its height (a hair cap: 0.15
	## keeps the top 85%... measured from the bottom), so a sphere of hair sits over the head's crown only.
	func sphere(centre: Vector3, r: Vector3, c: Color, bone: int, cut := -1.0, seg := 12, rings := 8) -> void:
		seg = maxi(6, roundi(seg * seg_k))
		rings = maxi(4, roundi(rings * seg_k))
		var base := verts.size()
		var lat0 := 0
		var cols := seg + 1
		var kept := 0
		for j in rings + 1:
			var v := float(j) / rings        # 0 top .. 1 bottom
			if cut >= 0.0 and (1.0 - v) < cut:
				break
			kept += 1
			var phi := PI * v
			for i in cols:
				var th := TAU * float(i) / seg
				var n := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
				_vert(centre + Vector3(n.x * r.x, n.y * r.y, n.z * r.z), Vector3(n.x / r.x, n.y / r.y, n.z / r.z), c, bone)
		for j in kept - 1:
			for i in seg:
				var a0 := base + j * cols + i
				var a1 := a0 + 1
				var b0 := a0 + cols
				var b1 := b0 + 1
				idx.append_array([a0, a1, b0, a1, b1, b0])
		if lat0 != 0:
			pass

	## A ring (a headband) round centre, radii rx and rz, h tall.
	func band(centre: Vector3, rx: float, rz: float, h: float, c: Color, bone: int, seg := 16) -> void:
		var base := verts.size()
		for k in 2:
			for i in seg:
				var t := TAU * float(i) / seg
				var n := Vector3(cos(t), 0, sin(t))
				_vert(centre + Vector3(n.x * rx, (k - 0.5) * h, n.z * rz), n, c, bone)
		for i in seg:
			var i2 := (i + 1) % seg
			idx.append_array([base + i, base + seg + i, base + i2, base + i2, base + seg + i, base + seg + i2])

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		arrays[Mesh.ARRAY_INDEX] = idx
		# Godot draws clockwise triangles as the front: the parts above were wound the other way.
		for i in range(0, idx.size(), 3):
			var t := idx[i + 1]
			idx[i + 1] = idx[i + 2]
			idx[i + 2] = t
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
