extends SceneTree
## WsgAssetPack against a local server (tests/asset_pack_server.py): a pack built here (PCKPacker) is downloaded
## through a redirect, checked, mounted and read from; a download dropped half way resumes with a Range request and
## fetches only the rest; a wrong checksum is refused and thrown away; a mounted pack is found again without a
## download; the progress reaches the end, never going back.
##   godot --headless --path . -s tests/asset_pack_test.gd

var fails := []


func _initialize() -> void:
	await process_frame
	var dir := OS.get_user_data_dir().path_join("pack_test_srv")
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	# The pack: one text file and 3 MB of noise (enough to take several reads).
	var src := dir.path_join("hello.txt")
	var fa := FileAccess.open(src, FileAccess.WRITE)
	fa.store_string("the High pack is here")
	fa.close()
	var noise := dir.path_join("noise.bin")
	fa = FileAccess.open(noise, FileAccess.WRITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var buf := PackedByteArray()
	buf.resize(3 * 1024 * 1024)
	for i in buf.size():
		buf[i] = rng.randi() & 255
	fa.store_buffer(buf)
	fa.close()
	var pck := dir.path_join("high.pck")
	var packer := PCKPacker.new()
	packer.pck_start(pck)
	packer.add_file("res://pack_test/hello.txt", src)
	packer.add_file("res://pack_test/noise.bin", noise)
	packer.flush()
	var bytes := FileAccess.get_file_as_bytes(pck)
	var sha := _sha(bytes)
	var port := 18000 + randi() % 2000
	var drop := bytes.size() / 2
	var pid := OS.create_process("python3", [ProjectSettings.globalize_path("res://tests/asset_pack_server.py"), dir, str(port), str(drop)])
	await _wait_ms(1200)
	var url := "http://127.0.0.1:%d/go/high.pck" % port
	var pack := WsgAssetPack.new(url, sha, bytes.size(), "test_high.pck")
	pack.remove()
	var fr := []
	pack.progressed.connect(func(f: float): fr.append(f))
	# 1. Dropped half way: false, the part kept.
	var ok := await pack.fetch()
	_expect(not ok and pack.error != "", "a dropped download reported success (%s)" % pack.error)
	var part_size := FileAccess.open(pack.path + ".part", FileAccess.READ).get_length() if FileAccess.file_exists(pack.path + ".part") else 0
	print("dropped at %d of %d bytes: '%s'" % [part_size, bytes.size(), pack.error])
	_expect(part_size > 0 and part_size < bytes.size(), "nothing kept to resume from (%d bytes)" % part_size)
	# 2. Again, behind a loading bar: resumes with a Range, fetches only the rest, checks, mounts.
	var menu := Control.new()
	root.add_child(menu)
	var ld := WsgLoading.cover(menu, [])
	var res := [false]
	ld.step("Downloading", func(): res[0] = await pack.fetch(ld))
	await ld.run()
	await ld.done()
	print("resumed: %s, fetched %d bytes (the rest: %d), error '%s'" % [pack.resumed, pack.fetched, bytes.size() - part_size, pack.error])
	_expect(res[0], "the resumed download failed: %s" % pack.error)
	_expect(pack.resumed and pack.fetched == bytes.size() - part_size, "it did not resume (fetched %d)" % pack.fetched)
	var log := FileAccess.get_file_as_string(dir.path_join("requests.log"))
	_expect(log.contains("bytes=%d-" % part_size), "no Range request from the part's end: %s" % log)
	_expect(FileAccess.file_exists("res://pack_test/hello.txt") and FileAccess.get_file_as_string("res://pack_test/hello.txt") == "the High pack is here", "the mounted pack's file cannot be read")
	var back := false
	for i in range(1, fr.size()):
		if fr[i] < fr[i - 1] - 0.0001:
			back = true
	_expect(not fr.is_empty() and is_equal_approx(fr[-1], 1.0), "the progress did not reach the end (%s)" % [fr.back() if not fr.is_empty() else "none"])
	_expect(not back, "the progress went back")
	# 3. Next start: here and checked, mounted with no download.
	var again := WsgAssetPack.new(url, sha, bytes.size(), "test_high.pck")
	var n_before := log.split("\n", false).size()
	_expect(again.have() and await again.fetch(), "a checked pack was not found again")
	_expect(FileAccess.get_file_as_string(dir.path_join("requests.log")).split("\n", false).size() == n_before, "a pack already here was downloaded again")
	# 4. A wrong checksum: refused, thrown away.
	var bad := WsgAssetPack.new("http://127.0.0.1:%d/high.pck" % port, "00".repeat(32), bytes.size(), "test_bad.pck")
	bad.remove()
	_expect(not await bad.fetch() and bad.error.contains("checksum"), "a wrong checksum was accepted (%s)" % bad.error)
	_expect(not FileAccess.file_exists(bad.path) and not FileAccess.file_exists(bad.path + ".part"), "a damaged download was kept")
	print("checksum refused: '%s'" % bad.error)
	pack.remove()
	bad.remove()
	OS.kill(pid)
	print("ASSET PACK TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)


func _expect(ok: bool, msg: String) -> void:
	if not ok:
		fails.append(msg)
		printerr(msg)


func _sha(b: PackedByteArray) -> String:
	var c := HashingContext.new()
	c.start(HashingContext.HASH_SHA256)
	c.update(b)
	return c.finish().hex_encode()


func _wait_ms(ms: int) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < ms:
		await process_frame
