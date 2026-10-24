class_name VenueLook
extends RefCounted
## The venues' shaders. All of a venue's structure is drawn by two materials (one lit, one that glows) and its lights
## by a third, so a whole venue is three draw calls. Each face carries a kind in its second UV (Geo.kind), and the
## shader paints it: a polished court with the lights reflected in it, a timber floor, a stand painted with seated
## people, stairs and aisle lights, brushed metal, glossy plastic, a corded net, glowing boards. The far parts fade
## into the night (fade_*).

## The kinds of face (Geo.kind.x). Their parameter (Geo.kind.y) is noted beside each.
const PLAIN := 0.0       # vertex colour as it is (glow: y adds brightness)
const FLOOR := 1.0       # a polished floor: pools of light (pool_*), sheen, the lights reflected, a vignette
const WOOD := 2.0        # a timber floor (boards along x), polished like FLOOR
const STAND := 3.0       # a tier of seats with people on it; UV in metres (u along, v up the slope); y the first row filled
const METAL := 4.0       # brushed metal: a bright streak down a cylinder
const GLOSS := 5.0       # glossy plastic (the ring, padding)
const NET := 6.0         # glow: a corded net; UV u round the ring (one per cord), v down
const LED := 7.0         # glow: an LED band, a slow sweep of light along it; y adds brightness
const ASPHALT := 8.0     # an outdoor court's surround: speckled, a little sheen
const STANDING := 9.0    # people standing in a row, painted on an upright face; UV in metres
const FENCE := 10.0      # glow: chain-link wire; UV in metres
const MAPLE := 11.0      # a sprung maple floor (tex_wood, the photo-scanned veneer), polished, the hall in it (refl_pan)
const BLOCK := 12.0      # painted concrete block: the vertex colour is the paint, tex_block's normal map its relief
const CEIL := 13.0       # ceiling boards (tex_ceil)
const SLAT := 14.0       # pale timber slats on a wall, upright (tex_wood)
const ACRYLIC := 15.0    # an outdoor court's acrylic coat on asphalt: the vertex colour, the asphalt's grain (tex_asph)
const TARMAC := 16.0     # plain asphalt paths (tex_tarmac)
const GRASS := 17.0      # mown grass in stripes (vertex colour, tex_tarmac's grain)
const PAINTED := 18.0    # a painted sprung timber court: the vertex colour is the paint, tex_wood's grain under it

const COMMON := """
varying vec3 wpos;
uniform vec3 lamp[8];
uniform int lamp_count = 0;
uniform vec3 lamp_col : source_color = vec3(1.0, 0.95, 0.85);
uniform float sheen = 0.35;
uniform float gloss = 260.0;
uniform vec2 vig_size = vec2(26.0, 18.0);
uniform float vig_dark = 0.55;
uniform vec3 night : source_color = vec3(0.03, 0.06, 0.16);
uniform float fade_y0 = 5.0;
uniform float fade_y1 = 15.0;
uniform float fade_amt = 0.0;
uniform vec3 seat_col : source_color = vec3(0.1, 0.12, 0.3);
uniform vec3 stair_col : source_color = vec3(0.35, 0.38, 0.5);
uniform vec3 team_a : source_color = vec3(1.0, 0.8, 0.1);
uniform vec3 team_b : source_color = vec3(0.1, 0.4, 0.2);
uniform float density = 0.85;
uniform float excite = 0.0;
uniform float aisle_every = 10.0;
uniform vec3 stand_tint = vec3(1.0);
uniform vec2 pool_size = vec2(17.0, 10.0);
uniform float pool_lo = 1.0;
uniform float pool_hi = 1.0;
uniform float pool_glow = 0.0;
uniform sampler2D tex_wood : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_block : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_ceil : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex_asph : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_tarmac : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D refl_pan : filter_linear_mipmap, repeat_enable;
uniform float refl_amt = 0.0;
uniform float refl_lod = 3.0;
uniform vec3 refl_tint = vec3(1.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 shirt_col(float h) {
	if (h < 0.28) return team_a;
	if (h < 0.42) return team_b;
	vec3 c = 0.5 + 0.5 * cos(6.2831 * (fract(h * 7.31) + vec3(0.0, 0.33, 0.67)));
	c = h > 0.85 ? vec3(0.9) : h > 0.75 ? vec3(0.08) : c;
	return pow(mix(c, vec3(dot(c, vec3(0.33))), 0.3) * 0.85, vec3(2.2));
}

vec3 skin_col(float h) {
	vec3 c = h < 0.25 ? vec3(0.75, 0.48, 0.3) : h < 0.5 ? vec3(0.55, 0.3, 0.17) : h < 0.75 ? vec3(0.4, 0.22, 0.12) : vec3(0.85, 0.62, 0.45);
	return pow(c, vec3(2.2));
}

// A rounded box's signed distance.
float sd_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// One person, feet at the origin, in metres: torso sd, head sd.
vec3 person(vec2 p, float h, float tall, float aa, vec3 base) {
	float torso = sd_box(p - vec2(0.0, tall * 0.32), vec2(0.19, tall * 0.2), 0.08);
	float head = length(p - vec2(0.0, tall * 0.68)) - 0.115;
	vec3 c = base;
	float hd = fract(h * 13.7);
	c = mix(c, shirt_col(fract(h * 3.3)), smoothstep(aa, -aa, torso));
	vec3 face = skin_col(fract(h * 5.9));
	vec3 hair = hd < 0.5 ? vec3(0.003) : hd < 0.8 ? vec3(0.02, 0.008, 0.003) : vec3(0.2, 0.12, 0.04);
	face = mix(face, hair, step(tall * 0.71 + 0.02 * hd, p.y));
	c = mix(c, face, smoothstep(aa, -aa, head));
	return c;
}

// A stand: rows of seats up the slope, stairs every aisle_every metres with lights at their steps, people in the
// seats from row first on. glow comes back for the aisle lights.
vec3 paint_stand(vec2 uv, float first, out float glow) {
	const float SEAT = 0.55;
	const float ROW = 0.95;
	glow = 0.0;
	float aa = max(fwidth(uv.x), fwidth(uv.y)) * 0.75;
	float row = floor(uv.y / ROW);
	float ly = fract(uv.y / ROW) * ROW;
	vec3 seat = seat_col * (0.8 + 0.35 * smoothstep(0.55, 0.62, ly));
	seat = mix(seat, seat_col * 1.35 + 0.02, smoothstep(0.05 + aa, 0.0, ly));
	float ax = mod(uv.x, aisle_every) - aisle_every * 0.5;
	if (abs(ax) < 0.62) {
		float st = fract(uv.y / ROW * 2.0);
		vec3 c = stair_col * (0.75 + 0.25 * step(0.18, st));
		vec2 lp = vec2(abs(ax) - 0.52, (st - 0.1) * ROW * 0.5);
		glow = smoothstep(0.06 + aa, 0.0, length(lp)) * step(0.5, fract(row * 0.5 + 0.25));
		return mix(c, vec3(1.0, 0.8, 0.45), glow);
	}
	float si = floor(uv.x / SEAT);
	vec3 crowd_avg = mix(seat, vec3(0.08, 0.06, 0.07), density * 0.6);
	float far = smoothstep(0.05, 0.12, aa);
	vec3 c = seat;
	// This row's person, then the one in the row in front, whose head comes up over this row. Seen from the court a
	// slope is foreshortened, so people are drawn taller along it than they are.
	for (int k = 0; k <= 1; k++) {
		float r = row - float(k);
		float h = hash12(vec2(si, r) + 17.0);
		if (r < first || h > density) continue;
		float bob = sin(TIME * 1.3 + h * 40.0) * 0.015 + max(0.0, sin(TIME * 8.0 + h * 60.0)) * excite * 0.14;
		vec2 p = vec2((fract(uv.x / SEAT) - 0.5) * SEAT + (fract(h * 21.0) - 0.5) * 0.08, (ly + float(k) * ROW - 0.06) / 1.5 - bob);
		c = person(p, h, 1.0, aa, c);
	}
	return mix(c, crowd_avg, far);
}

// People standing three deep, painted on an upright face (u along, v up, metres).
vec3 paint_standing(vec2 uv, vec3 base, out float alpha) {
	const float W = 0.6;
	float aa = max(fwidth(uv.x), fwidth(uv.y)) * 0.75;
	alpha = 0.0;
	vec3 c = base;
	for (int k = 2; k >= 0; k--) {
		float off = float(k) * 0.29;
		float si = floor((uv.x + off) / W);
		float h = hash12(vec2(si, float(k)) + 3.0);
		if (h > density) continue;
		float tall = 1.55 + 0.25 * fract(h * 9.1);
		vec2 p = vec2((fract((uv.x + off) / W) - 0.5) * W, uv.y - float(k) * 0.12 - sin(TIME * 1.1 + h * 30.0) * 0.01);
		float legs = sd_box(p - vec2(0.0, tall * 0.2), vec2(0.13, tall * 0.2), 0.03);
		float body = sd_box(p - vec2(0.0, tall * 0.56), vec2(0.18, tall * 0.17), 0.07);
		float head = length(p - vec2(0.0, tall * 0.84)) - 0.11;
		float m = smoothstep(aa, -aa, min(min(legs, body), head));
		vec3 pc = mix(vec3(0.015, 0.015, 0.025), shirt_col(fract(h * 3.3)), smoothstep(aa, -aa, body));
		pc = mix(pc, skin_col(fract(h * 5.9)), smoothstep(aa, -aa, head));
		c = mix(c, pc * (1.0 - float(k) * 0.18), m);
		alpha = max(alpha, m);
	}
	return c;
}

// The lights' reflections in a polished floor, drawn out toward the camera as on a sprung floor under floodlights,
// and the room in it at a low angle.
vec3 floor_sheen(vec3 v, float amt, vec3 cam) {
	vec3 e = night * 2.0 * pow(1.0 - clamp(v.y, 0.0, 1.0), 4.0);
	vec3 to_p = normalize(wpos - cam);
	for (int i = 0; i < 8; i++) {
		if (i >= lamp_count) break;
		vec3 m = vec3(lamp[i].x, -lamp[i].y, lamp[i].z);
		vec3 to_m = normalize(m - cam);
		vec3 f = normalize(vec3(to_m.x, 0.0, to_m.z));
		vec3 d = to_p - to_m;
		float dh = dot(d, vec3(-f.z, 0.0, f.x));
		float dv = d.y;
		e += lamp_col * (exp(-dh * dh * gloss * 9.0 - dv * dv * gloss * 0.35) * 0.9 + exp(-dh * dh * gloss * 0.6 - dv * dv * gloss * 0.04) * 0.08);
	}
	return e * amt;
}

// Where the floodlights fall (0-1): a broad pool over the court, brightest under the three banks of lights down it.
float pool() {
	vec2 p = wpos.xz;
	vec2 e = p / pool_size;
	float broad = exp(-dot(e, e) * 1.4);
	float spots = 0.0;
	for (int i = -1; i <= 1; i++) {
		vec2 d = (p - vec2(float(i) * 10.5, -0.8)) / vec2(5.5, 4.6);
		spots += exp(-dot(d, d));
	}
	return clamp(broad * 0.6 + spots * 0.45, 0.0, 1.0);
}

// The room reflected in a polished face (refl_pan: an equirectangular HDR), at a blur of lod.
vec3 pan(vec3 d, float lod) {
	vec2 uv = vec2(atan(d.x, -d.z) / 6.2832 + 0.5, acos(clamp(d.y, -1.0, 1.0)) / 3.1416);
	return textureLod(refl_pan, uv, lod).rgb;
}

float vignette() {
	float r = length(wpos.xz / vig_size);
	return mix(1.0, vig_dark, smoothstep(0.55, 1.25, r));
}
"""

static var _cache := {}


## The lit material for a venue's structure (one per venue: its uniforms are the venue's).
static func lit() -> ShaderMaterial:
	return _make("lit", """
shader_type spatial;
render_mode vertex_lighting, cull_back, specular_disabled;
""" + COMMON + """
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	int k = int(UV2.x + 0.5);
	vec3 col = COLOR.rgb;
	vec3 emit = vec3(0.0);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	// Along an upright face, in metres: u along it, v up.
	vec2 wuv = vec2(abs(wnrm.x) > abs(wnrm.z) ? -wpos.z * sign(wnrm.x) : wpos.x * sign(wnrm.z), wpos.y);
	if (k == 12) {
		// Block relief, lit from above: the normal map's slope toward the light.
		vec3 n = texture(tex_block, wuv / 2.4).xyz * 2.0 - 1.0;
		col *= 0.9 + 0.32 * dot(n.xy, vec2(-0.25, 0.75)) - 0.12 * (1.0 - n.z);
	} else if (k == 13) {
		col *= texture(tex_ceil, wpos.xz / 2.4).rgb * 1.6;
	} else if (k == 14) {
		vec3 t = texture(tex_wood, vec2(wuv.y, wuv.x) / 2.4).rgb;
		float aa = fwidth(wuv.x) * 1.5;
		float groove = smoothstep(aa + 0.006, 0.0, abs(fract(wuv.x / 0.095) - 0.5) * 0.095 - 0.04);
		col *= t * 1.1 * (1.0 - groove * 0.45 * (1.0 - smoothstep(0.01, 0.04, aa)));
	} else if (k == 16) {
		col *= texture(tex_tarmac, wpos.xz / 3.0).rgb * 1.8;
	} else if (k == 17) {
		float stripe = step(0.5, fract(wpos.x / 6.0));
		float g = dot(texture(tex_tarmac, wpos.xz / 1.3).rgb, vec3(0.33));
		col *= (0.92 + 0.12 * stripe) * (0.75 + g * 0.7);
	}
	if (k == 1 || k == 2 || k == 8 || k == 11 || k == 15 || k == 16 || k == 17 || k == 18) {
		if (k == 11) {
			col *= texture(tex_wood, wpos.xz / 2.4).rgb;
		} else if (k == 18) {
			// The grain shows through the paint: the veneer's light and dark, not its colour.
			col *= 1.0 + (dot(texture(tex_wood, wpos.xz / 2.4).rgb, vec3(0.33)) - 0.84) * 7.0;
		} else if (k == 15) {
			float g = dot(texture(tex_asph, wpos.xz / 2.0).rgb, vec3(0.33));
			col *= 0.82 + g * 0.45;
		}
		if (k == 2) {
			float aa = fwidth(wpos.z) * 1.5;
			float board = floor(wpos.z / 0.11);
			float bh = hash12(vec2(board, floor((wpos.x + board * 1.7) / 2.4)));
			float seam = smoothstep(aa + 0.004, 0.0, abs(fract(wpos.z / 0.11) - 0.5) * 0.11 - 0.05);
			float grain = sin(wpos.x * 9.0 + bh * 20.0 + sin(wpos.x * 1.3) * 3.0) * 0.5 + 0.5;
			float detail = 1.0 - smoothstep(0.01, 0.05, aa);
			col *= 1.0 + ((bh - 0.5) * 0.16 + grain * 0.05 - seam * 0.12) * detail;
		} else if (k == 8) {
			float aa = fwidth(wpos.x) * 2.0;
			float sp = hash12(floor(wpos.xz * 30.0));
			col *= 1.0 + (sp - 0.5) * 0.25 * (1.0 - smoothstep(0.01, 0.05, aa));
		}
		float pl = pool();
		col *= mix(pool_lo, pool_hi, pl) * vignette();
		emit += COLOR.rgb * pl * pl * pool_glow + lamp_col * pow(pl, 3.0) * pool_glow * 0.06;
		float sh = k == 8 || k == 15 ? 0.25 : (k == 16 || k == 17 ? 0.0 : 1.0);
		emit += floor_sheen(v, sheen * sh, CAMERA_POSITION_WORLD) * mix(1.0, 0.6, 1.0 - vignette());
		if (k == 11 && refl_amt > 0.0) {
			float fr = 0.03 + 0.97 * pow(1.0 - clamp(v.y, 0.0, 1.0), 5.0);
			emit += pan(reflect(-v, vec3(0.0, 1.0, 0.0)), refl_lod) * refl_tint * fr * refl_amt;
		}
	} else if (k == 3) {
		// The stands are in the dark beyond the floodlights: painted as they look (stand_tint), not lit again.
		float g;
		emit += paint_stand(UV, UV2.y, g) * stand_tint + vec3(1.0, 0.75, 0.4) * g * 1.6;
		col = vec3(0.0);
	} else if (k == 9) {
		float a;
		col = paint_standing(UV, col, a);
		if (a < 0.5) discard;
	} else if (k == 4 || k == 5) {
		float f = clamp(dot(NORMAL, vec3(0.0, 0.0, 1.0)), 0.0, 1.0);
		float hl = pow(clamp(dot(NORMAL, normalize(vec3(-0.45, 0.5, 0.75))), 0.0, 1.0), k == 4 ? 18.0 : 40.0);
		col *= 0.55 + 0.45 * f;
		emit += vec3(1.0) * hl * (k == 4 ? 0.55 : 0.8) + col * 0.15;
	}
	float fade = smoothstep(fade_y0, fade_y1, wpos.y) * fade_amt;
	ALBEDO = mix(col, night, fade);
	EMISSION = emit * (1.0 - fade);
}
""")


## The material for what glows: lines, light strips, boards, the net (unshaded, a draw call of its own).
static func glow() -> ShaderMaterial:
	return _make("glow", """
shader_type spatial;
render_mode unshaded, cull_disabled;
""" + COMMON + """
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	int k = int(UV2.x + 0.5);
	vec3 col = COLOR.rgb;
	float bright = 1.0 + (k == 6 || k == 10 ? 0.0 : UV2.y);
	if (k == 6) {
		// Diamonds of cord: two families of diagonals, a knot where they cross.
		float a = UV.x + UV.y * 0.5;
		float b = UV.x - UV.y * 0.5;
		float aa = max(fwidth(a), fwidth(b));
		float w = 0.07 + aa * 0.6;
		float da = abs(fract(a) - 0.5) * 2.0;
		float db = abs(fract(b) - 0.5) * 2.0;
		float cord = max(step(1.0 - w, da), step(1.0 - w, db));
		float knot = step(length(vec2(1.0 - da, 1.0 - db)), 0.2 + aa);
		float rim = step(UV.y, 0.06 + aa);
		if (max(max(cord, knot), rim) < 0.5) discard;
		col *= 0.82 + 0.18 * (1.0 - UV.y / 3.0) + knot * 0.1;
		col *= FRONT_FACING ? 1.0 : 0.7;
	} else if (k == 7) {
		float s = 0.5 + 0.5 * sin(wpos.x * 0.35 + wpos.z * 0.35 - TIME * 1.6);
		col *= 0.75 + 0.45 * s;
	} else if (k == 10) {
		vec2 p = UV / 0.09;
		float a = abs(fract(p.x + p.y) - 0.5);
		float b = abs(fract(p.x - p.y) - 0.5);
		float aa = max(fwidth(p.x), fwidth(p.y));
		if (aa > 0.2) {
			// Too fine to draw: every other pixel, so it still reads as wire you see through.
			if (mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0) < 1.0) discard;
			col *= 0.55;
		} else if (min(a, b) > 0.08 + aa * 0.5) {
			discard;
		}
	}
	float fade = smoothstep(fade_y0, fade_y1, wpos.y) * fade_amt * 0.6;
	ALBEDO = mix(col * bright, night, fade);
}
""")


## The lights, added to what is behind them and drawn last: soft glowing sprites that face the camera with a faint
## horizontal streak; glows in the air round lights (Geo.sprite with streak -1); beams down from them (Geo.beam).
static func flare() -> ShaderMaterial:
	return _make("flare", """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform float intensity = 1.0;
uniform float halo = 1.0;
varying vec2 q;
varying float streak;
varying float twinkle;
void vertex() {
	vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 c = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	streak = UV2.y;
	vec3 w;
	if (streak < -1.5) {
		// A beam: a strip down its axis (NORMAL), turned about it to face the camera, wider at its foot.
		vec3 axis = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 side = normalize(cross(axis, c - INV_VIEW_MATRIX[3].xyz));
		w = c + side * (UV.x - 0.5) * UV2.x * mix(0.35, 1.0, UV.y);
		q = vec2(UV.x * 2.0 - 1.0, UV.y);
	} else {
		q = (UV - 0.5) * 2.0;
		float s = UV2.x;
		float wide = 1.0 + max(streak, 0.0) * 2.5;
		w = c + right * q.x * s * wide + up * q.y * s;
		q.x *= wide;
	}
	twinkle = COLOR.a > 0.01 ? 0.55 + 0.45 * sin(TIME * (2.0 + COLOR.a * 5.0) + COLOR.a * 40.0) : 1.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}
void fragment() {
	float k;
	if (streak < -1.5) {
		float a = 1.0 - q.x * q.x;
		k = a * a * (1.0 - q.y * 0.75) * smoothstep(0.0, 0.08, q.y);
	} else if (streak < -0.5) {
		// A glow in the air round a light (no lamp in it).
		float d = length(q);
		k = exp(-d * d * 3.5) * smoothstep(1.0, 0.7, d);
	} else {
		float d = length(q);
		float core = smoothstep(0.32, 0.12, d);
		float glow = exp(-d * d * 5.0) * 0.55 * halo;
		float st = exp(-abs(q.y) * 22.0) * exp(-abs(q.x) * 0.9) * streak * 0.5 * halo;
		k = core * 1.6 + glow + st;
	}
	ALBEDO = COLOR.rgb * k * intensity * twinkle;
	ALPHA = 1.0;
}
""")


## The props' material (VenueProps): models from one atlas, cut-outs (kind 1 in UV2.x) from a second with their alpha
## cut at 0.4, metal (kind 2) a little shiny; UV2.y makes a surface glow (a lamp's diffuser). Lit per vertex on Low.
static func props(low: bool) -> ShaderMaterial:
	return _make("props_low" if low else "props", """
shader_type spatial;
render_mode cull_disabled%s;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D cards : source_color, filter_linear_mipmap, repeat_disable, hint_default_transparent;
uniform vec3 night : source_color = vec3(0.03, 0.06, 0.16);
uniform float fade_y0 = 5.0;
uniform float fade_y1 = 15.0;
uniform float fade_amt = 0.0;
uniform float props_bright = 1.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	int k = int(UV2.x + 0.5);
	vec4 t = k == 1 ? texture(cards, UV) : vec4(texture(atlas, UV).rgb, 1.0);
	if (t.a < 0.4) discard;
	vec3 c = t.rgb * COLOR.rgb * props_bright;
	float fade = smoothstep(fade_y0, fade_y1, wpos.y) * fade_amt;
	ALBEDO = mix(c, night, fade);
	ROUGHNESS = k == 2 ? 0.45 : 0.8;
	METALLIC = k == 2 ? 0.6 : 0.0;
	SPECULAR = 0.3;
	EMISSION = t.rgb * COLOR.rgb * UV2.y * (1.0 - fade);
}
""" % (", vertex_lighting" if low else ""))


## Glass (a basketball backboard): faintly tinted, clearer face on, the room reflected at a glancing angle.
static func glass() -> ShaderMaterial:
	return _make("glass", """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D refl_pan : filter_linear_mipmap, repeat_enable;
uniform float refl_amt = 0.0;
uniform vec3 glass_col : source_color = vec3(0.75, 0.85, 0.85);
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 n = dot(wnrm, v) < 0.0 ? -wnrm : wnrm;
	float fr = 0.08 + 0.92 * pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 4.0);
	vec3 d = reflect(-v, n);
	vec2 uv = vec2(atan(d.x, -d.z) / 6.2832 + 0.5, acos(clamp(d.y, -1.0, 1.0)) / 3.1416);
	vec3 r = mix(glass_col * 0.9, textureLod(refl_pan, uv, 1.5).rgb, refl_amt);
	// A sheen across the glass, as a board catches the lights.
	float streak = smoothstep(0.35, 0.0, abs(fract(wpos.y * 0.9 + (wpos.x + wpos.z) * 0.35) - 0.5)) * 0.25;
	ALBEDO = r * (0.6 + streak) + glass_col * 0.1;
	ALPHA = clamp(0.16 + fr * 0.6 + streak * 0.3, 0.0, 0.85);
}
""")


## A photographed sky: bg (an equirectangular panorama, tone-mapped) as the background, and on Medium and High the
## HDR (hdr) for the light the sky casts and its reflections (the radiance pass). yaw turns it (radians).
static func sky() -> ShaderMaterial:
	return _make("sky", """
shader_type sky;
uniform sampler2D bg : source_color, filter_linear, repeat_enable;
uniform sampler2D hdr : filter_linear, repeat_enable;
uniform bool use_hdr = false;
uniform float bg_energy = 1.0;
uniform float hdr_energy = 1.0;
uniform float yaw = 0.0;
void sky() {
	vec3 d = EYEDIR;
	float c = cos(yaw);
	float s = sin(yaw);
	d = vec3(c * d.x - s * d.z, d.y, s * d.x + c * d.z);
	vec2 uv = vec2(atan(d.x, -d.z) / 6.2832 + 0.5, acos(clamp(d.y, -1.0, 1.0)) / 3.1416);
	if (AT_CUBEMAP_PASS && use_hdr) {
		COLOR = texture(hdr, uv).rgb * hdr_energy;
	} else {
		COLOR = texture(bg, uv).rgb * bg_energy;
	}
}
""")


static func _make(name: String, code: String) -> ShaderMaterial:
	if not _cache.has(name):
		var sh := Shader.new()
		sh.code = code
		_cache[name] = sh
	var m := ShaderMaterial.new()
	m.shader = _cache[name]
	return m
