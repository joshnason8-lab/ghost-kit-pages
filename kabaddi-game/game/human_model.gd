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
var celebrate := 0.0        # celebrating, 0..1
var bounce := 0.0           # a raider's light, quick steps on the spot, 0..1
var _tap := 0.0
var ref_sig := 0            # an official's hand signal, see SIGNALS
var ref_amt := 0.0          # ... how far into it, 0..1
var cele := 0               # how: 0 arms up, 1 fist pump, 2 clap, 3 high five, 4 point to the crowd, 5 chest thump
var hold_arms := 0.0        # grabbing the raider, 0..1
# Emotions, 0..1 each.
var roar := 0.0             # arms flung wide, chest out, head back
var slump := 0.0            # hands on head, dejected
var shove := 0.0            # both arms driving forward
var argue := 0.0            # pointing and appealing to the referee
var slap := 0.0             # slapping the thighs before a raid
var back_kick := 0.0        # back or side kick, 0..1
var kick_back := 1.0        # direction of that kick: 1 straight back ..
var kick_side := 0.0        # .. and -1 left / 1 right
var dubki := 0.0            # ducking low under the defenders' arms, 0..1
var jump := 0.0             # lion jump: height of the leap, 0..1
var move_fwd := 1.0         # direction of travel relative to facing: 1 forward, -1 backward
var move_side := 0.0        # ... -1 left, 1 right (a side-shuffle)
var seated := 0.0           # sitting in the sitting block, 0..1
var look_around := 0.25     # how much an idle player turns his head about
var _life := 0.0            # per-player offset so idle movement is never in step
var clip: MocapClip = null  # captured motion that overrides the hand-made pose
var clip_time := 0.0
var clip_loop := true
var clip_weight := 0.0
var clip_rate := 1.0         # clip seconds per second: a fitted move plays over the move's length
var _prev_clip: MocapClip = null   # the clip before, fading out
var _prev_time := 0.0
var _prev_rate := 1.0
var _prev_loop := true
var _prev_weight := 0.0
var move_weight := 0.0      # how much a captured running clip carries him now, 0..1
var air := 0.0              # how high his lowest point should be off the floor now (m): 0 standing or lying
var _moves = null           # the captured running set (MocapClip.moves()), once looked up
var _move: MocapClip = null
var _move_t := 0.0
var _move_prev: MocapClip = null
var _move_prev_t := 0.0
var _move_fade := 1.0
var _move_held := 0.0       # seconds since the running clip last changed
var _low_gait := false      # running crouched (shuffle clips): with hysteresis so it does not flicker
# The final pose stage: when a clip changes, the step between last frame's pose and the new one is kept as
# an offset that fades out, so every transition starts from the pose on screen (see _settle).
const SETTLE_TIME := 0.18
var _joints: Array[Node3D] = []
var _last_q: Array[Quaternion] = []
var _last_h := 0.0
var _off_q: Array[Quaternion] = []
var _off_h := 0.0
var _off_t := SETTLE_TIME
var _settle_pending := false

var skin := Color("c68863")
var hair := Color("1a1410")
var jersey := Color("1d4ed8")
var shorts := Color("0c1a29")
var trim := Color.WHITE
var number := 7
var height := 1.78
var build := 1.0
var barefoot := false
var body_kind := "player"   # which realistic bodies to choose from: "player" or "referee"
var body_seed := 0          # varies the choice between people alike
var body_file := ""         # a particular body from bodies.json instead of choosing one

var _phase := 0.0
var _t := 0.0
var _custom: Node3D = null
var rig: RiggedBody = null
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
	if RiggedBody.available() and int(Game.settings.get("models", 1)) == 1:
		_use_rigged_body()


## Swap the placeholder look for the realistic rigged body. The placeholder joints stay and
## keep animating (hidden); the rigged body copies them every frame.
func _use_rigged_body() -> void:
	for n in pelvis.find_children("*", "", true, false):
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).visible = false
	rig = RiggedBody.new()
	add_child(rig)
	var seed := body_seed if body_seed != 0 else hash([number, height, build, skin.to_html()])
	var file := body_file if body_file != "" else RiggedBody.pick(body_kind, skin, build, seed)
	rig.setup(skin, jersey, shorts, hair, height, trim, file)
	if number > 0:
		rig.add_number(number, trim, jersey.darkened(0.4))


## Standing pelvis height of the placeholder, for scaling the rigged body's hips.
func leg_length() -> float:
	return 0.06 + 0.88 * height / 1.78 + 0.04


## Hide the head when the camera sits inside it (first person).
func set_head_visible(v: bool) -> void:
	for n in head_parts:
		n.visible = v and rig == null
	if rig:
		rig.set_head_visible(v)


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
	num.visible = number > 0
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
	_clips = {"idle": "idle", "run": "run", "crouch": "defend_idle", "raid": "raid_idle", "reach": "hand_touch", "kick": "toe_touch", "dive": "tackle_dive", "struggle": "struggle", "fallen": "fallen", "celebrate": "celebrate", "hold": "hold", "jump": "lion_jump", "dubki": "dubki"}
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
	elif jump > 0.3:
		want = "jump"
	elif dubki > 0.3:
		want = "dubki"
	elif kick > 0.3 or back_kick > 0.3:
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

## Officials' hand signals: left arm, right arm, left elbow, right elbow, and how far each
## arm comes in across the body (negative: out to the side).
const SIGNALS := {
	1: [2.95, 1.5, 0.15, 0.05, -0.15, 0.0],    # points: one hand up, the other at the scoring team
	2: [0.15, 0.2, 0.3, 0.05, 0.0, -1.45],     # bonus: arm out at shoulder height, thumb up
	3: [0.2, 2.2, 0.4, 0.1, 0.0, 0.0],         # out: pointing up at the side with players out
	4: [0.15, 0.1, 0.3, 0.05, 0.0, -1.25],     # technical point: arm out, thumb down
	5: [1.45, 1.55, 0.25, 1.6, 0.85, -0.05],   # time out: a T with the hands
	6: [1.25, 1.25, 1.1, 1.1, 0.75, 0.75],     # half time: arms crossed in front of the chest
	7: [1.57, 1.57, 0.05, 0.05, 0.08, 0.08],   # end of the match: both arms straight ahead
	8: [2.95, 2.95, 0.1, 0.1, -0.2, -0.2],     # all out (lona): both hands up
	9: [0.15, 3.05, 0.3, 0.0, 0.0, 0.0],       # card: held straight up
}

func _process(delta: float) -> void:
	_t += delta
	if _custom:
		_custom_pose()
		return
	if pelvis == null:
		return
	_animate(delta)
	air = jump * 0.32 * height / 1.78   # a hand-made lion jump leaves the floor by as much as it lifts the hips
	_apply_moves(delta)
	_apply_clip(delta)
	_settle(delta)
	if rig:
		rig.drive(self)
	else:
		_ground()


func _animate(delta: float) -> void:
	if _life == 0.0:
		_life = randf() * TAU
	# The stride follows how fast he moves over the floor, but a body lying on it (diving, holding a leg,
	# fallen) is slid along, not running: no stride.
	var gait := speed * (1.0 - clampf(maxf(dive, fallen), 0.0, 1.0))
	var run := clampf(gait / 3.5, 0.0, 1.0)
	# Gait. A full cycle is two steps, and its length grows with gait, so each step covers
	# the ground the body moves and the feet do not skate. Moving sideways is a crouched
	# shuffle; moving away from where he is looking is a backpedal.
	var cycle_len := clampf(0.9 + 0.48 * gait, 0.9, 3.2)
	var side_w := clampf(absf(move_side) * 1.4 - 0.25, 0.0, 1.0) if gait > 0.25 else 0.0
	var back := move_fwd < -0.3 and side_w < 0.6
	var fwd_w := 1.0 - side_w
	_phase = fmod(_phase + delta * gait / cycle_len * TAU * (-1.0 if back else 1.0) + TAU, TAU)
	var sw := sin(_phase)
	var cw := cos(_phase)

	var c := crouch * (1.0 - run * 0.5 * fwd_w)
	var lie := maxf(dive, fallen)

	# Pelvis height: crouch lowers it, each step dips it (lowest at mid-stance), diving and
	# falling drop it to the mat.
	var hip_h := (0.06 + 0.88 * height / 1.78 + 0.04)
	var y := hip_h - c * 0.26 - absf(cw) * 0.045 * run * fwd_w - struggle * 0.12 - side_w * 0.08 * minf(1.0, gait)
	y = lerpf(y, 0.28, lie)
	# Dubki: drop nearly to the mat. Lion jump: up and over.
	y -= dubki * 0.5 * height / 1.78
	y += jump * 0.32 * height / 1.78
	pelvis.position.y = y
	# Every joint's whole rotation is set afresh each frame, here and below, before any clip is laid over
	# it: setting one Euler angle alone keeps the other two from the last frame's blended pose, so a clip
	# would leak into later frames (and an angle past 90 degrees flips the others round).
	# Whole-body pitch for dives (face down toward the target) and falls.
	var pel_x := lerpf(0.0, -1.35, dive) + lerpf(0.0, -1.5, fallen * (1.0 - dive))
	var pel_z := sw * 0.04 * run * fwd_w
	var pel_y := sw * 0.12 * run * fwd_w
	# Idle life: weight shifting from foot to foot and breathing.
	var still := clampf(1.0 - gait * 2.0, 0.0, 1.0) * (1.0 - lie)
	pelvis.position.x = sin(_t * 0.55 + _life) * 0.025 * still
	pel_z += sin(_t * 0.55 + _life) * 0.035 * still
	# A side kick tips the body away from the kicking leg.
	var kick_leg := 1.0 if kick_side >= 0.0 else -1.0
	var kb := back_kick * clampf(kick_back, 0.0, 1.0)
	var ks := back_kick * absf(kick_side)
	pel_z += -kick_leg * ks * 0.45
	pelvis.rotation = Vector3(pel_x, pel_y, pel_z)

	# Spine lean: forward for running, crouching, struggling and toe touches.
	var lean_total := lean - c * 0.5 - run * 0.22 - struggle * 0.55 + kick * 0.3 - reach * 0.25 - kb * 0.75 - dubki * 1.35 - jump * 0.35
	var spine_x := lean_total * (1.0 - lie * 0.7)
	var spine_y := -reach * 0.35 - sw * 0.16 * run * fwd_w
	var head_x := -lean_total * 0.7 * (1.0 - lie * 0.4) - lie * 0.7
	var head_y := (sin(_t * 0.31 + _life * 1.7) * 0.6 + sin(_t * 0.83 + _life) * 0.25) * look_around * still
	chest.rotation = Vector3.ZERO
	neck.rotation = Vector3.ZERO
	chest.scale = Vector3.ONE * (1.0 + sin(_t * 2.2) * 0.012 * (1.0 - run))

	# Legs. The thigh swings with the stride; the knee folds while that leg swings through
	# toward the next step and is nearly straight as the foot lands.
	var amp := clampf(0.2 + 0.13 * gait, 0.0, 0.8) * fwd_w * (0.6 if back else 1.0) * minf(1.0, gait * 2.0)
	var fold := clampf(0.35 + 0.28 * gait, 0.35, 1.6) * fwd_w * minf(1.0, gait * 1.5)
	var lthigh := sw * amp + c * 0.75
	var rthigh := -sw * amp + c * 0.75
	var lknee := -(0.08 * minf(1.0, gait) + fold * pow(maxf(0.0, cw), 1.5)) - c * 1.35
	var rknee := -(0.08 * minf(1.0, gait) + fold * pow(maxf(0.0, -cw), 1.5)) - c * 1.35
	# A raider on his toes: quick light steps on the spot while he works the cover.
	var tap := bounce * clampf(1.0 - gait * 0.7, 0.0, 1.0) * (1.0 - lie)
	if tap > 0.01:
		_tap = fmod(_tap + delta * TAU * 2.4, TAU)
		var ts := sin(_tap)
		lthigh += 0.16 * tap * maxf(0.0, ts)
		rthigh += 0.16 * tap * maxf(0.0, -ts)
		lknee -= 0.32 * tap * maxf(0.0, ts)
		rknee -= 0.32 * tap * maxf(0.0, -ts)
		pelvis.position.y += 0.018 * tap * absf(ts)
	# Side-shuffle: sit into it, the leading leg steps out, the trailing leg closes up.
	var lead_r := move_side > 0.0
	var step_w := 0.32 * side_w * minf(1.0, gait * 1.2)
	var out_lead := step_w * maxf(0.0, sw)
	var out_trail := step_w * 0.55 * maxf(0.0, -sw)
	var side_l := out_trail if lead_r else out_lead
	var side_r := out_lead if lead_r else out_trail
	lthigh += side_w * 0.35
	rthigh += side_w * 0.35
	lknee -= side_w * 0.5
	rknee -= side_w * 0.5
	# Seated in the sitting block.
	lthigh = lerpf(lthigh, 1.45, seated)
	rthigh = lerpf(rthigh, 1.4, seated)
	lknee = lerpf(lknee, -1.45, seated)
	rknee = lerpf(rknee, -1.5, seated)
	pelvis.position.y = lerpf(pelvis.position.y, 0.47 * height / 1.78, seated)
	hip_l.rotation = Vector3(lthigh, 0, -0.06 - c * 0.12 - side_l - dubki * 0.25)
	hip_r.rotation = Vector3(rthigh, 0, 0.06 + c * 0.12 + kick * 0.12 + side_r + dubki * 0.25)
	kn_l.rotation = Vector3(lknee, 0, 0)
	kn_r.rotation = Vector3(rknee, 0, 0)

	# Arms: counter-swing when running, forward and ready when crouched.
	var arm_ready := maxf(c, hold_arms)
	var larm := -sw * 0.7 * run * fwd_w + arm_ready * 1.0 + side_w * 0.5
	var rarm := sw * 0.7 * run * fwd_w + arm_ready * 1.0 + side_w * 0.5
	var lel := 0.35 + run * 0.9 * fwd_w + arm_ready * 0.5 + side_w * 0.4
	var rel := 0.35 + run * 0.9 * fwd_w + arm_ready * 0.5 + side_w * 0.4
	var spread := 0.12 + arm_ready * 0.25 + side_w * 0.2
	# Seated: hands resting on the knees.
	larm = lerpf(larm, 0.55, seated)
	rarm = lerpf(rarm, 0.55, seated)
	lel = lerpf(lel, 0.6, seated)
	rel = lerpf(rel, 0.6, seated)
	# Hand touch: right arm whips out straight.
	rarm = lerpf(rarm, 1.75, reach)
	rel = lerpf(rel, 0.05, reach)
	# Toe touch: arms out for balance.
	larm = lerpf(larm, -0.5, kick)
	rarm = lerpf(rarm, 0.6, kick)
	# Back kick: arms forward for balance. Dubki: arms tucked back. Lion jump: arms
	# thrown up and forward.
	larm = lerpf(larm, 1.1, back_kick)
	rarm = lerpf(rarm, 0.9, back_kick)
	larm = lerpf(larm, -0.5, dubki)
	rarm = lerpf(rarm, -0.5, dubki)
	lel = lerpf(lel, 0.6, dubki)
	rel = lerpf(rel, 0.6, dubki)
	larm = lerpf(larm, 2.5, jump)
	rarm = lerpf(rarm, 2.5, jump)
	lel = lerpf(lel, 0.3, jump)
	rel = lerpf(rel, 0.3, jump)
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
	# Celebrate, in one of several ways.
	var c_out := 0.0
	var c_in := 0.0
	if celebrate > 0.0:
		var ca := [2.9, 2.9, 0.3, 0.3]   # left arm, right arm, left elbow, right elbow
		var bounce := 0.0
		match cele:
			1:  # Fist pump: the right fist punches the air.
				var pump := maxf(0.0, sin(_t * 8.0 + _life))
				ca = [0.5, 2.2 + pump * 0.7, 1.7, 1.7 - pump * 1.4]
				bounce = 0.03
			2:  # Clap: hands meet in front.
				ca = [0.9, 0.9, 1.35, 1.35]
				c_in = 0.42 + 0.16 * sin(_t * 15.0 + _life)
			3:  # High five: right hand up and forward to meet a team-mate's.
				ca = [0.35, 2.55, 0.5, 0.15]
			4:  # Pointing out to the crowd.
				ca = [0.6, 2.05, 1.8, 0.05]
				c_out = -0.35
			5:  # Thumping his chest.
				var th := maxf(0.0, sin(_t * 6.5 + _life))
				ca = [0.4, 1.05 + th * 0.35, 0.5, 2.25]
				c_in = 0.25
			_:  # Both arms up, bouncing.
				c_out = 0.25
				bounce = 0.08
		larm = lerpf(larm, ca[0], celebrate)
		rarm = lerpf(rarm, ca[1], celebrate)
		lel = lerpf(lel, ca[2], celebrate)
		rel = lerpf(rel, ca[3], celebrate)
		pelvis.position.y += absf(sin(_t * 7.0 + _life)) * bounce * celebrate
	# Roar: arms wide and up.
	larm = lerpf(larm, 1.9, roar)
	rarm = lerpf(rarm, 1.9, roar)
	lel = lerpf(lel, 0.6, roar)
	rel = lerpf(rel, 0.6, roar)
	# Shove: both arms straight out in front.
	larm = lerpf(larm, 1.5, shove)
	rarm = lerpf(rarm, 1.5, shove)
	lel = lerpf(lel, 0.05, shove)
	rel = lerpf(rel, 0.05, shove)
	# Argue: right arm points at the line, left arm open.
	rarm = lerpf(rarm, 1.6, argue)
	rel = lerpf(rel, 0.1, argue)
	larm = lerpf(larm, 0.7, argue)
	lel = lerpf(lel, 1.2, argue)
	# Slump: hands on the head.
	larm = lerpf(larm, 2.7, slump)
	rarm = lerpf(rarm, 2.7, slump)
	lel = lerpf(lel, 2.3, slump)
	rel = lerpf(rel, 2.3, slump)
	# Thigh slap: hands drop to the thighs in turn.
	if slap > 0.0:
		var sw2 := sin(_t * 9.0)
		larm = lerpf(larm, 0.3 + maxf(0.0, sw2) * 0.55, slap)
		rarm = lerpf(rarm, 0.3 + maxf(0.0, -sw2) * 0.55, slap)
		lel = lerpf(lel, 0.5, slap)
		rel = lerpf(rel, 0.5, slap)
	# Officials' hand signals.
	if ref_amt > 0.0:
		var sa: Array = SIGNALS.get(ref_sig, [0.0, 0.0, 0.3, 0.3, 0.0, 0.0])
		larm = lerpf(larm, sa[0], ref_amt)
		rarm = lerpf(rarm, sa[1], ref_amt)
		lel = lerpf(lel, sa[2], ref_amt)
		rel = lerpf(rel, sa[3], ref_amt)
		spread = lerpf(spread, 0.0, ref_amt)
	var sig_l: float = (SIGNALS.get(ref_sig, [0, 0, 0, 0, 0.0, 0.0])[4] as float) * ref_amt
	var sig_r: float = (SIGNALS.get(ref_sig, [0, 0, 0, 0, 0.0, 0.0])[5] as float) * ref_amt
	sh_l.rotation = Vector3(larm, 0, sig_l - spread - kick * 0.8 - celebrate * (c_out - c_in) - roar * 0.9 - argue * 0.3 - slump * 0.5)
	sh_r.rotation = Vector3(rarm, 0, -sig_r + spread + celebrate * (c_out - c_in) + roar * 0.9 + slump * 0.5)
	spine_x += roar * 0.3 - slump * 0.3 - shove * 0.45 - slap * 0.35 - argue * 0.1
	head_x += roar * 0.45 - slump * 0.35 + dubki * 0.6
	spine.rotation = Vector3(spine_x, spine_y, 0)
	head.rotation = Vector3(head_x, head_y, 0)
	el_l.rotation = Vector3(lel, 0, 0)
	el_r.rotation = Vector3(rel, 0, 0)


## Blend captured motion over the hand-made pose: the state's clip, and the one before it fading out.
func _apply_clip(delta: float) -> void:
	# Looping stance clips give way to the run cycle when the player is moving fast.
	var want := 0.0
	if clip:
		want = 1.0 if not clip_loop else clampf(1.0 - (speed - 0.8) / 2.0, 0.0, 1.0)
	# A quick move comes in fast: its clip already starts from the run-up.
	clip_weight = move_toward(clip_weight, want, delta * (6.0 if clip_loop else 14.0))
	if _prev_clip and _prev_weight > 0.0:
		_prev_weight = move_toward(_prev_weight, 0.0, delta * 6.0)
		_prev_time += delta * _prev_rate
		_play_frame(_prev_clip, _prev_time, _prev_loop, _prev_weight)
	if clip and clip_weight > 0.0:
		clip_time += delta * clip_rate
		_play_frame(clip, clip_time, clip_loop, clip_weight)


func _play_frame(c: MocapClip, t: float, loop: bool, w: float) -> void:
	# A stance (a looping clip) gives the legs up to the running set while he moves: legs from both take
	# different strides and the feet slide. Its trunk, head and arms stay.
	var legs := w * (1.0 - move_weight) if loop else w
	if c.version >= 2:
		_apply_pose(c.sample_pose(t, loop), legs, false, c.arms == "r", w)   # the move's clip drives the arms too
		return
	# Footage clips (version 1) give one bend per joint. Applied as rotations (not by setting one Euler
	# angle, which can flip the others round): knees and elbows are hinges; hips, shoulders and the spine
	# keep their sideways and twisting angles from the pose underneath.
	var f := c.sample(t, loop)
	var hip_h := 0.06 + 0.88 * height / 1.78 + 0.04
	if f.has("height"):
		pelvis.position.y = lerpf(pelvis.position.y, hip_h * float(f.height), legs)
	for item in [["spine", spine, w], ["hip_l", hip_l, legs], ["hip_r", hip_r, legs], ["sh_l", sh_l, w], ["sh_r", sh_r, w]]:
		if f.has(item[0]) and item[2] > 0.0:
			var node: Node3D = item[1]
			var e := node.rotation
			node.quaternion = node.quaternion.slerp(Quaternion.from_euler(Vector3(float(f[item[0]]), e.y, e.z)), item[2])
	for item in [["knee_l", kn_l, legs], ["knee_r", kn_r, legs], ["el_l", el_l, w], ["el_r", el_r, w]]:
		if f.has(item[0]) and item[2] > 0.0:
			var node: Node3D = item[1]
			node.quaternion = node.quaternion.slerp(Quaternion(Vector3.RIGHT, float(f[item[0]])), item[2])


## Captured motion for an athlete's state (MocapClip.FOR_STATE), if there is any; none hands back to the
## hand-made pose. Of several clips, he takes the one that starts nearest the pose he is in (so a player
## lying on his back gets up the way people do from their back), with a little of his own taste.
func play_state(state: String, length := 0.0, variant := "") -> void:
	var opts := MocapClip.options(state, variant) if state != "" else []
	if opts.is_empty():
		play_clip(null, true)
		return
	var how := MocapClip.how(state)
	var best: MocapClip = null
	var best_score := INF
	for i in opts.size():
		var c: MocapClip = opts[i]
		var score := float(hash([_life, c.name]) % 1000) / 1000.0 * 0.6
		if c.version >= 2:
			var first := c.sample_pose(0.0, false)
			score += pelvis.quaternion.angle_to(first.pelvis) + absf(pelvis.position.y / (0.98 * height / 1.78) - float(first.h)) * 2.0
		if score < best_score:
			best = c
			best_score = score
	play_clip(best, how == "loop", length if how == "fit" else 0.0)


## Captured running: whenever he travels, the running clip nearest his direction and speed carries the
## body, played at the rate that keeps the planted foot still. Moves that need the body for themselves
## (dives, dubki, jumps, kicks, holds, celebrations) and a deep crouch keep the hand-made pose; the right
## arm stays free to reach for a touch.
func _apply_moves(delta: float) -> void:
	if _moves == null:
		_moves = MocapClip.moves()
	if (_moves as Array).is_empty():
		return
	var busy := maxf(maxf(dive, fallen), maxf(maxf(struggle, dubki), maxf(jump, maxf(kick, back_kick))))
	busy = maxf(busy, maxf(seated, maxf(celebrate, shove)))
	var want := clampf((speed - 0.35) / 0.6, 0.0, 1.0) * (1.0 - busy)
	# Crouched or upright gait, with a gap between going down and coming up so it does not flicker.
	if crouch > 0.55:
		_low_gait = true
	elif crouch < 0.4:
		_low_gait = false
	var crouched := 1.0 if _low_gait else 0.0
	var way := Vector2(move_side, move_fwd)
	way = way.normalized() if way.length() > 0.1 else Vector2(0, 1)
	var s178 := speed * 1.78 / height   # his speed as a 1.78 m player's
	var best: MocapClip = null
	var best_score := INF
	var cur_score := INF
	for c in _moves:
		var align: float = (c as MocapClip).dir.normalized().dot(way)
		if align < (0.45 if c == _move else 0.6):
			continue
		var score := (1.0 - align) * 3.0 + absf(log(maxf(s178, 0.3) / (c as MocapClip).speed))
		score += absf(crouched - (1.0 if (c as MocapClip).low else 0.0)) * 1.5   # a crouched player shuffles low
		if c == _move:
			cur_score = score
		if score < best_score:
			best = c
			best_score = score
	# Hysteresis: keep the clip he is in unless another fits clearly better, and give each clip a moment.
	_move_held += delta
	if _move != null and cur_score < INF and (best_score > cur_score - 0.3 or _move_held < 0.3):
		best = _move
	if best == null:
		want = 0.0
	# An upright clip for a crouching player: his own crouch in the body and arms, but the clip's legs in
	# full. Legs half from a clip and half hand-made take different strides and the feet slide.
	var upper := 1.0 if best == null or best.low else 1.0 - 0.7 * crouch
	move_weight = move_toward(move_weight, want, delta * 5.0)
	if best != null and best != _move:
		# Switch clips through a quick cross-fade, starting the new one at the same point of its stride.
		if _move != null and _move_fade < 1.0:
			_settle_pending = true   # switched again mid-fade: the final pose stage carries over the step
		_move_held = 0.0
		_move_prev = _move
		_move_prev_t = _move_t
		_move_fade = 0.0 if _move != null else 1.0
		_move_t = (fposmod(_move_t, _move.length) / _move.length * best.length) if _move != null else randf() * best.length
		_move = best
	if _move == null or move_weight <= 0.0:
		return
	_move_t += delta * clampf(s178 / _move.speed, 0.5, 1.8)
	var pose := _move.sample_pose(_move_t, true)
	if _move_prev != null and _move_fade < 1.0:
		_move_fade = minf(1.0, _move_fade + delta * 5.0)
		_move_prev_t += delta * clampf(s178 / _move_prev.speed, 0.5, 1.8)
		var old := _move_prev.sample_pose(_move_prev_t, true)
		for k in pose:
			if not old.has(k):
				continue
			if k == "h" or k == "a":
				pose[k] = lerpf(float(old[k]), float(pose[k]), _move_fade)
			else:
				var qo: Quaternion = old[k]
				pose[k] = qo.slerp(pose[k], _move_fade)
	_apply_pose(pose, move_weight, true, false, move_weight * upper)


## Lay a captured pose over the hand-made one, by weight w. With keep_arms (a running clip), arms busy
## reaching or grabbing keep theirs.
func _apply_pose(pose: Dictionary, w: float, keep_arms := true, right_only := false, upper := -1.0) -> void:
	var hip_h := 0.06 + 0.88 * height / 1.78 + 0.04
	if pose.has("h"):
		pelvis.position.y = lerpf(pelvis.position.y, hip_h * float(pose.h), w)
	if pose.has("a"):
		air = lerpf(air, float(pose.a) * height / 1.78, w)
	# upper: a separate weight for the trunk, head and arms (the legs, pelvis and hip height take w).
	var u := w if upper < 0.0 else upper
	var arm_l := u * (1.0 - hold_arms) if keep_arms else (0.0 if right_only else u)
	var arm_r := u * (1.0 - maxf(hold_arms, reach)) if keep_arms else u
	for pair in [["pelvis", pelvis, w], ["spine", spine, u], ["chest", chest, u], ["neck", neck, u * 0.6],
			["head", head, u * 0.6], ["sh_l", sh_l, arm_l], ["el_l", el_l, arm_l], ["sh_r", sh_r, arm_r],
			["el_r", el_r, arm_r], ["hip_l", hip_l, w], ["kn_l", kn_l, w], ["hip_r", hip_r, w], ["kn_r", kn_r, w]]:
		if pose.has(pair[0]) and pair[2] > 0.0:
			var node: Node3D = pair[1]
			node.quaternion = node.quaternion.slerp(pose[pair[0]], pair[2])


## A point on the body as drawn now, in world space (see RiggedBody.anchor for the parts). The classic
## body works it out from its own joints.
func anchor(part: String) -> Vector3:
	if rig:
		return rig.anchor(part)
	var s := height / 1.78
	var side := part.substr(part.length() - 1)
	match part.substr(0, part.length() - 2) if part != "waist" else part:
		"hand":
			var el: Node3D = el_l if side == "l" else el_r
			return el.global_transform * Vector3(0, -0.29 * s, 0)
		"foot", "ankle", "shin":
			var kn: Node3D = kn_l if side == "l" else kn_r
			var down := {"foot": 0.44, "ankle": 0.39, "shin": 0.29}[part.substr(0, part.length() - 2)] as float
			return kn.global_transform * Vector3(0, -down * s, 0)
		"thigh":
			var hip: Node3D = hip_l if side == "l" else hip_r
			return hip.global_transform * Vector3(0, -0.24 * s, 0)
		"waist":
			return spine.global_transform * Vector3(0, -0.04 * s, 0)
	return global_position


## The final pose stage, after the hand-made pose and the clips are laid over it. A transition (a clip let
## go mid-fade, a running clip switched mid-fade) or any joint jumping further in one frame than a body can
## swing it (1200 deg/s: 40 degrees a frame at 30 fps, 20 at 60) keeps last frame's pose as an offset that
## fades out over SETTLE_TIME, so nothing on screen snaps.
func _settle(delta: float) -> void:
	if _joints.is_empty():
		_joints = [pelvis, spine, chest, neck, head, sh_l, sh_r, el_l, el_r, hip_l, hip_r, kn_l, kn_r]
		for j in _joints:
			_last_q.append(j.quaternion)
			_off_q.append(Quaternion.IDENTITY)
		_last_h = pelvis.position.y
		return
	var w := _settle_weight(_off_t)
	if not _settle_pending:
		var jump := deg_to_rad(1200.0) * clampf(delta, 1.0 / 120.0, 1.0 / 20.0)
		for i in _joints.size():
			var q := Quaternion.IDENTITY.slerp(_off_q[i], w) * _joints[i].quaternion if w > 0.0 else _joints[i].quaternion
			if _last_q[i].angle_to(q) > jump:
				_settle_pending = true
				break
	if _settle_pending:
		# Whatever offset is still fading is folded in, so the pose stays where it was on screen.
		for i in _joints.size():
			_off_q[i] = (_last_q[i] * _joints[i].quaternion.inverse()).normalized()
		_off_h = _last_h - pelvis.position.y
		_off_t = 0.0
		w = 1.0
		_settle_pending = false
	if w > 0.0:
		for i in _joints.size():
			_joints[i].quaternion = (Quaternion.IDENTITY.slerp(_off_q[i], w) * _joints[i].quaternion).normalized()
		pelvis.position.y += _off_h * w
	_off_t += delta
	for i in _joints.size():
		_last_q[i] = _joints[i].quaternion
	_last_h = pelvis.position.y


func _settle_weight(t: float) -> float:
	if t >= SETTLE_TIME:
		return 0.0
	var x := t / SETTLE_TIME
	return 1.0 - x * x * (3.0 - 2.0 * x)   # smooth: full at the transition, nothing at the end


## The classic body on the floor: its lowest point (soles, knees, hands, head, back) as high as air says.
func _ground() -> void:
	var s := height / 1.78
	var low := INF
	for kn in [kn_l, kn_r]:
		# Sole: heel and toe under the shin.
		low = minf(low, (kn as Node3D).to_global(Vector3(0, -0.44 * s - 0.045, 0.03)).y)
		low = minf(low, (kn as Node3D).to_global(Vector3(0, -0.44 * s - 0.045, -0.17)).y)
		low = minf(low, (kn as Node3D).global_position.y - 0.06)
	for el in [el_l, el_r]:
		low = minf(low, (el as Node3D).to_global(Vector3(0, -0.3 * s, 0)).y - 0.04)
	low = minf(low, head.to_global(Vector3(0, 0.07, 0)).y - 0.12)
	low = minf(low, chest.global_position.y - 0.15)
	low = minf(low, pelvis.global_position.y - 0.15)
	pelvis.global_position.y += global_position.y + air - low


func play_clip(c: MocapClip, loop: bool, fit := 0.0) -> void:
	if c == clip and c != null and loop and clip_loop:
		return
	# A clip still fading out under this one is let go; the final pose stage carries its share over.
	if _prev_clip and _prev_weight > 0.0 and clip and clip_weight > 0.0:
		_settle_pending = true
	# The clip playing now fades out under the new one.
	if clip and clip_weight > 0.0:
		_prev_clip = clip
		_prev_time = clip_time
		_prev_rate = clip_rate
		_prev_loop = clip_loop
		_prev_weight = clip_weight
		clip_weight = 0.0
	clip = c
	clip_loop = loop
	clip_rate = c.length / fit if (c and fit > 0.0) else 1.0
	# Start loops at a random point so a whole team never moves in lockstep.
	clip_time = randf() * c.length if (c and loop) else 0.0
