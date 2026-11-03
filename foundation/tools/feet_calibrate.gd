extends SceneTree
## Calibration for a low-foot jump bound: a game's walker (world.gd's walker(), or the test hurler) driven through a
## walk, jog, run, sprint, a cut at the sprint and a hard stop from it, every frame; for each frame a foot is low (its
## heel or toe under LOW of where it stands, this frame and the last) how far it moved in that frame (the smaller of
## the heel's and the toe's moves) and how much that move changed from the frame before (the smaller of the heel's and
## the toe's change, as vectors), and the jump: the smaller of the change into the frame and out of it (a jump goes
## still - far - still; a landing changes sharply on one side only, a take-off on the other). Prints each segment's
## count and maxima, and the worst jumps.
##   godot --headless --fixed-fps 30 --path . -s res://tools/wsg/feet_calibrate.gd -- [--game res://game/world.gd]
##       [--scale 1.0] [--json OUT.json]

const LOW := 0.10
const PATH := [[1.5, Vector2.ZERO, 0.0, "standing"], [3.0, Vector2(0, 1.3), NAN, "walk"], [3.0, Vector2(0, 3.5), NAN, "jog"],
	[3.0, Vector2(0, 6.0), NAN, "run"], [3.0, Vector2(0, 8.0), NAN, "sprint"], [2.0, Vector2(8.0, 0), NAN, "cut 90 at 8"],
	[2.0, Vector2.ZERO, NAN, "stop from 8"], [1.5, Vector2(0, -6.0), NAN, "run back"], [1.5, Vector2(0, 6.0), NAN, "cut 180 at 6"],
	[2.0, Vector2.ZERO, NAN, "stop from 6"]]


func _arg(args: PackedStringArray, key: String, def: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else def


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var game_path := _arg(args, "--game", "")
	var sc := float(_arg(args, "--scale", "1.0"))
	var holder := Node3D.new()
	root.add_child(holder)
	var bl: Array
	if game_path != "":
		var g: WsgWorldGame = load(game_path).new()
		bl = g.walker(holder)
	else:
		var body := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
		body.scale = Vector3.ONE * sc
		holder.add_child(body)
		bl = [body, WsgLocomotor.attach(body)]
	var body: WsgBody = bl[0]
	var loco: WsgLocomotor = bl[1]
	await process_frame
	var frames := []
	var segs := []
	await WsgWorldRules.drive(self, body, loco, PATH, func(_t: float, si: int):
		frames.append(WsgNoteChecks.feet(body))
		segs.append(si))
	var per := {}
	var perd := {}
	var worst := []
	var worstd := []
	var perj := {}
	var worstj := []
	for side in 2:
		var la := INF
		var lt := INF
		for f: Array in frames:
			la = minf(la, (f[side * 2] as Vector3).y)
			lt = minf(lt, (f[side * 2 + 1] as Vector3).y)
		for i in range(1, frames.size()):
			var a0: Vector3 = frames[i - 1][side * 2]
			var t0: Vector3 = frames[i - 1][side * 2 + 1]
			var a: Vector3 = frames[i][side * 2]
			var t: Vector3 = frames[i][side * 2 + 1]
			if minf(a0.y - la, t0.y - lt) >= LOW or minf(a.y - la, t.y - lt) >= LOW:
				continue
			var mv := minf(Vector2(a.x - a0.x, a.z - a0.z).length(), Vector2(t.x - t0.x, t.z - t0.z).length()) * 100.0
			var nm: String = PATH[segs[i]][3]
			if i >= 2:
				var a1: Vector3 = frames[i - 2][side * 2]
				var t1: Vector3 = frames[i - 2][side * 2 + 1]
				if minf(a1.y - la, t1.y - lt) < LOW:
					var da := Vector2(a.x - 2.0 * a0.x + a1.x, a.z - 2.0 * a0.z + a1.z).length()
					var dt := Vector2(t.x - 2.0 * t0.x + t1.x, t.z - 2.0 * t0.z + t1.z).length()
					var dd := minf(da, dt) * 100.0
					if not perd.has(nm):
						perd[nm] = []
					(perd[nm] as Array).append(dd)
					worstd.append([dd, nm, i, side, snappedf((a.y - la) * 100.0, 0.1), snappedf((t.y - lt) * 100.0, 0.1)])
			if i >= 2 and i + 1 < frames.size():
				# A jump: the frame's move changed sharply from the frame before AND to the frame after (still - far -
				# still). A landing changes on one side only (fast, fast, still), a take-off on the other.
				var a1: Vector3 = frames[i - 2][side * 2]
				var t1: Vector3 = frames[i - 2][side * 2 + 1]
				var a2: Vector3 = frames[i + 1][side * 2]
				var t2: Vector3 = frames[i + 1][side * 2 + 1]
				if minf(a1.y - la, t1.y - lt) < LOW and minf(a2.y - la, t2.y - lt) < LOW:
					var ja := minf(Vector2(a.x - 2.0 * a0.x + a1.x, a.z - 2.0 * a0.z + a1.z).length(),
						Vector2(a2.x - 2.0 * a.x + a0.x, a2.z - 2.0 * a.z + a0.z).length())
					var jt := minf(Vector2(t.x - 2.0 * t0.x + t1.x, t.z - 2.0 * t0.z + t1.z).length(),
						Vector2(t2.x - 2.0 * t.x + t0.x, t2.z - 2.0 * t.z + t0.z).length())
					var jj := minf(ja, jt) * 100.0
					if not perj.has(nm):
						perj[nm] = []
					(perj[nm] as Array).append(jj)
					worstj.append([jj, nm, i, side, snappedf((a.y - la) * 100.0, 0.1), snappedf((t.y - lt) * 100.0, 0.1)])
			if not per.has(nm):
				per[nm] = []
			(per[nm] as Array).append(mv)
			worst.append([mv, nm, i, side, snappedf((a.y - la) * 100.0, 0.1), snappedf((t.y - lt) * 100.0, 0.1)])
	var out := {}
	for seg: Array in PATH:
		var nm: String = seg[3]
		var v: Array = per.get(nm, [])
		v.sort()
		var n := v.size()
		var row := {"n": n, "p99": float(v[int(n * 0.99)]) if n else 0.0, "p999": float(v[mini(n - 1, int(n * 0.999))]) if n else 0.0,
			"max": float(v[-1]) if n else 0.0}
		var vd: Array = perd.get(nm, [])
		vd.sort()
		var nd := vd.size()
		row["d_p99"] = float(vd[int(nd * 0.99)]) if nd else 0.0
		row["d_max"] = float(vd[-1]) if nd else 0.0
		var vj: Array = perj.get(nm, [])
		vj.sort()
		var nj := vj.size()
		row["j_p99"] = float(vj[int(nj * 0.99)]) if nj else 0.0
		row["j_max"] = float(vj[-1]) if nj else 0.0
		out[nm] = row
		print("CAL %-14s n %4d  move max %5.1f | change max %5.1f | jump p99 %5.1f max %5.1f cm" % [nm, n, row["max"], row.d_max, row.j_p99, row.j_max])
	worst.sort_custom(func(x, y): return x[0] > y[0])
	for w in worst.slice(0, 4):
		print("CAL worst move %.1f cm  %s  frame %d  side %d  heel %.1f toe %.1f cm up" % w)
	worstj.sort_custom(func(x, y): return x[0] > y[0])
	for w in worstj.slice(0, 6):
		print("CAL worst jump %.1f cm  %s  frame %d  side %d  heel %.1f toe %.1f cm up" % w)
	var jp := _arg(args, "--json", "")
	if jp != "":
		var f := FileAccess.open(jp, FileAccess.WRITE)
		f.store_string(JSON.stringify({"segments": out, "worst": worst.slice(0, 10), "worst_change": worstd.slice(0, 10), "worst_jump": worstj.slice(0, 10)}))
	quit(0)
