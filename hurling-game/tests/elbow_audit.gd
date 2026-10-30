extends Node
## Every elbow in a whole match, on the shared foundation: an AI v AI match (runs, cuts, stops, swings, catches,
## solos, frees, puck-outs, the officials' signals) played headless, each body read when its skeleton has its final
## pose. An elbow is wrong two ways:
##   bent backwards: the forearm past straight about the elbow's hinge (the rig's hinge limit should make it
##     impossible: this proves it is applied last);
##   turned the wrong way: the upper arm turned about its length so far that the elbow points where an elbow
##     cannot (its bend more than TWIST_MAX from the way an arm hanging, raised or swung bends, in the chest).
##   straightened: an arm the game poses (its moves; the hurley arm) much straighter on the rig than in the game - the
##     hinge throwing away a bend it could not follow (the arm snapping straight and back).
## The same is measured on the game's own body (17 bones), to tell the foundation's faults from the game's poses.
## And the hands, close up (the free-taking practice and the shoot-out are filmed close): a wrist turned past WRIST_MAX
## about the forearm (candy-wrap), a finger through the hurley's handle. And the feet: in the game's own moves where
## the game has them (not floating), under the motion capture never both far off the ground.
##   godot --headless --path . --fixed-fps 30 res://tests/elbow_audit.tscn -- [match minutes] [seed] [raw]
##   ... -- practice     (the ten frees of the practice: set, lift, toss, strike, follow-through; the umpires)
##   ... -- shootout     (the extra-time shoot-out to a winner: the takers, the goalkeepers, the umpires)

const TWIST_MAX := 115.0    # degrees: a humerus turns about 70 in and 90 out from neutral; past this it is wrong
const BENT := 25.0          # an elbow bent less than this has no direction to be wrong in
const STRAIGHTENED := 30.0  # degrees less bend on the rig than in the game's pose
const FEET_OFF := 5.0       # cm the lower ankle is above (or below) its standing height when the game has a foot down
const FEET_AIR := 30.0      # cm the lower ankle may be up under the motion capture (a sprint's flight)
const FINGER_IN := 5.0      # mm of a finger's skin into the handle (flesh gives a little round a grip)
const WRIST_MAX := 110.0    # degrees the hand may turn about the forearm (the forearm's own range is about 85 each way)

var worst := []             # [deg, kind, who, action, mode, time]
var counts := {}
var frames := 0
var _seen := {}
var m: Node
var _raw := false
var _handle := {}           # link -> [the handle's middle, its direction, its radius, half its length] (the hurley's own space)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var length := float(args[0]) if args.size() > 0 else 4.0
	var seed := int(args[1]) if args.size() > 1 else 7
	_raw = "raw" in args         # the game's arms as it turns them: shows what the rebuilding fixes
	if not FoundationLink.enabled():
		print("ELBOW AUDIT: SKIPPED (the foundation is off: no licensed data)")
		get_tree().quit(0)
		return
	Game.main = self
	Game.settings.sound = false
	if "practice" in args or "shootout" in args:
		await _close("practice" in args)
		_report()
		return
	var ids := DB.counties_ranked()
	m = load("res://game/match.gd").new()
	m.config = {"home": ids[0], "away": ids[3], "venue": "county", "user_team": -1, "seed": seed, "length": length, "mode": "sim_test"}
	m.set_meta("test", true)
	add_child(m)
	var limit := int(length * 60.0 * 30.0 * 1.6)
	while m.phase != m.P.OVER and frames < limit:
		if frames % 30 == 0:
			_hook()
		await get_tree().process_frame
		frames += 1
	_report()


## The practice's ten frees, or a shoot-out to a winner, aimed as a player would (the target low in the middle, or
## over the bar): every frame of every swing.
func _close(practice: bool) -> void:
	Game.settings.graphics = Game.GFX_HIGH
	if practice:
		m = load("res://game/practice.gd").new()
		m.config = {"home": "KIL", "away": "TIP", "venue": "county", "user_team": 0, "seed": 7, "mode": "practice"}
	else:
		m = load("res://game/match.gd").new()
		m.config = {"home": "KIL", "away": "TIP", "venue": "county", "user_team": 0, "seed": 5, "length": 8.0,
			"mode": "champ", "knockout": true}
	m.set_meta("test", true)
	add_child(m)
	await get_tree().process_frame
	await get_tree().process_frame
	if not practice:
		m._begin_shootout()
	var aim_t := -1.0
	while frames < 30 * 200:
		if frames % 10 == 0:
			_hook()
		if m.placed_aim != null and not m.placed_aim.stopped and m.user_buttons() == ["SHOOT"]:
			aim_t = frames if aim_t < 0.0 else aim_t
			if frames - aim_t > 20:
				m.placed_aim.angle = PI * 0.5 if frames % 2 == 0 else PI * 1.5
				m.placed_aim._place()
				m._on_action("SHOOT")
				m.placed_aim.bar_x = 0.0
				m._on_action("SHOOT")
				aim_t = -1.0
		if practice and String(m.practice.state) == "over" or not practice and m.phase == m.P.OVER:
			break
		await get_tree().process_frame
		frames += 1
	print("%s: %s" % ["practice" if practice else "shoot-out", m.practice.marks if practice else str(m.shootout.goals)])


func _hook() -> void:
	for n in m.find_children("*", "Player", true, false):
		var pl := n as Player
		if pl.link == null or _seen.has(pl.link.get_instance_id()):
			continue
		_seen[pl.link.get_instance_id()] = true
		var link: FoundationLink = pl.link
		link.reader.sound_arms = not _raw
		link.body.posed.connect(_check.bind(pl, link))


func _who(pl: Player) -> String:
	return pl.role if pl.role != "" else "%s #%d" % [["home", "away"][pl.team], pl.num]


func _check(pl: Player, link: FoundationLink) -> void:
	if not pl.visible_on_screen or not link.body.is_visible_in_tree():
		return    # (not drawn)
	var sk := link.body.skeleton
	var t: float = m.now
	var mode: String = link._mode
	# The feet: when the game's body has a foot on the grass, so has this one (not floating, not sunk).
	var tk0 := link.toon.skeleton
	var game_low := INF
	for c0 in ["l", "r"]:
		game_low = minf(game_low, (tk0.global_transform * tk0.get_bone_global_pose(tk0.find_bone("foot_" + c0))).origin.y)
	var rig_low := INF
	for sd in ["Left", "Right"]:
		rig_low = minf(rig_low, (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(sd + "Foot"))).origin.y)
	var game_rest := (tk0.global_transform * tk0.get_bone_global_rest(tk0.find_bone("foot_l"))).origin.y - tk0.global_transform.origin.y
	var rig_rest := (sk.global_transform * sk.get_bone_global_rest(sk.find_bone("LeftFoot"))).origin.y - sk.global_transform.origin.y
	var blending: bool = m.now - link.mode_since < 0.2
	if mode == "full" and not blending:
		# A move of the game's: its legs, its feet where it planted them. (Not in the moment it blends in or out of the
		# motion capture's.)
		if game_low - tk0.global_transform.origin.y < game_rest + 0.04 and pl.global_position.y < 0.05:
			_note(absf((rig_low - sk.global_transform.origin.y) - rig_rest) * 100.0, "rig feet off the ground (cm)", pl, mode, t, FEET_OFF)
	elif mode != "full" and pl.vel.length() < 4.5 and float(link.loco.get("_w_sprint")) < 0.05 \
			and int(link.loco.get("state")) != WsgLocomotor.State.JUMP:
		# The motion capture's legs, standing or jogging: a foot near the ground (a sprint's flight and a jump have
		# both well up), never both feet far up (a leg dragged sideways).
		_note(((rig_low - sk.global_transform.origin.y) - rig_rest) * 100.0, "rig feet in the air (cm)", pl, mode, t, FEET_AIR)
	for side in ["Left", "Right"]:
		# Bent backwards about the hinge (the forearm's own turn, after every modifier).
		var axis := Vector3.DOWN if side == "Left" else Vector3.UP
		var fi := sk.find_bone(side + "ForeArm")
		var q := sk.get_bone_pose_rotation(fi)
		var rest_dir := WsgRig.bone_axis(link.body.joints, side + "ForeArm")
		var d := q * rest_dir
		var flat := d - axis * d.dot(axis)
		var hinge := rad_to_deg(rest_dir.signed_angle_to(flat.normalized(), axis)) if flat.length_squared() > 1e-6 else 0.0
		_note(-hinge, "rig %s elbow backwards" % side, pl, mode, t, 3.0)
		var chest := sk.get_bone_global_pose(sk.find_bone("Spine2")).basis.get_rotation_quaternion()
		var s := sk.get_bone_global_pose(sk.find_bone(side + "Arm")).origin
		var e := sk.get_bone_global_pose(fi).origin
		var w := sk.get_bone_global_pose(sk.find_bone(side + "Hand")).origin
		_note(_twist(chest, s, e, w), "rig %s elbow turned" % side, pl, mode, t, TWIST_MAX)
		# The game's own arm.
		var tk := link.toon.skeleton
		var c := "l" if side == "Left" else "r"
		var tchest := tk.get_bone_global_pose(tk.find_bone("chest")).basis.get_rotation_quaternion()
		var ts := tk.get_bone_global_pose(tk.find_bone("upperarm_" + c)).origin
		var te := tk.get_bone_global_pose(tk.find_bone("forearm_" + c)).origin
		var tw := tk.get_bone_global_pose(tk.find_bone("hand_" + c)).origin
		_note(_twist(tchest, ts, te, tw), "game %s elbow turned" % side, pl, mode, t, TWIST_MAX)
		# Posed by the game (not the motion capture): bent as much as the game bends it.
		# (Not a hand held on the hurley's handle: that arm goes where the handle is, not as the game bends it.)
		var on_handle: bool = link.legacy.hold.has(side) and float(link.legacy.hold[side][2]) > 0.5
		var legacy_arm: bool = link.legacy.weight > 0.5 and (mode != "move" or (side == "Right" and pl.role == "")) and not on_handle
		if legacy_arm:
			var game_bend := rad_to_deg((te - ts).angle_to(tw - te))
			var rig_bend := rad_to_deg((e - s).angle_to(w - e))
			_note(game_bend - rig_bend, "rig %s elbow straightened" % side, pl, mode, t, STRAIGHTENED)
		# The wrist: the hand turned about the forearm.
		var fq := sk.get_bone_global_pose(fi).basis.get_rotation_quaternion()
		var hq := sk.get_bone_global_pose(sk.find_bone(side + "Hand")).basis.get_rotation_quaternion()
		var wt: Quaternion = WsgRig.swing_twist(fq.inverse() * hq, rest_dir)[1]
		_note(absf(rad_to_deg(WsgRig.twist_angle(wt, rest_dir))), "rig %s wrist turned" % side, pl, mode, t, WRIST_MAX)
		# The game's own wrist (its hand's turn about its forearm, which hangs down at rest).
		var tf := tk.get_bone_global_pose(tk.find_bone("forearm_" + c)).basis.get_rotation_quaternion()
		var th := tk.get_bone_global_pose(tk.find_bone("hand_" + c)).basis.get_rotation_quaternion()
		var gt: Quaternion = WsgRig.swing_twist(tf.inverse() * th, Vector3.DOWN)[1]
		_note(absf(rad_to_deg(WsgRig.twist_angle(gt, Vector3.DOWN))), "game %s wrist turned" % side, pl, mode, t, WRIST_MAX)
		# The fingers: none through the hurley's handle (either hand that is on it).
		if link.stick != null and link.stick.is_visible_in_tree():
			var into := _through(link, side) * 1000.0
			_note(into, "rig %s finger in the handle (mm)" % side, pl, mode, t, FINGER_IN)


## How far (m) the deepest finger of a hand goes into the hurley's handle, skin into wood (0: none; off it: 0).
func _through(link: FoundationLink, side: String) -> float:
	if not _handle.has(link):
		_handle[link] = _measure_handle(link)
	var hd: Array = _handle[link]
	if hd.is_empty():
		return 0.0
	var xf := link.stick.global_transform
	var mid: Vector3 = xf * (hd[0] as Vector3)
	var dir: Vector3 = (xf.basis * (hd[1] as Vector3)).normalized()
	var r: float = hd[2] * xf.basis.get_scale().x
	var half: float = hd[3] * xf.basis.get_scale().x
	var sk := link.body.skeleton
	var deepest := 0.0

	for f in ["Thumb", "Index", "Middle", "Ring", "Pinky"]:
		var pts := []
		for j in [1, 2, 3]:
			pts.append(link.body.global_transform * sk.get_bone_global_pose(sk.find_bone("%sHand%s%d" % [side, f, j])).origin)
		# The segments' middles too, and the tip. (The thumb's first joint is where it meets the wrist, inside the ball
		# of the thumb: a handle across the palm is always that near it. Its knuckle on are the thumb.)
		var tip: Vector3 = (pts[2] as Vector3) + ((pts[2] as Vector3) - (pts[1] as Vector3)) * 0.85
		pts.append(((pts[1] as Vector3) + (pts[2] as Vector3)) * 0.5)
		pts.append(tip)
		if f == "Thumb":
			pts.remove_at(0)
		else:
			pts.append(((pts[0] as Vector3) + (pts[1] as Vector3)) * 0.5)
		for pi in pts.size():
			var p: Vector3 = pts[pi]
			var d: Vector3 = p - mid
			var along := d.dot(dir)
			if absf(along) > half:
				continue
			var off := (d - dir * along).length()
			# The finger's skin into the handle (a finger is WsgGrip.FINGER_HALF from its middle to its skin).
			var into := r + WsgGrip.FINGER_HALF - off
			if off < 0.08:
				deepest = maxf(deepest, into)
	return deepest


## The handle, in the hurley's own space (the game's body's, at rest: HeroBody._hurley): the grip-taped part round the
## fist - [its middle, its direction, its radius, half its length].
static func _measure_handle(link: FoundationLink) -> Array:
	var hb := link.toon as HeroBody
	if hb == null:
		return []
	var rest_hand := link.toon.skeleton.get_bone_global_rest(link.toon.bone("hand_r")).origin
	var dir := HeroBody.HURLEY_DIR.normalized()
	var hh: Vector3 = rest_hand + hb._grip()
	return [hh + dir * 0.03, dir, 0.021, 0.11]


## How far (degrees) an elbow's bend is from the way it bends with the upper arm not turned about its length: the
## bend of an arm hanging is forward, and an arm raised or swung carries that with it (the shortest turn from
## hanging). 0 when the elbow is too straight to say, or the arm points almost straight up.
static func _twist(chest: Quaternion, s: Vector3, e: Vector3, w: Vector3) -> float:
	var inv := chest.inverse()
	var u := (inv * (e - s)).normalized()
	var f := (inv * (w - e)).normalized()
	if rad_to_deg(u.angle_to(f)) < BENT:
		return 0.0
	return absf(rad_to_deg(WsgLegacyPose.elbow_turn(u, f)))


func _note(deg: float, kind: String, pl: Player, mode: String, t: float, limit: float) -> void:
	if deg > limit:
		counts[kind] = int(counts.get(kind, 0)) + 1
	worst.append([deg, kind, _who(pl), pl.action if pl.action != "" else ("carry" if pl.ball_stick or pl.ball_hand else "run"), mode, t])
	if worst.size() > 4000:
		_trim()


func _trim() -> void:
	# The worst frame of each kind and action, the rest dropped.
	var best := {}
	for r in worst:
		var k: String = r[1] + "|" + r[3]
		if not best.has(k) or r[0] > best[k][0]:
			best[k] = r
	worst = best.values()


func _limit_of(kind: String) -> float:
	if kind.contains("backwards"):
		return 3.0
	if kind.contains("straightened"):
		return STRAIGHTENED
	if kind.contains("wrist"):
		return WRIST_MAX
	if kind.contains("finger"):
		return FINGER_IN
	if kind.contains("feet in the air"):
		return FEET_AIR
	if kind.contains("feet"):
		return FEET_OFF
	return TWIST_MAX


func _report() -> void:
	_trim()
	worst.sort_custom(func(a, b): return a[0] > b[0])
	print("elbow audit: %d frames (%.1f match min)" % [frames, frames / 1800.0])
	for r in worst.slice(0, 40):
		print("  %6.1f deg  %-24s %-10s %-14s mode %-5s t %.1f" % r)
	# The worst of each check, whoever and whenever.
	var per := {}
	for r in worst:
		if not per.has(r[1]) or r[0] > per[r[1]][0]:
			per[r[1]] = r
	var kinds := per.keys()
	kinds.sort()
	print("  worst of each:")
	for k in kinds:
		var r: Array = per[k]
		print("    %-34s %7.1f  (%s, %s, t %.1f)" % [k, r[0], r[2], r[3], r[5]])
	# Past a limit: by action (the worst of each).
	var past := worst.filter(func(r): return String(r[1]).begins_with("rig") and r[0] > _limit_of(r[1]))
	if not past.is_empty():
		print("  past a limit, by action:")
		for r in past:
			print("    %-34s %7.1f  (%s, %s, mode %s, t %.1f)" % [r[1], r[0], r[2], r[3], r[4], r[5]])
	var fail := worst.is_empty()
	if fail:
		print("  nothing was audited (no body drawn on the foundation: a script that does not compile?)")
	for k in counts:
		print("  %s: %d frames past the limit" % [k, counts[k]])
		if String(k).begins_with("rig"):
			fail = true
	print("ELBOW AUDIT %s" % ("FAIL" if fail else "PASS"))
	get_tree().quit(1 if fail else 0)
