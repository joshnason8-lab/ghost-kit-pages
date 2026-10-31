class_name Flags
extends RefCounted
## Procedural national flags for the international teams.
## Every flag is drawn with plain Image pixel work at a supersampled size and
## scaled down with Lanczos filtering, so no flag art ships with the game.
## Unknown ids (league franchises) get a plain swatch of the team's main colour.

static var _cache: Dictionary = {}


## Flag texture for a team id, cached per id and size.
static func texture(id: String, w := 60, h := 40) -> ImageTexture:
	var key := "%s_%d_%d" % [id, w, h]
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(image(id, w, h))
	_cache[key] = tex
	return tex


## RGBA8 image of a team's flag at w x h pixels.
static func image(id: String, w: int, h: int) -> Image:
	w = maxi(w, 1)
	h = maxi(h, 1)
	# Small icons get extra supersampling so thin details survive the downscale.
	var ss: int = 4 if h < 64 else 2
	var img := Image.create_empty(w * ss, h * ss, false, Image.FORMAT_RGBA8)
	match id:
		"IND":
			_india(img)
		"IRN":
			_iran(img)
		"KOR":
			_korea(img)
		"PAK":
			_pakistan(img)
		"BAN":
			_bangladesh(img)
		"KEN":
			_kenya(img)
		"JPN":
			_japan(img)
		"ARG":
			_argentina(img)
		"NEP":
			_nepal(img)
		"SRI":
			_sri_lanka(img)
		"THA":
			_thailand(img)
		"POL":
			_poland(img)
		_:
			img.fill(_team_colour(id))
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return img


## Main kit colour of a non-country team, or grey when the id is unknown.
static func _team_colour(id: String) -> Color:
	var t: Dictionary = DB.team(id)
	if t.has("c1"):
		return t.c1
	return Color(0.5, 0.5, 0.5)


# --- Flags -------------------------------------------------------------------


static func _india(img: Image) -> void:
	_stripes_h(img, [Color("ff9933"), Color.WHITE, Color("138808")])
	var s := _size(img)
	var ctr := s * 0.5
	var r := s.y * 0.135
	var navy := Color("000080")
	# Ashoka Chakra: rim, hub and 12 spokes.
	_ring(img, navy, ctr, r * 0.84, r)
	_disc(img, navy, ctr, r * 0.2)
	for i in 12:
		var dir := Vector2.from_angle(TAU * i / 12.0)
		_segment(img, navy, ctr, ctr + dir * r * 0.9, r * 0.09)


static func _iran(img: Image) -> void:
	_stripes_h(img, [Color("239f40"), Color.WHITE, Color("da0000")])
	var s := _size(img)
	var ctr := s * 0.5
	var red := Color("da0000")
	var r := s.y * 0.085
	# Tulip-like emblem: two outward-facing crescents around a central stem.
	var off := Vector2(r * 0.45, 0.0)
	_crescent(img, red, ctr - Vector2(r * 0.15, 0.0), r, ctr + off * 0.6, r * 0.88)
	_crescent(img, red, ctr + Vector2(r * 0.15, 0.0), r, ctr - off * 0.6, r * 0.88)
	_segment(img, red, ctr - Vector2(0.0, r * 1.05), ctr + Vector2(0.0, r * 1.05), r * 0.2)


static func _korea(img: Image) -> void:
	img.fill(Color.WHITE)
	var s := _size(img)
	var ctr := s * 0.5
	var h := s.y
	var red := Color("cd2e3a")
	var blue := Color("0047a0")
	# Taegeuk: axis tilted along the top-left / bottom-right diagonal, red above it.
	var r := h * 0.25
	var d := s.normalized()
	var n := Vector2(s.y, -s.x).normalized()
	var head_red := ctr - d * r * 0.5
	var head_blue := ctr + d * r * 0.5
	var half := r * 0.5
	_fill(img, red, _box(ctr, r), func(p: Vector2) -> bool:
		if p.distance_squared_to(ctr) > r * r:
			return false
		if p.distance_squared_to(head_red) <= half * half:
			return true
		if p.distance_squared_to(head_blue) <= half * half:
			return false
		return (p - ctr).dot(n) > 0.0)
	_fill(img, blue, _box(ctr, r), func(p: Vector2) -> bool:
		if p.distance_squared_to(ctr) > r * r:
			return false
		if p.distance_squared_to(head_blue) <= half * half:
			return true
		if p.distance_squared_to(head_red) <= half * half:
			return false
		return (p - ctr).dot(n) <= 0.0)
	# Trigrams, true = solid bar, listed from the centre outwards.
	_trigram(img, ctr, Vector2(-s.x, -s.y), [true, true, true])       # geon, top-left
	_trigram(img, ctr, Vector2(s.x, -s.y), [false, true, false])      # gam, top-right
	_trigram(img, ctr, Vector2(-s.x, s.y), [true, false, true])       # ri, bottom-left
	_trigram(img, ctr, Vector2(s.x, s.y), [false, false, false])      # gon, bottom-right


## One group of three black bars, perpendicular to the diagonal toward a corner.
static func _trigram(img: Image, ctr: Vector2, toward: Vector2, solid: Array) -> void:
	var h := float(img.get_height())
	var dir := toward.normalized()
	var across := Vector2(-dir.y, dir.x)
	var bar_w := h / 24.0
	var gap := h / 48.0
	var len_half := h / 8.0
	var start := h * 0.375 + bar_w * 0.5
	for i in 3:
		var c := ctr + dir * (start + i * (bar_w + gap))
		if solid[i]:
			_rot_rect(img, Color.BLACK, c, dir, bar_w * 0.5, len_half)
		else:
			var piece := (len_half * 2.0 - gap) * 0.25
			_rot_rect(img, Color.BLACK, c + across * (gap * 0.5 + piece), dir, bar_w * 0.5, piece)
			_rot_rect(img, Color.BLACK, c - across * (gap * 0.5 + piece), dir, bar_w * 0.5, piece)


static func _pakistan(img: Image) -> void:
	var s := _size(img)
	var h := s.y
	img.fill(Color("01411c"))
	img.fill_rect(Rect2i(0, 0, int(s.x * 0.25), int(h)), Color.WHITE)
	# Crescent opening toward the upper fly, star inside the opening.
	var ctr := Vector2(s.x * 0.625, h * 0.5)
	var up_fly := Vector2(1.0, -0.8).normalized()
	_crescent(img, Color.WHITE, ctr, h * 0.3, ctr + up_fly * h * 0.085, h * 0.265)
	_star(img, Color.WHITE, ctr + up_fly * h * 0.21, h * 0.095, h * 0.038, 5, up_fly.angle())


static func _bangladesh(img: Image) -> void:
	img.fill(Color("006a4e"))
	var s := _size(img)
	_disc(img, Color("f42a41"), Vector2(s.x * 0.45, s.y * 0.5), s.x * 0.2)


static func _kenya(img: Image) -> void:
	var s := _size(img)
	var h := s.y
	# Black, red and green bands (6 parts each) with white fimbriation (1 part).
	_band_h(img, 0.0, 6.0 / 20.0, Color.BLACK)
	_band_h(img, 6.0 / 20.0, 7.0 / 20.0, Color.WHITE)
	_band_h(img, 7.0 / 20.0, 13.0 / 20.0, Color("bb0000"))
	_band_h(img, 13.0 / 20.0, 14.0 / 20.0, Color.WHITE)
	_band_h(img, 14.0 / 20.0, 1.0, Color("006600"))
	var ctr := s * 0.5
	# Crossed white spears behind the shield.
	var reach := Vector2(h * 0.26, h * 0.44)
	_segment(img, Color.WHITE, ctr - reach, ctr + reach, h * 0.022)
	_segment(img, Color.WHITE, ctr + Vector2(reach.x, -reach.y), ctr + Vector2(-reach.x, reach.y), h * 0.022)
	_ellipse(img, Color.WHITE, ctr - reach * 0.92, h * 0.025, h * 0.05)
	_ellipse(img, Color.WHITE, ctr + Vector2(reach.x, -reach.y) * 0.92, h * 0.025, h * 0.05)
	# Maasai shield: red ellipse with black outer lobes and a white centre mark.
	var rx := h * 0.15
	var ry := h * 0.39
	_ellipse(img, Color.BLACK, ctr, rx, ry)
	_ellipse(img, Color("bb0000"), ctr, rx * 0.55, ry * 0.97)
	_ellipse(img, Color.WHITE, ctr, rx * 0.2, ry * 0.16)
	_segment(img, Color.WHITE, ctr - Vector2(0.0, ry * 0.75), ctr + Vector2(0.0, ry * 0.75), h * 0.012)


static func _japan(img: Image) -> void:
	img.fill(Color.WHITE)
	var s := _size(img)
	_disc(img, Color("bc002d"), s * 0.5, s.y * 0.3)


static func _argentina(img: Image) -> void:
	var blue := Color("74acdf")
	_stripes_h(img, [blue, Color.WHITE, blue])
	var s := _size(img)
	var ctr := s * 0.5
	var h := s.y
	var gold := Color("f6b40e")
	# Sol de Mayo: 16 rays of alternating length around a disc.
	for i in 16:
		var dir := Vector2.from_angle(TAU * i / 16.0)
		var tip := h * (0.15 if i % 2 == 0 else 0.13)
		_segment(img, gold, ctr, ctr + dir * tip, h * 0.022)
	_disc(img, Color("85340a"), ctr, h * 0.075)
	_disc(img, gold, ctr, h * 0.066)


static func _nepal(img: Image) -> void:
	# Transparent outside the pennants; RGB matches the border to avoid dark fringes.
	img.fill(Color(0.0, 0.22, 0.576, 0.0))
	var s := _size(img)
	# Pennant outline in flag units (24 wide, 30 tall, y up), fitted to the height.
	var unit := s.y / 30.0
	var left := (s.x - 24.0 * unit) * 0.5
	var to_px := func(x: float, y: float) -> Vector2:
		return Vector2(left + x * unit, s.y - y * unit)
	var outline := PackedVector2Array([
		to_px.call(0.0, 30.0), to_px.call(24.0, 18.0), to_px.call(7.0, 18.0),
		to_px.call(24.0, 0.0), to_px.call(0.0, 0.0),
	])
	_poly(img, Color("003893"), outline)
	var inset := PackedVector2Array([
		to_px.call(1.4, 27.6), to_px.call(20.2, 19.4), to_px.call(3.8, 19.4),
		to_px.call(20.6, 1.4), to_px.call(1.4, 1.4),
	])
	_poly(img, Color("dc143c"), inset)
	# Moon: upward crescent in the upper pennant.
	var moon: Vector2 = to_px.call(6.2, 21.6)
	_crescent(img, Color.WHITE, moon, unit * 2.9, moon - Vector2(0.0, unit * 1.3), unit * 2.6)
	_disc(img, Color.WHITE, moon + Vector2(0.0, unit * 1.0), unit * 1.0)
	# Sun: twelve-pointed star in the lower pennant.
	_star(img, Color.WHITE, to_px.call(6.2, 7.0), unit * 3.6, unit * 2.3, 12, -PI * 0.5)


static func _sri_lanka(img: Image) -> void:
	var s := _size(img)
	var b := s.y * 0.06
	var gold := Color("ffbe29")
	var maroon := Color("8d153a")
	img.fill(gold)
	# Hoist panel: green and saffron stripes, gold between every panel.
	var stripe := s.x * 0.115
	var x := b
	img.fill_rect(_rect(x, b, stripe, s.y - b * 2.0), Color("00534e"))
	x += stripe + b * 0.6
	img.fill_rect(_rect(x, b, stripe, s.y - b * 2.0), Color("eb7400"))
	x += stripe + b
	var panel := Rect2(x, b, s.x - b - x, s.y - b * 2.0)
	img.fill_rect(Rect2i(panel), maroon)
	# Bo leaves in the panel corners.
	var leaf := panel.size.y * 0.06
	var inset := Vector2(leaf * 1.6, leaf * 1.6)
	for corner in [panel.position + inset, Vector2(panel.end.x - inset.x, panel.position.y + inset.y),
			Vector2(panel.position.x + inset.x, panel.end.y - inset.y), panel.end - inset]:
		_ellipse(img, gold, corner, leaf * 0.75, leaf)
	# Lion silhouette walking toward the hoist, sword raised in its forepaw.
	var c := panel.get_center()
	var u := panel.size.y
	_ellipse(img, gold, c + Vector2(u * 0.05, u * 0.04), u * 0.22, u * 0.11)
	_disc(img, gold, c + Vector2(-u * 0.12, -u * 0.06), u * 0.15)
	_ellipse(img, gold, c + Vector2(-u * 0.25, -u * 0.1), u * 0.08, u * 0.065)
	for leg in [Vector2(-u * 0.13, 0.0), Vector2(-u * 0.04, 0.0), Vector2(u * 0.14, 0.0), Vector2(u * 0.22, 0.0)]:
		_segment(img, gold, c + leg + Vector2(0.0, u * 0.06), c + leg + Vector2(-u * 0.02, u * 0.3), u * 0.065)
	_segment(img, gold, c + Vector2(u * 0.25, -u * 0.02), c + Vector2(u * 0.33, -u * 0.2), u * 0.035)
	_disc(img, gold, c + Vector2(u * 0.31, -u * 0.24), u * 0.05)
	_segment(img, gold, c + Vector2(-u * 0.15, -u * 0.02), c + Vector2(-u * 0.32, -u * 0.04), u * 0.05)
	_segment(img, gold, c + Vector2(-u * 0.34, u * 0.02), c + Vector2(-u * 0.34, -u * 0.36), u * 0.03)
	_segment(img, gold, c + Vector2(-u * 0.39, -u * 0.02), c + Vector2(-u * 0.29, -u * 0.02), u * 0.03)


static func _thailand(img: Image) -> void:
	var red := Color("a51931")
	var blue := Color("2d2a4a")
	_stripes_h(img, [red, Color.WHITE, blue, blue, Color.WHITE, red])


static func _poland(img: Image) -> void:
	_stripes_h(img, [Color.WHITE, Color("dc143c")])


# --- Drawing helpers ---------------------------------------------------------


static func _size(img: Image) -> Vector2:
	return Vector2(img.get_width(), img.get_height())


static func _rect(x: float, y: float, w: float, h: float) -> Rect2i:
	return Rect2i(roundi(x), roundi(y), roundi(w), roundi(h))


## Square bounding box around a centre.
static func _box(ctr: Vector2, r: float) -> Rect2:
	return Rect2(ctr - Vector2(r, r), Vector2(r, r) * 2.0)


## Equal horizontal stripes, top to bottom.
static func _stripes_h(img: Image, colours: Array) -> void:
	var n := colours.size()
	for i in n:
		_band_h(img, float(i) / n, float(i + 1) / n, colours[i])


## Horizontal band between two fractions of the height.
static func _band_h(img: Image, from: float, to: float, c: Color) -> void:
	var h := img.get_height()
	var y0 := roundi(from * h)
	var y1 := roundi(to * h)
	img.fill_rect(Rect2i(0, y0, img.get_width(), y1 - y0), c)


## Paints every pixel in box whose centre passes the inside test.
static func _fill(img: Image, c: Color, box: Rect2, inside: Callable) -> void:
	var x0 := maxi(0, floori(box.position.x))
	var y0 := maxi(0, floori(box.position.y))
	var x1 := mini(img.get_width(), ceili(box.end.x) + 1)
	var y1 := mini(img.get_height(), ceili(box.end.y) + 1)
	for y in range(y0, y1):
		for x in range(x0, x1):
			if inside.call(Vector2(x + 0.5, y + 0.5)):
				img.set_pixel(x, y, c)


static func _disc(img: Image, c: Color, ctr: Vector2, r: float) -> void:
	_fill(img, c, _box(ctr, r), func(p: Vector2) -> bool: return p.distance_squared_to(ctr) <= r * r)


static func _ring(img: Image, c: Color, ctr: Vector2, r_in: float, r_out: float) -> void:
	_fill(img, c, _box(ctr, r_out), func(p: Vector2) -> bool:
		var d2 := p.distance_squared_to(ctr)
		return d2 <= r_out * r_out and d2 >= r_in * r_in)


static func _ellipse(img: Image, c: Color, ctr: Vector2, rx: float, ry: float) -> void:
	var box := Rect2(ctr - Vector2(rx, ry), Vector2(rx, ry) * 2.0)
	_fill(img, c, box, func(p: Vector2) -> bool:
		var q := (p - ctr) / Vector2(rx, ry)
		return q.length_squared() <= 1.0)


## Disc of radius r with a second disc cut out of it.
static func _crescent(img: Image, c: Color, ctr: Vector2, r: float, cut_ctr: Vector2, cut_r: float) -> void:
	_fill(img, c, _box(ctr, r), func(p: Vector2) -> bool:
		return p.distance_squared_to(ctr) <= r * r and p.distance_squared_to(cut_ctr) > cut_r * cut_r)


## Thick line from a to b with round ends.
static func _segment(img: Image, c: Color, a: Vector2, b: Vector2, width: float) -> void:
	var hw := width * 0.5
	var box := Rect2(a, Vector2.ZERO).expand(b).grow(hw)
	_fill(img, c, box, func(p: Vector2) -> bool:
		return p.distance_squared_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= hw * hw)


## Rectangle centred on ctr, half_along along dir and half_across perpendicular to it.
static func _rot_rect(img: Image, c: Color, ctr: Vector2, dir: Vector2, half_along: float, half_across: float) -> void:
	var across := Vector2(-dir.y, dir.x)
	_fill(img, c, _box(ctr, half_along + half_across), func(p: Vector2) -> bool:
		var q := p - ctr
		return absf(q.dot(dir)) <= half_along and absf(q.dot(across)) <= half_across)


static func _poly(img: Image, c: Color, pts: PackedVector2Array) -> void:
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	_fill(img, c, box, func(p: Vector2) -> bool: return Geometry2D.is_point_in_polygon(p, pts))


## Star with the given number of points, first point aimed at angle rot.
static func _star(img: Image, c: Color, ctr: Vector2, r_out: float, r_in: float, points: int, rot: float) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := r_out if i % 2 == 0 else r_in
		pts.append(ctr + Vector2.from_angle(rot + PI * i / points) * r)
	_poly(img, c, pts)
