class_name CameraRig
extends Node3D
## Three cameras: third person (behind your player), first person (from your player's eyes),
## and broadcast (the side-on TV view). Drag on the screen to look around.

var mode := Game.CAM_THIRD
var cam: Camera3D
var orbit := 0.0        # third person: drag offset around the player
var look_yaw := 0.0     # first person: absolute yaw, 0 faces -z (toward the opposition half)
var look_pitch := -0.08
var _t := 0.0
var _hidden_head: Athlete = null
var _last_focus: Athlete = null
var frozen := false      # hold the camera still (used when recording test footage)


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.05
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	cam.position = Vector3(0, 9, 16)
	cam.look_at(Vector3.ZERO)


func flat_forward() -> Vector3:
	var f := -cam.global_basis.z
	f.y = 0
	return f.normalized() if f.length() > 0.01 else Vector3(0, 0, -1)


## Joystick vector (x right, y down) to a ground direction relative to the camera.
func input_to_world(v: Vector2) -> Vector3:
	if v.length() < 0.05:
		return Vector3.ZERO
	var fwd := flat_forward()
	var right := Vector3(-fwd.z, 0, fwd.x)
	return (right * v.x + fwd * -v.y).limit_length(1.0)


func follow(m, dt: float) -> void:
	if frozen:
		return
	_t += dt
	var look: Vector2 = m.controls.take_look()
	var a: Athlete = m.focus_athlete()
	if a != _last_focus:
		_last_focus = a
		look_yaw = 0.0
		look_pitch = -0.08
	var fp: bool = mode == Game.CAM_FIRST and m.phase in ["raid", "setup", "post"] and a != null and a.on_mat
	_set_head_hidden(a if fp else null)

	if m.phase in ["intro", "fulltime", "halftime"] or a == null:
		# Slow orbit of the ground.
		var r := 15.0
		var ang := _t * 0.12 + 0.6
		var pos := Vector3(sin(ang) * r, 6.5, cos(ang) * r)
		_move(pos, Vector3(0, 0.5, 0), dt, 2.0)
		return

	if fp:
		look_yaw -= look.x * 0.006
		look_pitch = clampf(look_pitch - look.y * 0.004, -0.7, 0.45)
		var hm := a.model
		var eye_h := hm.height * 0.93 - hm.crouch * 0.28 - hm.struggle * 0.3 - hm.dive * 0.9 - hm.fallen * 1.2
		var fwd := Vector3(-sin(look_yaw), 0, -cos(look_yaw))
		var eye := a.position + Vector3(0, maxf(0.35, eye_h), 0) + fwd * 0.14
		var dir := (fwd * cos(look_pitch) + Vector3.UP * sin(look_pitch)).normalized()
		cam.global_position = eye
		cam.look_at(eye + dir, Vector3.UP)
		cam.fov = 72.0
		return

	cam.fov = lerpf(cam.fov, 60.0, dt * 4.0)
	if mode == Game.CAM_TV:
		var z := clampf(a.position.z * 0.55, -4.5, 4.5)
		_move(Vector3(11.5, 6.2, z), Vector3(0, 0.4, a.position.z * 0.75), dt, 3.0)
		return

	# Third person: behind the player, looking up the court toward -z.
	orbit = clampf(orbit - look.x * 0.005, -1.4, 1.4)
	if look.length() < 0.01:
		orbit = move_toward(orbit, 0.0, dt * 0.15)
	var b := Basis(Vector3.UP, orbit)
	var pos := a.position + b * Vector3(0, 2.9, 5.2)
	var tgt := a.position + b * Vector3(0, 0.8, -3.2)
	_move(pos, tgt, dt, 6.0)


func _move(pos: Vector3, target: Vector3, dt: float, rate: float) -> void:
	var k := clampf(dt * rate, 0.0, 1.0)
	cam.global_position = cam.global_position.lerp(pos, k)
	var cur := cam.global_position + (-cam.global_basis.z) * 5.0
	var want := cur.lerp(target, k * 1.4)
	if (want - cam.global_position).length() > 0.01:
		cam.look_at(want, Vector3.UP)


func _set_head_hidden(a: Athlete) -> void:
	if _hidden_head == a:
		return
	if _hidden_head and is_instance_valid(_hidden_head):
		_hidden_head.model.set_head_visible(true)
	_hidden_head = a
	if a:
		a.model.set_head_visible(false)
