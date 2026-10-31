class_name Player
extends Node3D
## One person on the rink: a field player, a goalkeeper or a referee. Movement is written here and only here (step()):
## the AI, your joystick and the match set what a player wants (want_vel, want_face, act), and this turns it into
## motion a body can make, with a top speed, acceleration and turning, so nothing ever snaps in a frame. The legs'
## stride follows the ground actually covered, and the stick and arms follow what he is doing with the ball.

const MAX_SPEED := 7.6        # m/s: a top floorball sprint (about 27 km/h)
const ACCEL := 9.0            # m/s2 from standing
const DECEL := 12.0
const TURN := 9.0             # rad/s the body turns at
const STRIDE := 1.55          # m covered by one stride (two steps) at a run; shorter when slower
const REACH := 0.95           # how far from the feet the blade can play the ball (m)

var data := {}                # the squad entry (DB.squad), or a referee's
var team := 0                 # 0, 1, or -1 for a referee
var role := "F"               # G, C, F, D, or R for a referee
var slot := 0                 # the place in the line: 0 C, 1 LW, 2 RW, 3 LD, 4 RD; 5 the goalkeeper; 6 the sixth
                              # player of an empty net; 9 a penalised player on his way to the penalty bench
var body: Body
var link: FoundationLink      # the shared foundation drawing him (when the build has its licensed clips), else null
var match_node: Node = null

var pos := Vector2.ZERO       # on the floor
var vel := Vector2.ZERO
var facing := 0.0             # radians, 0 along +x
var want_vel := Vector2.ZERO
var want_face := NAN          # where to face, or NAN: the way he moves
var max_speed := MAX_SPEED
var act := ""                 # what the body does now: "", shoot, pass, tackle, save_low, save_high, catch, throw,
                              # signal_*, celebrate, kneel, down
var act_t := 0.0              # time into act
var act_len := 0.0
var windup := 0.0             # a shot being wound up (0 to 1): the stick drawn back, the trunk turned away (match.gd)
var deke_side := 1.0          # a deke's side (+ his left... as the match gives it): the blade pulls the ball that way
var signal_arm := Vector2.ZERO  # a referee's signal: the floor direction an arm points
var stamina := 1.0
var on_rink := true
var off_boards := false       # may go over the boards (to the penalty bench): no board stops him
var in_box := false           # on the penalty bench
var marker: MeshInstance3D    # your player's ring on the floor
var writes := 0               # step() calls this frame: the motion audit checks there is exactly one

var respawned := false        # came back on (from the penalty bench) this frame: the one jump allowed, unseen
var _pending := Vector2(INF, INF)
var _phase := 0.0             # the stride's phase (0..1), advanced by distance covered
var _lean := 0.0
var _crouch := 0.0
var _blade := Vector3(0.2, 0.0, 0.62)   # where the blade is (local), smoothed toward where it should be
var _wob := 0.0
var _down := {"l": true, "r": true}   # each foot on the floor in the captured cycle, for the footsteps
const ARM_REACH := 0.47       # shoulder to the grip at most (m, a 1.80 m player): the hands always reach the stick


func _init(p_data := {}, p_team := 0, p_role := "F", p_slot := 0) -> void:
	data = p_data
	team = p_team
	role = p_role
	slot = p_slot


func _ready() -> void:
	body = Body.new(_look())
	add_child(body)
	if role == "G" or role == "R":
		body.no_stick()
	_place()
	# Drawn with the shared foundation (the owner's model on the shared rig, motion-capture locomotion) when this build
	# has the licensed library (FoundationLink); the game's own body stays, posed and measured, unseen.
	if FoundationLink.enabled():
		link = FoundationLink.new(self, body)
		add_child(link)


## Marks this player as the one you run: a ring on the floor in your team's colour and a bigger number.
func mark(on: bool) -> void:
	if on and marker == null:
		marker = MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(1.6, 1.6)
		marker.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = Ball.ring_texture()
		m.albedo_color = Color(Game.C_YELLOW, 0.95)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		marker.material_override = m
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.position = Vector3(0, 0.008, 0)
		add_child(marker)
		# And a small arrow over his head, seen over the others (no numbers over heads: only yours is marked).
		var arrow := Label3D.new()
		arrow.text = "▼"
		arrow.font = Game.font_bold
		arrow.font_size = 56
		arrow.pixel_size = 0.006
		arrow.outline_size = 10
		arrow.modulate = Game.C_YELLOW
		arrow.outline_modulate = Color(0, 0, 0, 0.6)
		arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		arrow.no_depth_test = true
		arrow.position = Vector3(0, 2.2, 0)
		marker.add_child(arrow)
	if marker:
		marker.visible = on


func _look() -> Dictionary:
	var kit: Array = data.get("kit", [Color("1d4ed8"), Color("1d4ed8"), Color.WHITE])
	if role == "R":
		return {"kind": "referee", "skin": Color(String(data.get("skin", "e8b48f"))), "jersey": Color(String(data.get("shirt", "f2d21b"))), "shorts": Color("15171a"),
			"socks": Color("15171a"), "trim": Color("15171a"), "hair": Color(String(data.get("hair", "3b2a20"))), "hair_style": int(data.get("hair_style", 0)), "height": float(data.get("height", 1.8))}
	var keeper := role == "G"
	var jersey: Color = kit[0]
	var shorts: Color = kit[1]
	if keeper:
		# 403: the goalkeeper's jersey a colour of its own: here the team's colour darkened to tell him apart.
		jersey = Color("2b2f36") if kit[0].get_luminance() > 0.6 else kit[0].lerp(Color("15171a"), 0.5)
		shorts = Color("2b2f36")
	return {"kind": "keeper" if keeper else "player", "skin": Color(String(data.get("skin", "e8b48f"))), "jersey": jersey, "shorts": shorts,
		"socks": kit[0] if not keeper else shorts, "trim": kit[2], "hair": Color(String(data.get("hair", "4a3220"))),
		"hair_style": int(data.get("hair_style", 0)), "height": float(data.get("height", 1.8)), "goggles": bool(data.get("goggles", false)),
		"women": String(data.get("id", "")).substr(3, 1) == "w",
		"stick": Color("1f2933") if int(data.get("num", 0)) % 3 != 0 else Color("e9ecef"), "blade": Color("f4f5f6") if int(data.get("num", 0)) % 2 == 0 else Color("1d1f22")}


## A line change: this place on the rink is now another player (the one who came over the board).
func become(p_data: Dictionary) -> void:
	data = p_data
	if body:
		body.relook(_look())
	if link:
		link.recolour()


func stat(k: String) -> float:
	return float(data.get(k, 60.0))


## A player who shoots left (the blade on his left, the right hand at the top of the stick) or right.
func shoots_left() -> bool:
	return bool(data.get("left", true))


func dir() -> Vector2:
	return Vector2(cos(facing), sin(facing))


var _shot_from := 0.0         # the wind-up a shot started from (its follow-through goes with it)


func do(a: String, length := 0.4) -> void:
	if a == "shoot":
		_shot_from = windup
	act = a
	act_t = 0.0
	act_len = length


## Comes back onto the rink at a place (he was off it, out of sight): taken up in the next step.
func respawn(at: Vector2) -> void:
	_pending = at


## The one place a player's position changes. dt in game seconds.
func step(dt: float) -> void:
	writes += 1
	respawned = false
	if _pending.x != INF:
		pos = _pending
		vel = Vector2.ZERO
		_pending = Vector2(INF, INF)
		respawned = true
	var top := max_speed * (0.65 + 0.35 * stamina)
	var want := want_vel
	if want.length() > top:
		want = want.normalized() * top
	# Accelerate toward the velocity wanted, quicker to slow than to speed up, and turning costs speed.
	var diff := want - vel
	var lim := (ACCEL if want.length() > vel.length() else DECEL) * dt
	if diff.length() > lim:
		diff = diff.normalized() * lim
	vel += diff
	pos += vel * dt
	# The boards: he stops at them (a body cannot pass through).
	if not off_boards and not Rules.in_rink(pos, 0.3):
		var c: Array = Rules.board_contact(pos)
		pos = c[0] + c[1] * 0.3
		var n: Vector2 = c[1]
		var vn := vel.dot(n)
		if vn < 0.0:
			vel -= n * vn
	# Turning: toward want_face, or the way he moves when he is moving.
	var target := facing
	if not is_nan(want_face):
		target = want_face
	elif vel.length() > 0.6:
		target = vel.angle()
	facing = rotate_toward(facing, target, TURN * dt)
	# Stamina: sprinting tires, standing recovers (a shift on the rink is short for this reason).
	var effort := vel.length() / MAX_SPEED
	stamina = clampf(stamina - (effort * effort * 0.018 - 0.006) * dt, 0.35, 1.0)
	if act != "":
		act_t += dt
		if act_t >= act_len:
			act = ""
	_animate(dt)
	_place()
	if link:
		link.update(dt)


func _place() -> void:
	position = Vector3(pos.x, 0, pos.y)
	rotation = Vector3(0, PI * 0.5 - facing, 0)


# ---------------------------------------------------------------- the body's motion

## The pose for this frame from what he is doing: the run's stride from distance covered, the stance, the stick.
## On the move the legs, hips and trunk are motion capture (game/mocap.gd: walk, jog and run blended by speed, the
## cycle advanced by the ground covered so the feet stay put while down); over that go the floorball stance (bent
## forward over the stick, knees bent) and the arms on the stick. Standing, turning on the spot and a goalkeeper's
## work are posed here in code.
func _animate(dt: float) -> void:
	if body == null:
		return
	var sp := vel.length()
	var run := clampf(sp / 3.0, 0.0, 1.0)
	# Forward lean with speed, a low stance near the ball (a floorball player plays bent at the knees).
	var lean_want := 40.0 + run * 4.0   # a floorball player plays bent forward over his stick
	if act == "tackle":
		lean_want += 22.0   # and lunges into a tackle
	var crouch_want := 0.0
	match role:
		"G":
			crouch_want = 1.0
			lean_want = 22.0
		"R":
			lean_want = 3.0 + run * 8.0
		_:
			crouch_want = 0.8
	_lean = lerpf(_lean, lean_want, minf(1.0, 6.0 * dt))
	_crouch = lerpf(_crouch, crouch_want, minf(1.0, 6.0 * dt))
	# The legs run the way he moves; the trunk keeps facing where he faces. Moving backward the cycle runs backward.
	var size := float(data.get("height", 1.8)) / 1.8
	var mv := Vector2(vel.dot(dir()), vel.dot(dir().orthogonal()))   # ahead, and to his left
	var yaw := atan2(mv.y, mv.x) if sp > 0.05 else 0.0   # the way he moves, turned from his facing (left +)
	var back := absf(yaw) > deg_to_rad(105.0)
	if back:
		yaw -= signf(yaw) * PI
	var legs_yaw := clampf(yaw, -deg_to_rad(70.0), deg_to_rad(70.0))
	var along := sp * cos(yaw - legs_yaw) * (-1.0 if back else 1.0)   # ground covered along the legs' way
	var moc := 0.0
	var gait := {}
	if role != "G" and Mocap.available():
		moc = smoothstep(0.15, 0.9, sp)
		var g: Array = Mocap.gaits_at(sp / size)
		var stride_m: float = lerpf(g[0].stride, g[1].stride, g[2]) * size
		var stride_p := STRIDE * clampf(0.45 + sp / MAX_SPEED * 0.55, 0.45, 1.0)
		_phase = fposmod(_phase + along * dt / lerpf(stride_p, stride_m, moc), 1.0)
		var w: float = g[2]
		var arms := role == "R"
		gait = Mocap.sample(g[0], _phase, arms) if w < 0.02 else (Mocap.sample(g[1], _phase, arms) if w > 0.98 else
			Mocap.blend(Mocap.sample(g[0], _phase, arms), Mocap.sample(g[1], _phase, arms), w))
		gait.lean = lerpf(g[0].lean, g[1].lean, g[2])
		_footsteps(g[0] if g[2] < 0.5 else g[1], sp, moc)
	else:
		var stride := STRIDE * clampf(0.45 + sp / MAX_SPEED * 0.55, 0.45, 1.0)
		_phase = fposmod(_phase + absf(along) * dt / stride, 1.0)
	# The cycle's phase 0 is the left foot at its farthest forward.
	var k := cos(_phase * TAU)
	var k2 := -k
	var swing := 34.0 * run
	var p := {}
	var knee := 12.0 + _crouch * 30.0
	p.thigh_l = Vector3(-k * swing - knee * 0.6, 0, 3)
	p.thigh_r = Vector3(-k2 * swing - knee * 0.6, 0, -3)
	p.shin_l = Vector3(knee + maxf(0.0, -sin(_phase * TAU)) * 55.0 * run, 0, 0)
	p.shin_r = Vector3(knee + maxf(0.0, sin(_phase * TAU)) * 55.0 * run, 0, 0)
	p.foot_l = Vector3(-knee * 0.4, 0, 0)
	p.foot_r = Vector3(-knee * 0.4, 0, 0)
	p.hips_y = -0.03 - _crouch * 0.12 + absf(sin(_phase * TAU * 2.0)) * 0.035 * run
	p.spine = Vector3(_lean * 0.45, 0, 0)
	p.chest = Vector3(_lean * 0.4, k * 4.0 * run, 0)
	# A shot: the trunk turns away to the stick's side as it winds up, and unwinds through the ball past the front.
	if role != "G" and role != "R":
		var sd := 1.0 if shoots_left() else -1.0
		var tw := 0.0
		if windup > 0.0 and act == "":
			tw = 34.0 * windup
		elif act == "shoot":
			var tt := act_t / maxf(0.01, act_len)
			var from := 34.0 * maxf(_shot_from, 0.45)
			tw = lerpf(from, -26.0, clampf(tt / 0.6, 0.0, 1.0))
		var ch: Vector3 = p.chest
		ch.y += tw * 0.6 * sd
		p.chest = ch
		p.spine = Vector3(_lean * 0.45, tw * 0.4 * sd, 0)
	p.head = Vector3(-_lean * 0.6, 0, 0)
	p.upperarm_l = Vector3(k * 28.0 * run, 0, 8)
	p.upperarm_r = Vector3(k2 * 28.0 * run, 0, -8)
	p.forearm_l = Vector3(-35, 0, 0)
	p.forearm_r = Vector3(-35, 0, 0)
	if moc > 0.0:
		_mocap_legs(p, gait, moc, legs_yaw)
	var t := act_t / maxf(0.01, act_len) if act != "" else 0.0
	if role == "G":
		_keeper_pose(p, t, dt)
	elif role == "R":
		_referee_pose(p, t, dt)
	elif act == "celebrate":
		p.upperarm_l = Vector3(-160, 0, 25)
		p.upperarm_r = Vector3(-150, 0, -20)
		p.forearm_l = Vector3(-10, 0, 0)
		p.forearm_r = Vector3(-10, 0, 0)
	body.apply(p)
	if role != "G" and role != "R":
		_stick(dt, t)
	body.sync()


## A footstep as a foot comes down in the captured cycle: your player's, and those of the players near the ball (where
## the play and the camera are; a rink of twelve all heard would be a clatter). Not in the menu's match, nor in a pause.
func _footsteps(c: Dictionary, sp: float, moc: float) -> void:
	for side in ["l", "r"]:
		var d := Mocap.down(c, side, _phase)
		if d and not _down[side] and moc > 0.5 and _heard():
			Sfx.step(Vector3(pos.x, 0.05, pos.y), sp)
		_down[side] = d


func _heard() -> bool:
	if match_node == null or bool(match_node.get("demo")) or bool(match_node.get("paused")):
		return false
	if match_node.get("user_player") == self:
		return true
	var b: Variant = match_node.get("ball")
	return b != null and Vector2(b.pos.x, b.pos.z).distance_to(pos) < 6.0


## Motion capture under the floorball stance: the captured legs, hips and trunk, the legs turned to the way he
## moves (the trunk turned back to face where he faces), the knees bent a little deeper and the trunk bent forward over
## the stick as a layer on top; mixed with the pose in code by w.
func _mocap_legs(p: Dictionary, g: Dictionary, w: float, legs_yaw: float) -> void:
	var turn := Quaternion(Vector3.UP, legs_yaw)
	var hips: Quaternion = turn * g.hips
	var off: Vector3 = turn * (g.hips_off as Vector3)
	var legs := {}
	for b in ["thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r"]:
		legs[b] = g[b]
	# The trunk: the captured sway, turned back to his facing, then bent forward by the stance's lean, less what the
	# captured runner already leans.
	var extra := deg_to_rad(maxf(0.0, _lean - float(g.lean)))
	var spine: Quaternion = hips.inverse() * Quaternion(Vector3.UP, -legs_yaw) * hips * g.spine * Quaternion(Vector3.RIGHT, extra * 0.45)
	var trunk := {
		"hips": hips,
		"spine": spine,
		"chest": (g.chest as Quaternion) * Quaternion(Vector3.RIGHT, extra * 0.4),
		"head": (g.head as Quaternion) * Quaternion(Vector3.RIGHT, -extra * 0.6),
	}
	if role == "R" and not act.begins_with("signal_"):
		# A referee runs with his arms free: theirs too.
		for b in ["upperarm_l", "forearm_l", "upperarm_r", "forearm_r"]:
			trunk[b] = g[b]
	# The floorball stance: the hips lower than a jogger's, the knees bending to keep each foot where the capture put it
	# (so a foot that is down stays down where it is). Not on Low, where the picture is small and the phone slow: there
	# they run as captured.
	var cap := {"hips": hips, "hips_side": off.x, "hips_y": off.y, "hips_fwd": off.z}
	cap.merge(legs)
	if int(Game.settings.graphics) != Game.GFX_LOW:
		var feet := [Body.leg(cap, "l")[2], Body.leg(cap, "r")[2]]
		cap.hips_y = off.y - _crouch * 0.1
		Body.leg_ik(cap, "l", feet[0])
		Body.leg_ik(cap, "r", feet[1])
	for b in legs:
		p[b] = Body._q(p[b]).slerp(cap[b], w)
	for b in trunk:
		p[b] = Body._q(p.get(b, Vector3.ZERO)).slerp(trunk[b], w)
	p.hips_y = lerpf(p.hips_y, cap.hips_y, w)
	p.hips_side = off.x * w
	p.hips_fwd = off.z * w


## The stick: blade on the floor in front, to his stick side; drawn back and swept through in a shot, never above the
## waist (507.2: a high stick is an offence).
func _stick(dt: float, t: float) -> void:
	var side := 1.0 if shoots_left() else -1.0
	var want := Vector3(0.24 * side, 0.0, 0.82)
	var top_hand := "r" if shoots_left() else "l"
	var lift := 0.0     # the hands drawn back and up across his chest with the wind-up (0 to 1)
	var follow := 0.0   # and through, high in front, after the shot
	if windup > 0.0 and act == "":
		# Winding up a shot: the blade drawn back along the floor and up behind him, the harder the higher.
		var w := windup
		want = Vector3((0.45 + 0.2 * w) * side, 0.05 + 0.65 * w * w, 0.45 - 1.1 * w)
		lift = w
	match act:
		"shoot", "pass":
			var big := 1.0 if act == "shoot" else 0.55
			if act == "shoot" and _shot_from > 0.0:
				# From a wind-up: the whole sweep through the ball at once, and up into the follow-through.
				var w := clampf(t / 0.35, 0.0, 1.0)
				var back := Vector3((0.45 + 0.2 * _shot_from) * side, 0.05 + 0.65 * _shot_from * _shot_from, 0.45 - 1.1 * _shot_from)
				var thru := Vector3(0.1 * side, 0.03, 0.85)
				var high := Vector3(-0.35 * side, 0.6 + 0.5 * _shot_from, 1.05)
				want = back.lerp(thru, w) if t < 0.35 else thru.lerp(high, clampf((t - 0.35) / 0.4, 0.0, 1.0))
				lift = _shot_from * (1.0 - w)
				follow = clampf((t - 0.35) / 0.4, 0.0, 1.0) * (0.5 + 0.5 * _shot_from)
			elif t < 0.4:
				# The back-swing: the blade back and up, to the waist (a slap shot to the shoulder).
				var w := t / 0.4
				want = Vector3((0.35 + 0.3 * w * big) * side, 0.05 + 0.75 * w * big, 0.4 - 0.8 * w * big)
				lift = 0.7 * w * big
			else:
				# Through the ball and up into a follow-through at the chest.
				var w := (t - 0.4) / 0.6
				want = Vector3((0.65 * big - 1.05 * w) * side * (1.0 if big > 0.6 else 0.6), maxf(0.0, 0.8 * big * (1.0 - w * 2.2)) + 0.55 * maxf(0.0, w - 0.45) * big, -0.4 * big + 1.45 * w)
				lift = 0.7 * big * maxf(0.0, 1.0 - w * 2.0)
				follow = maxf(0.0, w - 0.45) / 0.55 * big
		"deke":
			# The blade pulls the ball across, as if to shoot that way, and back.
			want = Vector3((0.1 + 0.42 * sin(clampf(t, 0.0, 1.0) * PI)) * deke_side, 0.0, 0.8)
		"tackle":
			want = Vector3(0.1 * side, 0.0, 0.95 + 0.2 * sin(t * PI))
		"dribble":
			pass
		"celebrate":
			want = Vector3(0.3 * side, 0.9, 0.2)
	if act == "" and windup <= 0.0 and match_node and match_node.has_method("has_ball") and match_node.has_ball(self):
		# Dribbling: the blade works the ball side to side in front of him.
		_wob += dt * (7.0 + vel.length() * 0.6)
		want = Vector3((0.14 + 0.16 * sin(_wob)) * side, 0.0, 0.76 + vel.length() * 0.03)
	var rate := 26.0 if act in ["shoot", "pass", "tackle"] else 12.0
	_blade = _blade.lerp(want, minf(1.0, rate * dt))
	# Heel on the floor (or where the swing has it), the grip end near the top hand's hip.
	var grip := Vector3(-0.06 * side, 0.96 - _crouch * 0.14, 0.27)
	grip = grip.lerp(Vector3(-0.18 * side, 1.12, 0.16), lift).lerp(Vector3(-0.28 * side, 1.18, 0.42), follow)
	var heel := _blade + Vector3(-0.06 * side, 0.0, -0.06)
	var shaft := heel - grip
	if shaft.length() > Body.STICK_LEN:
		grip = heel - shaft.normalized() * Body.STICK_LEN
	else:
		heel = grip + shaft.normalized() * Body.STICK_LEN
	heel.y = maxf(heel.y, 0.01)
	# The grip within the top hand's reach: the point of the stick's reach round the blade nearest his shoulder, and the
	# blade drawn in toward him when even that is too far (a lunge the arms cannot make; the play keeps _blade).
	var sh := body.shoulder(top_hand)
	if grip.distance_to(sh) > ARM_REACH:
		grip = heel + (sh - heel).normalized() * Body.STICK_LEN
		if grip.distance_to(sh) > ARM_REACH:
			heel = sh + (heel - sh).normalized() * (Body.STICK_LEN + ARM_REACH)
			heel.y = maxf(heel.y, 0.01)
			grip = heel + (sh - heel).normalized() * Body.STICK_LEN
	# The blade carries on from the shaft along the floor (the stick's lie), its toe away from him, its face to the
	# ball.
	var toe := Vector3(heel.x - grip.x, 0, heel.z - grip.z)
	toe = toe.normalized() if toe.length() > 0.01 else Vector3(0.3 * side, 0, 1.0).normalized()
	body.place_stick(grip, heel, toe, top_hand, 0.24)


## Where the blade is now, on the floor (for the ball to sit on and for tackles).
func blade_floor() -> Vector2:
	var w := global_transform * (_blade * (float(data.get("height", 1.8)) / 1.8))
	return Vector2(w.x, w.z)


## Where a dribbled ball sits: against the blade's face, toward its middle (the blade runs on from the heel, away
## from him, along the floor; its face is the side toward his front).
func ball_spot() -> Vector3:
	var heel := blade_floor()
	var out := heel - pos
	out = out.normalized() if out.length() > 0.01 else dir()
	var face := out.orthogonal()
	if face.dot(dir()) < 0.0:
		face = -face
	var b := heel + out * 0.14 + face * 0.05
	return Vector3(b.x, Ball.R, b.y)


var _kneel := 0.0              # a goalkeeper down on his knees (1) or standing in his crouch (0), eased between
var _shuffle := 0.0           # his side-steps' (or knee-shuffles') phase, advanced by the ground covered sideways
var _kp := {}                 # his last pose: every pose eases into the next (nothing snaps)


## A floorball goalkeeper (no stick; 303) works mostly on his knees: down in a wide butterfly, upright, hands open in
## front, when the ball is in front of his goal; up in a deep crouch, feet wide, when it is far off. He moves along
## his line in side-steps standing and in short knee-shuffles kneeling. A low save is a leg kicked out flat to the
## ball's side, the other knee down; a high one an arm thrown up and the body leaning after it; a catch both hands to
## the chest; the throw-out overarm. Each pose eases into the next.
func _keeper_pose(p: Dictionary, t: float, dt: float) -> void:
	var b := _ball_floor()
	var own_x := signf(pos.x) * Rules.GOAL_LINE if absf(pos.x) > 1.0 else Rules.GOAL_LINE
	var ahead := (own_x - b.x) * signf(own_x)        # how far the ball is out in front of his goal line
	var near := ahead > -0.5 and ahead < 10.0 and absf(b.y) < 7.0
	if match_node and String(match_node.get("phase")) == "shootout":
		near = ahead < 11.0
	var down_want := 1.0 if near or act in ["kneel", "save_low"] else 0.0
	if act in ["throw", "celebrate"]:
		down_want = 0.0
	_kneel = move_toward(_kneel, down_want, dt * (5.0 if down_want > _kneel else 2.5))
	var k := _kneel
	# Sideways: the side-step or knee-shuffle cycle, by ground covered across his facing.
	var lat := vel.dot(dir().orthogonal())
	_shuffle = fposmod(_shuffle + absf(lat) * dt / lerpf(0.55, 0.32, k), 1.0)
	var step := sin(_shuffle * TAU) * clampf(absf(lat) / 1.5, 0.0, 1.0)
	var lead_l := lat > 0.0                         # moving to his left: the left leg leads
	# Standing: the ready crouch, feet wide, hands out in front at the hips.
	var st := {
		"thigh_l": Vector3(-38, 0, 16 + (step * 10.0 if lead_l else -step * 4.0)),
		"thigh_r": Vector3(-38, 0, -16 - (step * 10.0 if not lead_l else -step * 4.0)),
		"shin_l": Vector3(62, 0, 0), "shin_r": Vector3(62, 0, 0),
		"foot_l": Vector3(-24, 0, 0), "foot_r": Vector3(-24, 0, 0),
		"upperarm_l": Vector3(-34, 0, 32), "upperarm_r": Vector3(-34, 0, -32),
		"forearm_l": Vector3(-48, 0, 0), "forearm_r": Vector3(-48, 0, 0),
		"spine": Vector3(14, 0, 0), "chest": Vector3(10, 0, 0), "head": Vector3(-14, 0, 0),
	}
	# Kneeling: the butterfly, both knees down, the shins flared out along the line, the trunk upright, hands open
	# in front at the chest, a little wide.
	var kn := {
		"thigh_l": Vector3(-8 + step * 6.0, 0, 20), "thigh_r": Vector3(-8 - step * 6.0, 0, -20),
		"shin_l": Vector3(104, 0, 42), "shin_r": Vector3(104, 0, -42),
		"foot_l": Vector3(-38, 0, 0), "foot_r": Vector3(-38, 0, 0),
		"upperarm_l": Vector3(-46, 0, 40), "upperarm_r": Vector3(-46, 0, -40),
		"forearm_l": Vector3(-62, 0, 0), "forearm_r": Vector3(-62, 0, 0),
		"spine": Vector3(4, 0, 0), "chest": Vector3(2, 0, 0), "head": Vector3(-4, 0, 0),
	}
	for key in st:
		p[key] = (st[key] as Vector3).lerp(kn[key], k)
	p.hips_y = lerpf(-0.26, -0.56, k) - absf(step) * lerpf(0.02, 0.012, k)
	p.hips_side = 0.0
	# Which side of him the ball is on: + his left.
	var side := 1.0 if (b - pos).dot(dir().orthogonal()) > 0.0 else -1.0
	var sl := "l" if side > 0.0 else "r"
	var ol := "r" if side > 0.0 else "l"
	var rate := 12.0
	match act:
		"save_low":
			# The leg on the ball's side kicked out flat along the floor, the other knee down, the trunk over it, the
			# near hand down to the floor.
			var w := sin(clampf(t * 1.6, 0.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.75, 1.0, t))
			p["thigh_" + sl] = (p["thigh_" + sl] as Vector3).lerp(Vector3(-12, 0, 78 * side), w)
			p["shin_" + sl] = (p["shin_" + sl] as Vector3).lerp(Vector3(6, 0, 0), w)
			p["foot_" + sl] = Vector3(-50 * w, 0, 0)
			p["upperarm_" + sl] = (p["upperarm_" + sl] as Vector3).lerp(Vector3(-25, 0, 70 * side), w)
			p["forearm_" + sl] = Vector3(-15, 0, 0)
			p.chest = Vector3(8, 0, 16 * side * w)
			p.hips_side = 0.22 * side * w
			p.hips_y = -0.6
			rate = 26.0
		"save_high_l", "save_high_r":
			# An arm thrown up on the shot's side, the body leaning after it, the far knee pushing.
			var s := 1.0 if act == "save_high_l" else -1.0
			var hs := "l" if s > 0.0 else "r"
			var w := sin(clampf(t * 1.4, 0.0, 1.0) * PI * 0.5) * (1.0 - smoothstep(0.7, 1.0, t))
			p["upperarm_" + hs] = (p["upperarm_" + hs] as Vector3).lerp(Vector3(-150, 0, 55 * s), w)
			p["forearm_" + hs] = Vector3(-8, 0, 0)
			p["upperarm_" + ("r" if s > 0.0 else "l")] = (p["upperarm_" + ("r" if s > 0.0 else "l")] as Vector3).lerp(Vector3(-60, 0, -45 * s), w)
			p.chest = Vector3(6, 0, 26 * s * w)
			p.spine = Vector3(2, 0, 12 * s * w)
			p.hips_side = 0.32 * s * w
			p.hips_y = (p.hips_y as float) + 0.12 * w * (1.0 - k)
			rate = 26.0
		"catch":
			# Both hands to the chest round the ball, the trunk curled over it.
			p.upperarm_l = Vector3(-58, 0, 10)
			p.upperarm_r = Vector3(-58, 0, -10)
			p.forearm_l = Vector3(-88, 0, 0)
			p.forearm_r = Vector3(-88, 0, 0)
			p.chest = Vector3(16, 0, 0)
			p.head = Vector3(-6, 0, 0)
			rate = 18.0
		"throw":
			# Up, a step into it, the throwing arm from behind the head over the top.
			var w := clampf(t, 0.0, 1.0)
			p.thigh_l = Vector3(-26, 0, 6)
			p.thigh_r = Vector3(14, 0, -6)
			p.shin_l = Vector3(22, 0, 0)
			p.shin_r = Vector3(28, 0, 0)
			p.hips_y = -0.08
			p.upperarm_r = Vector3(lerpf(70.0, -160.0, smoothstep(0.25, 0.75, w)), 0, -12)
			p.forearm_r = Vector3(lerpf(-70.0, -10.0, smoothstep(0.3, 0.8, w)), 0, 0)
			p.upperarm_l = Vector3(lerpf(-70.0, 20.0, w), 0, 20)
			p.chest = Vector3(lerpf(-12.0, 18.0, w), lerpf(-20.0, 15.0, w), 0)
			rate = 16.0
		"celebrate":
			p.upperarm_l = Vector3(-160, 0, 25)
			p.upperarm_r = Vector3(-160, 0, -25)
			p.hips_y = -0.02
			p.thigh_l = Vector3(0, 0, 4)
			p.thigh_r = Vector3(0, 0, -4)
			p.shin_l = Vector3(5, 0, 0)
			p.shin_r = Vector3(5, 0, 0)
	# Ease from his last pose into this one.
	var a := 1.0 - exp(-rate * dt)
	for key in p:
		var v: Variant = p[key]
		if _kp.has(key) and typeof(_kp[key]) == typeof(v):
			if v is Vector3:
				p[key] = (_kp[key] as Vector3).lerp(v, a)
			elif v is float:
				p[key] = lerpf(float(_kp[key]), float(v), a)
		_kp[key] = p[key]


## Where the ball is on the floor (the match's), or the middle of the rink.
func _ball_floor() -> Vector2:
	if match_node == null or not is_instance_valid(match_node):
		return Vector2.ZERO
	var bl: Variant = match_node.get("ball")
	if bl == null:
		return Vector2.ZERO
	return (bl as Node).call("floor_pos")


## A referee's signals, as the IFF's signs show them (docs/RULES.md, "Officials"): the consequence first, then the
## offence where it is needed. signal_arm is the direction the arm points along the floor.
func _referee_pose(p: Dictionary, t: float, _dt: float) -> void:
	if not act.begins_with("signal_"):
		return
	var kind := act.substr(7)
	# The arm toward the direction: its yaw in his own frame.
	var local := signal_arm.rotated(-facing)   # x ahead of him, y to his right
	var yaw := rad_to_deg(atan2(local.y, local.x))
	var right_side := yaw > 0.0   # the floor's +z is a player's right when he faces +x
	var arm := "upperarm_r" if right_side else "upperarm_l"
	var other := "upperarm_l" if right_side else "upperarm_r"
	var s := -1.0 if right_side else 1.0
	match kind:
		"free_hit":
			# One arm out level, pointing the way the free-hit goes (the foot marks the spot).
			p[arm] = Vector3(-90 * cos(deg_to_rad(absf(yaw))), 0, 90 * s * sin(deg_to_rad(absf(yaw))) + 0.0)
			p[arm.replace("upper", "fore")] = Vector3(0, 0, 0)
		"hit_in":
			# The arm out and angled down toward the floor, the way the hit-in goes.
			p[arm] = Vector3(-55 * cos(deg_to_rad(absf(yaw))), 0, 55 * s * sin(deg_to_rad(absf(yaw))))
			p[arm.replace("upper", "fore")] = Vector3(0, 0, 0)
		"advantage":
			# Advantage: the arm out forward and up, the way the play goes.
			p[arm] = Vector3(-130 * cos(deg_to_rad(absf(yaw))), 0, 60 * s * sin(deg_to_rad(absf(yaw))))
			p[arm.replace("upper", "fore")] = Vector3(0, 0, 0)
		"passive":
			# Passive play: the arm raised forward and up, held while the warning stands [verify the sign].
			p.upperarm_r = Vector3(-140, 0, -10)
			p.forearm_r = Vector3.ZERO
		"delayed":
			# A delayed penalty: one arm straight up, held until play stops.
			p.upperarm_r = Vector3(-180, 0, -5)
			p.forearm_r = Vector3.ZERO
		"goal":
			# A goal: the arm points to the centre spot.
			p[arm] = Vector3(-90 * cos(deg_to_rad(absf(yaw))), 0, 90 * s * sin(deg_to_rad(absf(yaw))))
			p[arm.replace("upper", "fore")] = Vector3.ZERO
		"no_goal":
			# No goal: both arms swept out sideways, level.
			var w := sin(t * PI * 3.0)
			p.upperarm_l = Vector3(-90, 0, 40 * w)
			p.upperarm_r = Vector3(-90, 0, -40 * w)
			p.forearm_l = Vector3.ZERO
			p.forearm_r = Vector3.ZERO
		"pen2", "pen5":
			# A bench penalty: the arm up, fingers showing two minutes or five.
			p.upperarm_r = Vector3(-165, 0, -15)
			p.forearm_r = Vector3(-10, 0, 0)
			p.upperarm_l = Vector3(0, 0, 10)
		"pen10", "match":
			# A personal penalty: both hands up (ten); a match penalty: the red card held high.
			p.upperarm_r = Vector3(-170, 0, -15)
			p.upperarm_l = Vector3(-170, 0, 15) if kind == "pen10" else Vector3(0, 0, 10)
			p.forearm_r = Vector3.ZERO
			p.forearm_l = Vector3.ZERO
		"penalty_shot":
			# A penalty shot: the arm points to the centre spot, then the arms cross above the head.
			if t < 0.5:
				p[arm] = Vector3(-90, 0, 90 * s * 0.5)
			else:
				p.upperarm_l = Vector3(-165, 0, -25)
				p.upperarm_r = Vector3(-165, 0, 25)
				p.forearm_l = Vector3(0, 0, -30)
				p.forearm_r = Vector3(0, 0, 30)
		"face_off":
			# A face-off: pointing down at the dot.
			p[arm] = Vector3(-40, 0, 20 * s)
		"timeout":
			# Time-out: the hands make a T.
			p.upperarm_r = Vector3(-90, 0, -10)
			p.forearm_r = Vector3(0, 0, 80)
			p.upperarm_l = Vector3(-90, 0, 10)
			p.forearm_l = Vector3(-90, 0, 0)
	p[other] = p.get(other, Vector3(0, 0, 8 * -s))
