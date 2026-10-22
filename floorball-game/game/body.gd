class_name Body
extends Node3D
## A person built in code: a skinned mesh on a Skeleton3D with the usual humanoid bone names (so a Meshy model rigged
## to the same names can take its place, docs/MESHY_BRIEF.md), posed each frame from joint angles. A field player in
## shirt, shorts, long socks and indoor shoes, with goggles for the young; a goalkeeper in long padded trousers, a
## padded jersey and a caged helmet, and no stick (Rules 403); a referee in black and the referees' yellow shirt.
##
## The stick is a bone of its own (stick), so body and stick are one mesh and one draw call. The player places it
## (place_stick) and the arms reach for its grip (two-bone IK, hands on the shaft).
##
## Local space: the person faces +Z, his left is +X, soles at y = 0. Every bone's rest rotation is the identity, so a
## pose is each bone's rotation in degrees (x: pitch, y: twist, z: roll): legs and arms hang down, a negative x swings
## them forward; a positive x on a shin or forearm bends the knee or elbow; a positive z lifts the left limb out; a
## positive x on the spine, chest or head leans forward.

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
	["stick", -1, Vector3.ZERO],
]
const UPPER := 0.28
const FORE := 0.25
const STICK_LEN := 0.96     # grip end to the blade's heel (Material Regulations: at most 114 cm with the blade)

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var look := {}          # kind (player, keeper, referee), skin, jersey, shorts, socks, trim, hair, hair_style, height
var pose := {}
var _idx := {}
var _rest := {}         # bone -> rest position (model space)
var _stick_xf := Transform3D()
var _has_stick := true
var _hands := {}        # side -> how far down the shaft from the grip's end that hand holds it (m)
var rig: RiggedBody = null   # the owner's model, when it is there: this skeleton is then posed but not drawn

static var _mat: ShaderMaterial
static var _cache := {}


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
	var h := float(look.get("height", 1.80))
	scale = Vector3.ONE * (h / 1.80)
	if RiggedBody.available() and not bool(look.get("procedural", false)):
		rig = RiggedBody.new()
		add_child(rig)
		rig.setup(self, look)
		return
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = _mesh()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	mesh_instance.material_override = material()


## Changes the kit or face (a line change: the next player out wears his own number and face).
func relook(p_look: Dictionary) -> void:
	look = p_look
	if rig:
		rig.recolour(look)
		scale = Vector3.ONE * (float(look.get("height", 1.80)) / 1.80)
	if mesh_instance:
		mesh_instance.mesh = _mesh()
		scale = Vector3.ONE * (float(look.get("height", 1.80)) / 1.80)


## The shared material: soft hall light from above (half-Lambert), a cool fill from the floor, a little rim.
static func material() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 light_dir = vec3(0.25, 0.92, 0.3);
varying vec3 wn;
void vertex() { wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	vec3 n = normalize(wn);
	float d = dot(n, normalize(light_dir)) * 0.5 + 0.5;
	float k = 0.42 + 0.68 * d * d;
	float up = clamp(-n.y, 0.0, 1.0) * 0.08;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * 0.12;
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = c * k + vec3(0.04, 0.07, 0.12) * up + rim;
}
"""
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	return _mat


func bone(name: String) -> int:
	return int(_idx.get(name, -1))


func bone_world(name: String) -> Vector3:
	var i := bone(name)
	if i < 0 or skeleton == null:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin


## The blade's middle in world space (where the ball sits on it).
func blade_world() -> Vector3:
	return skeleton.global_transform * (_stick_xf * Vector3(0, -STICK_LEN, 0.13))


## Puts the skeleton in the pose (bone -> degrees), with hips_y lifting the body (m) and hips_fwd moving it forward.
func apply(p: Dictionary) -> void:
	pose = p
	if skeleton == null:
		return
	for i in BONES.size() - 1:
		var n: String = BONES[i][0]
		var e: Vector3 = p.get(n, Vector3.ZERO)
		skeleton.set_bone_pose_rotation(i, _q(e))
	skeleton.set_bone_pose_position(0, BONES[0][2] + Vector3(float(p.get("hips_side", 0.0)), float(p.get("hips_y", 0.0)), float(p.get("hips_fwd", 0.0))))


static func _q(e: Vector3) -> Quaternion:
	return Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)), EULER_ORDER_YXZ).get_rotation_quaternion()


## The model-space transform of a bone from the pose as set (the same sums the skeleton does, done here so the arms'
## IK reads the chest where this frame's pose put it).
func _fk(name: String) -> Transform3D:
	var chain := []
	var i := bone(name)
	while i >= 0:
		chain.push_front(i)
		i = int(BONES[i][1])
	var xf := Transform3D()
	for b in chain:
		var off: Vector3 = BONES[b][2]
		if b == 0:
			off += Vector3(float(pose.get("hips_side", 0.0)), float(pose.get("hips_y", 0.0)), float(pose.get("hips_fwd", 0.0)))
		xf = xf * Transform3D(Basis(_q(pose.get(BONES[b][0], Vector3.ZERO))), off)
	return xf


## The stick: its grip end at top, its blade's heel at heel (both in model space), the blade running from the heel
## toward toe (a direction across the shaft). The hands go to it: top_hand at the grip's
## end, the other hand lower down the shaft at low_k (0 the top, 1 the blade).
func place_stick(top: Vector3, heel: Vector3, toe: Vector3, top_hand := "r", low_k := 0.38, two_hands := true) -> void:
	if skeleton == null:
		return
	var down := (heel - top).normalized()
	var z := (toe - down * toe.dot(down)).normalized()
	if z.length() < 0.01:
		z = Vector3.FORWARD
	var x := (-down).cross(z).normalized()
	var b := Basis(x, -down, z)
	_stick_xf = Transform3D(b, top)
	skeleton.set_bone_pose_rotation(bone("stick"), b.get_rotation_quaternion())
	skeleton.set_bone_pose_position(bone("stick"), top)
	var other := "l" if top_hand == "r" else "r"
	_has_stick = true
	_hands = {top_hand: 0.03}
	_reach(top_hand, top + down * 0.03)
	if two_hands:
		_hands[other] = STICK_LEN * low_k
		_reach(other, top + down * (STICK_LEN * low_k))


## Hides the stick (a goalkeeper, a referee): folded into the hips, out of sight.
func no_stick() -> void:
	_has_stick = false
	if skeleton:
		skeleton.set_bone_pose_position(bone("stick"), Vector3(0, 0.9, 0))
		skeleton.set_bone_pose_rotation(bone("stick"), Quaternion.IDENTITY)


## Two-bone IK: the arm on side reaches target (model space), the elbow bending out and down.
func _reach(side: String, target: Vector3) -> void:
	var chest := _fk("chest")
	var sh: Vector3 = chest * BONES[bone("upperarm_" + side)][2]
	var to := target - sh
	var d := clampf(to.length(), 0.08, UPPER + FORE - 0.005)
	var dir := to.normalized()
	# The elbow: law of cosines, bent toward the pole (out to the arm's side and down).
	var cos_a := clampf((UPPER * UPPER + d * d - FORE * FORE) / (2.0 * UPPER * d), -1.0, 1.0)
	var a := acos(cos_a)
	var pole := Vector3(0.6 if side == "l" else -0.6, -0.6, -0.2).normalized()
	var bend := (pole - dir * pole.dot(dir)).normalized()
	if bend.length() < 0.01:
		bend = Vector3.DOWN
	var elbow := sh + (dir * cos(a) + bend * sin(a)) * UPPER
	var hand := sh + dir * d
	var up_g := _from_to(Vector3.DOWN, (elbow - sh).normalized())
	var fo_g := _from_to(Vector3.DOWN, (hand - elbow).normalized())
	var up_l := chest.basis.inverse() * up_g
	var fo_l := up_g.inverse() * fo_g
	skeleton.set_bone_pose_rotation(bone("upperarm_" + side), up_l.get_rotation_quaternion())
	skeleton.set_bone_pose_rotation(bone("forearm_" + side), fo_l.get_rotation_quaternion())
	skeleton.set_bone_pose_rotation(bone("hand_" + side), Quaternion.IDENTITY)


## The shoulder of side ("l" or "r") in this body's space, from the pose as set this frame.
func shoulder(side: String) -> Vector3:
	return _fk("chest") * (BONES[bone("upperarm_" + side)][2] as Vector3)


## The drawn body (the owner's model) takes this frame's pose: call once a frame after apply() and place_stick().
func sync() -> void:
	if rig and skeleton:
		rig.follow(self)


func has_stick() -> bool:
	return _has_stick


## The stick's grip end and frame in this body's space (the shaft down -Y, the blade toward +Z).
func stick_transform() -> Transform3D:
	return _stick_xf


func stick_hands() -> Dictionary:
	return _hands


static func _from_to(a: Vector3, b: Vector3) -> Basis:
	var axis := a.cross(b)
	var s := axis.length()
	var c := a.dot(b)
	if s < 0.0001:
		return Basis.IDENTITY if c > 0.0 else Basis(Vector3.RIGHT, PI)
	return Basis(axis / s, atan2(s, c))


# ---------------------------------------------------------------- the mesh

func _key() -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s|%d|%s" % [int(Game.settings.graphics) == Game.GFX_LOW, look.get("kind", "player"), look.get("skin"), look.get("jersey"), look.get("shorts"),
		look.get("socks"), look.get("trim"), look.get("hair"), int(look.get("hair_style", 0)), look.get("goggles", false)]


func _mesh() -> ArrayMesh:
	var key := _key()
	if _cache.has(key):
		return _cache[key]
	MeshBuilder.low = int(Game.settings.graphics) == Game.GFX_LOW
	var m := MeshBuilder.new()
	var kind := String(look.get("kind", "player"))
	var skin: Color = look.get("skin", Color("e8b48f"))
	var jersey: Color = look.get("jersey", Color("1d4ed8"))
	var shorts: Color = look.get("shorts", Color("1d4ed8"))
	var socks: Color = look.get("socks", jersey)
	var trim: Color = look.get("trim", Color.WHITE)
	var shoe := Color("f2f2f2") if kind != "referee" else Color("1a1a1a")
	var hair: Color = look.get("hair", Color("4a3220"))
	var keeper := kind == "keeper"
	var r := _rest
	var bulk := 1.18 if keeper else 1.0
	# Torso.
	m.capsule(r.hips + Vector3(0, -0.04, 0), r.spine + Vector3(0, 0.06, 0), 0.165 * bulk, 0.16 * bulk, shorts, bone("hips"), Vector3(1.0, 1, 0.72))
	m.capsule(r.spine, r.chest + Vector3(0, 0.12, 0), 0.16 * bulk, 0.195 * bulk, jersey, bone("spine"), Vector3(1.0, 1, 0.66))
	m.capsule(r.chest + Vector3(0, 0.04, 0), r.neck - Vector3(0, 0.02, 0), 0.195 * bulk, 0.12, jersey, bone("chest"), Vector3(1.05, 1, 0.66))
	m.capsule(r.neck - Vector3(0, 0.03, 0), r.neck + Vector3(0, 0.01, 0), 0.08, 0.08, trim, bone("chest"))
	m.capsule(r.neck, r.head + Vector3(0, 0.04, 0), 0.058, 0.058, skin, bone("neck"))
	# Head.
	var hc: Vector3 = r.head + Vector3(0, 0.12, 0.0)
	m.sphere(hc, Vector3(0.11, 0.13, 0.12), skin, bone("head"))
	if keeper:
		# The goalkeeper's helmet and cage (403): a shell over the head, bars across the face.
		m.sphere(hc + Vector3(0, 0.02, -0.01), Vector3(0.135, 0.15, 0.145), jersey.darkened(0.35), bone("head"), 0.35)
		for k in 4:
			var y := -0.06 + k * 0.035
			m.capsule(hc + Vector3(-0.1, y, 0.115), hc + Vector3(0.1, y, 0.115), 0.006, 0.006, Color("d8dde2"), bone("head"), Vector3.ONE, 5)
		for k in 3:
			var x := -0.06 + k * 0.06
			m.capsule(hc + Vector3(x, -0.08, 0.12), hc + Vector3(x, 0.06, 0.125), 0.006, 0.006, Color("d8dde2"), bone("head"), Vector3.ONE, 5)
	else:
		match int(look.get("hair_style", 0)):
			0:
				m.sphere(hc + Vector3(0, 0.035, -0.012), Vector3(0.12, 0.105, 0.125), hair, bone("head"), 0.15)
			1:
				m.sphere(hc + Vector3(0, 0.03, -0.01), Vector3(0.116, 0.11, 0.123), hair, bone("head"), 0.3)
			2:
				# Long hair tied back (a ponytail): common in the women's game.
				m.sphere(hc + Vector3(0, 0.04, -0.015), Vector3(0.122, 0.11, 0.128), hair, bone("head"), 0.1)
				m.capsule(hc + Vector3(0, 0.02, -0.12), hc + Vector3(0, -0.12, -0.15), 0.035, 0.022, hair, bone("head"))
			_:
				m.sphere(hc + Vector3(0, 0.05, -0.01), Vector3(0.125, 0.12, 0.13), hair, bone("head"), 0.05)
		for sx: float in [-1.0, 1.0]:
			m.sphere(hc + Vector3(0.04 * sx, 0.005, 0.105), Vector3(0.014, 0.018, 0.01), Color("1b2026"), bone("head"))
			m.sphere(hc + Vector3(0.11 * sx, -0.005, 0.0), Vector3(0.018, 0.03, 0.022), skin.darkened(0.06), bone("head"))
		m.sphere(hc + Vector3(0, -0.03, 0.118), Vector3(0.018, 0.022, 0.018), skin.darkened(0.05), bone("head"))
		if bool(look.get("goggles", false)):
			m.band(hc + Vector3(0, 0.005, 0.0), 0.118, 0.128, 0.035, Color(0.85, 0.9, 0.95), bone("head"))
	# Arms.
	for side in ["l", "r"]:
		var sh: Vector3 = r["upperarm_" + side]
		var el: Vector3 = r["forearm_" + side]
		var wr: Vector3 = r["hand_" + side]
		var sleeve := jersey if not keeper else jersey
		m.sphere(sh + Vector3(0, -0.02, 0), Vector3(0.08, 0.08, 0.08) * bulk, jersey, bone("upperarm_" + side))
		m.capsule(sh + Vector3(0, -0.02, 0), sh.lerp(el, 0.5 if kind != "referee" else 0.45), 0.07 * bulk, 0.064 * bulk, sleeve, bone("upperarm_" + side))
		m.capsule(sh.lerp(el, 0.45), el, 0.052, 0.048, sleeve if keeper else skin, bone("upperarm_" + side))
		m.capsule(el, wr, 0.048 * bulk, 0.04 * bulk, sleeve if keeper else skin, bone("forearm_" + side))
		m.sphere(wr + Vector3(0, -0.05, 0.005), Vector3(0.042, 0.058, 0.032) * (1.15 if keeper else 1.0), Color("2b2f36") if keeper else skin, bone("hand_" + side))
		# Legs: shorts (a goalkeeper's long padded trousers), long socks over shin guards, indoor shoes.
		var hp: Vector3 = r["thigh_" + side]
		var kn: Vector3 = r["shin_" + side]
		var an: Vector3 = r["foot_" + side]
		if keeper:
			m.capsule(hp + Vector3(0, 0.04, 0), kn, 0.13, 0.11, shorts, bone("thigh_" + side))
			m.sphere(kn + Vector3(0, 0, 0.05), Vector3(0.095, 0.1, 0.09), shorts.lightened(0.15), bone("shin_" + side))
			m.capsule(kn, an + Vector3(0, 0.03, 0), 0.1, 0.085, shorts, bone("shin_" + side))
		else:
			m.capsule(hp + Vector3(0, 0.04, 0), hp.lerp(kn, 0.55), 0.112, 0.094, shorts, bone("thigh_" + side))
			m.capsule(hp.lerp(kn, 0.5), kn, 0.078, 0.068, skin, bone("thigh_" + side))
			m.capsule(kn + Vector3(0, 0.02, 0), kn.lerp(an, 0.6), 0.072, 0.058, socks, bone("shin_" + side))
			m.capsule(kn.lerp(an, 0.55), an + Vector3(0, 0.02, 0), 0.058, 0.05, socks, bone("shin_" + side))
			m.band(kn + Vector3(0, 0.0, 0), 0.074, 0.074, 0.03, trim, bone("shin_" + side))
		m.capsule(an + Vector3(0, -0.005, -0.045), an + Vector3(0, -0.01, 0.16), 0.056, 0.05, shoe, bone("foot_" + side), Vector3(1.05, 0.72, 1))
		m.capsule(an + Vector3(0, -0.035, -0.04), an + Vector3(0, -0.035, 0.15), 0.05, 0.046, Color("c64a3a") if kind != "referee" else Color("111111"), bone("foot_" + side), Vector3(1.05, 0.25, 1))
	if kind == "player":
		# The stick, in the stick bone's space: the shaft down -Y, the blade at its foot turned toward +Z.
		var s := bone("stick")
		var shaft := Color(look.get("stick", Color("1f2933")))
		m.capsule(Vector3(0, 0.02, 0), Vector3(0, -0.3, 0), 0.016, 0.016, Color("e9ecef"), s, Vector3.ONE, 6)
		m.capsule(Vector3(0, -0.3, 0), Vector3(0, -STICK_LEN, 0), 0.0145, 0.0125, shaft, s, Vector3.ONE, 6)
		m.capsule(Vector3(0, -STICK_LEN, -0.01), Vector3(0, -STICK_LEN + 0.005, 0.25), 0.01, 0.009, Color(look.get("blade", Color.WHITE)), s, Vector3(3.6, 1, 0.55), 6)
	var mesh := m.commit()
	_cache[key] = mesh
	return mesh


## Builds a skinned mesh out of rounded parts, each part rigidly on one bone, coloured by vertex.
class MeshBuilder:
	static var low := false   # Low graphics: rounder parts with fewer sides (the bodies are a phone's biggest triangle cost)
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
		if low:
			seg = maxi(5, seg * 6 / 10)
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
		if low:
			seg = maxi(6, seg * 2 / 3)
			rings = maxi(4, rings * 2 / 3)
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
