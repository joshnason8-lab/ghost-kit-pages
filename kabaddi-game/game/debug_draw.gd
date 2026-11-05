class_name DebugDraw
extends MeshInstance3D
## What the match is thinking, drawn on the court (off unless config.debug_draw is set; tests and recordings
## turn it on): each defender's place in the team's plan (a ring in his role's colour, a line from him to it),
## the holds' hand targets (white crosses) and held feet (magenta), and planted feet (yellow).

const ROLE_COL := {"line": Color(0.6, 0.6, 0.6), "mark": Color(1.0, 0.3, 0.2), "cover": Color(1.0, 0.65, 0.2),
	"lane": Color(0.2, 0.9, 1.0), "contain": Color(0.3, 0.5, 1.0), "help": Color(1.0, 0.2, 0.9)}

var m   # the Match
var _im := ImmediateMesh.new()


func _init(p_match) -> void:
	m = p_match
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	material_override = mat


func _process(_dt: float) -> void:
	_im.clear_surfaces()
	if m.raider == null or m.phase != "raid":
		return
	var lines := []   # [from, to, colour]
	for d in m.defenders():
		var o: Array = m.defence.order(d) if m.defence else []
		if o.is_empty() or not d.state in ["ready", "idle"]:
			continue
		var c: Color = ROLE_COL.get(String(o[2]), Color.WHITE)
		var at: Vector3 = o[0]
		lines.append([d.position + Vector3.UP * 0.03, at + Vector3.UP * 0.03, c])
		for k in 16:
			var a := TAU * k / 16.0
			var b := TAU * (k + 1) / 16.0
			lines.append([at + Vector3(cos(a), 0.03, sin(a)) * 0.25, at + Vector3(cos(b), 0.03, sin(b)) * 0.25, c])
	if m.grapple and m.grapple.state != "done":
		for h in m.grapple.holds:
			for g in m.grapple.hand_goals(h.who):
				_cross(lines, g[1], 0.06, Color.WHITE)
			if String(h.slot).begins_with("leg_"):
				_cross(lines, h.at, 0.08, Color(1.0, 0.2, 0.9))
	for a in m.athletes:
		if a.on_mat and a.model and a.model.rig:
			for s in a.model.rig._plant:
				_cross(lines, a.model.rig._plant[s][0], 0.05, Color(1.0, 0.9, 0.2))
	if lines.is_empty():
		return
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	for l in lines:
		_im.surface_set_color(l[2])
		_im.surface_add_vertex(l[0])
		_im.surface_set_color(l[2])
		_im.surface_add_vertex(l[1])
	_im.surface_end()


func _cross(lines: Array, p: Vector3, r: float, c: Color) -> void:
	lines.append([p - Vector3(r, 0, 0), p + Vector3(r, 0, 0), c])
	lines.append([p - Vector3(0, r, 0), p + Vector3(0, r, 0), c])
	lines.append([p - Vector3(0, 0, r), p + Vector3(0, 0, r), c])
