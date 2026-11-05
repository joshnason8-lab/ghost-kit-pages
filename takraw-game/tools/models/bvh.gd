extends RefCounted
## Reads a BVH motion capture file (the CMU library's, mocap.cs.cmu.edu, by B. Hahne's conversion) into what
## fbx_to_move.gd reads from an FBX: a scene with a Skeleton3D, and an Animation of it.
##
## The CMU skeleton's joints keep their names, but for its back: LowerBack, Spine and Spine1 become Spine, Spine1 and
## Spine2, as the players' models (and Mixamo) call them. Its extra joints (the hip joints, Neck1, the fingers) are
## kept and play no part. Its units are scaled to metres (SCALE: its legs as long as the man's), its 120 frames a
## second resampled to FPS. Each joint's channels are ZYX turns (degrees); the root's also its place.

const SCALE := 0.0564
const FPS := 30.0
const RENAME := {"LowerBack": "Spine", "Spine": "Spine1", "Spine1": "Spine2"}


## [scene, animation], or [] when the file can't be read.
static func load_scene(path: String) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("can't read " + path)
		return []
	var words := f.get_as_text().split("\n")
	var joints := []   # [name, parent index, offset, channels]
	var stack := []
	var cur := -1
	var end_site := false
	var i := 0
	while i < words.size() and not words[i].strip_edges().begins_with("MOTION"):
		var t := words[i].strip_edges().split(" ", false)
		i += 1
		if t.is_empty():
			continue
		match t[0]:
			"ROOT", "JOINT":
				var nm: String = RENAME.get(t[1], t[1])
				joints.append([nm, stack[-1] if not stack.is_empty() else -1, Vector3.ZERO, PackedStringArray()])
				cur = joints.size() - 1
				end_site = false
			"End":
				end_site = true
			"{":
				stack.append(cur if not end_site else -2)
			"}":
				var top = stack.pop_back()
				if top == -2:
					end_site = false
			"OFFSET":
				if not end_site:
					joints[cur][2] = Vector3(float(t[1]), float(t[2]), float(t[3])) * SCALE
			"CHANNELS":
				joints[cur][3] = t.slice(2)
	var frames := int(words[i + 1].split(":")[1])
	var dt := float(words[i + 2].split(":")[1])
	var rows := []
	for r in frames:
		rows.append(words[i + 3 + r].strip_edges().split(" ", false))

	# At rest the root stands as high as the skeleton's legs, its lowest joint on the floor (a BVH puts it at 0).
	var rest_at := []
	var lowest := 0.0
	for j in joints:
		var at: Vector3 = j[2] + (rest_at[int(j[1])] if int(j[1]) >= 0 else Vector3.ZERO)
		rest_at.append(at)
		lowest = minf(lowest, at.y)
	joints[0][2] = Vector3(0, -lowest, 0)
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	for j in joints:
		var b := sk.add_bone(j[0])
		if int(j[1]) >= 0:
			sk.set_bone_parent(b, int(j[1]))
		sk.set_bone_rest(b, Transform3D(Basis.IDENTITY, j[2]))
	var anim := Animation.new()
	var length := float(frames - 1) * dt
	anim.length = length
	var count := int(floor(length * FPS)) + 1
	var col := 0
	for b in joints.size():
		var ch: PackedStringArray = joints[b][3]
		var rot := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rot, NodePath("Skeleton3D:" + String(joints[b][0])))
		var pos := -1
		if ch.has("Xposition"):
			pos = anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(pos, NodePath("Skeleton3D:" + String(joints[b][0])))
		for k in count:
			var tk := float(k) / FPS
			var row: PackedStringArray = rows[mini(int(round(tk / dt)), frames - 1)]
			var q := Quaternion.IDENTITY
			var p: Vector3 = joints[b][2]
			for c in ch.size():
				var v := float(row[col + c])
				match ch[c]:
					"Xposition": p.x = v * SCALE
					"Yposition": p.y = v * SCALE
					"Zposition": p.z = v * SCALE
					"Xrotation": q = q * Quaternion(Vector3.RIGHT, deg_to_rad(v))
					"Yrotation": q = q * Quaternion(Vector3.UP, deg_to_rad(v))
					"Zrotation": q = q * Quaternion(Vector3.BACK, deg_to_rad(v))
			anim.rotation_track_insert_key(rot, tk, q)
			if pos >= 0:
				anim.position_track_insert_key(pos, tk, p)
		col += ch.size()
	var scene := Node3D.new()
	scene.add_child(sk)
	var ap := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	lib.add_animation("clip", anim)
	ap.add_animation_library("", lib)
	scene.add_child(ap)
	return [scene, anim]
