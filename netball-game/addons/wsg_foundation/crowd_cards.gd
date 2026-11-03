class_name WsgCrowdCards
extends Node3D
## The Low crowd, and the far stands at any tier: flat cards of the shared fans (crowd/cards.png, tools/bake_cards.gd)
## where a venue puts its fans (WsgCrowdVenue.place) - seated at their seat's height, standing on their floor, each
## turned toward the play (and toward the camera, at most turn off it) - in ONE draw call for the lot. They get up and
## cheer with WsgCrowd3D.set_excite, wear the team colours or the game's per-spot shirts, and take set_looks.
##
##   var cards := WsgCrowdCards.new()
##   add_child(cards)
##   cards.build(venue.place(seed))                        # Low: every place; Medium/High: crowd3d.placed and the
##   cards.set_teams(home, away)                           # spots crowd3d did not draw (build(placed, rest))
##
## Seen from behind (a camera behind a stand), a card shows the fan's back (crowd/cards_back.png; your own: use_art's
## back and back_mask), turned toward the camera from behind.
## Your own card art instead of the shared fans: use_art(atlas, mask, layout[, back, back_mask]) before build() (layout as cards.json:
## {"cols", "rows", "size": [w, h] m a cell, "poses": 3 (sit, stand, cheer), "fans": {name: {"seat": the seat's height
## in the cell, m}}}; mask: R shirt, G skin, B hair, A legs' clothes, or a blank one).

const DIR := "res://addons/wsg_foundation/crowd/"
## A card turns toward the camera at most this far off its fan's facing (radians).
const TURN := 0.6

var mm_instance: MultiMeshInstance3D
var material: ShaderMaterial
## Each card as placed: [spot index, transform (origin: the card's foot, basis: the fan's facing scaled by their
## size), fan name] - for the audit (a MultiMesh gives none back headless).
var placed_cards: Array = []
var _layout := {}
var _atlas: Texture2D
var _mask: Texture2D
var _back: Texture2D        # the same cells from behind (none: the front is shown from behind too)
var _back_mask: Texture2D
var _excite := 0.0
## How bright the cards are drawn (1: as the 3D fans; a game whose own crowd was painted brighter can match it).
var brightness := 1.0:
	set(v):
		brightness = v
		if material:
			material.set_shader_parameter("brightness", v)


static func available() -> bool:
	return ResourceLoader.exists(DIR + "cards.png") and FileAccess.file_exists(DIR + "cards.json")


func use_art(atlas: Texture2D, mask: Texture2D, layout: Dictionary, back: Texture2D = null, back_mask: Texture2D = null) -> void:
	_atlas = atlas
	_mask = mask
	_layout = layout
	_back = back
	_back_mask = back_mask


func _art() -> void:
	if _layout.is_empty():
		_layout = JSON.parse_string(FileAccess.get_file_as_string(DIR + "cards.json"))
		_atlas = load(DIR + "cards.png")
		_mask = load(DIR + "cards_mask.png")
		if ResourceLoader.exists(DIR + "cards_back.png"):
			_back = load(DIR + "cards_back.png")
			_back_mask = load(DIR + "cards_back_mask.png")


## The cards for these places (WsgCrowdVenue.place()'s dictionary; which: the indices to draw, none: all). shirts and
## lights as WsgCrowd3D.build's (one a spot; a card's shirt is exactly its Color). Seated fans are sized to their seat
## (the seat of the trousers on it).
func build(placed: Dictionary, which := PackedInt32Array(), seed := 0, shirts: Array = [], lights: Array = []) -> void:
	_art()
	if mm_instance:
		mm_instance.queue_free()
	placed_cards.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var idx := which if not which.is_empty() else PackedInt32Array(range(placed.spots.size()))
	var fans: Array = _layout.fans.keys()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true          # (each card's shirt exactly: its colour, alpha 1; none given: alpha 0)
	mm.mesh = _quad()
	mm.instance_count = idx.size()
	for k in idx.size():
		var i: int = idx[k]
		var spot: Vector3 = placed.spots[i]
		var fwd: Vector3 = placed.facings[i]
		fwd = Vector3(fwd.x, 0, fwd.z).normalized()
		var seat_h: float = placed.seat[i] if i < placed.seat.size() else 0.0
		var fi := rng.randi() % fans.size()
		var h := rng.randf_range(0.93, 1.07)
		var at := spot
		if seat_h > 0.0:
			# The fan whose legs fit the seat best, sized to it; the card just in front of the seat (its knees), so
			# the seat does not cut through it.
			var best := fi
			var err := INF
			for n in fans.size():
				var want: float = seat_h / float(_layout.fans[fans[n]].seat)
				var e := absf(want - 1.0) + rng.randf() * 0.06
				if e < err:
					err = e
					best = n
			fi = best
			h = clampf(seat_h / float(_layout.fans[fans[fi]].seat), WsgCrowd3D.FIT_MIN, WsgCrowd3D.FIT_MAX)
			var half: float = placed.half_depth[i] if placed.has("half_depth") and i < placed.half_depth.size() else 0.2
			at = spot + fwd * (half + 0.12)
			# A seat higher than they reach (a stool, a wall top): the card lifted, the seat of the trousers on it, the
			# legs hanging.
			at.y += maxf(0.0, seat_h - h * float(_layout.fans[fans[fi]].seat))
		var xf := Transform3D(Basis.looking_at(-fwd, Vector3.UP).scaled(Vector3.ONE * h), at)
		mm.set_instance_transform(k, xf)
		var li := clampf(float(lights[i]) if i < lights.size() else 1.0, 0.05, 2.0)
		mm.set_instance_custom_data(k, Color(rng.randf(), float(fi), li if seat_h > 0.0 else -li, 0.0))
		var shirt: Color = shirts[i] if i < shirts.size() and shirts[i] is Color else Color(0, 0, 0, 0)
		mm.set_instance_color(k, Color(shirt.r, shirt.g, shirt.b, 1.0 if shirt.a > 0.0 else 0.0))
		placed_cards.append([i, xf, fans[fi]])
	material = ShaderMaterial.new()
	material.shader = load("res://addons/wsg_foundation/crowd_card.gdshader")
	material.set_shader_parameter("atlas", _atlas)
	material.set_shader_parameter("mask", _mask)
	material.set_shader_parameter("has_back", _back != null)
	if _back != null:
		material.set_shader_parameter("back_atlas", _back)
		material.set_shader_parameter("back_mask", _back_mask if _back_mask != null else _mask)
	material.set_shader_parameter("cols", int(_layout.cols))
	material.set_shader_parameter("rows", int(_layout.rows))
	var poses: Variant = _layout.get("poses", 3)
	material.set_shader_parameter("poses", (poses as Array).size() if poses is Array else int(poses))
	material.set_shader_parameter("size", Vector2(_layout.size[0], _layout.size[1]))
	material.set_shader_parameter("turn", TURN)
	material.set_shader_parameter("brightness", brightness)
	var refs := {"skin": PackedVector3Array(), "hair": PackedVector3Array(), "legs": PackedVector3Array()}
	for n in 8:
		for part in refs:
			var c: Array = _layout.fans[fans[n]].get("looks", {}).get(part, [0.5, 0.5, 0.5]) if n < fans.size() else [0.5, 0.5, 0.5]
			refs[part].append(Vector3(c[0], c[1], c[2]))
	for part in refs:
		material.set_shader_parameter("ref_" + part, refs[part])
	_apply_looks()
	mm_instance = MultiMeshInstance3D.new()
	mm_instance.multimesh = mm
	mm_instance.material_override = material
	mm_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm_instance)


var _looks := {}


## As WsgCrowd3D.set_looks: each fan's skin, hair and legs' clothes from these lists (dark to light, up to 8).
func set_looks(skin: Array = [], hair: Array = [], legs: Array = []) -> void:
	_looks = {"skin": skin, "hair": hair, "legs": legs}
	_apply_looks()


func _apply_looks() -> void:
	if material == null:
		return
	for part in ["skin", "hair", "legs"]:
		var list: Array = _looks.get(part, [])
		var arr := PackedVector3Array()
		for c in list.slice(0, 8):
			arr.append(Vector3((c as Color).r, (c as Color).g, (c as Color).b))
		while arr.size() < 8:
			arr.append(Vector3.ZERO)
		var name: String = part + "s" if part != "legs" else "legs"
		material.set_shader_parameter(name, arr)
		material.set_shader_parameter("n_" + name, mini(list.size(), 8))


func set_teams(a: Color, b: Color) -> void:
	if material:
		material.set_shader_parameter("team_a", a)
		material.set_shader_parameter("team_b", b)


func _process(delta: float) -> void:
	if material == null:
		return
	# The same excitement as the 3D crowd (WsgCrowd3D.set_excite / set_tension), eased the same way.
	var target := maxf(WsgCrowd3D.target_excitement(), WsgCrowd3D.tension() * 0.55)
	_excite = lerpf(_excite, target, 1.0 - exp(-delta * (5.0 if target > _excite else 0.7)))
	material.set_shader_parameter("excite", _excite)
	material.set_shader_parameter("light", WsgCrowd3D._light)


## One card: a quad from the foot (0) to the top (1), its middle at the origin (the shader turns and sizes it).
static func _quad() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0), Vector3(-0.5, 1, 0)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# Big enough for a card turned any way, standing (the shader moves its corners).
	m.custom_aabb = AABB(Vector3(-1.5, -0.1, -1.5), Vector3(3.0, 2.8, 3.0))
	return m


## Measures the cards against their venue: each seated card's fan sits at its seat's height (their seat in the cell,
## times their size, against the seat), each card stands in front of its seat (the seat does not cut it), and faces
## the play as the 3D fans must. Returns {"cards", "fails", "hips": [min, max], "facing": most off}.
func audit(venue: WsgCrowdVenue, placed: Dictionary) -> Dictionary:
	var out := {"cards": placed_cards.size(), "fails": [], "hips": [INF, -INF], "facing": 0.0}
	var bad := {"hips": 0, "facing": 0, "in seat": 0}
	for c in placed_cards:
		var i: int = c[0]
		var xf: Transform3D = c[1]
		var h := xf.basis.get_scale().y
		var seat_h: float = placed.seat[i]
		if seat_h > 0.0:
			var he: float = (xf.origin.y - (placed.spots[i] as Vector3).y) + h * float(_layout.fans[c[2]].seat) - seat_h
			out.hips = [minf(out.hips[0], he), maxf(out.hips[1], he)]
			if he < WsgCrowdVenue.HIPS_TOL[0] - 0.03 or he > WsgCrowdVenue.HIPS_TOL[1] + 0.03:
				bad.hips += 1
			var ahead := (xf.origin - (placed.spots[i] as Vector3)).dot((placed.facings[i] as Vector3).normalized())
			if ahead < float(placed.half_depth[i]):
				bad["in seat"] += 1
		var fwd := Vector3(xf.basis.z.x, 0, xf.basis.z.z).normalized()
		var to := venue.nearest_play(xf.origin, minf(venue.play_size.x, venue.play_size.y) / 3.0) - xf.origin
		to.y = 0.0
		var off := rad_to_deg(fwd.angle_to(to.normalized())) if to.length() > 0.01 else 0.0
		out.facing = maxf(out.facing, off)
		if off > WsgCrowdVenue.FACING_MAX:
			bad.facing += 1
	for k in bad:
		if bad[k] > 0:
			out.fails.append("cards: %d %s" % [bad[k], k])
	return out
