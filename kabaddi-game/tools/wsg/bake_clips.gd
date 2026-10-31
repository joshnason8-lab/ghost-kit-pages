extends SceneTree
## Bakes motion-capture clips (MoCap Online "Mobility", HumanIK names; later ActorCore) onto the World Stage Games rig
## as one AnimationLibrary plus what the locomotion needs to know about each clip. LICENSED OUTPUT: it goes to
## addons/wsg_foundation/data/ (ignored by git) and from there only into built APKs. Never commit or publish it.
##
##   godot --headless --path <scratch> -s bake_clips.gd -- <out dir>
## The scratch project holds the clips imported by Godot: src/ipc/*.fbx (in place), src/rm/*.fbx (with root motion),
## src/aim/*.fbx (aim offsets), src/ref/MotusMan_v55.fbx (the pack's character: its bind pose is the T-pose every clip
## is measured from). tools/bake_clips.sh sets that up from the release zip.
##
## For each clip:
##   1. every frame (30 a second) retargeted onto the canonical rig: the long bones of the arms and legs by the way
##      they point (so a source whose legs splay a little in its rest still plants straight), every other bone by its
##      turn from the source's rest; the hips' height in proportion to the source's hip height (WsgRig's 0.98 m;
##      a character's own comes from Skeleton3D.motion_scale);
##   2. grounded: the hips lowered or raised by one amount for the whole clip so its lowest foot is exactly on the
##      ground (some sources float);
##   3. its root's path and turn, from the root-motion twin of the in-place clip (root = that clip's hips x the
##      in-place hips' inverse, flattened): speed, direction of travel, turn;
##   4. each foot's contacts: low and still in the world (the root's motion added back);
##   5. a loop is turned to start as the left foot lands and stretched to exactly one second, so every gait cycle
##      blends phase-matched with every other; its natural length and stride are kept in the metadata.
## Writes <out>/mobility.res (AnimationLibrary) and <out>/mobility.json (the metadata).

const FPS := 30.0
const H0 := 0.98            # the canonical hips' height (WsgRig "Hips")
const LOOP_KEYS := 32       # keys a loop gets over its one second
const DIR_BONES := {"LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "RightArm": "RightForeArm",
	"RightForeArm": "RightHand", "LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "RightUpLeg": "RightLeg",
	"RightLeg": "RightFoot"}
const CANON_DIR := {"LeftArm": Vector3.RIGHT, "LeftForeArm": Vector3.RIGHT, "RightArm": Vector3.LEFT,
	"RightForeArm": Vector3.LEFT, "LeftUpLeg": Vector3.DOWN, "LeftLeg": Vector3.DOWN, "RightUpLeg": Vector3.DOWN,
	"RightLeg": Vector3.DOWN}

var rig_bones := []          # canonical bones that clips drive (not the helpers)
var joints := {}             # default canonical joints, for the analysis
var meta := {}
var report := []
var ref: Skeleton3D          # the source's true T-pose (the pack's own character, MotusMan): every clip is measured
                             # from it; a clip file's own "rest" is not a T-pose and differs from clip to clip
var ref_scene: Node


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	joints = WsgRig.default_joints()
	for b in WsgRig.BONES:
		if not WsgRig.is_helper(b[0]):
			rig_bones.append(b[0])
	ref_scene = load("res://src/ref/MotusMan_v55.fbx").instantiate()
	ref = ref_scene.find_children("*", "Skeleton3D", true, false)[0]
	var lib := AnimationLibrary.new()
	var clips := _select()
	for name in clips:
		var c: Array = clips[name]
		var r := _bake(name, c[0], c[1], c[2])
		if r.is_empty():
			continue
		lib.add_animation(name, r.anim)
		meta[name] = r.meta
	print(error_string(ResourceSaver.save(lib, out.path_join("mobility.res"), ResourceSaver.FLAG_COMPRESS)), " ", lib.get_animation_list().size(), " clips")
	var f := FileAccess.open(out.path_join("mobility.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"source": "MoCap Online Mobility 27B Pro (licensed: private)", "fps": FPS, "clips": meta}, "\t"))
	f.close()
	for l in report:
		print(l)
	quit()


## The clips the locomotion, the officials and the crowd use: name -> [in-place file, root-motion file or "", kind].
func _select() -> Dictionary:
	var out := {}
	var ipc := DirAccess.get_files_at("res://src/ipc")
	for file: String in ipc:
		if not file.ends_with(".fbx"):
			continue
		# A few non-IPC copies sit among the in-place clips: take the _IPC one where both exist.
		if not file.ends_with("_IPC.fbx") and ipc.has(file.trim_suffix(".fbx") + "_IPC.fbx"):
			continue
		var name := file.trim_prefix("MOB1_").trim_suffix(".fbx").trim_suffix("_IPC").replace("_ Air", "_Air")
		var jump_part := name.contains("_Start") or name.contains("_Air") or name.contains("_Land")
		if name.begins_with("Crouch") or name.contains("Death") or name.ends_with("_Jump") \
				or (name.contains("Jump_LU") or name.contains("Jump_RU")) and not jump_part:
			continue
		var rm_path := ""
		for cand in ["MOB1_" + name + ".fbx", "MOB1_" + name.replace("_Air", "_ Air") + ".fbx"]:
			if FileAccess.file_exists("res://src/rm/" + cand):
				rm_path = "res://src/rm/" + cand
		var kind := "loop" if name.ends_with("_Loop") or name in ["Stand_Relaxed_Idle", "Stand_Relaxed_Idle_v2"] else "once"
		out[name] = ["res://src/ipc/" + file, rm_path, kind]
	for file: String in DirAccess.get_files_at("res://src/aim"):
		if file.ends_with(".fbx") and file.begins_with("MOB1_Stand"):
			out[file.trim_prefix("MOB1_").trim_suffix(".fbx")] = ["res://src/aim/" + file, "", "pose"]
	return out


## Every bone's transform (skeleton space) at time t: the clip's tracks, the rest elsewhere.
func _sample(sk: Skeleton3D, an: Animation, tracks: Dictionary, t: float) -> Array:
	var g := []
	for b in sk.get_bone_count():
		var nm := sk.get_bone_name(b)
		var rb := ref.find_bone(nm)
		var r := ref.get_bone_rest(rb) if rb >= 0 else sk.get_bone_rest(b)
		var q := r.basis.get_rotation_quaternion()
		var o := r.origin
		if tracks.has(nm):
			var tr: Array = tracks[nm]
			if tr[0] >= 0:
				q = an.rotation_track_interpolate(tr[0], t)
			if tr[1] >= 0:
				o = an.position_track_interpolate(tr[1], t)
		var local := Transform3D(Basis(q), o)
		var par := sk.get_bone_parent(b)
		g.append(g[par] * local if par >= 0 else local)
	return g


static func _tracks(an: Animation) -> Dictionary:
	var t := {}
	for i in an.get_track_count():
		var bn := String(an.track_get_path(i).get_concatenated_subnames())
		if not t.has(bn):
			t[bn] = [-1, -1]
		if an.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			t[bn][0] = i
		elif an.track_get_type(i) == Animation.TYPE_POSITION_3D:
			t[bn][1] = i
	return t


static func _load(path: String) -> Array:
	var scene: Node = load(path).instantiate()
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var an := ap.get_animation(ap.get_animation_list()[0])
	return [scene, sk, an]


## Flattened (yaw and ground-plane position only) transform.
static func _flat(t: Transform3D) -> Transform3D:
	var fwd := t.basis * Vector3.BACK
	var yaw := atan2(fwd.x, fwd.z)
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(t.origin.x, 0, t.origin.z))


func _bake(name: String, ipc_path: String, rm_path: String, kind: String) -> Dictionary:
	var a := _load(ipc_path)
	var sk: Skeleton3D = a[1]
	var an: Animation = a[2]
	var tracks := _tracks(an)
	var n := maxi(1, int(round(an.length * FPS)))
	# The source's rest, and how its long bones point there.
	var rest_g := []
	for b in sk.get_bone_count():
		var rb := ref.find_bone(sk.get_bone_name(b))
		rest_g.append(ref.get_bone_global_rest(rb) if rb >= 0 else sk.get_bone_global_rest(b))
	var src_of := {}
	for nm in rig_bones:
		src_of[nm] = sk.find_bone(nm)
	var hips_src := sk.find_bone("Hips")
	var h_src: float = rest_g[hips_src].origin.y
	var k := H0 / h_src
	var align := {}
	for nm in DIR_BONES:
		var b: int = src_of[nm]
		var c := sk.find_bone(DIR_BONES[nm])
		var ds: Vector3 = (rest_g[c].origin - rest_g[b].origin).normalized()
		align[nm] = Quaternion(ds, CANON_DIR[nm]).inverse()
	var rest_q := {}
	for nm in rig_bones:
		if src_of[nm] >= 0:
			rest_q[nm] = rest_g[src_of[nm]].basis.get_rotation_quaternion()
	# Root motion from the twin clip.
	var rm_frames := []
	if rm_path != "":
		var r := _load(rm_path)
		var rsk: Skeleton3D = r[1]
		var ran: Animation = r[2]
		var rtr := _tracks(ran)
		var rh := rsk.find_bone("Hips")
		for f in n + 1:
			var t := minf(f / FPS, ran.length)
			rm_frames.append(_sample(rsk, ran, rtr, t)[rh])
		r[0].free()
	# Retarget every frame.
	var frames := []     # [{bone: local Quaternion}, hips local position (canonical), root Transform3D]
	var root0 := Transform3D.IDENTITY
	for f in n + 1:
		var t := minf(f / FPS, an.length)
		var g := _sample(sk, an, tracks, t)
		var gt := {}
		var loc := {}
		for nm in rig_bones:
			var b: int = src_of[nm]
			if b < 0:
				continue
			var q: Quaternion = g[b].basis.get_rotation_quaternion() * (rest_q[nm] as Quaternion).inverse()
			if align.has(nm):
				q = q * (align[nm] as Quaternion)
			gt[nm] = q.normalized()
		for nm in gt:
			var par := WsgRig.parent_name(nm)
			loc[nm] = ((gt[par] as Quaternion).inverse() * gt[nm]).normalized() if par != "" and gt.has(par) else gt[nm]
		var hp: Vector3 = g[hips_src].origin
		var hips: Vector3 = Vector3(0, H0, 0) + (hp - rest_g[hips_src].origin) * k
		var root := Transform3D.IDENTITY
		if not rm_frames.is_empty():
			var rmh: Transform3D = rm_frames[f]
			root = _flat(rmh * g[hips_src].affine_inverse())
			if f == 0:
				root0 = root.affine_inverse()
			root = root0 * root
			root.origin *= k
		frames.append([loc, hips, root])
	a[0].free()
	# Feet on the canonical skeleton: ground the clip, find the contacts.
	var ankle_rest: float = (joints["LeftFoot"] as Vector3).y
	var toe_rest: float = (joints["LeftToeBase"] as Vector3).y
	var feet := []        # per frame: [left ankle, left toe, right ankle, right toe] (model space, before grounding)
	var low := INF
	for fr in frames:
		var p := _fk(fr[0], fr[1])
		feet.append([p.LeftFoot, p.LeftToeBase, p.RightFoot, p.RightToeBase])
		low = minf(low, minf(minf(p.LeftFoot.y - ankle_rest, p.LeftToeBase.y - toe_rest), minf(p.RightFoot.y - ankle_rest, p.RightToeBase.y - toe_rest)))
	var lift := -low
	if kind == "pose":
		lift = 0.0
	for fr in frames:
		fr[1] = fr[1] + Vector3(0, lift, 0)
	var contacts := [[], []]
	for f in frames.size():
		for side in 2:
			var ank: Vector3 = feet[f][side * 2] + Vector3(0, lift, 0)
			var toe: Vector3 = feet[f][side * 2 + 1] + Vector3(0, lift, 0)
			var height := minf(ank.y - ankle_rest, toe.y - toe_rest)
			var fp := (frames[f][2] as Transform3D) * ((ank + toe) * 0.5)
			var fq: Vector3 = (frames[maxi(0, f - 1)][2] as Transform3D) * ((feet[maxi(0, f - 1)][side * 2] + feet[maxi(0, f - 1)][side * 2 + 1]) * 0.5 + Vector3(0, lift, 0))
			var fn: Vector3 = (frames[mini(frames.size() - 1, f + 1)][2] as Transform3D) * ((feet[mini(frames.size() - 1, f + 1)][side * 2] + feet[mini(frames.size() - 1, f + 1)][side * 2 + 1]) * 0.5 + Vector3(0, lift, 0))
			var vel := Vector2(fn.x - fq.x, fn.z - fq.z).length() * FPS / maxf(1, (mini(frames.size() - 1, f + 1) - maxi(0, f - 1)))
			contacts[side].append(height < 0.035 and (vel < 0.45 or rm_frames.is_empty() and height < 0.02))
	# Travel: over the clip (for a loop, its speed and direction).
	var last: Transform3D = frames[-1][2]
	var dur := an.length
	var travel := Vector2(last.origin.x, last.origin.z)
	var turn := rad_to_deg(atan2((last.basis * Vector3.BACK).x, (last.basis * Vector3.BACK).z))
	var m := {"kind": kind, "frames": frames.size(), "length": snappedf(dur, 0.001), "lift": snappedf(lift, 0.001),
		"travel": [snappedf(travel.x, 0.001), snappedf(travel.y, 0.001)], "turn": snappedf(turn, 0.1)}
	if kind == "loop":
		m.speed = snappedf(travel.length() / dur, 0.001)
		m.dir = snappedf(rad_to_deg(atan2(travel.x, travel.y)), 0.1) if travel.length() > 0.05 else 0.0
		m.cycle = snappedf(dur, 0.001)
		m.stride = snappedf(travel.length(), 0.001)
		m.turn_rate = snappedf(turn / dur, 0.1)
		# Start where the left foot lands (the first frame of a left contact after a frame off the ground).
		var start := 0
		var nl: int = contacts[0].size() - 1   # the last frame repeats the first in a loop
		for f in nl:
			if contacts[0][f] and not contacts[0][(f - 1 + nl) % nl]:
				start = f
				break
		m.phase_shift = snappedf(float(start) / nl, 0.001)
		var c2 := [[], []]
		for side in 2:
			for i in nl:
				c2[side].append(contacts[side][(start + i) % nl])
		m.contacts = [_ranges(c2[0]), _ranges(c2[1])]
		var anim := _loop_anim(frames, start, nl)
		return {"anim": anim, "meta": m}
	m.contacts = [_ranges(contacts[0]), _ranges(contacts[1])]
	# The root's path (every frame: x, z, yaw degrees), for the game to follow or to measure against.
	var path := []
	for fr in frames:
		var rt: Transform3D = fr[2]
		var fwd := rt.basis * Vector3.BACK
		path.append([snappedf(rt.origin.x, 0.001), snappedf(rt.origin.z, 0.001), snappedf(rad_to_deg(atan2(fwd.x, fwd.z)), 0.1)])
	m.root = path
	return {"anim": _once_anim(frames, kind == "pose"), "meta": m}


## Contact flags (one per frame or key) as [start, end] fractions of the clip.
static func _ranges(flags: Array) -> Array:
	var out := []
	var n := flags.size()
	var i := 0
	while i < n:
		if flags[i]:
			var j := i
			while j + 1 < n and flags[j + 1]:
				j += 1
			out.append([snappedf(float(i) / n, 0.001), snappedf(float(j + 1) / n, 0.001)])
			i = j + 1
		else:
			i += 1
	return out


## Canonical joint positions (model space) for a frame's local turns and hips position.
func _fk(loc: Dictionary, hips: Vector3) -> Dictionary:
	var g := {}
	var p := {}
	for b in WsgRig.BONES:
		var nm: String = b[0]
		if WsgRig.is_helper(nm):
			continue
		var q: Quaternion = loc.get(nm, Quaternion.IDENTITY)
		if b[1] == "":
			g[nm] = q
			p[nm] = hips
		else:
			g[nm] = (g[b[1]] as Quaternion) * q
			p[nm] = (p[b[1]] as Vector3) + (g[b[1]] as Quaternion) * ((joints[nm] as Vector3) - (joints[b[1]] as Vector3))
	return p


func _new_anim(length: float, loop: bool) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return anim


func _tracks_for(anim: Animation) -> Dictionary:
	var t := {}
	for nm in rig_bones:
		var i := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(i, NodePath("Skeleton3D:" + nm))
		t[nm] = i
	var h := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(h, NodePath("Skeleton3D:Hips"))
	t["@hips"] = h
	return t


## A loop: from the left foot's landing, stretched to one second, LOOP_KEYS keys (the last equals the first).
func _loop_anim(frames: Array, start: int, nl: int) -> Animation:
	var anim := _new_anim(1.0, true)
	var t := _tracks_for(anim)
	for kk in LOOP_KEYS + 1:
		var x := float(kk) / LOOP_KEYS * nl + start
		var i := int(floor(x))
		var w := x - i
		var fa: Array = frames[i % nl]
		var fb: Array = frames[(i + 1) % nl]
		var time := float(kk) / LOOP_KEYS
		for nm in rig_bones:
			var qa: Quaternion = fa[0].get(nm, Quaternion.IDENTITY)
			var qb: Quaternion = fb[0].get(nm, Quaternion.IDENTITY)
			anim.rotation_track_insert_key(t[nm], time, qa.slerp(qb, w))
		anim.position_track_insert_key(t["@hips"], time, (fa[1] as Vector3).lerp(fb[1], w))
	return anim


func _once_anim(frames: Array, pose: bool) -> Animation:
	var anim := _new_anim(maxf(1.0 / FPS, (frames.size() - 1) / FPS), false)
	var t := _tracks_for(anim)
	for f in frames.size():
		if pose and f > 0:
			break
		var time := f / FPS
		for nm in rig_bones:
			anim.rotation_track_insert_key(t[nm], time, frames[f][0].get(nm, Quaternion.IDENTITY))
		anim.position_track_insert_key(t["@hips"], time, frames[f][1])
	return anim
