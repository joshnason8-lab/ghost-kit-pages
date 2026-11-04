class_name WsgWorldRules
extends RefCounted
## The world rules' checks (docs/WORLD_RULES.md), each on the game's own code through its WsgWorldGame hooks. Run by
## tools/world_check.gd (wsg_world_check); each returns {"rule", "status": "pass" | "fail" | "not wired", "lines": what
## it measured, "fails": what broke the rule}.

## A planted foot's worst slip in any one step (cm), walking, jogging, turning, running and stopping (the lead, item 5:
## "feet planted, 2 cm slip a step at most").
const FEET_MAX_CM := 2.0
## A standing foot's toe off the ground with its heel down (cm): boots resting toe-up (Hurling 0.20).
const TOE_UP_MAX_CM := 1.0
## A low foot's jump in one frame (WsgNoteChecks.foot_slip's jump_cm), at most: 1.6 times the most any game's walker
## reads walking to sprinting and cutting at 8 m/s (15.4 cm, tools/feet_calibrate, 2026-11-03; the lead chose 25).
const JUMP_MAX_CM := 25.0
## The stick's way against the camera's (degrees; WsgNoteChecks.joystick).
const STICK_TOL := 25.0
## The loading overlay must be up within this many frames of the tap (the tap's own frame: 0).
const LOADING_FRAMES := 1
const DT := 1.0 / 30.0
const ACCEL := 9.0
const DECEL := 12.0
## A match's moves: [seconds, velocity wanted (x, z m/s), facing (degrees; NAN: the way it moves), name].
const MATCH_PATH := [[1.5, Vector2.ZERO, 0.0, "standing"], [2.5, Vector2(0, 1.3), NAN, "walk"],
	[2.0, Vector2(0, 3.5), NAN, "jog"], [2.0, Vector2(3.5, 0), NAN, "jog, turned"], [2.5, Vector2(6.0, 0), NAN, "run"],
	[1.5, Vector2.ZERO, NAN, "stop"], [2.0, Vector2.ZERO, NAN, "standing again"]]


static func result(rule: String) -> Dictionary:
	return {"rule": rule, "status": "pass", "lines": [], "fails": [], "warnings": []}


## A passing reading close to its bound: warned (the lead, 2026-11-03: Kabaddi's stop jump read 24.1 against 25 - too
## close to pass quietly). Within NEAR_CM of a bound in centimetres; for a bound of a few centimetres (2 cm), within
## NEAR_FRACTION of it (3 cm there would warn on everything).
const NEAR_CM := 3.0
const NEAR_FRACTION := 0.15


static func _near(r: Dictionary, what: String, value: float, bound: float) -> void:
	var margin := minf(NEAR_CM, bound * NEAR_FRACTION) if bound < NEAR_CM * 4.0 else NEAR_CM
	if value <= bound and value >= bound - margin:
		r.warnings.append("%s: %.1f cm, within %.1f cm of the %.1f cm bound" % [what, value, bound - value, bound])


static func _close(r: Dictionary) -> Dictionary:
	if r.status == "pass" and not (r.fails as Array).is_empty():
		r.status = "fail"
	return r


static func _not_wired(r: Dictionary, hook: String) -> Dictionary:
	r.status = "not wired"
	r.fails.append("the game's world.gd does not fill in %s()" % hook)
	return r


## Drives BODY along SEGMENTS ([seconds, wanted velocity (x, z), facing degrees or NAN, ...]) as a game drives its
## players (accelerating at 9 m/s/s, stopping at 12); ON_FRAME(t, segment) once each frame's pose is final (inside
## skeleton_updated: read there, the pose is the drawn one - after the frame the bones are back to the clip's).
static func drive(tree: SceneTree, body: WsgBody, loco: WsgLocomotor, segments: Array, on_frame: Callable) -> void:
	var vel := Vector2.ZERO
	var pos := body.position
	var t := 0.0
	var facing := 0.0
	var turn_a := 0.0
	for si in segments.size():
		var seg: Array = segments[si]
		var end := t + float(seg[0])
		# (A fifth element: a turning run - the wanted way swings round at that many rad/s from the way he faces, at the
		# segment's speed: Pok Ta Pok's AI turns 9 rad/s while it speeds up.)
		var turning := seg.size() > 4 and float(seg[4]) != 0.0
		turn_a = facing
		while t < end:
			var want: Vector2 = seg[1]
			if turning:
				turn_a += float(seg[4]) * DT
				want = Vector2(sin(turn_a), cos(turn_a)) * (seg[1] as Vector2).length()
			var lim := (ACCEL if want.length() > vel.length() else DECEL) * DT
			vel = vel.move_toward(want, lim)
			if is_nan(float(seg[2])):
				if vel.length() > 0.3:
					facing = atan2(vel.x, vel.y)
			else:
				facing = deg_to_rad(float(seg[2]))
			pos += Vector3(vel.x, 0, vel.y) * DT
			body.position = pos
			# Every frame, as a game drives its players (until 2026-11-04 it took two frames a step: the pose advances only
			# inside drive, so the hurler's numbers are the same, but a modifier keeping its own frame-by-frame state ran
			# twice a step there and once in a game).
			loco.drive(DT, Vector3(vel.x, 0, vel.y), facing, Vector3(want.x, 0, want.y))
			# (A body the game advances itself - set_manual - is posed only when advanced: Hurling's hung the walk.)
			if body.manual:
				body.call_deferred("advance", DT)
			# The frame's own pass - the pose as drawn (the locomotor's drive poses it once already, inside the call).
			await body.skeleton.skeleton_updated
			on_frame.call(t, si)
			# (Out of skeleton_updated before the next drive: poses set inside it are undone.)
			await tree.process_frame
			t += DT


## feet: the game's player driven along MATCH_PATH; every step's planted foot slips FEET_MAX_CM at most, a standing
## foot rests flat (toe up TOE_UP_MAX_CM at most), and it is never in a T- or A-pose.
static func feet(game: WsgWorldGame, parent: Node) -> Dictionary:
	var r := result("feet")
	var bl := game.walker(parent)
	if bl.is_empty():
		return _not_wired(r, "walker")
	var body: WsgBody = bl[0]
	var loco: WsgLocomotor = bl[1]
	var tree := parent.get_tree()
	await tree.process_frame
	var frames := {}
	var poses := {}
	await drive(tree, body, loco, MATCH_PATH, func(_t: float, si: int):
		if not frames.has(si):
			frames[si] = []
		(frames[si] as Array).append(WsgNoteChecks.feet(body))
		var p := WsgNoteChecks.t_or_a_pose(body)
		if p != "":
			poses[si] = p)
	for si in MATCH_PATH.size():
		var name: String = MATCH_PATH[si][3]
		var s := WsgNoteChecks.foot_slip(frames.get(si, []))
		var moving := (MATCH_PATH[si][1] as Vector2).length() > 0.0 or si == 5
		r.lines.append("%-15s %2d steps, worst slip %.1f cm, mean %.1f cm, skid %.1f cm, jump %.1f cm%s" % [name, s.steps, s.max_cm,
			s.mean_cm, s.skid_cm, s.jump_cm, "" if moving else ", toe up %.1f cm" % s.toe_up_cm])
		_near(r, "%s: a planted foot's slip" % name, float(s.max_cm), FEET_MAX_CM)
		_near(r, "%s: a flat foot's skid" % name, float(s.skid_cm), FEET_MAX_CM)
		_near(r, "%s: a low foot's jump" % name, float(s.jump_cm), JUMP_MAX_CM)
		if float(s.max_cm) > FEET_MAX_CM:
			r.fails.append("%s: a planted foot slid %.1f cm in one step (%.1f at most)" % [name, s.max_cm, FEET_MAX_CM])
		if float(s.skid_cm) > FEET_MAX_CM:
			r.fails.append("%s: a foot flat on the ground slid %.1f cm in one frame (%.1f at most)" % [name, s.skid_cm, FEET_MAX_CM])
		if float(s.jump_cm) > JUMP_MAX_CM:
			r.fails.append("%s: a foot low over the ground jumped %.1f cm in one frame (%.0f at most)" % [name, s.jump_cm, JUMP_MAX_CM])
		if not moving and float(s.toe_up_cm) > TOE_UP_MAX_CM:
			r.fails.append("%s: a standing foot's toe is %.1f cm off the ground (%.1f at most)" % [name, s.toe_up_cm, TOE_UP_MAX_CM])
		if poses.has(si):
			r.fails.append("%s: the player stands in a %s" % [name, poses[si]])
	body.queue_free()
	return _close(r)


## feet_low: the feet rule on what the game draws at Low (WsgWorldGame.walker_low): its own body driven along the match
## path by the game's own drive, its feet read as drawn; "foundation" passes (the feet rule measured that body).
static func feet_low(game: WsgWorldGame, parent: Node) -> Dictionary:
	var r := result("feet_low")
	var w: Variant = game.walker_low(parent)
	if w == null:
		return _not_wired(r, "walker_low")
	if w is String and w == "foundation":
		r.lines.append("Low draws the foundation's bodies: the feet rule measured them")
		return _close(r)
	if not (w is Array and (w as Array).size() >= 3 and w[1] is Callable and w[2] is Callable):
		r.fails.append("walker_low() returned %s: want \"foundation\" or [body, drive, feet]" % [w])
		return _close(r)
	var body: Node = w[0]
	var drive_fn: Callable = w[1]
	var feet_fn: Callable = w[2]
	var tree := parent.get_tree()
	await tree.process_frame
	var frames := {}
	var vel := Vector2.ZERO
	var facing := 0.0
	for si in MATCH_PATH.size():
		var seg: Array = MATCH_PATH[si]
		var n := int(float(seg[0]) / DT)
		frames[si] = []
		for k in n:
			var want: Vector2 = seg[1]
			vel = vel.move_toward(want, (ACCEL if want.length() > vel.length() else DECEL) * DT)
			if is_nan(float(seg[2])):
				if vel.length() > 0.3:
					facing = atan2(vel.x, vel.y)
			else:
				facing = deg_to_rad(float(seg[2]))
			drive_fn.call(DT, Vector3(vel.x, 0, vel.y), facing)
			await tree.process_frame
			(frames[si] as Array).append(feet_fn.call())
	for si in MATCH_PATH.size():
		var name: String = MATCH_PATH[si][3]
		var s := WsgNoteChecks.foot_slip(frames.get(si, []))
		r.lines.append("Low: %-15s %2d steps, worst slip %.1f cm, skid %.1f cm, jump %.1f cm" % [name, s.steps, s.max_cm, s.skid_cm, s.jump_cm])
		_near(r, "Low: %s: a planted foot's slip" % name, float(s.max_cm), FEET_MAX_CM)
		_near(r, "Low: %s: a flat foot's skid" % name, float(s.skid_cm), FEET_MAX_CM)
		_near(r, "Low: %s: a low foot's jump" % name, float(s.jump_cm), JUMP_MAX_CM)
		if float(s.max_cm) > FEET_MAX_CM:
			r.fails.append("Low: %s: a planted foot slid %.1f cm in one step (%.1f at most)" % [name, s.max_cm, FEET_MAX_CM])
		if float(s.skid_cm) > FEET_MAX_CM:
			r.fails.append("Low: %s: a foot flat on the ground slid %.1f cm in one frame (%.1f at most)" % [name, s.skid_cm, FEET_MAX_CM])
		if float(s.jump_cm) > JUMP_MAX_CM:
			r.fails.append("Low: %s: a foot low over the ground jumped %.1f cm in one frame (%.0f at most)" % [name, s.jump_cm, JUMP_MAX_CM])
	if is_instance_valid(body):
		body.queue_free()
	return _close(r)


## Plays every mode the game has: each started as the tap does (WsgWorldGame.start_mode), its loading watched from the
## tap's frame, then PLAY_SECONDS of it watched (its bodies' and officials' drawn poses), then its cameras taken.
## [{mode, root, cover_frame (frames after the tap the overlay was up; -1 never), load_frames, bodies, officials,
## poses: {name: what}, blocks: {name: why}, cams}] - each mode's root freed after the caller is done (free_modes).
static func play_modes(game: WsgWorldGame, parent: Node) -> Array:
	var tree := parent.get_tree()
	var out := []
	for mode: String in game.modes():
		var holder := Node.new()
		holder.name = "Mode_" + mode.validate_node_name()
		parent.add_child(holder)
		await tree.process_frame
		var m := {"mode": mode, "root": holder, "cover_frame": -1, "load_frames": 0, "bodies": [], "officials": [],
			"poses": {}, "pose_excused": {}, "blocks": {}, "cams": []}
		var f0 := Engine.get_process_frames()
		game.start_mode(mode, holder)
		if _covering(holder):
			m.cover_frame = 0
		var waited := 0
		while waited < 30 * 120:
			await tree.process_frame
			waited += 1
			if m.cover_frame < 0 and _covering(holder):
				m.cover_frame = Engine.get_process_frames() - f0
			if m.cover_frame >= 0 and not WsgLoading.busy():
				break
			if m.cover_frame < 0 and waited > 30 * 5:
				break
		m.load_frames = waited
		var want := {"on": false}
		var hooked := {}
		var frames := int(game.play_seconds(mode) * 30.0)
		for f in frames:
			var bodies := game.find_bodies(holder)
			var offs := game.find_officials(holder)
			for b: WsgBody in bodies:
				_watch(game, b, b.name, m, want, hooked)
			for o: Node in offs:
				var ob: Variant = o.get("body") if o.get("body") is WsgBody else (o if o is WsgBody else null)
				if ob:
					_watch(game, ob, "official " + o.name, m, want, hooked)
				var why := WsgNoteChecks.block_figure(o)
				if why != "":
					m.blocks["official " + o.name] = why
			if f % 10 == 0:
				for b: WsgBody in bodies:
					var why := WsgNoteChecks.block_figure(b)
					if why != "":
						m.blocks[String(b.name)] = why
			want.on = f % 5 == 0
			await tree.process_frame
			m.bodies = bodies
			m.officials = offs
		want.on = false
		m.cams = game.cameras(mode, holder)
		# Done with: stopped and hidden, its cameras kept for the joystick rule (every mode left playing and drawing
		# under the later rules took Kabaddi's run past 50 minutes on software GL).
		holder.process_mode = Node.PROCESS_MODE_DISABLED
		for c in holder.get_children():
			if c is Node3D or c is CanvasItem:
				c.visible = false
		out.append(m)
	return out


static func free_modes(modes: Array) -> void:
	for m: Dictionary in modes:
		if is_instance_valid(m.root):
			(m.root as Node).queue_free()


static func _covering(under: Node) -> bool:
	var ld := WsgLoading.current()
	return ld != null and ld.is_inside_tree() and ld.visible


## Records BODY's T/A-pose as drawn (inside skeleton_updated) on the frames WANT.on is set - unless the game declares
## that pose by design then (WsgWorldGame.pose_excuse: counted with its reason, not failed).
static func _watch(game: WsgWorldGame, body: WsgBody, name: String, m: Dictionary, want: Dictionary, hooked: Dictionary) -> void:
	var id := body.get_instance_id()
	if hooked.has(id):
		return
	hooked[id] = true
	body.skeleton.skeleton_updated.connect(func():
		if want.on and is_instance_valid(body):
			var p := WsgNoteChecks.t_or_a_pose(body)
			if p != "":
				var why := game.pose_excuse(body)
				if why != "":
					m.pose_excused[why] = int(m.pose_excused.get(why, 0)) + 1
				else:
					m.poses[name] = p)


## pose: no body in any mode stands in a T- or A-pose, and none is a block figure (primitive shapes, no skinned body).
static func pose(game: WsgWorldGame, modes: Array) -> Dictionary:
	var r := result("pose")
	if game.modes().is_empty():
		return _not_wired(r, "modes")
	for m: Dictionary in modes:
		r.lines.append("%s: %d bodies, %d officials watched; T/A-poses: %d, block figures: %d" % [m.mode,
			(m.bodies as Array).size(), (m.officials as Array).size(), (m.poses as Dictionary).size(), (m.blocks as Dictionary).size()])
		if (m.bodies as Array).is_empty() and (m.officials as Array).is_empty():
			r.fails.append("%s: no bodies found (find_bodies)" % m.mode)
		for n in m.poses:
			r.fails.append("%s: %s stands in a %s" % [m.mode, n, m.poses[n]])
		for why in m.get("pose_excused", {}):
			r.lines.append("%s: excused by the game (%s): %d frames" % [m.mode, why, m.pose_excused[why]])
		for n in m.blocks:
			r.fails.append("%s: %s is a block figure: %s" % [m.mode, n, m.blocks[n]])
	return _close(r)


## officials: each mode has the officials it should, each a person on the rig (skinned, moving, never a T- or A-pose)
## dressed as an official: a kit of their own, not a player's.
static func officials(game: WsgWorldGame, modes: Array) -> Dictionary:
	var r := result("officials")
	if game.modes().is_empty():
		return _not_wired(r, "modes")
	for m: Dictionary in modes:
		var want := game.officials(m.mode)
		if want < 0:
			return _not_wired(r, "officials")
		var offs: Array = m.officials
		r.lines.append("%s: %d officials (%d expected)" % [m.mode, offs.size(), want])
		if offs.size() < want:
			r.fails.append("%s: %d officials on the field, %d expected" % [m.mode, offs.size(), want])
		var kits := []
		# (Untyped: a typed loop variable is assigned before the check, and a body the game has freed since - a mode
		# replacing the last - stopped the rule with an error; world_check then never finished. Hurling, Floorball.)
		for b in m.bodies:
			if is_instance_valid(b) and b is WsgBody:
				kits.append_array(_kits(b))
		for o in offs:
			if not is_instance_valid(o):
				continue
			var ob: Variant = o.get("body") if o.get("body") is WsgBody else (o if o is WsgBody else null)
			if ob == null:
				r.fails.append("%s: official %s is not a person on the rig (no WsgBody)" % [m.mode, o.name])
				continue
			var mine := _kits(ob)
			if mine.is_empty():
				r.fails.append("%s: official %s wears no kit of their own (no material on the body)" % [m.mode, o.name])
			for k in mine:
				for pk in kits:
					if _same_kit(k, pk):
						r.fails.append("%s: official %s is dressed in a player's kit" % [m.mode, o.name])
						break
	return _close(r)


static func _kits(b: WsgBody) -> Array:
	var out := []
	var mi := b.mesh_instance
	if mi == null:
		return out
	if mi.material_override:
		out.append(mi.material_override)
	for s in mi.get_surface_override_material_count():
		if mi.get_surface_override_material(s):
			out.append(mi.get_surface_override_material(s))
	return out


static func _same_kit(a: Material, b: Material) -> bool:
	if a == b:
		return true
	if a is StandardMaterial3D and b is StandardMaterial3D:
		var ca := (a as StandardMaterial3D).albedo_color
		var cb := (b as StandardMaterial3D).albedo_color
		return Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length() < 0.08 and (a as StandardMaterial3D).albedo_texture == (b as StandardMaterial3D).albedo_texture
	return false


## loading: every mode's tap puts the loading overlay up within LOADING_FRAMES frames (the tap's own: 0), and it comes
## down when the mode is ready.
static func loading(game: WsgWorldGame, modes: Array) -> Dictionary:
	var r := result("loading")
	if game.modes().is_empty():
		return _not_wired(r, "modes")
	for m: Dictionary in modes:
		var cf: int = m.cover_frame
		r.lines.append("%s: the overlay up %s; down after %d frames" % [m.mode, "in the tap's frame" if cf == 0 else ("%d frames after the tap" % cf if cf > 0 else "never"), m.load_frames])
		if cf < 0:
			r.fails.append("%s: no loading overlay after the tap (WsgLoading.cover)" % m.mode)
		elif cf > LOADING_FRAMES:
			r.fails.append("%s: the loading overlay came up %d frames after the tap (%d at most)" % [m.mode, cf, LOADING_FRAMES])
		elif m.load_frames >= 30 * 120:
			r.fails.append("%s: still loading after 120 s" % m.mode)
	return _close(r)


## joystick: on every camera of every mode, the game's own stick mapping moves the body the camera's way, wherever on
## the screen it is (WsgNoteChecks.joystick, STICK_TOL degrees).
static func joystick(game: WsgWorldGame, modes: Array) -> Dictionary:
	var r := result("joystick")
	var map := game.stick_map()
	if not map.is_valid():
		return _not_wired(r, "stick_map")
	var any := false
	for m: Dictionary in modes:
		var cams: Array = (m.cams as Array).filter(func(c: Variant) -> bool: return is_instance_valid(c) and c is Camera3D)
		if cams.is_empty():
			continue
		any = true
		var fails := WsgNoteChecks.joystick(map, cams, STICK_TOL)
		r.lines.append("%s: %d cameras (%s), %s" % [m.mode, cams.size(), ", ".join(cams.map(func(c: Camera3D) -> String: return String(c.name))),
			"the stick the camera's way on all" if fails.is_empty() else "%d faults" % fails.size()])
		for f in fails:
			r.fails.append("%s: %s" % [m.mode, f])
	if not any:
		return _not_wired(r, "cameras")
	return _close(r)


## tiers: every mode at each tier the player can choose (Low, Medium, High) keeps to that tier (item 3): it never
## puts the tier up (Hurling's practice forced High: 2,400 fans, a 9.7 s start), its 3D crowd is within the tier's
## budget (WsgFoundation.crowd_budget of crowd_quality), at most full_bodies() bodies are drawn in full, and - with a
## renderer (xvfb, opengl3) - a frame draws no more triangles or draw calls than WsgFoundation.frame_budget. A mode the
## owner lets run higher names their note in tier_exceptions(). Headless, the drawn counts are not measured (the
## scene's own triangle count, not culled, is reported instead).
## Frames a tier's start is drawn before its counts are read (30 until 2026-11-03: Kabaddi's 12 starts, each 30
## frames drawn in software on CI, took 15 of the world check's 52 minutes; the counts are the same after a few).
static var TIER_FRAMES := 5


static func tiers(game: WsgWorldGame, parent: Node) -> Dictionary:
	var r := result("tiers")
	if game.modes().is_empty():
		return _not_wired(r, "modes")
	var tree := parent.get_tree()
	var excused := game.tier_exceptions()
	var drawn := DisplayServer.get_name() != "headless" and parent is Viewport
	var was := WsgFoundation.tier
	var warm_was := WsgLoading.skip_warm
	WsgLoading.skip_warm = true
	for mode: String in game.modes():
		if excused.has(mode):
			r.lines.append("%s: excused by the owner: %s" % [mode, excused[mode]])
			continue
		for t in [WsgFoundation.LOW, WsgFoundation.MEDIUM, WsgFoundation.HIGH]:
			WsgFoundation.over_tier.clear()
			game.set_tier(t)
			var holder := Node.new()
			holder.name = "Tier%d_%s" % [t, mode.validate_node_name()]
			parent.add_child(holder)
			await tree.process_frame
			var t0 := Time.get_ticks_msec()
			game.start_mode(mode, holder)
			var waited := 0
			while waited < 30 * 120:
				await tree.process_frame
				waited += 1
				if waited > 2 and not WsgLoading.busy():
					break
			var start_ms := Time.get_ticks_msec() - t0
			# (The most any of those frames drew: the camera moves, a frame's counts by a few.)
			var vpd := parent as Viewport if drawn else null
			var tris_max := 0
			var dcs_max := 0
			for f in TIER_FRAMES:
				await tree.process_frame
				if vpd:
					tris_max = maxi(tris_max, vpd.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
					dcs_max = maxi(dcs_max, vpd.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
			var now_tier := WsgFoundation.tier
			var fans := 0
			for c in holder.find_children("*", "WsgCrowd3D", true, false):
				fans += (c as WsgCrowd3D).used.size()
			var bodies := holder.find_children("*", "WsgBody", true, false)
			var full := bodies.filter(func(b: WsgBody) -> bool: return b.full).size()
			# (The most any quality the tier allows can build: on the budget profile Close, 3, builds fewer fans than 2 -
			# Kabaddi's High asked 2 and built its 700, within the tier, and was failed against Close's 500.)
			var fans_max := 0
			for q in range(1, WsgFoundation.crowd_most() + 1):
				fans_max = maxi(fans_max, int(WsgFoundation.crowd_budget(q)[1]))
			var full_max := WsgFoundation.full_bodies()
			var tag := "%s at %s" % [mode, ["Low", "Medium", "High"][t]]
			var line := "%s: tier %d after the start, %d 3D fans (at most %d), %d of %d bodies in full (at most %d), started in %.1f s (this machine)" % [
				tag, now_tier, fans, fans_max, full, bodies.size(), full_max, start_ms / 1000.0]
			if drawn:
				var vp := parent as Viewport
				var tris := maxi(tris_max, vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
				var dcs := maxi(dcs_max, vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
				var fb := WsgFoundation.frame_budget(t)
				line += ", drawn %d triangles in %d draw calls (at most %d, %d)" % [tris, dcs, fb.triangles, fb.draw_calls]
				if tris > int(fb.triangles):
					r.fails.append("%s: a frame draws %d triangles, over the tier's %d" % [tag, tris, fb.triangles])
				if dcs > int(fb.draw_calls):
					r.fails.append("%s: a frame makes %d draw calls, over the tier's %d" % [tag, dcs, fb.draw_calls])
			else:
				line += ", the scene holds %d triangles (not culled; drawn counts need a renderer)" % _scene_triangles(holder)
			# What the start left outside the parent it was given (start_mode must replace what the last call started,
			# as a tap does: Hurling's kept its last match drawing - 524k triangles, 154 draw calls at Low).
			var outside := _scene_triangles(tree.root) - _scene_triangles(holder)
			if outside > 0:
				line += "; %d triangles outside the parent start_mode was given (the last mode's? see ADOPTING 5.18)" % outside
			r.lines.append(line)
			if now_tier > t:
				r.fails.append("%s: the mode put the graphics tier up to %d (the player chose %d)" % [tag, now_tier, t])
			if fans > fans_max:
				r.fails.append("%s: %d 3D fans, over the tier's %d" % [tag, fans, fans_max])
			if full > full_max:
				r.fails.append("%s: %d bodies drawn in full detail, over the tier's %d (WsgFoundation.rank_detail)" % [tag, full, full_max])
			for o: Dictionary in WsgFoundation.over_tier:
				r.lines.append("%s: asked for a %s of quality %d, built at %d (the tier's most)" % [tag, o.what, o.wanted, o.got])
			holder.queue_free()
			await tree.process_frame
			while WsgLoading.busy():
				await tree.process_frame
	game.set_tier(was)
	WsgLoading.skip_warm = warm_was
	return _close(r)


static func _scene_triangles(root: Node) -> int:
	var n := 0
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		if not (g as GeometryInstance3D).is_visible_in_tree():
			continue
		if g is MeshInstance3D and (g as MeshInstance3D).mesh:
			n += _mesh_tris((g as MeshInstance3D).mesh)
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh and (g as MultiMeshInstance3D).multimesh.mesh:
			var mm := (g as MultiMeshInstance3D).multimesh
			n += _mesh_tris(mm.mesh) * (mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count)
	return n


static func _mesh_tris(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var idx: Variant = a[Mesh.ARRAY_INDEX]
		n += ((idx as PackedInt32Array).size() if idx != null and (idx as PackedInt32Array).size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


## How long each mode is watched at each tier for the knees rule (frames at 30 fps; a knee read every frame).
static var KNEE_FRAMES := 240
## A body's backward knees fail "knees" (what the owner saw) when they hold more than KNEE_RUN frames running, or come on
## more than KNEE_SHARE of its bent knee-frames, or any one goes more than KNEE_GROSS_CM behind. Fewer and smaller -
## single strays - fail "knee_strays" (the lead, 2026-11-04: deferred to 11-13 12:00, "planter step swing flick, #82").
const KNEE_RUN := 2
const KNEE_SHARE := 0.005
const KNEE_GROSS_CM := 15.0
## knee_strays' lines and fails from the last knees() run (one pass reads both).
static var knee_strays_last := {}


## knees: in every mode at every tier the player can choose, no knee drawn bends backwards - every skeleton under the
## mode (the foundation's bodies, and a game's own: a RiggedBody, a ModelBody, a toon, a RealBody), read as drawn inside
## skeleton_updated, its knee no more than WsgNoteChecks.KNEE_BACK behind its hip-ankle line against the body's forward.
## A named acrobatic move the game declares (knee_excuse) is counted with its reason, not failed. (The owner, 2026-11-04,
## Sepak Takraw on the A16: "broken backwards knees" - its own Low bodies, never measured by the pose rule's WsgBody.)
## A body's knees backward more than KNEE_RUN frames running, on more than KNEE_SHARE of its bent knee-frames, or any
## over KNEE_GROSS_CM fail this rule; fewer, smaller strays go to "knee_strays" (knee_strays_last).
static func knees(game: WsgWorldGame, parent: Node) -> Dictionary:
	var r := result("knees")
	var rs := result("knee_strays")
	knee_strays_last = rs
	if game.modes().is_empty():
		_not_wired(rs, "modes")
		return _not_wired(r, "modes")
	var tree := parent.get_tree()
	var was := WsgFoundation.tier
	var warm_was := WsgLoading.skip_warm
	WsgLoading.skip_warm = true
	for mode: String in game.modes():
		for t in [WsgFoundation.LOW, WsgFoundation.MEDIUM, WsgFoundation.HIGH]:
			game.set_tier(t)
			var holder := Node.new()
			holder.name = "Knees%d_%s" % [t, mode.validate_node_name()]
			parent.add_child(holder)
			await tree.process_frame
			game.start_mode(mode, holder)
			var waited := 0
			while waited < 30 * 120:
				await tree.process_frame
				waited += 1
				if waited > 2 and not WsgLoading.busy():
					break
			var tag := "%s at %s" % [mode, ["Low", "Medium", "High"][t]]
			# Per skeleton: {name, bent (knee-frames a knee was bent), back, worst (cm behind), at (frame), run (each leg's
			# backward frames running now), longest (the most running), excused}
			var seen := {}
			var unknown := {}
			var frame := [0]
			for f in KNEE_FRAMES:
				if f % 15 == 0:
					for n: Node in holder.find_children("*", "Skeleton3D", true, false):
						var sk := n as Skeleton3D
						var id := sk.get_instance_id()
						if seen.has(id) or unknown.has(id):
							continue
						var legs := WsgNoteChecks.leg_bones(sk, game.leg_bones(sk))
						var nm := String(holder.get_path_to(sk.get_parent() if sk.get_parent() else sk))
						if legs.is_empty():
							if sk.get_bone_count() > 0 and sk.is_visible_in_tree():
								unknown[id] = nm
							continue
						var rec := {"name": nm, "bent": 0, "back": 0, "worst": 0.0, "at": -1, "run": [0, 0], "longest": 0, "excused": {}}
						seen[id] = rec
						sk.skeleton_updated.connect(func():
							if not is_instance_valid(sk) or not sk.is_visible_in_tree():
								return
							var ks := WsgNoteChecks.knees(sk, legs)
							for li in ks.size():
								var k: Array = ks[li]
								var behind := float(k[1]) >= WsgNoteChecks.KNEE_BENT and float(k[0]) < -WsgNoteChecks.KNEE_BACK
								if float(k[1]) >= WsgNoteChecks.KNEE_BENT:
									rec.bent += 1
								if behind:
									var why := game.knee_excuse(sk)
									if why != "":
										rec.excused[why] = int(rec.excused.get(why, 0)) + 1
										behind = false
								if not behind:
									rec.run[li] = 0
									continue
								rec.back += 1
								rec.run[li] = int(rec.run[li]) + 1
								rec.longest = maxi(int(rec.longest), int(rec.run[li]))
								if -float(k[0]) * 100.0 > float(rec.worst):
									rec.worst = -float(k[0]) * 100.0
									rec.at = frame[0])
				frame[0] = f
				await tree.process_frame
			var bent := 0
			var back := 0
			for id in seen:
				var rec: Dictionary = seen[id]
				bent += int(rec.bent)
				back += int(rec.back)
				for why in rec.excused:
					r.lines.append("%s: %s excused by the game (%s): %d knee-frames" % [tag, rec.name, why, rec.excused[why]])
				if int(rec.back) == 0:
					continue
				var what := "%s: %s bent a knee backwards on %d of %d bent knee-frames, %d running at most (worst %.1f cm behind its hip-ankle line, frame %d)" % [
					tag, rec.name, rec.back, rec.bent, rec.longest, rec.worst, rec.at]
				if int(rec.longest) > KNEE_RUN or float(rec.back) > KNEE_SHARE * float(maxi(int(rec.bent), 1)) or float(rec.worst) > KNEE_GROSS_CM:
					r.fails.append(what)
				else:
					rs.fails.append(what)
			r.lines.append("%s: %d skeletons with legs watched %d frames, %d bent knee-frames, %d backwards%s" % [tag, seen.size(),
				KNEE_FRAMES, bent, back, ("; %d skeletons with no legs it knows (leg_bones): %s" % [unknown.size(), ", ".join(unknown.values().slice(0, 4))]) if not unknown.is_empty() else ""])
			# (No skeleton drawn at all is no knee to bend - a tier whose bodies are cards or rigid figures; a skeleton drawn
			# whose legs it cannot find is one it cannot vouch for.)
			if seen.is_empty() and not unknown.is_empty():
				r.fails.append("%s: %d skeletons drawn and none with legs it knows (find a body's legs: WsgWorldGame.leg_bones)" % [tag, unknown.size()])
			holder.queue_free()
			await tree.process_frame
			# (A start that failed in the game's own loading - Kabaddi's _swap on a freed node - left it busy for ever.)
			var left := 30 * 60
			while WsgLoading.busy() and left > 0:
				await tree.process_frame
				left -= 1
	game.set_tier(was)
	WsgLoading.skip_warm = warm_was
	rs.lines.append("single strays: a body's backward knees %d frames running at most, on %.1f%% of its bent knee-frames at most, %.0f cm at most (more fails \"knees\")" % [KNEE_RUN, KNEE_SHARE * 100.0, KNEE_GROSS_CM])
	_close(rs)
	return _close(r)



## sounds: every key moment's sound kind stays crisp at a distance (WsgAudio.bright_kinds: brought within
## bright_distance of the listener, its highs kept).
static func sounds(game: WsgWorldGame, parent: Node) -> Dictionary:
	var r := result("sounds")
	var kinds := game.key_sounds()
	if kinds.is_empty():
		return _not_wired(r, "key_sounds")
	var au := game.audio(parent)
	for f in WsgNoteChecks.bright(au, kinds):
		r.fails.append(f)
	r.lines.append("%d key sounds (%s): %s" % [kinds.size(), ", ".join(kinds), "all crisp at a distance" if r.fails.is_empty() else "%d dulled" % r.fails.size()])
	au.queue_free()
	return _close(r)


## web: no licensed data (MoCap Online, ActorCore, Mixamo-derived: addons/wsg_foundation/data) in a Web build. Every
## Web preset in export_presets.cfg excludes addons/wsg_foundation/data/*, and the exported pack (PCK, when given)
## holds none of it.
static func web(presets_path: String, pck: String) -> Dictionary:
	var r := result("web")
	var cfg := ConfigFile.new()
	var webs := 0
	if FileAccess.file_exists(presets_path) and cfg.load(presets_path) == OK:
		for sec in cfg.get_sections():
			if not sec.ends_with(".options") and str(cfg.get_value(sec, "platform", "")) == "Web":
				webs += 1
				var ex := str(cfg.get_value(sec, "exclude_filter", ""))
				var name := str(cfg.get_value(sec, "name", sec))
				var ok := false
				for p in ex.split(",", false):
					var q := p.strip_edges().trim_prefix("res://")
					if q in ["addons/wsg_foundation/data/*", "addons/wsg_foundation/data/**", "addons/wsg_foundation/data/*.*"]:
						ok = true
				r.lines.append("Web preset '%s': %s" % [name, "excludes addons/wsg_foundation/data/*" if ok else "does NOT exclude the licensed data"])
				if not ok:
					r.fails.append("the Web preset '%s' does not exclude addons/wsg_foundation/data/* (licensed data would ship on a public page)" % name)
	if webs == 0:
		r.lines.append("no Web preset in %s" % presets_path)
	if pck != "" and webs == 0 and not FileAccess.file_exists(pck):
		# No Web build at all (Kabaddi's removed at the owner's word): nothing to ship the data in - N/A, a pass, even
		# with CI still passing --web-pck.
		r.lines.append("N/A: no Web preset and no Web pack (%s)" % pck)
	elif pck != "":
		if not FileAccess.file_exists(pck):
			r.fails.append("the Web pack %s is not there" % pck)
		else:
			var bytes := FileAccess.get_file_as_bytes(pck)
			var found := []
			for needle in ["wsg_foundation/data/", "mobility.res", "actorcore.res"]:
				if _find(bytes, needle.to_utf8_buffer()) >= 0:
					found.append(needle)
			r.lines.append("Web pack %s (%.1f MB): %s" % [pck.get_file(), bytes.size() / 1048576.0, "no licensed data" if found.is_empty() else "holds " + ", ".join(found)])
			if not found.is_empty():
				r.fails.append("the Web pack holds licensed data: %s" % ", ".join(found))
	return _close(r)


static func _find(hay: PackedByteArray, needle: PackedByteArray) -> int:
	var n := needle.size()
	if n == 0 or hay.size() < n:
		return -1
	var first := needle[0]
	var i := hay.find(first)
	while i >= 0 and i <= hay.size() - n:
		if hay.slice(i, i + n) == needle:
			return i
		i = hay.find(first, i + 1)
	return -1
