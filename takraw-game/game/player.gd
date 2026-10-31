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
var carrying := false      # the ball in his hands (Match keeps it there): in one hand as he walks, both standing
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
var _yaw := 0.0
var _carry_w := 0.0        # eased: how much his arms hold the ball
var _two := 1.0            # eased: both hands (standing) .. one (walking)
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


func _ready() -> void:
	add_child(body)
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
	move = name
	move_start = now
	move_mirror = mirror
	_queued = ""


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
		want = to.normalized() * minf(top, to.length() * (2.5 if stroll else 4.5))   # (a walk slows sooner)
	if airborne:
		want = vel   # no changing course in the air
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
	_yaw = lerp_angle(_yaw, want_yaw, minf(1.0, 10.0 * dt))
	# The pose: the move if one is playing, blended over the run or the ready stance.
	var speed := vel.length()
	var local := vel.rotated(Vector3.UP, -_yaw)
	# Stepping backwards (backpedalling, facing the net): the stride played backwards, so his feet step back too.
	var back := speed > 0.4 and local.z < -0.5 * speed
	_ph += dt * (4.0 + speed * 2.2) * (-1.0 if back else 1.0)
	# A footstep each half stride while he runs (two to a turn of the stride's phase).
	var half := floori(_ph / PI)
	if half != _half:
		_half = half
		if speed > 1.2 and move == "":
			Sfx.step(global_position, speed)
	var sidestep := clampf(local.x / maxf(speed, 0.01), -1.0, 1.0) if speed > 0.4 else 0.0
	var base := Moves.run(_ph, clampf(speed / 5.0, 0.0, 1.0), sidestep * 0.8)
	var p := base
	var lift := 0.0
	var yaw_add := 0.0
	if move != "":
		var t := (now - move_start) / Moves.length(move)
		if t >= 1.0:
			_carry(move, move_mirror)
			move = ""
		else:
			_w = minf(1.0, _w + dt * 14.0)
			var mp := Moves.sample(move, t, move_mirror)
			p = Moves.blend(base, mp, _w)
			lift = float(mp.get("y", 0.0))
			yaw_add = deg_to_rad(float(mp.get("yaw", 0.0)))
	if move == "":
		_w = 0.0
	_life_pose(p, dt, now, speed)
	body.rotation.y = _yaw + yaw_add
	body.position.y = lift
	_shadow.scale = Vector3.ONE * clampf(1.0 - lift * 0.4, 0.5, 1.0)
	body.apply(p)


## A man standing is never still: his breath, his weight from one foot to the other now and then, his head on the
## ball, his arms; waiting for a serve, on his toes, the knees working (ready_bounce). Carrying the ball: in his right
## hand as he walks, in both in front of him standing. Laid over the stance or the stride, eased out as he runs or
## plays a move.
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
	# His head on what he watches (the ball, the server), the neck taking a little of the turn.
	var d: Vector3 = body.global_transform.affine_inverse() * look_at_pos
	var want := Vector2(clampf(rad_to_deg(atan2(d.x, d.z)), -70.0, 70.0),
		clampf(-rad_to_deg(atan2(d.y - 1.55, Vector2(d.x, d.z).length())), -30.0, 25.0))
	_head += (want - _head) * (1.0 - exp(-dt * 6.0))
	var hw := 1.0 - _w
	_add(p, "neck", Vector3(_head.y * 0.35, _head.x * 0.3, 0) * hw)
	_add(p, "head", Vector3(_head.y * 0.55, _head.x * 0.5, 0) * hw)
	# The ball in his hands.
	_carry_w = move_toward(_carry_w, 1.0 if carrying and move == "" else 0.0, dt * 6.0)
	_two = move_toward(_two, 1.0 if speed < 0.6 else 0.0, dt * 4.0)
	if _carry_w > 0.0:
		for bone in CARRY_TWO:
			var to = Moves._mix(p.get(bone, Vector3.ZERO), CARRY_TWO[bone], _two)
			if CARRY_ONE.has(bone):
				to = Moves._mix(CARRY_ONE[bone], CARRY_TWO[bone], _two)
			p[bone] = Moves._mix(p.get(bone, Vector3.ZERO), to, _carry_w)


## The arms carrying the ball: both hands holding it in front of him, or the right hand by his hip as he walks.
const CARRY_TWO := {"upperarm_l": Vector3(-34, 0, -10), "forearm_l": Vector3(-72, 0, 0), "hand_l": Vector3(0, 0, -20),
	"upperarm_r": Vector3(-34, 0, 10), "forearm_r": Vector3(-72, 0, 0), "hand_r": Vector3(0, 0, 20)}
const CARRY_ONE := {"upperarm_r": Vector3(-16, 0, -14), "forearm_r": Vector3(-58, 0, 0), "hand_r": Vector3(0, 0, 10)}


## Where the ball sits when he carries it: between his hands, or in his right hand.
func carry_point() -> Vector3:
	var r := _palm("r")
	if _two < 0.5:
		return r
	return (r + _palm("l")) * 0.5


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

