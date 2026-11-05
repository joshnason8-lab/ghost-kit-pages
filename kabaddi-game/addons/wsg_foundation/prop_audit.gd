class_name WsgPropAudit
extends RefCounted
## The props' audit (tools/prop_audit.gd runs it over a game's Watch-AI matches): every frame a game hands it its
## bodies and its ball, and it notes every body more than PEN_TOL into a prop (WsgSolidProps.penetration) and every
## ball step that went through one (the straight way between two of the ball's frames more than PEN_TOL inside a
## prop: a ball that bounced off never does).
##   var audit := WsgPropAudit.new(solid)
##   audit.body("home 7", pos, 0.3, 1.8)      # each body, each frame
##   audit.ball(ball_pos, 0.11)               # the ball, each frame
##   audit.ball_reset()                       # the ball put somewhere new (a restart): no step from the old place
##   audit.report()                           # {pass, body_cases, ball_tunnels, worst: [...], skipped}

const PEN_TOL := 0.02
## The worst cases kept for the report and its close-ups.
const KEEP := 24

var solid: WsgSolidProps
var body_checks := 0
## Frames a body was seated on a prop (body(..., seated = true)): counted, not checked.
var seated_frames := 0
var ball_steps := 0
var body_cases := 0
var ball_tunnels := 0
## The worst: {kind ("body" | "ball"), who, prop (name), depth (m), pos, from (a ball's step), time}.
var worst: Array = []
var time := 0.0
## The caller's own frame number, when it has one (WsgSim): stamped on each case. (Its time - a sum of frame times -
## read as a frame comes out a frame early for most frames: a replay stopped there ended before the case.)
var frame := -1

var _last := {}       # a ball -> its last position


func _init(p_solid: WsgSolidProps = null) -> void:
	solid = p_solid


## SEATED: the body sits on the prop (a substitute on the bench, a scorer at the table: its seated pose is over the
## seat, not in it) - counted, not checked. A body getting up from it must be out within a few frames (free_spot).
func body(who: String, pos: Vector3, radius: float, height := 1.8, seated := false) -> void:
	if seated:
		seated_frames += 1
		return
	body_checks += 1
	var pen := solid.penetration(pos, radius, height)
	if float(pen[0]) > PEN_TOL:
		body_cases += 1
		_keep({"kind": "body", "who": who, "prop": String(solid.props[int(pen[1])].name), "depth": float(pen[0]),
			"pos": pos, "radius": radius, "height": height, "time": time, "frame": frame})


## The ball (WHO) at POS this frame. PATH: the places it went through since the last frame, in order, if its physics
## takes several steps a frame (a bounce off a wall inside a frame: the straight line from the last frame's place cut
## the corner past a prop by the wall - Sepak Takraw's camera tripod, 2.3 cm "into" it). Each step is swept.
func ball(pos: Vector3, radius: float, who := "ball", path := []) -> void:
	if _last.has(who):
		ball_steps += 1
		var from: Vector3 = _last[who]
		for q in path:
			if q is Vector3 and (q as Vector3).is_finite() and not (q as Vector3).is_equal_approx(from):
				_ball_step(who, from, q, radius)
				from = q
		if not pos.is_equal_approx(from) or path.is_empty():
			_ball_step(who, from, pos, radius)
	_last[who] = pos


func _ball_step(who: String, p0: Vector3, pos: Vector3, radius: float) -> void:
	var h := solid.sweep(p0, pos, radius)
	if h.hit:
		# How deep the straight way goes: from where it meets the prop to where it leaves it, its middle.
		var back := solid.sweep(pos, p0, radius)
		var t_out := 1.0 - float(back.t) if back.hit else 1.0
		var t_in := float(h.t)
		if t_out > t_in:
			var mid := p0.lerp(pos, (t_in + t_out) * 0.5)
			var inside := solid.sweep(mid, mid, radius)
			if inside.hit and float(inside.get("depth", 0.0)) > PEN_TOL:
				ball_tunnels += 1
				_keep({"kind": "ball", "who": who, "prop": String(h.name), "depth": float(inside.depth), "pos": mid,
					"from": p0, "to": pos, "radius": radius, "time": time, "frame": frame})


func ball_reset(who := "ball") -> void:
	_last.erase(who)


## Advance the audit's clock (for the report's times): a game calls it once a frame with its delta.
func tick(delta: float) -> void:
	time += delta


func report() -> Dictionary:
	return {"pass": body_cases == 0 and ball_tunnels == 0, "body_checks": body_checks, "seated_frames": seated_frames, "ball_steps": ball_steps,
		"body_cases": body_cases, "ball_tunnels": ball_tunnels, "worst": worst.map(func(c: Dictionary) -> Dictionary:
			var o := c.duplicate()
			for k in ["pos", "from", "to"]:
				if o.has(k):
					o[k] = [snappedf(o[k].x, 0.01), snappedf(o[k].y, 0.01), snappedf(o[k].z, 0.01)]
			o.depth = snappedf(o.depth, 0.001)
			return o), "skipped": solid.skipped}


func _keep(c: Dictionary) -> void:
	# One a body and prop (the deepest), the deepest KEEP in all.
	for k in worst.size():
		var w: Dictionary = worst[k]
		if w.kind == c.kind and w.who == c.who and w.prop == c.prop:
			if c.depth > w.depth:
				worst[k] = c
			return
	worst.append(c)
	worst.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.depth) > float(y.depth))
	if worst.size() > KEEP:
		worst.resize(KEEP)
