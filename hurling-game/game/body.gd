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
var pose := {}          # bone name -> Vector3 degrees; plus "hips_y" (m above rest), "hips_x"/"hips_z" handled as bones
var _idx := {}
var _rest := {}         # bone -> rest position (model space)

static var _toon_mat: ShaderMaterial
static var _outline_mat: ShaderMaterial
static var _cache := {}  # look key -> ArrayMesh (players who look alike share a mesh)


func _init(p_look := {}) -> void:
	look = p_look


func _ready() -> void:
	skeleton = Skeleton3D.new()
	add_child(skeleton)
	var acc := {}
	for i in BONES.size():
		var b: Array = BONES[i]
		skeleton.add_bone(b[0])
		_idx[b[0]] = i
		if int(b[1]) >= 0:
			skeleton.set_bone_parent(i, int(b[1]))
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, b[2]))
		skeleton.set_bone_pose_position(i, b[2])
		acc[b[0]] = (acc[BONES[int(b[1])][0]] if int(b[1]) >= 0 else Vector3.ZERO) + b[2]
	_rest = acc
	var h := float(look.get("height", 1.78))
	scale = Vector3.ONE * (h / 1.80)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = _mesh()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	mesh_instance.material_override = material(int(Game.settings.graphics) > Game.GFX_LOW)


## The shared cel-shaded material (with its outline pass on Medium and High).
static func material(outline: bool) -> ShaderMaterial:
	if _toon_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 light_dir = vec3(0.35, 0.85, 0.4);
uniform float shade = 0.72;
varying vec3 wn;
void vertex() { wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	float d = dot(normalize(wn), normalize(light_dir));
	float k = d > 0.15 ? 1.0 : (d > -0.35 ? mix(shade, 1.0, 0.45) : shade);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * 0.18;
	vec3 c = pow(COLOR.rgb, vec3(2.2));   // the parts' colours are sRGB
	ALBEDO = c * k + rim * 0.5;
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
		var e: Vector3 = p.get(n, Vector3.ZERO)
		skeleton.set_bone_pose_rotation(i, Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)), EULER_ORDER_YXZ).get_rotation_quaternion())
	skeleton.set_bone_pose_position(0, BONES[0][2] + Vector3(0, float(p.get("hips_y", 0.0)), float(p.get("hips_fwd", 0.0))))


# ---------------------------------------------------------------- the mesh

func _key() -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%d" % [look.get("skin"), look.get("jersey"), look.get("shorts"), look.get("trim"),
		look.get("shoe"), look.get("hair"), look.get("band"), int(look.get("hair_style", 0))]


func _mesh() -> ArrayMesh:
	var key := _key()
	if _cache.has(key):
		return _cache[key]
	var m := MeshBuilder.new()
	var skin: Color = look.get("skin", Color("c98a5a"))
	var jersey: Color = look.get("jersey", Color("ff8a1f"))
	var shorts: Color = look.get("shorts", Color("2a1a0e"))
	var trim: Color = look.get("trim", Color.WHITE)
	var shoe: Color = look.get("shoe", Color("f3efe6"))
	var hair: Color = look.get("hair", Color("1a1410"))
	var band: Color = look.get("band", Color("e8336d"))
	var r := _rest
	# Torso: the jersey from the hips to the shoulders, a little wider at the chest.
	m.capsule(r.hips + Vector3(0, -0.02, 0), r.spine + Vector3(0, 0.06, 0), 0.17, 0.165, shorts.lerp(jersey, 0.0), bone("hips"), Vector3(1.0, 1, 0.72))
	m.capsule(r.spine, r.chest + Vector3(0, 0.12, 0), 0.165, 0.2, jersey, bone("spine"), Vector3(1.0, 1, 0.66))
	m.capsule(r.chest + Vector3(0, 0.04, 0), r.neck - Vector3(0, 0.02, 0), 0.2, 0.12, jersey, bone("chest"), Vector3(1.05, 1, 0.66))
	# Collar trim and the neck.
	m.capsule(r.neck - Vector3(0, 0.03, 0), r.neck + Vector3(0, 0.01, 0), 0.085, 0.085, trim, bone("chest"))
	m.capsule(r.neck, r.head + Vector3(0, 0.04, 0), 0.06, 0.06, skin, bone("neck"))
	# Head, a little big for the style; hair, headband, eyes, nose and ears.
	var hc: Vector3 = r.head + Vector3(0, 0.13, 0.0)
	m.sphere(hc, Vector3(0.125, 0.14, 0.13), skin, bone("head"))
	match int(look.get("hair_style", 0)):
		0:   # short crop
			m.sphere(hc + Vector3(0, 0.035, -0.012), Vector3(0.133, 0.115, 0.135), hair, bone("head"), 0.15)
		1:   # buzz cut
			m.sphere(hc + Vector3(0, 0.03, -0.01), Vector3(0.129, 0.12, 0.133), hair, bone("head"), 0.3)
		2:   # longer on top
			m.sphere(hc + Vector3(0, 0.05, -0.01), Vector3(0.138, 0.13, 0.142), hair, bone("head"), 0.05)
		_:   # shaved: just the band
			pass
	m.band(hc + Vector3(0, 0.055, -0.005), 0.137, 0.14, 0.03, band, bone("head"))
	for sx: float in [-1.0, 1.0]:
		m.sphere(hc + Vector3(0.045 * sx, 0.005, 0.115), Vector3(0.017, 0.024, 0.012), Color("0c1a29"), bone("head"))
		m.sphere(hc + Vector3(0.124 * sx, -0.005, 0.0), Vector3(0.02, 0.035, 0.025), skin.darkened(0.06), bone("head"))
	m.sphere(hc + Vector3(0, -0.03, 0.128), Vector3(0.02, 0.025, 0.02), skin.darkened(0.05), bone("head"))
	# Arms: short sleeves in the jersey, then skin.
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		var sh: Vector3 = r["upperarm_" + side]
		var el: Vector3 = r["forearm_" + side]
		var wr: Vector3 = r["hand_" + side]
		m.sphere(sh + Vector3(-0.01 * s, -0.02, 0), Vector3(0.085, 0.085, 0.085), jersey, bone("upperarm_" + side))
		m.capsule(sh + Vector3(0, -0.02, 0), sh.lerp(el, 0.45), 0.075, 0.068, jersey, bone("upperarm_" + side))
		m.capsule(sh.lerp(el, 0.4), el, 0.055, 0.05, skin, bone("upperarm_" + side))
		m.capsule(el, wr, 0.05, 0.042, skin, bone("forearm_" + side))
		m.sphere(wr + Vector3(0, -0.05, 0.005), Vector3(0.045, 0.06, 0.035), skin, bone("hand_" + side))
		# Legs: shorts to above the knee, skin, a sock and the shoe.
		var hp: Vector3 = r["thigh_" + side]
		var kn: Vector3 = r["shin_" + side]
		var an: Vector3 = r["foot_" + side]
		m.capsule(hp + Vector3(0, 0.04, 0), hp.lerp(kn, 0.62), 0.115, 0.095, shorts, bone("thigh_" + side))
		m.capsule(hp.lerp(kn, 0.55), kn, 0.08, 0.07, skin, bone("thigh_" + side))
		m.capsule(kn, kn.lerp(an, 0.62), 0.07, 0.055, skin, bone("shin_" + side))
		m.capsule(kn.lerp(an, 0.6), an + Vector3(0, 0.02, 0), 0.055, 0.05, trim, bone("shin_" + side))
		m.capsule(an + Vector3(0, -0.005, -0.04), an + Vector3(0, -0.01, 0.15), 0.055, 0.05, shoe, bone("foot_" + side), Vector3(1.0, 0.75, 1))
	var mesh := m.commit()
	_cache[key] = mesh
	return mesh


## Builds a skinned mesh out of rounded parts, each part rigidly on one bone, coloured by vertex.
class MeshBuilder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var idx := PackedInt32Array()

	func _vert(p: Vector3, n: Vector3, c: Color, b: int) -> void:
		verts.append(p)
		normals.append(n.normalized())
		colors.append(c)
		bones.append_array([b, 0, 0, 0])
		weights.append_array([1.0, 0.0, 0.0, 0.0])

	## A rounded, tapered tube from a to b (radius ra at a, rb at b), squashed by squash across its width.
	func capsule(a: Vector3, b: Vector3, ra: float, rb: float, c: Color, bone: int, squash := Vector3.ONE, seg := 10) -> void:
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
