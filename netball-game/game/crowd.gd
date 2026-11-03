class_name Crowd
extends Node3D
## The spectators, where the venue declares them (CrowdVenues: the shared foundation's WsgCrowdVenue), placed, sized
## to their seats and turned to the play by the shared foundation. On Medium and High they are whole 3D people
## (WsgCrowd3D: about a dozen draw calls) who sit on their seats or stand on the floor, get up and cheer a goal, clap
## at the breaks and turn their heads to the ball (the match's, a replay's too), in the venue's sections the level
## draws in 3D ("solid"); in the others (the arena bowl's far tiers), and on Low everywhere, the same people as flat
## cards (WsgCrowdCards: one draw call), getting up and cheering with them. One shirt a place, decided once, about half
## in the two teams' colours.

var venue: CrowdVenues.Venue
var placed := {}                 # the places with someone in them (WsgCrowdVenue.place: spots, facings, seats...)
var shirts: Array = []           # each place's shirt
var people: WsgCrowd3D           # Medium and High: the 3D people (null on Low)
var used := PackedInt32Array()   # which places the 3D people are (Medium, High; the far tiers: cards)
var cards: WsgCrowdCards         # Low: everyone; Medium and High: any the 3D budget left out (null: none)
var _match: Node                 # whose ball they watch and whose play they cheer
var _cheer := 0.0                # seconds of a cheer left (a goal, the end of a quarter)
var _tension := 0.0              # the attack near a goal: the keen ones up before the shot
static var _tint := Color.WHITE
## People this close to the camera (m, flat) are left out: seen from just behind (the Courtside camera over a hall's
## stand, the close shot of the post beside the park's crowd) they would fill the bottom of the screen.
const NEAR_HIDE := 6.0
var _groups: Array = []          # [multimesh, transforms as placed, facings (cards; empty: 3D), flat box round them, node,
                                 # where they are (_cells)]
var _hidden := {}                # Vector2i(group, instance) -> true: left out for now
var _hidden_in: Array = []       # each group's: {instance: true} left out for now
var _cam_at := Vector3.INF


## Fills the venue's places (who came: its density), shirts from palette (the home crowd's colours) and away (the
## visitors'); teams: the two teams' colours.
func build(v: CrowdVenues.Venue, palette: Array, seed_ := 1, away: Array = [], teams: Array = []) -> void:
	venue = v
	var hd := Game.hd() and WsgCrowd3D.available() and not OS.has_environment("WSG_OFF")
	var level := clampi(int(Game.settings.graphics), 1, 2)
	# Every seat someone came to: on Medium and High those in the sections the level draws in 3D ("solid": the
	# courtside stands, the arena bowl's nearer rows) are whole 3D people, never cards - any past the 3D budget left
	# out, an empty seat - and the rest (the bowl's far tiers) person-shaped cards, one draw call (the owner, via the
	# lead, 2026-11-03: a full house, cut-outs in the far tiers only). Low: everyone as cards.
	placed = v.place(seed_)
	shirts = _shirts(placed.id, palette, away, seed_)
	var lights := _lights(v, placed.spots)
	var rest := PackedInt32Array()
	if hd:
		people = WsgCrowd3D.new()
		people.name = "People"
		add_child(people)
		# A netball crowd: about two thirds of them the two women of the shared fans (as the venue's seats allow).
		people.fan_weights = v.fan_weights
		# The 3D sections' places (the same people in the same shirts, by the place). (density 1: the places are
		# already the ones with someone in them.)
		v.solid = level
		var sub: Dictionary = v.place(seed_)
		var at := {}
		for k in placed.id.size():
			at[placed.id[k]] = k
		var sub_shirts := []
		var sub_lights := []
		for i in sub.id:
			sub_shirts.append(shirts[at[i]])
			sub_lights.append(lights[at[i]])
		var drawn := people.build_venue(v, level, Vector3.ZERO, 1.0, seed_, sub_shirts, sub_lights)
		v.solid = 0
		used = PackedInt32Array()
		for n in drawn:
			used.append(at[sub.id[n]])
		# Each their own skin, hair and trousers, skirt or shorts (no draw calls, no CPU: in the crowd's shader).
		people.set_looks(WsgCrowd3D.LOOKS.skin, WsgCrowd3D.LOOKS.hair, WsgCrowd3D.LOOKS.legs)
		if teams.size() >= 2:
			people.set_teams(teams[0], teams[1])
		for i in placed.spots.size():
			if not v.is_solid(placed.section[i], level):
				rest.append(i)
	if (not hd or not rest.is_empty()) and WsgCrowdCards.available() and not placed.spots.is_empty():
		cards = WsgCrowdCards.new()
		cards.name = "Cards"
		cards.fan_weights = v.fan_weights
		add_child(cards)
		cards.build(placed, rest, seed_, shirts, lights)
		cards.set_looks(WsgCrowd3D.LOOKS.skin, WsgCrowd3D.LOOKS.hair, WsgCrowd3D.LOOKS.legs)
		if teams.size() >= 2:
			cards.set_teams(teams[0], teams[1])
	v.solid = 0
	# Lit as the venue lights its stands (the arena's dim blue night, a hall's white light, the park's evening sun).
	WsgCrowd3D.set_light(clampf(_tint.get_luminance(), 0.3, 1.0))
	set_excite(0.0)
	WsgCrowd3D.set_tension(0.0)
	_groups = []
	_hidden = {}
	_hidden_in = []
	if people:
		for mi in people.meshes.size():
			var xfs := []
			for pl: Array in people.placed_xf[mi]:
				xfs.append(pl[0])
			_groups.append([people.meshes[mi].multimesh, xfs, [], _box(xfs), people.meshes[mi], _cells(xfs)])
			_hidden_in.append({})
	if cards:
		var xfs := []
		var fwd := []
		for c: Array in cards.placed_cards:
			xfs.append(c[1])
			fwd.append(placed.facings[c[0]])
		_groups.append([cards.mm_instance.multimesh, xfs, fwd, _box(xfs), cards.mm_instance, _cells(xfs)])
		_hidden_in.append({})


## Each place's light (WsgCrowd3D's and the cards' "lights"): darker going up into a dark roof, as the venue fades its
## stands (CrowdVenues.Venue.fade); 1 elsewhere.
static func _lights(v: CrowdVenues.Venue, spots: Array) -> Array:
	var out := []
	for p: Vector3 in spots:
		out.append(1.0 - v.fade.z * smoothstep(v.fade.x, v.fade.y, p.y))
	return out


## Each group's people by where they stand, in squares NEAR_HIDE across (Vector2i -> PackedInt32Array of instances):
## the near-camera check looks only in the squares round the camera (the arena's bowl: thousands of cards).
static func _cells(xfs: Array) -> Dictionary:
	var out := {}
	for k in xfs.size():
		var o: Vector3 = (xfs[k] as Transform3D).origin
		var c := Vector2i(floori(o.x / NEAR_HIDE), floori(o.z / NEAR_HIDE))
		if not out.has(c):
			out[c] = PackedInt32Array()
		out[c].append(k)
	return out


static func _box(xfs: Array) -> Rect2:
	var box := Rect2()
	for k in xfs.size():
		var o: Vector3 = (xfs[k] as Transform3D).origin
		box = Rect2(o.x, o.z, 0, 0) if k == 0 else box.expand(Vector2(o.x, o.z))
	return box


## Every person's transform as drawn and the way they face: [[transform, facing, is a card]] (the tests).
func everyone() -> Array:
	var out := []
	for g: Array in _groups:
		for k in (g[1] as Array).size():
			var xf: Transform3D = g[1][k]
			var f: Vector3 = g[2][k] if not (g[2] as Array).is_empty() else xf.basis.z
			out.append([global_transform * xf, f, not (g[2] as Array).is_empty()])
	return out


## Leaves out the people within NEAR_HIDE of the camera, putting back those it no longer is: only when the camera has
## moved, and only among those in the squares round it and those left out before. A mesh with everyone in it left out
## is not drawn at all.
func _hide_for(c: Vector3) -> void:
	if c.distance_squared_to(_cam_at) < 0.04:
		return
	_cam_at = c
	var c2 := Vector2(c.x, c.z)
	var cc := Vector2i(floori(c.x / NEAR_HIDE), floori(c.z / NEAR_HIDE))
	for gi in _groups.size():
		var g: Array = _groups[gi]
		var box: Rect2 = g[3]
		var was: Dictionary = _hidden_in[gi]
		if not box.grow(NEAR_HIDE).has_point(c2) and was.is_empty():
			continue
		var mm: MultiMesh = g[0]
		var xfs: Array = g[1]
		var cells: Dictionary = g[5]
		var look := was.keys()
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var cell := cc + Vector2i(dx, dz)
				if cells.has(cell):
					look.append_array(Array(cells[cell]))
		for k: int in look:
			var xf: Transform3D = xfs[k]
			var hide := Vector2(xf.origin.x, xf.origin.z).distance_squared_to(c2) < NEAR_HIDE * NEAR_HIDE
			if hide != was.has(k):
				# (Hidden: shrunk to nothing where they stand; the shaders' sums stay finite.)
				mm.set_instance_transform(k, Transform3D(xf.basis.scaled(Vector3.ONE * 0.001), xf.origin) if hide else xf)
				if hide:
					was[k] = true
					_hidden[Vector2i(gi, k)] = true
				else:
					was.erase(k)
					_hidden.erase(Vector2i(gi, k))
		(g[4] as Node3D).visible = was.size() < xfs.size()
		if was.is_empty():
			_hidden.erase(gi)
		else:
			_hidden[gi] = true


## Each place's shirt, decided once (by the place: the same person's whoever draws them): about half in the teams'
## colours (the home side's palette most, the visitors' away), the rest anything (the shaders mute them).
static func _shirts(ids: PackedInt32Array, palette: Array, away: Array, seed_: int) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	for i in ids:
		rng.seed = hash([seed_, i])
		var col := Color(rng.randf(), rng.randf(), rng.randf())
		var k := rng.randf()
		if k < 0.32 and not palette.is_empty():
			col = palette[rng.randi_range(0, palette.size() - 1)]
		elif k < 0.5 and not away.is_empty():
			col = away[rng.randi_range(0, away.size() - 1)]
		out.append(col)
	return out


func _ready() -> void:
	# The match this crowd is at (the arena's parent): its ball and its play.
	var a := get_parent()
	_match = a.get_parent() if a else null
	if _match and _match.has_signal("game_event"):
		_match.game_event.connect(_on_event)
	var outdoors: bool = a != null and a.has_method("indoor") and not a.indoor()
	for n in (a.get_children() if a else []):
		if n is DirectionalLight3D:
			# Lit from the venue's key light (the sun outdoors), as the players are; outdoors the side away from the
			# low evening sun kept lighter (the faces read).
			WsgCrowd3D.set_sun((n as DirectionalLight3D).global_transform.basis.z, 0.85 if outdoors else 0.72)
			break


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		_hide_for(cam.global_position)
	var ball = _match.get("ball") if _match else null
	if ball is Node3D:
		var b: Vector3 = (ball as Node3D).global_position
		if people:
			people.watch_ball(b)
		# (The cards look to the ball's side too, where their art has the poses: the shared cards have none yet.)
		if cards:
			cards.watch_ball(b)
		# Play near a goal (in its circle) has the keen ones on the edge of their seats; anywhere else they settle.
		var want := 0.45 if absf(b.x) > Court.HALF_L - 4.9 and absf(b.z) < 5.0 else 0.0
		_tension = move_toward(_tension, want, delta * (0.8 if want > _tension else 0.4))
		WsgCrowd3D.set_tension(_tension)
	if _cheer > 0.0:
		_cheer -= delta
		if _cheer <= 0.0:
			set_excite(0.0)


## The play as the crowd sees it: up for a goal, an ooh at a gain, applause at the end of a quarter and the match.
func _on_event(kind: String, _info: Dictionary) -> void:
	match kind:
		"goal":
			set_excite(1.0)
			_cheer = 3.0
		"gain":
			set_excite(0.45)
			_cheer = 1.2
		"period_end":
			set_excite(0.55)
			_cheer = 4.0
			if people:
				people.clap(2.2, 0.55, 5.0)
			if cards:
				cards.clap(2.2, 0.55, 5.0)
		"centre_setup":
			_tension = 0.0


static func set_excite(k: float) -> void:
	WsgCrowd3D.set_excite(k)


static func set_light(k: float) -> void:
	WsgCrowd3D.set_light(k)


## The colour of the light the crowd sits in (a dark arena's blue, a hall's warm white): how brightly they are lit.
static func set_tint(c: Color) -> void:
	_tint = c
