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

	if mode == Game.CAM_TV:
		# Side-on, panning with the play. In close while the raider is held (a little nearer, a little lower, narrower),
		# back out as he gets away or the raid ends; and never quite still, as a camera operator's hands are not.
		var held: bool = m.phase == "raid" and m.raider != null and not (m.raid.holders as Array).is_empty()
		_tight = move_toward(_tight, 1.0 if held else 0.0, dt * (1.1 if held else 0.6))
		var close_in := smoothstep(0.0, 1.0, _tight)
		cam.fov = lerpf(cam.fov, 60.0 - 9.0 * close_in, dt * 3.0)
		var z := clampf(a.position.z * 0.55, -4.5, 4.5)
		var drift := Vector3(0, sin(_t * 0.53) * 0.035 + sin(_t * 1.31) * 0.012, sin(_t * 0.41 + 1.0) * 0.05)
		_move(Vector3(11.5 - 1.2 * close_in, 6.2 - 0.9 * close_in, z) + drift + _shake_offset(dt),
			Vector3(0, 0.4 + 0.25 * close_in, a.position.z * 0.75) + drift * 0.5, dt, 3.0)
		return
	cam.fov = lerpf(cam.fov, 60.0, dt * 4.0)

	# Third person: behind the player, looking up the court toward -z.
	orbit = clampf(orbit - look.x * 0.005, -1.4, 1.4)
	if look.length() < 0.01:
		orbit = move_toward(orbit, 0.0, dt * 0.15)
	var b := Basis(Vector3.UP, orbit)
	var pos := a.position + b * Vector3(0, 2.9, 5.2)
	var tgt := a.position + b * Vector3(0, 0.8, -3.2)
	_move(pos + _shake_offset(dt), tgt, dt, 6.0)


## This frame's shake: a quick, tight wobble that dies away.
func _shake_offset(dt: float) -> Vector3:
	if _jolt <= 0.001:
		return Vector3.ZERO
	_jolt_t += dt
	_jolt = move_toward(_jolt, 0.0, dt * 0.22)
	return Vector3(sin(_jolt_t * 61.0), sin(_jolt_t * 47.0 + 1.3), sin(_jolt_t * 53.0 + 2.1) * 0.5) * _jolt


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
