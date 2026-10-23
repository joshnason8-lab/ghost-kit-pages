class_name Crowd
extends MultiMeshInstance3D
## The spectators: flat cut-outs from one small sheet of painted figures, every one an instance of the same quad, so a
## stand of thousands is one draw call. A shader turns each to face the camera, picks its figure and shirt from the
## sheet, and makes it fidget, and jump and wave when the crowd goes up (excite).

const FIGS := 8          # figures across the sheet
const FIG_W := 48
const FIG_H := 96

static var _sheet: ImageTexture
static var _mat: ShaderMaterial

var spots: Array[Vector3] = []   # where people stand or sit (their feet)


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


static func material() -> ShaderMaterial:
	if _mat:
		return _mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
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
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("sheet", sheet())
	_mat.set_shader_parameter("figs", float(FIGS))
	return _mat


## Fills the spots with people, density 0-1 of them; shirts from palette (a home crowd in its team's colours).
func build(p_spots: Array, density: float, palette: Array, seed_ := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var keep: Array[Vector3] = []
	for s in p_spots:
		if rng.randf() < density:
			keep.append(s)
	spots = keep
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2(0.52, 1.04)
	q.center_offset = Vector3(0, 0.52, 0)
	mm.mesh = q
	mm.instance_count = keep.size()
	for i in keep.size():
		mm.set_instance_transform(i, Transform3D(facing(keep[i]), keep[i]))
		var col: Color = palette[rng.randi_range(0, palette.size() - 1)] if not palette.is_empty() and rng.randf() < 0.45 else Color(rng.randf(), rng.randf(), rng.randf())
		# x: figure, y: a seed for a random shirt (or the palette colour coded below), z: phase.
		mm.set_instance_custom_data(i, Color(rng.randf(), _code(col), rng.randf(), 0.0))
	multimesh = mm
	material_override = material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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


func _process(_delta: float) -> void:
	if material_override:
		(material_override as ShaderMaterial).set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)


static func set_excite(k: float) -> void:
	material().set_shader_parameter("excite", clampf(k, 0.0, 1.0))


static func set_light(k: float) -> void:
	material().set_shader_parameter("light", k)


## The colour of the light the crowd sits in (a dark arena's blue, a hall's warm white).
static func set_tint(c: Color) -> void:
	material().set_shader_parameter("tint", Vector3(c.r, c.g, c.b))
