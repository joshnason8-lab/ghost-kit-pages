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


func build(court: Court) -> void:
	for s in [-1.0, 1.0]:
		var j := Body.new({"kind": "judge", "skin": Color("9a6c4a") if s < 0 else Color("85593b"), "hair": Color("15110e"), "height": 1.7 if s < 0 else 1.66, "build": 0.6})
		var at := Vector3(0.0, 0.0, s * 3.4)
		if court.classic():
			at = Vector3(0.6 * s, Court.WALL_H, s * (Court.TALUD_Z + 0.9))
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
	if _call_t >= 0.0:
		_call_t += delta
		if _call_t > 2.4:
			_call_t = -1.0
