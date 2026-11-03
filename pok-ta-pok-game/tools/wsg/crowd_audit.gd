extends SceneTree
## A game's crowds, venue by venue, measured and photographed (the owner's check: fans sitting on their seats, not in
## them, soles on the floor, facing the play, standing properly). For each venue its game registers, the 3D crowd is
## built (WsgCrowd3D.build_venue) and audited (WsgCrowdVenue.audit: every fan), and so are the Low cards
## (WsgCrowdCards on every place), and a contact sheet is written: each section close up from in front and from the
## side, seated and on their feet (a big moment), in 3D and as Low cards, with its numbers.
##   xvfb-run -a godot --path <game> --rendering-driver opengl3 -s res://tools/wsg/crowd_audit.gd -- <registry.gd> <out dir> [quality]
## registry.gd (the game's, e.g. res://game/crowd_venues.gd): `static func venues() -> Array` of {"name": String,
## "venue": WsgCrowdVenue, "scene": optional path of the venue's scene (drawn instead of the plain boxes)}.
## Writes <out>/<venue>.png and <out>/crowd_audit.json; exits 1 if any venue fails.

## Each close-up (phone-legible: two a row, the owner reads them on a phone).
const CELL := Vector2i(720, 450)


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 2:
		printerr("crowd_audit: -- <registry.gd> <out dir> [quality]")
		quit(2)
		return
	var reg: GDScript = load(a[0])
	var out_dir: String = a[1]
	var quality := int(a[2]) if a.size() > 2 else 2
	DirAccess.make_dir_recursive_absolute(out_dir)
	var report := {}
	var failed := false
	for entry in reg.venues():
		var name: String = entry.name
		var venue: WsgCrowdVenue = entry.venue
		var res: Dictionary = await _venue(name, venue, entry.get("scene", ""), quality, out_dir)
		report[name] = res
		print("%s: %d fans (3D), %d cards (Low), %s" % [name, res.fans, res.low.cards, "PASS" if res.fails.is_empty() else "FAIL"])
		print("  %-22s cards: hips %s  facing <= %.0f deg" % ["Low", _range(res.low.hips), res.low.facing])
		for s in res.sections:
			var r: Dictionary = res.sections[s]
			print("  %-22s %4d fans  hips %s  feet %s  inside %.3f  facing <= %.0f deg  backwards %d" % [s, r.fans,
				_range(r.hips), _range(r.feet), r.inside, r.facing, r.backwards])
		for f in res.fails:
			printerr("  FAIL: ", f)
		failed = failed or not res.fails.is_empty()
	var f := FileAccess.open(out_dir.path_join("crowd_audit.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	print("CROWD AUDIT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


static func _range(r: Array) -> String:
	if r[0] == INF:
		return "  -  "
	return "%+.3f..%+.3f" % [r[0], r[1]]


func _venue(name: String, venue: WsgCrowdVenue, scene: String, quality: int, out_dir: String) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = CELL
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.7, 0.82)
	env.environment.ambient_light_color = Color(0.9, 0.9, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	vp.add_child(sun)
	if scene != "":
		vp.add_child((load(scene) as PackedScene).instantiate())
	var crowd := WsgCrowd3D.new()
	vp.add_child(crowd)
	crowd.build_venue(venue, quality, venue.play_centre, 1.0, 7)
	crowd.set_looks(WsgCrowd3D.LOOKS.skin, WsgCrowd3D.LOOKS.hair, WsgCrowd3D.LOOKS.legs)
	crowd.watch_ball(venue.play_centre)
	if scene == "":
		_boxes(vp, crowd.placed.obstacles, venue)
	var res := WsgCrowdVenue.audit(crowd, venue, 0)
	# Low: the same places as cards (every one), measured too.
	var cards := WsgCrowdCards.new()
	vp.add_child(cards)
	cards.build(crowd.placed, PackedInt32Array(), 7)
	cards.set_looks(WsgCrowd3D.LOOKS.skin, WsgCrowd3D.LOOKS.hair, WsgCrowd3D.LOOKS.legs)
	cards.visible = false
	var low: Dictionary = cards.audit(venue, crowd.placed)
	res["low"] = low
	res.fails.append_array(low.fails)
	var cam := Camera3D.new()
	cam.fov = 50
	vp.add_child(cam)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(10, 8)
	vp.add_child(label)
	# Each section: [in front, seated], [side, seated], [in front, up], [side, up].
	var shots := []
	for s in venue.sections:
		var fr := venue.frame(s)
		var along: Vector3 = fr[0]
		var away: Vector3 = fr[1]
		var length: float = fr[2]
		var mid: Vector3 = (s.a + s.b) * 0.5 + away * minf(s.rows, 3) * s.tread * 0.5 + Vector3.UP * minf(s.rows, 3) * s.rise * 0.5
		var front := mid - away * 4.5 + along * 1.2 + Vector3.UP * 1.3
		# The side: a profile of the end of the rows, from beyond the section's end (a), looking along them.
		var deep: Vector3 = away * minf(s.rows, 3) * s.tread * 0.5 + Vector3.UP * minf(s.rows, 3) * s.rise * 0.5
		var side: Vector3 = s.a - along * 2.4 + deep + Vector3.UP * 0.9
		var side_at: Vector3 = s.a + along * 0.6 + deep + Vector3.UP * 0.5
		if s.has("barrier"):
			front += Vector3.UP * float(s.barrier.get("height", 1.0))
		# The cards: from in front and from three quarters (a card faces the play: side on it is a sliver).
		var three_q: Vector3 = mid + (-away * 4.5).rotated(Vector3.UP, 0.6) + Vector3.UP * 1.3
		if s.has("barrier"):
			three_q += Vector3.UP * float(s.barrier.get("height", 1.0))
		for as_cards in [false, true]:
			var v2: Vector3 = three_q if as_cards else side
			var v2_at: Vector3 = mid + Vector3.UP * 0.4 if as_cards else side_at
			shots.append([s, front, mid + Vector3.UP * 0.4, false, as_cards, "front"])
			shots.append([s, v2, v2_at, false, as_cards, "three quarters" if as_cards else "side"])
			shots.append([s, front, mid + Vector3.UP * 0.6, true, as_cards, "front"])
			shots.append([s, v2, v2_at, true, as_cards, "three quarters" if as_cards else "side"])
	var cols := 2
	var sheet := Image.create(CELL.x * cols, CELL.y * shots.size() / cols, false, Image.FORMAT_RGBA8)
	var up_now := false
	for n in shots.size():
		var sh: Array = shots[n]
		crowd.visible = not sh[4]
		cards.visible = sh[4]
		if sh[3] != up_now:
			up_now = sh[3]
			WsgCrowd3D.set_excite(1.0 if up_now else 0.0)
			for k in 90:
				await process_frame
			cards._excite = 1.0 if up_now else 0.0
		cam.look_at_from_position(sh[1], sh[2], Vector3.UP)
		var r: Dictionary = res.sections[sh[0].name]
		var head := "%s - %s\n%s, %s, %s" % [name, sh[0].name, "LOW (cards)" if sh[4] else "3D", sh[5], "on their feet" if up_now else "seated"]
		if sh[4]:
			label.text = head + "\nhips on seat %s m   facing <= %.0f deg" % [_range(low.hips), low.facing]
		else:
			label.text = head + "\nhips on seat %s m   soles %s m\ninto seats/rails <= %.3f m   facing <= %.0f deg" % [_range(r.hips),
				_range(r.feet), r.inside, r.facing]
		for k in 4:
			await process_frame
		sheet.blit_rect(vp.get_texture().get_image(), Rect2i(Vector2i.ZERO, CELL), Vector2i((n % cols) * CELL.x, (n / cols) * CELL.y))
	WsgCrowd3D.set_excite(0.0)
	sheet.save_png(out_dir.path_join(name.to_lower().replace(" ", "_") + ".png"))
	vp.queue_free()
	return res


## The venue drawn plainly from its declaration: the seats, their backs, the steps and the barriers (and the floor).
func _boxes(vp: Node, obstacles: Array, venue: WsgCrowdVenue) -> void:
	var colours := {"seat": Color(0.75, 0.2, 0.2), "seat back": Color(0.65, 0.18, 0.18), "step": Color(0.55, 0.55, 0.58),
		"barrier": Color(0.3, 0.32, 0.36)}
	for ob in obstacles:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = ob.size
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = colours.get(ob.what, Color.GRAY)
		mi.material_override = m
		mi.transform = ob.xf
		vp.add_child(mi)
	# The treads: each row's floor as a slab under it.
	for s in venue.sections:
		var fr := venue.frame(s)
		var along: Vector3 = fr[0]
		var away: Vector3 = fr[1]
		for r in s.rows:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			var hgt: float = (r + 1) * s.rise + 0.05
			bm.size = Vector3(fr[2], hgt, s.tread)
			mi.mesh = bm
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.7, 0.7, 0.72)
			mi.material_override = m
			var c: Vector3 = (s.a + s.b) * 0.5 + away * (r * s.tread + s.tread * 0.5) + Vector3.UP * (r * s.rise - hgt * 0.5 + s.rise * 0.0)
			c.y = (s.a as Vector3).y + r * s.rise - hgt * 0.5 + (r + 1) * s.rise - r * s.rise - s.rise
			mi.transform = Transform3D(Basis(along, Vector3.UP, along.cross(Vector3.UP)), Vector3(c.x, (s.a as Vector3).y + r * s.rise - hgt * 0.5, c.z))
			vp.add_child(mi)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.35, 0.55, 0.35)
	ground.material_override = gm
	ground.position = venue.play_centre + Vector3(0, -0.01, 0)
	vp.add_child(ground)
