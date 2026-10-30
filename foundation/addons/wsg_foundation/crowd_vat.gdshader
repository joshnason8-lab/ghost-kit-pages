// The 3D crowd: every fan an instance of one low-poly figure, animated from vertex-animation textures baked through
// the rig (tools/bake_crowd.gd). Everything a fan does is worked out here, from the instance's own random numbers and
// a few shared values the crowd sets each frame, so a stand of thousands costs the CPU nothing:
//   seated fans get up as the excitement passes their own threshold (the sit-to-stand clip, by how far up they are)
//   and sit back down as it falls; the keener ones clap or cheer (arms up, waving) as it builds;
//   claps fall on the clapping sound's beat (clap_time, clap_rate), each fan a little off it unless the sound is in
//   unison (clap_sync);
//   heads and shoulders turn to the ball (smoothed by the crowd), each fan a little their own way;
//   shirts take a team's colours.
// Works on the Compatibility (GLES3) and Mobile (Vulkan) renderers.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D vat_pos : filter_nearest, repeat_disable;
uniform sampler2D vat_nrm : filter_nearest, repeat_disable;
uniform int vertices;               // columns before the pivots (torso, head)
uniform float fps = 15.0;
// Each clip: row, frames, length (s), loop (1/0).
uniform vec4 clip_sit_idle;
uniform vec4 clip_sit_clap;
uniform vec4 clip_sit_to_stand;
uniform vec4 clip_stand_idle;
uniform vec4 clip_stand_clap;
uniform vec4 clip_cheer;
uniform float excite = 0.0;          // 0..1, eased by the crowd
uniform float clap_time = 0.0;       // s on the clapping sound's clock
uniform float clap_rate = 2.4;       // claps a second
uniform float clap_sync = 0.6;       // 1: all on the beat
uniform vec3 ball = vec3(0.0);       // what they watch (world), smoothed
uniform float watch = 1.0;           // how much they turn to it
uniform vec4 team_a : source_color = vec4(0.1, 0.45, 0.2, 1.0);
uniform vec4 team_b : source_color = vec4(0.8, 0.15, 0.1, 1.0);
uniform float light = 1.0;           // the ground's light (night, shade)

varying vec3 colour;

float hash(float n) {
	return fract(sin(n * 12.9898 + 4.1414) * 43758.5453);
}

vec3 texel(sampler2D t, int col, float row) {
	return texelFetch(t, ivec2(col, int(row)), 0).xyz;
}

// A clip at time s: [position, normal] for this vertex (column), frames eased between.
void clip_at(vec4 clip, float s, int col, out vec3 p, out vec3 n) {
	float f = s * fps;
	float frames = clip.y;
	if (clip.w > 0.5) {
		f = mod(f, frames);
	} else {
		f = clamp(f, 0.0, frames - 1.0);
	}
	float f0 = floor(f);
	float f1 = clip.w > 0.5 ? mod(f0 + 1.0, frames) : min(f0 + 1.0, frames - 1.0);
	float w = f - f0;
	p = mix(texel(vat_pos, col, clip.x + f0), texel(vat_pos, col, clip.x + f1), w);
	n = mix(texel(vat_nrm, col, clip.x + f0), texel(vat_nrm, col, clip.x + f1), w) * 2.0 - 1.0;
}

vec3 turn_y(vec3 v, vec3 pivot, float a) {
	vec3 d = v - pivot;
	float c = cos(a);
	float s = sin(a);
	return pivot + vec3(d.x * c + d.z * s, d.y, -d.x * s + d.z * c);
}

void vertex() {
	int col = int(UV.x * float(vertices + 2));
	float id = float(INSTANCE_ID) + INSTANCE_CUSTOM.r * 1000.0;
	float r1 = hash(id * 1.31);
	float r2 = hash(id * 2.17);
	float r3 = hash(id * 3.71);
	float r4 = hash(id * 5.13);
	float r5 = hash(id * 7.77);
	float r6 = hash(id * 9.91);
	float r7 = hash(id * 11.3);
	// How far up this fan is: each gets up at their own point of the excitement.
	float thr = mix(0.32, 0.86, r1);
	// INSTANCE_CUSTOM.g: 1 on a seat (gets up), 0 on a terrace (always standing).
	float up = INSTANCE_CUSTOM.g > 0.5 ? smoothstep(thr, thr + 0.14, excite) : 1.0;
	// How much they clap or cheer.
	float keen = smoothstep(0.12 + 0.4 * r2, 0.3 + 0.4 * r2, excite);
	float t_idle = TIME * (0.85 + 0.3 * r3) + r3 * 20.0;
	float beat = clap_time * clap_rate + (1.0 - clap_sync) * r4;
	float t_clap = fract(beat) * clip_sit_clap.z;
	float t_cheer = TIME * (0.8 + 0.5 * r5) + r5 * 3.0;
	vec3 p0; vec3 n0; vec3 p1; vec3 n1;
	vec3 piv_t; vec3 piv_h; vec3 q;
	if (up <= 0.001) {
		clip_at(clip_sit_idle, t_idle, col, p0, n0);
		clip_at(clip_sit_clap, t_clap, col, p1, n1);
		clip_at(clip_sit_idle, t_idle, vertices, piv_t, q);
		clip_at(clip_sit_idle, t_idle, vertices + 1, piv_h, q);
	} else if (up >= 0.999) {
		clip_at(clip_stand_idle, t_idle, col, p0, n0);
		if (r6 < 0.55) {
			clip_at(clip_cheer, t_cheer, col, p1, n1);
		} else {
			clip_at(clip_stand_clap, t_clap, col, p1, n1);
		}
		clip_at(clip_stand_idle, t_idle, vertices, piv_t, q);
		clip_at(clip_stand_idle, t_idle, vertices + 1, piv_h, q);
	} else {
		float s = up * clip_sit_to_stand.z;
		clip_at(clip_sit_to_stand, s, col, p0, n0);
		p1 = p0;
		n1 = n0;
		clip_at(clip_sit_to_stand, s, vertices, piv_t, q);
		clip_at(clip_sit_to_stand, s, vertices + 1, piv_h, q);
		keen = 0.0;
	}
	vec3 p = mix(p0, p1, keen);
	vec3 n = normalize(mix(n0, n1, keen));
	// Watching the ball: the angle to it in the fan's own frame, a little each their own way; the shoulders take
	// up to 30 degrees of it, the head the rest (up to 75 in all).
	vec3 d = ball - MODEL_MATRIX[3].xyz;
	vec3 ax = MODEL_MATRIX[0].xyz;
	vec3 az = MODEL_MATRIX[2].xyz;
	float yaw = atan(dot(d, ax) / dot(ax, ax), dot(d, az) / dot(az, az));
	yaw = clamp(yaw + (r7 - 0.5) * 0.35, -1.3, 1.3) * watch * (0.6 + 0.4 * excite);
	float torso = clamp(yaw, -0.52, 0.52);
	float head = yaw - torso;
	p = turn_y(p, piv_t, torso * UV2.x);
	n = turn_y(n, vec3(0.0), torso * UV2.x);
	piv_h = turn_y(piv_h, piv_t, torso);
	p = turn_y(p, piv_h, head * UV2.y);
	n = turn_y(n, vec3(0.0), head * UV2.y);
	VERTEX = p;
	NORMAL = n;
	// Colours: shirts in a team's colours (most fans), a little variety in everything else.
	vec3 team = r3 < 0.5 ? team_a.rgb : team_b.rgb;
	float wear = r4 < 0.8 ? COLOR.a * 0.85 : 0.0;
	vec3 base = COLOR.rgb * (0.85 + 0.3 * r2);
	colour = mix(base, team * (0.55 + 0.45 * dot(COLOR.rgb, vec3(0.33))) * 1.6, wear);
}

void fragment() {
	ALBEDO = colour * light;
	ROUGHNESS = 0.9;
}
