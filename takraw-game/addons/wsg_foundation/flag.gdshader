// A flag flying (WsgFlags): the cloth rippling away from the pole - nothing at the pole, most at the free end - in
// waves that run out along it, each flag its own phase; faster and bigger as the crowd's excitement rises. Two
// colours (COLOR above, INSTANCE_CUSTOM.rgb below), lit as the games light their people and written as their
// cut-outs are.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec2 cloth = vec2(2.0, 1.3);
uniform float excite = 0.0;
uniform float light = 1.0;
uniform vec3 sun_dir = vec3(0.35, 0.85, 0.4);
varying vec3 top_col;
varying vec3 low_col;
varying float v_y;
varying vec3 wn;

void vertex() {
	float x = VERTEX.x / cloth.x;                    // 0 at the pole, 1 at the free end
	float ph = INSTANCE_CUSTOM.a * 6.2831;
	float speed = 4.0 + 7.0 * excite;
	float amp = (0.07 + 0.16 * excite) * x * cloth.x / 1.25;
	float w = sin(x * 7.0 - TIME * speed + ph) + 0.4 * sin(x * 13.0 - TIME * speed * 1.7 + ph * 2.0);
	VERTEX.z += w * amp;
	VERTEX.y -= x * x * 0.18 * (1.0 - excite);       // the free end droops a little when it is calm
	float dz = cos(x * 7.0 - TIME * speed + ph) * 7.0 * amp / cloth.x;
	vec3 n = normalize(vec3(-dz, 0.0, 1.0));
	wn = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	top_col = COLOR.rgb;
	low_col = INSTANCE_CUSTOM.rgb;
	v_y = VERTEX.y;
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
	vec3 c = v_y > -cloth.y * 0.5 ? top_col : low_col;
	float d = abs(dot(normalize(wn), normalize(sun_dir)));    // (both faces of a flag catch the light)
	float k = mix(0.7, 1.0, smoothstep(0.0, 0.6, d));
	ALBEDO = as_written(pow(max(c, vec3(0.0)), vec3(2.2)) * k * light);
}
