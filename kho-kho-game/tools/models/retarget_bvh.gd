extends SceneTree
## Clips from the CMU motion capture library onto the player model, baked as compressed Animation resources the game
## plays (assets/models/anims/). Their input is tools/models/bvh_to_json.py's: each bone's world rotation in the BVH
## skeleton, frame by frame, the clip's travel over the ground already taken out (the root, kept in the metadata).
##
## As in tools/models/retarget.gd, a rotation is not copied straight across: the player's rig is first put into the
## BVH skeleton's rest pose (a T-pose), bone by bone from the hips out, each bone swung to point where the same stretch
## of body points in the BVH skeleton. Every BVH joint rests unturned, so a frame's player bone is the BVH joint's world
## rotation times that T-posed bone. The hips' position is scaled by the two legs' lengths.
##
## Then the feet: the player's legs are not the actor's, so a foot the actor planted drifts a little on the model.
## Each foot's contacts with the ground (low and nearly still, with the clip's root moving under it) are found, and
## through each one the foot is held where it landed: the hip and knee are turned (two-bone IK, the knee kept in its
## own plane) so the ankle reaches the held spot, the foot keeping its own angle. Last, the whole clip is set down so
## its planted toes stand on the floor.
##
##   godot --headless --path . -s res://tools/models/retarget_bvh.gd -- JSON_DIR OUT_DIR

const TARGET := "res://assets/models/player.glb"
const TRACK_ROOT := "target_character/Skeleton3D"
const AIM := {"Hips": "Spine", "Spine2": "Neck", "Neck": "Head"}
const CONTACT_UP := 3.0       # cm above the planted toe's height: still on the ground
const CONTACT_SPEED := 80.0   # cm/s over the ground: still planted

var tgt: Skeleton3D
var n_bones := 0


func _init() -> void:
	_go.call_deferred()


func _go() -> void:
	var args := OS.get_cmdline_user_args()
	var src_dir: String = args[0]
	var out_dir: String = args[1] if args.size() > 1 else "res://assets/models/anims"
	var root_node: Node = (load(TARGET) as PackedScene).instantiate()
	root.add_child(root_node)
	tgt = root_node.find_children("*", "Skeleton3D", true, false)[0]
	n_bones = tgt.get_bone_count()
	for f in DirAccess.get_files_at(src_dir):
		if f.ends_with(".json"):
			_bake(f.get_basename(), JSON.parse_string(FileAccess.get_file_as_string(src_dir.path_join(f))), out_dir)
	quit()


func _short(i: int) -> String:
	return tgt.get_bone_name(i).trim_prefix("mixamorig_")


func _bone(short: String) -> int:
	return tgt.find_bone("mixamorig_" + short)


func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func _swing(a: Vector3, b: Vector3) -> Basis:
	var axis := a.cross(b)
	var s := axis.length()
	var c := a.dot(b)
	if s < 1e-6:
		return Basis.IDENTITY if c > 0.0 else Basis(Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT, PI)
	return Basis(axis / s, atan2(s, c))


func _aim_child(i: int) -> int:
	var kids := tgt.get_bone_children(i)
	var want: String = AIM.get(_short(i), "")
	for k in kids:
		if want != "" and _short(k) == want:
			return k
	return kids[0] if kids.size() == 1 else -1


## The player's rig in the BVH skeleton's rest pose: each bone's world basis.
func _tpose(rest: Dictionary) -> Array:
	var aim: Dictionary = rest.aim
	var g := []
	g.resize(n_bones)
	for i in n_bones:
		var p := tgt.get_bone_parent(i)
		var world: Basis = (g[p] as Basis) * tgt.get_bone_rest(i).basis.orthonormalized() if p >= 0 else tgt.get_bone_global_rest(i).basis.orthonormalized()
		var c := _aim_child(i)
		if aim.has(_short(i)) and c >= 0:
			var have := (world * tgt.get_bone_rest(c).origin).normalized()
			var want := _v(aim[_short(i)]).normalized()
			world = _swing(have, want) * world
			if p < 0:
				# The hips: also turned about the spine so the legs lie across as the BVH skeleton's do.
				var across := (world * (tgt.get_bone_rest(_bone("LeftUpLeg")).origin - tgt.get_bone_rest(_bone("RightUpLeg")).origin)).normalized()
				var s_across := _v(rest.across).normalized()
				var a1 := (across - want * across.dot(want)).normalized()
				var a2 := (s_across - want * s_across.dot(want)).normalized()
				world = Basis(want, atan2(want.dot(a1.cross(a2)), a1.dot(a2))) * world
		g[i] = world.orthonormalized()
	return g


## Bone transforms in the skeleton's space (cm) from local rotations and the hips' position.
func _fk(local: Array, hips: Vector3) -> Array:
	var g := []
	g.resize(n_bones)
	for i in n_bones:
		var p := tgt.get_bone_parent(i)
		if p < 0:
			g[i] = Transform3D(local[i], hips)
		else:
			g[i] = (g[p] as Transform3D) * Transform3D(local[i], tgt.get_bone_rest(i).origin)
	return g


## Where a point in the skeleton's space is on the ground at frame f, the clip's root moving it.
func _world(root: Vector3, p: Vector3) -> Vector3:
	return Vector3(root.x, 0, root.y) + Basis(Vector3.UP, root.z) * p


func _bake(name: String, clip: Dictionary, out_dir: String) -> void:
	var rest: Dictionary = clip.rest
	var fps := float(clip.fps)
	var frames: Array = clip.frames
	var n := frames.size()
	var tp := _tpose(rest)
	var leg := (tgt.get_bone_global_rest(_bone("LeftLeg")).origin - tgt.get_bone_global_rest(_bone("LeftUpLeg")).origin).length() \
		+ (tgt.get_bone_global_rest(_bone("LeftFoot")).origin - tgt.get_bone_global_rest(_bone("LeftLeg")).origin).length()
	var ratio := leg / (float(rest.leg) * 100.0)   # the model's leg (cm) over the actor's (cm)
	var mapped := []
	for i in n_bones:
		if (frames[0].rot as Dictionary).has(_short(i)):
			mapped.append(i)
	# Local rotations and hips, frame by frame; the root (x, z in cm on the model's scale, heading).
	var locals := []
	var hips := []
	var roots := []
	for fr in frames:
		var world := []
		world.resize(n_bones)
		var loc := []
		loc.resize(n_bones)
		for i in n_bones:
			var p := tgt.get_bone_parent(i)
			if (fr.rot as Dictionary).has(_short(i)):
				var q: Array = fr.rot[_short(i)]
				world[i] = (Basis(Quaternion(q[0], q[1], q[2], q[3])) * (tp[i] as Basis)).orthonormalized()
			else:
				world[i] = (world[p] as Basis) * tgt.get_bone_rest(i).basis if p >= 0 else tgt.get_bone_global_rest(i).basis
			loc[i] = (world[p] as Basis).inverse() * (world[i] as Basis) if p >= 0 else world[i]
		locals.append(loc)
		hips.append(_v(fr.hips) * 100.0 * ratio)
		roots.append(Vector3(fr.root[0] * 100.0 * ratio, fr.root[1] * 100.0 * ratio, fr.root[2]))
	# Set down: the planted toes (the lowest tenth of the frames) at the toes' resting height.
	var toes := [_bone("LeftToeBase"), _bone("RightToeBase")]
	var lows := []
	for f in n:
		var g := _fk(locals[f], hips[f])
		lows.append(minf((g[toes[0]] as Transform3D).origin.y, (g[toes[1]] as Transform3D).origin.y))
	var sorted_lows := lows.duplicate()
	sorted_lows.sort()
	var drop: float = tgt.get_bone_global_rest(toes[0]).origin.y - float(sorted_lows[int(n * 0.1)])
	for f in n:
		hips[f] = (hips[f] as Vector3) + Vector3(0, drop, 0)
	var floor_y: float = tgt.get_bone_global_rest(toes[0]).origin.y
	# Foot locks, each side.
	var before := 0.0
	var after := 0.0
	for side in ["Left", "Right"]:
		var toe := _bone(side + "ToeBase")
		var up := _bone(side + "UpLeg")
		var knee := _bone(side + "Leg")
		var foot := _bone(side + "Foot")
		var w_pos := []
		for f in n:
			w_pos.append(_world(roots[f], ((_fk(locals[f], hips[f])[toe]) as Transform3D).origin))
		var planted := []
		for f in n:
			var a := maxi(f - 1, 0)
			var b := mini(f + 1, n - 1)
			var dv := (w_pos[b] as Vector3) - (w_pos[a] as Vector3)
			var spd := Vector2(dv.x, dv.z).length() * fps / maxf(b - a, 1)
			planted.append((w_pos[f] as Vector3).y < floor_y + CONTACT_UP and spd < CONTACT_SPEED)
		var f0 := 0
		while f0 < n:
			if not planted[f0]:
				f0 += 1
				continue
			var f1 := f0
			while f1 + 1 < n and planted[f1 + 1]:
				f1 += 1
			if f1 > f0:
				# Held where it is slowest, on the floor.
				var hold: Vector3 = w_pos[f0]
				var slow := INF
				for f in range(f0, f1 + 1):
					var dv := (w_pos[mini(f + 1, n - 1)] as Vector3) - (w_pos[maxi(f - 1, 0)] as Vector3)
					if Vector2(dv.x, dv.z).length() < slow:
						slow = Vector2(dv.x, dv.z).length()
						hold = w_pos[f]
				hold.y = floor_y
				before = maxf(before, _drift(w_pos, f0, f1))
				for f in range(maxi(f0 - 1, 0), mini(f1 + 2, n)):
					var w := 1.0 if f >= f0 and f <= f1 else 0.5
					var want: Vector3 = (w_pos[f] as Vector3).lerp(hold, w)
					var shift: Vector3 = Basis(Vector3.UP, (roots[f] as Vector3).z).inverse() * (want - (w_pos[f] as Vector3))
					_leg_ik(locals[f], hips[f], up, knee, foot, shift)
				var held := []
				for f in n:
					held.append(_world(roots[f], ((_fk(locals[f], hips[f])[toe]) as Transform3D).origin))
				after = maxf(after, _drift(held, f0, f1))
			f0 = f1 + 1
	# The clip.
	var anim := Animation.new()
	var loop := bool(clip.loop)
	anim.length = (n if loop else n - 1) / fps
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for i in mapped:
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("%s:%s" % [TRACK_ROOT, tgt.get_bone_name(i)]))
		for f in n:
			anim.rotation_track_insert_key(t, f / fps, (locals[f][i] as Basis).orthonormalized().get_rotation_quaternion())
	var pt := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pt, NodePath("%s:%s" % [TRACK_ROOT, tgt.get_bone_name(0)]))
	for f in n:
		anim.position_track_insert_key(pt, f / fps, hips[f])
	# The root (metres, heading), for the clip's speed and the foot-slide test.
	var path := PackedVector3Array()
	var dist := 0.0
	for f in n:
		var r: Vector3 = roots[f]
		path.append(Vector3(r.x * 0.01, r.y * 0.01, r.z))
		if f > 0:
			dist += Vector2(r.x - roots[f - 1].x, r.y - roots[f - 1].y).length() * 0.01
	anim.set_meta("root", path)
	anim.set_meta("fps", fps)
	anim.set_meta("speed", dist / anim.length)
	anim.compress(8192, int(fps))
	var out := out_dir.path_join(name + ".res")
	ResourceSaver.save(anim, out, ResourceSaver.FLAG_COMPRESS)
	print("%s: %d frames, %.2f s, %.2f m/s, legs x%.2f; planted feet drifted up to %.1f cm, held to %.1f cm -> %s" % [
		name, n, anim.length, float(anim.get_meta("speed")), ratio, before, after, out])


## How far a planted toe wanders over frames f0-f1 (cm, over the ground).
func _drift(pos: Array, f0: int, f1: int) -> float:
	var worst := 0.0
	for f in range(f0, f1 + 1):
		var d := (pos[f] as Vector3) - (pos[f0] as Vector3)
		worst = maxf(worst, Vector2(d.x, d.z).length())
	return worst


## Turns the hip and knee so the ankle moves by shift (the skeleton's space), the knee in its own plane, the foot
## keeping its angle.
func _leg_ik(local: Array, hips: Vector3, up: int, knee: int, foot: int, shift: Vector3) -> void:
	var g := _fk(local, hips)
	var gh: Transform3D = g[up]
	var gk: Transform3D = g[knee]
	var gf: Transform3D = g[foot]
	var h := gh.origin
	var k := gk.origin
	var a := gf.origin
	var target := a + shift
	var la := (k - h).length()
	var lb := (a - k).length()
	var to := target - h
	var d := clampf(to.length(), absf(la - lb) + 0.01, la + lb - 0.01)
	var u := to.normalized()
	var pole := (k - h) - u * (k - h).dot(u)
	if pole.length() < 1e-4:
		return
	var v := pole.normalized()
	var ca := clampf((la * la + d * d - lb * lb) / (2.0 * la * d), -1.0, 1.0)
	var k2 := h + u * la * ca + v * la * sqrt(1.0 - ca * ca)
	var a2 := h + u * d
	var s1 := _swing((k - h).normalized(), (k2 - h).normalized())
	var up_b := s1 * gh.basis
	var knee_b := s1 * gk.basis
	var a_moved := h + s1 * (a - h)
	var s2 := _swing((a_moved - k2).normalized(), (a2 - k2).normalized())
	knee_b = s2 * knee_b
	var parent_b: Basis = (g[tgt.get_bone_parent(up)] as Transform3D).basis
	local[up] = (parent_b.inverse() * up_b).orthonormalized()
	local[knee] = (up_b.inverse() * knee_b).orthonormalized()
	local[foot] = (knee_b.inverse() * gf.basis).orthonormalized()
