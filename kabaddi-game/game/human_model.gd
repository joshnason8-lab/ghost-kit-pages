class_name HumanModel
extends Node3D
## A kabaddi athlete's body.
##
## By default this builds a placeholder human from smooth primitives and animates it in code
## (run cycle, defensive crouch, raider stance, hand touch, toe touch, dive, struggle, fall,
## celebrate). If res://assets/characters/athlete.glb (or .tscn) exists, that model is used
## instead and its AnimationPlayer clips are driven by the same pose state. See docs/ASSETS.md.

const CUSTOM_MODEL_PATHS := ["res://assets/characters/athlete.tscn", "res://assets/characters/athlete.glb", "res://assets/characters/athlete.gltf"]
const CLIP_MAP_PATH := "res://assets/characters/animations.json"

# Pose inputs, set by Athlete every frame.
var speed := 0.0            # ground speed, m/s
var crouch := 0.0           # 0 upright, 1 deep defensive crouch
var lean := 0.0             # forward lean, radians
var reach := 0.0            # right-arm hand touch, 0..1
var kick := 0.0             # toe touch leg extension, 0..1
var dive := 0.0             # tackle dive, 0..1
var fallen := 0.0           # lying on the mat, 0..1
var struggle := 0.0         # dragging defenders toward the line, 0..1
var celebrate := 0.0        # arms up, 0..1
var hold_arms := 0.0        # grabbing the raider, 0..1

var skin := Color("c68863")
var hair := Color("1a1410")
var jersey := Color("1d4ed8")
var shorts := Color("0c1a29")
var trim := Color.WHITE
var number := 7
var height := 1.78
var build := 1.0
var barefoot := false

var _phase := 0.0
var _t := 0.0
var _custom: Node3D = null
var _anim: AnimationPlayer = null
var _clips := {}
var _current_clip := ""

# Joints of the procedural body.
var pelvis: Node3D
var spine: Node3D
var chest: Node3D
var neck: Node3D
var head: Node3D
var sh_l: Node3D
var sh_r: Node3D
var el_l: Node3D
var el_r: Node3D
var hip_l: Node3D
var hip_r: Node3D
var kn_l: Node3D
var kn_r: Node3D
var head_parts: Array[Node3D] = []

static var _mesh_cache := {}
static var _mat_cache := {}


func setup(p_skin: Color, p_hair: Color, p_jersey: Color, p_trim: Color, p_number: int, p_height: float, p_build: float, p_barefoot := false) -> void:
	skin = p_skin
	hair = p_hair
	jersey = p_jersey
	trim = p_trim
	number = p_number
	height = p_height
	build = p_build
	barefoot = p_barefoot
	shorts = jersey.darkened(0.55) if jersey.get_luminance() > 0.35 else jersey.darkened(0.25)


func _ready() -> void:
	for path in CUSTOM_MODEL_PATHS:
		if ResourceLoader.exists(path):
			_build_custom(path)
			return
	_build_procedural()


## Hide the head when the camera sits inside it (first person).
func set_head_visible(v: bool) -> void:
	for n in head_parts:
		n.visible = v


# ---------------------------------------------------------------- procedural body

func _mat(c: Color, rough := 0.75, sheen := false) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [c.to_html(), rough, sheen]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if sheen:
		m.rim_enabled = true
		m.rim = 0.25
		m.rim_tint = 0.6
	_mat_cache[key] = m
	return m


func _capsule(radius: float, h: float) -> CapsuleMesh:
	var key := "c_%.3f_%.3f" % [radius, h]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(h, radius * 2.0 + 0.001)
	m.radial_segments = 14
	m.rings = 6
	_mesh_cache[key] = m
	return m


func _sphere(radius: float, h := -1.0) -> SphereMesh:
	var key := "s_%.3f_%.3f" % [radius, h]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 if h < 0.0 else h
	m.radial_segments = 18
	m.rings = 10
	_mesh_cache[key] = m
	return m


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j


func _build_procedural() -> void:
	var s := height / 1.78
	var w := build
	var skin_m := _mat(skin, 0.62, true)
	var jersey_m := _mat(jersey, 0.82)
	var trim_m := _mat(trim, 0.8)
	var shorts_m := _mat(shorts, 0.85)
	var hair_m := _mat(hair, 0.95)
	var shoe_m := _mat(Color("f2f2f2") if not barefoot else skin.darkened(0.15), 0.7)

	var thigh_len := 0.44 * s
	var shin_len := 0.44 * s
	var upper_arm := 0.30 * s
	var forearm := 0.27 * s
	var hip_h := 0.06 + thigh_len + shin_len + 0.04

	pelvis = _joint(self, Vector3(0, hip_h, 0))
	# Hips and shorts.
	_part(pelvis, _sphere(0.17 * w), shorts_m, Vector3(0, 0.0, 0), Vector3(1.05, 0.75, 0.72))

	spine = _joint(pelvis, Vector3(0, 0.06, 0))
	# Abdomen and chest in the jersey, tapered to the waist.
	_part(spine, _capsule(0.15 * w, 0.36 * s), jersey_m, Vector3(0, 0.16 * s, 0), Vector3(1.0, 1.0, 0.7))
	chest = _joint(spine, Vector3(0, 0.30 * s, 0))
	_part(chest, _capsule(0.19 * w, 0.30 * s), jersey_m, Vector3(0, 0.06 * s, 0), Vector3(1.08, 1.0, 0.68))
	# Collar trim.
	_part(chest, _capsule(0.075, 0.16), trim_m, Vector3(0, 0.205 * s, 0), Vector3(1.4, 0.35, 1.0), Vector3(0, 0, PI / 2))

	# Shirt number on the back.
	var num := Label3D.new()
	num.text = str(number)
	num.font_size = 96
	num.pixel_size = 0.0022
	num.outline_size = 8
	num.modulate = trim
	num.outline_modulate = jersey.darkened(0.4)
	num.position = Vector3(0, 0.06 * s, 0.135 * w)
	# Label3D faces +Z, which is the player's back (bodies face -Z).
	num.double_sided = false
	chest.add_child(num)

	neck = _joint(chest, Vector3(0, 0.22 * s, 0))
	var neck_mesh := _part(neck, _capsule(0.055, 0.12), skin_m, Vector3(0, 0.03, 0))
	head = _joint(neck, Vector3(0, 0.1, 0))
	var skull := _part(head, _sphere(0.105), skin_m, Vector3(0, 0.07, -0.005), Vector3(0.92, 1.12, 1.0))
	var jaw := _part(head, _sphere(0.085), skin_m, Vector3(0, 0.0, -0.02), Vector3(0.9, 0.8, 0.95))
	var hair_cap := _part(head, _sphere(0.11, 0.15), hair_m, Vector3(0, 0.125, 0.012), Vector3(0.95, 1.0, 1.05))
	var ear_l := _part(head, _sphere(0.022), skin_m, Vector3(-0.098, 0.06, 0.005), Vector3(0.6, 1.2, 1.0))
	var ear_r := _part(head, _sphere(0.022), skin_m, Vector3(0.098, 0.06, 0.005), Vector3(0.6, 1.2, 1.0))
	var nose := _part(head, _sphere(0.018), skin_m, Vector3(0, 0.055, -0.1), Vector3(0.8, 1.3, 1.0))
	var brow := _part(head, _capsule(0.012, 0.11), hair_m, Vector3(0, 0.1, -0.088), Vector3.ONE, Vector3(0, 0, PI / 2))
	var eye_m := _mat(Color("16110d"), 0.3)
	var eye_l := _part(head, _sphere(0.011), eye_m, Vector3(-0.035, 0.078, -0.092))
	var eye_r := _part(head, _sphere(0.011), eye_m, Vector3(0.035, 0.078, -0.092))
	var beard := _part(head, _sphere(0.08), _mat(hair.lightened(0.05), 0.95), Vector3(0, -0.005, -0.03), Vector3(0.95, 0.65, 0.9))
	beard.visible = (number % 3) == 0
	head_parts = [neck_mesh, skull, jaw, hair_cap, ear_l, ear_r, nose, brow, eye_l, eye_r, beard]

	# Arms: short jersey sleeves over skin.
	var shoulder_w := 0.215 * w
	sh_l = _joint(chest, Vector3(-shoulder_w, 0.15 * s, 0))
	sh_r = _joint(chest, Vector3(shoulder_w, 0.15 * s, 0))
	for sh in [sh_l, sh_r]:
		_part(sh, _sphere(0.07 * w), jersey_m, Vector3(0, -0.01, 0))
		_part(sh, _capsule(0.058 * w, upper_arm), skin_m, Vector3(0, -upper_arm * 0.5, 0))
		_part(sh, _capsule(0.066 * w, 0.14), jersey_m, Vector3(0, -0.05, 0))
	el_l = _joint(sh_l, Vector3(0, -upper_arm, 0))
	el_r = _joint(sh_r, Vector3(0, -upper_arm, 0))
	for el in [el_l, el_r]:
		_part(el, _capsule(0.047 * w, forearm), skin_m, Vector3(0, -forearm * 0.5, 0))
		_part(el, _sphere(0.048), skin_m, Vector3(0, -forearm - 0.03, 0), Vector3(0.8, 1.25, 0.55))

	# Legs: shorts to mid-thigh, then skin, then shoes (or bare feet on mud and sand).
	hip_l = _joint(pelvis, Vector3(-0.1 * w, -0.04, 0))
	hip_r = _joint(pelvis, Vector3(0.1 * w, -0.04, 0))
	for hip in [hip_l, hip_r]:
		_part(hip, _capsule(0.085 * w, thigh_len), skin_m, Vector3(0, -thigh_len * 0.5, 0))
		_part(hip, _capsule(0.098 * w, thigh_len * 0.62), shorts_m, Vector3(0, -thigh_len * 0.26, 0))
	kn_l = _joint(hip_l, Vector3(0, -thigh_len, 0))
	kn_r = _joint(hip_r, Vector3(0, -thigh_len, 0))
	for kn in [kn_l, kn_r]:
		_part(kn, _capsule(0.062 * w, shin_len), skin_m, Vector3(0, -shin_len * 0.5, 0))
		# Calf bulge.
		_part(kn, _sphere(0.065 * w), skin_m, Vector3(0, -shin_len * 0.3, 0.018), Vector3(1.0, 1.7, 1.0))
		_part(kn, _capsule(0.05, 0.25), shoe_m, Vector3(0, -shin_len - 0.02, -0.06), Vector3(1.05, 1.0, 0.75), Vector3(PI / 2, 0, 0))

	if not Game.shadows_enabled():
		# Blob shadow keeps players grounded when real shadows are off.
		var blob := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.75, 0.75)
		blob.mesh = quad
		blob.rotation = Vector3(-PI / 2, 0, 0)
		blob.position = Vector3(0, 0.012, 0)
		var bm := StandardMaterial3D.new()
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var grad := GradientTexture2D.new()
		grad.fill = GradientTexture2D.FILL_RADIAL
		grad.fill_from = Vector2(0.5, 0.5)
		grad.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0.45))
		g.set_color(1, Color(0, 0, 0, 0))
		grad.gradient = g
		bm.albedo_texture = grad
		blob.material_override = bm
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(blob)


# ---------------------------------------------------------------- custom model

func _build_custom(path: String) -> void:
	var res = load(path)
	if res is PackedScene:
		_custom = res.instantiate()
	if _custom == null:
		_build_procedural()
		return
	add_child(_custom)
	_anim = _find_anim(_custom)
	_clips = {"idle": "idle", "run": "run", "crouch": "defend_idle", "raid": "raid_idle", "reach": "hand_touch", "kick": "toe_touch", "dive": "tackle_dive", "struggle": "struggle", "fallen": "fallen", "celebrate": "celebrate", "hold": "hold"}
	if FileAccess.file_exists(CLIP_MAP_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CLIP_MAP_PATH))
		if parsed is Dictionary:
			for k in parsed:
				_clips[k] = String(parsed[k])
	_tint_custom(_custom)


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var a := _find_anim(c)
		if a:
			return a
	return null


## Recolours surfaces whose material name mentions jersey, shorts, skin or hair.
func _tint_custom(n: Node) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				if m == null:
					continue
				var nm := String(m.resource_name).to_lower()
				var col := Color(0, 0, 0, 0)
				if nm.contains("jersey") or nm.contains("shirt"):
					col = jersey
				elif nm.contains("short"):
					col = shorts
				elif nm.contains("skin") or nm.contains("body"):
					col = skin
				elif nm.contains("hair"):
					col = hair
				if col.a > 0.0 and m is BaseMaterial3D:
					var dup: BaseMaterial3D = m.duplicate()
					dup.albedo_color = col
					mi.set_surface_override_material(i, dup)
	for c in n.get_children():
		_tint_custom(c)


func _custom_pose() -> void:
	if _anim == null:
		return
	var want := "idle"
	var spd := 1.0
	if fallen > 0.5:
		want = "fallen"
	elif dive > 0.3:
		want = "dive"
	elif struggle > 0.3:
		want = "struggle"
	elif celebrate > 0.3:
		want = "celebrate"
	elif kick > 0.3:
		want = "kick"
	elif reach > 0.3:
		want = "reach"
	elif hold_arms > 0.3:
		want = "hold"
	elif speed > 0.6:
		want = "run"
		spd = clampf(speed / 4.5, 0.6, 1.6)
	elif crouch > 0.5:
		want = "crouch"
	elif lean < -0.2:
		want = "raid"
	var clip: String = _clips.get(want, "idle")
	if not _anim.has_animation(clip):
		clip = _clips.get("idle", "idle")
		if not _anim.has_animation(clip):
			return
	_anim.speed_scale = spd
	if clip != _current_clip:
		_current_clip = clip
		_anim.play(clip, 0.15)


# ---------------------------------------------------------------- animation

func _process(delta: float) -> void:
	_t += delta
	if _custom:
		_custom_pose()
		return
	if pelvis == null:
		return
	_animate(delta)


func _animate(delta: float) -> void:
	var run := clampf(speed / 3.5, 0.0, 1.0)
	var stride_hz := 1.2 + speed * 0.28
	_phase = fmod(_phase + delta * stride_hz * TAU, TAU)
	var sw := sin(_phase)
	var cw := cos(_phase)

	var c := crouch * (1.0 - run * 0.5)
	var lie := maxf(dive, fallen)

	# Pelvis height: crouch lowers it, running bobs it, diving and falling drop it to the mat.
	var hip_h := (0.06 + 0.88 * height / 1.78 + 0.04)
	var y := hip_h - c * 0.26 - absf(sw) * 0.035 * run - struggle * 0.12
	y = lerpf(y, 0.28, lie)
	pelvis.position.y = y
	# Whole-body pitch for dives (face down toward the target) and falls.
	pelvis.rotation.x = lerpf(0.0, -1.35, dive) + lerpf(0.0, -1.5, fallen * (1.0 - dive))
	pelvis.rotation.z = sw * 0.04 * run

	# Spine lean: forward for running, crouching, struggling and toe touches.
	var lean_total := lean - c * 0.5 - run * 0.22 - struggle * 0.55 + kick * 0.3 - reach * 0.25
	spine.rotation.x = lean_total * (1.0 - lie * 0.7)
	spine.rotation.y = -reach * 0.35 + sw * 0.08 * run
	chest.rotation.x = 0.0
	head.rotation.x = -lean_total * 0.7 * (1.0 - lie * 0.4) - lie * 0.7
	chest.scale = Vector3.ONE * (1.0 + sin(_t * 2.2) * 0.012 * (1.0 - run))

	# Legs.
	var thigh_swing := 0.75 * run
	var lthigh := sw * thigh_swing + c * 0.75
	var rthigh := -sw * thigh_swing + c * 0.75
	var lknee := -(0.25 + maxf(0.0, -sw) * 1.25) * run - c * 1.35
	var rknee := -(0.25 + maxf(0.0, sw) * 1.25) * run - c * 1.35
	# Toe touch: right leg stretches forward along the mat toward a defender's foot,
	# the left leg bends to take the weight.
	rthigh = lerpf(rthigh, 1.3, kick)
	rknee = lerpf(rknee, -0.05, kick)
	lthigh = lerpf(lthigh, 0.45, kick)
	lknee = lerpf(lknee, -1.0, kick)
	pelvis.position.y -= kick * 0.16
	# Struggle: short, fast driving steps.
	if struggle > 0.0:
		var ss := sin(_t * 14.0)
		lthigh = lerpf(lthigh, 0.55 + ss * 0.3, struggle)
		rthigh = lerpf(rthigh, 0.55 - ss * 0.3, struggle)
		lknee = lerpf(lknee, -0.9, struggle)
		rknee = lerpf(rknee, -0.9, struggle)
	# Lying down: legs straight behind.
	lthigh = lerpf(lthigh, 0.05, lie)
	rthigh = lerpf(rthigh, -0.05, lie)
	lknee = lerpf(lknee, -0.1, lie)
	rknee = lerpf(rknee, -0.25, lie)
	hip_l.rotation = Vector3(lthigh, 0, -0.06 - c * 0.12)
	hip_r.rotation = Vector3(rthigh, 0, 0.06 + c * 0.12 + kick * 0.12)
	kn_l.rotation.x = lknee
	kn_r.rotation.x = rknee

	# Arms: counter-swing when running, forward and ready when crouched.
	var arm_ready := maxf(c, hold_arms)
	var larm := -sw * 0.7 * run + arm_ready * 1.0
	var rarm := sw * 0.7 * run + arm_ready * 1.0
	var lel := 0.35 + run * 0.9 + arm_ready * 0.5
	var rel := 0.35 + run * 0.9 + arm_ready * 0.5
	var spread := 0.12 + arm_ready * 0.25
	# Hand touch: right arm whips out straight.
	rarm = lerpf(rarm, 1.75, reach)
	rel = lerpf(rel, 0.05, reach)
	# Toe touch: arms out for balance.
	larm = lerpf(larm, -0.5, kick)
	rarm = lerpf(rarm, 0.6, kick)
	# Struggle: both arms clawing toward the line.
	larm = lerpf(larm, 2.2, struggle)
	rarm = lerpf(rarm, 2.4, struggle)
	lel = lerpf(lel, 0.3, struggle)
	rel = lerpf(rel, 0.2, struggle)
	# Dive: arms out in front, reaching for the ankle.
	larm = lerpf(larm, 2.9, lie)
	rarm = lerpf(rarm, 2.9, lie)
	lel = lerpf(lel, 0.1, lie)
	rel = lerpf(rel, 0.1, lie)
	# Celebrate: both arms up, a little bounce.
	larm = lerpf(larm, 2.9, celebrate)
	rarm = lerpf(rarm, 2.9, celebrate)
	lel = lerpf(lel, 0.3, celebrate)
	rel = lerpf(rel, 0.3, celebrate)
	if celebrate > 0.0:
		pelvis.position.y += absf(sin(_t * 7.0)) * 0.08 * celebrate
	sh_l.rotation = Vector3(larm, 0, -spread - kick * 0.8 - celebrate * 0.25)
	sh_r.rotation = Vector3(rarm, 0, spread + celebrate * 0.25)
	el_l.rotation.x = lel
	el_r.rotation.x = rel
