extends WsgWorldGame
## Sepak Takraw Unleashed's side of the world rules check (tools/wsg/world_check.gd; the foundation's
## docs/WORLD_RULES.md, ADOPTING §5.18): every way into play started by its own screen and its own Play button, as the
## player's tap does, and the rules checked on the real game:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tools/wsg/world_check.gd -- --out "$RUNNER_TEMP/world"
## The bodies the rules read are the shared foundation's (WsgBody: FoundationLink), which draw the players, the
## substitutes and the officials on Medium and High, so the modes are played at High, set as the player sets it (the
## tiers rule then plays each at Low, Medium and High). Low draws the game's own bodies (RealBody), and its suite checks
## those the same ways (tests/test_runner.gd: the glide, the jitter, the officials, the joystick on every camera).

const MODES := ["quick match", "watch AI", "season", "international"]

var _kept: Array = []   # the modes played before, out of the picture (start_mode)


func _init() -> void:
	set_tier(WsgFoundation.HIGH)


func game_name() -> String:
	return "Sepak Takraw Unleashed"


## props: a Watch-AI match at every venue (game/prop_runs.gd), every player and standing official and the free ball.
func prop_registry() -> String:
	return "res://game/prop_runs.gd"


## A match of 90 s a venue (CI's prop audit before the world check: 24,300 body frames and about 2,100 ball steps each).
func prop_args() -> Array:
	return [1, 90]


## crowd: every venue's stands (game/crowd_venues.gd).
func crowd_registry() -> String:
	return "res://game/crowd_venues.gd"


func modes() -> Array:
	return MODES


## The tap: the mode's own screen, and its Play (Watch) pressed as the player presses it, at the graphics level the
## player chose (set_tier; never put up). Game.play_match puts the loading overlay up in this very call
## (WsgLoading.cover).
func start_mode(mode: String, parent: Node) -> void:
	# (The mode before is taken out of the picture but kept: the game's next screen would free it, and the check
	# still reads its bodies and officials after the next mode has started.)
	var was: Node = Game.current
	if is_instance_valid(was) and was.is_inside_tree():
		was.get_parent().remove_child(was)
		_kept.append(was)
	Game.current = null
	Game.main = parent
	match mode:
		"quick match":
			Game.show_screen("res://ui/quick_setup.gd").call("_play")
		"watch AI":
			Game.show_screen("res://ui/quick_setup.gd", {"watch": true}).call("_play")
		"season":
			Game.new_season("MY", "PRK")
			_press(Game.show_screen("res://ui/season_hub.gd"), "PLAY")
		"international":
			Game.new_cup("world", "THA")
			_press(Game.show_screen("res://ui/cup_screen.gd"), "PLAY")


## The screen's button reading KEY (its first, as the player sees it), pressed.
static func _press(screen: Node, key: String) -> void:
	for b in screen.find_children("*", "Button", true, false):
		if (b as Button).text == TranslationServer.translate(key) and (b as Button).is_visible_in_tree():
			(b as Button).pressed.emit()
			return
	push_error("world.gd: no %s button on %s" % [key, screen.name])


## The referee in his chair, the assistant referee at the other post, and a line judge at each end
## (Match._make_officials), in every mode. (FoundationLink puts each official's drawn body in "wsg_official".)
func officials(_mode: String) -> int:
	return 4


## A player as he walks between points in a match: the man the foundation draws him as (FoundationLink: the rig's man,
## his locomotor and its planter, his boots flattened), at the scale the link draws a player at under the capture.
## [] where the licensed library isn't there (a fork's build; CI fetches it).
func walker(parent: Node) -> Array:
	if not (WsgClips.available() and ResourceLoader.exists(FoundationLink.DIR + "man_rig.json")):
		return []
	var gb := RealBody.new({})
	parent.add_child(gb)
	var link := FoundationLink.new(gb, "player")
	gb.add_child(link)
	var s := link.free_scale()
	gb.queue_free()
	var body := WsgBody.new(WsgBody.load_character(FoundationLink.DIR, "man"), null, 0)
	parent.add_child(body)
	body.scale = Vector3.ONE * s
	var loco := WsgLocomotor.attach(body)
	WsgFootFlat.attach(body)
	return [body, loco]


## The graphics level as the Settings screen sets it (ui/settings_screen.gd): a level chosen, not Auto, and handed to
## the shared foundation (WsgFoundation.tier: its bodies, crowd and budgets). Game's levels are the foundation's tiers.
func set_tier(t: int) -> void:
	Game.settings.gfx_auto = false
	Game.settings.graphics = t
	WsgFoundation.tier = t


## The ball off a foot, its bounce, the net, the referee's whistle.
func key_sounds() -> Array:
	return ["kick", "bounce", "net", "whistle"]


## (The game's own Sfx plays every sound where it happens with the distance filter off - nothing on a court this size
## is muffled with distance - so the shared WsgAudio's bright kinds stand for it: they hold all four.)
func audio(parent: Node) -> WsgAudio:
	return super.audio(parent)


## The match's own stick-to-floor mapping (CameraRig.stick_world, which Match._cam_dir is: the screen's right and down
## where he is drawn, from the camera's rays).
func stick_map() -> Callable:
	return func(st: Vector2, cam: Camera3D, at: Vector3) -> Vector3: return CameraRig.stick_world(st, cam, at)


## The match's camera in each of its views (broadcast, side on, behind your end), a Camera3D each, set as in play.
func cameras(_mode: String, root: Node) -> Array:
	var m: Node = Game.current
	if m == null or not is_instance_valid(m) or not root.is_ancestor_of(m) or not (m.get("cam") is CameraRig):
		return []
	var rig: CameraRig = m.cam
	var keep: int = rig.mode
	var out := []
	for mode in [Game.CAM_TV, Game.CAM_SIDE, Game.CAM_END]:
		rig.mode = mode
		rig.snap()
		var c := Camera3D.new()
		c.name = {Game.CAM_TV: "broadcast", Game.CAM_SIDE: "side on", Game.CAM_END: "end"}[mode]
		c.fov = rig.fov
		c.near = rig.near
		c.far = rig.far
		root.add_child(c)
		c.global_transform = rig.global_transform
		out.append(c)
	rig.mode = keep
	rig.snap()
	return out
