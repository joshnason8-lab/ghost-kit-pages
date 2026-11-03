// The Low crowd (WsgCrowdCards): each fan a flat card from one atlas (tools/bake_cards.gd), all in one draw call.
// A card stands where the venue puts the fan (WsgCrowdVenue: seated on their seat's height, standing on their floor),
// turned toward the camera about the vertical but never more than turn off the way the fan faces (the play), so the
// stands still look at the game. Seated fans get up as the excitement passes their own point and the keen ones
// cheer, as the 3D crowd's do; shirts take the team colours or the game's per-spot shirts, and skin, hair and the
// legs' clothes the game's palettes (set_looks), from the mask atlas.
shader_type spatial;
render_mode unshaded, cull_disabled, world_vertex_coords;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2D mask : filter_linear_mipmap, repeat_disable;
uniform int cols = 6;
uniform int rows = 3;
uniform int poses = 3;                 // cells a fan: sit, stand, cheer
uniform vec2 size = vec2(1.15, 2.3);   // a cell in the fan's own metres
uniform float turn = 0.6;              // radians a card may turn off its fan's facing toward the camera
uniform float excite = 0.0;
uniform vec4 team_a : source_color = vec4(0.1, 0.45, 0.2, 1.0);
uniform vec4 team_b : source_color = vec4(0.8, 0.15, 0.1, 1.0);
uniform float light = 1.0;
uniform float brightness = 1.0;       // WsgCrowdCards.brightness
uniform vec3 ref_skin[8];
uniform vec3 ref_hair[8];
uniform vec3 ref_legs[8];
uniform vec3 skins[8];
uniform int n_skins = 0;
uniform vec3 hairs[8];
uniform int n_hairs = 0;
uniform vec3 legs[8];
uniform int n_legs = 0;

varying vec2 cell_uv;
varying flat int fan;
varying vec3 shirt;
varying float seat_light;
varying vec3 skin_c;
varying vec3 hair_c;
varying vec3 legs_c;

float hash(float n) {
	return fract(sin(n * 12.9898 + 4.1414) * 43758.5453);
}

float luma(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = length(MODEL_MATRIX[1].xyz);
	vec3 f = MODEL_MATRIX[2].xyz;
	f = normalize(vec3(f.x, 0.0, f.z));
	vec3 to = CAMERA_POSITION_WORLD - origin;
	to = normalize(vec3(to.x, 0.0, to.z) + f * 0.001);
	// Turned from the fan's facing toward the camera about up, at most turn.
	float a = clamp(atan(f.z * to.x - f.x * to.z, dot(f, to)), -turn, turn);
	vec3 dir = vec3(f.x * cos(a) + f.z * sin(a), 0.0, -f.x * sin(a) + f.z * cos(a));
	vec3 right = cross(vec3(0.0, 1.0, 0.0), dir);
	float x = UV.x - 0.5;
	float y = 1.0 - UV.y;
	VERTEX = origin + right * (x * size.x * h) + vec3(0.0, y * size.y * h, 0.0);
	// INSTANCE_CUSTOM: r the fan's own random number, g which fan (their first cell / poses), b the seat's light
	// (positive seated, negative standing). COLOR (the instance's): the shirt, alpha 1 if the game gave one.
	float id = float(INSTANCE_ID) + INSTANCE_CUSTOM.r * 1000.0;
	fan = int(INSTANCE_CUSTOM.g + 0.5);
	float thr = mix(0.32, 0.86, hash(id * 1.31));
	float keen = step(0.3 + 0.4 * hash(id * 2.17), excite);
	int pose = 0;
	if (INSTANCE_CUSTOM.b < 0.0 || excite > thr) {
		pose = keen > 0.5 && hash(id * 7.77) < 0.55 ? 2 : 1;
	}
	int cell = fan * poses + pose;
	cell_uv = (vec2(float(cell % cols), float(cell / cols)) + UV) / vec2(float(cols), float(rows));
	seat_light = abs(INSTANCE_CUSTOM.b);
	// The shirt as the 3D fans': about half in a team's colours, the rest their own, or the game's code.
	vec3 team = hash(id * 3.71) < 0.5 ? team_a.rgb : team_b.rgb;
	float r5 = hash(id * 7.77);
	vec3 own = mix(vec3(0.5), 0.5 + 0.5 * cos(6.2832 * (r5 + vec3(0.0, 0.33, 0.67))), 0.45) * 0.75;
	shirt = hash(id * 5.13) < 0.55 ? team : own;
	// The game's own shirt for this spot, exactly (the instance colour; alpha 0: none given).
	if (COLOR.a > 0.5) {
		shirt = COLOR.rgb;
	}
	int si = min(int(hash(id * 13.7) * float(n_skins)), n_skins - 1);
	skin_c = n_skins > 0 ? skins[si] : vec3(-1.0);
	float dark = n_skins > 0 && luma(skins[si]) < 0.4 ? 0.5 : 1.0;
	hair_c = n_hairs > 0 ? hairs[min(int(hash(id * 17.3) * float(n_hairs) * dark), n_hairs - 1)] : vec3(-1.0);
	legs_c = n_legs > 0 ? legs[min(int(hash(id * 19.1) * float(n_legs)), n_legs - 1)] : vec3(-1.0);
}

vec3 recolour(vec3 c, vec3 ref, vec3 tgt) {
	return tgt * clamp(luma(c) / max(luma(ref), 0.04), 0.6, 1.35);
}

vec3 as_written(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	vec3 cc = max(c, vec3(0.0));
	return mix(pow((cc + vec3(0.055)) / vec3(1.055), vec3(2.4)), cc / 12.92, lessThan(cc, vec3(0.04045)));
#endif
}

void fragment() {
	vec4 t = texture(atlas, cell_uv);
	if (t.a < 0.5) {
		discard;
	}
	vec4 m = texture(mask, cell_uv);
	vec3 c = t.rgb;
	if (skin_c.x >= 0.0) {
		c = mix(c, recolour(t.rgb, ref_skin[fan], skin_c), m.g);
	}
	if (hair_c.x >= 0.0) {
		c = mix(c, recolour(t.rgb, ref_hair[fan], hair_c), m.b);
	}
	if (legs_c.x >= 0.0) {
		c = mix(c, recolour(t.rgb, ref_legs[fan], legs_c), m.a);
	}
	float folds = clamp(luma(t.rgb) * 1.15, 0.5, 1.0);
	c = mix(c, shirt * folds, m.r);
	ALBEDO = as_written(pow(max(min(c, vec3(0.95)), vec3(0.0)), vec3(2.2)) * light * seat_light * brightness);
}
