// The game's colours were chosen under the GL Compatibility renderer, which draws them as they are written. The
// Mobile (Vulkan) renderer, the game's own since 0.11, works in linear light and encodes for the screen at the end,
// so a colour reaching ALBEDO is decoded first: the same colour on screen. The game's shaders read their textures and
// colour uniforms without the source_color hint, so as written on both renderers and every GPU (the renderer's own
// decoding of a GPU-compressed texture was found to differ from that of an uncompressed one); this, at the end, is
// the one conversion. Under GL Compatibility (the fallback for phones without a working Vulkan) it does nothing.
vec3 compat_to_scene(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return c;
#else
	vec3 cc = max(c, vec3(0.0));
	return mix(pow((cc + vec3(0.055)) / vec3(1.055), vec3(2.4)), cc / 12.92, lessThan(cc, vec3(0.04045)));
#endif
}
