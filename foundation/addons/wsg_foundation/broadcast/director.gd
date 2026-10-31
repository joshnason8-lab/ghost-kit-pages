class_name WsgDirector
extends Node3D
## The television director for the moments between the play: a shot list run on its own camera, then the game's
## camera back. The shots:
##   close: tight on a body (a scorer celebrating), from the side of the play the game's camera is on (never across
##          the line: the 180-degree rule), the camera easing in as it holds;
##   crowd: the stand reacting, from the touchline looking up into it, pushing in slowly;
##   orbit: a flight round a point (the ground before the throw-in), from one bearing to another, coming down;
##   still: a fixed camera (a transform), e.g. Low's stand-in for the flight.
## Each holds at least MIN_HOLD (no flicker of cuts); a tap or skip() ends the list.
##   var d := WsgDirector.new(); add_child(d)
##   await d.run([{"shot": "close", "target": scorer, "secs": 1.8}, {"shot": "crowd", "at": stand, "secs": 1.6}],
##       live_camera)
## WsgDirector.packages(): what a tier can afford (WsgFoundation's profile): Low none, or a still.

signal finished

const MIN_HOLD := 1.2

var camera: Camera3D
var running := false
var _skip := false


func _ready() -> void:
	camera = Camera3D.new()
	camera.near = 0.2
	camera.far = 1200.0
	add_child(camera)


## Whether the tier runs packages (cut-aways and the flight): a budget phone's Low does not (its replay ring is
## short too); everything else does.
static func packages() -> bool:
	return not (WsgFoundation.tier == WsgFoundation.LOW)


## Run the shots, then give the picture back to live (the game's camera). Returns when done or skipped.
func run(shots: Array, live: Camera3D) -> void:
	running = true
	_skip = false
	camera.make_current()
	for s in shots:
		if _skip:
			break
		await _shot(s, live)
	running = false
	if is_instance_valid(live):
		live.make_current()
	finished.emit()


func skip() -> void:
	_skip = true


func _unhandled_input(event: InputEvent) -> void:
	if running and (event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed):
		skip()
		get_viewport().set_input_as_handled()


func _shot(s: Dictionary, live: Camera3D) -> void:
	var secs := maxf(float(s.get("secs", 2.0)), MIN_HOLD)
	var t := 0.0
	var kind := String(s.get("shot", "close"))
	var from_side := Vector3.BACK
	if is_instance_valid(live) and s.has("target") and is_instance_valid(s.target):
		var d: Vector3 = live.global_position - (s.target as Node3D).global_position
		from_side = Vector3(d.x, 0, d.z).normalized() if Vector3(d.x, 0, d.z).length() > 0.1 else Vector3.BACK
	var way := [0.0, 0.0]
	if kind == "close" and s.has("target") and is_instance_valid(s.target):
		way = _clear_bearing(s.target, from_side, float(s.get("far", 4.2)), float(s.get("height", 1.45)))
	while t < secs and not _skip:
		var k := t / secs
		match kind:
			"close":
				var tgt: Node3D = s.target
				if not is_instance_valid(tgt):
					break
				var face := tgt.global_basis.z.normalized()
				# Toward the camera's side of the line, and a little round to the face (a face, not a back).
				var dir := (from_side * 0.7 + Vector3(face.x, 0, face.z) * 0.5).normalized().rotated(Vector3.UP, way[0])
				var dist := lerpf(float(s.get("far", 4.2)), float(s.get("near", 3.2)), smoothstep(0.0, 1.0, k))
				var head := tgt.global_position + Vector3(0, float(s.get("height", 1.45)), 0)
				camera.fov = 30.0
				camera.look_at_from_position(head + dir * dist + Vector3(0, 0.15 + float(way[1]), 0), head - Vector3(0, 0.12, 0))
			"crowd":
				var at: Vector3 = s.at
				var from: Vector3 = s.get("from", at + Vector3(0, -6, 18))
				camera.fov = lerpf(38.0, 30.0, smoothstep(0.0, 1.0, k))
				camera.look_at_from_position(from, at)
			"orbit":
				var c: Vector3 = s.get("center", Vector3.ZERO)
				var a := lerpf(float(s.get("from_deg", -70.0)), float(s.get("to_deg", 20.0)), smoothstep(0.0, 1.0, k))
				var r := lerpf(float(s.get("radius", 140.0)), float(s.get("radius_end", 95.0)), k)
				var h := lerpf(float(s.get("height", 70.0)), float(s.get("height_end", 28.0)), smoothstep(0.0, 1.0, k))
				var p := c + Vector3(sin(deg_to_rad(a)) * r, h, cos(deg_to_rad(a)) * r)
				camera.fov = 45.0
				camera.look_at_from_position(p, c + Vector3(0, 2.0, 0))
			"still":
				camera.global_transform = s.xf
				camera.fov = float(s.get("fov", 50.0))
		await get_tree().process_frame
		t += get_process_delta_time()


## The way to the target's head with the most room (bearings within 50 degrees of the first choice - the same side
## of the line - at eye level and from a little above, over a shoulder): [radians round, metres up]. A bearing is as
## good as the nearest body to its line of sight; small turns win a tie.
func _clear_bearing(target: Node3D, from_side: Vector3, dist: float, height: float) -> Array:
	var face := target.global_basis.z.normalized()
	var base := (from_side * 0.7 + Vector3(face.x, 0, face.z) * 0.5).normalized()
	var head := target.global_position + Vector3(0, height, 0)
	var others := []
	for b in get_tree().get_nodes_in_group("wsg_bodies"):
		if b != target and (b as Node3D).is_visible_in_tree() and (b as Node3D).global_position.distance_to(target.global_position) < dist + 2.0:
			others.append((b as Node3D).global_position)
	var best := [0.0, 0.0]
	var best_room := -1.0
	for lift in [0.0, 0.9]:
		for a in [0.0, 20.0, -20.0, 35.0, -35.0, 50.0, -50.0]:
			var cam := head + base.rotated(Vector3.UP, deg_to_rad(a)) * dist + Vector3(0, 0.15 + lift, 0)
			var room := 2.0
			for p: Vector3 in others:
				# Their body: a column from the knees to the head, its nearest point to the line of sight.
				var ab := head - cam
				for y in [0.6, 1.1, 1.6]:
					var q := p + Vector3(0, y, 0)
					var tt := clampf((q - cam).dot(ab) / ab.length_squared(), 0.0, 1.0)
					if tt < 0.97:
						room = minf(room, q.distance_to(cam + ab * tt))
			room -= absf(a) * 0.002 + lift * 0.1
			if room > best_room:
				best_room = room
				best = [deg_to_rad(a), lift]
	return best
