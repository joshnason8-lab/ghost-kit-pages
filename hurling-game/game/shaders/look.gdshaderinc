// The game's colours were chosen under the GL Compatibility renderer, which draws them as they are written. Ultra's
// Mobile (Vulkan) renderer works in linear light and encodes for the screen at the end, so there they are decoded
// first: the same colours on screen. Under GL Compatibility (Low, Medium, High) this returns them untouched.
vec3 compat_to_scene(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	vec3 cc = max(c, vec3(0.0));
	return mix(pow((cc + vec3(0.055)) / vec3(1.055), vec3(2.4)), cc / 12.92, lessThan(cc, vec3(0.04045)));
#endif
}
