class_name FoundationLink
extends Node3D
## A floorball player, goalkeeper or referee drawn with the World Stage Games foundation (addons/wsg_foundation): the
## owner's Meshy athlete baked onto the shared rig (fingers, twist and joint helpers), run by the motion-capture
## locomotion (starts, cuts, stops, backpedals; the feet planted), with every move the game makes by hand laid over it
## from the game's own body (WsgLegacyPose): the shot, the pass, the tackle, the goalkeeper's whole game, a referee's
## signals, and the trunk and arms of a player running with his stick. The game's Body stays the game's: player.gd
## still poses it every frame and everything measured off it (the blade, the stick, the hands) is unchanged; it, and
## the RiggedBody that drew it, are only no longer drawn.
## Without the licensed clip library (a fork's build, CI) Player makes none, and the game is as it was.

const DIR := "res://assets/foundation/"
## The game's own moves on a player with a stick: the whole body is the game's pose (its legs, its facing).
const FULL := ["shoot", "pass", "tackle"]
const TRUNK := ["Spine", "Spine1", "Spine2", "Neck", "Head"]
const ARMS := ["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]
## The shaft as drawn (RiggedBody.stick_mesh: a 25 mm tube) and the fingers closed round it, a millimetre clear.
const SHAFT_R := 0.0125
const GRIP_R := 0.0135
## The top fist's middle down the shaft from the grip's end (m): the knob shows above the fist.
const TOP_AT := 0.06

var player: Player
var gb: Body                  # the game's body (posed by player.gd, not drawn)
var body: WsgBody
var loco: WsgLocomotor
var legacy: StickLayer
var reader: WsgLegacyPose
var stick: MeshInstance3D
var material: ShaderMaterial
var mode := ""
var top := "Right"            # the hand at the top of the stick (a left-shooter's right)
var low := "Left"
var _arm_len := {}            # side -> shoulder to wrist (m, the rig's rest)
var _reach_len := {}          # side -> the same as the layer measures it (the forearm's and hand's rest offsets)
var _grip_pt := {}            # side -> the shaft's axis through that fist (rest, the joints' space)
var _history: Array = []      # [clock, the stick in the top hand as drawn] for the replay
var _dt := 1.0 / 60.0
var _at := Vector3.INF

## The replay's moment (FoundationLink.clock()), or INF in live play: the sticks are drawn as they were then.
static var replay_at := INF


## Floorball draws with the Mobile renderer and is made for the nicer phones (WsgFoundation: Medium by default).
static func _static_init() -> void:
	WsgFoundation.profile = OS.get_environment("WSG_PROFILE") if OS.has_environment("WSG_PROFILE") else "premium"


static func enabled() -> bool:
	return WsgClips.available() and ResourceLoader.exists(DIR + "man_rig.json") and not OS.has_environment("WSG_OFF")


## The clock the replay keeps its frames by (physics frames, in seconds).
static func clock() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


func _init(p_player: Player, p_body: Body) -> void:
	player = p_player
	gb = p_body
	name = "Foundation"
	top_level = true


func _ready() -> void:
	var look := gb.look
	var kind := String(look.get("kind", "player"))
	var prefix := "woman" if bool(look.get("women", false)) and kind != "referee" else "man"
	if not ResourceLoader.exists(DIR + prefix + "_rig.json"):
		prefix = "man"
	var lod := 1 if int(Game.settings.graphics) == Game.GFX_LOW else 0
	body = WsgBody.new(WsgBody.load_character(DIR, prefix), null, lod)
	add_child(body)
	body.set_manual(true)
	body.visible = false        # till its first pose (the rig's T-pose otherwise, for a frame)
	body.scale = gb.scale
	_make_material()
	body.mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	legacy = StickLayer.new()
	legacy.link = self
	legacy.name = "Legacy"
	body.skeleton.add_child(legacy)
	body.skeleton.move_child(legacy, 0)
	loco = WsgLocomotor.attach(body)
	legacy.lift_after = loco.planter.hips_offset     # the game's hips height is this body's already
	legacy.torso_r = 0.1        # the forearms kept out of this (broader) body's chest
	reader = WsgLegacyPose.new(gb.skeleton, body.joints)
	legacy.arms = reader
	for side in ["Left", "Right"]:
		_grip_pt[side] = WsgGrip.clear_axis_point(body.joints, side, GRIP_R)
		_arm_len[side] = (body.joints[side + "ForeArm"] as Vector3).distance_to(body.joints[side + "Arm"]) + \
			(body.joints[side + "Hand"] as Vector3).distance_to(body.joints[side + "ForeArm"])
		var sk := body.skeleton
		_reach_len[side] = sk.get_bone_rest(sk.find_bone(side + "ForeArm")).origin.length() + sk.get_bone_rest(sk.find_bone(side + "Hand")).origin.length()
	# The game's body stays (posed, measured), unseen; what it carried is drawn here.
	gb.drawn_elsewhere = true
	if gb.rig:
		gb.rig.visible = false
	if gb.mesh_instance:
		gb.mesh_instance.visible = false
	if kind == "player":
		top = "Right" if player.shoots_left() else "Left"
		low = "Left" if top == "Right" else "Right"
		reader.held = {top: true}
		_make_stick()
	elif kind == "keeper":
		_make_helmet()


## The game's kit shader (RiggedBody's: the team's colours by the texture's blues and each vertex's standing height),
## its height read from the bake's vertex colour (tools/wsg/bake_character.gd: the rest position, y / 2 in green).
static var _shader: Shader


func _make_material() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = RiggedBody.SHADER.replace("h = COLOR.r;", "h = COLOR.g * (2.0 / 1.8);")
	material = ShaderMaterial.new()
	material.shader = _shader
	body.mesh_instance.material_override = material
	recolour()


## The kit (a line change: the next player out in his own colours and skin): RiggedBody's colours, as it has them.
func recolour() -> void:
	if material == null:
		return
	body.scale = gb.scale
	if gb.rig and gb.rig.material:
		for k in ["albedo_tex", "jersey_col", "shorts_col", "socks_col", "trim_col", "skin_ratio", "keeper", "recolour"]:
			material.set_shader_parameter(k, gb.rig.material.get_shader_parameter(k))
		return
	# (No RiggedBody: the colours straight from the look.)
	var look := gb.look
	for k in [["jersey_col", "jersey", Color.BLUE], ["shorts_col", "shorts", Color.BLUE], ["socks_col", "socks", Color.BLUE], ["trim_col", "trim", Color.WHITE]]:
		var c: Color = look.get(k[1], k[2])
		material.set_shader_parameter(k[0], Vector3(c.r, c.g, c.b))
	material.set_shader_parameter("keeper", 1.0 if String(look.get("kind", "")) == "keeper" else 0.0)
	var tex := RiggedBody.DIR + ("woman" if bool(look.get("women", false)) else "man") + ".jpg"
	if ResourceLoader.exists(tex):
		material.set_shader_parameter("albedo_tex", load(tex))


## The stick: RiggedBody's mesh and materials, drawn in this body's top hand (a child of the body, so it moves with
## it between the frames it is posed), placed when the skeleton has its final pose.
func _make_stick() -> void:
	stick = MeshInstance3D.new()
	stick.name = "Stick"
	var src: MeshInstance3D = gb.rig.stick if gb.rig else null
	if src:
		stick.mesh = src.mesh
		for i in src.mesh.get_surface_count():
			stick.set_surface_override_material(i, src.get_surface_override_material(i))
	else:
		stick.mesh = RiggedBody.stick_mesh()
	stick.cast_shadow = body.mesh_instance.cast_shadow
	body.add_child(stick)
	body.posed.connect(_place_stick)


## The goalkeeper's helmet and cage (Rules 403) on this body's head: RiggedBody's shell and cage material, the face
## forward (+Z, the rig's rest).
func _make_helmet() -> void:
	var src: MeshInstance3D = null
	if gb.rig:
		for mi in gb.rig.find_children("*", "MeshInstance3D", true, false):
			if mi != gb.rig.mesh and mi != gb.rig.stick and (mi as MeshInstance3D).mesh is SphereMesh:
				src = mi
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	body.skeleton.add_child(att)
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	var j: Dictionary = body.joints
	var crown := 1.8 - (j["Head"] as Vector3).y
	var r := crown * 0.6
	sp.radius = r
	sp.height = r * 2.1
	sp.radial_segments = 16
	sp.rings = 10
	mi.mesh = sp
	mi.transform = Transform3D(Basis.IDENTITY, Vector3(0, crown * 0.52, 0.012))
	if src and src.material_override is ShaderMaterial:
		var m := (src.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		m.set_shader_parameter("fwd", Vector3(0, 0, 1))
		mi.material_override = m
	mi.cast_shadow = body.mesh_instance.cast_shadow
	att.add_child(mi)


## After player.gd has posed the game's body and placed him this frame (game seconds): drive this one.
func update(dt: float) -> void:
	if dt <= 0.0 or not is_visible_in_tree():
		return
	_dt = dt
	global_transform = Transform3D(Basis.IDENTITY, player.global_position)
	body.scale = gb.scale
	var act := player.act
	var want := "stick"
	if player.role == "G":
		want = "full"
	elif player.role == "R":
		want = "upper" if act.begins_with("signal_") else "move"
	elif act in FULL:
		want = "full"
	var pose := reader.read()
	if stick and want == "full" and pose.has("@hips"):
		pose["@hips"] = (pose["@hips"] as Vector3) + _shifts.get("full", Vector3.ZERO)
	var bp := {}
	if stick and want == "full":
		bp = reader.body_space(TRUNK + ARMS)
	match want:
		"stick":
			# Running with the stick: the legs (and the hips) the motion capture's, the trunk and both arms where the
			# game's body has them (in the body: the hands on the stick wherever the capture's hips turn).
			bp = reader.body_space(TRUNK + ARMS)
			pose = {}
		"upper":
			# A referee's signal over his run: his arms as the game has them.
			var up := {}
			for k in ARMS:
				if pose.has(k):
					up[k] = pose[k]
			pose = up
		"move":
			pose = {}
	legacy.set_pose(pose)
	if want != mode:
		var w := 0.0 if want == "move" else 1.0
		if mode == "":
			legacy.weight = w      # (a new body starts as the game's: no blend in from nothing)
		legacy.fade_to(w, 0.16)
		mode = want
	body.visible = true
	# Put somewhere new (a restart, back from the bench): the feet are not held where they were.
	if _at != Vector3.INF and player.global_position.distance_to(_at) > 1.5:
		loco.planter.reset()
	_at = player.global_position
	var yaw := PI * 0.5 - player.facing        # Player: rotation.y = PI/2 - facing; the rig faces +Z
	loco.drive(dt, Vector3(player.vel.x, 0, player.vel.y), yaw, Vector3(player.want_vel.x, 0, player.want_vel.y))
	# A move of the game's own has its feet where the game put them: the planter holds them only under the capture.
	loco.planter.enabled = mode != "full"
	if mode == "full":
		loco.yaw = yaw
		body.rotation.y = yaw
	# (The game's trunk and arms turned into this body's frame: the capture turns the body after the game's facing a
	# moment late, and the trunk, the hands and the stick face where the game's do.)
	var turn := (body.skeleton.global_transform.affine_inverse() * gb.skeleton.global_transform).basis.orthonormalized().get_rotation_quaternion()
	# And leant further forward over the stick by the lean (the rig's shoulders stand further back than the game's).
	var lean := Quaternion(Vector3.RIGHT, float(_leans.get(mode, 0.0))) if stick else Quaternion.IDENTITY
	for k in bp:
		var q: Quaternion = turn * (bp[k] as Quaternion)
		if k != "Head":
			q = (lean.slerp(Quaternion.IDENTITY, 0.5) if k == "Neck" else lean) * q
		bp[k] = q.normalized()
	legacy.body_pose = bp
	legacy.stick_on = false
	legacy.shift = Vector3.ZERO
	if stick:
		stick.visible = gb.has_stick()
		if stick.visible:
			_stick_space()
			body.grip(top, GRIP_R, 1.0, [_grip_pt[top], Vector3.BACK])
			body.grip(low, GRIP_R, 1.0, [_grip_pt[low], Vector3.BACK])
			if mode == "stick":
				legacy.shift = _shifts.get("stick", Vector3.ZERO)
	legacy.hold = {}
	# The skeleton's modifiers now, once (WsgBody.set_manual).
	body.advance(dt)


## The stick in this body's skeleton space this frame: where the game's body has it (so the blade is where the ball
## is), carried over into this body (which may face a little differently while the capture turns it).
func _stick_space() -> void:
	var to_rig := body.skeleton.global_transform.affine_inverse() * gb.skeleton.global_transform
	_rig_turn = to_rig.basis.orthonormalized().get_rotation_quaternion()
	legacy.stick = to_rig * gb.stick_transform()
	legacy.stick_on = true


var _rig_turn := Quaternion.IDENTITY


## Both fists on the shaft (StickLayer calls it as it runs, with the hips where they now are): each fist turned the
## least way from the game's hand that lays its grip along the shaft, the top one TOP_AT down from the grip's end and
## held to the hips, the lower one as far below it as the game's and held to the top hand; each slides along the
## shaft to where its arm can reach. lift: what the foot planter adds to the hips after.
func holds(sk: Skeleton3D, hips_g: Transform3D, lift: Vector3) -> Dictionary:
	var g := reader._last_global
	if not g.has(top + "Hand") or not g.has(low + "Hand"):
		return {}
	var sx: Transform3D = legacy.stick
	var down := -sx.basis.y.normalized()
	var hands := gb.stick_hands()
	var t_s := "r" if top == "Right" else "l"
	var l_s := "l" if t_s == "r" else "r"
	var v_top: Vector3 = (_grip_pt[top] as Vector3) - (body.joints[top + "Hand"] as Vector3)
	var v_low: Vector3 = (_grip_pt[low] as Vector3) - (body.joints[low + "Hand"] as Vector3)
	var qt := _along(_rig_turn * (g[top + "Hand"] as Quaternion), down)
	var ql := _along(_rig_turn * (g[low + "Hand"] as Quaternion), down)
	var spacing := maxf(0.12, float(hands.get(l_s, 0.23)) - float(hands.get(t_s, 0.03)))
	# Each fist slid along the shaft to where its arm reaches (the shoulders where the trunk now has them; the lift
	# not yet added): the top one never off the grip's end, the lower one at least a hand below it.
	var top_at := sx.origin - lift + down * TOP_AT
	var x_t := maxf(_slide(sk, top, top_at - qt * v_top, down), 0.03 - TOP_AT)
	var x_l := maxf(_slide(sk, low, top_at + down * (x_t + spacing) - ql * v_low, down), 0.1 - spacing)
	var hand_t := Transform3D(Basis(qt), sx.origin + down * (TOP_AT + x_t) - qt * v_top)
	var hand_l := Transform3D(Basis(ql), sx.origin + down * (TOP_AT + x_t + spacing + x_l) - ql * v_low)
	var in_hips := hips_g.affine_inverse() * Transform3D(hand_t.basis, hand_t.origin - lift)
	# (No handle given to the layer: its own slide and roll round the handle, searched each frame, cost a phone more
	# than all the rest of the hold.)
	return {top: ["Hips", in_hips, 1.0], low: [top + "Hand", hand_t.affine_inverse() * hand_l, 1.0]}


## How far along dir a wrist meant for wrist must move for the side's arm to reach it comfortably (WsgPoseLayer's own
## rule: within 0.97 of the arm, no nearer the shoulder than half of it): the nearer way; the nearest point of the
## line when it never comes within reach.
func _slide(sk: Skeleton3D, side: String, wrist: Vector3, dir: Vector3) -> float:
	var s := sk.get_bone_global_pose(sk.find_bone(side + "Arm")).origin
	var arm: float = _reach_len[side]
	var v := wrist - s
	var want := clampf(v.length(), arm * 0.5, arm * 0.97)
	if is_equal_approx(want, v.length()):
		return 0.0
	var b := v.dot(dir)
	var disc := b * b - (v.length_squared() - want * want)
	if disc < 0.0:
		return -b
	var r := sqrt(disc)
	return -b - r if absf(-b - r) < absf(-b + r) else -b + r


## A hand's turn (the rig's convention) turned the least way that lays its grip (across the palm, rest +Z) along dir.
static func _along(q0: Quaternion, dir: Vector3) -> Quaternion:
	var across := q0 * Vector3.BACK
	var to := dir if across.dot(dir) >= 0.0 else -dir
	return (Quaternion(across, to) * q0).normalized()


## The stick where the game's body has it, once the skeleton has its final pose; moved across (never more than a few
## cm) to run through the top fist should the arm not have quite reached it. Its place in the top hand is kept for the
## replay, which draws it so. And the hips: this body lowered (or raised) toward the game's top shoulder's height,
## a little each frame (the shift), so its hands reach the stick as the game's do.
func _place_stick() -> void:
	if stick == null or not stick.visible:
		return
	var hand := body.bone_world(top + "Hand")
	if replay_at != INF:
		stick.global_transform = hand * _replay_stick(replay_at)
		return
	var xf := body.skeleton.global_transform * legacy.stick
	var d := (xf.basis * Vector3.DOWN).normalized()
	var fist: Vector3 = hand * ((_grip_pt[top] as Vector3) - (body.joints[top + "Hand"] as Vector3))
	var v := fist - xf.origin
	var off := v - d * v.dot(d)
	var s := gb.global_transform.basis.get_scale().y
	xf.origin += off.limit_length(0.06 * s)
	# And turned about the top fist (at most 10 degrees) to run through the lower one, should that arm not have
	# reached the shaft (a pass's follow-through across the chest).
	var lo: Vector3 = body.bone_world(low + "Hand") * ((_grip_pt[low] as Vector3) - (body.joints[low + "Hand"] as Vector3))
	var pivot := xf.origin + d * d.dot(fist - xf.origin)
	var a := (xf * Vector3(0, -Body.STICK_LEN * 0.5, 0)) - pivot
	var b := lo - pivot
	b -= d * minf(0.0, b.dot(d))     # (only toward a fist below the top one)
	if b.length() > 0.08 * s and a.angle_to(b) > 0.005:
		var ang := minf(a.angle_to(b), deg_to_rad(10.0))
		var ax := a.cross(b).normalized()
		if ax.is_normalized():
			var r := Basis(ax, ang)
			xf = Transform3D(r * xf.basis, pivot + r * (xf.origin - pivot))
	stick.global_transform = xf
	if measure:
		_measure(xf)
	var now := clock()
	if _history.is_empty() or now > float(_history[-1][0]):
		_history.append([now, hand.affine_inverse() * xf])
		while _history.size() > 2 and float(_history[0][0]) < now - 12.0:
			_history.pop_front()
	var t_s := "r" if top == "Right" else "l"
	var inv := body.global_transform.affine_inverse()
	# (Nearer the stick than the game's by what this body's arm is shorter, the fists reaching the shaft: each shoulder
	# within its arm of its fist's place, the top hand's counting most.)
	var game_sh := inv * (gb.skeleton.global_transform * gb.shoulder(t_s))
	var err := Vector3.ZERO
	var spacing := maxf(0.12, float(gb.stick_hands().get("l" if t_s == "r" else "r", 0.23)) - float(gb.stick_hands().get(t_s, 0.03)))
	for k in 2:
		var side := top if k == 0 else low
		var grip := inv * (xf * Vector3(0, -(TOP_AT + spacing * k), 0))
		var sh := inv * body.bone_world(side + "Arm").origin
		var from := game_sh if k == 0 else sh
		var arm: float = _arm_len[side]
		var want_sh := grip + (from - grip).normalized() * clampf(from.distance_to(grip), arm * 0.62, arm - 0.03)
		err += (want_sh - sh) * (0.65 if k == 0 else 0.35)
	# Forward: mostly a further lean of the trunk (the hips carried forward took the legs into the stick), the rest the
	# hips; down and sideways the hips.
	var lean := clampf(float(_leans.get(mode, 0.0)) + err.z / 0.45 * 0.3, 0.0, 0.35)
	_leans[mode] = lean
	var shift: Vector3 = _shifts.get(mode, Vector3.ZERO) + err * 0.35
	_shifts[mode] = Vector3(clampf(shift.x, -0.08, 0.08), clampf(shift.y, -0.32, 0.04), clampf(shift.z, -0.04, 0.05))


## The hips moved (this body's skeleton space) so its top shoulder is where the game's is: lower and further forward
## (the rig's chest stands taller and its shoulders further back than the game's floorball stance).
var _shifts := {}             # mode -> Vector3
var _leans := {}              # mode -> radians the trunk is leant further forward


func _replay_stick(t: float) -> Transform3D:
	var i := 0
	while i < _history.size() - 1 and float(_history[i + 1][0]) <= t:
		i += 1
	var a: Array = _history[i]
	var b: Array = _history[mini(i + 1, _history.size() - 1)]
	var w := 0.0 if a == b else clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4), 0.0, 1.0)
	return (a[1] as Transform3D).interpolate_with(b[1], w)


## Set (the tests, the close-up tools): each posed frame keeps the fists' middles' distance from the shaft's axis, in
## last_fists {side: m}.
var measure := false
var last_fists := {}


func _measure(xf: Transform3D) -> void:
	var dir := (xf.basis * Vector3.DOWN).normalized()
	for side in [top, low]:
		var hand := body.bone_world(side + "Hand")
		var p: Vector3 = hand * ((_grip_pt[side] as Vector3) - (body.joints[side + "Hand"] as Vector3))
		var v := p - xf.origin
		last_fists[side] = (v - dir * v.dot(dir)).length()
		last_fists[side + "_along"] = v.dot(dir)
	var want := gb.skeleton.global_transform * (gb.stick_transform() * Vector3(0, -Body.STICK_LEN, 0))
	last_fists["heel"] = (xf * Vector3(0, -Body.STICK_LEN, 0)).y - want.y
	last_fists["crouch"] = [_shifts.get(mode, Vector3.ZERO), rad_to_deg(float(_leans.get(mode, 0.0)))]
	var t_s := "r" if top == "Right" else "l"
	var inv := body.global_transform.affine_inverse()
	var game_sh := inv * (gb.skeleton.global_transform * gb.shoulder(t_s))
	var rig_sh := inv * body.bone_world(top + "Arm").origin
	last_fists["sh_diff"] = rig_sh - game_sh
	last_fists["reach"] = rig_sh.distance_to(inv * (xf * Vector3(0, -TOP_AT, 0)))
	last_fists["game_reach"] = game_sh.distance_to(inv * (gb.skeleton.global_transform * (gb.stick_transform() * Vector3(0, -TOP_AT, 0))))


## The game's poses over the capture (WsgPoseLayer), and the hands on the stick: the holds worked out as it runs,
## once the hips are where they will be (the game's, or the capture's moved by the shift), against the stick in
## this body's space; the planter's lift after it allowed for.
class StickLayer extends WsgPoseLayer:
	var link: FoundationLink
	var stick := Transform3D()    # skeleton space, as drawn (after the planter's lift)
	var stick_on := false
	var shift := Vector3.ZERO     # the capture's hips moved by (running with the stick: lower, further forward)

	func _process_modification_with_delta(delta: float) -> void:
		var sk := get_skeleton()
		if sk != null and link != null and (weight > 0.0 or _target > 0.0):
			var w := smoothstep(0.0, 1.0, weight)
			var hi := sk.find_bone("Hips")
			# (What the layer does to the hips anyway, done first so the holds are made against it; done again by it
			# changes nothing.)
			if pose.has("Hips"):
				sk.set_bone_pose_rotation(hi, sk.get_bone_pose_rotation(hi).slerp(pose["Hips"], w))
			if hips != Vector3.INF:
				sk.set_bone_pose_position(hi, sk.get_bone_pose_position(hi).lerp(sk.get_bone_rest(hi).origin + hips - Vector3(0, lift_after, 0), w))
			elif shift != Vector3.ZERO:
				sk.set_bone_pose_position(hi, sk.get_bone_pose_position(hi) + shift * w)
			hold = {}
			if stick_on:
				# (The trunk too - where the shoulders will be - as the layer will lay it.)
				for b in ["Spine", "Spine1", "Spine2", "LeftShoulder", "RightShoulder"]:
					if body_pose.has(b):
						var i := sk.find_bone(b)
						var pq := sk.get_bone_global_pose(sk.get_bone_parent(i)).basis.get_rotation_quaternion()
						sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i).slerp((pq.inverse() * (body_pose[b] as Quaternion)).normalized(), w))
				hold = link.holds(sk, sk.get_bone_global_pose(hi), Vector3(0, lift_after, 0))
		super(delta)
