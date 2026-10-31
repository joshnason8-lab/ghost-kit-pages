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

const Bvh := preload("res://tools/models/bvh.gd")
const FPS := 30.0
const SPECS := {
	# move: clip, mirrored, source times [start, contact, end], game length (s), contact fraction, the part that
	# meets the ball (and the ball's centre above it, m), a jump added at contact (m), extra turn (degrees)
	"serve": {"file": "Kicking.fbx", "mirror": true, "t": [0.62, 1.15, 1.9], "length": 1.1, "contact": 0.5,
		"at": "instep", "ball": 0.08, "lift": 0.0, "turn": 0.0, "lock": "support"},
	"roll": {"file": "Scissor Kick.fbx", "mirror": false, "t": [0.12, 0.8, 2.65], "length": 1.65, "contact": 0.36,
		"at": "foot", "ball": 0.0, "lift": 0.3, "turn": 0.0, "lock": "support"},
	"sunback": {"file": "Mma Kick.fbx", "mirror": false, "t": [0.25, 0.7, 1.6], "length": 1.05, "contact": 0.43,
		"at": "foot", "ball": 0.0, "lift": 0.55, "turn": 0.0, "lock": "support"},
	"tapak": {"file": "Roundhouse Kick.fbx", "mirror": false, "t": [0.45, 1.0, 2.1], "length": 1.05, "contact": 0.42,
		"at": "foot", "ball": 0.0, "lift": 0.5, "turn": 0.0, "lock": "support"},
	"thigh": {"file": "Knee Kick Lead.fbx", "mirror": true, "t": [0.5, 0.72, 1.45], "length": 0.62, "contact": 0.42,
		"at": "thigh", "ball": 0.07, "lift": 0.0, "turn": 0.0, "lock": "support"},
	# A real two-footed jump (the CMU library's 118_04: the dip, the spring, the landing taken on the knees), as high as
	# the move's own; in the air the takraw part laid over it from the keys in Moves: the block's raised leg, side on,
	# the arms out (never up); the header's nod and the arms' swing.
	"block": {"file": "118_04.bvh", "mirror": false, "t": [1.6, 2.56, 3.1], "length": 0.9, "contact": 0.45,
		"at": "foot", "ball": 0.0, "lift": 0.0, "turn": 0.0, "face": "start", "lift_to": 0.6, "blend_in": 0.22, "blend_out": 0.45, "root": "feet",
		"layer": {"yaw": 1.0, "hips": 1.0, "spine": 1.0, "chest": 1.0, "head": 1.0, "upperarm_l": 1.0, "upperarm_r": 1.0,
			"forearm_l": 1.0, "forearm_r": 1.0, "thigh_r": 1.0, "shin_r": 1.0, "foot_r": 1.0, "thigh_l": 0.5, "shin_l": 0.5,
			"foot_l": 0.5},
		"steady": {"head": 1.0, "neck": 1.0, "spine": 0.5, "chest": 0.5, "foot_l": 0.7, "foot_r": 0.7}},
	"head_spike": {"file": "118_04.bvh", "mirror": false, "t": [1.6, 2.56, 3.1], "length": 0.95, "contact": 0.45,
		"at": "head", "ball": 0.0, "lift": 0.0, "turn": 0.0, "face": "start", "lift_to": 0.68, "blend_in": 0.22, "blend_out": 0.45, "root": "feet",
		"layer": {"head": 1.0, "neck": 1.0, "spine": 0.7, "chest": 0.7, "upperarm_l": 0.8, "upperarm_r": 0.8,
			"forearm_l": 0.8, "forearm_r": 0.8},
		"steady": {"head": 0.7, "neck": 0.7, "spine": 0.4, "chest": 0.4, "foot_l": 0.7, "foot_r": 0.7}},
	# A jump for joy: the same real jump's legs (the dip, the spring, the landing), upright, both arms thrown up.
	"celebrate": {"file": "118_04.bvh", "mirror": false, "t": [1.6, 2.56, 3.3], "length": 1.3, "contact": 0.45,
		"at": "head", "ball": 0.0, "lift": 0.0, "turn": 0.0, "face": "start", "lift_to": 0.38, "blend_in": 0.22, "blend_out": 0.45, "root": "feet",
		"steady": {"upperarm_l": 1.0, "upperarm_r": 1.0, "forearm_l": 1.0, "forearm_r": 1.0, "head": 0.8, "neck": 0.8,
			"spine": 0.85, "chest": 0.85, "hips": 0.6, "foot_l": 0.7, "foot_r": 0.7}},
}
## Strides, from the models' own animations: one cycle each, in place (Moves.run).
const LOOPS := {
	"run": {"file": "res://assets/models/man.glb", "anim": "Running"},
	"walk": {"file": "res://assets/models/man.glb", "anim": "Walking"},
}
const BLEND_IN := 0.14
const BLEND_OUT := 0.22
const STEP := 0.03       # a foot sliding while it is down is lifted this much more at a time (m): a step
const STEP_MAX := 0.15

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
	if dir == "slide":
		# How far each move's planted feet slide, on both models (what tests/test_runner checks).
		for w in [false, true]:
			for name in SPECS:
				var s := slide(RealBody.rig(w), name)
				print("%s (%s): worst %.3f m a frame, the %s foot at %.2f; on the floor %s" % [name, "woman" if w else "man", s[0], s[2], s[1], s[3]])
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
		var frames := _convert(dir.path_join(spec.file), spec, name)
		if frames.is_empty():
			continue
		# Where the ball is met: on the man's model, in the pose at the contact frame.
		var cf := int(round(float(spec.contact) * (frames.size() - 1)))
		var p: Dictionary = frames[cf]
		man.solve(p)
		var at := _point(man, String(spec.at)) + Vector3(0, float(p.get("y", 0.0)) + float(spec.ball), 0)
		at = at.rotated(Vector3.UP, deg_to_rad(float(p.get("yaw", 0.0))))
		var row := [snappedf(at.y, 0.01), snappedf(at.z, 0.01), snappedf(-at.x, 0.01), float(spec.length), float(spec.contact)]
		_save(name, {"name": name, "source": spec.file, "fps": FPS, "length": spec.length, "contact": row}, frames)
		var top := 0.0
		for fr in frames:
			top = maxf(top, float(fr.get("y", 0.0)))
		print("%s: %d frames, highest off the floor %.2f m" % [name, frames.size(), top])
		print('	"%s": %s,' % [name, str(row)])
	get_tree().quit()


## How far a move's feet slide on a model: while a foot is on the floor (the middle of it under RealBody.SOLE_DOWN),
## its worst movement along the floor from one frame (1/30 s) to the next. [metres, when (0-1), "Left"/"Right", and a
## frame by frame record of which are down: L, R, B (both) or . (neither)].
static func slide(rig: RealBody.Rig, name: String) -> Array:
	var frames := int(round(Moves.length(name) * FPS)) + 1
	var worst := [0.0, 0.0, "", ""]
	var last := {}
	for i in frames:
		var f := float(i) / float(frames - 1)
		var p := Moves.sample(name, f)
		rig.solve(p)
		var yaw := deg_to_rad(float(p.get("yaw", 0.0)))
		var code := 0
		for side in ["Left", "Right"]:
			var at := (rig.sole(side) + Vector3(0, float(p.get("y", 0.0)), 0)).rotated(Vector3.UP, yaw)
			var down := at.y < RealBody.SOLE_DOWN
			code += (1 if side == "Left" else 2) if down else 0
			if down and last.has(side) and last[side][1]:
				var d := Vector2(at.x - last[side][0].x, at.z - last[side][0].z).length()
				if d > float(worst[0]):
					worst = [d, f, side, worst[3]]
			last[side] = [at, down]
		worst[3] = String(worst[3]) + ".LRB"[code]
	return worst


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
	elif path.get_extension() == "bvh":
		var read := Bvh.load_scene(path)
		if read.is_empty():
			return []
		scene = read[0]
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


func _convert(path: String, spec: Dictionary, move := "") -> Array:
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
	if String(spec.at) == "thigh" or String(spec.get("face", "")) == "start":
		turn = Basis(Vector3.UP, -_yaw(start) + deg_to_rad(float(spec.turn)))   # a knee lifts (or he jumps) in front of him
	var hips_rest := _pos(rest, "Hips").y
	var feet_rest := {}
	for nm in ["LeftFoot", "LeftToeBase", "RightFoot", "RightToeBase"]:
		feet_rest[nm] = _pos(rest, nm).y
	var length := float(spec.length)
	var count := int(ceil(length * FPS)) + 1
	var cf := float(spec.contact)
	var lift := float(spec.lift)
	var frames := []
	var under := []   # where his feet are (between them, on the floor), and whether both are down
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
		frames.append(p)
		var mid := turn * ((_pos(g, "LeftFoot") + _pos(g, "RightFoot")) * 0.5 - root)
		var down := maxf(_pos(g, "LeftFoot").y - float(feet_rest.LeftFoot), _pos(g, "RightFoot").y - float(feet_rest.RightFoot)) < 0.04
		under.append([Vector2(mid.x, mid.z), down])
	scene.free()
	# Jumping on the spot ("root": "feet"): the hips measured from his feet while both are down (and from where they
	# were and will be, through the air), so the clip's own travel is left out and his feet stay where they are; where
	# he is stays the movement's to say.
	if String(spec.get("root", "")) == "feet":
		var ref := []
		for i in under.size():
			ref.append(under[i][0] if under[i][1] else null)
		var last = null
		for i in ref.size():
			if ref[i] == null:
				var nxt = null
				var j := i
				while j < ref.size() and ref[j] == null:
					j += 1
				nxt = ref[j] if j < ref.size() else last
				if last == null:
					last = nxt
				var a := i - 1
				ref[i] = (last as Vector2).lerp(nxt as Vector2, float(i - a) / float(j - a)) if nxt != null else last
			last = ref[i]
		var first: Vector2 = ref[0]
		for i in frames.size():
			var d: Vector2 = (ref[i] as Vector2) - first
			frames[i].hips_fwd = float(frames[i].hips_fwd) - d.y
			frames[i].hips_side = float(frames[i].hips_side) + d.x
	# A real jump as high as the move's own (lift_to, m), and the move's own part laid over it while he is off the floor
	# (layer: the bones, and "yaw", from the keys in Moves; each with its weight) and all through (steady: his eyes on
	# the ball, not folding over the net).
	var peak := 0.0
	for p in frames:
		peak = maxf(peak, float(p.y))
	var layer: Dictionary = spec.get("layer", {})
	var steady: Dictionary = spec.get("steady", {})
	for i in frames.size():
		var p: Dictionary = frames[i]
		var air := smoothstep(0.15, 0.6, float(p.y) / maxf(peak, 0.001))
		if spec.has("lift_to") and peak > 0.0:
			# (The first 2 cm off the floor are the subject's feet rolling, not a jump: on the floor.)
			p.y = maxf(0.0, float(p.y) - 0.02) * float(spec.lift_to) / (peak - 0.02)
		if not layer.is_empty() or not steady.is_empty():
			var drawn := Moves.drawn(move, float(i) / float(frames.size() - 1))
			p["yaw"] = 0.0
			for key in layer.keys() + steady.keys():
				var k := 1.0 - (1.0 - air * float(layer.get(key, 0.0))) * (1.0 - float(steady.get(key, 0.0)))
				var one := Moves.blend({key: p[key]}, {key: drawn[key]}, k)
				p[key] = one[key]
	var out := []
	for i in frames.size():
		var p: Dictionary = frames[i]
		if bool(spec.mirror):
			p = Moves.mirrored(p)
		var f := float(i) / float(frames.size() - 1)
		# (A jump's dip and landing settle in and out of the ready stance over longer, so the feet don't slide:
		# blend_in, blend_out.)
		var w := minf(smoothstep(0.0, float(spec.get("blend_in", BLEND_IN)), f), 1.0 - smoothstep(1.0 - float(spec.get("blend_out", BLEND_OUT)), 1.0, f))
		out.append(Moves.blend(Moves.READY, p, w))
	if String(spec.get("root", "")) == "feet":
		for p in out:
			p["plant"] = 1.0   # RealBody keeps a foot on the floor while he is on it (the subject's legs aren't his)
		_lock_feet(out)
	elif String(spec.get("lock", "")) == "support":
		for p in out:
			p["plant"] = 1.0
		_lock_support(out)
	return out


## Feet locked to the floor, on the players' own model: while both are down, the hips are moved so the feet stay where
## they stood at the start (its legs aren't the subject's, so the subject's planted feet move a little on it); in the
## air the correction carries over from take-off to landing.
func _lock_feet(frames: Array) -> void:
	var man := RealBody.rig(false)
	var fix := []
	var start := Vector2.ZERO
	for i in frames.size():
		var p: Dictionary = frames[i]
		man.solve(p)
		var yaw := deg_to_rad(float(p.get("yaw", 0.0)))
		var l := man.sole("Left").rotated(Vector3.UP, yaw)
		var r := man.sole("Right").rotated(Vector3.UP, yaw)
		var mid := Vector2(l.x + r.x, l.z + r.z) * 0.5
		if i == 0:
			start = mid
		var down := maxf(l.y, r.y) + float(p.get("y", 0.0)) < RealBody.SOLE_DOWN
		fix.append(start - mid if down else null)
	var last: Vector2 = Vector2.ZERO
	for i in fix.size():
		if fix[i] == null:
			var j := i
			while j < fix.size() and fix[j] == null:
				j += 1
			var nxt: Vector2 = fix[j] if j < fix.size() else last
			fix[i] = last.lerp(nxt, 1.0 / float(j - i + 1))
		last = fix[i]
		frames[i].hips_fwd = float(frames[i].get("hips_fwd", 0.0)) + (fix[i] as Vector2).y
		frames[i].hips_side = float(frames[i].get("hips_side", 0.0)) - (fix[i] as Vector2).x


## A kick off one foot, its feet locked to the floor on the players' own model. The hips are moved so the foot he stands
## on stays where it is: the one down (the left, his standing foot, while both are), kept until it leaves the floor;
## through the air the correction is held. The other foot, where it moves along the floor while it is still down (the
## ready stance blending into the kick's and back), is lifted into a step: raised straight up by its hip and knee.
## Where his feet finish is left as the move's travel (Player moves him by it as the move ends).
func _lock_support(frames: Array) -> void:
	var man := RealBody.rig(false)
	var woman := RealBody.rig(true)
	var base := []
	for p in frames:
		base.append((p as Dictionary).duplicate())
	# The foot he stands on, frame by frame (0 left, 1 right, -1 neither), from the kick as it is.
	var locks := []
	var lock := -1
	var low := []   # how high each sole is
	for p in base:
		man.solve(p)
		var down := [false, false]
		var h := Vector2.ZERO
		for k in 2:
			h[k] = man.sole(["Left", "Right"][k]).y + float(p.get("y", 0.0))
			down[k] = h[k] < RealBody.SOLE_DOWN
		low.append(h)
		if lock < 0 or not down[lock]:
			lock = 0 if down[0] else (1 if down[1] else -1)
		locks.append(lock)
	# Landing, the foot is held a frame or two before it is down (it comes to rest as it meets the floor: on the
	# woman's shorter legs it is down sooner).
	for i in range(locks.size() - 1, 0, -1):
		var k := int(locks[i])
		if k >= 0 and int(locks[i - 1]) < 0:
			for j in [i - 1, i - 2]:
				if j > 0 and int(locks[j]) < 0 and float((low[j] as Vector2)[k]) < RealBody.SOLE_DOWN + 0.1:
					locks[j] = k
	var lift := []   # per frame: how far each foot (left, right) is lifted into a step (m)
	lift.resize(frames.size())
	lift.fill(Vector2.ZERO)
	for pass_no in 10:
		_step_and_hold(frames, base, lift, locks, man)
		# The other foot, sliding while it is down: lifted into a step there (and a few frames either side).
		var need := []
		need.resize(frames.size())
		need.fill(Vector2.ZERO)
		var any := false
		for rig in [man, woman]:   # (on both models: the woman's legs are shorter)
			var last := []
			for i in frames.size():
				var p: Dictionary = frames[i]
				rig.solve(p)
				var yaw := deg_to_rad(float(p.get("yaw", 0.0)))
				var now := []
				for k in 2:
					var v: Vector3 = rig.sole(["Left", "Right"][k]).rotated(Vector3.UP, yaw) + Vector3(0, float(p.get("y", 0.0)), 0)
					now.append(v)
					var stood := i > 0 and int(locks[i]) == k and int(locks[i - 1]) == k   # (held there)
					if i > 0 and not stood and v.y < RealBody.SOLE_DOWN and (last[k] as Vector3).y < RealBody.SOLE_DOWN:
						if Vector2(v.x - last[k].x, v.z - last[k].z).length() > 0.012:
							var n: Vector2 = need[i]
							n[k] = 1.0
							need[i] = n
							any = true
				last = now
		if not any:
			break
		for i in range(1, frames.size() - 1):   # (the first and last frames stay the ready stance)
			var w: Vector2 = lift[i]
			for k in 2:
				if int(locks[i]) == k or int(locks[i]) < 0:
					continue   # never the foot he stands on, nor in the air
				var more := 0.0
				for j in range(maxi(0, i - 3), mini(frames.size(), i + 4)):
					more = maxf(more, float((need[j] as Vector2)[k]) * (1.0 - absf(float(j - i)) / 4.0))
				w[k] = minf(STEP_MAX, w[k] + more * STEP)
			lift[i] = w
	_step_and_hold(frames, base, lift, locks, man)
	_debug_feet(frames, lift, woman if OS.get_environment("TAKRAW_DEBUG") == "woman" else man)


func _debug_feet(frames: Array, lift: Array, man: RealBody.Rig) -> void:
	if not OS.has_environment("TAKRAW_DEBUG"):
		return
	for i in frames.size():
		var p: Dictionary = frames[i]
		man.solve(p)
		var yaw := deg_to_rad(float(p.get("yaw", 0.0)))
		var l := man.sole("Left").rotated(Vector3.UP, yaw) + Vector3(0, float(p.get("y", 0.0)), 0)
		var r := man.sole("Right").rotated(Vector3.UP, yaw) + Vector3(0, float(p.get("y", 0.0)), 0)
		print("%2d L %s R %s lift %s hips %.3f %.3f" % [i, l.snappedf(0.001), r.snappedf(0.001), (lift[i] as Vector2).snappedf(0.01), float(p.hips_fwd), float(p.hips_side)])


## frames made from base: each foot lifted into a step as far as lift says, and the hips moved so the foot he stands on
## (locks) stays put.
func _step_and_hold(frames: Array, base: Array, lift: Array, locks: Array, man: RealBody.Rig) -> void:
	for i in frames.size():
		var p: Dictionary = base[i].duplicate()
		for k in 2:
			var h := float((lift[i] as Vector2)[k])
			if h > 0.0:
				_lift_foot(man, p, k, h)
		frames[i] = p
	var anchor := Vector2.ZERO
	var cur := Vector2.ZERO
	for i in frames.size():
		var p: Dictionary = frames[i]
		man.solve(p)
		var yaw := deg_to_rad(float(p.get("yaw", 0.0)))
		var k := int(locks[i])
		if k >= 0:
			var v := man.sole(["Left", "Right"][k]).rotated(Vector3.UP, yaw)
			if i == 0 or int(locks[i - 1]) != k:
				anchor = Vector2(v.x, v.z) + cur
			cur = anchor - Vector2(v.x, v.z)
		var off := Vector3(cur.x, 0, cur.y).rotated(Vector3.UP, -yaw)
		p.hips_fwd = float(base[i].get("hips_fwd", 0.0)) + off.z
		p.hips_side = float(base[i].get("hips_side", 0.0)) - off.x


## The foot k (0 left, 1 right) raised h metres straight up by its hip and knee (the knee bending the way it bends
## now), the foot turned as it was.
func _lift_foot(man: RealBody.Rig, p: Dictionary, k: int, h: float) -> void:
	man.solve(p)
	var side: String = ["Left", "Right"][k]
	var sfx: String = ["_l", "_r"][k]
	var ti := 11 if k == 0 else 14   # thigh_l / thigh_r in RealBody.BONES, the shin and foot after it
	var hip: Vector3 = man.out_pos[man.index[side + "UpLeg"]]
	var knee: Vector3 = man.out_pos[man.index[side + "Leg"]]
	var ankle: Vector3 = man.out_pos[man.index[side + "Foot"]]
	var a := hip.distance_to(knee)
	var b := knee.distance_to(ankle)
	var to := ankle + Vector3(0, h, 0)
	var d := clampf(hip.distance_to(to), absf(a - b) + 0.001, a + b - 0.001)
	var axis := (to - hip).normalized()
	var bend := (knee - hip) - axis * (knee - hip).dot(axis)
	if bend.length() < 0.001:
		bend = Vector3.BACK - axis * axis.z   # (a straight leg: the knee forward)
	bend = bend.normalized()
	var along := (a * a - b * b + d * d) / (2.0 * d)
	var knee2 := hip + axis * along + bend * sqrt(maxf(0.0, a * a - along * along))
	var turn1 := Quaternion((knee - hip).normalized(), (knee2 - hip).normalized())
	var thigh := turn1 * (man._q[ti] as Quaternion)
	var turn2 := Quaternion(turn1 * (ankle - knee).normalized(), (hip + axis * d - knee2).normalized())
	var shin := turn2 * turn1 * (man._q[ti + 1] as Quaternion)
	p["thigh" + sfx] = (man._q[0] as Quaternion).inverse() * thigh
	p["shin" + sfx] = thigh.inverse() * shin
	p["foot" + sfx] = shin.inverse() * (man._q[ti + 2] as Quaternion)


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
				var d := _pos(rest, to) - _pos(rest, nm)
				var further: String = RealBody.RIG.get(to, ["", "", ""])[2]
				if d.length() < 0.001 and _bone.has(further):
					d = _pos(rest, further) - _pos(rest, nm)   # (a CMU skeleton's lower back sits on its hips)
				q = Quaternion(d.normalized(), spec[3])
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
