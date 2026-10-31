class_name Officials
extends Node3D
## The match officials (Rules of Control): the referee, who keeps the time and gives every decision, signalling it
## as referees do (an arm out the way of a free, an arm straight up for advantage, the card held up, ten fingers
## for the sin bin, both arms to the 20 m line for a penalty); two linesmen along the side lines, flag out the way a
## sideline cut goes; four umpires in white coats, two at each end beside the posts: the white flag waved for a
## point, the green for a goal, arms crossed over the head for a wide, an arm straight up and then pointing in for
## a 65.

var m: Node
var people: Array = []
var referee: Player
var linesmen: Array = []
var umpires: Array = []     # [end -x left, end -x right, end +x left, end +x right]
var _ref_signal_until := 0.0
var _adv := false


func _init(p_match: Node) -> void:
	m = p_match


func _ready() -> void:
	var ref_look := {"kind": "referee", "jersey": Color("1a1a1a"), "trim": Color("f2c230"), "skin": Color("e8bc9a"),
		"hair": Color("3a2a1c"), "height": 1.8}
	referee = Player.new({"num": 0, "line": -1}, -1, ref_look, "referee")
	add_child(referee)
	people.append(referee)
	for i in 2:
		var lk := ref_look.duplicate()
		lk.jersey = Color("2a2a2a")
		var ln := Player.new({"num": 0, "line": -1}, -1, lk, "linesman")
		add_child(ln)
		linesmen.append(ln)
		people.append(ln)
	for i in 4:
		var uk := {"kind": "umpire", "jersey": Color("f4f4f0"), "trim": Color("f4f4f0"), "skin": Color("e8bc9a"),
			"hair": Color("6a6a6a"), "height": 1.76}
		var u := Player.new({"num": 0, "line": -1}, -1, uk, "umpire")
		add_child(u)
		umpires.append(u)
		people.append(u)
	_place_umpires()


func _place_umpires() -> void:
	for i in 4:
		var u: Player = umpires[i]
		var s := -1.0 if i < 2 else 1.0
		var zs := -1.0 if i % 2 == 0 else 1.0
		u.position = Vector3((Pitch.HALF_L + 0.6) * s, 0, (Pitch.POST_GAP * 0.5 + 1.0) * zs)
		u.face_to = Vector3(0, 0, u.position.z * 0.5)
		u.yaw = atan2(-s, 0.0)


func place_for_throw_in() -> void:
	referee.position = Vector3(0, 0, 3.0)
	referee.vel = Vector3.ZERO
	linesmen[0].position = Vector3(0, 0, -Pitch.HALF_W - 1.5)
	linesmen[1].position = Vector3(0, 0, Pitch.HALF_W + 1.5)
	_place_umpires()


func throw_in() -> void:
	referee.face_to = Vector3(0, 0, 0)
	referee.play("sig_throw")


## Every frame: the referee keeps up with play, behind it and off to the camera's far side (a diagonal), never in the
## ball's way; the linesmen move along their lines with it; the umpires keep to their posts.
func tick(_dt: float) -> void:
	var b: Vector3 = m.ball.global_position
	var lead := Vector3.ZERO
	if m.carrier != null:
		lead = Vector3(m.dir(m.carrier.team) * -12.0, 0, 0)
	var want := Vector3(b.x, 0, b.z) + lead + Vector3(0, 0, -12.0 if b.z > -20.0 else 10.0)
	want = Pitch.clamp_in(want, 2.0)
	if m.phase in [m.P.SETUP, m.P.SET] and not m.restart.is_empty():
		var rs: Vector3 = m.restart.spot
		want = Pitch.clamp_in(rs + Vector3(0, 0, -10.0 if rs.z > -20.0 else 10.0), 2.0)
		if String(m.restart.kind) == "penalty":
			want = Pitch.penalty_spot(m.dir(int(m.restart.team))) + Vector3(-m.dir(int(m.restart.team)) * 3.0, 0, 8.0)
	_go(referee, want, 6.0)
	if not referee.busy() and not referee.action.begins_with("sig_"):
		referee.face_to = b
	elif referee.action.begins_with("sig_") and m.now > _ref_signal_until and not _adv:
		referee.stop_action()
	for i in 2:
		var ln: Player = linesmen[i]
		var z := (Pitch.HALF_W + 1.5) * (-1.0 if i == 0 else 1.0)
		_go(ln, Vector3(clampf(b.x, -Pitch.HALF_L, Pitch.HALF_L), 0, z), 5.5)
		if ln.action == "" or not ln.action.begins_with("sig_"):
			ln.face_to = Vector3(b.x, 0, 0)
	for i in 4:
		var u: Player = umpires[i]
		u.want_vel = Vector3.ZERO
		if u.action.begins_with("sig_") and u.action_t > u.action_len:
			u.stop_action()
		if u.action == "":
			# The ball in front of them, they watch it; once it is over their line (a score, a wide, in the net behind
			# them) they keep looking out at the play, where it came from, not round at it or at each other.
			u.face_to = b if absf(b.x) < Pitch.HALF_L - 0.3 or signf(b.x) != signf(u.position.x) else _play_from(u)


## Where an umpire looks while the ball is behind him: where the last shot was struck from, else out up the pitch.
func _play_from(u: Player) -> Vector3:
	var shot: Dictionary = m.ball.get_meta("shot", {})
	if shot.has("from"):
		var f: Vector3 = shot.from
		return Vector3(f.x, 0, f.z)
	return Vector3(signf(u.position.x) * (Pitch.HALF_L - 30.0), 0, u.position.z * 0.5)


func _go(p: Player, target: Vector3, speed: float) -> void:
	var d := target - p.global_position
	d.y = 0
	var l := d.length()
	if l < 1.0:
		p.want_vel = Vector3.ZERO
		return
	p.want_vel = d / l * minf(speed, l * 0.9)


## The umpires at end s (the end line at x = s * HALF_L): the one nearer where it crossed signals, the other too
## for a score.
func umpire_signal(s: float, kind: String, z: float) -> void:
	var base := 0 if s < 0.0 else 2
	var near: Player = umpires[base + (0 if z < 0.0 else 1)]
	near.play(kind)
	near.face_to = _play_from(near)
	if kind in ["sig_point", "sig_goal", "sig_wide"]:
		var other: Player = umpires[base + (1 if z < 0.0 else 0)]
		other.play(kind)
		other.face_to = _play_from(other)


func linesman_signal(c: Vector3, toward: float) -> void:
	var ln: Player = linesmen[0 if c.z < 0.0 else 1]
	# Side-on, so the flag held out in the right hand points the way the cut goes.
	ln.face_to = ln.global_position + Vector3(0, 0, -10.0 * toward)
	ln.play("sig_sideline")


## The free: the whistle, then the arm out toward the goal the free attacks (he turns side-on so it points there).
func signal_free(award: Dictionary, toward: float) -> void:
	_adv = false
	referee.face_to = referee.global_position + Vector3(0, 0, 10.0 * -toward)
	if String(award.get("kind", "")) == "penalty":
		referee.play("sig_penalty")
	else:
		referee.play("sig_free")
	_ref_signal_until = m.now + 1.8


func signal_advantage() -> void:
	_adv = true
	referee.play("sig_advantage")
	_ref_signal_until = m.now + Rules.ADVANTAGE_S


func end_advantage() -> void:
	if _adv:
		_adv = false
		referee.stop_action()


func show_card(pl: Player, card: String) -> void:
	referee.card_colour = card
	referee.face_to = pl.global_position
	referee.play("sig_card")
	_ref_signal_until = m.now + 2.2
	if card == "black":
		m._after(2.3, func():
			referee.play("sig_sinbin")
			_ref_signal_until = m.now + 2.4)
