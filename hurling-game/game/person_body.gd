class_name PersonBody
extends ToonBody
## An official drawn from a Meshy model (assets/people, baked by tools/player/build_people.sh the way the hurlers are):
## the referee and the linesmen in black, the umpires in their long white coats and caps. Their meshes sit on
## ToonBody's seventeen bones, so the officials' signals (player.gd) play on them as before. Drawn with the model's
## own texture, lit as the players are (a soft step from the sun, a rim). (Round five: "make the referees look better
## and more realistic".)

const DIR := "res://assets/people/"

static var _data := {}         # name -> its offsets
static var _meshes := {}
static var _mats := {}

var who := "referee"
var dir := DIR


func _init(p_look := {}) -> void:
	super(p_look)
	who = String(p_look.get("model", "umpire" if String(p_look.get("kind", "")) == "umpire" else "referee"))
	dir = String(p_look.get("dir", DIR))   # tools/crowd draws the fans this way


func _offsets() -> Array:
	if not _data.has(who):
		_data[who] = JSON.parse_string(FileAccess.get_file_as_string(dir + who + ".json")).offsets
	var off: Dictionary = _data[who]
	var out := []
	for b in BONES:
		var a: Array = off[b[0]]
		out.append(Vector3(a[0], a[1], a[2]))
	return out


func _dress() -> void:
	if not _meshes.has(who):
		_meshes[who] = load(dir + who + ".res")
	mesh_instance.mesh = _meshes[who]
	# The texture: 512 on Low, 1024 (<who>_hd.jpg) on Medium and High.
	var tex := Game.hd(dir + who + ".jpg")
	if not _mats.has(tex):
		var m := ShaderMaterial.new()
		m.shader = _shader()
		m.set_shader_parameter("albedo", load(tex))
		_mats[tex] = m
	mesh_instance.material_override = _mats[tex]


static var _sh: Shader


static func _shader() -> Shader:
	if _sh == null:
		_sh = Shader.new()
		_sh.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform vec3 light_dir = vec3(0.35, 0.85, 0.4);
uniform float shade = 0.72;
varying vec3 wn;
void vertex() { wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	vec3 c = texture(albedo, UV).rgb;
	float d = dot(normalize(wn), normalize(light_dir));
	float k = mix(shade, 1.0, smoothstep(-0.35, 0.3, d));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * 0.18;
	ALBEDO = c * k + rim * 0.5;
}
"""
	return _sh
