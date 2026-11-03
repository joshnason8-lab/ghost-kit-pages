extends SceneTree
## The props' audit over a game's own matches (the owner: nobody ever walks through a table or a bench; the ball
## bounces off them). For each venue the game's registry plays Watch-AI matches at sim speed, handing every body and
## the ball to a WsgPropAudit each frame; this writes prop_audit.json (every body more than 2 cm into a prop, every
## ball step through one, the worst of each) and, where it can draw, a sheet of close-ups of the worst cases per venue
## (the props' wire boxes yellow, the body red, the ball's step red). Exits 1 on any case.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/prop_audit.gd -- res://game/prop_runs.gd "$RUNNER_TEMP/prop_audit" [matches] [seconds]
## OUT must be outside the project (an export would pack the sheets: Floorball's APK went from 89 MB to 155 MB).
##
## The registry (the game's; tests/prop_runs.gd is the foundation's own):
##   static func venues() -> Array                       # the venues' names
##   func run(venue: String, seed: int, seconds: float, audit: WsgPropAudit, tree: SceneTree) -> Node
##       # a coroutine: builds a Watch-AI match at the venue, sets audit.solid to its WsgSolidProps, plays SECONDS of it
##       # (Engine.time_scale as fast as it stays right), calling audit.body / audit.ball / audit.ball_reset / audit.tick
##       # every frame; returns the match's root, left in the tree for the close-ups (this frees it)

const SHOTS := 6
const W := 640
const H := 400


func _initialize() -> void:
	await process_frame
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		printerr("prop_audit: -- <registry.gd> <out dir> [matches] [seconds]")
		quit(2)
		return
	var out_dir := String(a[1])
	var abs_out := ProjectSettings.globalize_path(out_dir) if out_dir.begins_with("res://") or out_dir.begins_with("user://") else out_dir
	var project := ProjectSettings.globalize_path("res://").simplify_path()
	if abs_out.simplify_path().begins_with(project) or out_dir.begins_with("res://"):
		printerr("prop_audit: write outside the project (%s is in it: an export would pack the sheets)" % out_dir)
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(abs_out)
	var matches := int(a[2]) if a.size() > 2 else 2
	var seconds := float(a[3]) if a.size() > 3 else 120.0
	var reg_script: Script = load(a[0])
	var reg: Object = reg_script.new()
	var all := {}
	var ok := true
	var can_draw := DisplayServer.get_name() != "headless"
	for venue in reg_script.call("venues"):
		var audit := WsgPropAudit.new()
		var scene: Node = null
		for m in matches:
			if scene:
				scene.queue_free()
				await process_frame
			scene = await reg.call("run", String(venue), 1000 + m, seconds, audit, self)
		var rep := audit.report()
		all[venue] = rep
		ok = ok and bool(rep.pass)
		print("%s: %d body frames, %d inside a prop; %d ball steps, %d through one%s" % [venue, rep.body_checks, rep.body_cases,
			rep.ball_steps, rep.ball_tunnels, "" if rep.pass else " - FAIL"])
		for c in (rep.worst as Array).slice(0, 6):
			print("  %s %s: %.3f m into %s at %s" % [c.kind, c.who, c.depth, c.prop, c.pos])
		if can_draw and scene and not (audit.worst as Array).is_empty():
			await _sheet(scene, audit, abs_out.path_join(String(venue).validate_filename() + ".png"))
		if scene:
			scene.queue_free()
			await process_frame
	var f := FileAccess.open(abs_out.path_join("prop_audit.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"pass": ok, "venues": all}, "  "))
	f.close()
	print("PROP AUDIT: ", "PASS" if ok else "FAIL", " (", abs_out.path_join("prop_audit.json"), ")")
	quit(0 if ok else 1)


## Close-ups of the worst cases: two views of each (from the front and from the side), two cases a row.
func _sheet(scene: Node, audit: WsgPropAudit, path: String) -> void:
	var holder := Node3D.new()
	scene.add_child(holder)
	holder.add_child(audit.solid.debug_mesh())
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(1, 0.1, 0.1, 0.6)
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.no_depth_test = true
	var cases: Array = audit.worst.slice(0, SHOTS)
	for c: Dictionary in cases:
		var mi := MeshInstance3D.new()
		if c.kind == "body":
			var cap := CapsuleMesh.new()
			cap.radius = c.radius
			cap.height = c.height
			mi.mesh = cap
			mi.position = (c.pos as Vector3) + Vector3.UP * float(c.height) * 0.5
		else:
			var sp := SphereMesh.new()
			sp.radius = c.radius
			sp.height = float(c.radius) * 2.0
			mi.mesh = sp
			mi.position = c.pos
			var line := ImmediateMesh.new()
			line.surface_begin(Mesh.PRIMITIVE_LINES)
			line.surface_add_vertex(c.from)
			line.surface_add_vertex(c.to)
			line.surface_end()
			var lm := MeshInstance3D.new()
			lm.mesh = line
			lm.material_override = red
			holder.add_child(lm)
		mi.material_override = red
		holder.add_child(mi)
	var cam := Camera3D.new()
	cam.fov = 55.0
	holder.add_child(cam)
	cam.make_current()
	var vp := root.get_viewport()
	var shots := []
	for c: Dictionary in cases:
		var at: Vector3 = (c.pos as Vector3) + Vector3.UP * 0.6
		for dir in [Vector3(0.0, 0.55, 1.0), Vector3(1.0, 0.55, 0.0)]:
			cam.global_position = at + (dir as Vector3).normalized() * 3.5
			cam.look_at(at, Vector3.UP)
			for k in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.resize(W, H)
			shots.append(img)
	var cols := 4
	var rows := ceili(shots.size() / float(cols))
	var sheet := Image.create(W * cols, H * rows, false, shots[0].get_format())
	for k in shots.size():
		sheet.blit_rect(shots[k], Rect2i(0, 0, W, H), Vector2i((k % cols) * W, (k / cols) * H))
	sheet.save_png(path)
	print("  close-ups: ", path)
	holder.queue_free()
