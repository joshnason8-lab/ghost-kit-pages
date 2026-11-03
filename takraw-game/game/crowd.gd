class_name Crowd
extends Node3D
## The spectators (0.15.0): the shared foundation's crowd, as the owner asked of every game - fans sitting on their
## seats (not in them, not floating), standing on the floor, never inside a seat, a row or a rail, and facing the
## play. Each venue's seats and standing room are declared (Arena.crowd_venue: WsgCrowdVenue sections, the same rows,
## heights and depths as Arena builds), the foundation places every fan (square to their row, turned toward the court
## at most 50 degrees; a seated fan's feet on the floor in front of their seat), and they are drawn as flat cards of
## the shared fans (WsgCrowdCards: sized to their seat, standing just in front of it, turned to the camera at most 35
## degrees off the way they face) in ONE draw call at every graphics level. A share of the places is filled by the
## level (Game.crowd_density). They get up and cheer with the play (set_excite: the shared crowd's excitement), wear
## the home side's colours more than any other, and hold up the two teams' flags here and there (show_teams; the
## flags are this game's own).
## The near side's fans (facing +z, toward the court, as the broadcast and side cameras do over their heads) are their
## own set, hidden while the camera looks the way they face: a card has only its front, and seen from behind it turns
## edge on, a sliver (the end camera, from the side, shows them).

const FLAG_W := 96       # a flag's pixels (in the crowd)
const FLAG_H := 64
## The fans' looks (WsgCrowdCards.set_looks, sRGB, dark to light): a Southeast Asian crowd - mostly darker skin, black
## and dark brown hair; jeans, dark trousers, shorts.
const SKIN := [Color("4f3221"), Color("63402b"), Color("744d33"), Color("85593c"), Color("966747"), Color("a87654"),
	Color("ba8763"), Color("cc9b78")]
const HAIR := [Color("0b0908"), Color("110d0b"), Color("17120e"), Color("1e1712"), Color("261d16"), Color("30241b"),
	Color("3d2e22"), Color("58432f")]
const LEGS := [Color("16181d"), Color("23262c"), Color("1f2b3d"), Color("2c3d58"), Color("3d4a5c"), Color("4a4a4f"),
	Color("5c4c3a"), Color("8a7a62")]

const BEHIND_Z := 0.5      # a fan facing +z more than this is the near side's
const BEHIND_LOOK := 0.35  # hidden while the camera looks +z more than this (over their backs)

static var _flag_mat: ShaderMaterial
static var _flag_mesh: ArrayMesh
static var _excite := 0.0

var cards: WsgCrowdCards                      # the fans the cameras see from in front or from the side
var cards_behind: WsgCrowdCards               # the near side's, facing the way the cameras over them look
var places := {}                              # WsgCrowdVenue.place(): every place in the venue
var shown := PackedInt32Array()               # the places filled (by the level's density)
var _flag_at: Array[Transform3D] = []         # where the flags are held up
var _flag_mi: MultiMeshInstance3D


## The crowd for a venue: density of its places filled (seeded), palette[0] (the home side's colour) on most shirts
## that are not just anyone's.
func build(venue: WsgCrowdVenue, density: float, palette: Array, seed_ := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	places = venue.place(seed_)
	shown = PackedInt32Array()
	var front := PackedInt32Array()
	var behind := PackedInt32Array()
	var shirts := []
	# Exactly the level's share of the places, picked at random (a seeded shuffle: a small venue's share as true as a
	# big one's).
	var n: int = places.spots.size()
	var order := range(n)
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = order[i]
		order[i] = order[j]
		order[j] = t
	var take := {}
	for k in roundi(n * clampf(density, 0.0, 1.0)):
		take[order[k]] = true
	for i in n:
		if take.has(i):
			shown.append(i)
			if (places.facings[i] as Vector3).z > BEHIND_Z:
				behind.append(i)
			else:
				front.append(i)
		var col: Color = palette[rng.randi_range(0, palette.size() - 1)] if not palette.is_empty() and rng.randf() < 0.45 \
			else Color(rng.randf(), rng.randf(), rng.randf())
		shirts.append(col)
	_excite = 0.0
	WsgCrowd3D.set_excite(0.0)
	for old in [cards, cards_behind]:
		if old:
			old.queue_free()
	cards = _card_set(front, seed_, shirts, palette)
	cards_behind = _card_set(behind, seed_ + 1, shirts, palette)
	_flags(rng, palette)


## A set of the places drawn as cards (none: null - WsgCrowdCards draws every place when given none).
func _card_set(which: PackedInt32Array, seed_: int, shirts: Array, palette: Array) -> WsgCrowdCards:
	if which.is_empty():
		return null
	var c := WsgCrowdCards.new()
	add_child(c)
	c.build(places, which, seed_, shirts)
	c.set_looks(SKIN, HAIR, LEGS)
	c.set_teams(palette[0] if not palette.is_empty() else Game.C_SAFFRON, palette[1] if palette.size() > 1 else Color.WHITE)
	return c


## Every card set (for the tests' audit).
func card_sets() -> Array:
	return [cards, cards_behind].filter(func(c): return c != null)


func _process(_delta: float) -> void:
	if cards_behind == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		var fwd := -cam.global_transform.basis.z
		cards_behind.visible = Vector2(fwd.x, fwd.z).normalized().y < BEHIND_LOOK


## A card's foot and the way its fan faces (the flag is held up from there).
func _card_place(k: int) -> Transform3D:
	var xf: Transform3D = cards.placed_cards[k][1]
	var f: Vector3 = places.facings[int(cards.placed_cards[k][0])]
	return Transform3D(Basis.looking_at(-Vector3(f.x, 0, f.z).normalized(), Vector3.UP), xf.origin)


## Flags held up here and there in the crowd (one in thirty), waving, harder when the crowd is up: a pole and a cloth
## each, all of them one draw call. Until show_teams says whose, two stripes of the home side's colours.
func _flags(rng: RandomNumberGenerator, palette: Array) -> void:
	_flag_at.clear()
	for k in (cards.placed_cards.size() if cards else 0):
		if rng.randf() < 0.033:
			var at := _card_place(k)
			_flag_at.append(Transform3D(at.basis.rotated(Vector3.UP, rng.randf_range(-0.7, 0.7)), at.origin + at.basis.x * 0.18))
	var img := Image.create_empty(FLAG_W, FLAG_H, false, Image.FORMAT_RGBA8)
	img.fill(palette[0] if not palette.is_empty() else Game.C_SAFFRON)
	img.fill_rect(Rect2i(0, FLAG_H / 2, FLAG_W, FLAG_H / 2), palette[1] if palette.size() > 1 else Color.WHITE)
	_show_flags(img, img, 0.0)


## The flags in the crowd are the two teams' (their countries' flags, or a club's colours): most of them the home
## side's, a third the visitors'; the shirts' team colours the two sides' too.
func show_teams(home: String, away: String) -> void:
	if cards:
		for c: WsgCrowdCards in card_sets():
			c.set_teams(DB.team(home).get("c1", Game.C_SAFFRON), DB.team(away).get("c1", Color.WHITE))
	if not _flag_at.is_empty():
		_show_flags(team_flag(home), team_flag(away), 0.35)


## A team's flag as the crowd waves it: a country's own, or a club's colours (the first, with a sash of the second).
static func team_flag(id: String) -> Image:
	var t := DB.team(id)
	if t.get("kind", "") == "country":
		return Flags.image(id, FLAG_W, FLAG_H)
	var img := Image.create_empty(FLAG_W, FLAG_H, false, Image.FORMAT_RGBA8)
	var c1: Color = t.get("c1", Game.C_SAFFRON)
	var c2: Color = t.get("c2", Color.WHITE)
	for y in FLAG_H:
		for x in FLAG_W:
			var d := float(y) / FLAG_H - (1.0 - float(x) / FLAG_W) * 0.9 - 0.05
			img.set_pixel(x, y, c2 if absf(d) < 0.16 else c1)
	return img


## The flags made: home's cloth on away_share of them, away's on the rest; the two side by side in one texture.
func _show_flags(home: Image, away: Image, away_share: float) -> void:
	if _flag_mi:
		_flag_mi.queue_free()
		_flag_mi = null
	if _flag_at.is_empty():
		return
	var both := Image.create_empty(FLAG_W * 2, FLAG_H, false, Image.FORMAT_RGBA8)
	for k in 2:
		var img: Image = (home if k == 0 else away).duplicate()
		img.convert(Image.FORMAT_RGBA8)
		if img.get_size() != Vector2i(FLAG_W, FLAG_H):
			img.resize(FLAG_W, FLAG_H, Image.INTERPOLATE_LANCZOS)
		both.blit_rect(img, Rect2i(0, 0, FLAG_W, FLAG_H), Vector2i(k * FLAG_W, 0))
	both.generate_mipmaps()
	_flag_material().set_shader_parameter("flags", ImageTexture.create_from_image(both))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _flag()
	mm.instance_count = _flag_at.size()
	for i in _flag_at.size():
		mm.set_instance_transform(i, _flag_at[i])
		# r: whose (0 home, 1 away), a: the wave's phase.
		mm.set_instance_custom_data(i, Color(1.0 if rng.randf() < away_share else 0.0, 0, 0, rng.randf()))
	_flag_mi = MultiMeshInstance3D.new()
	_flag_mi.multimesh = mm
	_flag_mi.material_override = _flag_material()
	_flag_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flag_mi)


## A flag on its pole, as held up by a spectator: the pole from the hands to 2.5 m, the cloth (UV.x along it, from the
## pole) in four strips so it can wave; UV.x below 0 marks the pole.
static func _flag() -> ArrayMesh:
	if _flag_mesh:
		return _flag_mesh
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	v.append_array([Vector3(-0.012, 1.1, 0), Vector3(0.012, 1.1, 0), Vector3(0.012, 2.5, 0), Vector3(-0.012, 2.5, 0)])
	uv.append_array([Vector2(-1, 0), Vector2(-1, 0), Vector2(-1, 1), Vector2(-1, 1)])
	idx.append_array([0, 1, 2, 0, 2, 3])
	for k in 5:
		var u := k / 4.0
		v.append_array([Vector3(u * 0.75, 1.98, 0), Vector3(u * 0.75, 2.48, 0)])
		uv.append_array([Vector2(u, 0), Vector2(u, 1)])
		if k > 0:
			var b := 4 + (k - 1) * 2
			idx.append_array([b, b + 2, b + 3, b, b + 3, b + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	_flag_mesh = ArrayMesh.new()
	_flag_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _flag_mesh


static func _flag_material() -> ShaderMaterial:
	if _flag_mat:
		return _flag_mat
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D flags : source_color, filter_linear_mipmap;   // the home side's flag, then the visitors'
uniform float excite = 0.0;
uniform float light = 1.0;
varying vec4 data;
varying float shade;
void vertex() {
	data = INSTANCE_CUSTOM;
	shade = 1.0;
	if (UV.x >= 0.0) {
		float ph = data.a * 6.2831;
		float w = TIME * (5.0 + 4.0 * excite) + ph - UV.x * 3.0;
		VERTEX.z += sin(w) * 0.16 * UV.x * (0.5 + excite);
		VERTEX.y -= 0.06 * UV.x * UV.x;
		shade = 0.86 + 0.14 * cos(w);   // the folds a little lighter and darker
	}
}
void fragment() {
	vec2 uv = vec2((clamp(UV.x, 0.02, 0.98) + data.r) * 0.5, 1.0 - UV.y);
	vec3 c = UV.x < 0.0 ? vec3(0.55) : texture(flags, uv).rgb * shade;
	ALBEDO = c * light;
}
"""
	_flag_mat = ShaderMaterial.new()
	_flag_mat.shader = sh
	return _flag_mat


## The cards' art, loaded once (the loading screen warms it).
static func sheet() -> Texture2D:
	return load(WsgCrowdCards.DIR + "cards.png") if WsgCrowdCards.available() else null


## How excited the crowd is (0-1): the fans get up and cheer (the shared crowd's excitement: up quick, down slow), the
## flags wave harder.
static func set_excite(k: float) -> void:
	_excite = clampf(k, 0.0, 1.0)
	WsgCrowd3D.set_excite(_excite)
	_flag_material().set_shader_parameter("excite", _excite)


## Where the play is. (The cards face the court as they sit; the shared 3D crowd's heads follow the ball. Kept so the
## match can say it.)
static func set_look(_at: Vector3) -> void:
	pass


static func set_light(k: float) -> void:
	WsgCrowd3D.set_light(k)
	_flag_material().set_shader_parameter("light", k)
