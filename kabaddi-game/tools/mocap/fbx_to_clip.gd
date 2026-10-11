extends Node
## Turns an animation from Mixamo (FBX) or Meshy (FBX or GLB) into a clip the game plays
## (assets/mocap/<name>.json, version 2: a full 3D rotation for each of the game's joints).
##
##   godot --headless --path . res://tools/mocap/fbx_to_clip.tscn -- IN.fbx OUT.json [NAME] [--loop]
##
## The source skeleton is matched to the game's by bone names (Mixamo's "mixamorig:" names, or Meshy's).
## Each game joint takes its source bone's rotation, offset once so that the two rest poses line up (the
## sources stand in a T-pose, the game's skeleton with its arms down). The clip also records the hips'
## height through the motion, and, for a move that travels (run, strafe, backpedal), how fast and which
## way: from the planted foot sliding back under an in-place clip, or from the hips moving otherwise. The
## game plays travelling clips at the rate that keeps the feet planted at the player's speed.

const FPS := 30.0
## Game joint -> its parent joint, and the source bone (and the bone it points to) for each skeleton.
const JOINTS := ["pelvis", "spine", "chest", "neck", "head", "sh_l", "sh_r", "el_l", "el_r", "hip_l", "hip_r", "kn_l", "kn_r"]
const PARENT := {"pelvis": "", "spine": "pelvis", "chest": "spine", "neck": "chest", "head": "neck", "sh_l": "chest",
	"sh_r": "chest", "el_l": "sh_l", "el_r": "sh_r", "hip_l": "pelvis", "hip_r": "pelvis", "kn_l": "hip_l", "kn_r": "hip_r"}
const MIXAMO := {"pelvis": ["hips", "spine"], "spine": ["spine", "spine1"], "chest": ["spine2", "neck"], "neck": ["neck", "head"],
	"head": ["head", "headtop_end"], "sh_l": ["leftarm", "leftforearm"], "sh_r": ["rightarm", "rightforearm"],
	"el_l": ["leftforearm", "lefthand"], "el_r": ["rightforearm", "righthand"], "hip_l": ["leftupleg", "leftleg"],
	"hip_r": ["rightupleg", "rightleg"], "kn_l": ["leftleg", "leftfoot"], "kn_r": ["rightleg", "rightfoot"]}
const MESHY := {"pelvis": ["hips", "spine02"], "spine": ["spine02", "spine01"], "chest": ["spine", "neck"], "neck": ["neck", "head"],
	"head": ["head", "head_end"], "sh_l": ["leftarm", "leftforearm"], "sh_r": ["rightarm", "rightforearm"],
	"el_l": ["leftforearm", "lefthand"], "el_r": ["rightforearm", "righthand"], "hip_l": ["leftupleg", "leftleg"],
	"hip_r": ["rightupleg", "rightleg"], "kn_l": ["leftleg", "leftfoot"], "kn_r": ["rightleg", "rightfoot"]}

var _sk: Skeleton3D
var _bone := {}          # normalised name -> bone index


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0]
	var out: String = args[1]
	var name := args[2] if args.size() > 2 and not args[2].begins_with("--") else out.get_file().get_basename()
	var loop := "--loop" in args
	var doc = FBXDocument.new() if src.to_lower().ends_with(".fbx") else GLTFDocument.new()
	var state = FBXState.new() if src.to_lower().ends_with(".fbx") else GLTFState.new()
	if doc.append_from_file(src, state) != OK:
		push_error("can't read " + src)
		get_tree().quit(1)
		return
	var root: Node3D = doc.generate_scene(state)
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
	var map: Dictionary = MESHY if _bone.has("spine02") else MIXAMO
	var anim := _longest(root.find_children("*", "AnimationPlayer", true, false))
	if anim == null:
		push_error("no animation in " + src)
		get_tree().quit(1)
		return
	var clip := _convert(anim, map, name, loop)
	clip["source"] = src.get_file()
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(clip))
	f.close()
	print("wrote %s: %s, %.2f s, %d frames, speed %.2f m/s %s, hips %.2f..%.2f" % [out, name, clip.length,
		(clip.frames as Array).size(), clip.speed, clip.dir, clip.h_min, clip.h_max])
	get_tree().quit()


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
	var n := maxi(2, int(round(anim.length * FPS)) + (0 if loop else 1))
	var feet := []   # per frame: [left foot pos, right foot pos]
	var hips_track := []
	var h_min := INF
	var h_max := -INF
	for i in n:
		var t := minf(anim.length, i / FPS)
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
		frames.append({"t": snappedf(t, 0.0001), "h": snappedf(h, 0.0001), "q": q})

	# How fast and which way the move travels, scaled to a 1.78 m player.
	var vel := Vector3.ZERO
	var travel: Vector3 = (hips_track[-1] as Vector3) - (hips_track[0] as Vector3)
	travel.y = 0.0
	if travel.length() > 0.3:
		vel = travel / anim.length   # the hips really move
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
	var scale := 1.78 * 0.97 / body_h
	var speed := vel.length() * scale
	var dir := Vector3.ZERO if speed < 0.2 else vel.normalized()
	# The game's "forward" is -Z: report the direction as [side, forward].
	return {"name": name, "version": 2, "fps": FPS, "length": snappedf(anim.length, 0.0001), "loop": loop,
		"speed": snappedf(speed, 0.01), "dir": [snappedf(dir.x, 0.01), snappedf(-dir.z, 0.01)],
		"h_min": snappedf(h_min, 0.001), "h_max": snappedf(h_max, 0.001), "joints": JOINTS, "frames": frames}
