extends Node
## Measures how players move and how their bodies follow, frame by frame, on the realistic bodies:
##   - foot skate: how fast a sole slides along the floor while it is down on it (m/s);
##   - pace mismatch: how far the speed the legs animate for differs from how fast the body really moves;
##   - jumps: a position change no running or diving could make in one frame;
##   - facing snaps: the body turning faster than a person can (deg/s) while on the move;
##   - pose pops: a joint jumping further in one frame than any move swings it;
##   - clip flicker: running clips switched, cross-fades restarted part-way, fading clips dropped;
##   - neck drift: the neck left turned by a clip that has finished;
##   - stance: a defender standing ready (not moving off), how often a leg is held straight (knee over STRAIGHT_KNEE)
##     or splayed (out to the side over SPLAY_DEG), how far apart his feet are, and the steps he takes to settle them.
## Two runs: "course" (one raider and one defender sprint, stop, backpedal, shuffle, pivot and sprint again; the
## defender creeps forward and back in his crouch too)
## and "match" (an AI match, every player on the mat). Prints one line per measure; --json writes them,
## --log prints each jump, snap and pop as it happens. "view" plays the course on screen, with the planted
## feet marked, for recording:
##   godot --headless --path . --fixed-fps 30 res://tests/locomotion_check.tscn -- [course|match|both] [SECONDS] [--json FILE] [--log]
##       [--seed N]   (another match: the AI's choices and the bodies' small variations come from it)
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 --write-movie out.avi \
##       --fixed-fps 30 res://tests/locomotion_check.tscn -- view

const JUMP_SPEED := 10.0        # m/s: faster than any dive or dodge carries a player
const SNAP_TURN := 720.0        # deg/s: faster than a person turns while moving
const POP_DEG := 40.0           # deg in a 30th of a second (1200 deg/s): faster than a body swings a joint
const JERK_DEG := 25.0          # deg in a 30th of a second that starts out of nowhere: 3x the frame before
const STANCE_H := 0.025         # a sole this close to the floor is standing on it
const STRAIGHT_KNEE := 160.0    # deg: a knee this open, standing ready, is a straight leg
const SPLAY_DEG := 20.0         # deg: a leg this far out to the side of straight down, from the front, is splayed
const JOINTS := ["pelvis", "spine", "chest", "neck", "head", "sh_l", "sh_r", "el_l", "el_r", "hip_l", "hip_r", "kn_l", "kn_r"]

var _probes := {}               # athlete -> Probe
var _mode := "both"
var _secs := 60.0
var _json := ""
var _results := {}
var _view := false
var _view_who := 0          # whom the camera follows: 0 the raider, 1 the defender
var _seed := 7
var _cam: Camera3D
var _marks := []


class Probe:
	static var log_events := false
	static var t_now := 0.0
	var a: Athlete
	var pos := Vector3.INF
	var facing := Vector3.ZERO
	var joints := {}
	var soles := {}             # side -> world position of its lowest point last frame (or null)
	var move: MocapClip = null
	var move_fade := 1.0
	var prev_clip: MocapClip = null
	var prev_w := 0.0
	var clip: MocapClip = null
	var frames := 0
	var secs := 0.0
	var skate := []             # sole speeds while down
	var label := ""             # what he is doing (course segment), to break skating down by it
	var by_label := {}
	var pace := []              # |animated speed - real speed|
	var jumps := 0
	var max_step := 0.0
	var snaps := 0
	var max_turn := 0.0
	var pops := 0
	var jerks := 0
	var placed := 0
	var steps := {}             # joint -> its last frame's step (deg)
	var max_pop := 0.0
	var pop_where := {}
	var switches := 0
	var restarts := 0
	var drops := 0
	var neck := 0.0
	var stance_frames := 0        # standing ready
	var straight := 0             # ... with a leg held straight
	var splayed := 0              # ... with a leg out to the side
	var apart := []               # ... how far apart the ankles are (m)
	var settles := 0              # settling steps (RiggedBody.settle_steps)
	var settle_base := -1

	func _init(p_a: Athlete) -> void:
		a = p_a

	func sample(dt: float, joint_names: Array) -> void:
		var m: HumanModel = a.model
		if m == null or m.pelvis == null:
			return
		frames += 1
		secs += dt
		var p := a.global_position
		var placing := false
		if pos != Vector3.INF:
			var step := Vector2(p.x - pos.x, p.z - pos.z).length()
			# More than a metre at once is the game placing him (a new raid, the bench), counted apart.
			placing = step > 1.0
			if placing:
				placed += 1
			else:
				max_step = maxf(max_step, step / dt)
			if step / dt > JUMP_SPEED and not placing:
				jumps += 1
				if log_events:
					print("%6.2f JUMP %s %.2fm state=%s" % [t_now, a.name, step, a.state])
			var real := step / dt
			if real > 0.3 or m.speed > 0.3:
				pace.append(absf(m.speed - real))
			# The body as drawn (its node's turn), which is what a viewer sees snap.
			var seen := -a.global_transform.basis.z
			seen = Vector3(seen.x, 0.0, seen.z).normalized()
			if real > 1.5 and facing != Vector3.ZERO and not placing:
				var turn := rad_to_deg(facing.angle_to(seen)) / dt
				max_turn = maxf(max_turn, turn)
				if turn > SNAP_TURN:
					snaps += 1
					if log_events:
						print("%6.2f SNAP %s %.0fdeg/s state=%s lock=%s spd=%.1f" % [t_now, a.name, turn, a.state, a.lock_facing, real])
		pos = p
		var drawn := -a.global_transform.basis.z
		facing = Vector3(drawn.x, 0.0, drawn.z).normalized()
		# Joints relative to the player himself, so turning on the spot is not a pop.
		var inv := a.global_transform.basis.inverse()
		for jn in joint_names:
			var node: Node3D = m.get(jn)
			var q := (inv * node.global_transform.basis).get_rotation_quaternion()
			if joints.has(jn) and not placing:
				# Joint steps as degrees per 30th of a second, so any frame rate compares with 30 fps.
				var d := rad_to_deg((joints[jn] as Quaternion).angle_to(q)) / (dt * 30.0)
				if d > max_pop:
					max_pop = d
				if d > JERK_DEG and d > 3.0 * float(steps.get(jn, 0.0)):
					jerks += 1
				steps[jn] = d
				if d > POP_DEG:
					pops += 1
					pop_where[jn] = int(pop_where.get(jn, 0)) + 1
					if log_events:
						print("%6.2f POP %s %s %.0fdeg state=%s clip=%s w=%.2f prev=%s pw=%.2f move=%s mw=%.2f fade=%.2f" % [t_now, a.name, jn, d, a.state,
							m.clip.name if m.clip else "-", m.clip_weight, m._prev_clip.name if m._prev_clip else "-", m._prev_weight,
							m._move.name if m._move else "-", m.move_weight, m._move_fade])
			joints[jn] = q
		# Soles on the floor: how fast they slide.
		if m.rig and m.rig.skeleton:
			var sk := m.rig.skeleton
			var xf := sk.global_transform
			for s in m.rig.body.get("soles", {}):
				var bi: int = m.rig.body.soles[s][0]
				var bp := sk.get_bone_global_pose(bi)
				var pts := m.rig.body.soles[s][1] as PackedVector3Array
				var now := []
				for q in pts:
					now.append(xf * (bp.origin + bp.basis * q))
				# A foot rolling heel to toe keeps one point still; a sliding foot moves them all. So: the
				# slowest of the points that were on the floor last frame and still are.
				var was = soles.get(s)
				if was != null:
					var slow := INF
					for i in now.size():
						var a0: Vector3 = was[i]
						var a1: Vector3 = now[i]
						if a0.y < STANCE_H and a1.y < STANCE_H:
							slow = minf(slow, Vector2(a1.x - a0.x, a1.z - a0.z).length() / dt)
					if slow < INF:
						skate.append(slow)
						if label != "":
							if not by_label.has(label):
								by_label[label] = []
							by_label[label].append(slow)
				soles[s] = now
		# Running clips and state clips.
		if m._move != move:
			if move != null:
				switches += 1
				if move_fade < 0.99:
					restarts += 1   # switched again before the last cross-fade had finished
			move = m._move
		move_fade = m._move_fade
		if m._prev_clip != prev_clip:
			if prev_clip != null and prev_w > 0.05:
				drops += 1   # a clip still fading out was dropped outright
			prev_clip = m._prev_clip
		prev_w = m._prev_weight
		if m.clip == null and m.move_weight <= 0.001 and m.neck:
			neck = maxf(neck, rad_to_deg(m.neck.quaternion.get_angle()))
		# Standing ready: the legs as drawn.
		if m.rig and m.rig.skeleton:
			if settle_base < 0:
				settle_base = int(m.rig.get("settle_steps")) if m.rig.get("settle_steps") != null else 0
			settles = (int(m.rig.get("settle_steps")) if m.rig.get("settle_steps") != null else 0) - settle_base
		if a.state == "ready" and m.speed < 0.35 and m.rig and m.rig.skeleton:
			var r: RiggedBody = m.rig
			var side := a.global_transform.basis.x
			side = Vector3(side.x, 0.0, side.z).normalized()
			var knee_max := 0.0
			var out_max := 0.0
			for sd in ["l", "r"]:
				var hip := r.anchor("hip_" + sd)
				var sk := r.skeleton
				var kn := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("shin_" + sd)).origin
				var an := r.anchor("foot_" + sd)
				knee_max = maxf(knee_max, rad_to_deg((hip - kn).angle_to(an - kn)))
				var d := an - hip
				var outward := d.dot(side) * (-1.0 if sd == "l" else 1.0)   # the model's left is -x
				out_max = maxf(out_max, rad_to_deg(atan2(outward, -d.y)))
			stance_frames += 1
			if knee_max > STRAIGHT_KNEE:
				straight += 1
			if out_max > SPLAY_DEG:
				splayed += 1
			apart.append(r.anchor("foot_l").distance_to(r.anchor("foot_r")))


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] in ["course", "match", "both"]:
			_mode = args[i]
		elif args[i] == "view":
			_mode = "course"
			_view = true
		elif args[i] == "defender":
			_view_who = 1
		elif args[i] == "--json" and i + 1 < args.size():
			_json = args[i + 1]
		elif args[i] == "--log":
			Probe.log_events = true
		elif args[i] == "--seed" and i + 1 < args.size():
			_seed = int(args[i + 1])
		elif args[i].is_valid_float() and not (i > 0 and args[i - 1] == "--seed"):
			_secs = float(args[i])
	Game.settings.models = 1
	Game.settings.graphics = Game.GFX_LOW
	seed(_seed)
	if _view:
		_stage()
	if _mode in ["course", "both"]:
		await _course()
	if _mode in ["match", "both"]:
		await _match()
	if _json != "":
		var f := FileAccess.open(_json, FileAccess.WRITE)
		f.store_string(JSON.stringify(_results, "  "))
	get_tree().quit()


# ---------------------------------------------------------------- the course

## One raider and one defender, each over a course of the moves a raid is made of.
func _course() -> void:
	var raider := _athlete(0, "raid")
	var defender := _athlete(1, "ready")
	defender.position = Vector3(3, 0, 0)
	var fwd := Vector3(0, 0, -1)
	var right := Vector3(1, 0, 0)
	# [seconds, desired velocity, facing locked toward (or null: face the way he goes), note]
	var raid_course := [
		[1.0, Vector3.ZERO, fwd, "stand"],
		[2.0, fwd * 4.6, null, "sprint"],
		[1.0, Vector3.ZERO, null, "stop"],
		[1.5, -fwd * 2.4, fwd, "backpedal"],
		[1.5, right * 2.2, fwd, "shuffle right"],
		[1.5, -right * 2.2, fwd, "shuffle left"],
		[2.0, -fwd * 4.6, null, "pivot and sprint"],
		[1.0, Vector3.ZERO, null, "stop"],
		[1.6, (fwd + right).normalized() * 4.2, null, "diagonal run"],
		[0.8, -(fwd + right).normalized() * 4.2, null, "cut back"],
		[1.0, Vector3.ZERO, null, "stop"],
		[1.2, right * 1.2, fwd, "creep right"],
		[1.2, -right * 1.2, fwd, "creep left"],
		[1.0, Vector3.ZERO, fwd, "stand"],
	]
	var def_course := [
		[1.0, Vector3.ZERO, fwd, "set"],
		[1.6, fwd * 0.8, fwd, "creep forward"],
		[1.6, -fwd * 0.6, fwd, "creep back"],
		[1.2, right * 1.6, fwd, "shuffle right"],
		[1.2, -right * 1.6, fwd, "shuffle left"],
		[0.8, right * 1.6, fwd, "shuffle right"],
		[1.0, fwd * 3.0, fwd, "attack"],
		[1.2, -fwd * 2.0, fwd, "backpedal"],
		[1.0, Vector3.ZERO, fwd, "set"],
		[2.0, -right * 3.5, null, "chase"],
		[1.0, Vector3.ZERO, fwd, "set"],
	]
	await _run_course([raider, defender], [raid_course, def_course])
	_report("course raider", _probes[raider])
	_report("course defender", _probes[defender])
	raider.queue_free()
	defender.queue_free()
	_probes.clear()


func _athlete(team: int, state: String) -> Athlete:
	var data: Dictionary = DB.team("MUM" if team == 0 else "DEL").squad[team * 3].duplicate(true)
	var a := Athlete.new()
	a.setup(data, team, Color.TEAL if team == 0 else Color.ORANGE, Color.WHITE, true)
	add_child(a)
	a.facing = Vector3(0, 0, -1)
	a.set_state(state, 1000.0)
	_probes[a] = Probe.new(a)
	return a


func _run_course(who: Array, courses: Array) -> void:
	var idx := [0, 0]
	var left := [courses[0][0][0], courses[1][0][0]]
	var done := false
	while not done:
		done = true
		var dt := _step()
		for k in who.size():
			var a: Athlete = who[k]
			var c: Array = courses[k]
			if idx[k] >= c.size():
				a.drive(Vector3.ZERO, dt)
				continue
			done = false
			var seg: Array = c[idx[k]]
			(_probes[a] as Probe).label = seg[3]
			a.lock_facing = seg[2] != null
			if seg[2] != null:
				a.face_toward(a.position + seg[2], dt, 10.0)
			a.drive(seg[1], dt)
			left[k] -= dt
			if left[k] <= 0.0:
				idx[k] += 1
				if idx[k] < c.size():
					left[k] = c[idx[k]][0]
		await get_tree().process_frame
		Probe.t_now += dt
		for a in who:
			(_probes[a] as Probe).sample(dt, JOINTS)
		if _view:
			_follow(who)


## A floor with court lines, light and a camera, for watching the course.
func _stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.13, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.62, 0.7)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_m := MeshInstance3D.new()
	floor_m.mesh = PlaneMesh.new()
	(floor_m.mesh as PlaneMesh).size = Vector2(40, 40)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("2f6fd6").darkened(0.25)
	floor_m.material_override = fm
	add_child(floor_m)
	# A grid every metre, so sliding feet show against it.
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(1, 1, 1, 0.35)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(-15, 16):
		for horiz in [true, false]:
			var l := MeshInstance3D.new()
			l.mesh = BoxMesh.new()
			(l.mesh as BoxMesh).size = Vector3(30, 0.002, 0.02) if horiz else Vector3(0.02, 0.002, 30)
			l.position = Vector3(0, 0.002, i) if horiz else Vector3(i, 0.002, 0)
			l.material_override = lm
			add_child(l)
	_cam = Camera3D.new()
	_cam.fov = 42
	add_child(_cam)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(1.0, 0.85, 0.1)
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 4:
		var d := MeshInstance3D.new()
		d.mesh = CylinderMesh.new()
		(d.mesh as CylinderMesh).top_radius = 0.06
		(d.mesh as CylinderMesh).bottom_radius = 0.06
		(d.mesh as CylinderMesh).height = 0.004
		d.material_override = mm
		d.visible = false
		add_child(d)
		_marks.append(d)


## Follow one player from the side and a little above; mark each planted foot's anchor.
func _follow(who: Array) -> void:
	var mid := (who[_view_who] as Athlete).position
	var want := mid + Vector3(3.6, 1.7, 2.4)
	_cam.position = want if _cam.position == Vector3.ZERO else _cam.position.lerp(want, 0.08)
	_cam.look_at(mid + Vector3(0, 0.7, 0))
	var k := 0
	for a in who:
		var rig: RiggedBody = (a as Athlete).model.rig
		var plant = rig.get("_plant") if rig != null else null
		if plant == null:
			continue
		for side in plant:
			if k < _marks.size():
				_marks[k].visible = true
				_marks[k].position = Vector3((plant[side][0] as Vector3).x, 0.004, (plant[side][0] as Vector3).z)
				k += 1
	for i in range(k, _marks.size()):
		_marks[i].visible = false


# ---------------------------------------------------------------- an AI match

func _match() -> void:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "autoplay": true,
		"autoplay_no_report": true, "length": 0, "difficulty": 1, "seed": _seed}
	add_child(m)
	var t := 0.0
	while t < _secs and is_instance_valid(m):
		var dt := _step()
		await get_tree().process_frame
		t += dt
		Probe.t_now = t
		for team in m.teams:
			for a in team.players:
				if not a.on_mat:
					continue
				if not _probes.has(a):
					_probes[a] = Probe.new(a)
				(_probes[a] as Probe).sample(dt, JOINTS)
	var all := Probe.new(null)
	for p in _probes.values():
		var q: Probe = p
		all.frames += q.frames
		all.secs += q.secs
		all.skate.append_array(q.skate)
		all.pace.append_array(q.pace)
		all.jumps += q.jumps
		all.max_step = maxf(all.max_step, q.max_step)
		all.snaps += q.snaps
		all.max_turn = maxf(all.max_turn, q.max_turn)
		all.pops += q.pops
		all.jerks += q.jerks
		all.placed += q.placed
		all.max_pop = maxf(all.max_pop, q.max_pop)
		for k in q.pop_where:
			all.pop_where[k] = int(all.pop_where.get(k, 0)) + int(q.pop_where[k])
		all.switches += q.switches
		all.restarts += q.restarts
		all.drops += q.drops
		all.neck = maxf(all.neck, q.neck)
		all.stance_frames += q.stance_frames
		all.straight += q.straight
		all.splayed += q.splayed
		all.apart.append_array(q.apart)
		all.settles += q.settles
	_report("match (%d players, %ds)" % [_probes.size(), int(_secs)], all)
	if is_instance_valid(m):
		m.queue_free()
	_probes.clear()


# ---------------------------------------------------------------- report

## This frame's time step, which the players are about to move and pose with (called right after a frame
## starts, before their _process). Under --fixed-fps the steps vary a little around 1/fps (the engine
## keeps time with the physics ticks), so each is read rather than assumed.
func _step() -> float:
	var d := get_process_delta_time()
	return d if d > 0.0005 else 1.0 / 30.0

func _pct(v: Array, q: float) -> float:
	if v.is_empty():
		return 0.0
	var s := v.duplicate()
	s.sort()
	return float(s[clampi(int(round(q / 100.0 * (s.size() - 1))), 0, s.size() - 1)])


func _report(name: String, p: Probe) -> void:
	var mins := maxf(p.secs / 60.0, 0.001)
	var r := {
		"frames": p.frames,
		"skate_median_ms": snappedf(_pct(p.skate, 50), 0.01),
		"skate_p90_ms": snappedf(_pct(p.skate, 90), 0.01),
		"pace_error_median_ms": snappedf(_pct(p.pace, 50), 0.01),
		"pace_error_p90_ms": snappedf(_pct(p.pace, 90), 0.01),
		"jumps": p.jumps,
		"max_speed_ms": snappedf(p.max_step, 0.1),
		"facing_snaps": p.snaps,
		"max_turn_degs": snappedf(p.max_turn, 1.0),
		"placements": p.placed,
		"pose_pops": p.pops,
		"pops_per_min": snappedf(p.pops / mins, 0.1),
		"pose_jerks": p.jerks,
		"max_joint_step_deg": snappedf(p.max_pop, 0.1),
		"pop_joints": p.pop_where,
		"clip_switches_per_min": snappedf(p.switches / mins, 0.1),
		"fades_restarted": p.restarts,
		"dropped_fades": p.drops,
		"neck_left_turned_deg": snappedf(p.neck, 0.1),
		"stance_straight_leg_pct": snappedf(100.0 * p.straight / maxi(1, p.stance_frames), 0.1),
		"stance_splayed_leg_pct": snappedf(100.0 * p.splayed / maxi(1, p.stance_frames), 0.1),
		"stance_feet_apart_m": "median %.2f p10 %.2f p90 %.2f" % [_pct(p.apart, 50), _pct(p.apart, 10), _pct(p.apart, 90)],
		"settle_steps_per_min": snappedf(p.settles / mins, 0.1),
	}
	if not p.by_label.is_empty():
		var parts := {}
		for k in p.by_label:
			var v: Array = p.by_label[k]
			var slid := v.filter(func(x): return x > 0.5).size()
			parts[k] = "median %.2f p90 %.2f sliding %d%%" % [_pct(v, 50), _pct(v, 90), 100 * slid / maxi(1, v.size())]
		r["skate_by_move"] = parts
	_results[name] = r
	print("== ", name)
	for k in r:
		if k == "skate_by_move":
			for m in r[k]:
				print("    %-22s %s" % [m, r[k][m]])
		else:
			print("  %-26s %s" % [k, str(r[k])])
