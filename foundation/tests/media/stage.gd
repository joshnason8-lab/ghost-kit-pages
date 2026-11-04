class_name WsgStage
extends RefCounted
## A plain stage for looking at bodies: a grass-green floor with a metre grid (gliding feet show against it), a sun,
## a sky colour. Used by the videos and stills.

static func build(parent: Node, size := 60.0) -> void:
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	floor.mesh = pm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode diffuse_lambert;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = abs(fract(wp.xz + 0.5) - 0.5) / fwidth(wp.xz);
	float line = 1.0 - min(min(g.x, g.y), 1.0);
	vec3 grass = mix(vec3(0.20, 0.36, 0.17), vec3(0.24, 0.42, 0.20), step(0.5, fract(wp.z * 0.25)));
	ALBEDO = mix(grass, vec3(0.85), line * 0.55);
	ROUGHNESS = 0.95;
}"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	floor.material_override = mat
	parent.add_child(floor)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	parent.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.68, 0.82)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.55)
	parent.add_child(env)


static func hero_material(albedo_path: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if albedo_path != "" and FileAccess.file_exists(albedo_path):
		mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(albedo_path))
	mat.roughness = 0.8
	return mat
