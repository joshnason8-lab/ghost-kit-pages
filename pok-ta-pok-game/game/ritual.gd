class_name Ritual
extends Node3D
## Before a game on the Yucatán stone courts: an offering of copal, as the games played there today begin. An elder in
## white walks among the players with a clay censer of burning copal, its smoke drifting over each in turn; each raises
## his arms to the sky as the smoke reaches him; at the end all of them do, together. A conch sounds at the start.
## It is a few seconds long, the camera follows the elder, and a tap passes it (SKIP). Ulama's village and festival
## courts in Sinaloa have no such ceremony documented, and none is shown there (docs/CULTURE.md).

const STOP := 0.75          # seconds the elder stands with each player
const WALK := 1.7           # his pace (m/s)
const TOGETHER := 1.6       # seconds of all arms raised together at the end
const RAISE := 1.6          # how close (m) the smoke must be for a player's arms to go up

var m: Node
var elder: Body
var censer: Node3D
var smoke: CPUParticles3D
var done := false
var _stops: Array = []       # [player, where the elder stands]
var _leg := 0
var _wait := 0.0
var _t := 0.0
var _end_t := -1.0
var _phase := 0.0


## Starts it for a match (m): the elder at the analco's near edge.
func setup(p_match: Node) -> void:
	m = p_match
	elder = Body.new({"kind": "judge", "rigged": false, "shirt": Color("f2efe6"), "trousers": Color("ece6d6"), "hat": 0,
		"skin": Color("7c5236"), "hair": Color("d9d4cc"), "height": 1.62, "build": 0.4})
	add_child(elder)
	var hw: float = m.court.half_w_at(0.0)
	elder.global_position = Vector3(0.0, 0.0, hw - 0.6)
	_make_censer()
	for t in m.teams:
		for p in t.players:
			_stops.append([p, Vector3.ZERO])
	Sfx.play("conch", -6.0)


func _make_censer() -> void:
	censer = Node3D.new()
	add_child(censer)
	var bowl := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.045
	cyl.height = 0.08
	cyl.radial_segments = 12
	bowl.mesh = cyl
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color("8a4a2c")
	clay.roughness = 0.9
	bowl.material_override = clay
	censer.add_child(bowl)
	smoke = CPUParticles3D.new()
	smoke.amount = 18 if int(Game.settings.graphics) <= Game.GFX_LOW else 40
	smoke.lifetime = 3.0
	smoke.position = Vector3(0, 0.05, 0)
	smoke.direction = Vector3.UP
	smoke.spread = 18.0
	smoke.gravity = Vector3(0.12, 0.35, 0.0)
	smoke.initial_velocity_min = 0.15
	smoke.initial_velocity_max = 0.35
	smoke.scale_amount_min = 0.25
	smoke.scale_amount_max = 0.45
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.8))
	smoke.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.92, 0.92, 0.9, 0.55))
	fade.set_color(1, Color(0.85, 0.85, 0.85, 0.0))
	smoke.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var puff := GradientTexture2D.new()
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = g
	puff.width = 64
	puff.height = 64
	sm.albedo_texture = puff
	q.material = sm
	smoke.mesh = q
	censer.add_child(smoke)


## One frame of it (Match calls this during the intro and starts the serve once done).
func step(dt: float) -> void:
	if done:
		return
	_t += dt
	var hw: float = m.court.half_w_at(0.0)
	var target := elder.global_position
	if _leg < _stops.size():
		var pl: Player = _stops[_leg][0]
		# He stands a little toward the analco from the player, facing him.
		var at := pl.global_position + Vector3(-signf(pl.global_position.x) * 0.9, 0.0, 0.25)
		at.z = clampf(at.z, -hw + 0.3, hw - 0.3)
		target = at
		var to := target - elder.global_position
		to.y = 0.0
		if to.length() > 0.08:
			var stepv := minf(to.length(), WALK * dt)
			elder.global_position += to.normalized() * stepv
			elder.rotation.y = atan2(to.x, to.z)
			_phase += stepv / 1.1
			elder.apply(Moves.blend(Moves.stance(_t, 0.2), Moves.run(_phase, WALK, 0.2), 0.7))
		else:
			var f := pl.global_position - elder.global_position
			elder.rotation.y = atan2(f.x, f.z)
			elder.apply(_censing(_t))
			_wait += dt
			if _wait >= STOP:
				_wait = 0.0
				_leg += 1
	else:
		if _end_t < 0.0:
			_end_t = _t
		elder.apply(_censing(_t))
		if _t - _end_t >= TOGETHER:
			finish()
			return
	censer.global_position = elder.hand_world() + Vector3(0, -0.12, 0)
	# Each player's arms go up while the smoke is on him; at the end, everyone's together.
	for s in _stops:
		var pl: Player = s[0]
		var near := pl.global_position.distance_to(elder.global_position) < RAISE
		pl.offering = move_toward(pl.offering, 1.0 if near or _end_t >= 0.0 else 0.0, dt * 2.5)


## The elder swinging the censer before a player.
func _censing(t: float) -> Dictionary:
	var sw := sin(t * 3.2) * 18.0
	return {"spine": Moves._v(8.0), "head": Moves._v(6.0),
		"upperarm_r": Moves._v(-55.0 + sw, 0, -8.0), "forearm_r": Moves._v(-25.0),
		"upperarm_l": Moves._v(-10.0, 0, 10.0), "forearm_l": Moves._v(-30.0)}


func finish() -> void:
	if done:
		return
	done = true
	for s in _stops:
		(s[0] as Player).offering = 0.0
	smoke.emitting = false
	elder.visible = false
	censer.visible = false


## Where the camera looks while it lasts.
func focus() -> Vector3:
	return elder.global_position + Vector3(0, 1.0, 0)
