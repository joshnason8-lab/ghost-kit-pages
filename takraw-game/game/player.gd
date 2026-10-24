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

var move := ""             # the move playing, if any
var move_start := 0.0      # when it started (match time)
var move_mirror := false
var _queued := ""          # a move to start at _queued_at
var _queued_at := 0.0
var _queued_mirror := false
var _ph := 0.0             # running stride's phase
var _w := 0.0              # how much the move holds the pose (eases in and out)
var _yaw := 0.0
var _ring: MeshInstance3D
var _shadow: MeshInstance3D

static var _ring_mat: StandardMaterial3D


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
	_yaw = Court.facing(side)
	body.rotation.y = _yaw


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
	var to := target - position
	to.y = 0
	var want := Vector3.ZERO
	if to.length() > 0.03:
		want = to.normalized() * minf(top, to.length() * 4.5)
	if airborne:
		want = vel   # no changing course in the air
	vel = vel.move_toward(want, 16.0 * dt)
	position += vel * dt
	position.y = 0.0
	# Facing: the net, turned toward the ball a little.
	var face := net_dir()
	if watch:
		var tb := look_at_pos - position
		tb.y = 0
		if tb.length() > 0.3:
			face = (face * 1.2 + tb.normalized()).normalized()
	var want_yaw := atan2(face.x, face.z)
	if move != "":
		want_yaw = Court.facing(side)   # moves are made facing the net
	_yaw = lerp_angle(_yaw, want_yaw, minf(1.0, 10.0 * dt))
	# The pose: the move if one is playing, blended over the run or the ready stance.
	var speed := vel.length()
	_ph += dt * (4.0 + speed * 2.2)
	var local := vel.rotated(Vector3.UP, -_yaw)
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
	body.rotation.y = _yaw + yaw_add
	body.position.y = lift
	_shadow.scale = Vector3.ONE * clampf(1.0 - lift * 0.4, 0.5, 1.0)
	body.apply(p)
