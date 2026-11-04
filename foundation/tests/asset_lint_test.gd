extends SceneTree
## WsgAssetLint's own test: each fault planted in fixtures (user://) is found by its check, and the fixed one is not -
## a big texture not GPU-compressed (and a VRAM one without mipmaps: a warning); a big model with LODs off; a raw FBX,
## licensed data or a baked texture committed, the data folder not git-ignored; a toe-up model without WsgFootFlat; a
## bench no solid prop covers (registered, or opted out with a reason: fine).
##   godot --headless --path . -s tests/asset_lint_test.gd

var fails := []


func _initialize() -> void:
	await process_frame
	var dir := "user://lint_fixture"
	DirAccess.make_dir_recursive_absolute(dir)
	# Textures.
	_ctex(dir.path_join("big_raw.ctex"), 2048, 2048, 1, 5, 3 * 1024 * 1024)
	_ctex(dir.path_join("big_vram.ctex"), 2048, 2048, 0, 31, 3 * 1024 * 1024)
	_ctex(dir.path_join("small_raw.ctex"), 512, 512, 2, 5, 300 * 1024)
	var t1 := _import(dir.path_join("face.png.import"), "texture", {"path": dir.path_join("big_raw.ctex")}, {"compress/mode": 0, "mipmaps/generate": false})
	var t2 := _import(dir.path_join("sky.jpg.import"), "texture", {"path.etc2": dir.path_join("big_vram.ctex")}, {"compress/mode": 2, "mipmaps/generate": false})
	var t3 := _import(dir.path_join("icon.png.import"), "texture", {"path": dir.path_join("small_raw.ctex")}, {"compress/mode": 0})
	var a := WsgAssetLint.texture(t1[0], t1[1])
	var b := WsgAssetLint.texture(t2[0], t2[1])
	var c := WsgAssetLint.texture(t3[0], t3[1])
	_expect(a.size() == 1 and a[0].fail, "a 3 MB raw texture was not failed: %s" % [a])
	_expect(b.size() == 1 and not b[0].fail and String(b[0].what).contains("mipmaps"), "a big VRAM texture without mipmaps was not warned: %s" % [b])
	_expect(c.is_empty(), "a small UI texture was flagged: %s" % [c])
	print("textures: %s | %s" % [a[0].what if a.size() else "-", b[0].what if b.size() else "-"])
	# LODs.
	var big := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radial_segments = 128
	sm.rings = 64
	mi.mesh = sm
	big.add_child(mi)
	mi.owner = big
	var ps := PackedScene.new()
	ps.pack(big)
	ResourceSaver.save(ps, dir.path_join("stand.tscn"))
	big.free()
	var l1 := _import(dir.path_join("stand.tscn.import"), "scene", {}, {"meshes/generate_lods": false})
	var l2 := _import(dir.path_join("stand2.tscn.import"), "scene", {}, {"meshes/generate_lods": true})
	var la := WsgAssetLint.lods(l1[0], l1[1])
	_expect(la.size() == 1 and la[0].fail, "a %s-triangle model with LODs off was not failed" % [sm.get_faces().size() / 3])
	_expect(WsgAssetLint.lods(l2[0], l2[1]).is_empty(), "a model with LODs on was flagged")
	print("lods: %s" % (la[0].what if la.size() else "-"))
	# Licensed data.
	var lic := WsgAssetLint.licensed(["game/main.gd", "assets/models/player.FBX", "addons/wsg_foundation/data/mobility.res", "assets/crowd/actorcore_pos.exr", "assets/sky.png"], false)
	var paths := lic.map(func(i: Dictionary) -> String: return i.path)
	_expect(paths.has("assets/models/player.FBX") and paths.has("addons/wsg_foundation/data/mobility.res") and paths.has("assets/crowd/actorcore_pos.exr") and paths.has("addons/wsg_foundation/data/"), "licensed files were missed: %s" % [paths])
	_expect(not paths.has("game/main.gd") and not paths.has("assets/sky.png"), "a game file was flagged as licensed: %s" % [paths])
	_expect(WsgAssetLint.licensed(["game/main.gd"], true).is_empty(), "a clean repository was flagged")
	print("licensed: %d found (FBX, data, a baked texture, the data folder not ignored)" % lic.size())
	# Toe-up.
	var ch := WsgBody.load_character("res://tests/character", "hero")
	var body := WsgBody.new(ch)
	root.add_child(body)
	await process_frame
	var tilt := WsgFootFlat.sole_tilt(body)
	_expect(WsgAssetLint.toe_up(body).is_empty() == (tilt < WsgFootFlat.MIN_TILT), "the test hurler (%.1f degrees) judged wrongly" % tilt)
	# A model measured 8 degrees toe-up (the measuring itself: foot_flat_test): failed without WsgFootFlat, not with it.
	var tu := WsgAssetLint.toe_up(body, "the player", 8.0)
	_expect(tu.size() == 1 and tu[0].fail, "an 8-degree toe-up model without WsgFootFlat was not failed")
	var ff := WsgFootFlat.new()
	ff.down = deg_to_rad(8.0)
	body.skeleton.add_child(ff)
	_expect(WsgAssetLint.toe_up(body, "the player", 8.0).is_empty(), "a toe-up model with WsgFootFlat was still failed")
	print("toe_up: the test hurler %.1f degrees (flat); 8 degrees: %s" % [tilt, tu[0].what if tu.size() else "-"])
	body.queue_free()
	# Props.
	var venue := Node3D.new()
	root.add_child(venue)
	var bench := MeshInstance3D.new()
	bench.name = "Bench"
	var bm := BoxMesh.new()
	bm.size = Vector3(4.0, 0.45, 0.4)
	bench.mesh = bm
	bench.position = Vector3(0, 0.225, 6)
	venue.add_child(bench)
	var floor_m := MeshInstance3D.new()
	floor_m.name = "Floor"
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 30)
	floor_m.mesh = pm
	venue.add_child(floor_m)
	var solid := WsgSolidProps.new()
	var p1 := WsgAssetLint.props(venue, solid, "test")
	_expect(p1.size() == 1 and String(p1[0].path).contains("Bench"), "an unregistered bench was missed: %s" % [p1])
	solid.register(venue)
	_expect(WsgAssetLint.props(venue, solid, "test").is_empty(), "a registered bench was flagged")
	var solid2 := WsgSolidProps.new()
	bench.set_meta("wsg_solid", false)
	bench.set_meta("wsg_solid_reason", "a painted line on a wall")
	_expect(WsgAssetLint.props(venue, solid2, "test").is_empty(), "an opted-out mesh was flagged")
	print("props: %s" % (p1[0].what if p1.size() else "-"))
	venue.queue_free()
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	print("ASSET LINT TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)


func _ctex(path: String, w: int, h: int, df: int, fmt: int, size: int) -> void:
	var b := PackedByteArray()
	b.resize(size)
	b.encode_u32(0, 0x32545347)   # "GST2"
	b.encode_u32(4, 1)
	b.encode_u32(8, w)
	b.encode_u32(12, h)
	b.encode_u32(36, df)
	b.encode_u16(40, w)
	b.encode_u16(42, h)
	b.encode_u32(48, fmt)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(b)
	f.close()


func _import(path: String, importer: String, remap: Dictionary, params: Dictionary) -> Array:
	var cf := ConfigFile.new()
	cf.set_value("remap", "importer", importer)
	for k in remap:
		cf.set_value("remap", k, remap[k])
	for k in params:
		cf.set_value("params", k, params[k])
	cf.save(path)
	return [path, cf]


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		printerr(msg)
