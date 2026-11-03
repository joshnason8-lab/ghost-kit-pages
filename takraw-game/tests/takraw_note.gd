class_name TakrawNote
extends WsgOwnerNote
## Sepak Takraw's side of the owner's notes (ADOPTING §5.16; tools/wsg/owner_notes.gd runs every note listed in
## INDEX.json): a match built as the game builds it and played at 30 frames a second as fast as the machine goes, its
## cameras, and the venues. Each note's check() measures the symptom the owner saw over its whole range.

const DT := 1.0 / 30.0

var _made: Array = []


## A match under the tree's root, held still and played by play(): CONFIG over a Watch-AI regu at the National Arena.
## GRAPHICS: Game.GFX_LOW draws the game's own bodies; Medium and High the shared foundation's (FoundationLink), where
## its licensed library is here (CI fetches it; else they are the game's own, as on a fork's build).
func make_match(config := {}, graphics := Game.GFX_LOW) -> Node:
	Game.reset_settings_for_tests()
	Game.settings.sound = false
	Game.settings.graphics = graphics
	WsgFoundation.tier = graphics
	FoundationLink.off = graphics == Game.GFX_LOW
	var c := {"home": "THA", "away": "MAS", "venue": "national", "event": "regu", "sets": 1, "points": 15,
		"user_team": -1, "demo": true, "seed": 4, "mode": "quick"}
	c.merge(config, true)
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = c
	m.process_mode = Node.PROCESS_MODE_DISABLED   # (played here, frame by frame)
	tree.root.add_child(m)
	_made.append(m)
	return m


## Plays M on for SECS (or until it is over), calling EACH(m) after every frame; a frame of the tree now and then, or
## after every one (DRAWN: the shared foundation's bodies are posed in the tree's frame - what they draw is read there).
func play(m: Node, secs: float, each := Callable(), drawn := false) -> void:
	for i in int(secs / DT):
		m._process(DT)
		m.set("_start_replay_after", -1.0)   # (no replays: they put the bodies back where they were)
		if drawn:
			await frame()
		if each.is_valid():
			each.call(m)
		if int(m.state) == int(m.S.OVER) or bool(m.get_meta("note_done", false)):
			break
		if not drawn and i % 300 == 299:
			await frame()


## The match's camera in each of its views (broadcast, side on, behind your end), set as in play: a Camera3D each, in
## a 1280x720 viewport (the joystick checks read them).
func cameras(m: Node) -> Array:
	var sv := SubViewport.new()
	sv.size = Vector2i(1280, 720)
	tree.root.add_child(sv)
	_made.append(sv)
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
		sv.add_child(c)
		c.global_transform = rig.global_transform
		out.append(c)
	rig.mode = keep
	rig.snap()
	return out


## The gliding in AI play (tests/glide_probe.gd: a 150 s regu, the game's own bodies), measured once for every note
## that asks: {kind: [frames, metres moved, metres slid]}, and "_steps": {kind: [a planted foot's slip in each step (m)]}.
static var _glide := {}


func glide() -> Dictionary:
	if _glide.is_empty():
		Game.reset_settings_for_tests()
		Game.settings.sound = false
		Game.settings.graphics = Game.GFX_LOW
		FoundationLink.off = true
		var holder := Node.new()
		tree.root.add_child(holder)
		_glide = GlideProbe.measure(holder, 150.0, [7])
		holder.queue_free()
		await frame()
	return _glide


## Of the way the players went in KINDS with a foot on the floor, the share that foot slid along with them: [share, m].
func glide_share(kinds: Array) -> Array:
	var g: Dictionary = await glide()
	var moved := 0.0
	var slid := 0.0
	for k in kinds:
		if g.has(k):
			moved += float(g[k][1])
			slid += float(g[k][2])
	return [slid / maxf(moved, 0.001), moved]


## The median planted-foot slip a step in KIND (m) and how many steps: [median, n].
func step_slip(kind: String) -> Array:
	var g: Dictionary = await glide()
	var v: Array = (g.get("_steps", {}) as Dictionary).get(kind, []).duplicate()
	v.sort()
	return [float(v[v.size() / 2]) if not v.is_empty() else INF, v.size()]


## Every venue's id.
func venues() -> Array:
	return DB.VENUES.map(func(v): return String(v[0]))


## Everything this note made, gone (call at the end of check()).
func clean() -> void:
	for n in _made:
		if is_instance_valid(n):
			(n as Node).queue_free()
	_made.clear()
	FoundationLink.off = false
	await frame()
