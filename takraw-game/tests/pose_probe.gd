extends Node
## A move's pose measured the way tools/footage/pose_angles.py measures a traced one (MediaPipe's landmarks), to put
## the game's keys beside the footage: the trunk's lean, the right shoulder's flexion (the upper arm from the trunk's
## down line, + forward), the elbow's and knees' bends, and the right palm's height over the lower ankle and
## forward of the hips (m). Headless:
##   godot --headless --path . res://tests/pose_probe.tscn -- MOVE [steps] [w]

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var mv: String = a[0] if a.size() > 0 else "toss"
	if mv == "jitter":
		var rows := jolts(a.size() > 1 and a[1] == "w")
		rows.sort_custom(func(x, y): return float(x[1][0]) > float(y[1][0]))
		for row in rows:
			print("%-12s %6.1f mm/frame2  bone %s at %.2f" % [row[0], float(row[1][0]) * 1000.0, row[1][1], float(row[1][2])])
		get_tree().quit()
		return
	if mv == "trace":
		var r0 := RealBody.rig(false)
		var b := int(r0.index[a[2]])
		var n := int(Moves.length(a[1]) * 60.0)
		for i in n + 1:
			var t := float(i) / n
			if t < float(a[3]) or t > float(a[4]):
				continue
			var p := Moves.sample(a[1], t, a.size() > 5 and a[5] == "m")
			r0.solve(p)
			var pos: Vector3 = (r0.out_pos[b] as Vector3).rotated(Vector3.UP, deg_to_rad(float(p.get("yaw", 0.0)))) + Vector3(0, float(p.get("y", 0.0)), 0)
			print("%.3f yaw %7.1f y %.3f hips_y %.3f plant %s %s" % [t, float(p.get("yaw", 0.0)), float(p.get("y", 0.0)), float(p.get("hips_y", 0.0)), str(p.get("plant", "-")), pos])
		get_tree().quit()
		return
	var steps: int = int(a[1]) if a.size() > 1 else 10
	var women: bool = a.size() > 2 and a[2] == "w"
	var r := RealBody.rig(women)
	print("move %s (%s), %.2f s" % [mv, "women" if women else "men", Moves.length(mv)])
	print("   t   lean shFlex elbow kneeR kneeL palm_y palm_fwd palm-sh")
	for i in steps + 1:
		var t := float(i) / steps
		r.solve(Moves.sample(mv, t))
		print(row(r, t))
	get_tree().quit()


static func row(r: RealBody.Rig, t: float) -> String:
	var P := func(n: String) -> Vector3: return r.out_pos[int(r.index[n])]
	var hips: Vector3 = P.call("Hips")
	var sh_mid: Vector3 = (P.call("LeftArm") + P.call("RightArm")) * 0.5
	var up: Vector3 = sh_mid - hips
	var lean := rad_to_deg(atan2(up.z, up.y))
	var arm: Vector3 = P.call("RightForeArm") - P.call("RightArm")
	var flex := rad_to_deg(arm.angle_to(-up)) * (1.0 if arm.z >= 0.0 else -1.0)
	var elbow := 180.0 - rad_to_deg((P.call("RightArm") - P.call("RightForeArm")).angle_to(P.call("RightHand") - P.call("RightForeArm")))
	var knee := func(s: String) -> float:
		return 180.0 - rad_to_deg((P.call(s + "UpLeg") - P.call(s + "Leg")).angle_to(P.call(s + "Foot") - P.call(s + "Leg")))
	var hand: Vector3 = P.call("RightHand")
	var palm: Vector3 = hand + (hand - P.call("RightForeArm")).normalized() * 0.07
	var ankle := maxf(P.call("LeftFoot").y, P.call("RightFoot").y)
	return "%4.2f %5.0f %6.0f %5.0f %5.0f %5.0f %6.2f %8.2f %7.2f" % [t, lean, flex, elbow, knee.call("Right"), knee.call("Left"),
		palm.y - ankle, palm.z - hips.z, palm.y - P.call("RightArm").y]


## The worst jolt in each move: every bone's place 60 times a second (the body's yaw and lift included), and the
## largest second difference (m per frame per frame, at 60 fps) with the bone and the moment.
static func jolts(women: bool) -> Array:
	Moves._build()
	var r := RealBody.rig(women)
	var out := []
	var names: Array = Moves._moves.keys()
	for k in Moves._clips:
		if not names.has(k):
			names.append(k)
	var bone_name := {}
	for k in r.index:
		bone_name[int(r.index[k])] = k
	for mv in names:
		var n := maxi(3, int(Moves.length(mv) * 60.0))
		var prev := []
		var worst := [0.0, "", 0.0]
		for i in n + 1:
			var t := float(i) / n
			var p := Moves.sample(mv, t)
			r.solve(p)
			var yaw := deg_to_rad(float(p.get("yaw", 0.0)))
			var lift := float(p.get("y", 0.0))
			var now := []
			for b in r.count:
				now.append((r.out_pos[b] as Vector3).rotated(Vector3.UP, yaw) + Vector3(0, lift, 0))
			prev.append(now)
			if prev.size() == 3:
				for b in r.count:
					var d: float = ((prev[2][b] as Vector3) - 2.0 * (prev[1][b] as Vector3) + (prev[0][b] as Vector3)).length()
					if d > float(worst[0]):
						worst = [d, bone_name.get(b, str(b)), t]
				prev.pop_front()
		out.append([mv, worst])
	return out
