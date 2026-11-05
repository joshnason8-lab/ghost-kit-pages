class_name Renderer
extends RefCounted
## The renderer: Godot's Mobile (Vulkan) renderer, the project's own (project.godot), at every graphics level. A phone
## that cannot start it gets OpenGL from Godot itself (rendering/rendering_device/fallback_to_opengl3); a phone whose
## graphics are known to struggle with Vulkan (older Mali, PowerVR, Adreno 3xx-5xx, Android 9 or older), or whose
## last start on Vulkan never reached the home screen (a crash), is set to GL Compatibility from its next start,
## quietly, by user://renderer.cfg (the project's settings override, application/config/project_settings_override).
## Every level draws the same colours on either renderer (game/shaders/look.gdshaderinc); High's real lighting
## (lit()) needs Vulkan. The same scheme as Hurling Heroes.

const OVERRIDE := "user://renderer.cfg"
const BOOT_FLAG := "user://vulkan_boot.flag"
## Graphics that struggle with Vulkan: these phones draw with GL Compatibility (adapter names, lower case).
const WEAK_VULKAN := ["mali-t", "mali-4", "mali-g31", "mali-g51", "mali-g52", "powervr", "img ", "ge8", "adreno (tm) 3",
	"adreno (tm) 4", "adreno (tm) 50", "adreno (tm) 51"]

static var fell_back := ""   # "crash": the last start on Vulkan failed (said once, in Settings)


## A phone for High: 64-bit, a recent GPU (Adreno 640 and later, Mali-G710 and later, Immortalis, Xclipse), 6 GB of
## memory or more. On a computer (testing), always.
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


## Graphics known to struggle with Vulkan (WEAK_VULKAN), or a phone older than Android 10.
static func weak_vulkan(gpu: String) -> bool:
	if not OS.has_feature("mobile"):
		return false
	gpu = gpu.to_lower()
	for w in WEAK_VULKAN:
		if gpu.contains(w):
			return true
	return OS.has_feature("android") and int(OS.get_version().get_slice(".", 0)) < 10


## The game is drawing with the Mobile (Vulkan) renderer.
static func vulkan() -> bool:
	return RenderingServer.get_current_rendering_method() != "gl_compatibility"


## High's real lighting: on Vulkan, at High.
static func lit() -> bool:
	return int(Game.settings.graphics) == Game.GFX_HIGH and vulkan()


## For the next start: GL Compatibility (on), or the project's own Vulkan (off).
static func use_gl(on: bool) -> void:
	if on:
		var f := FileAccess.open(OVERRIDE, FileAccess.WRITE)
		if f:
			f.store_string('[rendering]\n\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n')
	elif FileAccess.file_exists(OVERRIDE):
		DirAccess.remove_absolute(OVERRIDE)


## At start, before anything is drawn: on Vulkan, a phone whose last start crashed, or whose graphics struggle with
## Vulkan, goes to GL Compatibility from its next start.
static func boot() -> void:
	if not vulkan():
		return
	if FileAccess.file_exists(BOOT_FLAG):
		fell_back = "crash"             # the last start on Vulkan never reached the home screen
		use_gl(true)
		DirAccess.remove_absolute(BOOT_FLAG)
	elif weak_vulkan(RenderingServer.get_video_adapter_name()):
		use_gl(true)


## The game itself is starting (main.gd, not a test or a tool): on Vulkan, the flag that says so until the home screen
## is up (started), so a start that crashes on the way is known at the next.
static func arm() -> void:
	if vulkan():
		var f := FileAccess.open(BOOT_FLAG, FileAccess.WRITE)
		if f:
			f.store_string(Time.get_datetime_string_from_system())


static func started() -> void:
	if FileAccess.file_exists(BOOT_FLAG):
		DirAccess.remove_absolute(BOOT_FLAG)
