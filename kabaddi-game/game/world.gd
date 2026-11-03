extends WsgWorldGame
## Kabaddi Raid's side of wsg_world_check (docs/WORLD_RULES.md, ADOPTING 5.18): the game's own start code, players,
## officials, sounds, stick and cameras, checked against the rules every World Stage game keeps.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tools/wsg/world_check.gd -- --out "$RUNNER_TEMP/world" --web-pck build/web/index.pck
##
## Every start goes through Game.start_match (Play, Watch, a cup or season fixture): the modes are those starts.


func game_name() -> String:
	return "Kabaddi Raid"


func prop_registry() -> String:
	return "res://game/prop_runs.gd"


func prop_args() -> Array:
	return [1, 60]


func crowd_registry() -> String:
	return "res://game/crowd_venues.gd"


## Quick match (the player defending and raiding), Watch AI, a cup final (the walk-out, the stadium), a season fixture
## at a local ground (chairs, stools, the scorers' trestle table).
func modes() -> Array:
	return ["match", "watch AI", "cup final", "season"]


func _config(mode: String) -> Dictionary:
	var c := {"home": "MUM", "away": "PUN", "length": 0, "difficulty": 1, "arena": "dome", "mode": "quick"}
	match mode:
		"watch AI":
			c.merge({"watch": true, "autoplay": true, "arena": "beach"}, true)
		"cup final":
			c.merge({"mode": "cup", "walkout": true, "arena": "stadium", "knockout": true}, true)
		"season":
			c.merge({"mode": "season", "arena": "village"}, true)
	return c


## The tap: the quick-match screen up (its buttons there to be turned off), then its Play, as the player does it.
## Played at Medium: the shared rig draws the players and officials there and on High (Low draws the game's own
## bodies, which the pose and officials rules do not read); tiers() plays every level.
func start_mode(mode: String, parent: Node) -> void:
	# The last mode's match, finished (stopped and hidden in cameras()), is let go rather than freed as a tap would: the
	# check keeps each mode's bodies and officials to read until it frees the modes itself (free_modes); its rules
	# loop over them typed, and a freed one is a script error there.
	var last: Node = Game.current
	if last and is_instance_valid(last) and last.process_mode == Node.PROCESS_MODE_DISABLED:
		Game.current = null
	Game.main = parent
	Game.settings.sound = false
	# The level the check sets stays: on its software renderer every frame is slow, and the match would lower its own
	# graphics mid-play (Match._check_frame_rate), releasing the shared bodies the check has hold of.
	Game.settings.auto_gfx = false
	set_tier(Game.GFX_MEDIUM)
	Game.loading_overlay = true
	Game.show_screen("res://ui/quick_setup.gd")
	Game.start_match(_config(mode))


func play_seconds(_mode: String) -> float:
	return 6.0


## The referee, two umpires and two line judges on their feet (the two scorers sit at their table).
func officials(_mode: String) -> int:
	return 5


## A player as the match draws him on Medium and High: his own Meshy rig, its locomotor as FoundationLink sets it up
## (a cut measured from the way he was going), his feet turned down if his model stands toe-up.
func walker(parent: Node) -> Array:
	set_tier(Game.GFX_MEDIUM)
	var body := WsgBody.new(WsgBody.load_character(FoundationLink.DIR, "player_01"), null, 0)
	parent.add_child(body)
	var loco := WsgLocomotor.attach(body)
	loco.cut_from_heading = true
	WsgFootFlat.attach(body)
	return [body, loco]


## The key moments' sounds (Sfx.BRIGHT: a tag's slap, a body onto the mat, the referee's whistle).
func key_sounds() -> Array:
	return Sfx.BRIGHT.values()


func set_tier(t: int) -> void:
	Game.settings.graphics = t
	WsgFoundation.tier = t


## The stick as the game maps it (CameraRig.stick_to_world: up the stick is up the screen where the player stands).
func stick_map() -> Callable:
	return Callable(CameraRig, "stick_to_world")


## The match's cameras, each settled as in play: behind the player he moves, and the broadcast camera. The last the
## check asks of a mode: its match is then stopped and hidden (kept for the rules that read what was captured), so
## it does not go on playing - and drawing - under every rule after it.
func cameras(_mode: String, root: Node) -> Array:
	var out := []
	for rig in root.find_children("*", "CameraRig", true, false):
		var m: Node = rig.get_parent()
		var was: int = rig.mode
		for mode in [Game.CAM_THIRD, Game.CAM_TV]:
			rig.mode = mode
			for i in 45:
				rig.follow(m, 1.0 / 30.0)
			var c := Camera3D.new()
			c.name = "camera %s" % ["behind the player", "", "broadcast"][mode]
			c.fov = rig.cam.fov
			root.add_child(c)
			c.global_transform = rig.cam.global_transform
			out.append(c)
		rig.mode = was
	return out
