class_name WsgFlags
extends Node3D
## Flags in the stands, held up by fans and flying in the wind - harder as the crowd's excitement rises (a score
## and they go mad). Each a pole and a cloth in two colours (a county's: the first above, the second below), all of
## them two draw calls: the waving is the shader's. Cheap on a budget phone: fewer of them, a coarser cloth, none at
## its Low (WsgFlags.count_for()).
##   var f := WsgFlags.new(); add_child(f)
##   f.build([[spot, facing, Color.BLACK, Color.GOLD], ...])     # spot: a fan's feet; the pole in their hands
##   (each frame the crowd's excitement is WsgCrowd3D's: nothing more to call)

const POLE := 2.8        # m of pole above the hands
const HANDS := 1.25      # m the hands are above the feet
const CLOTH := Vector2(2.0, 1.3)   # a terrace flag: big enough to read from across the ground

var _mat: ShaderMaterial
var _excite := 0.0


## How many flags the tier allows out of want (a premium phone all of them; a budget phone half, none on its Low).
static func count_for(want: int) -> int:
	if WsgFoundation.profile == "budget":
		return 0 if WsgFoundation.tier == WsgFoundation.LOW else want / 2
	return want


## flags: [spot, facing (flat), first colour, second colour] each.
func build(flags: Array) -> void:
	for c in get_children():
		c.queue_free()
	if flags.is_empty():
		return
	var fine := not (WsgFoundation.profile == "budget" and WsgFoundation.tier < WsgFoundation.HIGH)
	var cloth := PlaneMesh.new()
	cloth.orientation = PlaneMesh.FACE_Z
	cloth.size = CLOTH
	cloth.center_offset = Vector3(CLOTH.x * 0.5, -CLOTH.y * 0.5, 0)
	cloth.subdivide_width = 10 if fine else 4
	cloth.subdivide_depth = 4 if fine else 1
	var pole := CylinderMesh.new()
	pole.top_radius = 0.018
	pole.bottom_radius = 0.018
	pole.height = POLE + 0.3
	pole.radial_segments = 4
	pole.rings = 0
	var mm_cloth := MultiMesh.new()
	mm_cloth.transform_format = MultiMesh.TRANSFORM_3D
	mm_cloth.use_custom_data = true
	mm_cloth.use_colors = true
	mm_cloth.mesh = cloth
	mm_cloth.instance_count = flags.size()
	var mm_pole := MultiMesh.new()
	mm_pole.transform_format = MultiMesh.TRANSFORM_3D
	mm_pole.mesh = pole
	mm_pole.instance_count = flags.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = flags.size() * 7919
	for i in flags.size():
		var f: Array = flags[i]
		var spot: Vector3 = f[0]
		var face: Vector3 = Vector3((f[1] as Vector3).x, 0, (f[1] as Vector3).z).normalized()
		# The pole leans a little forward and to a side; the cloth flies from its top, across the wind.
		var lean := Basis(face.cross(Vector3.UP).normalized(), rng.randf_range(0.08, 0.22)) * Basis(face, rng.randf_range(-0.15, 0.15))
		var base := spot + Vector3(0, HANDS - 0.3, 0)
		var top := base + lean * Vector3(0, POLE + 0.3, 0)
		mm_pole.set_instance_transform(i, Transform3D(lean, base.lerp(top, 0.5)))
		var side := face.cross(Vector3.UP).normalized() * (1.0 if rng.randf() < 0.5 else -1.0)
		mm_cloth.set_instance_transform(i, Transform3D(Basis(side, Vector3.UP, side.cross(Vector3.UP)), top))
		mm_cloth.set_instance_color(i, f[2])
		var c2: Color = f[3]
		mm_cloth.set_instance_custom_data(i, Color(c2.r, c2.g, c2.b, rng.randf()))
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://addons/wsg_foundation/flag.gdshader")
	_mat.set_shader_parameter("cloth", CLOTH)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(0.55, 0.52, 0.48)
	for pair in [[mm_cloth, _mat], [mm_pole, pm]]:
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = pair[0]
		mi.material_override = pair[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _process(delta: float) -> void:
	if _mat == null:
		return
	var want := WsgCrowd3D.target_excitement()
	_excite = lerpf(_excite, want, 1.0 - exp(-delta * (4.0 if want > _excite else 0.6)))
	_mat.set_shader_parameter("excite", _excite)
	_mat.set_shader_parameter("light", WsgCrowd3D._light)
	_mat.set_shader_parameter("sun_dir", WsgCrowd3D._sun)
