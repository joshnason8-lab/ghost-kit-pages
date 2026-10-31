class_name PersonBody
extends ToonBody
## An official drawn from a Meshy model (assets/people, baked by tools/player/build_people.sh the way the hurlers are):
## the referee and the linesmen in black, the umpires in their long white coats and caps. Their meshes sit on
## ToonBody's seventeen bones, so the officials' signals (player.gd) play on them as before. Drawn with the model's
## own texture, lit as the players are (a soft step from the sun, a rim). (Round five: "make the referees look better
## and more realistic".)

const DIR := "res://assets/people/"
const ULTRA_DIR := "res://ultra/people/"

static var _data := {}         # name -> its offsets
static var _meshes := {}
static var _mats := {}

var who := "referee"
var dir := DIR
var stem := "referee"   # the model's files: <who> on Low (and with the HD pack, in ULTRA_DIR), <who>_full otherwise


func _init(p_look := {}) -> void:
	super(p_look)
	who = String(p_look.get("model", "umpire" if String(p_look.get("kind", "")) == "umpire" else "referee"))
	dir = String(p_look.get("dir", DIR))   # tools/crowd draws the fans this way
	stem = who
	# High with the HD pack: the officials re-made by Meshy with their physically based maps (normal, roughness), at full detail.
	if dir == DIR and Ultra.active() and ResourceLoader.exists(ULTRA_DIR + who + ".res"):
		dir = ULTRA_DIR
	elif dir == DIR and int(Game.settings.graphics) != Game.GFX_LOW and ResourceLoader.exists(DIR + who + "_full.res"):
		# Medium and High: the Meshy model whole (about 8,400 triangles, with its own levels for far away). Cut down
		# to half, as Low still is, its triangles' edges crossed the borders between the pieces of its texture and
		# showed slivers of the wrong colour (dark cracks across the face, pale flecks on the trousers).
		stem = who + "_full"


## The Meshy models were made with their arms out and palms up (an A-pose); brought down to the game's stance the
## palms faced forward, like a shop dummy. Each arm is turned about its own length so the palms face the thighs as the
## hurlers' do, and every pose the game gives the arms reads on the officials as on the hurlers: degrees at the
## shoulder and in the forearm (the left arm; the right mirrors it), each model its own (Low's are the older, lighter
## models). The shoulder's turn sets the way the elbow bends: at 160 it bends forward, the hands coming up in front as a
## man's do (with less, the officials' elbows bent backward, the hands behind the hips: the owner saw "the refs'
## elbows bend the wrong way"); the forearm turns back by as much, so the palms still face the thighs. Found by eye from
## the side, standing with the elbows bent, signalling and running.
const TWIST := {"referee": [160.0, -250.0], "umpire": [160.0, -70.0], "referee_low": [160.0, -250.0],
	"umpire_low": [160.0, -250.0]}


## The Meshy models' feet were made pitched up at the ankle (toes to the sky, the owner saw); each foot is turned down
## by this much (degrees, toes down) so it stands flat. Found by eye from the side, each model its own.
static var foot_pitch := {"referee": 35.0, "umpire": 38.0, "referee_low": 35.0, "umpire_low": 38.0}


func apply(p: Dictionary) -> void:
	super(p)
	if skeleton == null or dir not in [DIR, ULTRA_DIR]:
		return
	var tw: Array = TWIST.get(_twist_key(), [0.0, 0.0])
	for side in [[5, 6, 1.0], [8, 9, -1.0]]:
		for j in 2:
			var b: int = side[j]
			var q := skeleton.get_bone_pose_rotation(b)
			skeleton.set_bone_pose_rotation(b, q * Quaternion(Vector3.UP, deg_to_rad(float(tw[j]) * float(side[2]))))
	# The shoulder lifts with the arm: an arm raised high (a flag, a card) turned about a joint as low as the armpit,
	# and came out of the coat's side under the shoulder, as if not joined to it (the owner's screenshot). Each
	# shoulder rises and comes in as the arm goes above level, as a man's collarbone does.
	var chest := skeleton.get_bone_global_pose(2).basis
	for side in [[5, 1.0], [8, -1.0]]:
		var b: int = side[0]
		var arm := (chest.inverse() * skeleton.get_bone_global_pose(b).basis * Vector3.DOWN).normalized()
		var up := smoothstep(0.1, 0.95, arm.y)   # 0 at level, 1 overhead
		skeleton.set_bone_pose_position(b, skeleton.get_bone_rest(b).origin + Vector3(-0.025 * float(side[1]), 0.085, 0.0) * up)
	var fp := float(foot_pitch.get(_twist_key(), 0.0))
	if fp != 0.0:
		for b in [13, 16]:
			var q := skeleton.get_bone_pose_rotation(b)
			skeleton.set_bone_pose_rotation(b, q * Quaternion(Vector3.RIGHT, deg_to_rad(fp)))


func _twist_key() -> String:
	return who if stem != who or dir == ULTRA_DIR else who + "_low"


## How far the right hand is turned (degrees about the arm), for what it holds (a flag, a card) to be turned back.
func right_turn() -> float:
	var tw: Array = TWIST.get(_twist_key(), [0.0, 0.0])
	return -(float(tw[0]) + float(tw[1]))


func _offsets() -> Array:
	if not _data.has(dir + stem):
		_data[dir + stem] = JSON.parse_string(FileAccess.get_file_as_string(dir + stem + ".json")).offsets
	var off: Dictionary = _data[dir + stem]
	var out := []
	for b in BONES:
		var a: Array = off[b[0]]
		out.append(Vector3(a[0], a[1], a[2]))
	return out


func _dress() -> void:
	if not _meshes.has(dir + stem):
		_meshes[dir + stem] = load(dir + stem + ".res")
	mesh_instance.mesh = _meshes[dir + stem]
	relook()


func relook() -> void:
	if mesh_instance == null:
		return
	# The texture: 512 on Low, 1024 (<who>_full.jpg) on Medium and High, 2048 with its maps with the HD pack; lit on
	# High (on Vulkan). (The crowd's fans: <model>.jpg, or <model>_hd.jpg for the sharper sheet.)
	var ultra := dir == ULTRA_DIR
	var lit := Ultra.lit() and dir in [DIR, ULTRA_DIR]
	var tex := dir + stem + ".jpg" if ultra or stem != who or dir == DIR else Game.hd(dir + who + ".jpg")
	if not _mats.has(tex + str(lit)):
		var m := ShaderMaterial.new()
		m.shader = _ultra_shader() if lit else _shader()
		m.set_shader_parameter("albedo", load(tex))
		if ultra:
			m.set_shader_parameter("normal_map", load(dir + who + "_normal.png"))
			m.set_shader_parameter("rough", load(dir + who + "_rough.jpg"))
		_mats[tex + str(lit)] = m
	mesh_instance.material_override = _mats[tex + str(lit)]


static var _sh: Shader


static var _ush: Shader


## High (on Vulkan): lit by the scene's light; with the HD pack, the model's own normal and roughness maps.
static func _ultra_shader() -> Shader:
	if _ush == null:
		_ush = Shader.new()
		_ush.code = """
shader_type spatial;
render_mode cull_back;
#include "res://game/shaders/look.gdshaderinc"
uniform sampler2D albedo : filter_linear_mipmap;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;
uniform sampler2D rough : hint_roughness_r, filter_linear_mipmap;
void fragment() {
	ALBEDO = compat_to_scene(texture(albedo, UV).rgb);
	NORMAL_MAP = texture(normal_map, UV).rgb;
	ROUGHNESS = texture(rough, UV).r;
	SPECULAR = 0.35;
	RIM = 0.2;
	RIM_TINT = 0.5;
}
"""
	return _ush


static func _shader() -> Shader:
	if _sh == null:
		_sh = Shader.new()
		_sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
#include "res://game/shaders/look.gdshaderinc"
uniform sampler2D albedo : filter_linear_mipmap;
uniform vec3 light_dir = vec3(0.35, 0.85, 0.4);
uniform float shade = 0.72;
// The model's relief (the HD model's own normal map on its cuts, the shared foundation): 0 none.
uniform sampler2D nmap : hint_normal, filter_linear_mipmap;
uniform float nmap_k = 0.0;
varying vec3 wn;
varying vec3 wt;
varying vec3 wb;
void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wt = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz);
	wb = normalize((MODEL_MATRIX * vec4(BINORMAL, 0.0)).xyz);
}
void fragment() {
	vec3 c = texture(albedo, UV).rgb;
	vec2 nxy = texture(nmap, UV).rg * 2.0 - 1.0;
	vec3 nt = vec3(nxy, sqrt(max(1.0 - dot(nxy, nxy), 0.0)));
	vec3 n = normalize(mix(normalize(wn), normalize(wt * nt.x + wb * nt.y + wn * nt.z), nmap_k));
	vec3 vn = normalize(mix(NORMAL, normalize(TANGENT * nt.x + BINORMAL * nt.y + NORMAL * nt.z), nmap_k));
	float d = dot(n, normalize(light_dir));
	float k = mix(shade, 1.0, smoothstep(-0.35, 0.3, d));
	float rim = pow(1.0 - clamp(dot(vn, VIEW), 0.0, 1.0), 3.0) * 0.18;
	ALBEDO = compat_to_scene(c * k + rim * 0.5);
}
"""
	return _sh
