extends SceneTree
## The owner's Mixamo animations (FBX, a T-posed 65-bone rig in metres) onto the player model (assets/models/player.glb,
## an A-posed 23-bone rig in centimetres under a 0.01 scale), baked as Animation resources the game plays.
##
## A rotation copied straight across would be wrong: the two rigs rest in different poses. So, once: the player's rig
## is put into the FBX rig's T-pose, bone by bone from the hips out, each bone swung so it points where the same bone
## points in the FBX rig (the hips also turned so the legs lie across the same way). Each bone's correction is then
## the difference between the FBX bone's rest and the T-posed player bone. Every frame (30 a second): the FBX bone's
## world rotation, times the correction, is the player bone's world rotation, and its local rotation follows from its
## parent's. The hips' height is scaled by the two rigs' hip heights; their travel across the ground is dropped (the
## game moves the player).
##
## Run in a scratch project holding the FBX files and player.glb in res://src/:
##   godot --headless --path SCRATCH -s res://retarget.gd -- OUT_DIR

const CLIPS := [
	# name in the game, FBX, loops, seconds kept (0: all)
	["run", "Running", true, 0.0],
	["dive", "Run_To_Dive", false, 0.9],   # Mixamo's is a dive into water: after 0.9 s it goes under the floor
	["reach", "Reaching_Out", false, 0.0],
	["turn", "Turn_To_Running", false, 0.0],
	["kneel_down", "Kneeling_Down", false, 0.0],
	["kneel", "Kneeling", true, 0.0],
]
const FLOOR := 0.03   # no bone below this (m): the hips are lifted to keep it
## Held poses for the officials and the crowd, made on the player's own rig: the bones named point the ways given
## (model space: +Z his front, +X his left, +Y up); the rest of him stands as the rig rests.
const POSES := {
	"stand": {},
	"whistle": {"RightArm": Vector3(-0.35, -0.55, 0.75), "RightForeArm": Vector3(0.45, 0.85, 0.3)},
	"signal_out": {"RightArm": Vector3(-0.2, 1.0, 0.1), "RightForeArm": Vector3(-0.1, 1.0, 0.05)},
	"signal_foul": {"RightArm": Vector3(-1.0, 0.2, 0.35), "RightForeArm": Vector3(-1.0, 0.15, 0.4)},
	"signal_end": {"RightArm": Vector3(-0.35, 0.95, 0.1), "RightForeArm": Vector3(0.5, 0.85, 0.1),
		"LeftArm": Vector3(0.35, 0.95, 0.1), "LeftForeArm": Vector3(-0.5, 0.85, 0.1)},
	"cheer": {"RightArm": Vector3(-0.55, 0.85, 0.1), "RightForeArm": Vector3(-0.35, 0.95, 0.0),
		"LeftArm": Vector3(0.55, 0.85, 0.1), "LeftForeArm": Vector3(0.35, 0.95, 0.0)},
}
const FPS := 30.0
const TARGET := "res://src/player.glb"
const TRACK_ROOT := "target_character/Skeleton3D"
## The child each bone points at, where it has more than one.
const AIM := {"Hips": "Spine", "Spine2": "Neck", "Neck": "Head"}

var tgt: Skeleton3D
var tgt_root: Node
var out_dir := "res://out"


func _init() -> void:
	_go.call_deferred()


## After the tree is running: an AnimationPlayer added during _init does not pose its skeleton.
func _go() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	tgt_root = (load(TARGET) as PackedScene).instantiate()
	root.add_child(tgt_root)
	tgt = tgt_root.find_children("*", "Skeleton3D", true, false)[0]
	for c in CLIPS:
		await _clip(String(c[0]), String(c[1]), bool(c[2]), float(c[3]))
	for k in POSES:
		_pose_clip(String(k), POSES[k])
	await _walk()
	quit()


## A held pose: one key for every bone, the named ones swung to point the ways given.
func _pose_clip(name: String, dirs: Dictionary) -> void:
	var world := {}
	var anim := Animation.new()
	anim.length = 0.1
	anim.loop_mode = Animation.LOOP_LINEAR
	for i in tgt.get_bone_count():
		var p := tgt.get_bone_parent(i)
		var rest_local := tgt.get_bone_rest(i).basis.orthonormalized()
		var w: Basis = (world[p] as Basis) * rest_local if p >= 0 else tgt.get_bone_global_rest(i).basis.orthonormalized()
		var key := _short(tgt, i)
		var c := _aim_child(tgt, i)
		if dirs.has(key) and c >= 0:
			var have := (w * tgt.get_bone_rest(c).origin).normalized()
			w = _swing(have, (dirs[key] as Vector3).normalized()) * w
		world[i] = w.orthonormalized()
		var local: Basis = (world[p] as Basis).inverse() * (world[i] as Basis) if p >= 0 else world[i]
		var t := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(t, NodePath("%s:%s" % [TRACK_ROOT, tgt.get_bone_name(i)]))
		anim.rotation_track_insert_key(t, 0.0, local.orthonormalized().get_rotation_quaternion())
	var h := _bone(tgt, "Hips")
	var pt := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pt, NodePath("%s:%s" % [TRACK_ROOT, tgt.get_bone_name(h)]))
	anim.position_track_insert_key(pt, 0.0, tgt.get_bone_rest(h).origin)
	anim.set_meta("speed", 0.0)
	ResourceSaver.save(anim, "%s/%s.res" % [out_dir, name])
	print("%s: a held pose" % name)


## The player model's own walk, its travel across the ground taken out, its speed noted.
func _walk() -> void:
	var ap: AnimationPlayer = tgt_root.find_children("*", "AnimationPlayer", true, false)[0]
	var a: Animation = ap.get_animation("Walking").duplicate(true)
	var h := _bone(tgt, "Hips")
	var hp := NodePath("%s:%s" % [TRACK_ROOT, tgt.get_bone_name(h)])
	var travel := 0.0
	for t in a.get_track_count():
		if a.track_get_path(t) == hp and a.track_get_type(t) == Animation.TYPE_POSITION_3D:
			var n := a.track_get_key_count(t)
			var first: Vector3 = a.track_get_key_value(t, 0)
			var last: Vector3 = a.track_get_key_value(t, n - 1)
			travel = Vector2(last.x - first.x, last.z - first.z).length() * 0.01
			var rest := tgt.get_bone_rest(h).origin
			for k in n:
				var v: Vector3 = a.track_get_key_value(t, k)
				a.track_set_key_value(t, k, Vector3(rest.x, v.y, rest.z))
	a.loop_mode = Animation.LOOP_LINEAR
	a.set_meta("speed", travel / a.length if travel > 0.05 else 1.4)
	ResourceSaver.save(a, "%s/walk.res" % out_dir)
	print("walk: %.2f s, %.2f m/s" % [a.length, float(a.get_meta("speed"))])


func _bone(sk: Skeleton3D, short: String) -> int:
	return sk.find_bone("mixamorig_" + short)


func _short(sk: Skeleton3D, i: int) -> String:
	return sk.get_bone_name(i).trim_prefix("mixamorig_")


func _aim_child(sk: Skeleton3D, i: int) -> int:
	var kids := sk.get_bone_children(i)
	var want: String = AIM.get(_short(sk, i), "")
	for k in kids:
		if want != "" and _short(sk, k) == want:
			return k
	return kids[0] if kids.size() == 1 else -1


## The player's rig in the FBX rig's rest pose: world bases, bone by bone from the hips out.
func _tpose(src: Skeleton3D) -> Dictionary:
	var g := {}   # target bone -> world Basis in the T-pose
	var order := []
	for i in tgt.get_bone_count():
		order.append(i)
	for i in order:
		var p := tgt.get_bone_parent(i)
		var rest_local := tgt.get_bone_rest(i).basis.orthonormalized()
		var world: Basis = (g[p] as Basis) * rest_local if p >= 0 else tgt.get_bone_global_rest(i).basis.orthonormalized()
		var si := _bone(src, _short(tgt, i))
		var c := _aim_child(tgt, i)
		if si >= 0 and c >= 0:
			var sc := _bone(src, _short(tgt, c))
			if sc >= 0:
				# Where this bone points now (its child's rest offset, turned by the world basis) and where it should.
				var have := (world * tgt.get_bone_rest(c).origin).normalized()
				var want := (src.get_bone_global_rest(sc).origin - src.get_bone_global_rest(si).origin).normalized()
				world = _swing(have, want) * world
				if p < 0:
					# The hips: also turn about the spine so the legs lie across as the FBX rig's do.
					var ll := _bone(tgt, "LeftUpLeg")
					var rl := _bone(tgt, "RightUpLeg")
					var across := (world * (tgt.get_bone_rest(ll).origin - tgt.get_bone_rest(rl).origin)).normalized()
					var s_across := (src.get_bone_global_rest(_bone(src, "LeftUpLeg")).origin - src.get_bone_global_rest(_bone(src, "RightUpLeg")).origin).normalized()
					var axis := want
					var a1 := (across - axis * across.dot(axis)).normalized()
					var a2 := (s_across - axis * s_across.dot(axis)).normalized()
					var ang := atan2(axis.dot(a1.cross(a2)), a1.dot(a2))
					world = Basis(axis, ang) * world
		g[i] = world.orthonormalized()
	return g


func _swing(a: Vector3, b: Vector3) -> Basis:
	var axis := a.cross(b)
	var s := axis.length()
	var c := a.dot(b)
	if s < 1e-6:
		return Basis.IDENTITY if c > 0.0 else Basis(Vector3.UP if absf(a.y) < 0.9 else Vector3.RIGHT, PI)
	return Basis(axis / s, atan2(s, c))


func _clip(name: String, fbx: String, loop: bool, keep: float) -> void:
	var src_root: Node = (load("res://src/%s.fbx" % fbx) as PackedScene).instantiate()
	root.add_child(src_root)
	await process_frame
	var src: Skeleton3D = src_root.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = src_root.find_children("*", "AnimationPlayer", true, false)[0]
	var an: String = ap.get_animation_list()[0]
	var length := ap.get_animation(an).length
	if keep > 0.0:
		length = minf(length, keep)
	var tp := _tpose(src)
	var corr := {}
	for i in tgt.get_bone_count():
		var si := _bone(src, _short(tgt, i))
		if si >= 0:
			corr[i] = src.get_bone_global_rest(si).basis.orthonormalized().inverse() * (tp[i] as Basis)
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks := {}
	for i in tgt.get_bone_count():
		if corr.has(i):
			var t := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(t, NodePath("%s:%s" % [TRACK_ROOT, tgt.get_bone_name(i)]))
			tracks[i] = t
	var hips := _bone(tgt, "Hips")
	var hips_src := _bone(src, "Hips")
	var pos_t := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos_t, NodePath("%s:%s" % [TRACK_ROOT, tgt.get_bone_name(hips)]))
	var ratio := tgt.get_bone_global_rest(hips).origin.y * 0.01 / src.get_bone_global_rest(hips_src).origin.y
	var n := int(ceil(length * FPS))
	var start_xz := Vector2.INF
	var end_xz := Vector2.ZERO
	var peak_t := 0.0
	var peak := -INF
	var hand := _bone(src, "RightHand")
	ap.play(an)
	for f in n + 1:
		var t := minf(f / FPS, length)
		ap.seek(t, true)
		var world := {}
		for i in tgt.get_bone_count():
			if not corr.has(i):
				continue
			var gs := src.get_bone_global_pose(_bone(src, _short(tgt, i))).basis.orthonormalized()
			world[i] = gs * (corr[i] as Basis)
		for i in tracks:
			var p := tgt.get_bone_parent(i)
			var local: Basis
			if p >= 0 and world.has(p):
				local = (world[p] as Basis).inverse() * (world[i] as Basis)
			else:
				# The hips' parent is the model's root (a 0.01 scale, no turn): world is local.
				local = world[i]
			anim.rotation_track_insert_key(tracks[i], t, local.orthonormalized().get_rotation_quaternion())
		var hp := src.get_bone_global_pose(hips_src).origin
		if start_xz == Vector2.INF:
			start_xz = Vector2(hp.x, hp.z)
		end_xz = Vector2(hp.x, hp.z)
		var reach := src.get_bone_global_pose(hand).origin.z - hp.z
		if reach > peak:
			peak = reach
			peak_t = t
		var lowest := INF
		for b in src.get_bone_count():
			lowest = minf(lowest, src.get_bone_global_pose(b).origin.y)
		var lift := maxf(0.0, FLOOR - lowest)
		var rest := tgt.get_bone_rest(hips).origin
		anim.position_track_insert_key(pos_t, t, Vector3(rest.x, (hp.y + lift) * ratio * 100.0, rest.z))
	# Its speed over the ground (m/s, the stride a playback rate of 1 matches) and when the right hand is furthest out.
	anim.set_meta("speed", (end_xz - start_xz).length() * ratio / length)
	anim.set_meta("peak", peak_t)
	var path := "%s/%s.res" % [out_dir, name]
	ResourceSaver.save(anim, path)
	print("%s <- %s: %.2f s, %d tracks, %d frames, %.2f m/s, hand out at %.2f s -> %s" % [name, fbx, length, anim.get_track_count(), n + 1, float(anim.get_meta("speed")), peak_t, path])
	src_root.queue_free()
