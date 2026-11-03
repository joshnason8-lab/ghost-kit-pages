class_name WsgAssetPack
extends RefCounted
## The downloadable High pack (owner-approved item 1): the High tier's extra assets - our own, Meshy and CC ones only,
## never licensed MoCap Online, ActorCore or Mixamo-derived data, which ship only inside the APK - as one Godot pack
## (.pck), a public GitHub release asset beside the APK (an Obtainium install takes the APK; the game fetches the pack
## when the player picks High). Downloaded in the background behind WsgLoading's bar, resumed where it stopped (a
## dropped connection, the app closed), checked against its SHA-256, then mounted (ProjectSettings.load_resource_pack).
##   var pack := WsgAssetPack.from_manifest()           # res://wsg_pack.json, written by CI: {url, sha256, size}
##   if pack and not pack.mount():                      # already here and checked: mounted, true
##       var ld := WsgLoading.cover(menu, [high_button], {"title": "Downloading High graphics"})
##       ld.step("Downloading", func(): await pack.fetch(ld))
##       await ld.run(); await ld.done()
##       if pack.error != "": (stay on Medium, say so: pack.error)
## The pack's assets' licences go in the credits screen (item 8). ADOPTING §5.20.

## Where the pack is kept (and its part while downloading).
const DIR := "user://packs"
## No data for this long: the download stops (what came is kept for the next try).
const STALL_S := 30.0
const CHUNK := 1 << 16

var url := ""
var sha256 := ""
var size := 0
var path := ""
## The last fetch's trouble ("" none): kept short, for a message to the player.
var error := ""
## The last fetch: bytes that came from the network (a resumed fetch fetches only the rest).
var fetched := 0
## The last fetch resumed a part already here.
var resumed := false
signal progressed(fraction: float)


func _init(p_url := "", p_sha256 := "", p_size := 0, name := "high.pck") -> void:
	url = p_url
	sha256 = p_sha256.to_lower()
	size = p_size
	path = DIR.path_join(name)


## The pack this build was made with (CI writes res://wsg_pack.json: {"url", "sha256", "size", "name"}), or null.
static func from_manifest(res_path := "res://wsg_pack.json") -> WsgAssetPack:
	if not FileAccess.file_exists(res_path):
		return null
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(res_path))
	if not d is Dictionary or not (d as Dictionary).has("url"):
		return null
	return WsgAssetPack.new(str(d.url), str(d.get("sha256", "")), int(d.get("size", 0)), str(d.get("name", "high.pck")))


## The whole pack is here and was checked (its checksum noted when it was).
func have() -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or (size > 0 and f.get_length() != size):
		return false
	return FileAccess.get_file_as_string(path + ".sha256").strip_edges() == sha256


## Mounts the pack if it is here and checked (its files over the APK's own: the High assets): true when mounted.
func mount() -> bool:
	if not have():
		return false
	return ProjectSettings.load_resource_pack(path, true)


## Downloads what is not here yet (from where an earlier try stopped), checks it, mounts it. A coroutine; LOADING (a
## WsgLoading running this as a step) gets the progress on its bar. True when mounted; else error says why, and what
## came is kept to resume from (not after a bad checksum: that is thrown away).
func fetch(loading: WsgLoading = null) -> bool:
	error = ""
	fetched = 0
	resumed = false
	if mount():
		return true
	DirAccess.make_dir_recursive_absolute(DIR)
	var part := path + ".part"
	var have_bytes := 0
	if FileAccess.file_exists(part):
		have_bytes = FileAccess.open(part, FileAccess.READ).get_length()
		resumed = have_bytes > 0
	var tree := Engine.get_main_loop() as SceneTree
	var where := url
	var http := HTTPClient.new()
	var code := 0
	for hop in 6:
		var u := _split(where)
		if u.is_empty():
			error = "bad address: %s" % where
			return false
		var e := http.connect_to_host(u.host, u.port, TLSOptions.client() if u.tls else null)
		if e != OK:
			error = "cannot connect (%d)" % e
			return false
		var t0 := Time.get_ticks_msec()
		while http.get_status() in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
			http.poll()
			await tree.process_frame
			if Time.get_ticks_msec() - t0 > STALL_S * 1000.0:
				error = "no connection"
				return false
		if http.get_status() != HTTPClient.STATUS_CONNECTED:
			error = "cannot connect (status %d)" % http.get_status()
			return false
		var headers := PackedStringArray(["User-Agent: WorldStageGames-Pack"])
		if have_bytes > 0:
			headers.append("Range: bytes=%d-" % have_bytes)
		http.request(HTTPClient.METHOD_GET, u.path, headers)
		while http.get_status() == HTTPClient.STATUS_REQUESTING:
			http.poll()
			await tree.process_frame
		if not http.has_response():
			error = "no answer"
			return false
		code = http.get_response_code()
		if code in [301, 302, 303, 307, 308]:
			# (GitHub sends a release asset's download on to its storage.)
			var loc := _header(http.get_response_headers(), "location")
			http.close()
			if loc == "":
				error = "a redirect with nowhere to go"
				return false
			where = loc if loc.begins_with("http") else "%s://%s%s" % ["https" if u.tls else "http", u.host_port, loc]
			continue
		break
	if code == 416 and have_bytes > 0:
		http.close()
		return await _finish(part, loading)
	if code != 200 and code != 206:
		error = "the server answered %d" % code
		http.close()
		return false
	var f: FileAccess
	if code == 206 and have_bytes > 0:
		f = FileAccess.open(part, FileAccess.READ_WRITE)
		f.seek_end()
	else:
		# (A whole file sent back: start the part again.)
		have_bytes = 0
		resumed = false
		f = FileAccess.open(part, FileAccess.WRITE)
	if f == null:
		error = "cannot write the pack (storage full?)"
		http.close()
		return false
	var total := size if size > 0 else (have_bytes + http.get_response_body_length() if http.get_response_body_length() > 0 else 0)
	var got := have_bytes
	var quiet := Time.get_ticks_msec()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.is_empty():
			if Time.get_ticks_msec() - quiet > STALL_S * 1000.0:
				break
			await tree.process_frame
			continue
		quiet = Time.get_ticks_msec()
		f.store_buffer(chunk)
		got += chunk.size()
		fetched += chunk.size()
		if total > 0:
			var frac := clampf(float(got) / total, 0.0, 1.0) * 0.95
			progressed.emit(frac)
			if loading:
				await loading.checkpoint(frac)
	f.close()
	http.close()
	if total > 0 and got < total:
		error = "the download stopped at %d of %d MB (it goes on from there next time)" % [got / 1048576, total / 1048576]
		return false
	return await _finish(part, loading)


## Checks the downloaded part against the checksum (in slices, the bar moving), then keeps and mounts it.
func _finish(part: String, loading: WsgLoading) -> bool:
	var f := FileAccess.open(part, FileAccess.READ)
	if f == null:
		error = "the download is gone"
		return false
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var n := f.get_length()
	var done := 0
	while not f.eof_reached() and done < n:
		var b := f.get_buffer(CHUNK * 16)
		ctx.update(b)
		done += b.size()
		if loading:
			await loading.checkpoint(0.95 + 0.05 * float(done) / maxf(1.0, n))
	f.close()
	var got := ctx.finish().hex_encode()
	if sha256 != "" and got != sha256:
		DirAccess.remove_absolute(part)
		error = "the download was damaged (checksum): it starts again next time"
		return false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(part, path)
	var mark := FileAccess.open(path + ".sha256", FileAccess.WRITE)
	mark.store_string(got)
	mark.close()
	progressed.emit(1.0)
	if not ProjectSettings.load_resource_pack(path, true):
		error = "the pack would not open"
		return false
	return true


## Throws the pack away (Settings: free the space; a newer build's pack replaces it).
func remove() -> void:
	for p in [path, path + ".part", path + ".sha256"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## A response header's value ("" none). (get_response_headers_as_dictionary() came back empty on 4.7.2.)
static func _header(headers: PackedStringArray, name: String) -> String:
	for h in headers:
		var i := h.find(":")
		if i > 0 and h.substr(0, i).strip_edges().to_lower() == name:
			return h.substr(i + 1).strip_edges()
	return ""


static func _split(u: String) -> Dictionary:
	var tls := u.begins_with("https://")
	if not tls and not u.begins_with("http://"):
		return {}
	var rest := u.substr(8 if tls else 7)
	var slash := rest.find("/")
	var hp := rest if slash < 0 else rest.substr(0, slash)
	var p := "/" if slash < 0 else rest.substr(slash)
	var host := hp
	var port := 443 if tls else 80
	if hp.contains(":"):
		host = hp.get_slice(":", 0)
		port = int(hp.get_slice(":", 1))
	return {"tls": tls, "host": host, "port": port, "path": p, "host_port": hp}
