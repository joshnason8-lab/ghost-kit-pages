class_name Scenery
extends Node3D
## The real-world pieces round a ground (the shared assets: Poly Haven's scans and the owner's models, in
## assets/env/models): trees and hedgerow plants as cut-outs (two crossed planes, 4 triangles each), the village's
## cottages and terraced rows, benches, street lamps, mossy rocks. Every kind is placed with one MultiMeshInstance3D,
## so forty trees cost one draw call. Cut-outs are drawn unlit in the time of day's light (as the players and the
## grass are); buildings and props are lit by the sun (per vertex on Low).

const DIR := "res://assets/env/models/"
const CARDS := ["oak_tree_card", "broadleaf_tree_dark_card", "small_broadleaf_card", "fern_card", "grass_clumps_card",
	"grass_wispy_card"]

static var _meshes := {}      # name -> [Mesh, Transform3D (the mesh's own place in its file)]
static var _mats := {}        # name|time|graphics -> Material

var time := "day"
var _xf := {}                 # name -> Array[Transform3D]


func _init(p_time := "day") -> void:
	time = p_time


## Puts a name (a file in assets/env/models, without .glb) at p, turned yaw radians, scaled s, tipped forward tilt
## radians (a floodlight aimed down at the field).
func add(name: String, p: Vector3, yaw := 0.0, s := 1.0, tilt := 0.0) -> void:
	if not _xf.has(name):
		_xf[name] = []
	_xf[name].append(Transform3D((Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)).scaled(Vector3.ONE * s), p))


## How many of each are placed (tests and the perf notes).
func count(name: String) -> int:
	return _xf.get(name, []).size()


func names() -> Array:
	return _xf.keys()


## Where each of a kind was placed.
func placed(name: String) -> Array:
	return _xf.get(name, [])


## Facing the point to (the model's front is +Z).
static func facing(p: Vector3, to := Vector3.ZERO) -> float:
	return atan2(to.x - p.x, to.z - p.z)


## Builds one MultiMeshInstance3D a kind.
func commit() -> void:
	for name in _xf:
		var m := mesh_of(name)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m[0]
		var xs: Array = _xf[name]
		mm.instance_count = xs.size()
		var own: Transform3D = m[1]
		var aabb := AABB()
		for i in xs.size():
			var t: Transform3D = (xs[i] as Transform3D) * own
			mm.set_instance_transform(i, t)
			var b := t * (m[0] as Mesh).get_aabb()
			aabb = b if i == 0 else aabb.merge(b)
		var mi := MultiMeshInstance3D.new()
		mi.name = name
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = _material(name, m[0])
		mi.custom_aabb = aabb
		add_child(mi)


## The mesh in a model file, and where the file puts it.
static func mesh_of(name: String) -> Array:
	if not _meshes.has(name):
		var n: Node = load(DIR + name + ".glb").instantiate()
		var mi: MeshInstance3D = n.find_children("*", "MeshInstance3D", true, false)[0]
		var t := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != n:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		_meshes[name] = [mi.mesh, t]
		n.free()
	return _meshes[name]


## The model's own material, made fit for the time of day and the graphics level: a cut-out unlit and tinted by the
## time of day's light, alpha-scissored, both sides; a building or prop lit by the sun (per vertex on Low).
func _material(name: String, mesh: Mesh) -> Material:
	var g := int(Game.settings.graphics)
	var key := "%s|%s|%d" % [name, time, g]
	if _mats.has(key):
		return _mats[key]
	if name == "floodlight":
		_mats[key] = _floodlight(mesh.surface_get_material(0))
		return _mats[key]
	var src := mesh.surface_get_material(0)
	var m: StandardMaterial3D = src.duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
	if name in CARDS:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = light(time)
	else:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX if g == Game.GFX_LOW else BaseMaterial3D.SHADING_MODE_PER_PIXEL
		m.roughness = 0.85
		m.metallic = 0.6 if name.begins_with("street_lamp") else 0.0
		# Lit by the sun and the sky both, a white-plastered house would glare: toned to sit with the stands.
		m.albedo_color = {"day": Color(0.78, 0.78, 0.78), "dusk": Color(0.72, 0.68, 0.66), "night": Color(0.3, 0.32, 0.36)}.get(time, Color.WHITE)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats[key] = m
	return m


## The floodlights (a Meshy model: sixteen lamps in a steel frame): the frame in the time of day's light, the lamps'
## glass lit, warm white, from dusk on.
func _floodlight(src: Material) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://game/shaders/look.gdshaderinc"
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 light = vec3(1.0);
uniform float on = 0.0;
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float glass = smoothstep(0.55, 0.75, dot(c, vec3(0.2126, 0.7152, 0.0722)));
	ALBEDO = compat_to_scene(mix(c * light, vec3(1.0, 0.97, 0.86), glass * on));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tex", (src as BaseMaterial3D).albedo_texture if src is BaseMaterial3D else null)
	var l := light(time)
	m.set_shader_parameter("light", Vector3(l.r, l.g, l.b))
	m.set_shader_parameter("on", 0.0 if time == "day" else 1.0)
	return m


## The light an unlit thing is drawn in at each time of day (the grass and the players are drawn the same way).
static func light(t: String) -> Color:
	return {"day": Color(0.92, 0.94, 0.9), "dusk": Color(0.78, 0.68, 0.62), "night": Color(0.34, 0.38, 0.44)}.get(t, Color.WHITE)
