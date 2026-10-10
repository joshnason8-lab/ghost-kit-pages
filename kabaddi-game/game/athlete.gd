class_name Athlete
extends Node3D
## One player on (or beside) the mat: movement, ratings, current action, and the body.

var data: Dictionary
var team := 0
var slot := 0            # defensive slot index, left to right
var model: HumanModel
var on_mat := true
var vel := Vector3.ZERO
var facing := Vector3(0, 0, -1)
var lock_facing := false

# state: idle, ready, raid, touch, kick, backkick, dodge, dubki, jump, telegraph, dive, recover, held, holding, fallen, walk, sit, celebrate
var state := "idle"
var st_t := 0.0
var st_len := 0.0
var cooldown := 0.0
var touched := false
var hold_offset := Vector3.ZERO
var dive_dir := Vector3.ZERO
var walk_target := Vector3.ZERO
var energy := 1.0
var raids_made := 0
var is_user := false
var is_career := false
var chain_partner: Athlete = null   # team-mate whose hand this defender is holding
var chain_offset := Vector3.ZERO     # where to stand relative to that partner
var chain_dive := false              # this dive is part of a chain tackle
var shove_target: Athlete = null
var cards := 0                       # cards shown to him this match (green, then yellow)
var suspended := -1.0                # yellow card: match clock when he may return (-1: not suspended)
var suspended_half := 0
var sig_kind := 0                    # an official's signal, see HumanModel.SIGNALS
var cele_kind := 0                   # how he celebrates, see HumanModel.cele
var cele_partner: Athlete = null     # team-mate he is going to high-five
var moves := {}                      # raiding move ratings, see DB.moves
var dmoves := {}                     # defensive skill ratings, see DB.def_moves
var style := "ankle"                 # his default grip: ankle, thigh or waist hold
var tackle_kind := ""                # the tackle he is going in with right now
var kick_back := 0.0                 # back/side kick: how far behind the target is (0..1)
var kick_side := 0.0                 # ... and how far to the side (-1 left .. 1 right)
var kick_dir := Vector3.ZERO         # world direction of the kick

var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _ring_color := Color(0, 0, 0, 0)

# Ratings converted to physical numbers.
var max_speed := 4.6
var accel := 18.0
var reach := 1.0
var strength := 1.0
var tackle := 1.0
var agility := 1.0


func setup(p_data: Dictionary, p_team: int, kit: Color, trim: Color, barefoot: bool) -> void:
	data = p_data
	team = p_team
	var a: Dictionary = data.attrs
	max_speed = 4.1 + (float(a.speed) - 50.0) * 0.03
	accel = 14.0 + (float(a.agility) - 50.0) * 0.18
	reach = 0.95 + (float(a.reach) - 50.0) * 0.008
	strength = 1.0 + (float(a.strength) - 60.0) * 0.015
	tackle = 0.55 + (float(a.tackle) - 50.0) * 0.01
	agility = 1.0 + (float(a.agility) - 60.0) * 0.015
	moves = DB.moves(data)
	dmoves = DB.def_moves(data)
	style = DB.style(data)
	model = HumanModel.new()
	model.body_kind = "referee" if team == 2 else "player"
	model.body_seed = hash(String(data.get("id", data.get("name", ""))))
	model.body_file = String(data.get("body", ""))
	model.setup(Color(DB.SKIN_TONES[int(data.skin)]), Color(DB.HAIR_COLORS[int(data.hair)]), kit, trim, int(data.number), float(data.height), float(data.build), barefoot)
	add_child(model)
	_make_ring()


func _make_ring() -> void:
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.52
	t.rings = 24
	t.ring_segments = 6
	_ring.mesh = t
	_ring.scale = Vector3(1, 0.04, 1)
	_ring.position.y = 0.02
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)


func set_ring(c: Color) -> void:
	_ring_color = c
	_ring.visible = c.a > 0.0
	_ring_mat.albedo_color = c


func pid() -> String:
	return String(data.id)


func display_name() -> String:
	return String(data.name)


func is_raider_type() -> bool:
	return data.role != "defender"


func ground_pos() -> Vector3:
	return Vector3(position.x, 0, position.z)


func set_state(s: String, length := 0.0) -> void:
	state = s
	st_t = 0.0
	st_len = length
	if model:
		# Real captured motion for this move, if any has been recorded.
		var c = MocapClip.for_state(s)
		model.play_clip(c, MocapClip.loops(s))


func busy() -> bool:
	return state in ["touch", "kick", "backkick", "dubki", "jump", "shoved", "telegraph", "dive", "recover", "fallen", "held", "holding"]


## 0..1 skill at a raiding move.
func move_skill(move: String) -> float:
	return float(moves.get(move, 50)) / 100.0


## 0..1 skill at a defensive skill.
func dskill(kind: String) -> float:
	return float(dmoves.get(kind, 50)) / 100.0


## The tackle being made now, or his usual one.
func kind() -> String:
	return tackle_kind if tackle_kind != "" else style


## Pitch of his voice, the same every time for the same player.
func voice_pitch() -> float:
	return 0.88 + float(absi(hash(String(data.get("id", name)))) % 1000) / 1000.0 * 0.26


## Airborne part of a lion jump.
func airborne() -> bool:
	if state != "jump":
		return false
	var p := st_t / maxf(st_len, 0.01)
	return p > 0.12 and p < 0.88


## Accelerate toward a desired ground velocity and integrate.
func drive(desired: Vector3, dt: float) -> void:
	desired.y = 0
	vel = vel.move_toward(desired, accel * dt)
	position += vel * dt
	if not lock_facing and vel.length() > 0.4:
		facing = facing.slerp(vel.normalized(), clampf(dt * 10.0, 0.0, 1.0)).normalized()


func seek(target: Vector3, speed: float, dt: float, arrive := 0.6) -> void:
	var to := target - position
	to.y = 0
	var d := to.length()
	if d < 0.05:
		drive(Vector3.ZERO, dt)
		return
	var s := speed * clampf(d / arrive, 0.0, 1.0)
	drive(to / d * s, dt)


func face_toward(p: Vector3, dt: float, rate := 8.0) -> void:
	var to := p - position
	to.y = 0
	if to.length() > 0.05:
		facing = facing.slerp(to.normalized(), clampf(dt * rate, 0.0, 1.0)).normalized()


func _process(delta: float) -> void:
	st_t += delta
	cooldown = maxf(0.0, cooldown - delta)
	rotation.y = atan2(-facing.x, -facing.z)
	_pose(delta)
	if _ring.visible:
		_ring.rotation.y += delta * 1.5


func _pose(delta: float) -> void:
	var m := model
	var k := clampf(delta * 10.0, 0.0, 1.0)
	m.speed = Vector2(vel.x, vel.z).length()
	var want_crouch := 0.0
	var want_lean := 0.0
	var want_reach := 0.0
	var want_kick := 0.0
	var want_dive := 0.0
	var want_fallen := 0.0
	var want_struggle := 0.0
	var want_celebrate := 0.0
	var want_hold := 0.0
	var want := {"roar": 0.0, "slump": 0.0, "shove": 0.0, "argue": 0.0, "slap": 0.0}
	var want_back_kick := 0.0
	var want_dubki := 0.0
	var want_jump := 0.0
	var want_seated := 0.0
	var want_signal := 0.0
	var want_bounce := 0.0
	var p := clampf(st_t / maxf(st_len, 0.01), 0.0, 1.0)
	match state:
		"ready":
			want_crouch = 0.85
		"raid":
			want_crouch = 0.35
			want_lean = -0.15
			want_bounce = 1.0
		"touch":
			want_reach = sin(p * PI)
			want_crouch = 0.3
		"kick":
			want_kick = sin(p * PI)
		"backkick":
			want_back_kick = sin(p * PI)
		"dodge":
			want_crouch = 0.5
		"evade":
			# Pulling back from a touch: hips back, stomach in.
			want_crouch = 0.6
			want_lean = 0.25
		"dubki":
			want_dubki = clampf(sin(p * PI) * 1.6, 0.0, 1.0)
		"jump":
			want_jump = sin(p * PI)
		"telegraph":
			# The wind-up shows how he will tackle: low for an ankle hold, upright and wide
			# for a thigh hold or a block.
			match kind():
				"ankle":
					want_crouch = 1.0
					want_lean = -0.35
					want_hold = 0.35
				"waist":
					want_crouch = 0.45
					want_hold = 1.0
				"dash":
					want_crouch = 0.55
					want_lean = -0.3
					want.shove = 0.5
				_:
					want_crouch = 0.75
					want_hold = 0.7
		"dive":
			var depth := {"ankle": 1.0, "thigh": 0.72, "waist": 0.45, "dash": 0.3}.get(kind(), 0.8) as float
			want_dive = clampf(p * 2.5, 0.0, 1.0) * depth
			if kind() in ["dash", "waist"]:
				want.shove = 1.0 if kind() == "dash" else 0.4
		"shoved":
			want_struggle = 0.6
			want_lean = 0.25
		"recover":
			want_fallen = 1.0 - clampf((p - 0.55) * 2.2, 0.0, 1.0)
		"fallen":
			want_fallen = 1.0
		"held":
			want_struggle = 1.0
		"holding":
			want_dive = 0.55
			want_hold = 1.0
		"signal":
			want_signal = 1.0
		"celebrate":
			want_celebrate = 1.0
			# A high five waits until the two of them meet.
			if cele_partner != null and position.distance_to(cele_partner.position) > 1.15:
				want_celebrate = 0.0
		"sit":
			want_seated = 1.0
		"roar", "slump", "shove", "argue":
			want[state] = 1.0
			if state == "slump":
				want_crouch = 0.25
		"slap":
			want.slap = 1.0
			want_crouch = 0.45
	m.crouch = lerpf(m.crouch, want_crouch, k)
	m.lean = lerpf(m.lean, want_lean, k)
	m.reach = lerpf(m.reach, want_reach, clampf(delta * 20.0, 0.0, 1.0))
	m.kick = lerpf(m.kick, want_kick, clampf(delta * 18.0, 0.0, 1.0))
	m.dive = lerpf(m.dive, want_dive, clampf(delta * 14.0, 0.0, 1.0))
	m.fallen = lerpf(m.fallen, want_fallen, k)
	m.struggle = lerpf(m.struggle, want_struggle, k)
	m.celebrate = lerpf(m.celebrate, want_celebrate, k)
	m.hold_arms = lerpf(m.hold_arms, want_hold, k)
	m.roar = lerpf(m.roar, want.roar, k)
	m.slump = lerpf(m.slump, want.slump, k)
	m.shove = lerpf(m.shove, want.shove, clampf(delta * 16.0, 0.0, 1.0))
	m.argue = lerpf(m.argue, want.argue, k)
	m.slap = lerpf(m.slap, want.slap, k)
	m.back_kick = lerpf(m.back_kick, want_back_kick, clampf(delta * 18.0, 0.0, 1.0))
	m.kick_back = kick_back
	m.kick_side = kick_side
	m.dubki = lerpf(m.dubki, want_dubki, clampf(delta * 16.0, 0.0, 1.0))
	m.jump = want_jump
	m.cele = cele_kind
	m.bounce = lerpf(m.bounce, want_bounce, k)
	m.ref_sig = sig_kind
	m.ref_amt = lerpf(m.ref_amt, want_signal, clampf(delta * 9.0, 0.0, 1.0))
	m.seated = lerpf(m.seated, want_seated, clampf(delta * 4.0, 0.0, 1.0))
	# Which way he is moving relative to where he faces: forward, backpedalling or sideways.
	var flat := Vector3(vel.x, 0, vel.z)
	if flat.length() > 0.3:
		var dir := flat.normalized()
		var right := facing.cross(Vector3.UP).normalized()
		m.move_fwd = lerpf(m.move_fwd, dir.dot(facing), k)
		m.move_side = lerpf(m.move_side, dir.dot(right), k)
	else:
		m.move_fwd = lerpf(m.move_fwd, 1.0, k)
		m.move_side = lerpf(m.move_side, 0.0, k)
	# Players with nothing to do look around; players in the action keep their eyes on it.
	m.look_around = 1.0 if state in ["idle", "sit", "walk"] or not on_mat else 0.25
