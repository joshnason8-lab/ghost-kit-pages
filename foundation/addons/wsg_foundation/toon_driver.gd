class_name WsgToonDriver
extends RefCounted
## The motion-capture locomotion (WsgLocomotor) on a game's OWN cheap body, for the Low tier: the game keeps drawing
## its 17-bone toon (one mesh, the same draw calls) and this poses its bones from the capture, so it runs with planted
## strides and bent, swinging arms instead of gliding with its arms out. No second skinned mesh, no IK, no modifiers:
## a hidden, mesh-less WsgBody (the rig's skeleton only, never in the scene tree) is driven by a WsgLocomotor, and each
## of the game's bones is turned to lie along the rig's matching segment with the rig bone's twist about it.
##
##   if WsgToonDriver.available():
##       driver = WsgToonDriver.new(toon.skeleton)              # bone_map {"hips": "pelvis", ...} for other names
##   # every frame, after the game has posed its body (its own pose stays under the driver's):
##   driver.update(delta, velocity, facing)                     # world m/s; facing: world yaw (radians) or a Vector3
##   driver.set_override(1.0, WsgToonDriver.ARMS, 0.15)         # a hold or a pass: the game's arms win
##   driver.set_override(1.0, [], 0.1)                          # a shot or a leap: the whole body is the game's
##   driver.set_override(0.0, [], 0.2)                          # back to the capture (resumed at the body's speed)
##
## Or as a pose to blend with the game's own pose dictionaries: options {"auto_apply": false}, then pose() each frame
## ({game bone: local Quaternion, "@hips": the hips' offset from their rest}), or apply(weight, bones) over the
## skeleton yourself.
##
## The game's rest is read from its skeleton (Netball's ToonBody: identity rests, arms hanging; Kabaddi's rigged
## bodies: an A-pose with the legs apart, facing -Z: options {"face": PI}); the hips move by the clip's hips scaled by
## the toon's leg against the rig's, so the feet stay on the ground; the root motion stays the game's (it moves the
## body); the stride is the locomotor's own speed matching, its leg_scale the toon's leg (in the world) over the rig's.
## Cheap: about 0.1 ms a body on a desktop, a stripped clip library (the body's 20 bones, no fingers), and the posing
## can be staggered (every = 2 or 3 for far bodies: the last pose is laid again in between).
## Without the licensed clips (WsgClips.available() false: a fork, CI) available() is false and update() does nothing:
## the game keeps its own cycle.

## The game's bones, by the names six of the games share (WsgLegacyPose.MAP). bone_map renames them.
const BONES := ["hips", "spine", "chest", "neck", "head", "upperarm_l", "forearm_l", "hand_l", "upperarm_r",
	"forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
## Each one's bone on the rig.
const RIG := ["Hips", "Spine", "Spine2", "Neck", "Head", "LeftArm", "LeftForeArm", "LeftHand", "RightArm",
	"RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]
## The joint each segment runs to (an index into BONES; -1: a leaf, which is turned as the rig's bone is).
const NEXT := [1, 2, 3, 4, -1, 6, 7, -1, 9, 10, -1, 12, 13, -1, 15, 16, -1]
## Its parent among BONES (the hand's rest is matched as its forearm's).
const PARENT := [-1, 0, 1, 2, 3, 2, 5, 6, 2, 8, 9, 0, 11, 12, 0, 14, 15]
## Groups for set_override.
const ARMS := ["upperarm_l", "forearm_l", "hand_l", "upperarm_r", "forearm_r", "hand_r"]
const LEGS := ["thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
const TORSO := ["hips", "spine", "chest", "neck", "head"]
const HEAD := ["neck", "head"]
## The rig's bones the clips are kept for (the driver reads no other): the shoulders and Spine1 carry the arms and
## the chest.
const TRACKS := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm",
	"LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot",
	"RightUpLeg", "RightLeg", "RightFoot"]
## m over its rest an ankle of the rig's may be and still be down (the stop and jump clips pick their foot by it).
const DOWN := 0.035

## Off: no driver anywhere (a game's switch, like a build without the clips).
static var off := false
static var _lib: AnimationLibrary
static var _made := 0

## The game's skeleton, the hidden rig body and its locomotor (loco.play(), loco.jump(), loco.step for footsteps).
var skeleton: Skeleton3D
var body: WsgBody
var loco: WsgLocomotor
## Pose every n-th update (2 or 3 for bodies far from the camera); in between the last pose is laid again.
var every := 1
## update() lays the pose on the skeleton itself (apply(1.0)); off: the game takes pose() and blends it.
var auto_apply := true
## The game's body turned onto the rig's facing (+Z, the left +X): Kabaddi's, built facing -Z, is Quaternion(UP, PI).
var face := Quaternion.IDENTITY
## The toon's facing taken from its skeleton in the world (when it is in the tree), else from update()'s facing.
var facing_from_node := true
## The toon's size in the world (its strides scale with it); 0: the skeleton's own global scale.
var scale := 0.0
## After the whole body was the game's (an override of 1 on every bone), the capture picks up at the body's speed
## (WsgLocomotor.resume) rather than from what it was doing before.
var auto_resume := true

var _ti := PackedInt32Array()       # BONES index -> the toon's bone (-1: the game has none)
var _ri := PackedInt32Array()       # -> its place in TRACKS
var _tr := PackedInt32Array()       # TRACKS -> the rig's bone
var _tp := PackedInt32Array()       # TRACKS -> its parent's place in TRACKS (-1: the root)
var _fq: Array[Quaternion] = []     # TRACKS: model-space turns and places this pose (the skeleton's own global
var _fp: Array[Vector3] = []        # poses are not kept up to date outside the scene tree)
var _end := PackedInt32Array()      # -> the BONES index its segment runs to on both skeletons (-1: none)
var _drr: Array[Vector3] = []       # the rig's segment direction at rest (its own frame = the model's)
var _b: Array[Quaternion] = []      # the rig's rest onto the toon's: toon global = face^-1 * rig global * _b
var _anc := PackedInt32Array()      # the nearest of BONES above it on the toon (-1: none)
var _mid: Array[PackedInt32Array] = []   # the toon's bones between that one and it (top down)
var _g: Array[Quaternion] = []      # toon globals this pose
var _local: Array[Quaternion] = []  # the pose: each toon bone's local turn
var _rq: Array[Quaternion] = []
var _rp: Array[Vector3] = []
var _hips_off := Vector3.ZERO       # the toon's hips' offset from their rest (in their parent's frame)
var _hips_rest := Vector3.ZERO
var _rig_hips := Vector3.ZERO
var _rig_ankle := 0.08
var _leg := 0.85                    # the toon's leg (hip to ankle), its skeleton's metres
var _lift := 0.0                    # how far its hips stand higher on straight legs than at its rest (m)
var _rig_leg := 0.85
var _over := PackedFloat32Array()   # how much the game's own pose wins, each bone
var _over_to := PackedFloat32Array()
var _over_rate := 0.0
var _have := false
var _paused := false
var _acc := 0.0
var _tick := 0
var _offset := 0
var _down := [true, true]
## Holds a foot the capture has down where it landed - a two-bone turn of the game's thigh and shin, its foot keeping
## its turn - and lets it go over RELEASE once the capture lifts it: the game's toon has no planter, and the clip's feet
## slid under a body not going the clip's speed (Pok Ta Pok's Low players: 7-15 cm a step). options {"plant": false}
## leaves the clip's feet as they come.
var plant := true
## Over this long (s), eased in and out (the foot lands its swing where the clip's foot is, without a lurch).
const RELEASE := 0.25
var _lock := [Vector3.INF, Vector3.INF]      # where each foot is held (the world)
var _lw := [0.0, 0.0]                          # how much (1 held, easing to 0 let go)
var _was_w := [Vector3.INF, Vector3.INF]     # each ankle as the clip put it last frame (the world)
var _out := [false, false]                   # let go past the leg's reach: stepping, until the clip lifts it
var _speed := 0.0                            # the body's speed across (m/s), this update
var _held := [false, false]                  # down last frame (held)
var _was_y := [INF, INF]                     # each ankle's height last frame (the world)
## The ball of the foot in the game's foot bone (options toe; Pok Ta Pok's: (0, -0.025, 0.14)): a foot down on it, its
## heel up, is held by it. ZERO: the ankle only.
var toe := Vector3.ZERO
var _on_toe := [false, false]                # held by its ball, not its ankle
var _was_t := [Vector3.INF, Vector3.INF]
## How high a foot let go past its reach steps (m, an arc over RELEASE): across the floor it is read as sliding.
const STEP_UP := 0.05
## A body slower than this (m/s) is nearly still.
const STILL := 0.5


## Whether the capture can drive a toon here (the licensed clips are in this build and the driver is not off).
static func available() -> bool:
	return not off and WsgClips.available()


## toon_skeleton: the game's own skeleton (posed by the game, drawn by the game). bone_map: BONES name -> the game's
## name for it ("" or absent from the skeleton: the game has no such bone, it is left alone). options: every, face
## (a Quaternion, or a yaw in radians), scale, auto_apply, facing_from_node, auto_resume, offset (which of `every`
## frames this body poses on; by default the bodies take turns), rng (WsgLocomotor.rng), cut_from_heading.
func _init(toon_skeleton: Skeleton3D, bone_map := {}, options := {}) -> void:
	skeleton = toon_skeleton
	every = int(options.get("every", 1))
	auto_apply = bool(options.get("auto_apply", true))
	facing_from_node = bool(options.get("facing_from_node", true))
	auto_resume = bool(options.get("auto_resume", true))
	scale = float(options.get("scale", 0.0))
	plant = bool(options.get("plant", true))
	toe = options.get("toe", Vector3.ZERO)
	var f = options.get("face", Quaternion.IDENTITY)
	face = Quaternion(Vector3.UP, float(f)) if (f is float or f is int) else (f as Quaternion)
	_offset = int(options.get("offset", _made))
	_made += 1
	var n := BONES.size()
	_over.resize(n)
	_over_to.resize(n)
	if skeleton == null or not available():
		return
	body = WsgBody.new()          # no character: the rig's skeleton and its two drivers, no mesh, no skin
	body.name = "ToonDriverRig"
	body.set_manual(true)         # (never in the tree: nothing runs but what update() runs)
	loco = WsgLocomotor.attach(body)
	if not loco.enabled:
		body.free()
		body = null
		loco = null
		return
	loco.tree.remove_animation_library("mob")
	loco.tree.add_animation_library("mob", _stripped())
	if options.has("rng") and "rng" in loco:
		loco.set("rng", options.rng)
	if options.has("cut_from_heading") and "cut_from_heading" in loco:
		loco.set("cut_from_heading", bool(options.cut_from_heading))
	body.skeleton.motion_scale = 1.0    # the rig's own hips; the toon's are scaled here
	_setup(bone_map)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and body and is_instance_valid(body):
		body.free()


## The clip library with only the bones the driver reads (TRACKS): a third of the tracks, a third less time in the
## tree. Made once.
static func _stripped() -> AnimationLibrary:
	if _lib:
		return _lib
	var keep := {}
	for b in TRACKS:
		keep[NodePath("Skeleton3D:" + b)] = true
	var src := WsgClips.library()
	_lib = AnimationLibrary.new()
	for nm in src.get_animation_list():
		var a: Animation = src.get_animation(nm)
		var c := Animation.new()
		c.length = a.length
		c.loop_mode = a.loop_mode
		c.step = a.step
		for i in a.get_track_count():
			if not keep.has(a.track_get_path(i)):
				continue
			var t := c.add_track(a.track_get_type(i))
			c.track_set_path(t, a.track_get_path(i))
			c.track_set_interpolation_type(t, a.track_get_interpolation_type(i))
			c.track_set_interpolation_loop_wrap(t, a.track_get_interpolation_loop_wrap(i))
			for k in a.track_get_key_count(i):
				c.track_insert_key(t, a.track_get_key_time(i, k), a.track_get_key_value(i, k))
		_lib.add_animation(nm, c)
	return _lib


func _setup(bone_map: Dictionary) -> void:
	var n := BONES.size()
	var j: Dictionary = body.joints
	_ti.resize(n)
	_ri.resize(n)
	_end.resize(n)
	_anc.resize(n)
	var back := {}                 # toon index -> BONES index
	for b in TRACKS:
		var r := body.skeleton.find_bone(b)
		_tr.append(r)
		_tp.append(TRACKS.find(body.skeleton.get_bone_name(body.skeleton.get_bone_parent(r))) if body.skeleton.get_bone_parent(r) >= 0 else -1)
		_fq.append(Quaternion.IDENTITY)
		_fp.append(Vector3.ZERO)
	for i in n:
		var nm: String = bone_map.get(BONES[i], BONES[i])
		_ti[i] = skeleton.find_bone(nm) if nm != "" else -1
		_ri[i] = TRACKS.find(RIG[i])
		if _ti[i] >= 0:
			back[_ti[i]] = i
		_g.append(Quaternion.IDENTITY)
		_local.append(Quaternion.IDENTITY)
		_rq.append(Quaternion.IDENTITY)
		_rp.append(Vector3.ZERO)
		_drr.append(Vector3.UP)
		_b.append(Quaternion.IDENTITY)
		_mid.append(PackedInt32Array())
	# The rest onto the rig's: each segment the toon has turned from its rest direction onto the rig's (the shortest
	# turn, which keeps the toon's front the rig's front); a hand as its forearm; a head and a foot as they are (their
	# rests are the rig's: upright, flat and forward).
	var arc: Array[Quaternion] = []
	for i in n:
		var a := Quaternion.IDENTITY
		var nx: int = NEXT[i]
		_end[i] = -1
		if _ti[i] >= 0 and nx >= 0 and _ti[nx] >= 0:
			var dt := skeleton.get_bone_global_rest(_ti[nx]).origin - skeleton.get_bone_global_rest(_ti[i]).origin
			var dr: Vector3 = (j[RIG[nx]] as Vector3) - (j[RIG[i]] as Vector3)
			if dt.length() > 1e-4 and dr.length() > 1e-4:
				_drr[i] = dr.normalized()
				a = Quaternion((face * dt).normalized(), _drr[i])
				_end[i] = nx
		elif nx < 0 and BONES[i].begins_with("hand"):
			a = arc[PARENT[i]]
		arc.append(a)
		if _ti[i] >= 0:
			var g0 := skeleton.get_bone_global_rest(_ti[i]).basis.get_rotation_quaternion()
			_b[i] = (a * face * g0).normalized()
	# The toon's own hierarchy: which of its mapped bones each hangs from, through which others.
	for i in n:
		_anc[i] = -1
		if _ti[i] < 0:
			continue
		var mid := []
		var p := skeleton.get_bone_parent(_ti[i])
		while p >= 0 and not back.has(p):
			mid.push_front(p)
			p = skeleton.get_bone_parent(p)
		_anc[i] = back[p] if p >= 0 else -1
		_mid[i] = PackedInt32Array(mid)
	if _ti[0] >= 0:
		_hips_rest = skeleton.get_bone_rest(_ti[0]).origin
	_rig_hips = j["Hips"]
	_rig_ankle = (j["LeftFoot"] as Vector3).y
	_rig_leg = (j["LeftUpLeg"] as Vector3).distance_to(j["LeftLeg"]) + (j["LeftLeg"] as Vector3).distance_to(j["LeftFoot"])
	var legs := []
	var lift := 0.0
	for s in [[11, 12, 13], [14, 15, 16]]:
		if _ti[s[0]] >= 0 and _ti[s[1]] >= 0 and _ti[s[2]] >= 0:
			var h := skeleton.get_bone_global_rest(_ti[s[0]]).origin
			var k := skeleton.get_bone_global_rest(_ti[s[1]]).origin
			var an := skeleton.get_bone_global_rest(_ti[s[2]]).origin
			legs.append(h.distance_to(k) + k.distance_to(an))
			# A leg not straight down at rest (Kabaddi's, apart) is longer straight down than its rest is tall: the hips
			# go up by that much, so a straight leg stands on the ground as the rig's does.
			lift += (an.y + legs[-1] - h.y) * 0.5
	_leg = (legs[0] + legs[-1]) * 0.5 if not legs.is_empty() else _rig_leg
	_lift = lift if legs.size() == 2 else 0.0


## One frame: the locomotor driven (on this body's frames: every), its pose laid on the game's bones (auto_apply),
## the overrides eased. velocity: world m/s (y ignored); facing: world yaw (radians, 0 = +Z) or a world direction;
## want_velocity: where the player is asking to go, if the game knows (WsgLocomotor.drive). True if it posed afresh.
func update(dt: float, velocity: Vector3, facing = 0.0, want_velocity := Vector3.INF) -> bool:
	if loco == null or dt <= 0.0:
		return false
	var yaw: float = atan2(facing.x, facing.z) if facing is Vector3 else float(facing)
	_speed = Vector2(velocity.x, velocity.z).length()
	_ease(dt)
	if _whole_body():
		# The game's own move over all of it: the capture waits (and costs nothing).
		_paused = true
		_acc = 0.0
		return false
	if _paused:
		_paused = false
		if auto_resume and loco.has_method("resume"):
			loco.call("resume", velocity, yaw)
		_have = false
	_acc += dt
	var fresh := false
	if not _have or (_tick + _offset) % maxi(every, 1) == 0:
		var s := scale
		if s <= 0.0:
			s = absf(skeleton.global_basis.get_scale().y) if skeleton.is_inside_tree() else 1.0
		loco.leg_scale = _leg * s / _rig_leg
		loco.drive(minf(_acc, 0.1), velocity, yaw, want_velocity)
		_retarget(yaw)
		_acc = 0.0
		_have = true
		fresh = true
	_tick += 1
	if auto_apply:
		apply(1.0)
		plant_feet(dt)
	return fresh


## The game's own pose wins over the capture's by weight on these bones (BONES names or the game's; [] all of them),
## and nowhere else; eased there over fade seconds. Arms only for a hold or a pass (ARMS), the whole body for a shot
## or a leap; weight 0 hands it all back.
func set_override(weight: float, bones := [], fade := 0.0) -> void:
	var w := clampf(weight, 0.0, 1.0)
	var want := {}
	for b in bones:
		want[_index(String(b))] = true
	for i in BONES.size():
		_over_to[i] = w if (bones.is_empty() or want.has(i)) else 0.0
		if fade <= 0.0:
			_over[i] = _over_to[i]
	_over_rate = 1.0 / fade if fade > 0.0 else 0.0


## How much the game's own pose wins on that bone now (0..1).
func override(bone: String) -> float:
	var i := _index(bone)
	return _over[i] if i >= 0 else 0.0


## The last pose: {the game's bone name: its local turn (Quaternion), "@hips": the hips' offset from their rest
## (their parent's frame, the skeleton's metres)}. Empty without the clips or before the first update.
func pose() -> Dictionary:
	var out := {}
	if not _have:
		return out
	for i in BONES.size():
		if _ti[i] >= 0:
			out[skeleton.get_bone_name(_ti[i])] = _local[i]
	if _ti[0] >= 0:
		out["@hips"] = _hips_off
	return out


## Lays the last pose over what the skeleton has now, by weight (times what the overrides leave), on these bones
## ([] all).
func apply(weight := 1.0, bones := []) -> void:
	if not _have or weight <= 0.0:
		return
	var only := {}
	for b in bones:
		only[_index(String(b))] = true
	for i in BONES.size():
		var ti := _ti[i]
		if ti < 0 or (not only.is_empty() and not only.has(i)):
			continue
		var w := weight * (1.0 - _over[i])
		if w <= 0.0:
			continue
		skeleton.set_bone_pose_rotation(ti, _local[i] if w >= 0.999 else skeleton.get_bone_pose_rotation(ti).slerp(_local[i], w))
		if i == 0:
			var p := _hips_rest + _hips_off
			skeleton.set_bone_pose_position(ti, p if w >= 0.999 else skeleton.get_bone_pose_position(ti).lerp(p, w))


## The feet held where the capture put them down (plant), on the skeleton as it is posed now: update() runs it after
## apply(); a game laying the pose itself (auto_apply off) calls it after its own apply().
func plant_feet(dt: float) -> void:
	if not plant or not _have or not skeleton.is_inside_tree():
		return
	var xf := skeleton.global_transform
	var inv := xf.affine_inverse()
	for f in 2:
		var s := [11, 12, 13] if f == 0 else [14, 15, 16]
		var th := _ti[s[0]]
		var sh := _ti[s[1]]
		var ft := _ti[s[2]]
		if th < 0 or sh < 0 or ft < 0 or skeleton.get_bone_parent(sh) != th or skeleton.get_bone_parent(ft) != sh \
				or _over[s[0]] > 0.001 or _over[s[1]] > 0.001 or _over[s[2]] > 0.001:
			_lock[f] = Vector3.INF
			_lw[f] = 0.0
			continue
		var gh := skeleton.get_bone_global_pose(th)
		var gk := skeleton.get_bone_global_pose(sh)
		var ga := skeleton.get_bone_global_pose(ft)
		var hip := gh.origin
		var knee := gk.origin
		var ank := ga.origin
		var a := hip.distance_to(knee)
		var b := knee.distance_to(ank)
		var ank_w := xf * ank
		# Down as the planter reads it, from the clip's foot on the game's body: within 3 cm of where it stands and as
		# slow as a stance foot (under 0.6 + 0.8 x the body's speed; a swing goes about twice the body's), held from its
		# first frame on the floor; it stays down under 3 cm however the clip moves it (a start's blend whips its feet about
		# at 4-13 m/s on the floor), under 5 cm until it goes as fast as a swing - a foot carried past the leg's reach
		# steps (below). (Not the rig's own down: a
		# walk's swing never rises 3.5 cm on it, and the foot was held through it - the leg dragged, the knee folded.)
		var stand_y := (xf * skeleton.get_bone_global_rest(ft).origin).y - (xf.origin.y - skeleton.global_position.y)
		var spd := Vector2(ank_w.x - (_was_w[f] as Vector3).x, ank_w.z - (_was_w[f] as Vector3).z).length() / maxf(dt, 0.001) \
			if _was_w[f] != Vector3.INF else INF
		_was_w[f] = ank_w
		var land := 0.6 + 0.8 * _speed
		var down: bool = (ank_w.y < stand_y + 0.03 and spd < land) if not _held[f] \
			else (ank_w.y < stand_y + 0.03 or (ank_w.y < stand_y + 0.05 and spd < 0.6 + 1.2 * _speed))
		# (Nearly still - a stop, standing: the rig's own down too, its feet's small shuffles faster than a still body's
		# stance; a still body has no swing to hold through.)
		if _speed < STILL and _down[f] and ank_w.y < stand_y + 0.05:
			down = true
		# (Or its ball down, its heel up - as the feet rule reads it: the lower of ankle and ball within 3 cm, the ball
		# under 1.2 m/s.)
		var toe_w := xf * (ga * toe) if toe != Vector3.ZERO else Vector3.INF
		var toe_floor := stand_y + ((xf * (skeleton.get_bone_global_rest(ft) * toe)).y - (xf * skeleton.get_bone_global_rest(ft).origin).y) \
			if toe != Vector3.ZERO else 0.0
		var tspd := Vector2(toe_w.x - (_was_t[f] as Vector3).x, toe_w.z - (_was_t[f] as Vector3).z).length() / maxf(dt, 0.001) \
			if toe != Vector3.ZERO and _was_t[f] != Vector3.INF else INF
		_was_t[f] = toe_w
		var toe_down := toe != Vector3.ZERO and toe_w.y < toe_floor + 0.03 and tspd < land and ank_w.y >= stand_y + 0.03
		down = down or toe_down
		# (Flat on the floor - within 2 cm, its ball too - it is down however fast the clip moves it, as the planter has
		# it: a swing never comes through flat, and one let go there skidded across the floor; and coming down within
		# 2.5 cm, the margin the feet rule's own flat reading takes from the lowest it goes - a landing at 3.2 m/s,
		# 2.3 cm up and falling, skidded 4 cm a frame.)
		var falling: bool = float(_was_y[f]) < INF and ank_w.y < float(_was_y[f]) - 0.0005
		_was_y[f] = ank_w.y
		if (ank_w.y < stand_y + 0.02 or (falling and ank_w.y < stand_y + 0.025)) and (toe == Vector3.ZERO or toe_w.y < toe_floor + 0.025):
			down = true
		if _out[f]:
			if ank_w.y > stand_y + 0.03:
				_out[f] = false
			down = false
		_held[f] = down
		if down:
			if _lock[f] == Vector3.INF:
				# (Held by its ball if that touched first: the ankle then goes where the foot's turn puts it.)
				_on_toe[f] = toe_down and not (ank_w.y < stand_y + 0.03)
				_lock[f] = toe_w if _on_toe[f] else ank_w
			elif _lw[f] < 1.0:
				# (Down again while still being let go: held where it is drawn now, not snapped back.)
				_lock[f] = ank_w.lerp(_lock[f] if not _on_toe[f] else (_lock[f] as Vector3) - (toe_w - ank_w), smoothstep(0.0, 1.0, _lw[f]))
				_on_toe[f] = false
			_lw[f] = 1.0
		elif _lock[f] != Vector3.INF:
			_lw[f] = move_toward(_lw[f], 0.0, dt / RELEASE)
			if _lw[f] <= 0.0:
				_lock[f] = Vector3.INF
		if _lock[f] == Vector3.INF:
			continue
		# (Far off - a teleport, a new play: let it go at once.)
		if ank.distance_to(inv * (_lock[f] as Vector3)) > (a + b):
			_lock[f] = Vector3.INF
			_lw[f] = 0.0
			continue
		# (At the end of the leg's reach, the body going on: the heel comes up over the held spot - the ankle rises, not
		# across: a toon standing on straight legs had its held spot dragged a few mm a frame, 2-6 cm a step. Only past
		# the leg's reach across does the held spot come along, rather than the foot let go across the floor at once.)
		var lk: Vector3 = inv * (_lock[f] as Vector3)
		if _on_toe[f]:
			lk -= (ga * toe) - ank
		var reach := (a + b) * 0.995
		var dv := lk - hip
		var up := xf.basis.inverse() * Vector3.UP
		var vert := dv.dot(up.normalized())
		var across := dv - up.normalized() * vert
		if across.length() > reach and not _out[f]:
			# (Past it across - the body carried on: the foot steps after it, let go in an arc over RELEASE.)
			_out[f] = true
			down = false
		if across.length() > reach:
			# (At its height, as far across as the leg reaches there.)
			lk = hip + up.normalized() * vert + across.normalized() * sqrt(maxf(0.0, reach * reach - vert * vert))
		elif dv.length() > reach:
			lk = hip + across - up.normalized() * sqrt(maxf(0.0, reach * reach - across.length_squared()))
		var target: Vector3 = ank.lerp(lk, smoothstep(0.0, 1.0, _lw[f]))
		# (Let go, it rises with the clip's foot and comes across as it does: over the floor it is read as sliding.)
		if not down:
			target.y = maxf(target.y, ank.y)
		if _out[f]:
			target.y = maxf(target.y, lk.y + STEP_UP * sin(PI * clampf(1.0 - _lw[f], 0.0, 1.0)))
		var d := hip.distance_to(target)
		d = clampf(d, absf(a - b) + 0.001, (a + b) * 0.9999)
		var t := (target - hip).normalized()
		# The knee bends forward (the toon's front): on a leg nearly straight the way it bends now is a few mm either way.
		var pole := face.inverse() * Vector3.BACK
		pole = pole - t * pole.dot(t)
		if pole.length_squared() < 1e-8:
			continue
		pole = pole.normalized()
		var x := (a * a - b * b + d * d) / (2.0 * d)
		var kn := hip + t * x + pole * sqrt(maxf(0.0, a * a - x * x))
		var r1 := Quaternion((knee - hip).normalized(), (kn - hip).normalized())
		var r2 := Quaternion((r1 * (ank - knee)).normalized(), (hip + t * d - kn).normalized())
		var qh := gh.basis.get_rotation_quaternion()
		var qk := gk.basis.get_rotation_quaternion()
		var qa := ga.basis.get_rotation_quaternion()
		var pq := Quaternion.IDENTITY
		var par := skeleton.get_bone_parent(th)
		if par >= 0:
			pq = skeleton.get_bone_global_pose(par).basis.get_rotation_quaternion()
		var nh := (r1 * qh).normalized()
		var nk := (r2 * r1 * qk).normalized()
		skeleton.set_bone_pose_rotation(th, (pq.inverse() * nh).normalized())
		skeleton.set_bone_pose_rotation(sh, (nh.inverse() * nk).normalized())
		skeleton.set_bone_pose_rotation(ft, (nk.inverse() * qa).normalized())


## Stride phase of the capture (0..1 from the left foot's landing), for a game that keys sounds or effects off it.
func phase() -> float:
	return loco.phase if loco else 0.0


func _index(name: String) -> int:
	var i := BONES.find(name)
	if i < 0 and skeleton:
		var t := skeleton.find_bone(name)
		if t >= 0:
			i = _ti.find(t)
	return i


func _ease(dt: float) -> void:
	for i in BONES.size():
		_over[i] = move_toward(_over[i], _over_to[i], _over_rate * dt) if _over_rate > 0.0 else _over_to[i]


func _whole_body() -> bool:
	for i in BONES.size():
		if _ti[i] >= 0 and _over[i] < 0.999:
			return false
	return true


## The rig's pose onto the toon: each segment along the rig's (exactly), turned about it as the rig's bone is; the
## rig's facing against the toon's (a turn on the spot turns the body under the game's facing) laid over all of it.
func _retarget(yaw: float) -> void:
	var rs := body.skeleton
	var n := BONES.size()
	for k in TRACKS.size():
		var r := _tr[k]
		var p := _tp[k]
		var lq := rs.get_bone_pose_rotation(r)
		var lp := rs.get_bone_pose_position(r)
		if p < 0:
			_fq[k] = lq
			_fp[k] = lp
		else:
			_fq[k] = _fq[p] * lq
			_fp[k] = _fp[p] + _fq[p] * lp
	for i in n:
		_rq[i] = _fq[_ri[i]]
		_rp[i] = _fp[_ri[i]]
	var game_yaw := yaw
	if facing_from_node and skeleton.is_inside_tree():
		var fwd := skeleton.global_basis * (face.inverse() * Vector3.BACK)
		game_yaw = atan2(fwd.x, fwd.z)
	var fy := face.inverse() * Quaternion(Vector3.UP, wrapf(loco.yaw - game_yaw, -PI, PI))
	for i in n:
		if _ti[i] < 0:
			continue
		var q := _rq[i]
		var e := _end[i]
		if e >= 0:
			var want := _rp[e] - _rp[i]
			if want.length_squared() > 1e-10:
				var have := q * _drr[i]
				q = Quaternion(have, want.normalized()) * q
		_g[i] = (fy * q * _b[i]).normalized()
	for i in n:
		var ti := _ti[i]
		if ti < 0:
			continue
		var gp := _g[_anc[i]] if _anc[i] >= 0 else Quaternion.IDENTITY
		for m in _mid[i]:
			gp = gp * skeleton.get_bone_pose_rotation(m)
		_local[i] = (gp.inverse() * _g[i]).normalized()
		if i == 0:
			_hips_off = gp.inverse() * ((fy * (_rp[0] - _rig_hips)) * (_leg / _rig_leg) + Vector3(0.0, _lift, 0.0))
	# Which feet are down (the locomotor's stops and jumps go by the foot that is up), and the footsteps.
	for f in 2:
		var down := _rp[13 if f == 0 else 16].y < _rig_ankle + DOWN
		loco.planter.contact[f] = 1.0 if down else 0.0
		if down and not _down[f]:
			loco.step.emit(f)
		_down[f] = down
