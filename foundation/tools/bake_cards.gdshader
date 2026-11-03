// tools/bake_cards.gd: a fan drawn for the Low crowd's cards. mode 0: their colours, lit as the 3D crowd lights its
// fans (a cel light from the front and above, as written by crowd_vat.gdshader before the screen's encoding); mode 1:
// what each pixel is, each its own share (blended across the low-poly figure's triangles as the 3D fans' colours
// are): R the shirt, G skin, B hair, A the legs' clothes (bake_crowd.gd REGIONS).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform int mode = 0;
varying vec3 wn;
varying vec4 parts;

void vertex() {
	wn = NORMAL;
	float part = floor(UV.y * 4.0 + 0.5);
	parts = vec4(smoothstep(0.2, 0.55, COLOR.a), part == 1.0 ? 1.0 : 0.0, part == 2.0 ? 1.0 : 0.0, part == 3.0 ? 1.0 : 0.0);
}

void fragment() {
	if (mode == 0) {
		float k = mix(0.72, 1.0, smoothstep(-0.35, 0.3, dot(normalize(wn), normalize(vec3(0.3, 0.8, 0.6)))));
		vec3 c = min(COLOR.rgb, vec3(0.9)) * k;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		ALBEDO = c;
#else
		ALBEDO = mix(pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
#endif
	} else if (mode == 1) {
		ALBEDO = parts.rgb;
	} else {
		ALBEDO = vec3(parts.a, 0.0, 0.0);
	}
}
