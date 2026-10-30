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
##   godot --headless --path . --fixed-fps 30 res://tests/elbow_audit.tscn -- [match minutes] [seed] [raw]

const TWIST_MAX := 115.0    # degrees: a humerus turns about 70 in and 90 out from neutral; past this it is wrong
const BENT := 25.0          # an elbow bent less than this has no direction to be wrong in
const STRAIGHTENED := 30.0  # degrees less bend on the rig than in the game's pose

var worst := []             # [deg, kind, who, action, mode, time]
var counts := {}
var frames := 0
var _seen := {}
var m: Node
var _raw := false


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
	var sk := link.body.skeleton
	var t: float = m.now
	var mode: String = link._mode
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
		var legacy_arm: bool = link.legacy.weight > 0.5 and (mode != "move" or (side == "Right" and pl.role == ""))
		if legacy_arm:
			var game_bend := rad_to_deg((te - ts).angle_to(tw - te))
			var rig_bend := rad_to_deg((e - s).angle_to(w - e))
			_note(game_bend - rig_bend, "rig %s elbow straightened" % side, pl, mode, t, STRAIGHTENED)


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


func _report() -> void:
	_trim()
	worst.sort_custom(func(a, b): return a[0] > b[0])
	print("elbow audit: %d frames (%.1f match min)" % [frames, frames / 1800.0])
	for r in worst.slice(0, 40):
		print("  %6.1f deg  %-24s %-10s %-14s mode %-5s t %.1f" % r)
	var fail := false
	for k in counts:
		print("  %s: %d frames past the limit" % [k, counts[k]])
		if String(k).begins_with("rig"):
			fail = true
	print("ELBOW AUDIT %s" % ("FAIL" if fail else "PASS"))
	get_tree().quit(1 if fail else 0)
