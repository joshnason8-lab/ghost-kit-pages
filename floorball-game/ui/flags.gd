class_name Flags
extends RefCounted
## Procedural national flags for the national teams.
## Every flag is drawn with plain Image pixel work at a supersampled size and
## scaled down with Lanczos filtering, so no flag art ships with the game.
## The club season's clubs have no flag: their crest's shield (ui/crest.gd draws it with the code). Unknown ids get a
## plain swatch of the team's main colour.

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
		"SWE":
			_nordic(img, Color("006aa7"), Color("fecc02"))
		"FIN":
			_nordic(img, Color.WHITE, Color("002f6c"))
		"NOR":
			_nordic(img, Color("ba0c2f"), Color.WHITE, Color("00205b"))
		"DEN":
			_nordic(img, Color("c8102e"), Color.WHITE)
		"SUI":
			_switzerland(img)
		"CZE":
			_czechia(img)
		"SVK":
			_slovakia(img)
		"LAT":
			_latvia(img)
		"EST":
			_stripes_h(img, [Color("0072ce"), Color("000000"), Color.WHITE])
		"GER":
			_stripes_h(img, [Color("1a1a1a"), Color("dd0000"), Color("ffce00")])
		"AUT":
			_stripes_h(img, [Color("ed2939"), Color.WHITE, Color("ed2939")])
		"HUN":
			_stripes_h(img, [Color("ce2939"), Color.WHITE, Color("477050")])
		"NED":
			_stripes_h(img, [Color("ae1c28"), Color.WHITE, Color("21468b")])
		"ITA":
			_vertical(img, [Color("009246"), Color.WHITE, Color("ce2b37")])
		"POL":
			_poland(img)
		"CAN":
			_canada(img)
		"JPN":
			_japan(img)
		"THA":
			_thailand(img)
		"PHI":
			_philippines(img)
		"SGP":
			_singapore(img)
		"USA":
			_usa(img)
		"AUS":
			_australia(img)
		_:
			if DB.is_club(id):
				_crest(img, id)
			else:
				img.fill(_team_colour(id))
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return img


## Main kit colour of a non-country team, or grey when the id is unknown.
static func _team_colour(id: String) -> Color:
	var t: Dictionary = DB.team(id)
	if t.has("c1"):
		return t.c1
	return Color(0.5, 0.5, 0.5)


## A club's shield in its jersey colour on a clear ground, a band of its second colour across the top.
static func _crest(img: Image, id: String) -> void:
	img.fill(Color(0, 0, 0, 0))
	var t: Dictionary = DB.team(id)
	var fill: Color = t.home[0]
	var second: Color = t.home[1] if not DB._alike(t.home[1], fill) else t.trim
	var s := _size(img)
	var w := minf(s.x, s.y * 0.92)
	var poly := Crest.outline(w, s.y, Vector2((s.x - w) * 0.5, 0))
	for y in img.get_height():
		for x in img.get_width():
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.is_point_in_polygon(p, poly):
				img.set_pixel(x, y, second if p.y < s.y * 0.2 else fill)


# --- Flags -------------------------------------------------------------------









static func _japan(img: Image) -> void:
	img.fill(Color.WHITE)
	var s := _size(img)
	_disc(img, Color("bc002d"), s * 0.5, s.y * 0.3)





static func _thailand(img: Image) -> void:
	var red := Color("a51931")
	var blue := Color("2d2a4a")
	_stripes_h(img, [red, Color.WHITE, blue, blue, Color.WHITE, red])


static func _poland(img: Image) -> void:
	_stripes_h(img, [Color.WHITE, Color("dc143c")])






static func _philippines(img: Image) -> void:
	_stripes_h(img, [Color("0038a8"), Color("ce1126")])
	var s := _size(img)
	_poly(img, Color.WHITE, PackedVector2Array([Vector2(0, 0), Vector2(s.y * 0.866, s.y * 0.5), Vector2(0, s.y)]))
	var c := Vector2(s.y * 0.29, s.y * 0.5)
	for i in 8:
		var d := Vector2.from_angle(TAU * i / 8.0)
		_segment(img, Color("fcd116"), c, c + d * s.y * 0.14, s.y * 0.03)
	_disc(img, Color("fcd116"), c, s.y * 0.07)
	for st in [Vector2(s.y * 0.07, s.y * 0.1), Vector2(s.y * 0.07, s.y * 0.9), Vector2(s.y * 0.72, s.y * 0.5)]:
		_star(img, Color("fcd116"), st, s.y * 0.045, s.y * 0.018, 5, -PI * 0.5)


static func _singapore(img: Image) -> void:
	_stripes_h(img, [Color("ef3340"), Color.WHITE])
	var s := _size(img)
	var c := Vector2(s.y * 0.3, s.y * 0.25)
	_crescent(img, Color.WHITE, c, s.y * 0.17, c + Vector2(s.y * 0.06, 0), s.y * 0.15)
	for i in 5:
		var a := -PI * 0.5 + TAU * i / 5.0
		_star(img, Color.WHITE, c + Vector2(s.y * 0.11, 0) + Vector2.from_angle(a) * s.y * 0.07, s.y * 0.028, s.y * 0.011, 5, -PI * 0.5)





static func _usa(img: Image) -> void:
	var cols := []
	for i in 13:
		cols.append(Color("b22234") if i % 2 == 0 else Color.WHITE)
	_stripes_h(img, cols)
	var s := _size(img)
	var cw := s.x * 0.4
	var ch := s.y * 7.0 / 13.0
	img.fill_rect(_rect(0, 0, cw, ch), Color("3c3b6e"))
	for r in 5:
		for c in 6:
			_star(img, Color.WHITE, Vector2((c + 0.5 + 0.5 * (r % 2)) * cw / 6.5, (r + 0.6) * ch / 5.2), ch * 0.055, ch * 0.022, 5, -PI * 0.5)


static func _australia(img: Image) -> void:
	img.fill(Color("00008b"))
	var s := _size(img)
	var cw := s.x * 0.5
	var ch := s.y * 0.5
	# The Union Jack in the canton, simply: the saltires and the cross.
	_segment(img, Color.WHITE, Vector2.ZERO, Vector2(cw, ch), ch * 0.2)
	_segment(img, Color.WHITE, Vector2(cw, 0), Vector2(0, ch), ch * 0.2)
	_segment(img, Color("c8102e"), Vector2.ZERO, Vector2(cw, ch), ch * 0.07)
	_segment(img, Color("c8102e"), Vector2(cw, 0), Vector2(0, ch), ch * 0.07)
	img.fill_rect(_rect(cw * 0.42, 0, cw * 0.16, ch), Color.WHITE)
	img.fill_rect(_rect(0, ch * 0.4, cw, ch * 0.2), Color.WHITE)
	img.fill_rect(_rect(cw * 0.46, 0, cw * 0.08, ch), Color("c8102e"))
	img.fill_rect(_rect(0, ch * 0.44, cw, ch * 0.12), Color("c8102e"))
	_star(img, Color.WHITE, Vector2(cw * 0.5, s.y * 0.76), s.y * 0.12, s.y * 0.06, 7, -PI * 0.5)
	for p in [Vector2(0.75, 0.25), Vector2(0.62, 0.45), Vector2(0.88, 0.42), Vector2(0.75, 0.8)]:
		_star(img, Color.WHITE, Vector2(s.x * p.x, s.y * p.y), s.y * 0.06, s.y * 0.028, 7, -PI * 0.5)


## Equal vertical stripes, hoist to fly.
static func _vertical(img: Image, colours: Array) -> void:
	var n := colours.size()
	var w := img.get_width()
	for i in n:
		img.fill_rect(Rect2i(roundi(float(i) / n * w), 0, roundi(float(i + 1) / n * w) - roundi(float(i) / n * w), img.get_height()), colours[i])


## A Nordic cross: the upright set toward the hoist (the flags of Sweden, Finland, Norway and Denmark), with an inner
## cross for Norway.
static func _nordic(img: Image, field: Color, cross: Color, inner := Color(0, 0, 0, 0)) -> void:
	var s := _size(img)
	img.fill(field)
	var w := s.y * 0.2
	var cx := s.x * 0.36
	img.fill_rect(_rect(cx - w * 0.5, 0, w, s.y), cross)
	img.fill_rect(_rect(0, s.y * 0.5 - w * 0.5, s.x, w), cross)
	if inner.a > 0.0:
		var iw := w * 0.5
		img.fill_rect(_rect(cx - iw * 0.5, 0, iw, s.y), inner)
		img.fill_rect(_rect(0, s.y * 0.5 - iw * 0.5, s.x, iw), inner)


## Switzerland's white cross on red (drawn in a 3:2 frame, as the teams' flags are shown side by side).
static func _switzerland(img: Image) -> void:
	var s := _size(img)
	img.fill(Color("d52b1e"))
	var c := s * 0.5
	var arm := s.y * 0.3
	var w := s.y * 0.2
	img.fill_rect(_rect(c.x - w * 0.5, c.y - arm, w, arm * 2.0), Color.WHITE)
	img.fill_rect(_rect(c.x - arm, c.y - w * 0.5, arm * 2.0, w), Color.WHITE)


static func _czechia(img: Image) -> void:
	var s := _size(img)
	_stripes_h(img, [Color.WHITE, Color("d7141a")])
	_poly(img, Color("11457e"), PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.5, s.y * 0.5), Vector2(0, s.y)]))


## Slovakia: white, blue, red, the shield with its double cross toward the hoist (simplified).
static func _slovakia(img: Image) -> void:
	var s := _size(img)
	_stripes_h(img, [Color.WHITE, Color("0b4ea2"), Color("ee1c25")])
	var x0 := s.x * 0.17
	var w := s.x * 0.24
	var y0 := s.y * 0.22
	var h := s.y * 0.58
	_poly(img, Color.WHITE, PackedVector2Array([Vector2(x0 - 2, y0 - 2), Vector2(x0 + w + 2, y0 - 2), Vector2(x0 + w + 2, y0 + h * 0.62), Vector2(x0 + w * 0.5, y0 + h + 3), Vector2(x0 - 2, y0 + h * 0.62)]))
	_poly(img, Color("ee1c25"), PackedVector2Array([Vector2(x0, y0), Vector2(x0 + w, y0), Vector2(x0 + w, y0 + h * 0.62), Vector2(x0 + w * 0.5, y0 + h), Vector2(x0, y0 + h * 0.62)]))
	var cx := x0 + w * 0.5
	img.fill_rect(_rect(cx - w * 0.06, y0 + h * 0.1, w * 0.12, h * 0.62), Color.WHITE)
	img.fill_rect(_rect(cx - w * 0.3, y0 + h * 0.22, w * 0.6, h * 0.08), Color.WHITE)
	img.fill_rect(_rect(cx - w * 0.38, y0 + h * 0.4, w * 0.76, h * 0.09), Color.WHITE)
	_ellipse(img, Color("0b4ea2"), Vector2(cx, y0 + h * 0.86), w * 0.36, h * 0.12)


static func _latvia(img: Image) -> void:
	img.fill(Color("9e3039"))
	_band_h(img, 0.4, 0.6, Color.WHITE)


## Canada: red bands at each end, a red maple leaf on white (a simplified leaf).
static func _canada(img: Image) -> void:
	var s := _size(img)
	img.fill(Color.WHITE)
	img.fill_rect(_rect(0, 0, s.x * 0.25, s.y), Color("d80621"))
	img.fill_rect(_rect(s.x * 0.75, 0, s.x * 0.25, s.y), Color("d80621"))
	var c := Vector2(s.x * 0.5, s.y * 0.52)
	var k := s.y * 0.4
	var leaf := [Vector2(0, -1), Vector2(0.18, -0.62), Vector2(0.38, -0.72), Vector2(0.3, -0.25), Vector2(0.75, -0.55), Vector2(0.62, -0.2),
		Vector2(0.88, -0.05), Vector2(0.45, 0.25), Vector2(0.5, 0.48), Vector2(0.06, 0.38), Vector2(0.06, 0.85), Vector2(-0.06, 0.85),
		Vector2(-0.06, 0.38), Vector2(-0.5, 0.48), Vector2(-0.45, 0.25), Vector2(-0.88, -0.05), Vector2(-0.62, -0.2), Vector2(-0.75, -0.55),
		Vector2(-0.3, -0.25), Vector2(-0.38, -0.72), Vector2(-0.18, -0.62)]
	var pts := PackedVector2Array()
	for p in leaf:
		pts.append(c + p * k)
	_poly(img, Color("d80621"), pts)


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
