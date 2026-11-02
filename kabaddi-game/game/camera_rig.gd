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
var _tight := 0.0        # broadcast: 0 the play as a whole, 1 in close on a struggle
var _jolt := 0.0         # metres of shake left (a takedown, a hold: shake)
var _jolt_t := 0.0
var _shake_now := Vector3.ZERO   # this frame's shake, put on after the smoothing (which would all but take it out)

const VIGNETTE := """
shader_type canvas_item;
uniform float strength = 0.3;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.42, 1.05, length(d) * 1.25) * strength);
}
"""


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.near = 0.05
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	cam.position = Vector3(0, 9, 16)
	cam.look_at(Vector3.ZERO)
	# The edges a shade darker, as a lens has them: under the HUD (layer 5).
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = Shader.new()
	sm.shader.code = VIGNETTE
	vig.material = sm
	cl.add_child(vig)


## A jolt to the camera, in metres: dies away in about a third of a second.
func shake(strength: float) -> void:
	_jolt = maxf(_jolt, strength)


## What the match does that the camera feels (Match._event).
func on_event(kind: String) -> void:
	match kind:
		"takedown":
			shake(0.07)
		"dash":
			shake(0.05)
		"hold":
			shake(0.025)


func flat_forward() -> Vector3:
	var f := -cam.global_basis.z
	f.y = 0
	return f.normalized() if f.length() > 0.01 else Vector3(0, 0, -1)


## The stick's axes: the ground ways that are up and right on the screen where the player it moves stands. Perspective
## bends them away from the camera's own yaw toward the screen's edges (up to 24 degrees here), so they are found by
## casting the camera's rays to the ground just above, below, left and right of him. Followed exactly as the camera
## turns, but eased over about 0.2 s when they jump (a camera cut), so the player does not turn on the spot.
var input_at := Vector3.INF          # where the player the stick moves stands (set each frame by follow)
var _in_up := Vector3.ZERO
var _in_right := Vector3.ZERO
const INPUT_EASE := 0.07             # s, the time constant of that ease (about 95% in 0.2 s)
const AXIS_PX := 24.0                # how far either side of him the rays go, in pixels


## Where the camera's ray through screen point s meets the ground (y 0), or INF.
func _ground_at(s: Vector2) -> Vector3:
	var o := cam.project_ray_origin(s)
	var n := cam.project_ray_normal(s)
	if n.y > -0.001:
		return Vector3.INF
	return o + n * (-o.y / n.y)


## [up, right]: the ground directions that are up and right on the screen at ground point at.
func stick_axes(at: Vector3) -> Array:
	var f := flat_forward()
	var flat := [f, Vector3(-f.z, 0, f.x)]
	if at == Vector3.INF or cam == null or not cam.is_inside_tree():
		return flat
	var g := Vector3(at.x, 0.0, at.z)
	if cam.is_position_behind(g):
		return flat
	var s := cam.unproject_position(g)
	var hi := _ground_at(s + Vector2(0, -AXIS_PX))
	var lo := _ground_at(s + Vector2(0, AXIS_PX))
	var rt := _ground_at(s + Vector2(AXIS_PX, 0))
	var lf := _ground_at(s + Vector2(-AXIS_PX, 0))
	if Vector3.INF in [hi, lo, rt, lf]:
		return flat
	var up := Vector3(hi.x - lo.x, 0, hi.z - lo.z)
	var right := Vector3(rt.x - lf.x, 0, rt.z - lf.z)
	if up.length() < 0.0001 or right.length() < 0.0001:
		return flat
	return [up.normalized(), right.normalized()]


func _ease_input(dt: float) -> void:
	var ax := stick_axes(input_at)
	var up: Vector3 = ax[0]
	var right: Vector3 = ax[1]
	if _in_up == Vector3.ZERO or (_in_up.angle_to(up) < 0.35 and _in_right.angle_to(right) < 0.35):
		_in_up = up
		_in_right = right
	else:
		var k := 1.0 - exp(-dt / INPUT_EASE)
		_in_up = _in_up.slerp(up, k).normalized()
		_in_right = _in_right.slerp(right, k).normalized()


## Joystick vector (x right, y down) to a ground direction: up the stick is up the screen where the player stands, in
## every camera. at: the axes there, now (no ease); else the eased axes at input_at.
func input_to_world(v: Vector2, at := Vector3.INF) -> Vector3:
	if v.length() < 0.05:
		return Vector3.ZERO
	var ax := stick_axes(at) if at != Vector3.INF or _in_up == Vector3.ZERO else [_in_up, _in_right]
	var w: Vector3 = ax[1] * v.x - ax[0] * v.y
	return w.normalized() * minf(v.length(), 1.0) if w.length() > 0.0001 else Vector3.ZERO


## The stick vector that moves the player along ground direction w (input_to_world's inverse; the demo tour's thumb).
func world_to_input(w: Vector3) -> Vector2:
	var ax := [_in_up, _in_right] if _in_up != Vector3.ZERO else stick_axes(input_at)
	var u: Vector3 = ax[0]
	var r: Vector3 = ax[1]
	var det := r.x * u.z - u.x * r.z
	if absf(det) < 0.0001:
		return Vector2.ZERO
	var a := (w.x * u.z - u.x * w.z) / det
	var b := (r.x * w.z - w.x * r.z) / det
	return Vector2(a, -b)


func follow(m, dt: float) -> void:
	if frozen:
		return
	var who = m.get("controlled")
	input_at = (who as Node3D).global_position if who is Node3D and is_instance_valid(who) else Vector3.INF
	_ease_input(dt)
	cam.global_position -= _shake_now   # last frame's shake off before the smoothing
	_shake_now = Vector3.ZERO
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

	if mode == Game.CAM_TV:
		# Side-on, panning with the play. In close while the raider is held (a little nearer, a little lower, narrower),
		# back out as he gets away or the raid ends; and never quite still, as a camera operator's hands are not.
		var held: bool = m.phase == "raid" and m.raider != null and not (m.raid.holders as Array).is_empty()
		_tight = move_toward(_tight, 1.0 if held else 0.0, dt * (1.1 if held else 0.6))
		var close_in := smoothstep(0.0, 1.0, _tight)
		cam.fov = lerpf(cam.fov, 60.0 - 9.0 * close_in, dt * 3.0)
		var z := clampf(a.position.z * 0.55, -4.5, 4.5)
		var drift := Vector3(0, sin(_t * 0.53) * 0.035 + sin(_t * 1.31) * 0.012, sin(_t * 0.41 + 1.0) * 0.05)
		_move(Vector3(11.5 - 1.2 * close_in, 6.2 - 0.9 * close_in, z) + drift,
			Vector3(0, 0.4 + 0.25 * close_in, a.position.z * 0.75) + drift * 0.5, dt, 3.0)
		_shake(dt)
		return
	cam.fov = lerpf(cam.fov, 60.0, dt * 4.0)

	# Third person: behind the player, looking up the court toward -z.
	orbit = clampf(orbit - look.x * 0.005, -1.4, 1.4)
	if look.length() < 0.01:
		orbit = move_toward(orbit, 0.0, dt * 0.15)
	var b := Basis(Vector3.UP, orbit)
	var pos := a.position + b * Vector3(0, 2.9, 5.2)
	var tgt := a.position + b * Vector3(0, 0.8, -3.2)
	_move(pos, tgt, dt, 6.0)
	_shake(dt)


## This frame's shake, on top of where the camera has moved to: a quick, tight wobble that dies away.
func _shake(dt: float) -> void:
	if _jolt <= 0.001:
		return
	_jolt_t += dt
	_jolt = move_toward(_jolt, 0.0, dt * 0.22)
	_shake_now = Vector3(sin(_jolt_t * 61.0), sin(_jolt_t * 47.0 + 1.3), sin(_jolt_t * 53.0 + 2.1) * 0.5) * _jolt
	cam.global_position += _shake_now


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
