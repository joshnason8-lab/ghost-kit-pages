class_name Officials
extends Node3D
## The match officials, placed as in a kabaddi match: the referee at the midline on the
## far side by the scorers' table, an umpire on each side line (each watching the half
## across from the other), and a line judge at each end line. They follow the raid with
## their eyes, the umpires shuffle along their lines, and they signal points.

const SHIRT := Color("eef1f4")
const SHORTS := Color("15181c")

var m                       # the Match
var referee: Athlete
var umpires: Array = []     # [far side, team 0 half], [near side, team 1 half]
var judges: Array = []
var scorers: Array = []
var _homes := {}            # athlete -> resting spot
var _signal_t := 0.0


func setup(p_match) -> void:
	m = p_match
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(m.config.get("home", "")) + String(m.config.get("away", "")))
	var edge := Arena.HALF_W + Arena.LOBBY
	referee = _official(rng, 0, Vector3(-edge - 0.9, 0, 0.0))
	umpires.append(_official(rng, 1, Vector3(-edge - 0.7, 0, Arena.HALF_L * 0.55)))
	umpires.append(_official(rng, 2, Vector3(edge + 0.7, 0, -Arena.HALF_L * 0.55)))
	judges.append(_official(rng, 3, Vector3(-edge + 0.4, 0, Arena.HALF_L + 0.7)))
	judges.append(_official(rng, 4, Vector3(-edge + 0.4, 0, -Arena.HALF_L - 0.7)))
	_table(Vector3(-edge - 1.65, 0, 0))
	for i in 2:
		var s := _official(rng, 5 + i, Vector3(-edge - 2.15, 0, -0.45 + i * 0.9))
		s.set_state("sit")
		s.facing = Vector3(1, 0, 0)
		scorers.append(s)


func _official(rng: RandomNumberGenerator, i: int, pos: Vector3) -> Athlete:
	var data := {
		"id": "OFFICIAL_%d" % i, "name": "", "role": "official",
		"attrs": {"speed": 55, "agility": 55, "strength": 55, "reach": 55, "tackle": 40, "stamina": 70},
		"number": 0, "team": "", "skin": rng.randi_range(0, 5), "hair": rng.randi_range(0, 3),
		"build": rng.randf_range(0.95, 1.1), "height": rng.randf_range(1.68, 1.82),
	}
	var a := Athlete.new()
	a.setup(data, 2, SHIRT, SHORTS, false)
	add_child(a)
	a.position = pos
	a.facing = Vector3(-signf(pos.x), 0, 0) if absf(pos.x) > Arena.HALF_W else Vector3(0, 0, -signf(pos.z))
	a.set_state("idle")
	_homes[a] = pos
	return a


func _table(pos: Vector3) -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("1d3557")
	cloth.roughness = 0.9
	var top := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.74, 2.2)
	top.mesh = box
	top.material_override = cloth
	top.position = pos + Vector3(0, 0.37, 0)
	add_child(top)
	var sign_l := Label3D.new()
	sign_l.text = tr("SCORERS")
	sign_l.font_size = 64
	sign_l.pixel_size = 0.004
	sign_l.modulate = Color("f3efe6")
	sign_l.position = pos + Vector3(0.36, 0.5, 0)
	sign_l.rotation = Vector3(0, PI / 2, 0)
	add_child(sign_l)


func _process(delta: float) -> void:
	if m == null or m.raider == null:
		return
	_signal_t = maxf(0.0, _signal_t - delta)
	var rp: Vector3 = m.raider.position
	var live: bool = m.phase == "raid"
	# The umpire on the side of the raid follows along his line; the other holds.
	for i in umpires.size():
		var u: Athlete = umpires[i]
		var home: Vector3 = _homes[u]
		var target := home
		if live and signf(rp.z) == signf(home.z):
			target.z = clampf(rp.z, minf(0.4 * signf(home.z), home.z * 1.5), maxf(0.4 * signf(home.z), home.z * 1.5))
		_step(u, target, rp, delta)
	var rhome: Vector3 = _homes[referee]
	_step(referee, rhome + Vector3(0, 0, clampf(rp.z * 0.25, -1.2, 1.2) if live else 0.0), rp, delta)
	for j in judges:
		_step(j, _homes[j], rp, delta)
	for s in scorers:
		s.drive(Vector3.ZERO, delta)


func _step(a: Athlete, target: Vector3, look: Vector3, dt: float) -> void:
	if a.state in ["argue", "celebrate"] and a.st_t < a.st_len:
		a.drive(Vector3.ZERO, dt)
		return
	a.seek(target, 2.0, dt, 0.4)
	a.lock_facing = true
	a.face_toward(look, dt, 5.0)
	var want := "walk" if a.vel.length() > 0.3 else "idle"
	if a.state != want:
		a.set_state(want)


## Points awarded: the referee and the umpire on that side point to the scoring team.
func signal_points(team_scored: int, all_out := false) -> void:
	if m == null:
		return
	var toward: Vector3 = m.pos_in(team_scored, 0.0, Arena.HALF_L * 0.5)
	for a in [referee, umpires[0] if team_scored == 0 else umpires[1]]:
		a.face_toward(toward, 1.0, 1000.0)
		a.set_state("celebrate" if all_out else "argue", 1.4)
