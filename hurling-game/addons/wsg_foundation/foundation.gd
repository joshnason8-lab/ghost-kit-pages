class_name WsgFoundation
extends RefCounted
## The phones a game is made for, set once by the game (ADOPTING.md, "Profiles"), and what the rest of the foundation
## spends because of it:
##   premium - nicer phones, the Mobile (Vulkan) renderer: Medium for an ordinary phone (Hurling, Floorball, Netball);
##   budget  - cheaper phones, GL Compatibility: Low for an ordinary phone; at Low and Medium a small band of 3D fans,
##             full detail only on the bodies nearest the camera (Kabaddi, Kho Kho, Sepak Takraw, Pok Ta Pok).
## Either way the phone decides (the owner: "if someone has a new phone and gets Kabaddi it should go to high
## quality"): a weak phone starts on Low, a flagship on High, the rest on the profile's default; and every tier is
## there to choose in Settings.
## In the game's boot, before anything is built:
##   WsgFoundation.profile = "budget"
##   if saved_graphics < 0: saved_graphics = WsgFoundation.starting_tier()   # the player's own choice always wins
##   WsgFoundation.tier = saved_graphics   # (and whenever the player changes it)
##   WsgFoundation.guard_renderer()     # a Vulkan game: phones that cannot hold Vulkan go to GL Compatibility
##   ...                                # and, once the home screen is up:
##   WsgFoundation.boot_ok()

const LOW := 0
const MEDIUM := 1
const HIGH := 2

## Per profile: the renderer it is made for, the tier an ordinary phone starts on, the 3D crowd per tier ([near: full
## figures, in all], see WsgCrowd3D; 3: Close, a practice or a shoot-out), and per tier how many bodies are drawn in
## full detail (twist and joint helpers, fingers, the full mesh) - the rest, farthest from the camera, get the light
## mesh and plain joints. A budget game's High is for the flagship that runs it: still GL Compatibility (Kabaddi's
## Vulkan crashes were on a flagship), a premium game's Medium crowd and every body in full.
const PROFILES := {
	"premium": {"renderer": "mobile", "default": MEDIUM,
		"crowd": {MEDIUM: [400, 1200], HIGH: [700, 2000], 3: [2000, 3000]}, "full_bodies": {LOW: 64, MEDIUM: 64, HIGH: 64}},
	"budget": {"renderer": "gl_compatibility", "default": LOW,
		"crowd": {MEDIUM: [150, 150], HIGH: [400, 1200], 3: [400, 600]}, "full_bodies": {LOW: 6, MEDIUM: 6, HIGH: 64}},
}

static var profile := "premium"
## The tier the game is drawing at now (the game sets it, at start and when the player changes it).
static var tier := MEDIUM

## Graphics that struggle with Vulkan (adapter names, lower case; the games' own experience), and phones that crash
## on it (model names: Kabaddi's Galaxy S24 family). A game adds its own: WsgFoundation.block_vulkan("sm-s92").
static var vulkan_blocklist := ["mali-t", "mali-4", "mali-g31", "mali-g51", "mali-g52", "powervr", "img ", "ge8",
	"adreno (tm) 3", "adreno (tm) 4", "adreno (tm) 50", "adreno (tm) 51"]
static var model_blocklist: Array = []

## The override file Godot reads at start (project.godot: application/config/project_settings_override); a game
## that already has one (Hurling: Ultra.OVERRIDE) keeps its own.
const OVERRIDE := "user://renderer.cfg"
const BOOT_FLAG := "user://wsg_vulkan_boot.flag"


static func spec() -> Dictionary:
	return PROFILES.get(profile, PROFILES.premium)


## The 3D crowd's budget at a tier: [near, in all].
static func crowd_budget(quality: int) -> Array:
	var c: Dictionary = spec().crowd
	return c.get(quality, c[MEDIUM])


static func full_bodies() -> int:
	return int((spec().full_bodies as Dictionary).get(tier, 64))


## The tier a phone starts on before the player has chosen one: a weak phone Low, a flagship High, the rest the
## profile's default. (A computer: the default.)
static func starting_tier() -> int:
	return tier_for_class(device_class())


## The tier a phone of that class (device_class) starts on.
static func tier_for_class(c: int) -> int:
	if c < 0:
		return LOW
	if c > 0:
		return HIGH
	return int(spec().default)


## The player's choice: any tier (the phone only picks the first one).
static func allowed(t: int) -> int:
	return clampi(t, LOW, HIGH)


## -1 a weak phone (under 4.5 GB, or a Galaxy A0x/A1x-class GPU: Mali-G5x/G6x, Adreno 5xx and 61x, PowerVR, Mali-T -
## a Galaxy A16 is here), 1 a flagship (6 GB and Adreno 640 or later, Mali-G710 or later, Immortalis, Xclipse), 0 the
## rest. (Hurling's first-run choice, from its players' phones: Game.detect_graphics.)
static func device_class(gpu := "", ram_gb := -1.0) -> int:
	if gpu.is_empty():
		if not OS.has_feature("mobile"):
			return 0
		gpu = RenderingServer.get_video_adapter_name()
	if ram_gb < 0.0:
		ram_gb = float(OS.get_memory_info().get("physical", 0)) / 1073741824.0
	gpu = gpu.to_lower()
	if ram_gb > 0.0 and ram_gb < 4.5:
		return -1
	for weak in ["mali-g5", "mali-g6", "mali-t", "mali-4", "powervr", "adreno (tm) 5", "adreno (tm) 61", "adreno (tm) 4",
			"img bxm", "ge8"]:
		if gpu.contains(weak):
			return -1
	if ram_gb >= 5.5:
		if gpu.contains("immortalis") or gpu.contains("xclipse"):
			return 1
		var adreno := _model_number(gpu, "adreno")
		var mali := _model_number(gpu, "mali-g")
		if adreno >= 640 or mali >= 710:
			return 1
	return 0


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


static func block_vulkan(name: String) -> void:
	model_blocklist.append(name.to_lower())


## A Vulkan game, at start: a phone on the blocklists, or whose last start on Vulkan never reached boot_ok() (it
## crashed), draws with GL Compatibility from its next start (the override file); Godot's own fallback
## (rendering/rendering_device/fallback_to_opengl3, set it in project.godot) covers a phone that cannot start Vulkan
## at all. Returns "gl_next_start" when it has set that, else "".
static func guard_renderer() -> String:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility" or not OS.has_feature("mobile"):
		return ""
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var model := OS.get_model_name().to_lower()
	var bad := FileAccess.file_exists(BOOT_FLAG)
	for w in vulkan_blocklist:
		bad = bad or gpu.contains(w)
	for m in model_blocklist:
		bad = bad or model.contains(m)
	if bad:
		use_gl(true)
		return "gl_next_start"
	var f := FileAccess.open(BOOT_FLAG, FileAccess.WRITE)
	if f:
		f.store_string("vulkan start\n")
	return ""


## The home screen is up: this start on Vulkan did not crash.
static func boot_ok() -> void:
	if FileAccess.file_exists(BOOT_FLAG):
		DirAccess.remove_absolute(BOOT_FLAG)


## For the next start: GL Compatibility (on), or the project's own renderer (off).
static func use_gl(on: bool) -> void:
	if on:
		var f := FileAccess.open(OVERRIDE, FileAccess.WRITE)
		if f:
			f.store_string('[rendering]\n\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"\n')
	elif FileAccess.file_exists(OVERRIDE):
		DirAccess.remove_absolute(OVERRIDE)


## Full detail for the bodies nearest the camera (full_bodies() of them), the light mesh and plain joints for the
## rest. Call every half second or so with the game's WsgBody nodes.
static func rank_detail(bodies: Array, camera: Vector3) -> void:
	var n := full_bodies()
	if bodies.size() <= n:
		for b in bodies:
			(b as WsgBody).set_detail(true)
		return
	var order := bodies.duplicate()
	order.sort_custom(func(a, b): return (a as Node3D).global_position.distance_squared_to(camera) < (b as Node3D).global_position.distance_squared_to(camera))
	for i in order.size():
		(order[i] as WsgBody).set_detail(i < n)
