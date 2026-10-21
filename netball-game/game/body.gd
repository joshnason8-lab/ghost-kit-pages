class_name ToonBody
extends Node3D
## A netball player built in code: a skinned mesh on a Skeleton3D (the same humanoid bones as Takraw Smash's bodies,
## so a Meshy model rigged to those names can take its place, docs/MESHY_BRIEF.md), posed each frame from joint angles
## (Poses). A woman's build: a fitted playing dress with a short flared skirt, compression shorts under it, a bib with
## her position's letters on the front and back (from one small strip of letters, assets/ui/bib_letters.png), her hair
## tied back. One mesh, one material: one draw call a player (two with the outline on Medium and High).
##
## Local space: she faces +Z, her left is +X, the soles of her feet at y = 0. Every bone's rest rotation is the
## identity, so a pose is each bone's rotation in degrees (x: pitch, y: twist, z: roll): a negative x swings an arm
## or leg forward; a positive x on a shin or forearm bends the knee or elbow; a positive z lifts the left arm or leg
## out to the side (negative for the right); a positive x on the spine, chest or head leans forward.

const BONES := [
	# name, parent, offset from the parent at rest
	["hips", -1, Vector3(0, 0.93, 0)],
	["spine", 0, Vector3(0, 0.12, 0)],
	["chest", 1, Vector3(0, 0.19, 0)],
	["neck", 2, Vector3(0, 0.2, 0)],
	["head", 3, Vector3(0, 0.07, 0)],
	["upperarm_l", 2, Vector3(0.175, 0.15, 0)],
	["forearm_l", 5, Vector3(0, -0.27, 0)],
	["hand_l", 6, Vector3(0, -0.24, 0)],
	["upperarm_r", 2, Vector3(-0.175, 0.15, 0)],
	["forearm_r", 8, Vector3(0, -0.27, 0)],
	["hand_r", 9, Vector3(0, -0.24, 0)],
	["thigh_l", 0, Vector3(0.095, -0.05, 0)],
	["shin_l", 11, Vector3(0, -0.43, 0)],
	["foot_l", 12, Vector3(0, -0.41, 0)],
	["thigh_r", 0, Vector3(-0.095, -0.05, 0)],
	["shin_r", 14, Vector3(0, -0.43, 0)],
	["foot_r", 15, Vector3(0, -0.41, 0)],
]

const LETTERS := ["GS", "GA", "WA", "C", "WD", "GD", "GK"]

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var look := {}          # skin, dress, trim, bib, shoe, hair (Colors), hair_style (int), height (m), pos (bib letters)
var pose := {}
var _idx := {}
var _rest := {}

static var _toon_mat: ShaderMaterial
static var _outline_mat: ShaderMaterial
static var _cache := {}  # look key -> ArrayMesh


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
	var h := float(look.get("height", 1.75))
	scale = Vector3.ONE * (h / 1.76)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = _mesh()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	mesh_instance.material_override = material(int(Game.settings.graphics) > Game.GFX_LOW)


## The shared cel-shaded material (with its outline pass on Medium and High). Parts are coloured by vertex; the bib's
## letters come from the strip, inked dark on a light bib and light on a dark one.
static func material(outline: bool) -> ShaderMaterial:
	if _toon_mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D letters : source_color, filter_linear_mipmap;
uniform vec3 light_dir = vec3(0.35, 0.85, 0.4);
uniform float shade = 0.72;
varying vec3 wn;
void vertex() { wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	float d = dot(normalize(wn), normalize(light_dir));
	float k = d > 0.15 ? 1.0 : (d > -0.35 ? mix(shade, 1.0, 0.45) : shade);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * 0.18;
	vec3 c = COLOR.rgb;
	if (UV.x >= 0.0) {
		float a = texture(letters, UV).a;
		float lum = dot(c, vec3(0.3, 0.59, 0.11));
		c = mix(c, lum > 0.5 ? vec3(0.07, 0.07, 0.09) : vec3(0.97), a);
	}
	ALBEDO = pow(c, vec3(2.2)) * k + rim * 0.5;
}
"""
		_toon_mat = ShaderMaterial.new()
		_toon_mat.shader = sh
		var tex_path := "res://assets/ui/bib_letters.png"
		if ResourceLoader.exists(tex_path):
			_toon_mat.set_shader_parameter("letters", load(tex_path))
		var osh := Shader.new()
		osh.code = """
shader_type spatial;
render_mode unshaded, cull_front;
uniform float width = 0.013;
void vertex() { VERTEX += NORMAL * width; }
void fragment() { ALBEDO = vec3(0.012, 0.008, 0.03); }
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


## Where a bone is now, in world space (a hand, where the ball is held).
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
	return "%s|%s|%s|%s|%s|%s|%d|%s|%s" % [look.get("skin"), look.get("dress"), look.get("trim"), look.get("bib"),
		look.get("shoe"), look.get("hair"), int(look.get("hair_style", 0)), look.get("pos", ""), look.get("umpire", false)]


func _mesh() -> ArrayMesh:
	var key := _key()
	if _cache.has(key):
		return _cache[key]
	var m := MeshBuilder.new()
	var skin: Color = look.get("skin", Color("c48f62"))
	var dress: Color = look.get("dress", Color("2f6fc4"))
	var trim: Color = look.get("trim", Color.WHITE)
	var bib: Color = look.get("bib", Color("f4f4f4"))
	var shoe: Color = look.get("shoe", Color("f3f1ee"))
	var hair: Color = look.get("hair", Color("1a1410"))
	var shorts: Color = dress.darkened(0.45)
	var umpire := bool(look.get("umpire", false))   # an umpire: a polo shirt and long trousers, no bib
	var trousers := Color("1c1b26")
	var r := _rest
	# The dress: a fitted bodice from the hips to the shoulders, a little narrower at the waist.
	m.capsule(r.hips + Vector3(0, -0.03, 0), r.spine + Vector3(0, 0.05, 0), 0.165, 0.145, dress, bone("hips"), Vector3(1.0, 1, 0.72))
	m.capsule(r.spine, r.chest + Vector3(0, 0.1, 0), 0.145, 0.165, dress, bone("spine"), Vector3(1.0, 1, 0.68))
	m.capsule(r.chest + Vector3(0, 0.03, 0), r.neck - Vector3(0, 0.03, 0), 0.165, 0.105, dress, bone("chest"), Vector3(1.04, 1, 0.68))
	if umpire:
		m.capsule(r.hips + Vector3(0, -0.06, 0), r.hips + Vector3(0, 0.04, 0), 0.165, 0.165, trousers, bone("hips"), Vector3(1.0, 1, 0.75))
	# The skirt: a short flared cone from the hips to the upper thigh, its hem in the trim colour.
	if not umpire:
		m.cone(r.hips + Vector3(0, 0.02, 0), r.hips + Vector3(0, -0.25, 0), 0.165, 0.24, dress, bone("hips"), Vector3(1.0, 1, 0.8))
		m.cone(r.hips + Vector3(0, -0.235, 0), r.hips + Vector3(0, -0.26, 0), 0.236, 0.243, trim, bone("hips"), Vector3(1.0, 1, 0.8))
	# Neckline trim and the neck.
	m.capsule(r.neck - Vector3(0, 0.035, 0), r.neck, 0.08, 0.08, trim, bone("chest"))
	m.capsule(r.neck, r.head + Vector3(0, 0.04, 0), 0.052, 0.052, skin, bone("neck"))
	# The bib, front and back: a panel tied over the dress, her position's letters on it.
	if not umpire:
		var li := LETTERS.find(String(look.get("pos", "C")))
		var bc: Vector3 = r.chest + Vector3(0, 0.02, 0)
		m.panel(bc + Vector3(0, 0, 0.122), Vector3(0.25, 0.23, 0), bib, bone("chest"), li, false)
		m.panel(bc + Vector3(0, 0, -0.122), Vector3(0.25, 0.23, 0), bib, bone("chest"), li, true)
	# Head, eyes, nose and ears; hair tied back.
	var hc: Vector3 = r.head + Vector3(0, 0.12, 0.0)
	m.sphere(hc, Vector3(0.112, 0.13, 0.12), skin, bone("head"))
	m.sphere(hc + Vector3(0, 0.028, -0.012), Vector3(0.12, 0.112, 0.126), hair, bone("head"), 0.22)
	match int(look.get("hair_style", 0)):
		0:   # a high ponytail
			m.sphere(hc + Vector3(0, 0.07, -0.1), Vector3(0.04, 0.04, 0.04), hair, bone("head"))
			m.capsule(hc + Vector3(0, 0.06, -0.13), hc + Vector3(0, -0.1, -0.17), 0.04, 0.025, hair, bone("head"))
		1:   # a bun
			m.sphere(hc + Vector3(0, 0.1, -0.08), Vector3(0.06, 0.055, 0.06), hair, bone("head"))
		2:   # braids, tied back in two
			for sx: float in [-1.0, 1.0]:
				m.capsule(hc + Vector3(0.06 * sx, 0.0, -0.1), hc + Vector3(0.07 * sx, -0.16, -0.12), 0.026, 0.02, hair, bone("head"))
		_:   # short
			pass
	# A headband in the trim colour.
	m.band(hc + Vector3(0, 0.06, -0.008), 0.121, 0.127, 0.022, trim, bone("head"))
	for sx: float in [-1.0, 1.0]:
		m.sphere(hc + Vector3(0.04 * sx, 0.005, 0.104), Vector3(0.015, 0.021, 0.01), Color("140e1f"), bone("head"))
		m.sphere(hc + Vector3(0.11 * sx, -0.005, 0.0), Vector3(0.018, 0.032, 0.022), skin.darkened(0.06), bone("head"))
	m.sphere(hc + Vector3(0, -0.03, 0.116), Vector3(0.018, 0.022, 0.018), skin.darkened(0.05), bone("head"))
	for side in ["l", "r"]:
		var sh: Vector3 = r["upperarm_" + side]
		var el: Vector3 = r["forearm_" + side]
		var wr: Vector3 = r["hand_" + side]
		# A sleeveless dress: a little cap of the dress at the shoulder, then the bare arm.
		m.sphere(sh + Vector3(0, -0.015, 0), Vector3(0.068, 0.07, 0.07), dress, bone("upperarm_" + side))
		if umpire:
			m.capsule(sh + Vector3(0, -0.02, 0), sh.lerp(el, 0.45), 0.066, 0.058, dress, bone("upperarm_" + side))
		m.capsule(sh + Vector3(0, -0.03, 0), el, 0.052, 0.044, skin, bone("upperarm_" + side))
		m.capsule(el, wr, 0.043, 0.035, skin, bone("forearm_" + side))
		m.sphere(wr + Vector3(0, -0.05, 0.005), Vector3(0.04, 0.056, 0.03), skin, bone("hand_" + side))
		# Legs: compression shorts under the skirt, skin, an ankle sock and the court shoe.
		var hp: Vector3 = r["thigh_" + side]
		var kn: Vector3 = r["shin_" + side]
		var an: Vector3 = r["foot_" + side]
		if umpire:
			m.capsule(hp + Vector3(0, 0.03, 0), kn, 0.1, 0.075, trousers, bone("thigh_" + side))
			m.capsule(kn, an.lerp(kn, 0.12), 0.075, 0.06, trousers, bone("shin_" + side))
		else:
			m.capsule(hp + Vector3(0, 0.03, 0), hp.lerp(kn, 0.42), 0.098, 0.084, shorts, bone("thigh_" + side))
			m.capsule(hp.lerp(kn, 0.38), kn, 0.08, 0.06, skin, bone("thigh_" + side))
			m.capsule(kn, an.lerp(kn, 0.18), 0.062, 0.046, skin, bone("shin_" + side))
		m.capsule(an.lerp(kn, 0.2), an + Vector3(0, 0.02, 0), 0.047, 0.045, Color("f4f4f4"), bone("shin_" + side))
		m.capsule(an + Vector3(0, -0.005, -0.04), an + Vector3(0, -0.01, 0.14), 0.052, 0.046, shoe, bone("foot_" + side), Vector3(1.0, 0.75, 1))
	var mesh := m.commit()
	_cache[key] = mesh
	return mesh


## Builds a skinned mesh out of rounded parts, each part rigidly on one bone, coloured by vertex. A vertex's UV is
## (-1, -1) except on a bib panel, where it points into the strip of letters.
class MeshBuilder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var idx := PackedInt32Array()

	func _vert(p: Vector3, n: Vector3, c: Color, b: int, uv := Vector2(-1, -1)) -> void:
		verts.append(p)
		normals.append(n.normalized())
		colors.append(c)
		uvs.append(uv)
		bones.append_array([b, 0, 0, 0])
		weights.append_array([1.0, 0.0, 0.0, 0.0])

	## A rounded, tapered tube from a to b (radius ra at a, rb at b), squashed by squash across its width.
	func capsule(a: Vector3, b: Vector3, ra: float, rb: float, c: Color, bone: int, squash := Vector3.ONE, seg := 10) -> void:
		_tube(a, b, ra, rb, c, bone, squash, seg, true)

	## An open cone from a to b (a skirt), radius ra at a and rb at b.
	func cone(a: Vector3, b: Vector3, ra: float, rb: float, c: Color, bone: int, squash := Vector3.ONE, seg := 14) -> void:
		_tube(a, b, ra, rb, c, bone, squash, seg, false)

	func _tube(a: Vector3, b: Vector3, ra: float, rb: float, c: Color, bone: int, squash: Vector3, seg: int, caps: bool) -> void:
		var axis := (b - a)
		var length := axis.length()
		if length < 0.0001:
			return
		var up := axis / length
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var fwd := side.cross(up).normalized()
		var rings := []   # [centre, radius, normal tilt]
		if caps:
			for k: float in [3, 2, 1]:
				var ang := PI * 0.5 * float(k) / 3.0
				rings.append([a - up * ra * sin(ang) * 0.85, ra * cos(ang), -sin(ang)])
		rings.append([a, ra, 0.0])
		rings.append([b, rb, 0.0])
		if caps:
			for k: float in [1, 2, 3]:
				var ang := PI * 0.5 * float(k) / 3.0
				rings.append([b + up * rb * sin(ang) * 0.85, rb * cos(ang), sin(ang)])
		var base := verts.size()
		var flare := (rb - ra) / length   # a cone's sides lean out: its normals tilt with them
		for ring in rings:
			for i in seg:
				var t := TAU * float(i) / seg
				var dir := (side * cos(t) * squash.x + fwd * sin(t) * squash.z)
				var rad: float = ring[1]
				var p: Vector3 = ring[0] + dir * maxf(rad, 0.002)
				var tilt: float = ring[2] if caps else -flare * 0.7
				var n := dir.normalized() * (1.0 - absf(tilt)) + up * tilt
				_vert(p, n, c, bone)
		for r in rings.size() - 1:
			for i in seg:
				var i2 := (i + 1) % seg
				var a0 := base + r * seg + i
				var a1 := base + r * seg + i2
				var b0 := base + (r + 1) * seg + i
				var b1 := base + (r + 1) * seg + i2
				idx.append_array([a0, b0, a1, a1, b0, b1])
		if not caps:
			# The inside of a skirt, seen from below: the same rings wound the other way.
			for r in rings.size() - 1:
				for i in seg:
					var i2 := (i + 1) % seg
					var a0 := base + r * seg + i
					var a1 := base + r * seg + i2
					var b0 := base + (r + 1) * seg + i
					var b1 := base + (r + 1) * seg + i2
					idx.append_array([a0, a1, b0, a1, b1, b0])
			return
		var first := verts.size()
		_vert(rings[0][0], -up, c, bone)
		var last := verts.size()
		_vert(rings[rings.size() - 1][0], up, c, bone)
		for i in seg:
			var i2 := (i + 1) % seg
			idx.append_array([first, base + i, base + i2])
			var top := base + (rings.size() - 1) * seg
			idx.append_array([last, top + i2, top + i])

	## An ellipsoid at centre with radii r. cut keeps only the part above that fraction of its height (a hair cap).
	func sphere(centre: Vector3, r: Vector3, c: Color, bone: int, cut := -1.0, seg := 12, rings := 8) -> void:
		var base := verts.size()
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

	## A bib panel: a slightly curved rectangle centred at c, size s (width, height), facing +Z (or -Z for the back),
	## with letter cell li of the strip on it, the right way round from whichever side it is seen.
	func panel(c: Vector3, s: Vector3, col: Color, bone: int, li: int, back: bool) -> void:
		var cols := 6
		var rows := 2
		var base := verts.size()
		var face := -1.0 if back else 1.0
		var cell := 1.0 / 7.0
		for j in rows + 1:
			for i in cols + 1:
				var u := float(i) / cols
				var v := float(j) / rows
				var x := (u - 0.5) * s.x
				var bend := -absf(x) * absf(x) * 1.4   # wraps round the body a little
				var p := c + Vector3(x * face, (0.5 - v) * s.y, bend * face)
				var n := Vector3(x * 2.0, 0, face).normalized()
				# Letters inset from the panel's edge: the middle 80% of the panel shows the cell.
				var lu := clampf((u - 0.1) / 0.8, 0.0, 1.0)
				var lv := clampf((v - 0.08) / 0.84, 0.0, 1.0)
				var uv := Vector2((li + lu) * cell, lv) if li >= 0 else Vector2(-1, -1)
				_vert(p, n, col, bone, uv)
		for j in rows:
			for i in cols:
				var a0 := base + j * (cols + 1) + i
				var a1 := a0 + 1
				var b0 := a0 + cols + 1
				var b1 := b0 + 1
				idx.append_array([a0, b0, a1, a1, b0, b1])

	func commit() -> ArrayMesh:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
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
