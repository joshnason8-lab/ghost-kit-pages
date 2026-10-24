class_name Bench
extends Node3D
## Each side's substitutes sitting in its dugout on the far touchline either side of halfway (where a substitute comes
## on), and the men taken off sitting down with them. They sit still, so each side's bench is one model posed once
## (the owner's hurler in the side's kit, seated: HeroBody's mesh baked in the pose) drawn as a MultiMesh: two draw
## calls for both benches, at every graphics level. (Round five: "add players waiting on the bench".)

const SEAT_Z := -Pitch.HALF_W - 3.45   # the seats' line, in the dugouts (Stadium._dugouts)
const SEAT_Y := 0.0                     # the seated pose sits the body on a seat at bench height
const FIRST := 6.6                      # m from halfway to the first seat
const STEP := 1.12                      # m between seats

## The seated pose on ToonBody's bones: thighs out level, shins down, the body leaning forward a little, forearms
## on the knees.
const SIT := {"thigh_l": Vector3(-88, 0, 4), "thigh_r": Vector3(-88, 0, -4), "shin_l": Vector3(86, 0, 0),
	"shin_r": Vector3(86, 0, 0), "foot_l": Vector3(4, 0, 0), "foot_r": Vector3(4, 0, 0), "spine": Vector3(14, 0, 0),
	"chest": Vector3(6, 0, 0), "head": Vector3(-8, 0, 0), "upperarm_l": Vector3(-38, 0, 6), "forearm_l": Vector3(58, 0, 0),
	"upperarm_r": Vector3(-38, 0, -6), "forearm_r": Vector3(58, 0, 0), "hips_y": -0.56}

var m: Node
var seated: Array = [[], []]       # each side's men on the bench: their squad data
var _mmi: Array = [null, null]
var _mesh: Array = [null, null]


func _init(p_match: Node) -> void:
	m = p_match


func _ready() -> void:
	for k in 2:
		seated[k] = (m.teams[k].bench as Array).duplicate()
		await _bake(k)
		_rebuild(k)


## Where seat i of side k is (side 0 to the left of halfway as the camera sees it, side 1 to the right).
static func seat(k: int, i: int) -> Vector3:
	var sx := -1.0 if k == 0 else 1.0
	return Vector3(sx * (FIRST + i * STEP), SEAT_Y, SEAT_Z)


## How many seats each dugout has (the squad's eleven substitutes and the men taken off, with room to spare).
const SEATS := 16


## A substitute goes on: his seat is empty.
func leave(k: int, pd: Dictionary) -> void:
	seated[k].erase(pd)
	_rebuild(k)


## A man taken off sits down; where (his seat's front, to walk to).
func next_seat(k: int) -> Vector3:
	return seat(k, mini(seated[k].size(), SEATS - 1)) + Vector3(0, 0, 0.9)


func sit_down(k: int, pd: Dictionary) -> void:
	if seated[k].size() < SEATS:
		seated[k].append(pd)
		_rebuild(k)


## The side's hurler in its kit, posed seated and baked into a still mesh (the lighter of the model's two meshes: the
## bench is across the field from the camera). Skinned here on the CPU: every rest rotation of ToonBody's bones is the
## identity, so a vertex goes by each bone's pose less its rest position, weighted.
func _bake(k: int) -> void:
	var pd: Dictionary = seated[k][0] if not seated[k].is_empty() else {"skin": 1, "hair": 1, "hair_style": 0, "height": 1.8, "line": 3}
	var look: Dictionary = m._look(k, pd, false)
	var body := HeroBody.new(look)
	body.set_lod(1)
	add_child(body)
	await get_tree().process_frame
	body.apply(SIT.duplicate())
	var sk := body.skeleton
	var xf := []
	for b in sk.get_bone_count():
		xf.append(sk.get_bone_global_pose(b) * Transform3D(Basis.IDENTITY, -sk.get_bone_global_rest(b).origin))
	var src: Mesh = body.mesh_instance.mesh
	var a := src.surface_get_arrays(0)
	var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var ws: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var pv := PackedVector3Array()
	pv.resize(vs.size())
	var pn := PackedVector3Array()
	pn.resize(vs.size())
	for v in vs.size():
		var p := Vector3.ZERO
		var n := Vector3.ZERO
		for j in 4:
			var w := ws[v * 4 + j]
			if w > 0.0:
				var t: Transform3D = xf[bs[v * 4 + j]]
				p += (t * vs[v]) * w
				n += (t.basis * ns[v]) * w
		pv[v] = p
		pn[v] = n.normalized()
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = pv
	out[Mesh.ARRAY_NORMAL] = pn
	out[Mesh.ARRAY_TEX_UV] = a[Mesh.ARRAY_TEX_UV]
	out[Mesh.ARRAY_COLOR] = a[Mesh.ARRAY_COLOR]
	out[Mesh.ARRAY_INDEX] = a[Mesh.ARRAY_INDEX]
	var baked := ArrayMesh.new()
	baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	_mesh[k] = [baked, body.mesh_instance.material_override]
	body.queue_free()


func _rebuild(k: int) -> void:
	if _mesh[k] == null:
		return
	if _mmi[k] == null:
		var mi := MultiMeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.material_override = _mesh[k][1]
		add_child(mi)
		_mmi[k] = mi
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.mesh = _mesh[k][0]
	mm.instance_count = seated[k].size()
	for i in seated[k].size():
		var pd: Dictionary = seated[k][i]
		var h := float(pd.get("height", 1.8)) / 1.8 * Player.DRAW_SCALE
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * h), seat(k, i)))
	(_mmi[k] as MultiMeshInstance3D).multimesh = mm
