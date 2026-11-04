extends Node
## godot --headless --path . --fixed-fps 30 res://tests/knee_probe.tscn -- [gfx 0/1/2] [seconds]
## Knees bent backwards, per actor: an autoplayed match's knees each frame - a knee bent over 15 degrees counts, and
## is backward when it lies more than 4 cm behind its hip-to-ankle line (forward: the way the athlete faces). Low by
## default (the game's own RiggedBody with the foundation's planter). Until the foundation's "knees" world rule is on
## the branch (2026-11-04: Kabaddi's Low officials bent knees backward with the planter's IK on seated legs).

var stats := {}   # actor -> [bent, backward, worst cm, state at the worst]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Game.main = self
	Game.settings.sound = false
	Game.loading_overlay = false
	Game.settings.graphics = int(args[0]) if args.size() > 0 else Game.GFX_LOW
	WsgFoundation.tier = Game.settings.graphics
	var secs := float(args[1]) if args.size() > 1 else 30.0
	Game.start_match({"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "autoplay": true, "length": 0,
		"difficulty": 1, "seed": 7})
	var m: Node = Game.current
	# From the first raid (as the owner note 2026-11-04-knees-forward measures).
	var g := 0
	while is_instance_valid(m) and m.phase != "raid" and g < 3600:
		await get_tree().process_frame
		g += 1
	for i in int(secs * 30.0):
		await get_tree().process_frame
		if not is_instance_valid(m):
			break
		for a in m.find_children("*", "Athlete", true, false):
			_measure(a)
	var keys := stats.keys()
	keys.sort()
	var tb := 0
	var tk := 0
	for k in keys:
		var s: Array = stats[k]
		tb += int(s[0])
		tk += int(s[1])
		if int(s[1]) > 0 or OS.get_environment("KP_ALL") != "":
			print("KNEE %-24s bent %5d backward %5d worst %5.1f cm (%s)" % [k, s[0], s[1], s[2], s[3]])
	print("KNEES gfx %d: %d of %d bent knee-frames backward, %d actors" % [int(Game.settings.graphics), tk, tb, keys.size()])
	get_tree().quit(0)


func _measure(a: Athlete) -> void:
	if a.model == null:
		return
	var link = a.model.get("link")
	if link != null and link.body != null and link.body.is_visible_in_tree():
		# Medium/High: the foundation's body as drawn (forward the way the foot points).
		var key2 := "%s %s" % [String(a.data.get("id", "?")), String(a.data.get("role", ""))]
		for sd in ["Left", "Right"]:
			var hip: Vector3 = link.body.bone_world(sd + "UpLeg").origin
			var knee: Vector3 = link.body.bone_world(sd + "Leg").origin
			var ank: Vector3 = link.body.bone_world(sd + "Foot").origin
			var toe: Vector3 = link.body.bone_world(sd + "ToeBase").origin
			if rad_to_deg((knee - hip).angle_to(ank - knee)) < 15.0:
				continue
			var f := Vector3(toe.x - ank.x, 0.0, toe.z - ank.z)
			if f.length() < 0.01:
				continue
			var line := ank - hip
			var t := clampf((knee - hip).dot(line) / maxf(line.length_squared(), 1e-6), 0.0, 1.0)
			var d := (knee - (hip + line * t)).dot(f.normalized())
			if not stats.has(key2):
				stats[key2] = [0, 0, 0.0, ""]
			stats[key2][0] += 1
			if d < -0.04:
				stats[key2][1] += 1
				print("BACK %s %s %s %.1f cm mode=%s w=%.2f every=%d vel=%s facing=%s toe=%s frame=%d" % [key2, sd, a.state,
					-d * 100.0, link.mode, link.legacy.weight, link.pose_every, a.move_vel, a.facing, f.normalized(),
					Engine.get_process_frames()])
				if -d * 100.0 > float(stats[key2][2]):
					stats[key2][2] = -d * 100.0
					stats[key2][3] = String(a.state)
		return
	if a.model.rig == null or a.model.rig.skeleton == null:
		return
	var rig: RiggedBody = a.model.rig
	var sk: Skeleton3D = rig.skeleton
	if not sk.is_visible_in_tree():
		return
	var fwd := Vector3(a.facing.x, 0.0, a.facing.z)
	if fwd.length() < 0.1:
		return
	fwd = fwd.normalized()
	var key := "%s %s" % [String(a.data.get("id", "?")), String(a.data.get("role", ""))]
	for s in ["l", "r"]:
		if not (rig._bone.has("thigh_" + s) and rig._bone.has("shin_" + s) and rig._bone.has("foot_" + s)):
			continue
		var hip := sk.global_transform * sk.get_bone_global_pose(int(rig._bone["thigh_" + s])).origin
		var knee := sk.global_transform * sk.get_bone_global_pose(int(rig._bone["shin_" + s])).origin
		var ank := sk.global_transform * sk.get_bone_global_pose(int(rig._bone["foot_" + s])).origin
		if rad_to_deg((knee - hip).angle_to(ank - knee)) < 15.0:
			continue
		# KP_FWD=foot: forward is the way this foot points (heel to toe), as a body's own hips would say - not the
		# athlete's facing (a seated scorer turned from his facing reads backward only this way).
		if OS.get_environment("KP_FWD") == "foot" and rig._bone.has("toe_" + s):
			var toe := sk.global_transform * sk.get_bone_global_pose(int(rig._bone["toe_" + s])).origin
			var f2 := Vector3(toe.x - ank.x, 0.0, toe.z - ank.z)
			if f2.length() > 0.01:
				fwd = f2.normalized()
		var line := ank - hip
		var t := clampf((knee - hip).dot(line) / maxf(line.length_squared(), 1e-6), 0.0, 1.0)
		var d := (knee - (hip + line * t)).dot(fwd)
		if not stats.has(key):
			stats[key] = [0, 0, 0.0, ""]
		stats[key][0] += 1
		if d < -0.04:
			stats[key][1] += 1
			if -d * 100.0 > float(stats[key][2]):
				stats[key][2] = -d * 100.0
				stats[key][3] = String(a.state)
