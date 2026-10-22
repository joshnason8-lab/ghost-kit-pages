extends Node
## Turns kicks from motion capture (Mixamo FBX files) into the game's moves, assets/moves/<move>.json:
##   godot --headless --path . res://tools/models/fbx_to_move.tscn -- FBX_DIR [MOVE]
## (and the strides, run and walk, from the models' own animations: LOOPS)
##
## Each move (SPECS) takes a stretch of a clip: from t[0] to t[2] seconds, the ball met at t[1]. That stretch is
## played in the move's length, the ball met at its contact fraction (the run-up and the recovery each at their own
## speed). Each frame becomes a pose: every pose bone's turn (RealBody: the source skeleton's rest put the same way as
## the models'), the hips' travel, and the lift off the floor; blended from the ready stance at the start and back
## to it at the end. A left-footed kick is mirrored: the moves are made for the right foot.
##
## It prints each move's CONTACT row (game/moves.gd): where the ball is met, measured on the man's model in that pose.

const FPS := 30.0
const SPECS := {
	# move: clip, mirrored, source times [start, contact, end], game length (s), contact fraction, the part that
	# meets the ball (and the ball's centre above it, m), a jump added at contact (m), extra turn (degrees)
	"serve": {"file": "Kicking.fbx", "mirror": true, "t": [0.62, 1.15, 1.9], "length": 1.1, "contact": 0.5,
		"at": "instep", "ball": 0.08, "lift": 0.0, "turn": 0.0},
	"roll": {"file": "Scissor Kick.fbx", "mirror": false, "t": [0.12, 0.8, 2.65], "length": 1.65, "contact": 0.36,
		"at": "foot", "ball": 0.0, "lift": 0.3, "turn": 0.0},
	"sunback": {"file": "Mma Kick.fbx", "mirror": false, "t": [0.25, 0.7, 1.6], "length": 1.05, "contact": 0.43,
		"at": "foot", "ball": 0.0, "lift": 0.55, "turn": 0.0},
	"tapak": {"file": "Roundhouse Kick.fbx", "mirror": false, "t": [0.45, 1.0, 2.1], "length": 1.05, "contact": 0.42,
		"at": "foot", "ball": 0.0, "lift": 0.5, "turn": 0.0},
	"thigh": {"file": "Knee Kick Lead.fbx", "mirror": true, "t": [0.5, 0.72, 1.45], "length": 0.62, "contact": 0.42,
		"at": "thigh", "ball": 0.07, "lift": 0.0, "turn": 0.0},
}
## Strides, from the models' own animations: one cycle each, in place (Moves.run).
const LOOPS := {
	"run": {"file": "res://assets/models/man.glb", "anim": "Running"},
	"walk": {"file": "res://assets/models/man.glb", "anim": "Walking"},
}
const BLEND_IN := 0.14
const BLEND_OUT := 0.22

var _sk: Skeleton3D
var _xf := Transform3D.IDENTITY   # the skeleton's place in the clip's scene
var _put := []                    # each bone's rest put the poses' way (as RealBody.Rig does it)
var _bone := {}                   # short name -> bone


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0] if a.size() > 0 else "."
	var only: String = a[1] if a.size() > 1 else ""
	var man := RealBody.rig(false)
	if dir.begins_with("measure:"):
		# Where a move written by hand meets the ball (measure:MOVE:PART): its CONTACT row.
		var w := dir.split(":")
		var c: Array = Moves.CONTACT[w[1]]
		var p := Moves.sample(w[1], float(c[4]))
		man.solve(p)
		var at := _point(man, w[2]) + Vector3(0, float(p.get("y", 0.0)), 0)
		var yaw := deg_to_rad(float(p.get("yaw", 0.0)))
		at = at.rotated(Vector3.UP, yaw)
		print('	"%s": %s,' % [w[1], str([snappedf(at.y, 0.01), snappedf(at.z, 0.01), snappedf(-at.x, 0.01), c[3], c[4]])])
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Moves.CLIP_DIR))
	for name in LOOPS:
		if only != "" and name != only:
			continue
		var frames := _convert_loop(LOOPS[name])
		if not frames.is_empty():
			_save(name, {"name": name, "source": LOOPS[name].anim, "fps": FPS, "loop": true}, frames)
	for name in SPECS:
		if only != "" and name != only:
			continue
		var spec: Dictionary = SPECS[name]
		var frames := _convert(dir.path_join(spec.file), spec)
		if frames.is_empty():
			continue
		# Where the ball is met: on the man's model, in the pose at the contact frame.
		var cf := int(round(float(spec.contact) * (frames.size() - 1)))
		var p: Dictionary = frames[cf]
		man.solve(p)
		var at := _point(man, String(spec.at)) + Vector3(0, float(p.get("y", 0.0)) + float(spec.ball), 0)
		var row := [snappedf(at.y, 0.01), snappedf(at.z, 0.01), snappedf(-at.x, 0.01), float(spec.length), float(spec.contact)]
		_save(name, {"name": name, "source": spec.file, "fps": FPS, "length": spec.length, "contact": row}, frames)
		var top := 0.0
		for fr in frames:
			top = maxf(top, float(fr.get("y", 0.0)))
		print("%s: %d frames, highest off the floor %.2f m" % [name, frames.size(), top])
		print('	"%s": %s,' % [name, str(row)])
	get_tree().quit()


func _save(name: String, out: Dictionary, frames: Array) -> void:
	out.frames = []
	for fr in frames:
		var o := {}
		for key in fr:
			var v = fr[key]
			if v is Quaternion or v is Vector3:
				var q := RealBody.local_rot(v)
				o[key] = [snappedf(q.x, 0.0001), snappedf(q.y, 0.0001), snappedf(q.z, 0.0001), snappedf(q.w, 0.0001)]
			else:
				o[key] = snappedf(float(v), 0.0001)
		out.frames.append(o)
	var f := FileAccess.open(Moves.CLIP_DIR + name + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()


## The part of the right leg (or head) that meets the ball, in the body's space (m).
func _point(r: RealBody.Rig, at: String) -> Vector3:
	var foot: Vector3 = r.out_pos[r.index["RightFoot"]]
	var toe: Vector3 = r.out_pos[r.index["RightToeBase"]]
	var knee: Vector3 = r.out_pos[r.index["RightLeg"]]
	var hip: Vector3 = r.out_pos[r.index["RightUpLeg"]]
	match at:
		"instep":
			return foot.lerp(toe, 0.55)
		"foot":
			return foot.lerp(toe, 0.5)
		"sole":
			return foot.lerp(toe, 0.4)
		"thigh":
			return hip.lerp(knee, 0.8)
		"head":
			return r.out_pos[r.index["Head"]] + Vector3(0, 0.12, 0)
	return foot


## Reads a clip (an FBX, or the models' own animations): the skeleton, its place, and the animation (by name, or the
## last). Returns [scene, animation], or [] when it cannot.
func _load(path: String, anim_name := "") -> Array:
	var scene: Node3D
	if path.begins_with("res://"):
		scene = (load(path) as PackedScene).instantiate()
	else:
		var doc := FBXDocument.new()
		var st := FBXState.new()
		if doc.append_from_file(path, st) != OK:
			push_error("can't read " + path)
			return []
		scene = doc.generate_scene(st)
	_sk = scene.find_children("*", "Skeleton3D", true, false)[0]
	_xf = Transform3D.IDENTITY
	var n: Node = _sk
	while n != null and n != scene:
		if n is Node3D:
			_xf = (n as Node3D).transform * _xf
		n = n.get_parent()
	var anim: Animation = null
	for ap in scene.find_children("*", "AnimationPlayer", true, false):
		for an in (ap as AnimationPlayer).get_animation_list():
			if anim_name == "" or String(an) == anim_name:
				anim = (ap as AnimationPlayer).get_animation(an)
	_bone.clear()
	for b in _sk.get_bone_count():
		_bone[String(_sk.get_bone_name(b)).trim_prefix("mixamorig_").trim_prefix("mixamorig:")] = b
	_rest_put(_globals(null, 0.0))
	return [scene, anim]


## Every pose bone's turn from rest at the moment g (the skeleton's globals), the clip turned by turn.
func _pose_at(g: Array, turn: Basis) -> Dictionary:
	var p := {}
	var turns := {}
	for bi in RealBody.BONES.size():
		var pb: String = RealBody.BONES[bi][0]
		var src := _source_of(pb)
		var d := Quaternion(turn * (_xf.basis * (g[_bone[src]] as Transform3D).basis).orthonormalized() * (_put[_bone[src]] as Basis).inverse())
		turns[pb] = d
		var par: String = RealBody.BONES[bi][1]
		p[pb] = (turns[par] as Quaternion).inverse() * d if par != "" else d
	return p


## A stride from the models' own animations, one cycle of it in place, facing +Z (Moves.run plays it).
func _convert_loop(spec: Dictionary) -> Array:
	var loaded := _load(String(spec.file), String(spec.anim))
	if loaded.is_empty() or loaded[1] == null:
		return []
	var scene: Node3D = loaded[0]
	var anim: Animation = loaded[1]
	var rest := _globals(null, 0.0)
	var length := anim.length
	var a := _globals(anim, 0.0)
	var p0 := _pos(a, "Hips")
	var travel := _pos(_globals(anim, length), "Hips") - p0
	travel.y = 0.0
	var turn := Basis(Vector3.UP, -atan2(travel.x, travel.z)) if travel.length() > 0.2 else Basis(Vector3.UP, -_yaw(a))
	var hips_rest := _pos(rest, "Hips").y
	var count := int(round(length * FPS))
	var frames := []
	var reach := []   # how far ahead the left foot is: the cycle starts with it furthest forward (walk and run in step)
	for i in count:
		var ts := length * float(i) / float(count)
		var g := _globals(anim, ts)
		var p := _pose_at(g, turn)
		var hp := turn * (_pos(g, "Hips") - p0 - travel * (ts / length))
		p["y"] = 0.0
		p["hips_y"] = hp.y + p0.y - hips_rest
		p["hips_fwd"] = hp.z
		p["hips_side"] = -hp.x
		p["plant"] = 0.0
		frames.append(p)
		reach.append((turn * (_pos(g, "LeftFoot") - _pos(g, "Hips"))).z)
	var first := reach.find(reach.max())
	frames = frames.slice(first) + frames.slice(0, first)
	print("%s: %.2f s a stride, %.2f m/s" % [spec.anim, length, travel.length() / length])
	scene.free()
	return frames


func _convert(path: String, spec: Dictionary) -> Array:
	var loaded := _load(path)
	if loaded.is_empty():
		return []
	var scene: Node3D = loaded[0]
	var anim: Animation = loaded[1]
	var rest := _globals(null, 0.0)
	var t: Array = spec.t
	var start := _globals(anim, float(t[0]))
	var root := _pos(start, "Hips")
	root.y = 0.0
	# Turned so the ball is met straight ahead (toward the net), the run-up's facing kept.
	var at_contact := _globals(anim, float(t[1]))
	var kick := "Right" if not bool(spec.mirror) else "Left"
	var reach := _pos(at_contact, kick + "Foot").lerp(_pos(at_contact, kick + "ToeBase"), 0.5) - root
	var turn := Basis(Vector3.UP, -atan2(reach.x, reach.z) + deg_to_rad(float(spec.turn)))
	if String(spec.at) == "thigh":
		turn = Basis(Vector3.UP, -_yaw(start) + deg_to_rad(float(spec.turn)))   # a knee lifts in front of him
	var hips_rest := _pos(rest, "Hips").y
	var feet_rest := {}
	for nm in ["LeftFoot", "LeftToeBase", "RightFoot", "RightToeBase"]:
		feet_rest[nm] = _pos(rest, nm).y
	var length := float(spec.length)
	var count := int(ceil(length * FPS)) + 1
	var cf := float(spec.contact)
	var lift := float(spec.lift)
	var frames := []
	for i in count:
		var f := float(i) / float(count - 1)
		var ts := lerpf(float(t[0]), float(t[1]), f / cf) if f <= cf else lerpf(float(t[1]), float(t[2]), (f - cf) / (1.0 - cf))
		var g := _globals(anim, ts)
		var p := _pose_at(g, turn)
		# The hips' travel from where the move starts, and how far off the floor the lowest of him is.
		var hp := turn * (_pos(g, "Hips") - root)
		var low := INF
		for nm in feet_rest:
			low = minf(low, _pos(g, nm).y - float(feet_rest[nm]))
		for nm in ["LeftHand", "RightHand"]:
			low = minf(low, _pos(g, nm).y - 0.05)
		low = minf(low, _pos(g, "Head").y - 0.12)
		low = minf(low, hp.y - 0.15)
		var up := maxf(0.0, low)
		var secs := ts - float(t[1])
		var jump := 0.0
		var span := 0.3 if secs < 0.0 else 0.36
		if absf(secs) < span:
			jump = lift * (1.0 - (secs / span) * (secs / span))
		p["y"] = up + jump
		p["hips_y"] = hp.y - hips_rest - up
		p["hips_fwd"] = hp.z
		p["hips_side"] = -hp.x
		p["plant"] = 0.0
		if bool(spec.mirror):
			p = Moves.mirrored(p)
		var w := minf(smoothstep(0.0, BLEND_IN, f), 1.0 - smoothstep(1.0 - BLEND_OUT, 1.0, f))
		frames.append(Moves.blend(Moves.READY, p, w))
	scene.free()
	return frames


func _source_of(pose_bone: String) -> String:
	for nm in RealBody.RIG:
		var r: Array = RealBody.RIG[nm]
		if r[0] == pose_bone and r[1] == "" and not String(r[2]).begins_with("=") and _bone.has(nm):
			return nm
	return {"head": "Head", "hand_l": "LeftHand", "hand_r": "RightHand"}.get(pose_bone, "Hips")


func _pos(g: Array, nm: String) -> Vector3:
	return _xf * (g[_bone[nm]] as Transform3D).origin


func _yaw(g: Array) -> float:
	var fwd := (_xf.basis * (g[_bone["Hips"]] as Transform3D).basis) * Vector3(0, 0, 1)
	return atan2(fwd.x, fwd.z)


## Each bone's rest turned so it lies the way the pose bones rest (as RealBody.Rig does for the models).
func _rest_put(rest: Array) -> void:
	_put.clear()
	var turned := {}
	for b in _sk.get_bone_count():
		var nm := String(_sk.get_bone_name(b)).trim_prefix("mixamorig_").trim_prefix("mixamorig:")
		var g := (_xf.basis * (rest[b] as Transform3D).basis).orthonormalized()
		var spec: Array = RealBody.RIG.get(nm, [])
		var q := Quaternion.IDENTITY
		if not spec.is_empty():
			var to: String = spec[2]
			if to.begins_with("="):
				q = turned.get(to.substr(1), Quaternion.IDENTITY)
			elif _bone.has(to):
				var d := (_pos(rest, to) - _pos(rest, nm)).normalized()
				q = Quaternion(d, spec[3])
			turned[nm] = q
		_put.append(Basis(q) * g)


## Every bone's transform in the skeleton's space at time t (anim null: the rest pose).
func _globals(anim: Animation, t: float) -> Array:
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
			local[b] = x
	var glob := []
	glob.resize(local.size())
	for b in local.size():
		var p := _sk.get_bone_parent(b)
		glob[b] = (glob[p] as Transform3D) * (local[b] as Transform3D) if p >= 0 else (local[b] as Transform3D)
	return glob
