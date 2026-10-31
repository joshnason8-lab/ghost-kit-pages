extends SceneTree
## Bakes the owner's ActorCore motions (Character Creator rig, CC_Base_* bones, each file with a "0_T-Pose" take)
## onto the World Stage Games rig, as a second library next to Mobility's. LICENSED OUTPUT: addons/.../data only.
##   godot --headless --path <scratch> -s bake_actorcore.gd -- <out dir>
## The scratch project has the clips in src/ (tools/bake_clips.sh puts them there from Actorcore.moves.zip).
## As bake_clips.gd, except: each file's own T-pose take is the reference; there is no in-place twin, so the root's
## path is the hips' path over the ground, smoothed (a loop's drift taken out: it is played in place); loops are
## turned to start as the left foot lands and stretched to one second. Writes <out>/actorcore.res and .json.

const FPS := 30.0
const H0 := 0.98
const LOOP_KEYS := 32
## File (without .fbx) -> [name in the library, kind, start s, end s (0: to the end)].
const CLIPS := {
	"idle_battle_218697": ["Ready_Stance", "loop", 0.0, 0.0],
	"run-together-loop-c1": ["Sprint_F_Loop", "loop", 0.0, 0.0],
	"parkour-swan-dive": ["Dive_Forward", "once", 0.0, 0.0],
	"basketball-passer-670285": ["Pass_Throw", "once", 0.0, 0.0],
	"cheer-victory": ["Celebrate_FistPump", "once", 0.0, 0.0],
	"happy-jump-m": ["Celebrate_Jump", "once", 0.0, 0.0],
	"lose-face-palm": ["Disappointed_HandsOnHead", "once", 0.0, 0.0],
	"sitchair-listening-m-396604": ["Crowd_Sit_Idle", "loop", 0.0, 0.0],
	"stand-to-sit-chair-m-": ["Crowd_Stand_To_Sit", "once", 0.0, 0.0],
	"sit-clap-and-nod02": ["Crowd_Sit_Clap", "once", 0.0, 0.0],
	"clap-nod03": ["Crowd_Stand_Clap", "once", 0.0, 0.0],
	"cheer03-555996": ["Crowd_Cheer", "once", 0.0, 0.0],
	"24-dive-catch-and-pass-the-ball": ["Extra_DiveCatchPass", "once", 0.0, 0.0],
	"badass-fake-shooting-626448": ["Extra_Shoot_Fake", "once", 0.0, 0.0],
	"basketball_shoot": ["Extra_Shoot", "once", 0.0, 0.0],
}
const MAP := {
	"CC_Base_Hip": "Hips", "CC_Base_Waist": "Spine", "CC_Base_Spine01": "Spine1", "CC_Base_Spine02": "Spine2",
	"CC_Base_NeckTwist01": "Neck", "CC_Base_Head": "Head",
	"CC_Base_L_Clavicle": "LeftShoulder", "CC_Base_L_Upperarm": "LeftArm", "CC_Base_L_Forearm": "LeftForeArm",
	"CC_Base_L_Hand": "LeftHand", "CC_Base_R_Clavicle": "RightShoulder", "CC_Base_R_Upperarm": "RightArm",
	"CC_Base_R_Forearm": "RightForeArm", "CC_Base_R_Hand": "RightHand",
	"CC_Base_L_Thigh": "LeftUpLeg", "CC_Base_L_Calf": "LeftLeg", "CC_Base_L_Foot": "LeftFoot", "CC_Base_L_ToeBase": "LeftToeBase",
	"CC_Base_R_Thigh": "RightUpLeg", "CC_Base_R_Calf": "RightLeg", "CC_Base_R_Foot": "RightFoot", "CC_Base_R_ToeBase": "RightToeBase",
}
const DIR_BONES := {"LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "RightArm": "RightForeArm",
	"RightForeArm": "RightHand", "LeftUpLeg": "LeftLeg", "LeftLeg": "LeftFoot", "RightUpLeg": "RightLeg",
	"RightLeg": "RightFoot"}
const CANON_DIR := {"LeftArm": Vector3.RIGHT, "LeftForeArm": Vector3.RIGHT, "RightArm": Vector3.LEFT,
	"RightForeArm": Vector3.LEFT, "LeftUpLeg": Vector3.DOWN, "LeftLeg": Vector3.DOWN, "RightUpLeg": Vector3.DOWN,
	"RightLeg": Vector3.DOWN}

var rig_bones := []
var joints := {}


func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	joints = WsgRig.default_joints()
	for b in WsgRig.BONES:
		if not WsgRig.is_helper(b[0]):
			rig_bones.append(b[0])
	var map := MAP.duplicate()
	for side in [["L", "Left"], ["R", "Right"]]:
		for f in ["Thumb", "Index", "Mid", "Ring", "Pinky"]:
			for k in [1, 2, 3]:
				map["CC_Base_%s_%s%d" % [side[0], f, k]] = "%sHand%s%d" % [side[1], "Middle" if f == "Mid" else f, k]
	var lib := AnimationLibrary.new()
	var meta := {}
	for file in CLIPS:
		var path := "res://src/%s.fbx" % file
		if not ResourceLoader.exists(path):
			print("missing ", file)
			continue
		var spec: Array = CLIPS[file]
		var r := _bake(path, map, spec)
		lib.add_animation(spec[0], r.anim)
		meta[spec[0]] = r.meta
		print("%-26s %-6s %5.2f s  speed %.2f  lift %+.3f  contacts L %d R %d" % [spec[0], spec[1], r.meta.length, r.meta.get("speed", 0.0), r.meta.lift, r.meta.contacts[0].size(), r.meta.contacts[1].size()])
	print(error_string(ResourceSaver.save(lib, out.path_join("actorcore.res"), ResourceSaver.FLAG_COMPRESS)))
	var f := FileAccess.open(out.path_join("actorcore.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"source": "ActorCore (licensed: private)", "fps": FPS, "clips": meta}, "\t"))
	f.close()
	quit()


func _bake(path: String, map: Dictionary, spec: Array) -> Dictionary:
	var scene: Node = load(path).instantiate()
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var tpose: Animation = null
	var an: Animation = null
	for a in ap.get_animation_list():
		if String(a).begins_with("0_T"):
			tpose = ap.get_animation(a)
		else:
			an = ap.get_animation(a)
	# The reference: the T-pose take's first frame (the file's own rest is not always the T).
	var ref := _sample(sk, tpose if tpose else an, 0.0)
	var src_of := {}
	for b in sk.get_bone_count():
		var nm: String = map.get(sk.get_bone_name(b), "")
		if nm != "":
			src_of[nm] = b
	var hips_src: int = src_of["Hips"]
	var h_src: float = ref[hips_src].origin.y
	var k := H0 / h_src
	var align := {}
	for nm in DIR_BONES:
		var ds: Vector3 = (ref[src_of[DIR_BONES[nm]]].origin - ref[src_of[nm]].origin).normalized()
		align[nm] = Quaternion(ds, CANON_DIR[nm]).inverse()
	var t0: float = spec[2]
	var t1: float = spec[3] if spec[3] > 0.0 else an.length
	# The takes were exported starting on a T-pose frame: skip it (and any frame still close to it), plus one.
	var arm: int = src_of.get("LeftArm", -1)
	while t0 < t1 - 0.2 and arm >= 0:
		var g0 := _sample(sk, an, t0)
		var d: float = g0[arm].basis.get_rotation_quaternion().angle_to(ref[arm].basis.get_rotation_quaternion())
		if rad_to_deg(d) > 10.0:
			break
		t0 += 1.0 / FPS
	if t0 > 0.0:
		t0 += 1.0 / FPS
	var n := maxi(1, int(round((t1 - t0) * FPS)))
	var frames := []
	var hips_xz := []
	for f in n + 1:
		var g := _sample(sk, an, minf(t0 + f / FPS, an.length))
		var gt := {}
		var loc := {}
		for nm in rig_bones:
			if not src_of.has(nm):
				continue
			var b: int = src_of[nm]
			var q: Quaternion = g[b].basis.get_rotation_quaternion() * ref[b].basis.get_rotation_quaternion().inverse()
			if align.has(nm):
				q = q * (align[nm] as Quaternion)
			gt[nm] = q.normalized()
		for nm in gt:
			var par := WsgRig.parent_name(nm)
			# A missing parent (none here) would take the nearest one's turn.
			while par != "" and not gt.has(par):
				par = WsgRig.parent_name(par)
			loc[nm] = ((gt[par] as Quaternion).inverse() * gt[nm]).normalized() if par != "" else gt[nm]
		var hp: Vector3 = (g[hips_src].origin - ref[hips_src].origin) * k
		hips_xz.append(Vector2(hp.x, hp.z))
		frames.append([loc, Vector3(0, H0, 0) + hp])
	scene.free()
	# A loop faces forward: its mean facing (a fighting stance stands side-on) is taken out.
	if spec[1] == "loop":
		var ys := 0.0
		for fr in frames:
			var fwd: Vector3 = (fr[0].get("Hips", Quaternion.IDENTITY) as Quaternion) * Vector3.BACK
			ys += atan2(fwd.x, fwd.z)
		var turn := Quaternion(Vector3.UP, -ys / frames.size())
		for i in frames.size():
			frames[i][0]["Hips"] = (turn * (frames[i][0].get("Hips", Quaternion.IDENTITY) as Quaternion)).normalized()
			var hp: Vector3 = (frames[i][1] as Vector3) - Vector3(0, H0, 0)
			frames[i][1] = Vector3(0, H0, 0) + turn * hp
			hips_xz[i] = Vector2((turn * Vector3(hips_xz[i].x, 0, hips_xz[i].y)).x, (turn * Vector3(hips_xz[i].x, 0, hips_xz[i].y)).z)
	# The root: the hips' path over the ground, smoothed over a stride (a loop's straight drift).
	var root := []
	var loop: bool = spec[1] == "loop"
	for f in frames.size():
		var p := Vector2.ZERO
		if loop:
			p = (hips_xz[0] as Vector2).lerp(hips_xz[-1], float(f) / maxf(frames.size() - 1, 1))
		else:
			var c := 0
			for j in range(maxi(0, f - 12), mini(frames.size(), f + 13)):
				p += hips_xz[j]
				c += 1
			p /= c
		root.append(p)
	for f in frames.size():
		var rp: Vector2 = root[f]
		frames[f][1] = (frames[f][1] as Vector3) - Vector3(rp.x, 0, rp.y)
	# Ground it, find the contacts (low and still over the ground).
	var ankle_rest: float = (joints["LeftFoot"] as Vector3).y
	var toe_rest: float = (joints["LeftToeBase"] as Vector3).y
	var feet := []
	var low := INF
	for fr in frames:
		var p := _fk(fr[0], fr[1])
		feet.append([p.LeftFoot, p.LeftToeBase, p.RightFoot, p.RightToeBase])
		low = minf(low, minf(minf(p.LeftFoot.y - ankle_rest, p.LeftToeBase.y - toe_rest), minf(p.RightFoot.y - ankle_rest, p.RightToeBase.y - toe_rest)))
	var lift := -low
	for fr in frames:
		fr[1] = (fr[1] as Vector3) + Vector3(0, lift, 0)
	var contacts := [[], []]
	for f in frames.size():
		for side in 2:
			var a: Vector3 = feet[f][side * 2] + Vector3(0, lift, 0)
			var t: Vector3 = feet[f][side * 2 + 1] + Vector3(0, lift, 0)
			var h := minf(a.y - ankle_rest, t.y - toe_rest)
			var fa := maxi(0, f - 1)
			var fb := mini(frames.size() - 1, f + 1)
			var wa: Vector2 = root[fa] + Vector2(feet[fa][side * 2].x, feet[fa][side * 2].z)
			var wb: Vector2 = root[fb] + Vector2(feet[fb][side * 2].x, feet[fb][side * 2].z)
			var v := wa.distance_to(wb) * FPS / maxf(fb - fa, 1)
			contacts[side].append(h < 0.035 and v < 0.6)
	var dur := (frames.size() - 1) / FPS
	var travel: Vector2 = root[-1] - root[0]
	var m := {"kind": spec[1], "frames": frames.size(), "length": snappedf(dur, 0.001), "lift": snappedf(lift, 0.001),
		"travel": [snappedf(travel.x, 0.001), snappedf(travel.y, 0.001)], "turn": 0.0}
	if loop:
		# Speed from the feet, not the root: a loop exported half in place keeps only some of its travel in the hips,
		# but the foot on the ground sweeps back under the body at the speed it runs. Also how far its facing is off.
		# Each stance: while one foot is the lower and near its lowest, how far it moves back under the hips over
		# that time (the clip played in place, this is the speed the legs run at).
		var yaw_sum := 0.0
		for f in range(frames.size()):
			var fwd: Vector3 = (frames[f][0].get("Hips", Quaternion.IDENTITY) as Quaternion) * Vector3.BACK
			yaw_sum += atan2(fwd.x, fwd.z)
		var speeds := []
		var stances := [[], []]
		for side in 2:
			var lowest := INF
			for f in frames.size():
				lowest = minf(lowest, (feet[f][side * 2] as Vector3).y)
			var start := -1
			for f in frames.size() + 1:
				var down := false
				if f < frames.size():
					var a: Vector3 = feet[f][side * 2]
					var o: Vector3 = feet[f][(1 - side) * 2]
					down = a.y < lowest + 0.04 and a.y <= o.y
				if down and start < 0:
					start = f
				elif not down and start >= 0:
					stances[side].append([start, f - 1])
					if f - 1 - start >= 2:
						var pa: Vector3 = feet[start][side * 2]
						var pb: Vector3 = feet[f - 1][side * 2]
						speeds.append(Vector2(pa.x - pb.x, pa.z - pb.z) * FPS / float(f - 1 - start))
					start = -1
		var run := Vector2.ZERO
		for v: Vector2 in speeds:
			run += v
		run /= maxf(speeds.size(), 1)
		m.root_speed = snappedf(travel.length() / maxf(dur, 0.01), 0.001)
		m.facing_off = snappedf(rad_to_deg(yaw_sum / frames.size()), 0.1)
		print("   loop %s: root %.2f m/s; the stance feet sweep back at %.2f m/s heading %.0f deg (%d stances)" % [spec[0], m.root_speed, run.length(), rad_to_deg(atan2(run.x, run.y)), speeds.size()])
		m.sweep_speed = snappedf(run.length(), 0.001)
		# The legs' speed: the stance sweep (what the in-place loop shows); SPRINT_ROOT=1 takes the root's instead.
		# The sprint is the exception: exported half in place, its feet sweep slower under the hips than its root goes;
		# played at its root's speed its planted feet slide least (tests/loco_test.gd: 31 cm/s against 40 at its feet's speed).
		var use_root: bool = spec[0] == "Sprint_F_Loop"
		# (Its stride a fifth longer again measured better still: 30.9 cm/s; it makes it 6.8 m/s, above the run.)
		var k_env := float(OS.get_environment("SPRINT_K")) if OS.has_environment("SPRINT_K") else 1.2
		travel = Vector2(0, 1) * (m.root_speed * k_env if use_root else run.length()) * dur
		m.speed = snappedf(travel.length() / maxf(dur, 0.01), 0.001)
		# Contacts from the stances found by height (the root of a half-in-place export is no guide).
		for side in 2:
			for i in contacts[side].size():
				contacts[side][i] = false
			for st: Array in stances[side]:
				for f in range(st[0], st[1] + 1):
					contacts[side][f] = true
		m.dir = snappedf(rad_to_deg(atan2(travel.x, travel.y)), 0.1) if travel.length() > 0.05 else 0.0
		m.cycle = snappedf(dur, 0.001)
		m.stride = snappedf(travel.length(), 0.001)
		m.turn_rate = 0.0
		var nl: int = frames.size() - 1
		var start := 0
		for f in nl:
			if contacts[0][f] and not contacts[0][(f - 1 + nl) % nl]:
				start = f
				break
		var c2 := [[], []]
		for side in 2:
			for i in nl:
				c2[side].append(contacts[side][(start + i) % nl])
		m.contacts = [_ranges(c2[0]), _ranges(c2[1])]
		return {"anim": _loop_anim(frames, start, nl), "meta": m}
	m.contacts = [_ranges(contacts[0]), _ranges(contacts[1])]
	var path_out := []
	for p: Vector2 in root:
		path_out.append([snappedf(p.x - root[0].x, 0.001), snappedf(p.y - root[0].y, 0.001), 0.0])
	m.root = path_out
	return {"anim": _once_anim(frames), "meta": m}


static func _sample(sk: Skeleton3D, an: Animation, t: float) -> Array:
	var tr := {}
	for i in an.get_track_count():
		var bn := String(an.track_get_path(i).get_concatenated_subnames())
		if not tr.has(bn):
			tr[bn] = [-1, -1]
		if an.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			tr[bn][0] = i
		elif an.track_get_type(i) == Animation.TYPE_POSITION_3D:
			tr[bn][1] = i
	var g := []
	for b in sk.get_bone_count():
		var r := sk.get_bone_rest(b)
		var q := r.basis.get_rotation_quaternion()
		var o := r.origin
		var nm := sk.get_bone_name(b)
		if tr.has(nm):
			if tr[nm][0] >= 0:
				q = an.rotation_track_interpolate(tr[nm][0], t)
			if tr[nm][1] >= 0:
				o = an.position_track_interpolate(tr[nm][1], t)
		var local := Transform3D(Basis(q), o)
		var par := sk.get_bone_parent(b)
		g.append(g[par] * local if par >= 0 else local)
	return g


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


func _loop_anim(frames: Array, start: int, nl: int) -> Animation:
	var anim := Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_LINEAR
	var t := _tracks_for(anim)
	for kk in LOOP_KEYS + 1:
		var x := float(kk) / LOOP_KEYS * nl + start
		var i := int(floor(x))
		var w := x - i
		var fa: Array = frames[i % nl]
		var fb: Array = frames[(i + 1) % nl]
		for nm in rig_bones:
			var qa: Quaternion = fa[0].get(nm, Quaternion.IDENTITY)
			var qb: Quaternion = fb[0].get(nm, Quaternion.IDENTITY)
			anim.rotation_track_insert_key(t[nm], float(kk) / LOOP_KEYS, qa.slerp(qb, w))
		anim.position_track_insert_key(t["@hips"], float(kk) / LOOP_KEYS, (fa[1] as Vector3).lerp(fb[1], w))
	return anim


func _once_anim(frames: Array) -> Animation:
	var anim := Animation.new()
	anim.length = maxf(1.0 / FPS, (frames.size() - 1) / FPS)
	var t := _tracks_for(anim)
	for f in frames.size():
		for nm in rig_bones:
			anim.rotation_track_insert_key(t[nm], f / FPS, frames[f][0].get(nm, Quaternion.IDENTITY))
		anim.position_track_insert_key(t["@hips"], f / FPS, frames[f][1])
	return anim
