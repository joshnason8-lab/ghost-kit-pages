class_name Crowd
extends MultiMeshInstance3D
## The spectators: flat cut-outs from one small sheet of painted figures, every one an instance of the same quad, so a
## stand of thousands is one draw call. A shader turns each to face the camera, picks its figure and shirt from the
## sheet, and makes it fidget, and jump and wave when the crowd goes up (excite).
## On Medium and High, where the venue says how each person sits or stands (build's seats), they are whole 3D people
## instead (the shared foundation's WsgCrowd3D: about a dozen draw calls), as many as the level's budget allows; any
## left over stay cut-outs, in the same shirts. They sit on the seats, get up and cheer a goal, clap at the breaks
## and turn their heads to the ball (the match's, a replay's too).

const FIGS := 8          # figures across the sheet
const FIG_W := 48
const FIG_H := 96

## Medium and High: 32 people drawn by tools/art/make_crowd.py (assets/venue/crowd_hd.png: their colour rows, then
## the mask rows that say what is shirt and what is scarf or hat in their team's colour). Low keeps the 8 above.
const FIGS_HD := 32
const SHEET_HD := "res://assets/venue/crowd_hd.png"

const SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D sheet : source_color, filter_linear_mipmap;
uniform float figs = 8.0;
uniform float excite = 0.0;
uniform float time_s = 0.0;
uniform float light = 1.0;
uniform vec3 tint = vec3(1.0);
// People this close to the camera are left out: seen from just behind (the Courtside camera over a hall's stand) the
// flat figures read as blocks across the bottom of the screen.
uniform float near_hide = 6.0;
varying vec4 data;
varying float back;
void vertex() {
	data = INSTANCE_CUSTOM;
	// Each spectator faces the court (the instance's +Z, Crowd.build): with the camera behind her, her back shows.
	vec3 seat = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 facing = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xz);
	vec2 to_cam = normalize(INV_VIEW_MATRIX[3].xz - seat.xz);
	back = dot(facing, to_cam) < -0.25 ? 1.0 : 0.0;
	float ph = data.z * 6.2831;
	float jump = max(0.0, sin(time_s * 9.0 + ph)) * excite * 0.28;
	float fidget = sin(time_s * 1.3 + ph) * 0.02;
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	world += right * (VERTEX.x + fidget) + vec3(0.0, VERTEX.y + jump, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	if (distance(cam.xz, (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz) < near_hide) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);   // outside the view: the figure is not drawn
	}
}
void fragment() {
	vec2 uv = vec2((UV.x + floor(data.x * figs)) / figs, (UV.y + back) * 0.5);
	vec4 c = texture(sheet, uv);
	if (c.a < 0.5) discard;
	vec3 shirt = vec3(fract(data.y * 7.13), fract(data.y * 3.77), fract(data.y * 5.31));
	shirt = mix(shirt, vec3(dot(shirt, vec3(0.33))), 0.3) * 0.9;
	float is_shirt = step(0.84, min(c.r, min(c.g, c.b)));
	vec3 col = mix(c.rgb, shirt * c.r, is_shirt);
	ALBEDO = pow(col, vec3(2.2)) * light * tint;
}
"""
const SHADER_HD := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform sampler2D sheet : source_color, filter_linear_mipmap;
uniform float figs = 8.0;
uniform float excite = 0.0;
uniform float time_s = 0.0;
uniform float light = 1.0;
uniform vec3 tint = vec3(1.0);
// People this close to the camera are left out: seen from just behind (the Courtside camera over a hall's stand) the
// flat figures read as blocks across the bottom of the screen.
uniform float near_hide = 6.0;
varying vec4 data;
varying float back;
void vertex() {
	data = INSTANCE_CUSTOM;
	// Each spectator faces the court (the instance's +Z, Crowd.build): with the camera behind her, her back shows.
	vec3 seat = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 facing = normalize((MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xz);
	vec2 to_cam = normalize(INV_VIEW_MATRIX[3].xz - seat.xz);
	back = dot(facing, to_cam) < -0.25 ? 1.0 : 0.0;
	float ph = data.z * 6.2831;
	float jump = max(0.0, sin(time_s * 9.0 + ph)) * excite * 0.28;
	float fidget = sin(time_s * 1.3 + ph) * 0.02;
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	world += right * (VERTEX.x + fidget) + vec3(0.0, VERTEX.y + jump, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	if (distance(cam.xz, (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xz) < near_hide) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);   // outside the view: the figure is not drawn
	}
}
void fragment() {
	// The sheet's rows: front, back (colour); front, back (mask). Mask red: the shirt; green: the team colour.
	vec2 uv = vec2((UV.x + floor(data.x * figs)) / figs, (UV.y + back) * 0.25);
	vec4 c = texture(sheet, uv);
	if (c.a < 0.5) discard;
	vec4 m = texture(sheet, uv + vec2(0.0, 0.5));
	vec3 shirt = vec3(fract(data.y * 7.13), fract(data.y * 3.77), fract(data.y * 5.31));
	shirt = mix(shirt, vec3(dot(shirt, vec3(0.33))), 0.3) * 0.9;
	vec3 team = vec3(fract(data.w * 7.13), fract(data.w * 3.77), fract(data.w * 5.31));
	vec3 col = mix(c.rgb, shirt * c.r, m.r);
	col = mix(col, team * c.r, m.g);
	ALBEDO = pow(col, vec3(2.2)) * light * tint;
}
"""

static var _sheet: ImageTexture
static var _mat: ShaderMaterial
static var _mat_hd: ShaderMaterial

var spots: Array[Vector3] = []   # where the cut-out people stand or sit (their feet)
var people: WsgCrowd3D           # Medium and High: the 3D people (null: all cut-outs)
var people_spots: Array = []     # each 3D person's feet (world, as the arena gave them)
var people_facings: Array = []   # and the way each faces (flat)
var people_seats: Array = []     # and their seat's height over their feet (0: standing)
var _match: Node                 # whose ball they watch and whose play they cheer
var _cheer := 0.0                # seconds of a cheer left (a goal, the end of a quarter)
var _tension := 0.0              # the attack near a goal: the keen ones up before the shot
static var _tint := Color.WHITE
## As the cut-outs' near_hide: the 3D people this close to the camera (m, flat) are left out (the Courtside camera
## behind the hall's stand, the close shot of the post beside the park's crowd).
const NEAR_HIDE := 6.0
var _near: Array = []            # per 3D crowd mesh: [the flat box round its people, their transforms as placed]
var _hidden := {}                # [mesh, instance] -> true: left out for now
var _cam_at := Vector3.INF


## The sheet: eight people, head and shoulders and a shirt, a few skin and hair tones, drawn once; the top row seen
## from the front, the bottom row the same people from behind (the back of the head: hair, the nape of the neck).
static func sheet() -> ImageTexture:
	if _sheet:
		return _sheet
	var img := Image.create_empty(FIG_W * FIGS, FIG_H * 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skins := [Color("e0b48c"), Color("c98a5a"), Color("b07448"), Color("8d5a36")]
	var hairs := [Color("15100c"), Color("2b1d14"), Color("15100c"), Color("4a3a2a")]
	for f in FIGS:
		var ox := f * FIG_W
		var skin: Color = skins[f % 4]
		var hair: Color = hairs[(f + 1) % 4]
		# The shirt is white here: the shader tints it with each person's colour.
		for y in FIG_H:
			for x in FIG_W:
				var u := (x + 0.5) / FIG_W - 0.5
				var v := (y + 0.5) / FIG_H
				var c := Color(0, 0, 0, 0)
				# Body: shoulders from 0.42 down, a rounded top.
				var shoulder := 0.45 + 0.04 * float(f % 3)
				if v > shoulder and absf(u) < 0.42 - maxf(0.0, (shoulder + 0.08 - v)) * 2.2:
					c = Color(1, 1, 1, 1)
				# Arms a shade darker at the sides.
				if c.a > 0.0 and absf(u) > 0.3:
					c = Color(0.85, 0.85, 0.85, 1)
				# Head.
				var hd := Vector2(u / 0.2, (v - 0.3) / 0.15)
				if hd.length() < 1.0:
					c = skin
					if v < 0.26 + 0.02 * float(f % 2) or (f % 4 == 3 and absf(u) > 0.13):
						c = hair
				# Neck.
				if v > 0.42 and v < shoulder + 0.02 and absf(u) < 0.07:
					c = skin.darkened(0.1)
				img.set_pixel(ox + x, y, c)
				# From behind: the head is hair down to the nape (a little skin under it for short hair).
				var b := c
				if hd.length() < 1.0:
					b = hair if v < 0.4 or f % 2 == 1 else skin.darkened(0.15)
				img.set_pixel(ox + x, FIG_H + y, b)
	img.generate_mipmaps()
	_sheet = ImageTexture.create_from_image(img)
	return _sheet


## The crowd's material at this graphics level (both made once).
static func material() -> ShaderMaterial:
	return _material_hd() if Game.hd() else _material_low()


static func _material_low() -> ShaderMaterial:
	if _mat:
		return _mat
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("sheet", sheet())
	_mat.set_shader_parameter("figs", float(FIGS))
	return _mat


static func _material_hd() -> ShaderMaterial:
	if _mat_hd:
		return _mat_hd
	var sh := Shader.new()
	sh.code = SHADER_HD
	_mat_hd = ShaderMaterial.new()
	_mat_hd.shader = sh
	_mat_hd.set_shader_parameter("sheet", load(SHEET_HD))
	_mat_hd.set_shader_parameter("figs", float(FIGS_HD))
	return _mat_hd


## Fills the spots with people, density 0-1 of them; shirts from palette (a home crowd in its team's colours).
## seats (Medium and High): for each spot, how a whole person is there - [their feet (world), the seat's height over
## them (0: standing), how far behind the feet the step behind rises (INF: nothing), the way they face (flat)]; with
## it they are 3D people (WsgCrowd3D) where the level's budget allows, about half in the two teams' colours (away:
## the visitors'), the cut-outs drawing the rest in the same shirts.
func build(p_spots: Array, density: float, palette: Array, seed_ := 1, seats: Array = [], away: Array = []) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var keep: Array[Vector3] = []
	var kept := []
	for i in p_spots.size():
		if rng.randf() < density:
			keep.append(p_spots[i])
			kept.append(i)
	var shirts := []
	if Game.hd() and seats.size() == p_spots.size() and WsgCrowd3D.available() and not OS.has_environment("WSG_OFF"):
		shirts = _shirts(kept, palette, away, seed_)
		var used := _build_people(kept, seats, shirts, seed_)
		# The cut-outs: everyone the 3D crowd's budget left out, in the shirts they would have worn.
		var taken := {}
		for n in used:
			taken[n] = true
		var rest: Array[Vector3] = []
		var rest_shirts := []
		for n in keep.size():
			if not taken.has(n):
				rest.append(keep[n])
				rest_shirts.append(shirts[n])
		keep = rest
		shirts = rest_shirts
	spots = keep
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(0.52, 1.04)
	q.center_offset = Vector3(0, 0.52, 0)
	mm.mesh = q
	mm.instance_count = keep.size()
	# Medium and High: each also has a scarf or hat in a team's colour (mostly the home team's), w; from a second
	# generator, so the people, their shirts and seats are those Low would draw.
	var hd := Game.hd()
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = seed_ + 7
	var codes := palette.map(func(c): return _code(c))
	for i in keep.size():
		mm.set_instance_transform(i, Transform3D(facing(keep[i]), keep[i]))
		var col: Color = palette[rng.randi_range(0, palette.size() - 1)] if not palette.is_empty() and rng.randf() < 0.45 else Color(rng.randf(), rng.randf(), rng.randf())
		if i < shirts.size():
			col = shirts[i]
		# x: figure, y: a seed for a random shirt (or the palette colour coded below), z: phase, w: the team colour.
		var w := 0.0
		if hd:
			w = float(codes[rng2.randi_range(0, codes.size() - 1)]) if not codes.is_empty() and rng2.randf() < 0.8 else rng2.randf()
		mm.set_instance_custom_data(i, Color(rng.randf(), _code(col), rng.randf(), w))
	multimesh = mm
	material_override = material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The 3D people (Medium and High) in the kept spots, as many as the level's budget allows (the rest: the indices into
## kept it did not take are the cut-outs'). Returns which of kept it drew.
func _build_people(kept: Array, seats: Array, shirts: Array, seed_: int) -> PackedInt32Array:
	var feet := []
	var facings := []
	var seated := []
	var room := []
	for i in kept:
		var s: Array = seats[i]
		feet.append(s[0])
		seated.append(float(s[1]))
		room.append(float(s[2]))
		facings.append(s[3])
	people = WsgCrowd3D.new()
	people.name = "People"
	add_child(people)
	# A netball crowd: about two thirds of them the two women of the shared fans.
	people.fan_weights = {"fan2": 4.0, "fan5": 4.0}
	# (density 1: the spots are already the ones with someone in them, as the cut-outs had them.)
	var used := people.build(feet, facings, 1.0, seed_, seated, clampi(int(Game.settings.graphics), 1, 2), Vector3.ZERO,
		room, shirts)
	# Each their own skin, hair and trousers, skirt or shorts (no draw calls, no CPU: in the crowd's shader).
	people.set_looks(WsgCrowd3D.LOOKS.skin, WsgCrowd3D.LOOKS.hair, WsgCrowd3D.LOOKS.legs)
	people_spots = []
	people_facings = []
	people_seats = []
	for n in used:
		people_spots.append(feet[n])
		people_facings.append(facings[n])
		people_seats.append(seated[n])
	# Lit as the venue lights its stands (the arena's dim blue night, a hall's white light, the park's evening sun):
	# by the key light, as bright as the cut-outs' tint.
	WsgCrowd3D.set_light(clampf(_tint.get_luminance(), 0.3, 1.0))
	set_excite(0.0)
	WsgCrowd3D.set_tension(0.0)
	_near = []
	_hidden = {}
	for mi in people.meshes:
		var mm := mi.multimesh
		var xfs := []
		var box := Rect2()
		for k in mm.instance_count:
			var xf := mm.get_instance_transform(k)
			xfs.append(xf)
			box = Rect2(xf.origin.x, xf.origin.z, 0, 0) if k == 0 else box.expand(Vector2(xf.origin.x, xf.origin.z))
		_near.append([box, xfs])
	return used


## Leaves out the 3D people within NEAR_HIDE of the camera (as the cut-outs' shader does), putting back those it no
## longer is: only when the camera has moved, and only in the crowd's meshes it is near.
func _near_hide() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return
	var c := cam.global_position
	if c.distance_squared_to(_cam_at) < 0.04:
		return
	_cam_at = c
	var c2 := Vector2(c.x, c.z)
	for i in _near.size():
		var box: Rect2 = _near[i][0]
		if box.grow(NEAR_HIDE).has_point(c2) or _hidden.has(i):
			var mm := people.meshes[i].multimesh
			var xfs: Array = _near[i][1]
			var any := false
			for k in xfs.size():
				var xf: Transform3D = xfs[k]
				var near := Vector2(xf.origin.x, xf.origin.z).distance_squared_to(c2) < NEAR_HIDE * NEAR_HIDE
				var key := Vector2i(i, k)
				if near != _hidden.has(key):
					# (Hidden: shrunk to nothing where they stand; the shader's sums stay finite.)
					mm.set_instance_transform(k, Transform3D(xf.basis.scaled(Vector3.ONE * 0.001), xf.origin) if near else xf)
					if near:
						_hidden[key] = true
					else:
						_hidden.erase(key)
				any = any or near
			if any:
				_hidden[i] = true
			else:
				_hidden.erase(i)


## Each kept spot's person's shirt, decided once (the 3D person and the cut-out wear the same): about half in the
## teams' colours (the home side's palette most, the visitors' away), the rest anything (the shader mutes them).
static func _shirts(kept: Array, palette: Array, away: Array, seed_: int) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	for i in kept:
		rng.seed = hash([seed_, i])
		var col := Color(rng.randf(), rng.randf(), rng.randf())
		var k := rng.randf()
		if k < 0.32 and not palette.is_empty():
			col = palette[rng.randi_range(0, palette.size() - 1)]
		elif k < 0.5 and not away.is_empty():
			col = away[rng.randi_range(0, away.size() - 1)]
		out.append(col)
	return out


## The way someone sitting in a row of seats facing normal (flat) faces: toward the court's middle, but turned no more
## than max_turn from straight ahead (their seat), so they fit it.
static func seat_facing(p: Vector3, normal: Vector3, max_turn := deg_to_rad(30.0)) -> Vector3:
	var n := Vector3(normal.x, 0.0, normal.z).normalized()
	var to := Vector3(-p.x, 0.0, -p.z)
	if to.length() < 0.01:
		return n
	var a := clampf(n.signed_angle_to(to.normalized(), Vector3.UP), -max_turn, max_turn)
	return n.rotated(Vector3.UP, a)


## A spectator at p faces the middle of the court (the origin): her +Z, flat on the ground, points there. The shader
## turns the cut-out to the camera but shows her back when the camera is behind her.
static func facing(p: Vector3) -> Basis:
	var to := Vector2(-p.x, -p.z)
	if to.length() < 0.01:
		return Basis.IDENTITY
	return Basis(Vector3.UP, atan2(to.x, to.y))


## Shirt colours come out of the shader from one number; find one whose colour is near col (a few tries).
static func _code(col: Color) -> float:
	var best := 0.0
	var bd := 9.0
	for i in 256:
		var y := float(i) / 256.0 + 0.001
		var c := Vector3(fposmod(y * 7.13, 1.0), fposmod(y * 3.77, 1.0), fposmod(y * 5.31, 1.0))
		var d := c.distance_to(Vector3(col.r, col.g, col.b))
		if d < bd:
			bd = d
			best = y
	return best


func _ready() -> void:
	if people == null:
		return
	# The match this crowd is at (the arena's parent): its ball and its play.
	var a := get_parent()
	_match = a.get_parent() if a else null
	if _match and _match.has_signal("game_event"):
		_match.game_event.connect(_on_event)
	for n in (a.get_children() if a else []):
		if n is DirectionalLight3D:
			# Lit from the venue's key light (the sun outdoors), as the players are.
			WsgCrowd3D.set_sun((n as DirectionalLight3D).global_transform.basis.z)
			break


func _process(delta: float) -> void:
	if material_override:
		(material_override as ShaderMaterial).set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)
	if people == null:
		return
	_near_hide()
	if _match == null:
		return
	var ball = _match.get("ball")
	if ball is Node3D:
		var b: Vector3 = (ball as Node3D).global_position
		people.watch_ball(b)
		# Play near a goal (in its circle) has the keen ones on the edge of their seats; anywhere else they settle.
		var want := 0.45 if absf(b.x) > Court.HALF_L - 4.9 and absf(b.z) < 5.0 else 0.0
		_tension = move_toward(_tension, want, delta * (0.8 if want > _tension else 0.4))
		WsgCrowd3D.set_tension(_tension)
	if _cheer > 0.0:
		_cheer -= delta
		if _cheer <= 0.0:
			set_excite(0.0)


## The play as the crowd sees it: up for a goal, an ooh at a gain, applause at the end of a quarter and the match.
func _on_event(kind: String, _info: Dictionary) -> void:
	match kind:
		"goal":
			set_excite(1.0)
			_cheer = 3.0
		"gain":
			set_excite(0.45)
			_cheer = 1.2
		"period_end":
			set_excite(0.55)
			_cheer = 4.0
			people.clap(2.2, 0.55, 5.0)
		"centre_setup":
			_tension = 0.0


static func set_excite(k: float) -> void:
	material().set_shader_parameter("excite", clampf(k, 0.0, 1.0))
	WsgCrowd3D.set_excite(k)


static func set_light(k: float) -> void:
	material().set_shader_parameter("light", k)
	WsgCrowd3D.set_light(k)


## The colour of the light the crowd sits in (a dark arena's blue, a hall's warm white).
static func set_tint(c: Color) -> void:
	_tint = c
	material().set_shader_parameter("tint", Vector3(c.r, c.g, c.b))
