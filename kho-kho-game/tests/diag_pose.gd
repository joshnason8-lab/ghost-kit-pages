extends SceneTree
## WsgSim's pose and feet checks found T- and A-poses and sliding feet on Kho Kho's bodies (CI, with the licensed
## clips): what each body was doing when it happened. One match of game/sim.gd as WsgSim plays it (the same sampled
## quarter posed in full), each body read as WsgSim reads it (in its skeleton_updated), and every T/A-pose or slip over
## 2 cm printed with the athlete's act, FoundationLink's mode, pose_every and the frame. Prints at most 60 lines.
##   godot --headless --fixed-fps 30 --path . -s res://tests/diag_pose.gd -- KIND SEED

var _lines := 0


func _say(s: String) -> void:
	if _lines < 60:
		print("DIAG ", s)
	_lines += 1


func _initialize() -> void:
	for k in 30:
		await process_frame
	var a := OS.get_cmdline_user_args()
	var kind := String(a[0]) if a.size() > 0 else "targeted:fair"
	var sd := int(a[1]) if a.size() > 1 else 101
	var g: WsgSimGame = (load("res://game/sim.gd") as Script).new()
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var cfg := g.config(kind, rng)
	cfg["seed"] = sd
	cfg["kind"] = kind
	cfg["short"] = not kind.begins_with("targeted:") and sd % 4 != 0
	seed(sd)
	var m: Node = await g.start(cfg, sd, self)
	_say("config %s" % JSON.stringify(cfg))
	var bl0 := g.bodies()
	var watched := {}
	for bi in bl0.size():
		var wb: Variant = (bl0[bi] as Dictionary).get("body")
		if wb is WsgBody:
			(wb as WsgBody).set_sim_full(bi % 4 == sd % 4)
	if not bl0.any(func(b: Dictionary) -> bool: return b.get("body") is WsgBody):
		_say("no WsgBody (no licensed clips here, or Low): nothing to read")
		quit(0)
		return
	var counts := {}
	var last_feet := {}
	var still := {}   # (stuck, as WsgSim reads it: a body with a target over 1.5 m away, hardly moving) name -> [pos, s]
	for frame in 30 * 600:
		await process_frame
		var st := g.state()
		g.events()
		g.rules()
		if bool(st.get("finished", false)):
			break
		for b: Dictionary in g.bodies():
			var tgt: Vector3 = b.target
			var bp: Vector3 = b.pos
			if bool(b.active) and tgt != Vector3.INF and Vector2(tgt.x - bp.x, tgt.z - bp.z).length() > 1.5:
				var sv: Array = still.get(b.name, [bp, 0.0])
				if (sv[0] as Vector3).distance_to(bp) < 0.15:
					sv[1] = float(sv[1]) + 1.0 / 30.0
					if float(sv[1]) > 4.0 and float(sv[1]) < 4.04:
						for a3 in m.everyone():
							if g._who(a3) == b.name:
								_say("f%d %s still 4 s, target %s m away: act '%s', pos %s, goal %s, want %s, vel %s, d_state %s, to_square %s, phase %s" % [frame, b.name, snappedf(Vector2(tgt.x - bp.x, tgt.z - bp.z).length(), 0.1), a3.act, bp.snappedf(0.01), a3.goal, a3.want.snappedf(0.01), a3.vel.snappedf(0.01), m.d_state.get(a3, "-"), m._to_square.get(a3, "-"), m.phase])
				else:
					sv = [bp, 0.0]
				still[b.name] = sv
			else:
				still.erase(b.name)
		for a2 in m.everyone():
			if a2.link == null or not is_instance_valid(a2.link.body):
				continue
			var body: WsgBody = a2.link.body
			var id := body.get_instance_id()
			if not watched.has(id):
				watched[id] = true
				var who: String = g._who(a2)
				body.skeleton.skeleton_updated.connect(func():
					if not body.sim_full:
						return   # (as WsgSim: only the quarter posed in full is read - the rest skip the rig's modifiers)
					var p := WsgNoteChecks.t_or_a_pose(body)
					var key := "%s|%s|%s|%s" % [p, a2.act, a2.link.mode, body.sim_full]
					if p != "" and a2.act != "pole_turn":
						counts[key] = int(counts.get(key, 0)) + 1
						if int(counts[key]) <= 2:
							_say("f%d %s: %s, act '%s', link mode '%s', pose_every %d, sim full %s, vel %.1f" % [Engine.get_process_frames(), who, p, a2.act, a2.link.mode, a2.link.pose_every, body.sim_full, a2.vel.length()])
					var ft := WsgNoteChecks.feet(body)
					if last_feet.has(id):
						var was: Array = last_feet[id]
						for k in [0, 2]:
							var now_y := (ft[k] as Vector3).y
							var dxz := Vector2((ft[k] as Vector3).x - (was[k] as Vector3).x, (ft[k] as Vector3).z - (was[k] as Vector3).z).length()
							if now_y < 0.12 and (was[k] as Vector3).y < 0.12 and dxz > 0.02 and a2.vel.length() < 0.4:
								var fk := "slip|%s|%s|%s" % [a2.act, a2.link.mode, body.sim_full]
								counts[fk] = int(counts.get(fk, 0)) + 1
								if int(counts[fk]) <= 2:
									_say("f%d %s: a standing foot moved %.1f cm, act '%s', link mode '%s', pose_every %d, sim full %s" % [Engine.get_process_frames(), who, dxz * 100.0, a2.act, a2.link.mode, a2.link.pose_every, body.sim_full])
					last_feet[id] = ft)
	print("DIAG COUNTS ", JSON.stringify(counts))
	g.stop()
	quit(0)
