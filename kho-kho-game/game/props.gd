class_name Props
extends RefCounted
## The shared assets the lead prepared for the six games (assets/env/, from the shared-assets branch: Poly Haven,
## CC0, and the owner's Meshy models), placed round a ground. Each kind of thing is one MultiMeshInstance3D however
## many there are of it, so forty chairs are one draw call. Low graphics takes the `_low` meshes, and the cut-outs
## for trees; Medium and High the full ones. Their materials are set as the brief says: rough, not metallic, and on
## Low lit per vertex.

const ENV := "res://assets/env/"

static var _meshes := {}
## The cut-outs' light (their pictures carry their own shading): the place's light falling on them, set per ground.
static var card_light := Color(1, 1, 1)


## The mesh of a model (its first), materials adjusted, cached. path is under assets/env/, without ".glb".
static func mesh(path: String) -> Mesh:
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	var key := path + ("|low" if low else "") + ("|" + card_light.to_html() if path.ends_with("_card") else "")
	if _meshes.has(key):
		return _meshes[key]
	var ps: PackedScene = load(ENV + path + ".glb")
	var root: Node = ps.instantiate()
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	var m: Mesh = mi.mesh.duplicate()
	for s in m.get_surface_count():
		var mat := m.surface_get_material(s)
		if mat is BaseMaterial3D:
			var b := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			b.metallic = 0.0
			b.roughness = 0.85
			b.metallic_specular = 0.2
			if low:
				b.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
				b.normal_enabled = false
			if String(b.resource_name).contains("glass") or (path.contains("fluorescent") and s == 1):
				# A lamp's diffuser: lit from inside.
				b.emission_enabled = true
				b.emission = Color(1.0, 0.98, 0.92)
				b.emission_energy_multiplier = 2.0
			if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				b.alpha_scissor_threshold = 0.4
				b.cull_mode = BaseMaterial3D.CULL_DISABLED
				b.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				b.albedo_color = card_light
			m.surface_set_material(s, b)
	root.free()
	_meshes[key] = m
	return m


## Many of one thing: the full model or, on Low, its `_low` copy (when there is one).
static func place(parent: Node, path: String, xforms: Array, has_low := true) -> MultiMeshInstance3D:
	if xforms.is_empty():
		return null
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh(path + ("_low" if low and has_low else ""))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


## A transform: at p, turned by yaw, scaled by s.
static func at(p: Vector3, yaw := 0.0, s := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), p)


## A tileable photo-scanned surface's colour texture (its normal map is left out: see docs/PROGRESS.md, round four):
## the 1k photo on Low; on Medium and High the 2k where there is one (VRAM-compressed). Only the grounds have a 2k: the
## field is under the camera, where its finest detail shows; the walls and roofs stand far off, where the 1k's own
## smaller mip levels are what is drawn anyway.
static func surface(name: String) -> Array:
	var hd := ENV + "surfaces/%s/%s_albedo_2k.jpg" % [name, name]
	if int(Game.settings.graphics) > Game.GFX_LOW and ResourceLoader.exists(hd):
		return [load(hd)]
	return [load(ENV + "surfaces/%s/%s_albedo_1k.jpg" % [name, name])]


## The material for the code-built structure's walls and roofs: a surface's texture laid on from the world
## (from above on floors and roofs, from the side on walls, so no UVs are needed), tinted by the vertex colour.
static func textured(name: String, tile_m := 2.5, tint := 1.0) -> ShaderMaterial:
	var t := surface(name)
	var low := int(Game.settings.graphics) == Game.GFX_LOW
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode %s specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tile = 2.5;
uniform float tint = 1.0;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 n = abs(wnrm);
	vec2 uv = n.y > 0.7 ? wpos.xz : (n.x > n.z ? wpos.zy : wpos.xy);
	vec3 t = texture(albedo_tex, uv / tile).rgb;
	// The photo's colour, carried by the part's own colour (lighter parts lighter): grey-ish parts take the photo
	// as it is, coloured parts tint it.
	ALBEDO = t * COLOR.rgb * tint * 1.6;
	ROUGHNESS = 0.9;
}
""" % ("vertex_lighting," if low else "")
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("albedo_tex", t[0])
	m.set_shader_parameter("tile", tile_m)
	m.set_shader_parameter("tint", tint)
	return m
