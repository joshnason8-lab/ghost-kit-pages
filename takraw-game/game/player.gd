class_name Player
extends Node3D
## One player on the court: his body (RealBody), where he is going and when he must be there, and the move he is
## playing. The match decides what he does (Match); this moves and poses him.

var data := {}             # from DB.squad
var side := 0              # 0 or 1
var role := DB.POS_TEKONG
var slot := 0              # his place in the line-up
var body: RealBody
var target := Vector3.ZERO # where he is going
var hurry := 0.0           # 0 a walk back to his place .. 1 a sprint to the ball
var vel := Vector3.ZERO
var look_at_pos := Vector3.ZERO
var watch := true          # turn to face the ball (else the net)
var stroll := false        # between points: walking somewhere, he turns to where he is going and walks there
var face_to := Vector3.INF # a point he turns to face, in a move too (the thrower to the server); INF: none
var look_to := Vector3.INF # what he watches, if not the ball (Match: the thrower watches the server)
var carrying := false      # the ball in his hands (Match keeps it there): his right, held out in front standing, by his
                           # hip as he walks (one hand, as the real ones hold it: 0.14.3)
var toss_crouch := false   # the thrower set to throw: down into his crouch, the ball held low (Match, before the toss)
var ready_bounce := 0.0    # 0 at ease .. 1 on his toes waiting for the serve (knees working, a little bounce)

var move := ""             # the move playing, if any
var move_start := 0.0      # when it started (match time)
var move_mirror := false
var _queued := ""          # a move to start at _queued_at
var _queued_at := 0.0
var _queued_mirror := false
var _ph := 0.0             # running stride's phase
var _half := 0             # half strides run (a footstep each)
var _w := 0.0              # how much the move holds the pose (eases in and out)
var _out_pose := {}        # the pose a move left him in (played out, or cut short by another), eased out of
var _out := 0.0            # 1 .. 0 over MOVE_OUT
var _last_p := {}          # last frame's pose (the move's over the stance or stride), before the small movements
var _yaw := 0.0
var _gait := 0              # going: 0 a run, -1/1 a side-shuffle, -2/2 a backpedal (the body turned to it)
var _step_w := 1.0          # under a move: how much his legs are his stride's (eased)
var _carry_w := 0.0        # eased: how much his arms hold the ball
var _hold := 1.0           # eased: the ball held out in front (standing) .. by his hip (walking)
var _crouch := 0.0         # eased: how far down into the thrower's crouch (Moves.LOW_HOLD)
var _life := 0.0           # his own clock for the small movements of a man standing (each his own pace)
var _life_rate := 1.0
var _shift := 0.0          # his weight: -1 on his left foot .. 1 on his right
var _shift_to := 0.0
var _next_shift := 0.0
var _head := Vector2.ZERO  # his head turned to what he watches: yaw, pitch (degrees)
var _ready_w := 0.0
var _ring: MeshInstance3D
var _mine: MeshInstance3D  # the thin ring under the one you play as (Settings: Play as one player)
var _shadow: MeshInstance3D

static var _ring_mat: StandardMaterial3D
static var _mine_mat: StandardMaterial3D


func _init(p_data := {}, p_side := 0, p_role := 0, look := {}) -> void:
	data = p_data
	side = p_side
	role = p_role
	body = RealBody.new(look)
	body.plant_feet = true   # (a foot on the floor stays put as he goes: RealBody._planted)


func _ready() -> void:
	add_child(body)
	body.link_foundation("player")
	_shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	q.orientation = PlaneMesh.FACE_Y
	_shadow.mesh = q
	_shadow.material_override = Ball.shadow_material()
	_shadow.position.y = 0.01
	add_child(_shadow)
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 24
	tm.ring_segments = 4
	_ring.mesh = tm
	_ring.scale = Vector3(1, 0.05, 1)
	_ring.position.y = 0.02
	_ring.material_override = ring_material()
	_ring.visible = false
	add_child(_ring)
	_mine = MeshInstance3D.new()
	var mm := TorusMesh.new()
	mm.inner_radius = 0.3
	mm.outer_radius = 0.34
	mm.rings = 24
	mm.ring_segments = 4
	_mine.mesh = mm
	_mine.scale = Vector3(1, 0.05, 1)
	_mine.position.y = 0.02
	if _mine_mat == null:
		_mine_mat = StandardMaterial3D.new()
		_mine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mine_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mine_mat.albedo_color = Color(1, 1, 1, 0.7)
	_mine.material_override = _mine_mat
	_mine.visible = false
	add_child(_mine)
	_yaw = Court.facing(side)
	body.rotation.y = _yaw
	_life = randf() * TAU
	_life_rate = randf_range(0.85, 1.15)
	_next_shift = randf_range(0.5, 4.0)


static func ring_material() -> StandardMaterial3D:
	if _ring_mat == null:
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mat.albedo_color = Game.C_SAFFRON
	return _ring_mat


func left_footed() -> bool:
	return bool(data.get("left", false))


## A kick from motion capture can finish away from where it started (the roll spike's landing, the step after the
## sunback): he is moved there as it ends, so the ready stance takes over where the kick left him.
func _carry(name: String, mirror: bool) -> void:
	if not Moves.is_clip(name):
		return
	var last := Moves.sample(name, 1.0, mirror)
	var off := Vector3(-float(last.get("hips_side", 0.0)), 0, float(last.get("hips_fwd", 0.0)))
	if off.length() > 0.005:
		position += off.rotated(Vector3.UP, body.rotation.y)


## Shows him as the one you control.
func set_selected(on: bool) -> void:
	_ring.visible = on


## Marks him as the one you play as, between his touches too.
func set_mine(on: bool) -> void:
	_mine.visible = on


func is_mine() -> bool:
	return _mine.visible


## The way he faces when he faces the net.
func net_dir() -> Vector3:
	return Vector3(1, 0, 0) if side == 0 else Vector3(-1, 0, 0)


## Where to stand so a move meets the ball at contact (the move's foot, knee or head where the ball will be), facing
## the net; kick_left: the move played with the left foot.
static func stand_for(contact: Vector3, move_name: String, side_: int, kick_left: bool) -> Vector3:
	var c: Array = Moves.CONTACT.get(move_name, [1.0, 0.3, 0.0, 1.0, 0.5])
	var f := Vector3(1, 0, 0) if side_ == 0 else Vector3(-1, 0, 0)
	var right := Vector3(-f.z, 0, f.x)
	var p := contact - f * float(c[1]) - right * float(c[2]) * (-1.0 if kick_left else 1.0)
	return Vector3(p.x, 0, p.z)


## Plays a move starting at match time at (so its contact lands when the ball does).
func queue_move(name: String, at: float, mirror := false) -> void:
	_queued = name
	_queued_at = at
	_queued_mirror = mirror


func play_now(name: String, now: float, mirror := false) -> void:
	if move != "" and _w > 0.0 and not _last_p.is_empty():
		# Cut short by another: eased out of where it had him, not jumped from (where a capture had taken his hips
		# carried into where he is, as at its end).
		_out_pose = _last_p.duplicate()
		if Moves.is_clip(move):
			var off := Vector3(-float(_out_pose.get("hips_side", 0.0)), 0, float(_out_pose.get("hips_fwd", 0.0)))
			position += off.rotated(Vector3.UP, body.rotation.y)
			_out_pose.erase("hips_fwd")
			_out_pose.erase("hips_side")
		_out = 1.0
		_w = 0.0
	move = name
	move_start = now
	move_mirror = mirror
	_queued = ""


## A move once the point is over (a cheer, a slump): from at, or once the move he is in has played out (a spiker in the
## air is not pulled out of his kick to cheer it).
func play_after(name: String, at: float, mirror := false) -> void:
	if move != "":
		at = maxf(at, move_start + Moves.length(move))
	queue_move(name, at, mirror)


func busy(now: float) -> bool:
	return move != "" and now - move_start < Moves.length(move)


func tick(dt: float, now: float) -> void:
	if _queued != "" and now >= _queued_at:
		play_now(_queued, _queued_at, _queued_mirror)
	# Moving: toward the target, quicker the more he hurries (his agility his top speed), slowing as he arrives.
	var airborne := move != "" and float(Moves.sample(move, (now - move_start) / Moves.length(move)).get("y", 0.0)) > 0.05
	var top := (2.2 + 3.6 * hurry) * (0.82 + float(data.get("agility", 70)) * 0.0028)
	if stroll:
		top = 1.6 + 2.0 * hurry   # a walk back to his place, a jog to fetch the ball
	var to := target - position
	to.y = 0
	var want := Vector3.ZERO
	if to.length() > 0.03:
		var go := minf(top, to.length() * (2.5 if stroll else 4.5))   # (a walk slows sooner)
		# A move of his on its way (a dig, a set, a block, a kick): he goes only as fast as gets him there a little
		# before it starts, to play it standing, not at a sprint he is still braking from as it begins (and slides
		# through: the owner saw it). If he can't, as fast as he can.
		if _queued != "" and not stroll:
			go = minf(go, maxf(to.length() / maxf(_queued_at - now - ARRIVE_EARLY, 0.05), ARRIVE_MIN))
		want = to.normalized() * go
	if airborne:
		want = vel   # no changing course in the air
	elif move != "":
		# Finishing a kick (or any touch) before he goes: from the touch until its follow-through is done he stays
		# (he ran off with his kicking leg still up, his standing foot dragged along).
		var c := Moves.contact_time(move)
		var ts := now - move_start
		if c > 0.0 and ts > c and ts < c + FOLLOW_THROUGH:
			want = Vector3.ZERO
	vel = vel.move_toward(want, 16.0 * dt)
	position += vel * dt
	position.y = 0.0
	# Facing: the net, turned toward the ball a little (or to what he must face: the server, for the throw).
	var face := net_dir()
	var facing_to := face_to.is_finite() and Vector2(face_to.x - position.x, face_to.z - position.z).length() > 0.1
	if facing_to:
		face = Vector3(face_to.x - position.x, 0, face_to.z - position.z).normalized()
	elif stroll and to.length() > 0.45 and vel.length() > 0.5:
		face = Vector3(vel.x, 0, vel.z).normalized()   # turned to where he walks; to the net again as he arrives
	elif watch:
		var tb := look_at_pos - position
		tb.y = 0
		if tb.length() > 0.3:
			face = (face * 1.2 + tb.normalized()).normalized()
	var want_yaw := atan2(face.x, face.z)
	if move != "" and not facing_to:
		want_yaw = Court.facing(side)   # moves are made facing the net
	# Going somewhere with no move of his own: turned so the way he goes is straight ahead, straight back or square to
	# his side - a run, a backpedal or a side-shuffle, whichever is nearest to the way he would face (at most 45
	# degrees off it) - as those are strides whose feet stay planted, which one at a slant is not. Far and fast he
	# turns and runs there (no one shuffles a long way at a sprint), and faces the net again as he arrives.
	var spd := Vector2(vel.x, vel.z).length()
	if move == "" and not facing_to and spd > GAIT_SPEED:
		var travel := atan2(vel.x, vel.z)
		var rel := wrapf(travel - want_yaw, -PI, PI)
		var g := roundi(rel / (PI * 0.5))
		if absf(wrapf(rel - _gait * PI * 0.5, -PI, PI)) < deg_to_rad(55.0):
			g = _gait   # (no flicking between two at 45 degrees)
		if spd > SHUFFLE_MAX and (to.length() > 1.2 or _gait == 0):
			g = 0   # (and still running till he has slowed)
		_gait = g
		want_yaw = travel - g * PI * 0.5
	else:
		_gait = 0
	# Turned as quickly as a man pivots (the planted foot stays where it is as he turns on it: RealBody._planted), more
	# quickly to square up for a move.
	var turn := wrapf(want_yaw - _yaw, -PI, PI) * minf(1.0, 10.0 * dt)
	var most := (YAW_MOVE if move != "" else YAW_MAX) * dt
	_yaw = wrapf(_yaw + clampf(turn, -most, most), -PI, PI)
	# The pose: the move if one is playing, blended over the run or the ready stance.
	var speed := vel.length()
	var local := vel.rotated(Vector3.UP, -_yaw)
	# Stepping backwards (backpedalling, facing the net): the stride played backwards, so his feet step back too.
	var back := speed > 0.4 and local.z < -0.5 * speed
	var sidestep := clampf(local.x / maxf(speed, 0.01), -1.0, 1.0) if speed > 0.4 else 0.0
	if move != "":
		# (under a move he faces the net: the nearer stride, crossed over smoothly - a switch jolted the legs)
		sidestep = signf(sidestep) * smoothstep(0.3, 0.7, absf(sidestep))
	# The stride turned as fast as he goes, for its standing foot to stay put (Moves.stride_rate, measured on the rig).
	var rate := 4.0 if speed < 0.3 else clampf(Moves.stride_rate(speed / body.scale.x, sidestep, body.women), 3.0, STRIDE_MAX)
	_ph += dt * rate * (-1.0 if back else 1.0)
	# A footstep each half stride while he runs (two to a turn of the stride's phase).
	var half := floori(_ph / PI)
	if half != _half:
		_half = half
		if speed > 1.2 and move == "":
			Sfx.step(global_position, speed)
	var base := Moves.run(_ph, clampf(speed / 5.0, 0.0, 1.0), sidestep)
	# A move just played out (or cut short) eased out of over MOVE_OUT, into the stance or the stride: before, he was
	# put straight into his stride from the move's last pose (a jolt of up to 0.9 m/frame^2 at a foot, the jitter test).
	if _out > 0.0:
		base = Moves.blend(base, _out_pose, smoothstep(0.0, 1.0, _out))
		_out = maxf(0.0, _out - dt / MOVE_OUT)
	var p := base
	var lift := 0.0
	var yaw_add := 0.0
	if move != "":
		var t := (now - move_start) / Moves.length(move)
		if t >= 1.0:
			_carry(move, move_mirror)
			if _w > 0.0 and not _last_p.is_empty():
				_out_pose = _last_p.duplicate()
				_out_pose.erase("hips_fwd")   # (carried into where he is)
				_out_pose.erase("hips_side")
				_out = 1.0
				base = Moves.blend(base, _out_pose, 1.0)   # (from this frame on)
				p = base
			move = ""
		else:
			_w = minf(1.0, _w + dt * 14.0)
			var mp := Moves.sample(move, t, move_mirror)
			p = Moves.blend(base, mp, _w)
			lift = float(mp.get("y", 0.0))
			yaw_add = deg_to_rad(float(mp.get("yaw", 0.0)))
			# Walking between points with a move of his own still playing (picking the ball up, lobbing it to the
			# thrower, cheering, a slump): his legs walk and the move keeps his arms and back. Standing, the move's
			# legs slid him along (the owner saw it). Not a kick he is still finishing as the point ends, and less
			# the further he is off the floor (a jump for joy).
			var k := 0.0
			if stroll and speed > 0.4 and move in STROLL_MOVES:
				k = clampf((speed - 0.4) / 0.6, 0.0, 1.0) * clampf(1.0 - lift / 0.08, 0.0, 1.0)
			# In the rally too: a move begun while he is still on his way (getting to a dig, a set, a block, a spike) -
			# he steps or shuffles under it, its legs his own only from a little before he leaves the floor or meets the
			# ball (Moves.legs_from) until its follow-through is done, then his stride's again as he goes back. Before,
			# the move's legs stood still as he slid to the spot: a blocker folded into his crouch, gliding along the
			# net (the owner saw it).
			var from := Moves.legs_from(move)
			var ts := now - move_start
			if not (stroll and move in STROLL_MOVES) and speed > 0.4:
				var c := Moves.contact_time(move)
				var before := 1.0 - smoothstep(from - 0.12, from, ts) if from < INF else 1.0
				var after := smoothstep(c + FOLLOW_THROUGH, c + FOLLOW_THROUGH + 0.15, ts) if c > 0.0 else 0.0
				k = clampf((speed - 0.4) / 0.6, 0.0, 1.0) * clampf(1.0 - lift / 0.08, 0.0, 1.0) * maxf(before, after)
			# (handed over at most STEP_EASE a second - his speed falls fast as he arrives, and the legs jolted - but in
			# time for the move to have its own by the moment it needs them)
			var ease := STEP_EASE
			if from < INF and ts < from and k < _step_w:
				ease = maxf(ease, (_step_w - k) / maxf(from - ts, 0.05))
			_step_w = move_toward(_step_w, k, ease * dt)
			k = _step_w
			if k > 0.0:
				for bone in LEGS:
					if base.has(bone):
						p[bone] = Moves._mix(p.get(bone, Vector3.ZERO), base[bone], k)
				p["hips_y"] = lerpf(float(p.get("hips_y", 0.0)), float(base.get("hips_y", 0.0)), k)
	if move == "":
		_w = 0.0
		_step_w = 1.0   # (a move begun from here starts from his stride)
	# (Off the floor and turned as the pose has him: the move's, or one eased out of.)
	lift = maxf(lift, float(base.get("y", 0.0)))
	yaw_add = deg_to_rad(float(p.get("yaw", 0.0)))
	_last_p = p.duplicate()
	_last_p["y"] = lift
	_last_p["yaw"] = rad_to_deg(yaw_add)
	_life_pose(p, dt, now, speed)
	body.rotation.y = _yaw + yaw_add
	body.position.y = lift
	_shadow.scale = Vector3.ONE * clampf(1.0 - lift * 0.4, 0.5, 1.0)
	body.apply(p)
	if body.link:
		_drive_link(dt, speed)


## The shared foundation's body (FoundationLink): the game's whole pose, except walking between points with no move
## of his own playing or about to - the motion capture's walk (the ball in his hands as the game holds it).
func _drive_link(dt: float, speed: float) -> void:
	var l := body.link
	var walking := l.mode in ["move", "carry"]
	var free := stroll and move == "" and _queued == "" and absf(body.position.y) < 0.01
	walking = free and (speed > (0.45 if walking else 0.6))
	l.want = ("carry" if carrying else "move") if walking else "full"
	l.vel = vel
	l.yaw = _yaw
	l.look = look_at_pos
	if move != "" or _queued != "" or carrying:
		l.pose_every = 1   # (his touch, his catch: drawn on its frame)
	l.update(dt)


## Where the ball in his hands is drawn: in the foundation's hands when it draws him, else carry_point().
func drawn_carry_point() -> Vector3:
	if body.link:
		var p := body.link.ball_point(false)
		if p.is_finite():
			return p
	return carry_point()


## A man standing is never still: his breath, his weight from one foot to the other now and then, his head on the
## ball, his arms; waiting for a serve, on his toes, the knees working (ready_bounce). Carrying the ball: in his right
## hand, by his hip as he walks, held out in front of him standing; the thrower set to throw, down in his crouch with
## it held low (toss_crouch). Laid over the stance or the stride, eased out as he runs or plays a move.
func _life_pose(p: Dictionary, dt: float, now: float, speed: float) -> void:
	_life += dt * _life_rate
	var still := (1.0 - clampf(speed / 0.8, 0.0, 1.0)) * (1.0 - _w)
	_ready_w = move_toward(_ready_w, ready_bounce, dt * 2.0)
	if now >= _next_shift:
		_next_shift = now + randf_range(2.5, 6.5) * (0.5 if ready_bounce > 0.5 else 1.0)
		_shift_to = (1.0 if _shift_to <= 0.0 else -1.0) * randf_range(0.4, 1.0)
	_shift += (_shift_to - _shift) * (1.0 - exp(-dt * (3.0 if _ready_w > 0.5 else 1.5)))
	var b := sin(_life * 1.6)            # the breath, every 4 s or so
	var sway := sin(_life * 0.7) * 1.5
	var s := _shift * (1.0 - _ready_w * 0.6) * (1.0 - _carry_w * 0.7)   # (holding the ball, his body steadier)
	var free := absf(s)
	var k := still
	_add(p, "spine", Vector3(0.8 * b, 0, sway - s * 3.0) * k)
	_add(p, "chest", Vector3(1.4 * b, 0, sway * 0.4) * k)
	_add(p, "hips", Vector3(0, 0, s * 3.0) * k)
	_add(p, "thigh_l", Vector3(-6.0 * free * float(s > 0.0), 0, -s * 2.5) * k)
	_add(p, "thigh_r", Vector3(-6.0 * free * float(s < 0.0), 0, -s * 2.5) * k)
	_add(p, "shin_l", Vector3(11.0 * free * float(s > 0.0), 0, 0) * k)
	_add(p, "shin_r", Vector3(11.0 * free * float(s < 0.0), 0, 0) * k)
	_add(p, "upperarm_l", Vector3(2.0 * sin(_life * 0.9), 0, 0.8 * b) * k)
	_add(p, "upperarm_r", Vector3(-2.0 * sin(_life * 0.9 + 1.0), 0, -0.8 * b) * k)
	_add(p, "forearm_l", Vector3(-5.0 * sin(_life * 1.1), 0, 0) * k)
	_add(p, "forearm_r", Vector3(-5.0 * sin(_life * 1.3 + 2.0), 0, 0) * k)
	# Ready for the serve: lower, on the balls of his feet, a small bounce in the knees and the weight moving.
	if _ready_w > 0.0:
		var r := _ready_w * k
		var bounce := 0.5 + 0.5 * sin(_life * 6.5)
		p["hips_y"] = float(p.get("hips_y", 0.0)) - (0.035 + 0.025 * bounce) * r
		p["hips_side"] = float(p.get("hips_side", 0.0)) + 0.035 * sin(_life * 2.1) * r
		_add(p, "spine", Vector3(6.0, 0, 0) * r)
		for leg in ["l", "r"]:
			_add(p, "thigh_" + leg, Vector3(-10.0 - 8.0 * bounce, 0, 0) * r)
			_add(p, "shin_" + leg, Vector3(18.0 + 14.0 * bounce, 0, 0) * r)
			_add(p, "foot_" + leg, Vector3(-6.0 - 6.0 * bounce, 0, 0) * r)
		_add(p, "upperarm_l", Vector3(-10.0, 0, 6.0) * r)
		_add(p, "upperarm_r", Vector3(-10.0, 0, -6.0) * r)
	# The thrower set to throw: down into his crouch over CROUCH_TIME, the ball held low in front of him, as the real
	# ones wait for the server (the World Cup broadcast, traced: tools/footage). His throw (toss_low) starts from the
	# same pose and holds it a moment: the crouch eases out within that, so he doesn't move as the throw takes over.
	_crouch = move_toward(_crouch, 1.0 if toss_crouch and move == "" and speed < 0.6 else 0.0,
		dt / (CROUCH_TIME if move == "" and speed < 0.6 else 0.25))
	var crouch := smoothstep(0.0, 1.0, _crouch)
	if move != "" and crouch > 0.0:
		_carry_w = 0.0   # (and the throw's arms are his from its start)
	if crouch > 0.0:
		for bone in Moves.LOW_HOLD:
			if not bone.begins_with("upperarm") and not bone.begins_with("forearm"):
				p[bone] = Moves._mix(p.get(bone, Moves._rest_of(bone, Moves.LOW_HOLD[bone])), Moves.LOW_HOLD[bone], crouch)
	# His head on what he watches (the ball, the server), the neck taking a little of the turn.
	var d: Vector3 = body.global_transform.affine_inverse() * look_at_pos
	var want := Vector2(clampf(rad_to_deg(atan2(d.x, d.z)), -70.0, 70.0),
		clampf(-rad_to_deg(atan2(d.y - 1.55, Vector2(d.x, d.z).length())), -30.0, 25.0))
	_head += (want - _head) * (1.0 - exp(-dt * 6.0))
	var hw := 1.0 - _w
	_add(p, "neck", Vector3(_head.y * 0.35, _head.x * 0.3, 0) * hw)
	_add(p, "head", Vector3(_head.y * 0.55, _head.x * 0.5, 0) * hw)
	# The ball in his hand: held out in front standing, by his hip walking, low in the crouch (and both arms the
	# crouch's there).
	_carry_w = move_toward(_carry_w, 1.0 if carrying and move == "" else 0.0, dt * 6.0)
	_hold = move_toward(_hold, 1.0 if speed < 0.6 else 0.0, dt * 4.0)
	if _carry_w > 0.0:
		for bone in CARRY_ARMS:
			var to = Moves._mix(CARRY_ONE.get(bone, p.get(bone, Vector3.ZERO)), Moves.HOLD.get(bone, p.get(bone, Vector3.ZERO)), _hold)
			if crouch > 0.0:
				to = Moves._mix(to, Moves.LOW_HOLD.get(bone, to), crouch)
			p[bone] = Moves._mix(p.get(bone, Vector3.ZERO), to, _carry_w)
	elif crouch > 0.0:
		for bone in CROUCH_ARMS:
			p[bone] = Moves._mix(p.get(bone, Vector3.ZERO), Moves.LOW_HOLD[bone], crouch)


const LEGS := ["thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
const STROLL_MOVES := ["pick", "toss", "celebrate", "fist", "clap", "point", "slump"]   # (played between points)
const GAIT_SPEED := 0.6     # m/s: going this fast, turned to run, backpedal or shuffle straight (see tick)
const SHUFFLE_MAX := 2.2    # m/s: faster than this a long way, he turns and runs
const STRIDE_MAX := 22.0    # rad/s: the stride's quickest (seven steps a second)
const YAW_MAX := 9.5        # rad/s: his quickest turn on his feet (about 540 degrees a second) ...
const YAW_MOVE := 16.0      # ... and squaring up for a move
const ARRIVE_EARLY := 0.15  # s: at the spot this long before his move starts (Player.tick) ...
const ARRIVE_MIN := 1.0     # ... going at least this fast (m/s)
const FOLLOW_THROUGH := 0.22   # s after the touch the move keeps its legs (the kick's follow-through)
const STEP_EASE := 6.0         # a second: the legs handed between his stride and a move's
const MOVE_OUT := 0.15   # s to ease out of a move that has played out or been cut short


## The right arm carrying the ball by his hip as he walks (standing, it is held out in front: Moves.HOLD).
const CARRY_ONE := {"upperarm_r": Vector3(-16, 0, -14), "forearm_r": Vector3(-58, 0, 0), "hand_r": Vector3(0, 0, 10)}
const CARRY_ARMS := ["upperarm_r", "forearm_r", "hand_r", "upperarm_l", "forearm_l"]
const CROUCH_ARMS := ["upperarm_r", "forearm_r", "upperarm_l", "forearm_l"]
const CROUCH_TIME := 0.8   # s down into the thrower's crouch (about the footage's)


## Where the ball sits when he carries it: in his right hand.
func carry_point() -> Vector3:
	return _palm("r")


## Down in the thrower's crouch, ready to throw.
func crouched() -> bool:
	return _crouch >= 1.0


func _palm(lr: String) -> Vector3:
	var hand := body.bone_world("hand_" + lr)
	var fore := body.bone_world("forearm_" + lr)
	return hand + (hand - fore).normalized() * 0.07


## Turns a bone of the pose further by v (degrees), whether the pose has it in degrees or (motion capture) as a turn.
static func _add(p: Dictionary, bone: String, v: Vector3) -> void:
	var cur = p.get(bone, Vector3.ZERO)
	if cur is Quaternion:
		p[bone] = (cur as Quaternion) * RealBody.local_rot(v)
	else:
		p[bone] = (cur as Vector3) + v

