extends Node
## Turns an animation from Mixamo (FBX), Meshy (FBX or GLB) or the CMU motion capture library (BVH) into a clip
## the game plays (assets/mocap/<name>.json, version 2: a full 3D rotation for each of the game's joints).
##
##   godot --headless --path . res://tools/mocap/fbx_to_clip.tscn -- IN.fbx OUT.json [NAME] [--loop] \
##       [--from=SECONDS] [--to=SECONDS] [--mirror] [--low]
##
## --from and --to keep only that stretch of the source (a CMU take holds several moves); --mirror swaps the body's
## left and right (a move to the left from one to the right); --low marks a clip crouched all through (a crouched
## walk, whose hips bob up past what the game would take for a crouch: MocapClip.low).
##
## The source skeleton is matched to the game's by bone names (Mixamo's "mixamorig:" names, Meshy's, or CMU's).
## Each game joint takes its source bone's rotation, offset once so that the two rest poses line up (the
## sources stand in a T-pose, the game's skeleton with its arms down). The clip also records the hips'
## height through the motion, and, for a move that travels (run, strafe, backpedal), which way it goes (the
## planted foot sliding back under an in-place clip, or the hips moving otherwise) and how fast: as fast as the
## game's own skeleton goes taking the clip's strides. The game plays travelling clips at the rate that keeps the
## feet planted at the player's speed.

const FPS := 30.0
## Game joint -> its parent joint, and the source bone (and the bone it points to) for each skeleton.
const JOINTS := ["pelvis", "spine", "chest", "neck", "head", "sh_l", "sh_r", "el_l", "el_r", "hip_l", "hip_r", "kn_l", "kn_r"]
const PARENT := {"pelvis": "", "spine": "pelvis", "chest": "spine", "neck": "chest", "head": "neck", "sh_l": "chest",
	"sh_r": "chest", "el_l": "sh_l", "el_r": "sh_r", "hip_l": "pelvis", "hip_r": "pelvis", "kn_l": "hip_l", "kn_r": "hip_r"}
const MIXAMO := {"pelvis": ["hips", "spine"], "spine": ["spine", "spine1"], "chest": ["spine2", "neck"], "neck": ["neck", "head"],
	"head": ["head", "headtop_end"], "sh_l": ["leftarm", "leftforearm"], "sh_r": ["rightarm", "rightforearm"],
	"el_l": ["leftforearm", "lefthand"], "el_r": ["rightforearm", "righthand"], "hip_l": ["leftupleg", "leftleg"],
	"hip_r": ["rightupleg", "rightleg"], "kn_l": ["leftleg", "leftfoot"], "kn_r": ["rightleg", "rightfoot"]}
## The CMU library's BVH skeleton (Hips, LowerBack, Spine, Spine1, Neck, Neck1, Head, LeftArm, LeftUpLeg ...).
const CMU := {"pelvis": ["hips", "spine"], "spine": ["spine", "spine1"], "chest": ["spine1", "neck1"], "neck": ["neck1", "head"],
	"head": ["head", "head_end"], "sh_l": ["leftarm", "leftforearm"], "sh_r": ["rightarm", "rightforearm"],
	"el_l": ["leftforearm", "lefthand"], "el_r": ["rightforearm", "righthand"], "hip_l": ["leftupleg", "leftleg"],
	"hip_r": ["rightupleg", "rightleg"], "kn_l": ["leftleg", "leftfoot"], "kn_r": ["rightleg", "rightfoot"]}
const MESHY := {"pelvis": ["hips", "spine02"], "spine": ["spine02", "spine01"], "chest": ["spine", "neck"], "neck": ["neck", "head"],
	"head": ["head", "head_end"], "sh_l": ["leftarm", "leftforearm"], "sh_r": ["rightarm", "rightforearm"],
	"el_l": ["leftforearm", "lefthand"], "el_r": ["rightforearm", "righthand"], "hip_l": ["leftupleg", "leftleg"],
	"hip_r": ["rightupleg", "rightleg"], "kn_l": ["leftleg", "leftfoot"], "kn_r": ["rightleg", "rightfoot"]}

var _sk: Skeleton3D
var _bone := {}          # normalised name -> bone index
var _t0 := 0.0           # --from: where in the source the clip starts
var _t1 := -1.0          # --to: and ends (-1: the source's end)
var _mirror := false
var _face := false       # a BVH take: its subject may face any way in the room, so turn the clip to face forward


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0]
	var out: String = args[1]
	var name := args[2] if args.size() > 2 and not args[2].begins_with("--") else out.get_file().get_basename()
	var loop := "--loop" in args
	_mirror = "--mirror" in args
	for a in args:
		if a.begins_with("--from="):
			_t0 = float(a.substr(7))
		elif a.begins_with("--to="):
			_t1 = float(a.substr(5))
	var root: Node3D
	if src.to_lower().ends_with(".bvh"):
		root = _load_bvh(src)
		_face = true
	else:
		var doc = FBXDocument.new() if src.to_lower().ends_with(".fbx") else GLTFDocument.new()
		var state = FBXState.new() if src.to_lower().ends_with(".fbx") else GLTFState.new()
		if doc.append_from_file(src, state) != OK:
			push_error("can't read " + src)
			get_tree().quit(1)
			return
		root = doc.generate_scene(state)
	if root == null:
		push_error("can't read " + src)
		get_tree().quit(1)
		return
	add_child(root)
	_sk = root.find_children("*", "Skeleton3D", true, false)[0]
	# "mixamorig:LeftArm", imported as "mixamorig_LeftArm" -> "leftarm"
	var prefix := RegEx.create_from_string("^mixamorig\\d*[:_]")
	for b in _sk.get_bone_count():
		var n := String(_sk.get_bone_name(b)).to_lower()
		_bone[prefix.sub(n.substr(n.rfind(":") + 1) if not n.begins_with("mixamorig") else n, "")] = b
	if not _bone.has("hips"):
		push_error("no Hips bone in " + src + ": not a Mixamo or Meshy skeleton")
		get_tree().quit(1)
		return
	var map: Dictionary = MESHY if _bone.has("spine02") else (CMU if _bone.has("lowerback") else MIXAMO)
	var anim := _longest(root.find_children("*", "AnimationPlayer", true, false))
	if anim == null:
		push_error("no animation in " + src)
		get_tree().quit(1)
		return
	var clip := _convert(anim, map, name, loop)
	clip["source"] = src.get_file()
	if "--low" in args:
		clip["low"] = true
	_write(clip, out)
	# A travelling clip goes at the speed the game's own skeleton's strides carry it (MocapClip.foot_speed): played at
	# that rate, its feet hold. The source's proportions are not the game's.
	var made := MocapClip.load_file(out)
	var held := made.foot_speed() if made != null else Vector2.ZERO
	if float(clip.speed) > 0.2 and held.x > 0.2:
		print("%s: the source travels at %.2f m/s, the game's skeleton at %.2f" % [name, clip.speed, held.x])
		clip["speed"] = snappedf(held.x, 0.01)
		_write(clip, out)
	print("wrote %s: %s, %.2f s, %d frames, speed %.2f m/s %s, hips %.2f..%.2f" % [out, name, clip.length,
		(clip.frames as Array).size(), clip.speed, clip.dir, clip.h_min, clip.h_max])
	get_tree().quit()


func _write(clip: Dictionary, out: String) -> void:
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(clip))
	f.close()


func _longest(players: Array) -> Animation:
	var best: Animation = null
	for p in players:
		for a in (p as AnimationPlayer).get_animation_list():
			var an := (p as AnimationPlayer).get_animation(a)
			if best == null or an.length > best.length:
				best = an
	return best


## Every bone's transform in the scene's space, posed at time t (null: the rest pose).
func _globals(anim: Animation, t) -> Array:
	var local := []
	for b in _sk.get_bone_count():
		local.append(_sk.get_bone_rest(b))
	if anim != null:
		for i in anim.get_track_count():
			var path := String(anim.track_get_path(i))
			var b := _sk.find_bone(path.substr(path.rfind(":") + 1))
			if b < 0:
				continue
			var x: Transform3D = local[b]
			match anim.track_get_type(i):
				Animation.TYPE_POSITION_3D:
					x.origin = anim.position_track_interpolate(i, t)
				Animation.TYPE_ROTATION_3D:
					x.basis = Basis(anim.rotation_track_interpolate(i, t)).scaled(x.basis.get_scale())
				Animation.TYPE_SCALE_3D:
					x.basis = x.basis.orthonormalized().scaled(anim.scale_track_interpolate(i, t))
			local[b] = x
	var glob := []
	glob.resize(local.size())
	for b in local.size():
		var p := _sk.get_bone_parent(b)
		glob[b] = (glob[p] as Transform3D) * (local[b] as Transform3D) if p >= 0 else _sk.global_transform * (local[b] as Transform3D)
	return glob


func _convert(anim: Animation, map: Dictionary, name: String, loop: bool) -> Dictionary:
	var rest := _globals(null, null)
	# Face the game's way (-Z): the toes point forward.
	var foot: int = _bone.get("leftfoot", -1)
	var toe: int = _bone.get("lefttoebase", _bone.get("lefttoe_end", -1))
	var turn := Basis()
	if foot >= 0 and toe >= 0 and ((rest[toe] as Transform3D).origin - (rest[foot] as Transform3D).origin).z > 0.0:
		turn = Basis(Vector3.UP, PI)
	var hips: int = _bone["hips"]
	var hips_rest := (turn * (rest[hips] as Transform3D).origin).y
	var top := 0.0
	for b in _sk.get_bone_count():
		top = maxf(top, (turn * (rest[b] as Transform3D).origin).y)
	var floor_y := INF
	for b in _sk.get_bone_count():
		floor_y = minf(floor_y, (turn * (rest[b] as Transform3D).origin).y)
	var body_h := top - floor_y   # head-top joint over the lowest joint (the toes), about 0.97 of standing height
	# The body's surface around each joint, for how high off the floor the body is: a foot's joints are as
	# far above the sole as they stand at rest, the rest as thick as a person is there.
	var radius := {}
	for b in _sk.get_bone_count():
		var n := String(_sk.get_bone_name(b)).to_lower()
		var y := (turn * (rest[b] as Transform3D).origin).y - floor_y
		var r := 0.03
		if "foot" in n or "toe" in n:
			r = y
		elif "headtop" in n or "head_end" in n:
			r = 0.0
		elif "head" in n:
			r = 0.1
		elif "neck" in n:
			r = 0.06
		elif "spine" in n or "hips" in n or "lowerback" in n:
			r = 0.12
		elif "hipjoint" in n:
			r = 0.09
		elif "shoulder" in n:
			r = 0.07
		elif "forearm" in n:
			r = 0.045
		elif "arm" in n:
			r = 0.055
		elif "hand" in n:
			r = 0.03
		elif "upleg" in n:
			r = 0.09
		elif "leg" in n:
			r = 0.055
		radius[b] = r
	var scale := 1.78 * 0.97 / body_h
	# Per joint: source rotation (in the game's frame) at rest, and the offset that lines the rest poses up.
	var offset := {}
	for j in JOINTS:
		var pair: Array = map[j]
		var b: int = _bone.get(pair[0], -1)
		if b < 0:
			continue
		var s0 := (turn * (rest[b] as Transform3D).basis).orthonormalized()
		var fix := Basis()
		var c: int = _bone.get(pair[1], -1)
		if c >= 0:
			var d_src := (turn * ((rest[c] as Transform3D).origin - (rest[b] as Transform3D).origin)).normalized()
			var d_game := Vector3.UP if j in ["pelvis", "spine", "chest", "neck", "head"] else Vector3.DOWN
			fix = Basis(Quaternion(d_game, d_src))   # game rest direction -> source rest direction
		offset[j] = s0.inverse() * fix

	var frames := []
	var t0 := clampf(_t0, 0.0, anim.length)
	var t1 := anim.length if _t1 < 0.0 else clampf(_t1, t0, anim.length)
	var span := t1 - t0
	var n := maxi(2, int(round(span * FPS)) + (0 if loop else 1))
	if _face:
		# The way the hips face through the clip, on average, turned to the game's forward (-Z).
		var face := Vector3.ZERO
		var rest_fwd := ((rest[hips] as Transform3D).basis.inverse() * Vector3.BACK)
		for i in n:
			var f := turn * ((_globals(anim, minf(t1, t0 + i / FPS))[hips] as Transform3D).basis * rest_fwd)
			face += Vector3(f.x, 0.0, f.z)
		if face.length() > 0.01:
			turn = Basis(Vector3.UP, PI - atan2(face.x, face.z)) * turn
	var feet := []   # per frame: [left foot pos, right foot pos]
	var hips_track := []
	var h_min := INF
	var h_max := -INF
	for i in n:
		var t := minf(t1, t0 + i / FPS)
		var g := _globals(anim, t)
		var glob := {}
		var q := []
		for j in JOINTS:
			if not offset.has(j):
				glob[j] = glob.get(PARENT[j], Basis()) if PARENT[j] != "" else Basis()
				q.append_array([0, 0, 0, 1])
				continue
			var b: int = _bone[map[j][0]]
			var s := (turn * (g[b] as Transform3D).basis).orthonormalized()
			var tg: Basis = s * (offset[j] as Basis)
			glob[j] = tg
			var parent_b: Basis = glob[PARENT[j]] if PARENT[j] != "" else Basis()
			var lq := (parent_b.inverse() * tg).get_rotation_quaternion()
			q.append_array([snappedf(lq.x, 0.0001), snappedf(lq.y, 0.0001), snappedf(lq.z, 0.0001), snappedf(lq.w, 0.0001)])
		var hp := turn * (g[hips] as Transform3D).origin
		var h := hp.y / hips_rest
		h_min = minf(h_min, h)
		h_max = maxf(h_max, h)
		hips_track.append(hp)
		var lf: int = _bone.get("leftfoot", hips)
		var rf: int = _bone.get("rightfoot", hips)
		feet.append([turn * (g[lf] as Transform3D).origin, turn * (g[rf] as Transform3D).origin])
		# Off the floor: the lowest point of the body's surface over the floor (0 standing or lying).
		var low := INF
		for b in _sk.get_bone_count():
			low = minf(low, (turn * (g[b] as Transform3D).origin).y - floor_y - float(radius[b]))
		var air := maxf(0.0, low) * scale
		if _mirror:
			q = _mirrored(q)
		frames.append({"t": snappedf(t - t0, 0.0001), "h": snappedf(h, 0.0001), "a": snappedf(air, 0.001), "q": q})

	# How fast and which way the move travels, scaled to a 1.78 m player.
	var vel := Vector3.ZERO
	var travel: Vector3 = (hips_track[-1] as Vector3) - (hips_track[0] as Vector3)
	travel.y = 0.0
	if travel.length() > 0.3:
		vel = travel / maxf(span, 0.001)   # the hips really move
	else:
		# In place: the foot on the ground slides back as fast as the body would go forward.
		var samples := []
		for i in range(1, n):
			for k in 2:
				var a: Vector3 = feet[i - 1][k]
				var b: Vector3 = feet[i][k]
				var other: Vector3 = feet[i][1 - k]
				if b.y <= other.y and b.y < floor_y + 0.08 * body_h:
					samples.append(-(b - a) * FPS)
		if samples.size() > 4:
			samples.sort_custom(func(x, y): return Vector2(x.x, x.z).length() < Vector2(y.x, y.z).length())
			vel = samples[samples.size() / 2]   # median
		vel.y = 0.0
	var speed := vel.length() * scale
	var dir := Vector3.ZERO if speed < 0.2 else vel.normalized()
	if _mirror:
		dir.x = -dir.x
	# The game's "forward" is -Z: report the direction as [side, forward].
	return {"name": name, "version": 2, "fps": FPS, "length": snappedf(span, 0.0001), "loop": loop,
		"speed": snappedf(speed, 0.01), "dir": [snappedf(dir.x, 0.01), snappedf(-dir.z, 0.01)],
		"h_min": snappedf(h_min, 0.001), "h_max": snappedf(h_max, 0.001), "joints": JOINTS, "frames": frames}


## The frame's joint rotations with the body's left and right swapped: each side takes the other's rotation,
## reflected through the body's middle (x to -x).
func _mirrored(q: Array) -> Array:
	var out := []
	for j in JOINTS:
		var k: String = j.replace("_l", "_R").replace("_r", "_l").replace("_R", "_r") if j.ends_with("_l") or j.ends_with("_r") else j
		var i: int = JOINTS.find(k) * 4
		out.append_array([q[i], -float(q[i + 1]), -float(q[i + 2]), q[i + 3]])
	return out


## A BVH file (the CMU library's) as a scene the converter reads: a Skeleton3D standing in the file's rest pose
## (each joint at its OFFSET, unturned) and an AnimationPlayer with its motion, a rotation track for every joint
## and a position track for the root. An End Site becomes a bone named after its joint with "_end".
func _load_bvh(path: String) -> Node3D:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var names: Array[String] = []
	var parents: Array[int] = []
	var offsets: Array[Vector3] = []
	var channels: Array = []          # per bone: its channel names
	var stack: Array[int] = []
	var pending := -1                 # the bone a "{" opens
	var frame_time := 1.0 / 120.0
	var motion: Array[PackedFloat64Array] = []
	var in_motion := false
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "":
			continue
		if in_motion:
			if line.begins_with("Frames:"):
				continue
			if line.begins_with("Frame Time:"):
				frame_time = float(line.substr(11).strip_edges())
				continue
			motion.append(PackedFloat64Array(Array(line.split(" ", false)).map(func(s): return float(s))))
			continue
		var parts := line.split(" ", false)
		match parts[0]:
			"ROOT", "JOINT":
				names.append(parts[1])
				parents.append(stack[-1] if not stack.is_empty() else -1)
				offsets.append(Vector3.ZERO)
				channels.append([])
				pending = names.size() - 1
			"End":
				names.append(names[stack[-1]] + "_end")
				parents.append(stack[-1])
				offsets.append(Vector3.ZERO)
				channels.append([])
				pending = names.size() - 1
			"{":
				stack.append(pending)
			"}":
				stack.pop_back()
			"OFFSET":
				offsets[stack[-1]] = Vector3(float(parts[1]), float(parts[2]), float(parts[3]))
			"CHANNELS":
				channels[stack[-1]] = parts.slice(2)
			"MOTION":
				in_motion = true
	# Stand the rest pose on the floor: the root's OFFSET is nought, and its motion is in the room's own heights.
	var rest_pos: Array[Vector3] = []
	var low := 0.0
	for k in names.size():
		rest_pos.append(offsets[k] + (rest_pos[parents[k]] if parents[k] >= 0 else Vector3.ZERO))
		low = minf(low, rest_pos[k].y)
	offsets[0] += Vector3(0.0, -low, 0.0)
	var root := Node3D.new()
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	root.add_child(sk)
	for b in names.size():
		sk.add_bone(names[b])
		if parents[b] >= 0:
			sk.set_bone_parent(b, parents[b])
		sk.set_bone_rest(b, Transform3D(Basis(), offsets[b]))
	var anim := Animation.new()
	anim.length = maxf(frame_time, (motion.size() - 1) * frame_time)
	var col := 0
	for b in names.size():
		var ch: Array = channels[b]
		if ch.is_empty():
			continue
		var rot := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rot, "Skeleton3D:" + names[b])
		var pos := -1
		if "Xposition" in ch:
			pos = anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(pos, "Skeleton3D:" + names[b])
		for i in motion.size():
			var row := motion[i]
			var basis := Basis()
			var at := offsets[b]
			for k in ch.size():
				var v := row[col + k]
				match String(ch[k]):
					"Xposition": at.x = v
					"Yposition": at.y = v
					"Zposition": at.z = v
					"Xrotation": basis = basis * Basis(Vector3.RIGHT, deg_to_rad(v))
					"Yrotation": basis = basis * Basis(Vector3.UP, deg_to_rad(v))
					"Zrotation": basis = basis * Basis(Vector3.BACK, deg_to_rad(v))
			anim.rotation_track_insert_key(rot, i * frame_time, basis.get_rotation_quaternion())
			if pos >= 0:
				anim.position_track_insert_key(pos, i * frame_time, at)
		col += ch.size()
	var player := AnimationPlayer.new()
	var lib := AnimationLibrary.new()
	lib.add_animation("take", anim)
	player.add_animation_library("", lib)
	root.add_child(player)
	return root
