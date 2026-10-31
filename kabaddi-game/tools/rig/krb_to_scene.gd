extends SceneTree
## Turns one of the game's packed bodies (assets/characters/bodies/*.krb: a Meshy model rigged by tools/rig on the
## game's own 21 bones) into an ordinary rigged scene with Mixamo names, facing +Z, so the shared foundation's
## tools/wsg/bake_character.sh can put it on the World Stage Games rig:
##   godot --headless --path <game> -s tools/rig/krb_to_scene.gd -- res://assets/characters/bodies/player_01.krb out.scn
## (tools/rig/bake_foundation.sh does it for every body in bodies.json.)
## The game's bodies face -Z: the model is turned half round (its left, "_l", stays its left). The rig's bones the
## game's do not have (Spine1, the collarbones, the toes) are added where they belong, with no weight of their own;
## the game's finger bones (one mitten joint and its tip) are left unnamed, so their weight goes to the hand and the
## bake makes the rig's own fingers from the hand's shape. Each vertex's kit region (the shorts, the hair; RiggedBody's
## vertex colour) is kept in UV2, which the bake carries through: x the shorts, y the hair.

const NAMES := {"hips": "Hips", "spine": "Spine", "chest": "Spine2", "neck": "Neck", "head": "Head",
	"upperarm_l": "LeftArm", "forearm_l": "LeftForeArm", "hand_l": "LeftHand", "upperarm_r": "RightArm",
	"forearm_r": "RightForeArm", "hand_r": "RightHand", "thigh_l": "LeftUpLeg", "shin_l": "LeftLeg",
	"foot_l": "LeftFoot", "thigh_r": "RightUpLeg", "shin_r": "RightLeg", "foot_r": "RightFoot"}
const TURN := Basis(Vector3.UP, PI)


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var d := read_krb(a[0])
	if d.is_empty():
		printerr("could not read ", a[0])
		quit(1)
		return
	var bones: Array = d.bones
	var head := {}
	var tail := {}
	for b in bones:
		head[String(b.name)] = TURN * _v(b.head)
		tail[String(b.name)] = TURN * _v(b.tail)
	# The joints by rig name, with the ones the game's skeleton lacks.
	var j := {}
	for k in NAMES:
		j[NAMES[k]] = head[k]
	j["Spine1"] = (j["Spine"] as Vector3).lerp(j["Spine2"], 0.5)
	for side in ["Left", "Right"]:
		var arm: Vector3 = j[side + "Arm"]
		var chest: Vector3 = j["Spine2"]
		j[side + "Shoulder"] = Vector3(chest.x + (arm.x - chest.x) * 0.25, arm.y + 0.01, arm.z)
		var s := "l" if side == "Left" else "r"
		# The ball of the foot: two thirds of the way from the ankle to the toe, near the floor.
		var toe: Vector3 = (head["foot_" + s] as Vector3).lerp(tail["foot_" + s], 0.66)
		j[side + "ToeBase"] = Vector3(toe.x, maxf(toe.y, 0.025), toe.z)
	var order := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm",
		"LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot",
		"LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]
	var parent := {"Hips": "", "Spine": "Hips", "Spine1": "Spine", "Spine2": "Spine1", "Neck": "Spine2", "Head": "Neck",
		"LeftShoulder": "Spine2", "LeftArm": "LeftShoulder", "LeftForeArm": "LeftArm", "LeftHand": "LeftForeArm",
		"RightShoulder": "Spine2", "RightArm": "RightShoulder", "RightForeArm": "RightArm", "RightHand": "RightForeArm",
		"LeftUpLeg": "Hips", "LeftLeg": "LeftUpLeg", "LeftFoot": "LeftLeg", "LeftToeBase": "LeftFoot",
		"RightUpLeg": "Hips", "RightLeg": "RightUpLeg", "RightFoot": "RightLeg", "RightToeBase": "RightFoot"}
	# The game's finger joints, unnamed for the rig (their weight goes to the hand).
	for b in bones:
		var n := String(b.name)
		if NAMES.has(n):
			continue
		var p := String(bones[int(b.parent)].name)
		var pn: String = NAMES.get(p, "krb_" + p)
		order.append("krb_" + n)
		parent["krb_" + n] = pn
		j["krb_" + n] = head[n]
	var root := Node3D.new()
	root.name = "Character"
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	root.add_child(sk)
	sk.owner = root
	for n in order:
		sk.add_bone(n)
	for n in order:
		var i := sk.find_bone(n)
		var p: String = parent[n]
		if p != "":
			sk.set_bone_parent(i, sk.find_bone(p))
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, (j[n] as Vector3) - (j[p] as Vector3 if p != "" else Vector3.ZERO)))
	sk.reset_bone_poses()
	# The mesh's bone indices are the game's bone order: bind each to its name here.
	var skin := Skin.new()
	for b in bones:
		var n := String(b.name)
		skin.add_named_bind(NAMES.get(n, "krb_" + n), Transform3D(Basis.IDENTITY, -(head[n] as Vector3)))
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = d.mesh
	mi.skin = skin
	sk.add_child(mi)
	mi.owner = root
	mi.skeleton = NodePath("..")
	var ps := PackedScene.new()
	ps.pack(root)
	print(a[1], " ", error_string(ResourceSaver.save(ps, a[1])))
	quit()


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## The packed form (tools/rig/pack_body.py; RiggedBody._read_krb), turned to face +Z, the regions in UV2.
static func read_krb(path: String) -> Dictionary:
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
	var uv2 := PackedVector2Array()
	verts.resize(n)
	norms.resize(n)
	uvs.resize(n)
	uv2.resize(n)
	for i in n:
		verts[i] = TURN * (lo + Vector3(pos.decode_u16(i * 6), pos.decode_u16(i * 6 + 2), pos.decode_u16(i * 6 + 4)) * span)
		norms[i] = TURN * Vector3(nrm.decode_s8(i * 3), nrm.decode_s8(i * 3 + 1), nrm.decode_s8(i * 3 + 2)).normalized()
		if meta.has_uv:
			uvs[i] = Vector2(uvb.decode_u16(i * 4), uvb.decode_u16(i * 4 + 2)) / 65535.0
		var r := region[i]
		uv2[i] = Vector2(1.0 if r == 2 else 0.0, 1.0 if r == 3 else 0.0)
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
	# glTF and trimesh wind front faces counter-clockwise; Godot wants clockwise. (A half turn keeps the winding.)
	for t in count / 3:
		for c in 3:
			var k = t * 3 + [0, 2, 1][c]
			idx[t * 3 + c] = ib.decode_u32(k * 4) if u32 else ib.decode_u16(k * 2)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return {"bones": meta.bones, "height": float(meta.height), "mesh": mesh, "meta": meta}
