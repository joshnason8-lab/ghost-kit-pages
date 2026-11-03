class_name Officials
extends Node3D
## The judges (veedores): one or two stand at the analco and watch that the rules are kept (Cuarto Poder; the
## Secretaría de Cultura's inventory; the UNAM thesis says one for each side). Here two, one each side of the analco,
## just off the taste; on the stone court, up on the structures at the centre line. Each raya they call aloud and
## point to the side that wins it; a fault, they cross their arms over their heads first. No source describes the
## signals, so the gestures are the game's (docs/CULTURE.md).

var judges: Array[Body] = []
var _yaws: Array[float] = []
var _call_t := -1.0
var _call_side := [1.0, 1.0]
var _fault := false
var _t := 0.0
## Where the ball is (Match sets it each frame): the judges drawn by the shared foundation watch it.
var watch := Vector3.INF


func build(court: Court) -> void:
	for s in [-1.0, 1.0]:
		var look := {"kind": "judge", "skin": Color("9a6c4a") if s < 0 else Color("85593b"), "hair": Color("15110e"), "height": 1.7 if s < 0 else 1.66, "build": 0.6, "hat": 0 if s < 0 else 1}
		if FoundationLink.enabled():
			look["foundation"] = true
		var j := Body.new(look)
		var at := Vector3(0.0, 0.0, s * 3.4)
		if court.classic():
			# On the coping along the wall's top (Venue._stone_court: 0.5 m over the wall), not sunk in it.
			at = Vector3(0.6 * s, Court.WALL_H + 0.5, s * (Court.TALUD_Z + 0.9))
		if court.solid != null:
			at = court.solid.push_out(at, Player.WALK_R)   # never standing in a prop (a torch post on the coping)
		add_child(j)
		j.position = at
		var yaw := atan2(-at.x * 0.0, -at.z)   # facing across the court
		j.rotation = Vector3(0, yaw, 0)
		judges.append(j)
		_yaws.append(yaw)
		j.apply(Moves.judge_idle(0.0))


func set_lod(l: int) -> void:
	for j in judges:
		j.set_lod(l)


## Call a raya for team (fault: crossed arms first).
func signal_raya(team: int, fault: bool) -> void:
	_call_t = 0.0
	_fault = fault
	var wx := -Rules.dir(team)   # that team's half
	for i in judges.size():
		var y := _yaws[i]
		var left := Vector3(cos(y), 0, -sin(y))
		_call_side[i] = 1.0 if left.x * wx > 0.0 else -1.0


func _process(delta: float) -> void:
	_t += delta
	for i in judges.size():
		var p: Dictionary
		if _call_t >= 0.0 and _call_t < 2.4:
			p = Moves.judge_call(_call_t / 2.4, _call_side[i], _fault)
		else:
			p = Moves.judge_idle(_t + i * 2.0)
		judges[i].apply(p)
		var l := judges[i].link
		if l:
			# The shared foundation (Medium and High): standing at ease from the motion capture, watching the ball;
			# a call is the game's arms over it.
			l.want = "upper" if _call_t >= 0.0 and _call_t < 2.4 else "move"
			l.vel = Vector3.ZERO
			l.yaw = _yaws[i]
			l.look = watch
			l.update(delta)
	if _call_t >= 0.0:
		_call_t += delta
		if _call_t > 2.4:
			_call_t = -1.0
