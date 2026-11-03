extends WsgWorldGame
## Hurling's side of the shared foundation's world check (docs/WORLD_RULES.md, ADOPTING §5.18): every way the game
## starts play, started as the button's tap starts it (Game.start_match_loading, behind its loading overlay), its
## players and officials watched as drawn; a hurler as the walker; the game's own stick mapping on every camera; the
## props' and the crowd's own registries.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tools/wsg/world_check.gd -- --out "$RUNNER_TEMP/world"

const Match := preload("res://game/match.gd")


func game_name() -> String:
	return "Hurling Heroes"


func prop_registry() -> String:
	return "res://game/prop_runs.gd"


func prop_args() -> Array:
	return [1, 30]


func crowd_registry() -> String:
	return "res://game/crowd_venues.gd"


func modes() -> Array:
	return ["match", "watch AI", "practice"]


## The tap: Throw-in (a quick match you play), Watch AI, Free-taking practice - each through Game.start_match_loading,
## which puts the loading overlay up in this frame.
func start_mode(mode: String, parent: Node) -> void:
	# (One match at a time, as in the game: the last mode's is let go - a tap on a menu button replaces the menu.)
	if Game.current != null and is_instance_valid(Game.current):
		Game.current.queue_free()
	Game.current = null
	Game.main = parent
	Game.settings.sound = false
	var cfg := {"home": "KIL", "away": "TIP", "venue": "county", "seed": 3, "length": 8.0}
	match mode:
		"match":
			cfg.merge({"mode": "quick", "user_team": 0})
		"watch AI":
			cfg.merge({"mode": "watch", "user_team": -1})
		"practice":
			cfg.merge({"mode": "practice", "user_team": 0})
	Game.start_match_loading(cfg)


## The referee, two linesmen and four umpires in a match; the umpires alone at free-taking practice.
func officials(mode: String) -> int:
	return 4 if mode == "practice" else 7


## The player's graphics level as Settings sets it: the game's own setting, handed to the foundation's tier.
func set_tier(t: int) -> void:
	Game.settings.graphics = clampi(t, Game.GFX_LOW, Game.GFX_HIGH)
	WsgFoundation.tier = clampi(t, WsgFoundation.LOW, WsgFoundation.HIGH)


## Practice draws its free-taker at full detail on every level (the owner's middle ground; docs/TIER_EXCEPTIONS.md);
## everything else at the player's level.
func tier_exceptions() -> Dictionary:
	return {"practice": "2026-11-03, the owner via the lead: \"Practice graphics, the middle ground: full detail regardless of tier for the taker, the hurley, the sliotar and the posts; the crowd, the far stands, venue extras and effects follow the player's own tier.\""}


## The officials on the field: each one's drawn body (FoundationLink puts it in the group "wsg_official").
func find_officials(root: Node) -> Array:
	return super.find_officials(root).filter(func(b: Node) -> bool:
		var pl := b.get_parent().get_parent() as Player if b.get_parent() != null else null
		return pl == null or pl.visible)


## The players, not those standing down out of sight (practice's: the taker alone on the pitch).
func find_bodies(root: Node) -> Array:
	return super.find_bodies(root).filter(func(b: Node) -> bool:
		var pl := b.get_parent().get_parent() as Player if b.get_parent() != null else null
		return pl == null or pl.visible)


## A hurler as a match makes one (Player: the owner's model on the shared rig, his locomotor and planter).
func walker(parent: Node) -> Array:
	var p := Player.new({"num": 9, "line": 4, "speed": 70, "accel": 70}, 0, {"jersey": Color("1f5aa6"), "trim": Color("f2c230"), "kind": "player"})
	parent.add_child(p)
	if p.link == null:
		return []
	# (In a match the game poses its bodies itself - WsgBody.set_manual, advanced by FoundationLink.update each frame
	# it draws them; driven alone here, the skeleton poses itself each frame, as the check reads it.)
	p.link.body.set_manual(false)
	return [p.link.body, p.link.loco]


## The knocks the owner listens for: the ball off the post and the crossbar, the strike, the whistle.
func key_sounds() -> Array:
	return ["post", "strike", "whistle"]


## Hurling's mixer as Sfx sets it up (with its own bright kinds: a far bounce left dull).
func audio(parent: Node) -> WsgAudio:
	var au: WsgAudio = Sfx._mixer()
	if au == null:
		return super.audio(parent)
	return au


## The game's own stick mapping (Match.stick_world: the grass's right and down on the screen at the man).
func stick_map() -> Callable:
	return func(st: Vector2, cam: Camera3D, at: Vector3) -> Vector3: return Match.stick_world(st, cam, at)


## Each camera a match has, set as in play: the broadcast, the high one, behind the goal (and practice's own low one).
func cameras(mode: String, root: Node) -> Array:
	var out := []
	var m: Node = Game.current
	if m == null or not is_instance_valid(m) or not root.is_ancestor_of(m):
		return root.find_children("*", "Camera3D", true, false)
	if mode == "practice" and m.get("view") is Camera3D:
		out.append(m.view)
		return out
	for c in [["broadcast", Game.CAM_TV], ["high", Game.CAM_HIGH], ["behind the goal", Game.CAM_END]]:
		m.cam.mode = c[1]
		m.cam.snap(m)
		var cam := Camera3D.new()
		cam.name = c[0]
		m.add_child(cam)
		cam.global_transform = m.cam.camera.global_transform
		cam.fov = m.cam.camera.fov
		out.append(cam)
	return out
