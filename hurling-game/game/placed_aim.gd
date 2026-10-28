class_name PlacedAim
extends Node3D
## Your free, 65 or penalty at the posts, as a test of timing: the camera low behind the taker, looking at the goal,
## and a target going round in front of it, through the net, out wide, up through the posts above the bar and out
## the other side. SHOOT stops it, and that is where the sliotar goes (match.gd strikes it there, near enough). The
## target hurries through the goal (a small space, with a keeper in it) and lingers between the posts above the bar
## (a big one), and goes round faster the further out the free is.
## (The owner: "When a penalty is in range of trying to score points have the camera be ground level beyond the
## shooter. There will be a simple button that says shoot. But it's about timing.")
## Then the strike itself: a bar across the bottom of the screen, red at each end and green in the middle, its marker
## running from side to side. SHOOT again stops it; in the green the sliotar goes where the target stopped, out to
## either side it goes that way, further the further out (the owner: "If they go to far to the left or right the
## ball reacts accordingly").

const CENTRE_Y := 3.2          # the middle of the target's round, above the ground (m)
const RADIUS_Z := 6.4          # across: out past each upright (the uprights are 3.25 m from the middle)
const RADIUS_Y := 2.9          # up and down: from 0.3 m (in the net) to 6.1 m (well over the bar)
const SLOW_POSTS := 0.55       # its speed between the posts above the bar, against wide
const FAST_GOAL := 1.9         # and in the goal

signal shot(target: Vector3)
signal done                    # the shot has been seen: back to the match camera

const WATCH := 2.6             # seconds the low camera stays on the flight after the strike
const WAIT := 12.0             # left this long, it stops by itself
const BAR_WAIT := 6.0          # and the bar, left this long after the target stopped
const GREEN := 0.17            # the bar's green, each side of the middle (the bar runs -1 to 1)

var goal_x := 0.0              # the goal line it is in front of
var dir := 1.0                 # the way the taker shoots
var angle := 0.0
var period := 2.6              # seconds for one round, wide all the way
var stopped := false           # the target stopped (the first SHOOT): the bar runs
var fired := false             # the bar stopped too (the second): the shot is on its way
var bar_x := -1.0              # the bar's marker, -1 (the left end) to 1
var bar_period := 1.4          # seconds for the marker to go from one end to the other and back
var camera: Camera3D
var _ring: MeshInstance3D
var _mat: StandardMaterial3D
var _t := 0.0
var _hold := 0.0
var _bar_t := 0.0
var _dist := 30.0
var _aim_at := Vector3.ZERO    # where the target stopped
var _layer: CanvasLayer        # the bar, over the HUD
var _bar: Control


## Set up for a taker standing at stand over the ball at spot, shooting toward d (+1 toward +x). skill 0-1 (his
## free-taking) slows it a little. view: a camera already there to use (free-taking practice keeps its own), else
## one is made.
func setup(spot: Vector3, stand: Vector3, d: float, skill: float, rng: RandomNumberGenerator, view: Camera3D = null) -> void:
	dir = d
	goal_x = Pitch.HALF_L * d
	var dist := absf(goal_x - spot.x)
	_dist = dist
	# Faster from further out: a round of 2.9 s from 14 m, 1.8 s from 65 m; a good free-taker's a little slower.
	period = lerpf(2.9, 1.8, clampf((dist - 14.0) / 51.0, 0.0, 1.0)) * lerpf(0.9, 1.12, clampf(skill, 0.0, 1.0))
	# The bar too: end to end and back in 1.6 s close in, 1.1 s from 65 m.
	bar_period = lerpf(1.6, 1.1, clampf((dist - 14.0) / 51.0, 0.0, 1.0)) * lerpf(0.9, 1.12, clampf(skill, 0.0, 1.0))
	angle = rng.randf() * TAU
	if view != null:
		camera = view
	else:
		camera = Camera3D.new()
		add_child(camera)
	low_view(camera, spot, stand, d)
	camera.make_current()
	var reach := Vector2(goal_x, 0).distance_to(Vector2(camera.global_position.x, camera.global_position.z))
	# The target: a ring that always faces the camera, about as big on the screen from any distance.
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.billboard_keep_scale = true
	_ring = MeshInstance3D.new()
	_ring.mesh = _ring_mesh(0.5, 0.3)
	_ring.material_override = _mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_ring.scale = Vector3.ONE * clampf(reach * 0.034, 0.7, 2.4)
	# A white edge round it, to read against the crowd and the sky.
	var edge_mat: StandardMaterial3D = _mat.duplicate()
	edge_mat.albedo_color = Color(1, 1, 1, 0.95)
	edge_mat.render_priority = -1
	var edge := MeshInstance3D.new()
	edge.mesh = _ring_mesh(0.6, 0.24)
	edge.material_override = edge_mat
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.add_child(edge)
	_place()


## The camera for a free: low, eight metres behind the taker (at stand) and a metre to his side, looking past his
## shoulder at the goal (right behind him, his back hid it); the goal framed at any distance (closer frees wider).
## back: metres further back still (free-taking practice eases in from there as he walks up).
static func low_view(camera: Camera3D, spot: Vector3, stand: Vector3, d: float, back := 0.0) -> void:
	var goal_x := Pitch.HALF_L * d
	var to_goal := Vector3(goal_x - stand.x, 0, -stand.z).normalized()
	var side := Vector3(-to_goal.z, 0, to_goal.x)
	# The side of him away from the ball: he is framed at the edge, the ball and the goal clear.
	var away := -signf(side.dot(spot - stand)) if (spot - stand).length() > 0.2 else 1.0
	camera.near = 0.2
	camera.far = 900.0
	camera.global_position = Vector3(stand.x, 0, stand.z) - to_goal * (8.0 + back) + side * away * 1.25 + Vector3(0, 1.0 + back * 0.15, 0)
	camera.look_at(Vector3(goal_x, CENTRE_Y + 0.6, 0))
	var reach := Vector2(goal_x, 0).distance_to(Vector2(camera.global_position.x, camera.global_position.z))
	camera.fov = clampf(rad_to_deg(2.0 * atan(6.5 / reach)), 17.0, 36.0)


## Where the target is now, on the goal line (world space).
func target() -> Vector3:
	return Vector3(goal_x, CENTRE_Y + sin(angle) * RADIUS_Y, cos(angle) * RADIUS_Z * dir)


## What the target is over: "goal" (in the net, under the bar between the posts), "point" (over the bar between
## them, as high as it goes) or "wide".
static func zone(p: Vector3) -> String:
	if absf(p.z) > Pitch.POST_GAP * 0.5 - 0.1:
		return "wide"
	return "goal" if p.y < Pitch.BAR_H - 0.12 else "point"


func _process(dt: float) -> void:
	_t += dt
	if not stopped and _t > WAIT:
		stop()
	if stopped and not fired:
		# The target held where it stopped, pulsing; the bar's marker running end to end, from the left.
		_bar_t += dt
		bar_x = -cos(_bar_t * TAU / bar_period)
		_mat.albedo_color.a = 0.75 + 0.25 * absf(sin(_bar_t * 6.0))
		_bar.queue_redraw()
		if _bar_t > BAR_WAIT:
			stop()
		return
	if fired:
		_hold += dt
		# A beat, the target flashing where it stopped, then gone as he strikes; the camera stays on the flight.
		_mat.albedo_color.a = 0.6 + 0.4 * absf(sin(_hold * 18.0))
		_ring.visible = _hold < 0.5
		_layer.visible = _hold < 0.7
		if _hold > 0.35 + WATCH:
			set_process(false)
			done.emit()
		return
	var z := zone(target())
	var k := SLOW_POSTS if z == "point" else (FAST_GOAL if z == "goal" else 1.0)
	angle = fmod(angle + TAU / period * k * dt, TAU)
	_place()


func _place() -> void:
	var p := target()
	_ring.global_position = p
	match zone(p):
		"point":
			_mat.albedo_color = Color(Game.C_GOLD, 0.95)
		"goal":
			_mat.albedo_color = Color(0.35, 0.9, 0.45, 0.95)
		_:
			_mat.albedo_color = Color(0.95, 0.3, 0.25, 0.9)


## SHOOT: the first stops the target and starts the bar; the second stops the bar, and shot is sent after a beat
## with where the sliotar goes: the target's spot, moved to the side the bar stopped on if it stopped out of the
## green. Returns that spot (the target's, the first time).
func stop() -> Vector3:
	if fired:
		return _aim_at
	if not stopped:
		stopped = true
		_aim_at = target()
		_show_bar()
		return _aim_at
	fired = true
	var p := strike_point(_aim_at, bar_x)
	_bar.queue_redraw()
	get_tree().create_timer(0.25).timeout.connect(func(): shot.emit(p))
	return p


## Where the sliotar goes for a target stopped at aim and the bar at x (-1 to 1): aim in the green; out of it,
## moved across the goal to that side (the side of the screen, from behind the taker), up to 2.5 m plus a ninth of
## the distance at the bar's end (a 45 m free from the end: 7.5 m, well wide), and a little lower (struck thin).
func strike_point(aim: Vector3, x: float) -> Vector3:
	var out := maxf(0.0, (absf(x) - GREEN) / (1.0 - GREEN))
	if out <= 0.0:
		return aim
	var k := pow(out, 1.2)
	var right := -camera.global_transform.basis.z.cross(Vector3.UP)
	var p := aim
	p.z += signf(x) * signf(right.z if absf(right.z) > 0.05 else 1.0) * k * (2.5 + _dist / 9.0)
	p.y = maxf(0.4, p.y - k * 0.9)
	return p


## The bar: across the bottom of the screen, over the HUD, with a line above it saying what to do.
func _show_bar() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)
	_bar = Control.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	_layer.add_child(_bar)
	var hint := Label.new()
	hint.text = tr("AIM_BAR_HINT")
	hint.theme = Game.theme
	hint.theme_type_variation = "SubLabel"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hint.add_theme_constant_override("outline_size", 6)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -360
	hint.offset_right = 360
	var r := _bar_rect()
	hint.offset_top = r.position.y - _bar.get_viewport_rect().size.y - 44
	hint.offset_bottom = hint.offset_top + 34
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(hint)


func _bar_rect() -> Rect2:
	var vp := get_viewport().get_visible_rect().size
	var w := clampf(vp.x * 0.42, 360.0, 760.0)
	return Rect2(Vector2((vp.x - w) * 0.5, vp.y * 0.8 - 17.0), Vector2(w, 34.0))


## Red at the ends through amber to green in the middle; the marker a white line with a point above it.
static func bar_colour(x: float) -> Color:
	var a := absf(x)
	if a <= GREEN:
		return Color(0.3, 0.84, 0.42)
	var k := (a - GREEN) / (1.0 - GREEN)
	return Color(0.95, 0.78, 0.25).lerp(Color(0.86, 0.24, 0.2), smoothstep(0.15, 0.75, k))


func _draw_bar() -> void:
	var r := _bar_rect()
	_bar.draw_rect(r.grow(5.0), Color(0.03, 0.06, 0.04, 0.82))
	var n := 72
	for i in n:
		var x0 := -1.0 + 2.0 * i / n
		var seg := Rect2(r.position + Vector2(r.size.x * i / n, 0), Vector2(r.size.x / n + 1.0, r.size.y))
		_bar.draw_rect(seg, bar_colour(x0 + 1.0 / n))
	# The green's edges, so the target zone reads at a glance.
	for e: float in [-GREEN, GREEN]:
		var ex := r.position.x + (e + 1.0) * 0.5 * r.size.x
		_bar.draw_line(Vector2(ex, r.position.y), Vector2(ex, r.end.y), Color(1, 1, 1, 0.7), 2.0)
	var mx := r.position.x + (bar_x + 1.0) * 0.5 * r.size.x
	var col := Color.WHITE if not fired else bar_colour(bar_x).lightened(0.4)
	_bar.draw_line(Vector2(mx, r.position.y - 10.0), Vector2(mx, r.end.y + 10.0), Color(0, 0, 0, 0.6), 8.0)
	_bar.draw_line(Vector2(mx, r.position.y - 10.0), Vector2(mx, r.end.y + 10.0), col, 4.0)
	_bar.draw_colored_polygon(PackedVector2Array([Vector2(mx - 11, r.position.y - 24), Vector2(mx + 11, r.position.y - 24),
		Vector2(mx, r.position.y - 10)]), col)


## A flat ring of inner radius r_in, outer r (a quad strip), with a dot in the middle.
static func _ring_mesh(r: float, r_in: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 40
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cos(a0), sin(a0), 0)
		var p1 := Vector3(cos(a1), sin(a1), 0)
		st.add_vertex(p0 * r_in)
		st.add_vertex(p0 * r)
		st.add_vertex(p1 * r)
		st.add_vertex(p0 * r_in)
		st.add_vertex(p1 * r)
		st.add_vertex(p1 * r_in)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(p0 * 0.09)
		st.add_vertex(p1 * 0.09)
	return st.commit()
