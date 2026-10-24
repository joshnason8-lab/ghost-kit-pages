class_name Scenery
extends Node3D
## The real-world pieces round a court (the shared assets: Poly Haven's scans and the owner's models, in
## assets/env/models): trees and plants as cut-outs (two crossed planes, 4 triangles each) - the rain tree (the
## parota and guanacaste of the Mexican lowlands are its kin), coconut palms, tropical broadleaves for the Yucatán
## forest, tall dry grass and boulders for the Sinaloa scrub - and the agave, built here. Every kind is placed with one MultiMeshInstance3D,
## so forty trees cost one draw call. Cut-outs are drawn unlit in the time of day's light (as the players and the
## grass are); buildings and props are lit by the sun (per vertex on Low).

const DIR := "res://assets/env/models/"
const CARDS := ["rain_tree_card", "coconut_palm_card", "island_tree_a_card", "island_tree_b_card", "dry_grass_tall_card",
	"grass_clumps_card"]

static var _meshes := {}      # name -> [Mesh, Transform3D (the mesh's own place in its file)]
static var _mats := {}        # name|time|graphics -> Material

var time := "day"
var _xf := {}                 # name -> Array[Transform3D]


func _init(p_time := "day") -> void:
	time = p_time


## Puts a name (a file in assets/env/models, without .glb) at p, turned yaw radians, scaled s.
func add(name: String, p: Vector3, yaw := 0.0, s := 1.0) -> void:
	if not _xf.has(name):
		_xf[name] = []
	_xf[name].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), p))


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
		if name == "agave":
			_meshes[name] = [agave_mesh(), Transform3D.IDENTITY]
			return _meshes[name]
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
		m.metallic = 0.0
		# Lit by the sun and the sky both, a white-plastered house would glare: toned to sit with the stands.
		m.albedo_color = {"day": Color(0.85, 0.85, 0.85), "dusk": Color(0.78, 0.72, 0.68), "night": Color(0.34, 0.34, 0.4)}.get(time, Color.WHITE)
		if name == "agave":
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats[key] = m
	return m


## The light an unlit thing is drawn in at each time of day (the grass and the players are drawn the same way).
static func light(t: String) -> Color:
	return {"day": Color(0.92, 0.94, 0.9), "dusk": Color(0.8, 0.68, 0.6), "night": Color(0.3, 0.33, 0.4)}.get(t, Color.WHITE)


## The agave of the Sinaloa scrub: a rosette of stiff blue-grey leaves, each a tapered, folded blade, about 1.2 m
## across (84 triangles).
static func agave_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var n := 14
	for i in n:
		var yaw := TAU * float(i) / n + rng.randf_range(-0.15, 0.15)
		var tilt := deg_to_rad(rng.randf_range(25.0, 65.0))
		var length := rng.randf_range(0.55, 0.85)
		var width := 0.09
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -tilt)
		var base := Vector3(0, 0.05, 0)
		var mid := base + b * Vector3(0, length * 0.5, 0)
		var tip := base + b * Vector3(0, length, 0)
		var side := b * Vector3(width, 0, 0)
		var fold := b * Vector3(0, 0, 0.03)
		var c0 := Color("6f8f8a").lerp(Color("8aa39a"), rng.randf())
		var c1 := c0.lerp(Color("c9b770"), 0.25)
		for tri in [[base - side * 0.6, mid - side, mid + fold], [base - side * 0.6, mid + fold, base + side * 0.6 * 0.0 + fold],
				[base + side * 0.6, base + fold, mid + fold], [base + side * 0.6, mid + fold, mid + side],
				[mid - side, tip, mid + fold], [mid + fold, tip, mid + side]]:
			var nrm: Vector3 = ((tri[1] - tri[0]).cross(tri[2] - tri[0])).normalized()
			for k in 3:
				st.set_normal(nrm)
				st.set_color(c1 if tri[k] == tip else c0)
				st.add_vertex(tri[k])
	return st.commit()
