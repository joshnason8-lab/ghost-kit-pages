extends WsgWorldGame
## Pok Ta Pok Rivals' side of the shared world check (docs/WORLD_RULES.md, ADOPTING §5.18): every rule on the game's
## own code. Each mode started as its menu's tap does (Game.start_match, the loading overlay up in that frame); the
## judges are the officials (two at every court); the walker is one of the players as a match draws him on Medium and
## High (his model on the foundation's rig through FoundationLink); the stick is the match's own (Match.stick_to_world)
## on the court-side, high and end cameras; props and crowd are the game's own audits.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 -s res://tools/wsg/world_check.gd -- --out "$RUNNER_TEMP/world"
## Drawn on Medium: the foundation's bodies are what is drawn there and on High. (Low draws the game's own body, the
## toon driver posing it from the capture: the owner notes' block-figure and A-pose tests cover it.)

const MatchScript := preload("res://game/match.gd")
const MODES := {
	"match": {"home": "ESC", "away": "LLA", "venue": "village", "rules": "ulama", "user_team": 0, "mode": "quick"},
	"watch AI": {"home": "PIS", "away": "VAL", "venue": "stone", "rules": "classic", "user_team": -1, "mode": "watch"},
	"tournament": {"home": "SAV", "away": "QUE", "venue": "festival", "rules": "ulama", "user_team": 0, "mode": "cup"},
	"night": {"home": "VAL", "away": "IZA", "venue": "night", "rules": "classic", "user_team": 0, "mode": "quick"},
}


func game_name() -> String:
	return "Pok Ta Pok Rivals"


func prop_registry() -> String:
	return "res://game/prop_runs.gd"


func prop_args() -> Array:
	return [1, 60]


func crowd_registry() -> String:
	return "res://game/crowd_venues.gd"


func modes() -> Array:
	return MODES.keys()


func play_seconds(_mode: String) -> float:
	return 6.0


## The tap: Game.start_match from a screen standing under PARENT (its buttons go dead, the overlay comes up at once).
func start_mode(mode: String, parent: Node) -> void:
	Game.settings.sound = false
	Game.settings.coach = false
	Game.settings.graphics = Game.GFX_MEDIUM
	Game.settings.auto_gfx = false
	Game.main = parent
	var host := Control.new()
	host.name = "Menu"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var start := Button.new()
	start.name = "Start"
	host.add_child(start)
	parent.add_child(host)
	Game.current = host
	var cfg: Dictionary = (MODES[mode] as Dictionary).duplicate()
	cfg.merge({"seed": 5, "length": 0.0, "difficulty": 1, "ritual": cfg.venue in ["stone", "night"]})
	Game.start_match(cfg)


## Two judges at every court (Officials: on the ground by the analco on the earth courts, on the coping on the stone).
func officials(_mode: String) -> int:
	return 2


## One of the players as a match draws him on Medium and High: the game's body (his look, his height) with the
## foundation's rig and locomotor made for it by FoundationLink, exactly as in play.
func walker(parent: Node) -> Array:
	Game.settings.graphics = Game.GFX_MEDIUM
	FoundationLink.off = false
	if not FoundationLink.enabled():
		return []
	var b := Body.new({"kind": "ulama", "skin": DB.SKINS[1], "hair": DB.HAIRS[0], "team": Color("b8352b"), "trim": Color("e9c46a"),
		"height": 1.74, "build": 0.6, "seed": 3, "foundation": true})
	parent.add_child(b)
	if b.link == null or b.link.body == null:
		return []
	b.link.body.visible = true
	return [b.link.body, b.link.loco]


## The moments' sounds: the ball off a hip, its bounce, the ring, the judges' call. (The game plays its own through
## Sfx, not positioned in the world - never dulled by distance; the kinds stand here for when it moves to WsgAudio.)
func key_sounds() -> Array:
	return ["hit", "bounce", "ring", "whistle"]


func stick_map() -> Callable:
	return func(st: Vector2, cam: Camera3D, at: Vector3) -> Vector3: return MatchScript.stick_to_world(st, cam, at)


## The match's three views (Settings: court-side, high, end), each as the camera rig sets it in play, as cameras.
func cameras(_mode: String, root: Node) -> Array:
	var out := []
	var m: Node = null
	for n in root.find_children("*", "", true, false):
		if n.get_script() == MatchScript:
			m = n
			break
	if m == null or m.cam == null:
		return out
	var keep: int = m.cam.mode
	for c in [Game.CAM_TV, Game.CAM_HIGH, Game.CAM_END]:
		m.cam.mode = c
		m.cam.snap(m)
		var cam := Camera3D.new()
		cam.name = ["court-side", "high", "end"][[Game.CAM_TV, Game.CAM_HIGH, Game.CAM_END].find(c)]
		cam.fov = m.cam.camera.fov
		root.add_child(cam)
		cam.global_transform = m.cam.camera.global_transform
		out.append(cam)
	m.cam.mode = keep
	return out
