class_name MoveDemo
extends Node3D
## A small stage that acts out a move on a loop, for the Training menu: a raider in teal,
## defenders in red, a patch of mat with the midline, baulk and bonus lines.
##
## Coordinates: the midline is z = 0; the defenders' half is z < 0, so a raider goes in
## toward -z and comes home toward +z.

const RAIDER_TEAM := "MUM"
const DEF_TEAM := "DEL"

var lesson := ""
var _t := 0.0
var _len := 4.0
var _raider: Athlete
var _defs: Array = []
var _link: MeshInstance3D
var _cam: Camera3D
var _prev := {}


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("0c1a29")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("9fb3cc")
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = int(Game.settings.graphics) >= Game.GFX_MEDIUM
	add_child(sun)
	_floor()
	var t := DB.team(RAIDER_TEAM)
	_raider = Athlete.new()
	_raider.setup(t.squad[0], 0, t.c1, t.c2, true)
	add_child(_raider)
	var d := DB.team(DEF_TEAM)
	for i in 2:
		var a := Athlete.new()
		a.setup(d.squad[4 + i], 1, d.c1, d.c2, true)
		add_child(a)
		_defs.append(a)
	_link = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 1.0
	_link.mesh = cyl
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Game.C_GOLD
	lm.emission_enabled = true
	lm.emission = Game.C_GOLD
	lm.emission_energy_multiplier = 0.6
	_link.material_override = lm
	add_child(_link)
	_cam = Camera3D.new()
	_cam.fov = 40
	add_child(_cam)
	show_lesson(lesson if lesson != "" else "touch")


func _floor() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("1d4f8c")
	mat.roughness = 0.8
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(11, 9)
	plane.mesh = pm
	plane.material_override = mat
	plane.position = Vector3(0, 0, -2.2)
	add_child(plane)
	var line := StandardMaterial3D.new()
	line.albedo_color = Color(1, 1, 1, 0.9)
	line.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var gold := line.duplicate()
	gold.albedo_color = Game.C_GOLD
	for z in [0.0, -3.75, -4.75]:
		_strip(Vector3(0, 0.01, z), Vector2(10, 0.06 if z != 0.0 else 0.1), gold if z == 0.0 else line)
	_strip(Vector3(4.6, 0.01, -2.2), Vector2(0.06, 9), line)


func _strip(pos: Vector3, size: Vector2, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	m.mesh = pm
	m.material_override = mat
	m.position = pos
	add_child(m)


## Set up a lesson's scene and start its loop from the top.
func show_lesson(id: String) -> void:
	lesson = id
	_t = 0.0
	_prev.clear()
	_link.visible = false
	for a in [_raider] + _defs:
		a.visible = true
		a.lock_facing = true
		a.set_state("idle")
		a.st_t = 0.0
		a.tackle_kind = ""
	_len = {"cant": 4.4, "bonus": 4.6, "dubki": 3.6, "escape": 3.8, "dash": 3.4}.get(id, 4.0)
	_defs[1].visible = id in ["dubki", "chain"]
	var cam_pos := Vector3(3.6, 1.8, 1.2)
	var look := Vector3(0, 0.75, -1.7)
	if id == "bonus":
		cam_pos = Vector3(4.6, 2.0, -0.6)
		look = Vector3(0.6, 0.6, -3.4)
	elif id == "dash":
		cam_pos = Vector3(1.0, 2.0, 1.4)
		look = Vector3(3.8, 0.6, -2.0)
	elif id == "cant":
		cam_pos = Vector3(3.8, 1.9, 1.6)
		look = Vector3(0, 0.75, -1.2)
	_cam.position = cam_pos
	_cam.look_at(look)
	_tick(0.0)


func _process(delta: float) -> void:
	_t += delta
	if _t > _len:
		_t = 0.0
		show_lesson(lesson)
		return
	_tick(delta)


# ---------------------------------------------------------------- helpers

## Put an actor at a point on a straight path between t0 and t1 (clamped either side).
func _path(a: Athlete, from: Vector3, to: Vector3, t0: float, t1: float, face_move := true) -> void:
	var k := clampf((_t - t0) / maxf(t1 - t0, 0.01), 0.0, 1.0)
	_place(a, from.lerp(to, k), face_move and _t > t0 and _t < t1, to - from)


func _place(a: Athlete, pos: Vector3, moving := false, dir := Vector3.ZERO) -> void:
	var dt := get_process_delta_time()
	var prev: Vector3 = _prev.get(a, pos)
	a.vel = (pos - prev) / maxf(dt, 0.001) if moving else Vector3.ZERO
	a.position = pos
	_prev[a] = pos
	if moving and dir.length() > 0.01:
		a.facing = Vector3(dir.x, 0, dir.z).normalized()


func _face(a: Athlete, at: Vector3) -> void:
	var d := at - a.position
	d.y = 0
	if d.length() > 0.01:
		a.facing = d.normalized()


## Change state once (so the move's timing starts from when it is entered).
func _state(a: Athlete, s: String, length := 0.0) -> void:
	if a.state != s:
		a.set_state(s, length)


func _between(t0: float, t1: float) -> bool:
	return _t >= t0 and _t < t1


func _show_link(a: Athlete, b: Athlete) -> void:
	_link.visible = true
	var p := a.position + Vector3(0, 0.95, 0)
	var q := b.position + Vector3(0, 0.95, 0)
	var d := q - p
	if d.length() < 0.01:
		return
	var y := d.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	_link.transform = Transform3D(Basis(x, y * d.length(), z), (p + q) * 0.5)


# ---------------------------------------------------------------- the lessons

func _tick(_delta: float) -> void:
	var r := _raider
	var d: Athlete = _defs[0]
	var d2: Athlete = _defs[1]
	match lesson:
		"cant":
			# In on one breath, a look around, and home.
			d.visible = false
			_path(r, Vector3(0, 0, 1.0), Vector3(0, 0, -3.0), 0.2, 2.4)
			if _between(2.4, 2.8):
				_place(r, Vector3(0, 0, -3.0))
				_face(r, Vector3(1, 0, -4))
			_path(r, Vector3(0, 0, -3.0), Vector3(0, 0, 1.0), 2.8, 4.2)
			_state(r, "raid")
		"touch", "toe":
			var toe := lesson == "toe"
			var stop_z := -1.7 if not toe else -1.2
			_place(d, Vector3(0, 0, -3.0))
			_face(d, r.position)
			_state(d, "ready")
			_path(r, Vector3(0.3, 0, 0.8), Vector3(0.1, 0, stop_z), 0.2, 1.5)
			if _between(1.5, 2.1):
				_place(r, Vector3(0.1, 0, stop_z))
				_face(r, d.position)
				_state(r, "kick" if toe else "touch", 0.5 if toe else 0.34)
			elif _t >= 2.1:
				_state(r, "raid")
				_path(r, Vector3(0.1, 0, stop_z), Vector3(0.4, 0, 0.9), 2.1, 3.2)
				if _t > 2.3:
					_state(d, "slump")
			else:
				_state(r, "raid")
		"bonus":
			_place(d, Vector3(-2.2, 0, -3.2))
			_face(d, r.position)
			_state(d, "ready")
			_path(r, Vector3(1.4, 0, 0.6), Vector3(1.4, 0, -4.15), 0.2, 2.4)
			if _between(2.4, 3.0):
				_place(r, Vector3(1.4, 0, -4.15))
				r.facing = Vector3(0, 0, -1)
				_state(r, "kick", 0.55)
			elif _t >= 3.0:
				_state(r, "raid")
				_path(r, Vector3(1.4, 0, -4.15), Vector3(1.4, 0, 0.6), 3.0, 4.4)
			else:
				_state(r, "raid")
		"kick":
			# A defender closes in behind; a back kick tags him.
			_place(d, Vector3(0.9, 0, -0.6))
			_path(d, Vector3(0.9, 0, -0.6), Vector3(0.5, 0, -1.6), 1.0, 1.8)
			_face(d, r.position)
			_state(d, "ready")
			_path(r, Vector3(0, 0, 0.8), Vector3(0, 0, -2.6), 0.2, 1.5)
			if _between(1.8, 2.4):
				_place(r, Vector3(0, 0, -2.6))
				r.facing = Vector3(0, 0, -1)
				r.kick_back = 1.0
				r.kick_side = 0.35
				r.kick_dir = (d.position - r.position).normalized()
				_state(r, "backkick", 0.46)
			elif _t >= 2.4:
				_state(r, "raid")
				_path(r, Vector3(0, 0, -2.6), Vector3(-0.8, 0, 0.8), 2.4, 3.7)
				if _t > 2.5:
					_state(d, "slump")
			else:
				_state(r, "raid")
		"dubki":
			# Linked hands across the way home; duck under them.
			for i in 2:
				var a: Athlete = _defs[i]
				_place(a, Vector3(-0.55 + 1.1 * i, 0, -1.6))
				a.facing = Vector3(0, 0, -1)
				_state(a, "ready")
			_show_link(d, d2)
			r.position.y = 0
			_path(r, Vector3(0, 0, -3.6), Vector3(0, 0, -2.25), 0.2, 1.2)
			if _between(1.2, 1.7):
				_path(r, Vector3(0, 0, -2.25), Vector3(0, 0, -0.9), 1.2, 1.7)
				_state(r, "dubki", 0.45)
			elif _t >= 1.7:
				_path(r, Vector3(0, 0, -0.9), Vector3(0, 0, 0.9), 1.7, 2.8)
				_state(r, "raid")
			else:
				_state(r, "raid")
		"lion":
			# A dive at the ankles; leap it.
			_place(d, Vector3(0, 0, -0.9))
			_face(d, r.position)
			d.tackle_kind = "ankle"
			_path(r, Vector3(0, 0, -3.6), Vector3(0, 0, -2.2), 0.2, 1.0)
			if _t < 0.8:
				_state(d, "ready")
			elif _t < 1.1:
				_state(d, "telegraph", 0.3)
			elif _t < 1.7:
				_state(d, "dive", 0.6)
				_path(d, Vector3(0, 0, -0.9), Vector3(0, 0, -2.0), 1.1, 1.6, false)
			else:
				_state(d, "recover", 1.2)
			if _between(1.15, 1.8):
				_path(r, Vector3(0, 0, -2.2), Vector3(0, 0, -0.6), 1.15, 1.8)
				_state(r, "jump", 0.62)
			elif _t >= 1.8:
				_path(r, Vector3(0, 0, -0.6), Vector3(0, 0, 0.9), 1.8, 2.7)
				_state(r, "raid")
			else:
				_state(r, "raid")
		"escape":
			# Held, push for the line, slip out with a dubki.
			var hold_at := Vector3(0, 0, -1.6)
			if _t < 1.6:
				_place(r, hold_at.lerp(Vector3(0, 0, -1.2), _t / 1.6), true, Vector3(0, 0, 1))
				r.facing = Vector3(0, 0, 1)
				_state(r, "held")
				_place(d, r.position + Vector3(0.1, 0, -0.55))
				_face(d, r.position)
				d.tackle_kind = "thigh"
				_state(d, "holding")
			elif _t < 2.1:
				_path(r, Vector3(0, 0, -1.2), Vector3(0, 0, -0.2), 1.6, 2.1)
				_state(r, "dubki", 0.45)
				_state(d, "recover", 1.2)
			else:
				_path(r, Vector3(0, 0, -0.2), Vector3(0, 0, 1.0), 2.1, 3.0)
				_state(r, "raid")
		"tackle", "waist":
			# The raider comes in; the defender winds up and goes in.
			var kind := "ankle" if lesson == "tackle" else "waist"
			d.tackle_kind = kind
			_place(d, Vector3(0, 0, -3.2))
			_face(d, r.position)
			_path(r, Vector3(0.3, 0, 0.6), Vector3(0.2, 0, -2.2), 0.2, 1.4)
			_state(r, "raid")
			if _t < 1.2:
				_state(d, "ready")
			elif _t < 1.5:
				_state(d, "telegraph", 0.3)
			elif _t < 2.0:
				_state(d, "dive", 0.5)
				_path(d, Vector3(0, 0, -3.2), Vector3(0.15, 0, -2.6), 1.5, 1.9, false)
			else:
				_state(d, "holding")
				_state(r, "held" if kind == "waist" else "fallen", 2.0)
		"chain":
			for i in 2:
				var a: Athlete = _defs[i]
				a.tackle_kind = "thigh"
				_face(a, r.position)
			_path(r, Vector3(0, 0, 0.6), Vector3(0, 0, -2.0), 0.2, 1.4)
			_state(r, "raid")
			if _t < 1.3:
				_place(d, Vector3(-0.55, 0, -3.0))
				_place(d2, Vector3(0.55, 0, -3.0))
				_state(d, "ready")
				_state(d2, "ready")
				_show_link(d, d2)
			elif _t < 1.9:
				_link.visible = false
				_path(d, Vector3(-0.55, 0, -3.0), Vector3(-0.35, 0, -2.45), 1.3, 1.8, false)
				_path(d2, Vector3(0.55, 0, -3.0), Vector3(0.35, 0, -2.45), 1.3, 1.8, false)
				_state(d, "dive", 0.5)
				_state(d2, "dive", 0.5)
			else:
				_state(d, "holding")
				_state(d2, "holding")
				_state(r, "held")
		"dash":
			# Near the side line, a dash shoves him out.
			d.tackle_kind = "dash"
			_path(r, Vector3(2.4, 0, 0.6), Vector3(3.6, 0, -2.0), 0.2, 1.4)
			_place(d, Vector3(2.4, 0, -2.8))
			_face(d, r.position)
			if _t < 1.2:
				_state(d, "ready")
				_state(r, "raid")
			elif _t < 1.5:
				_state(d, "telegraph", 0.3)
				_state(r, "raid")
			elif _t < 2.0:
				_state(d, "dive", 0.5)
				_path(d, Vector3(2.4, 0, -2.8), Vector3(3.2, 0, -2.2), 1.5, 1.8, false)
				_path(r, Vector3(3.6, 0, -2.0), Vector3(5.4, 0, -1.6), 1.6, 2.0, false)
				_state(r, "shoved", 0.4)
			else:
				_state(d, "recover", 1.0)
				_place(r, Vector3(5.4, 0, -1.6))
				_state(r, "slump")
