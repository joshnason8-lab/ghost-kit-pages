class_name Ultra
extends Node
## The Ultra graphics level: for recent high-end phones, opt-in, never chosen for you. It draws with Godot's Mobile
## (Vulkan) renderer rather than GL Compatibility, and its content (sharper players, grass, crowd, stadium: the HD
## pack) is a separate download, not in the APK, so Low, Medium and High are exactly as they were.
##
## The renderer is fixed when the game starts, so switching to Ultra or back writes user://renderer.cfg (the project's
## settings override: project.godot application/config/project_settings_override) and the game has to be opened
## again. If Vulkan will not start, Godot falls back to OpenGL by itself (rendering/rendering_device/
## fallback_to_opengl3) and the next start goes back to High; if a start in Ultra never gets as far as the home
## screen (a crash), the one after that goes back to High too.
##
## The pack: hurling-heroes-hd-<PACK>.pck on the beta release, with its manifest (size and SHA-256) beside it.
## Downloaded in pieces (resumed where it stopped, retried), checked whole, then mounted at start with
## ProjectSettings.load_resource_pack: its files appear under res://ultra/.

const OVERRIDE := "user://renderer.cfg"
const BOOT_FLAG := "user://ultra_boot.flag"
const DIR := "user://hd/"
const PACK := 1                           # the pack this build of the game expects
const RELEASE := "https://github.com/joshnason8-lab/ghost-kit-pages/releases/download/ash-and-leather-beta/"
const CHUNK := 4 * 1024 * 1024
const PROBE := "res://ultra/ground/grass_ground_albedo_4k.jpg"   # a file the pack brings

signal progress(done: int, total: int)
signal finished(ok: bool, message: String)

static var mounted := false
static var fell_back := ""                # why the last start left Ultra (shown once in Settings)


static func pack_name() -> String:
	return "hurling-heroes-hd-%d.pck" % PACK


static func manifest_name() -> String:
	return "hurling-heroes-hd-%d.json" % PACK


static func pack_path() -> String:
	return DIR + pack_name()


## A phone that can take Ultra: 64-bit, Vulkan-class GPU (Adreno 640 and later, Mali-G710 and later, Immortalis,
## Xclipse), 6 GB of memory or more. On a computer (testing), always.
static func capable() -> bool:
	if OS.has_feature("web"):
		return false
	if not OS.has_feature("mobile"):
		return true
	if not OS.has_feature("arm64"):
		return false
	var mem: Dictionary = OS.get_memory_info()
	if float(mem.get("physical", 0)) / 1073741824.0 < 5.5:
		return false
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	if gpu.contains("immortalis") or gpu.contains("xclipse"):
		return true
	var adreno := _model_number(gpu, "adreno")
	if adreno > 0:
		return adreno >= 640
	var mali := _model_number(gpu, "mali-g")
	if mali > 0:
		return mali >= 710
	return false


static func _model_number(gpu: String, key: String) -> int:
	var i := gpu.find(key)
	if i < 0:
		return 0
	var digits := ""
	for c in gpu.substr(i + key.length()):
		if c >= "0" and c <= "9":
			digits += c
		elif not digits.is_empty():
			break
	return int(digits) if not digits.is_empty() else 0


## The game is drawing with the Mobile (Vulkan) renderer.
static func renderer_ready() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


## Ultra is on and working: the renderer and the pack.
static func active() -> bool:
	return int(Game.settings.graphics) == Game.GFX_ULTRA and renderer_ready() and (mounted or ResourceLoader.exists(PROBE))


## For the next start: the Mobile renderer (on) or the project's own, GL Compatibility (off).
static func set_renderer(on: bool) -> void:
	if on:
		var f := FileAccess.open(OVERRIDE, FileAccess.WRITE)
		if f:
			f.store_string('[rendering]\n\nrenderer/rendering_method="mobile"\nrenderer/rendering_method.mobile="mobile"\n')
	elif FileAccess.file_exists(OVERRIDE):
		DirAccess.remove_absolute(OVERRIDE)


## At start, before anything is drawn: keep Ultra if it can work, else go back to High and say why.
static func boot() -> void:
	if int(Game.settings.graphics) != Game.GFX_ULTRA:
		if FileAccess.file_exists(OVERRIDE):
			set_renderer(false)   # a switch away from Ultra finished: the override is no longer wanted
		return
	var why := ""
	if FileAccess.file_exists(BOOT_FLAG):
		why = "crash"             # the last start in Ultra never reached the home screen
	elif not renderer_ready():
		why = "vulkan"            # Vulkan would not start: Godot fell back to OpenGL
	elif ResourceLoader.exists(PROBE):
		pass                      # the content is in the project itself (the editor, the tests): nothing to mount
	elif not FileAccess.file_exists(pack_path()) or ProjectSettings.load_resource_pack(pack_path(), false) == false:
		why = "pack"
	if why != "":
		fell_back = why
		Game.settings.graphics = Game.GFX_HIGH
		set_renderer(false)
		if FileAccess.file_exists(BOOT_FLAG):
			DirAccess.remove_absolute(BOOT_FLAG)
		Game.save_settings()
		return
	mounted = true
	var f := FileAccess.open(BOOT_FLAG, FileAccess.WRITE)
	if f:
		f.store_string(Time.get_datetime_string_from_system())


## The home screen is up: this start in Ultra worked.
static func started() -> void:
	if FileAccess.file_exists(BOOT_FLAG):
		DirAccess.remove_absolute(BOOT_FLAG)


## The pack is here and whole (its size as the manifest says; the full check was made when it was downloaded).
static func pack_ready() -> bool:
	if not FileAccess.file_exists(pack_path()) or not FileAccess.file_exists(DIR + manifest_name()):
		return false
	var man: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + manifest_name()))
	var f := FileAccess.open(pack_path(), FileAccess.READ)
	return man is Dictionary and f != null and f.get_length() == int(man.get("size", -1))


static func remove_pack() -> void:
	for n in [pack_name(), pack_name() + ".part", manifest_name()]:
		if FileAccess.file_exists(DIR + n):
			DirAccess.remove_absolute(DIR + n)


# ---------------------------------------------------------------- the download

var _http: HTTPRequest
var _man := {}
var _url := ""            # the pack's address after GitHub's redirect (signed, good for a few minutes)
var _part := ""
var _done := 0
var _fails := 0
var running := false
var file := pack_name()    # the release file fetched (tests point it elsewhere)
var dest := pack_path()


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 60.0
	_http.body_size_limit = CHUNK * 2   # a server that ignores the range would send it all: refused, tried again
	add_child(_http)


## The manifest: how big the pack is (for the screen) and its checksum.
func fetch_manifest() -> void:
	running = true
	DirAccess.make_dir_recursive_absolute(DIR)
	_http.max_redirects = 8
	_http.request_completed.connect(_on_manifest, CONNECT_ONE_SHOT)
	if _http.request(RELEASE + manifest_name()) != OK:
		_fail("net")


func _on_manifest(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("net")
		return
	var man: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (man is Dictionary) or int(man.get("pack", -1)) != PACK or int(man.get("size", 0)) <= 0:
		_fail("manifest")
		return
	_man = man
	var f := FileAccess.open(DIR + manifest_name(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(man))
	running = false
	progress.emit(0, int(_man.size))


func size() -> int:
	return int(_man.get("size", 0))


## (Tests: fetch any release file of known size and checksum.)
func use(p_file: String, p_size: int, p_sha256: String, p_dest: String) -> void:
	file = p_file
	dest = p_dest
	_man = {"pack": PACK, "size": p_size, "sha256": p_sha256}


## Fetch the pack (or the rest of it), check it, and keep it.
func download() -> void:
	if _man.is_empty():
		_fail("manifest")
		return
	running = true
	_fails = 0
	_part = dest + ".part"
	_done = 0
	if FileAccess.file_exists(_part):
		var f := FileAccess.open(_part, FileAccess.READ)
		_done = f.get_length() if f else 0
	if _done > size():
		DirAccess.remove_absolute(_part)
		_done = 0
	if _done == size():
		_check()                  # all here already (stopped while checking): only the check
		return
	_resolve()


## GitHub sends release files from elsewhere: find where once, then ask there for each piece.
func _resolve() -> void:
	if not running:
		return
	_http.max_redirects = 0
	_http.request_completed.connect(_on_resolved, CONNECT_ONE_SHOT)
	if _http.request(RELEASE + file, [], HTTPClient.METHOD_HEAD) != OK:
		_retry()


func _on_resolved(result: int, code: int, headers: PackedStringArray, _b: PackedByteArray) -> void:
	if not running:
		return
	_url = RELEASE + file
	if code in [301, 302, 303, 307, 308]:
		for h in headers:
			if h.to_lower().begins_with("location:"):
				_url = h.substr(9).strip_edges()
	elif result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_retry()
		return
	_next()


func _next() -> void:
	if not running:
		return
	if _done >= size():
		_check()
		return
	var end := mini(_done + CHUNK, size()) - 1
	_http.max_redirects = 8
	_http.request_completed.connect(_on_chunk, CONNECT_ONE_SHOT)
	if _http.request(_url, ["Range: bytes=%d-%d" % [_done, end]]) != OK:
		_retry()


func _on_chunk(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if not running:
		return
	if result != HTTPRequest.RESULT_SUCCESS or not (code == 206 or (code == 200 and _done == 0)) or body.is_empty():
		if code in [401, 403]:
			_resolve()            # the signed address ran out: find it again
			return
		_retry()
		return
	if code == 200 and body.size() != size():
		_retry()
		return
	var f := FileAccess.open(_part, FileAccess.READ_WRITE if FileAccess.file_exists(_part) else FileAccess.WRITE)
	if f == null:
		_fail("space")
		return
	f.seek_end()
	f.store_buffer(body)
	f.close()
	_done += body.size()
	_fails = 0
	progress.emit(_done, size())
	_next()


func _retry() -> void:
	_fails += 1
	if _fails > 4:
		_fail("net")
		return
	await get_tree().create_timer(1.5 * _fails).timeout
	if running:
		_resolve()


## The whole file against its SHA-256, a piece at a time (a big file is not read into memory).
func _check() -> void:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var f := FileAccess.open(_part, FileAccess.READ)
	if f == null:
		_fail("space")
		return
	while f.get_position() < f.get_length():
		ctx.update(f.get_buffer(1048576))
		await get_tree().process_frame
	f.close()
	if ctx.finish().hex_encode() != String(_man.get("sha256", "")).to_lower():
		DirAccess.remove_absolute(_part)
		_fail("corrupt")
		return
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	DirAccess.rename_absolute(_part, dest)
	running = false
	finished.emit(true, "")


func cancel() -> void:
	running = false
	_http.cancel_request()
	for c in _http.request_completed.get_connections():
		_http.request_completed.disconnect(c.callable)


func _fail(why: String) -> void:
	running = false
	finished.emit(false, why)
