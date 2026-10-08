extends Control
## Champions! A golden trophy on a podium, the team around it, confetti and a roaring crowd.

var team := ""
var title := ""
var back := "res://ui/main_menu.gd"
var _cam: Camera3D
var _trophy: Node3D
var _t := 0.0


func setup(args: Dictionary) -> void:
	team = String(args.get("team", "MUM"))
	title = String(args.get("title", ""))
	back = String(args.get("back", back))


func _ready() -> void:
	UI.screen(self, true)
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_2X
	svc.add_child(sv)
	var t := DB.team(team)
	var arena := Arena.new()
	sv.add_child(arena)
	arena.build("stadium" if t.kind == "country" else "dome", t.c1, t.c2, title.to_upper())
	arena.excite(1.0)
	_trophy = _make_trophy()
	_trophy.position = Vector3(0, 0, 0)
	sv.add_child(_trophy)
	var squad: Array = DB.team(team).squad
	if Game.get_season() and Game.get_season().team == team:
		squad = Game.get_season().squads[team]
	for i in mini(7, squad.size()):
		var a := Athlete.new()
		a.setup(squad[i], 0, t.c1, t.c2, false)
		sv.add_child(a)
		var ang := PI + (i - 3) * 0.32
		a.position = Vector3(sin(ang) * 2.4, 0, cos(ang) * 2.4)
		a.facing = (Vector3.ZERO - a.position).normalized() * -1.0
		a.set_state("celebrate" if i % 2 == 0 else "roar")
	_confetti(sv, t.c1, t.c2)
	_cam = Camera3D.new()
	_cam.fov = 50
	sv.add_child(_cam)
	_cam.current = true
	Sfx.crowd(1.0)
	Sfx.drums(true)
	Sfx.play("roar", -2.0)
	Sfx.play("crowd_chant", -6.0)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 48
	v.offset_top = 30
	v.offset_bottom = -30
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	v.add_child(UI.label(title.to_upper(), "EyebrowLabel", 20, Game.C_GOLD))
	var champ := UI.label(tr("CHAMPIONS"), "TitleLabel", 110, Game.C_GOLD)
	champ.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	champ.add_theme_constant_override("outline_size", 16)
	v.add_child(champ)
	v.add_child(UI.label(DB.team_name(team), "HeaderLabel", 54))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	var go := UI.button(tr("CONTINUE"), true, func():
		Sfx.stop_all()
		Game.show_screen(back))
	go.custom_minimum_size = Vector2(320, 70)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(go)
	champ.pivot_offset = Vector2(300, 60)
	champ.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(champ, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_trophy() -> Node3D:
	var root := Node3D.new()
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("e6b422")
	gold.metallic = 1.0
	gold.roughness = 0.22
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("1b1b1b")
	dark.roughness = 0.4
	var parts := [
		# [mesh, material, y, radius_top, radius_bottom, height]
		["cyl", dark, 0.25, 0.55, 0.65, 0.5],
		["cyl", dark, 0.62, 0.42, 0.5, 0.25],
		["cyl", gold, 0.85, 0.12, 0.3, 0.2],
		["cyl", gold, 1.05, 0.08, 0.12, 0.25],
		["cyl", gold, 1.45, 0.42, 0.14, 0.55],
		["cyl", gold, 1.76, 0.45, 0.42, 0.08],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = p[3]
		c.bottom_radius = p[4]
		c.height = p[5]
		c.radial_segments = 40
		mi.mesh = c
		mi.material_override = p[1]
		mi.position.y = p[2]
		root.add_child(mi)
	for sgn in [-1.0, 1.0]:
		var h := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.16
		tor.outer_radius = 0.22
		h.mesh = tor
		h.material_override = gold
		h.position = Vector3(sgn * 0.48, 1.45, 0)
		h.rotation = Vector3(PI / 2, 0, 0)
		root.add_child(h)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.6, 1.5)
	light.light_energy = 2.0
	light.light_color = Color("fff1c4")
	root.add_child(light)
	return root


func _confetti(parent: Node, c1: Color, c2: Color) -> void:
	for col in [c1, c2, Game.C_GOLD]:
		var p := GPUParticles3D.new()
		p.amount = 220
		p.lifetime = 4.0
		p.position = Vector3(0, 7, 0)
		p.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(5, 0.5, 5)
		pm.direction = Vector3(0, -1, 0)
		pm.initial_velocity_min = 0.5
		pm.initial_velocity_max = 1.5
		pm.gravity = Vector3(0, -1.6, 0)
		pm.angular_velocity_min = -360
		pm.angular_velocity_max = 360
		pm.turbulence_enabled = true
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.07, 0.11)
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		q.material = m
		p.draw_pass_1 = q
		parent.add_child(p)


func _process(delta: float) -> void:
	_t += delta
	if _trophy:
		_trophy.rotation.y = _t * 0.6
	if _cam:
		var a := 0.3 + sin(_t * 0.2) * 0.4
		_cam.position = Vector3(sin(a) * 5.5, 2.2, cos(a) * 5.5)
		_cam.look_at(Vector3(-0.9, 1.2, 0), Vector3.UP)
