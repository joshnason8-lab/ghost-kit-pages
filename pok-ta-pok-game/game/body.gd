class_name Body
extends Node3D
## A person built in code: one skinned mesh on a Skeleton3D of seventeen humanoid bones, shaped from rounded parts
## (the ribcage, the shoulders' muscle, the calves) and lit like everything else (no cartoon shading), posed each
## frame from joint angles (game/moves.gd). One mesh and one skeleton: one draw call a person.
##
## What they wear is the game's own (docs/CULTURE.md): an ulama player bare to the waist, barefoot, in the gamuza
## (the deerskin loincloth), the chimali (a leather belt about two inches wide strapped round the buttocks and waist)
## and the faja (a cloth belt, in the team's colour) over it (Aguilar-Moreno). On the classic court, a player in a
## cotton loincloth with the padded hip yoke and a knee pad seen in the old carvings and figurines (reconstructed). A
## judge (veedor) in everyday clothes: a white shirt, dark trousers and a straw hat.
##
## Local space: the body faces +Z, its left is +X, the soles at y = 0. Every bone's rest rotation is the identity; a
## pose is each bone's rotation in degrees (x: pitch, y: twist, z: roll): legs and arms hang down; a negative x swings
## them forward; a positive x on a shin or forearm bends the knee or elbow; a positive z lifts the left arm or leg out
## to the side (negative for the right); a positive x on the spine, chest or head leans forward.

const BONES := [
	["hips", -1, Vector3(0, 0.95, 0)],
	["spine", 0, Vector3(0, 0.12, 0)],
	["chest", 1, Vector3(0, 0.2, 0)],
	["neck", 2, Vector3(0, 0.21, 0)],
	["head", 3, Vector3(0, 0.07, 0)],
	["upperarm_l", 2, Vector3(0.19, 0.16, 0)],
	["forearm_l", 5, Vector3(0, -0.28, 0)],
	["hand_l", 6, Vector3(0, -0.25, 0)],
	["upperarm_r", 2, Vector3(-0.19, 0.16, 0)],
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
var look := {}          # kind ("ulama", "classic", "judge"), skin, hair, team (Color), trim (Color), band (bool), height (m), build (0-1)
var pose := {}
var _idx := {}
var _rest := {}
var _hips := Vector3.ZERO
var _lod := 0

static var _mats := {}
static var _cache := {}


func _init(p_look := {}) -> void:
	look = p_look


func set_lod(l: int) -> void:
	_lod = l


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
	_hips = BONES[0][2]
	scale = Vector3.ONE * (float(look.get("height", 1.7)) / 1.80)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	mesh_instance.mesh = _mesh()
	mesh_instance.material_override = material()


## The one material every body shares: the vertex colours, lit per pixel (per vertex on Low), a soft skin-like
## roughness.
static func material() -> StandardMaterial3D:
	var g := int(Game.settings.graphics)
	if not _mats.has(g):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 0.72
		m.metallic_specular = 0.3
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX if g == Game.GFX_LOW else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		if g >= Game.GFX_HIGH:
			m.rim_enabled = true
			m.rim = 0.25
			m.rim_tint = 0.6
		_mats[g] = m
	return _mats[g]


func bone(name: String) -> int:
	return int(_idx.get(name, -1))


func bone_world(name: String) -> Vector3:
	var i := bone(name)
	if i < 0 or skeleton == null:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin


## Where the outside of a hip is now (side: 1 the left, -1 the right), in world space: what meets the ball.
func hip_world(side: float) -> Vector3:
	var i := bone("hips")
	if i < 0 or skeleton == null:
		return global_position + Vector3(0, 0.9, 0)
	var t := skeleton.global_transform * skeleton.get_bone_global_pose(i)
	return t * Vector3(0.17 * side, -0.06, -0.02)


## The right hand's palm, in the world (the ball rests there before a serve).
func hand_world() -> Vector3:
	var i := bone("hand_r")
	if i < 0 or skeleton == null:
		return global_position + global_transform.basis * Moves.HAND_BALL
	var t := skeleton.global_transform * skeleton.get_bone_global_pose(i)
	return t * Vector3(0, -0.1, 0.06)


## Each bone's turn is Euler angles in degrees (Vector3, YXZ) or a Quaternion (recorded movement, Mocap).
func apply(p: Dictionary) -> void:
	pose = p
	if skeleton == null:
		return
	for i in BONES.size():
		skeleton.set_bone_pose_rotation(i, Moves.quat(p.get(BONES[i][0], Vector3.ZERO)))
	skeleton.set_bone_pose_position(0, _hips + Vector3(float(p.get("hips_side", 0.0)), float(p.get("hips_y", 0.0)), float(p.get("hips_fwd", 0.0))))


# ---------------------------------------------------------------- the mesh

func _key() -> String:
	# Everything about the look that shapes the mesh (not height: that is the node's scale).
	var k := look.duplicate()
	k.erase("height")
	return "%s|%d" % [str(k), _lod]


func _mesh() -> ArrayMesh:
	var key := _key()
	if _cache.has(key):
		return _cache[key]
	var m := MeshBuilder.new()
	m.seg_k = 1.0 if _lod == 0 else 0.6
	var kind := String(look.get("kind", "ulama"))
	var skin: Color = look.get("skin", Color("9a6a48"))
	var skin_dk := skin.darkened(0.12)
	var hair: Color = look.get("hair", Color("16110d"))
	var team: Color = look.get("team", Color("a8322a"))
	var trim: Color = look.get("trim", Color("e8dcc4"))
	var build := float(look.get("build", 0.5))
	var w := 0.94 + build * 0.12          # how broad
	var r := _rest
	# A judge or a spectator is dressed: a shirt, trousers or a skirt, sandals, maybe a hat.
	var judge := kind == "judge" or kind == "spectator"
	var shirt: Color = look.get("shirt", Color("eeeae0"))
	var trousers: Color = look.get("trousers", Color("2c2a2e"))
	var torso_col := shirt if judge else skin
	var B := func(n: String) -> int: return bone(n)

	# The torso: the pelvis, the belly, the ribcage, the chest's muscle, the back, the shoulders.
	m.ellipsoid(r.hips + Vector3(0, 0.02, -0.01), Vector3(0.165 * w, 0.12, 0.115), torso_col if judge else skin, B.call("hips"))
	m.capsule(r.hips + Vector3(0, 0.06, 0.0), r.spine + Vector3(0, 0.1, 0.0), 0.135 * w, 0.14 * w, torso_col, B.call("spine"), Vector3(1.0, 1, 0.74))
	m.capsule(r.spine + Vector3(0, 0.04, 0), r.chest + Vector3(0, 0.1, 0), 0.15 * w, 0.175 * w, torso_col, B.call("chest"), Vector3(1.0, 1, 0.68))
	if not judge:
		for s: float in [-1.0, 1.0]:
			m.ellipsoid(r.chest + Vector3(0.075 * s * w, 0.07, 0.07), Vector3(0.085 * w, 0.06, 0.04), skin, B.call("chest"))
			# The belly's muscle in two columns, faint.
			m.ellipsoid(r.spine + Vector3(0.04 * s, 0.03, 0.085), Vector3(0.045, 0.11, 0.025), skin_dk.lightened(0.08), B.call("spine"))
	m.ellipsoid(r.chest + Vector3(0, 0.12, -0.03), Vector3(0.17 * w, 0.08, 0.1), torso_col, B.call("chest"))
	# The neck and the trapezius.
	m.capsule(r.neck + Vector3(0, -0.06, -0.01), r.head + Vector3(0, 0.03, 0), 0.06, 0.055, skin, B.call("neck"))
	m.ellipsoid(r.neck + Vector3(0, -0.04, -0.035), Vector3(0.11 * w, 0.045, 0.06), torso_col, B.call("chest"))
	if judge:
		m.band(r.neck + Vector3(0, -0.035, 0), 0.075, 0.07, 0.04, shirt, B.call("chest"))
	_head(m, r, skin, hair, team, kind)

	# Arms.
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		var sh: Vector3 = r["upperarm_" + side]
		var el: Vector3 = r["forearm_" + side]
		var wr: Vector3 = r["hand_" + side]
		var arm := shirt if judge else skin
		m.ellipsoid(sh + Vector3(0.012 * s, -0.035, 0), Vector3(0.068 * w, 0.085, 0.07), arm, B.call("upperarm_" + side))
		m.capsule(sh + Vector3(0, -0.04, 0), el, 0.058 * w, 0.044, arm, B.call("upperarm_" + side))
		if not judge:
			m.ellipsoid(sh.lerp(el, 0.45) + Vector3(0, 0, 0.02), Vector3(0.04 * w, 0.075, 0.035), skin, B.call("upperarm_" + side))
		m.ellipsoid(el, Vector3(0.045, 0.045, 0.045), arm, B.call("forearm_" + side))
		m.capsule(el, wr, 0.046, 0.033, arm if judge else skin, B.call("forearm_" + side))
		if judge:
			m.capsule(el.lerp(wr, 0.75), wr, 0.04, 0.034, skin, B.call("forearm_" + side))
		# The hand: palm and fingers in one rounded block, the thumb.
		m.ellipsoid(wr + Vector3(0, -0.06, 0.005), Vector3(0.025, 0.07, 0.042), skin, B.call("hand_" + side))
		m.ellipsoid(wr + Vector3(0.0, -0.03, 0.04), Vector3(0.016, 0.035, 0.016), skin, B.call("hand_" + side))
		if kind == "classic" and side == "r":
			m.band(wr + Vector3(0, 0.03, 0), 0.042, 0.042, 0.06, Color("d8ccb2"), B.call("forearm_" + side))

	# Legs.
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		var hp: Vector3 = r["thigh_" + side]
		var kn: Vector3 = r["shin_" + side]
		var an: Vector3 = r["foot_" + side]
		var leg := trousers if judge else skin
		# The buttock and the thigh, its muscle at the front.
		m.ellipsoid(hp + Vector3(0.015 * s, 0.03, -0.045), Vector3(0.095 * w, 0.1, 0.085), leg, B.call("thigh_" + side))
		m.capsule(hp + Vector3(0, 0.02, 0), kn, 0.088 * w, 0.056, leg, B.call("thigh_" + side))
		if not judge:
			m.ellipsoid(hp.lerp(kn, 0.5) + Vector3(-0.005 * s, 0, 0.035), Vector3(0.06 * w, 0.14, 0.045), skin, B.call("thigh_" + side))
		m.ellipsoid(kn + Vector3(0, 0, 0.012), Vector3(0.055, 0.06, 0.055), leg, B.call("shin_" + side))
		m.capsule(kn, an + Vector3(0, 0.04, 0), 0.055, 0.035, leg, B.call("shin_" + side))
		if not judge:
			m.ellipsoid(kn.lerp(an, 0.3) + Vector3(0, 0, -0.03), Vector3(0.05, 0.11, 0.045), skin, B.call("shin_" + side))
		# Feet: bare for a player, sandals for a judge.
		var foot := Color("4a3626") if judge else skin_dk
		m.ellipsoid(an + Vector3(0, -0.005, -0.02), Vector3(0.04, 0.04, 0.05), skin_dk, B.call("foot_" + side))
		m.capsule(an + Vector3(0, -0.02, -0.03), an + Vector3(0, -0.025, 0.14), 0.042, 0.035, foot, B.call("foot_" + side), Vector3(1.0, 0.6, 1))
		if kind == "classic" and side == "r":
			# The knee pad of the old carvings.
			m.ellipsoid(kn + Vector3(0, 0.01, 0.045), Vector3(0.07, 0.08, 0.04), Color("cbb994"), B.call("shin_" + side))

	match kind:
		"ulama":
			_ulama_gear(m, r, team, trim)
		"classic":
			_classic_gear(m, r, team, trim)
		"judge", "spectator":
			# Trousers to the waist and a belt, or a long skirt.
			m.ellipsoid(r.hips + Vector3(0, 0.0, -0.01), Vector3(0.175 * w, 0.13, 0.125), trousers, B.call("hips"))
			if bool(look.get("skirt", false)):
				m.capsule(r.hips + Vector3(0, 0.02, 0), r.hips + Vector3(0, -0.8, 0.0), 0.17 * w, 0.21, trousers, B.call("hips"), Vector3(1.0, 1, 0.8))
			else:
				m.band(r.hips + Vector3(0, 0.08, 0), 0.16 * w, 0.115, 0.035, Color("3a2416"), B.call("hips"))
	var mesh := m.commit()
	_cache[key] = mesh
	return mesh


func _head(m: MeshBuilder, r: Dictionary, skin: Color, hair: Color, team: Color, kind: String) -> void:
	var hb := bone("head")
	var hc: Vector3 = r.head + Vector3(0, 0.12, 0.005)
	# The skull, the face's lower half (the jaw), the nose, the brow, the ears.
	m.ellipsoid(hc, Vector3(0.088, 0.112, 0.102), skin, hb)
	m.ellipsoid(hc + Vector3(0, -0.06, 0.02), Vector3(0.072, 0.06, 0.08), skin, hb)
	if _lod == 0:
		m.ellipsoid(hc + Vector3(0, -0.015, 0.098), Vector3(0.016, 0.03, 0.022), skin.darkened(0.04), hb)
		m.ellipsoid(hc + Vector3(0, 0.035, 0.083), Vector3(0.07, 0.016, 0.025), skin.darkened(0.06), hb)
		for s: float in [-1.0, 1.0]:
			m.ellipsoid(hc + Vector3(0.088 * s, -0.005, 0.0), Vector3(0.014, 0.028, 0.02), skin.darkened(0.05), hb)
			# The eyes: dark, set under the brow.
			m.ellipsoid(hc + Vector3(0.032 * s, 0.012, 0.086), Vector3(0.014, 0.008, 0.008), Color("1a1410"), hb)
	# Hair: short and black, cut close (a judge's under his hat).
	m.ellipsoid(hc + Vector3(0, 0.03, -0.012), Vector3(0.093, 0.093, 0.104), hair, hb, 0.42)
	if bool(look.get("long_hair", false)):
		m.capsule(hc + Vector3(0, 0.02, -0.06), hc + Vector3(0, -0.24, -0.09), 0.07, 0.04, hair, hb, Vector3(1.0, 1, 0.6), 8)
	var hat := int(look.get("hat", 1 if kind == "judge" else 0))
	if hat == 1:
		var straw := Color("cdb27a")
		m.ellipsoid(hc + Vector3(0, 0.075, -0.005), Vector3(0.095, 0.07, 0.105), straw, hb, 0.4)
		m.disc(hc + Vector3(0, 0.07, 0.0), 0.2, 0.012, straw.darkened(0.06), hb)
		m.band(hc + Vector3(0, 0.09, -0.004), 0.096, 0.106, 0.02, Color("3a2416"), hb)
	elif hat == 2:
		var cap: Color = look.get("cap", Color("8a2b24"))
		m.ellipsoid(hc + Vector3(0, 0.06, -0.005), Vector3(0.097, 0.07, 0.107), cap, hb, 0.4)
		m.capsule(hc + Vector3(0, 0.055, 0.08), hc + Vector3(0, 0.05, 0.16), 0.06, 0.05, cap, hb, Vector3(1.0, 1, 0.15), 8)
	elif bool(look.get("band", false)):
		m.band(hc + Vector3(0, 0.045, -0.004), 0.094, 0.106, 0.035, team, hb)


## The ulama player's gear (Aguilar-Moreno): the gamuza, a deerskin loincloth wrapped round the hips and between the
## legs; the chimali, a hard leather belt about 5 cm wide strapped round the buttocks and the waist; the faja, a cloth
## belt that holds the gamuza and tightens the stomach, here in the team's colour.
func _ulama_gear(m: MeshBuilder, r: Dictionary, team: Color, trim: Color) -> void:
	var hb := bone("hips")
	var deer := Color("a98559")
	var leather := Color("4a2e1c")
	var w := 0.94 + float(look.get("build", 0.5)) * 0.12
	# The gamuza: the wrap over the pelvis and the tops of the thighs, a flap hanging at the front.
	m.ellipsoid(r.hips + Vector3(0, -0.02, -0.012), Vector3(0.178 * w, 0.125, 0.128), deer, hb)
	for side in ["l", "r"]:
		var s := 1.0 if side == "l" else -1.0
		var hp: Vector3 = r["thigh_" + side]
		m.capsule(hp + Vector3(0, 0.03, 0), hp + Vector3(0.008 * s, -0.12, 0), 0.1 * w, 0.092 * w, deer, bone("thigh_" + side))
	m.capsule(r.hips + Vector3(0, -0.06, 0.12), r.hips + Vector3(0, -0.24, 0.105), 0.07, 0.065, deer.darkened(0.06), hb, Vector3(1.0, 1, 0.22), 8)
	# The chimali: the leather belt round the waist and buttocks.
	m.band(r.hips + Vector3(0, 0.06, -0.005), 0.172 * w, 0.13, 0.05, leather, hb)
	# The faja: the cloth belt above it, in the team's colour, its ends tied at the side.
	m.band(r.hips + Vector3(0, 0.125, -0.002), 0.158 * w, 0.122, 0.07, team, bone("spine"))
	m.ellipsoid(r.hips + Vector3(0.15 * w, 0.11, 0.03), Vector3(0.03, 0.05, 0.03), team.darkened(0.1), hb)
	m.capsule(r.hips + Vector3(0.155 * w, 0.1, 0.035), r.hips + Vector3(0.165 * w, -0.05, 0.05), 0.022, 0.018, team.darkened(0.15), hb, Vector3(1, 1, 0.5), 6)
	# The trim: a stripe woven into the faja.
	m.band(r.hips + Vector3(0, 0.125, -0.002), 0.161 * w, 0.125, 0.015, trim, bone("spine"))


## The classic court (reconstructed from the old carvings and figurines): a white cotton loincloth, and over it the
## thick padded hip yoke that took the ball, in the team's colour, and a knee pad (in the legs above).
func _classic_gear(m: MeshBuilder, r: Dictionary, team: Color, trim: Color) -> void:
	var hb := bone("hips")
	var cotton := Color("e6dcc8")
	var w := 0.94 + float(look.get("build", 0.5)) * 0.12
	m.ellipsoid(r.hips + Vector3(0, -0.03, -0.012), Vector3(0.172 * w, 0.115, 0.122), cotton, hb)
	m.capsule(r.hips + Vector3(0, -0.06, 0.12), r.hips + Vector3(0, -0.32, 0.1), 0.075, 0.07, cotton.darkened(0.04), hb, Vector3(1.0, 1, 0.22), 8)
	# The yoke: a thick ring round the waist.
	m.torus(r.hips + Vector3(0, 0.07, -0.005), 0.19 * w, 0.14, 0.05, team, hb)
	m.torus(r.hips + Vector3(0, 0.07, -0.005), 0.195 * w, 0.145, 0.018, trim, hb)


## Builds a skinned mesh out of rounded parts, each part on one bone, coloured by vertex.
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
		bones.append_array([maxi(b, 0), 0, 0, 0])
		weights.append_array([1.0, 0.0, 0.0, 0.0])

	## A rounded, tapered limb from a to b.
	func capsule(a: Vector3, b: Vector3, ra: float, rb: float, c: Color, bone: int, squash := Vector3.ONE, seg := 10) -> void:
		seg = maxi(5, roundi(seg * seg_k))
		var axis := b - a
		var length := axis.length()
		if length < 0.0001:
			return
		var up := axis / length
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var fwd := side.cross(up).normalized()
		var rings := []
		var caps := 2 if seg_k >= 1.0 else 1
		for k in range(caps, 0, -1):
			var ang := PI * 0.5 * float(k) / caps
			rings.append([a - up * ra * sin(ang) * 0.85, ra * cos(ang), -sin(ang)])
		# The limb swells a little in its middle, as muscle does.
		rings.append([a, ra, 0.0])
		rings.append([a.lerp(b, 0.4), lerpf(ra, rb, 0.4) * 1.05, 0.0])
		rings.append([b, rb, 0.0])
		for k in range(1, caps + 1):
			var ang := PI * 0.5 * float(k) / caps
			rings.append([b + up * rb * sin(ang) * 0.85, rb * cos(ang), sin(ang)])
		var base := verts.size()
		for ring in rings:
			for i in seg:
				var t := TAU * float(i) / seg
				var dir := side * cos(t) * squash.x + fwd * sin(t) * squash.z
				var p: Vector3 = ring[0] + dir * maxf(float(ring[1]), 0.002)
				var n := dir.normalized() * (1.0 - absf(float(ring[2]))) + up * float(ring[2])
				_vert(p, n, c, bone)
		for ri in rings.size() - 1:
			for i in seg:
				var i2 := (i + 1) % seg
				var a0 := base + ri * seg + i
				var a1 := base + ri * seg + i2
				var b0 := base + (ri + 1) * seg + i
				var b1 := base + (ri + 1) * seg + i2
				idx.append_array([a0, b0, a1, a1, b0, b1])

	## An ellipsoid at centre with radii r. cut keeps only its top part above that fraction of its height (from the
	## bottom): a cap of hair over the crown.
	func ellipsoid(centre: Vector3, r: Vector3, c: Color, bone: int, cut := -1.0, seg := 12, rings := 7) -> void:
		seg = maxi(6, roundi(seg * seg_k))
		rings = maxi(4, roundi(rings * seg_k))
		var base := verts.size()
		var cols := seg + 1
		var kept := 0
		for j in rings + 1:
			var v := float(j) / rings
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

	## A belt: a short open tube round centre (radii rx, rz), h tall, bulging a little.
	func band(centre: Vector3, rx: float, rz: float, h: float, c: Color, bone: int, seg := 18) -> void:
		seg = maxi(8, roundi(seg * seg_k))
		var base := verts.size()
		var ys := [-0.5, 0.0, 0.5]
		for k in ys.size():
			var bulge := 1.0 + (0.04 if k == 1 else 0.0)
			for i in seg:
				var t := TAU * float(i) / seg
				var n := Vector3(cos(t), float(ys[k]) * 0.6, sin(t))
				_vert(centre + Vector3(cos(t) * rx * bulge, float(ys[k]) * h, sin(t) * rz * bulge), n, c, bone)
		for k in ys.size() - 1:
			for i in seg:
				var i2 := (i + 1) % seg
				idx.append_array([base + k * seg + i, base + (k + 1) * seg + i, base + k * seg + i2,
					base + k * seg + i2, base + (k + 1) * seg + i, base + (k + 1) * seg + i2])

	## A thick ring (the yoke): a torus of tube radius tr round centre, radii rx, rz.
	func torus(centre: Vector3, rx: float, rz: float, tr: float, c: Color, bone: int, seg := 20, tseg := 8) -> void:
		seg = maxi(10, roundi(seg * seg_k))
		tseg = maxi(5, roundi(tseg * seg_k))
		var base := verts.size()
		for i in seg:
			var t := TAU * float(i) / seg
			var out := Vector3(cos(t), 0, sin(t))
			var ring_c := centre + Vector3(cos(t) * rx, 0, sin(t) * rz)
			for j in tseg:
				var u := TAU * float(j) / tseg
				var n := out * cos(u) + Vector3.UP * sin(u)
				_vert(ring_c + n * tr, n, c, bone)
		for i in seg:
			var i2 := (i + 1) % seg
			for j in tseg:
				var j2 := (j + 1) % tseg
				idx.append_array([base + i * tseg + j, base + i2 * tseg + j, base + i * tseg + j2,
					base + i * tseg + j2, base + i2 * tseg + j, base + i2 * tseg + j2])

	## A flat round brim (a hat's), r across, h thick.
	func disc(centre: Vector3, r: float, h: float, c: Color, bone: int, seg := 20) -> void:
		seg = maxi(10, roundi(seg * seg_k))
		var base := verts.size()
		_vert(centre + Vector3(0, h * 0.5, 0), Vector3.UP, c, bone)
		_vert(centre - Vector3(0, h * 0.5, 0), Vector3.DOWN, c, bone)
		for i in seg:
			var t := TAU * float(i) / seg
			var o := Vector3(cos(t) * r, 0, sin(t) * r)
			_vert(centre + o + Vector3(0, h * 0.5, 0), Vector3(cos(t) * 0.3, 1, sin(t) * 0.3), c, bone)
			_vert(centre + o - Vector3(0, h * 0.5, 0), Vector3(cos(t) * 0.3, -1, sin(t) * 0.3), c, bone)
		for i in seg:
			var i2 := (i + 1) % seg
			idx.append_array([base, base + 2 + i * 2, base + 2 + i2 * 2])
			idx.append_array([base + 1, base + 3 + i2 * 2, base + 3 + i * 2])
			idx.append_array([base + 2 + i * 2, base + 3 + i * 2, base + 2 + i2 * 2, base + 2 + i2 * 2, base + 3 + i * 2, base + 3 + i2 * 2])

	func triangles() -> int:
		return idx.size() / 3

	func commit() -> ArrayMesh:
		for i in range(0, idx.size(), 3):
			var t := idx[i + 1]
			idx[i + 1] = idx[i + 2]
			idx[i + 2] = t
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		arrays[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh
