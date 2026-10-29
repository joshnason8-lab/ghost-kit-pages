class_name PenaltyAim
extends Node3D
## Your penalty shot, as a test of timing (after Hurling Heroes' free-taking): the camera low behind the shooter as he
## skates in, and a target going round the goal mouth in front of him, out wide past the posts, over the bar, back
## in. SHOOT stops it, and that is where the ball goes (match.gd strikes it there). Then the strike: a bar across the
## bottom of the screen, red at each end and green in the middle, its marker running from side to side; SHOOT again
## stops it. In the green the ball goes where the target stopped; out to either side it drifts that way, further the
## further out. A shot into a top corner is the hardest for the goalkeeper (match.gd _check_shot); one in the middle
## of the goal, where he kneels, the easiest.

signal shot(target: Vector3)

const CENTRE_Y := 0.6          # the middle of the target's round, above the floor (m)
const RADIUS_Z := 1.3          # across: out past each post (the posts are 0.8 m from the middle)
const RADIUS_Y := 0.78         # up and down: from the floor to well over the bar (1.15 m)
const GREEN := 0.17            # the bar's green, each side of the middle (the bar runs -1 to 1)
const CORNER := 0.3            # a "top corner": within this of the corner where the bar meets a post (m)

var goal_x := Rules.GOAL_LINE  # the goal line it is in front of
var dir := 1.0                 # the way the shooter shoots (+1 toward +x)
var angle := 0.0
var period := 1.9              # seconds for one round
var bar_period := 1.3          # seconds for the marker to go from one end to the other and back
var stopped := false           # the target stopped (the first SHOOT): the bar runs
var fired := false             # the bar stopped too (the second): the shot is on its way
var bar_x := -1.0
var challenge := false         # practice: the top corners lit gold, worth double
var _t := 0.0
var _bar_t := 0.0
var _ring: MeshInstance3D
var _mat: StandardMaterial3D
var _aim_at := Vector3.ZERO
var _layer: CanvasLayer
var _bar: Control
var _corners: Array[MeshInstance3D] = []


## For a shooter toward d (+1: the goal at +x). skill 0-1 (his shooting) slows it a little.
func setup(d: float, skill: float, rng: RandomNumberGenerator) -> void:
	dir = d
	goal_x = Rules.GOAL_LINE * d
	period = 1.9 * lerpf(0.9, 1.15, clampf(skill, 0.0, 1.0))
	bar_period = 1.3 * lerpf(0.9, 1.15, clampf(skill, 0.0, 1.0))
	angle = rng.randf() * TAU
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.no_depth_test = true
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.billboard_keep_scale = true
	_mat.render_priority = 2
	_ring = MeshInstance3D.new()
	_ring.mesh = ring_mesh(0.17, 0.11)
	_ring.material_override = _mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	# A white edge round it, to read against the net and the crowd.
	var edge_mat: StandardMaterial3D = _mat.duplicate()
	edge_mat.albedo_color = Color(1, 1, 1, 0.95)
	edge_mat.render_priority = 1
	var edge := MeshInstance3D.new()
	edge.mesh = ring_mesh(0.2, 0.09)
	edge.material_override = edge_mat
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.add_child(edge)
	if challenge:
		_show_corners()
	_place()


## Where the target is now (the goal mouth's plane, on the goal line).
func target() -> Vector3:
	return Vector3(goal_x, maxf(0.06, CENTRE_Y + sin(angle) * RADIUS_Y), cos(angle) * RADIUS_Z)


## Is a point in the goal's opening (inside the posts, under the bar, a ball's width in)?
static func in_goal(p: Vector3) -> bool:
	return absf(p.z) < Rules.GOAL_W * 0.5 - Ball.R and p.y < Rules.GOAL_H - Ball.R and p.y > 0.0


## Is a point in one of the top corners?
static func top_corner(p: Vector3) -> bool:
	return in_goal(p) and Vector2(Rules.GOAL_W * 0.5 - absf(p.z), Rules.GOAL_H - p.y).length() < CORNER + 0.08


func _process(delta: float) -> void:
	_t += delta
	if not stopped:
		# Round and round; a little slower out wide, quicker across the goal (the target is small there).
		var p := target()
		var speed := 1.25 if in_goal(p) else 0.8
		angle = fposmod(angle + TAU / period * speed * delta, TAU)
		_place()
	elif not fired:
		_bar_t += delta
		bar_x = sin(_bar_t / bar_period * TAU - PI * 0.5)
		if _bar:
			_bar.queue_redraw()
	var pulse := 1.0 + 0.1 * sin(_t * 9.0) if not stopped else 1.0
	_ring.scale = Vector3.ONE * pulse


func _place() -> void:
	var p := target()
	_ring.global_position = p
	var c := Game.C_GREEN if in_goal(p) else Game.C_RED
	if challenge and top_corner(p):
		c = Game.C_GOLD
	_mat.albedo_color = Color(c, 0.95)


## SHOOT: the first stops the target and starts the bar; the second stops the bar and shoots.
func press() -> void:
	if not stopped:
		stopped = true
		_aim_at = target()
		_show_bar()
		Sfx.click()
		return
	if fired:
		return
	fired = true
	var aim := _aim_at
	var off := absf(bar_x) - GREEN
	if off > 0.0:
		# Out of the green: off to that side (as the camera sees it), up to 0.9 m at the bar's end, and a touch higher.
		var k := off / (1.0 - GREEN)
		var side := Vector3(0, 0, dir) * signf(bar_x)   # the camera looks along +x*dir: its right is +z*dir
		aim += side * (0.15 + 0.75 * k) + Vector3(0, 0.12 * k, 0)
	if _layer:
		_layer.queue_free()
		_layer = null
	_ring.visible = false
	shot.emit(aim)


## The accuracy bar, under the HUD's SHOOT, across the bottom of the screen.
func _show_bar() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 12
	add_child(_layer)
	_bar = Control.new()
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.custom_minimum_size = Vector2(620, 54)
	_bar.size = Vector2(620, 54)
	_bar.position = Vector2(-310, -150)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(func():
		var w := _bar.size.x
		var h := 30.0
		var y := 12.0
		var segs := 40
		for i in segs:
			var x0 := float(i) / segs
			var u := absf(x0 * 2.0 - 1.0 + 1.0 / segs)
			var col := Game.C_GREEN if u <= GREEN else (Game.C_YELLOW if u < 0.5 else Game.C_RED)
			_bar.draw_rect(Rect2(x0 * w, y, w / segs + 0.5, h), Color(col, 0.92))
		_bar.draw_rect(Rect2(0, y, w, h), Color(1, 1, 1, 0.9), false, 3.0)
		var mx := (bar_x * 0.5 + 0.5) * w
		_bar.draw_rect(Rect2(mx - 5, 2, 10, h + 20), Color.WHITE)
		_bar.draw_rect(Rect2(mx - 5, 2, 10, h + 20), Color(0, 0, 0, 0.6), false, 2.0))
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(root)
	root.add_child(_bar)


## The two top corners lit gold (practice's challenge shots): worth double.
func _show_corners() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(Game.C_GOLD, 0.35)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	for s: float in [-1.0, 1.0]:
		var q := MeshInstance3D.new()
		var pm := QuadMesh.new()
		pm.size = Vector2(CORNER, CORNER)
		q.mesh = pm
		q.material_override = m
		q.position = Vector3(goal_x, Rules.GOAL_H - CORNER * 0.5 - 0.02, s * (Rules.GOAL_W * 0.5 - CORNER * 0.5 - 0.02))
		q.rotation = Vector3(0, PI * 0.5, 0)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)
		_corners.append(q)


## A flat ring (the target), facing +z: radius r, band width w.
static func ring_mesh(r: float, w: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 40
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var o0 := Vector3(cos(a0), sin(a0), 0) * r
		var o1 := Vector3(cos(a1), sin(a1), 0) * r
		var i0 := Vector3(cos(a0), sin(a0), 0) * (r - w)
		var i1 := Vector3(cos(a1), sin(a1), 0) * (r - w)
		for v in [o0, o1, i1, o0, i1, i0]:
			st.add_vertex(v)
	return st.commit()
