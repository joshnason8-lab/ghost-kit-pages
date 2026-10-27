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
		"AUS":
			_australia(img)
		"NZL":
			_new_zealand(img)
		"ENG":
			_england(img)
		"SCO":
			_scotland(img)
		"WAL":
			_wales(img)
		"NIR":
			_northern_ireland(img)
		"JAM":
			_jamaica(img)
		"TTO":
			_trinidad(img)
		"BAR":
			_barbados(img)
		"RSA":
			_south_africa(img)
		"UGA":
			_uganda(img)
		"MWI":
			_malawi(img)
		"ZAM":
			_zambia(img)
		"ZIM":
			_zimbabwe(img)
		"BOT":
			_botswana(img)
		"NAM":
			_namibia(img)
		"TGA":
			_tonga(img)
		"SAM":
			_samoa(img)
		"FIJ":
			_fiji(img)
		"SGP":
			_singapore(img)
		"MAS":
			_malaysia(img)
		"SRI":
			_sri_lanka(img)
		"KEN":
			_kenya(img)
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


static func _australia(img: Image) -> void:
	img.fill(Color("00008b"))
	var s := _size(img)
	var cw := s.x * 0.5
	var ch := s.y * 0.5
	_union_jack(img, Rect2(0, 0, cw, ch), Color("00008b"))
	_star(img, Color.WHITE, Vector2(cw * 0.5, s.y * 0.76), s.y * 0.12, s.y * 0.06, 7, -PI * 0.5)
	for p in [Vector2(0.75, 0.25), Vector2(0.62, 0.45), Vector2(0.88, 0.42), Vector2(0.75, 0.8)]:
		_star(img, Color.WHITE, Vector2(s.x * p.x, s.y * p.y), s.y * 0.06, s.y * 0.028, 7, -PI * 0.5)


static func _new_zealand(img: Image) -> void:
	var blue := Color("00247d")
	img.fill(blue)
	var s := _size(img)
	_union_jack(img, Rect2(0, 0, s.x * 0.5, s.y * 0.5), blue)
	# Southern Cross: four red stars edged in white, Delta Crucis the smallest.
	var red := Color("cc142b")
	for st in [[0.75, 0.2, 0.075], [0.635, 0.43, 0.066], [0.855, 0.38, 0.07], [0.75, 0.8, 0.08]]:
		var c := Vector2(s.x * float(st[0]), s.y * float(st[1]))
		var r := s.y * float(st[2])
		_star(img, Color.WHITE, c, r, r * 0.45, 5, -PI * 0.5)
		_star(img, red, c, r * 0.68, r * 0.68 * 0.45, 5, -PI * 0.5)


static func _england(img: Image) -> void:
	img.fill(Color.WHITE)
	var s := _size(img)
	var red := Color("ce1124")
	var t := s.y * 0.2
	img.fill_rect(_rect((s.x - t) * 0.5, 0, t, s.y), red)
	img.fill_rect(_rect(0, (s.y - t) * 0.5, s.x, t), red)


static func _scotland(img: Image) -> void:
	img.fill(Color("005eb8"))
	var s := _size(img)
	var d := s.normalized() * s.y * 0.2
	_segment(img, Color.WHITE, -d, s + d, s.y * 0.2)
	_segment(img, Color.WHITE, Vector2(s.x, 0) + Vector2(d.x, -d.y), Vector2(0, s.y) + Vector2(-d.x, d.y), s.y * 0.2)


static func _wales(img: Image) -> void:
	_stripes_h(img, [Color.WHITE, Color("00ab39")])
	var s := _size(img)
	# Y Ddraig Goch: a red dragon passant facing the hoist, in a 100 x 60 design box.
	var k := s.y * 0.86 / 60.0
	var origin := s * 0.5 - Vector2(50.0, 33.0) * k
	var outline := [
		# Head, horn and neck.
		Vector2(6, 20), Vector2(12, 15), Vector2(18, 13), Vector2(22, 6), Vector2(25, 13),
		Vector2(29, 15), Vector2(33, 22), Vector2(38, 27),
		# Raised wing with a scalloped edge.
		Vector2(40, 24), Vector2(46, 12), Vector2(54, 3), Vector2(57, 10), Vector2(64, 6),
		Vector2(65, 13), Vector2(72, 12), Vector2(70, 19), Vector2(76, 20), Vector2(64, 30),
		# Back and tail curling up over the rump, ending in a barb.
		Vector2(74, 32), Vector2(82, 26), Vector2(86, 18), Vector2(86, 11), Vector2(82, 8),
		Vector2(90, 2), Vector2(94, 10), Vector2(91, 12), Vector2(92, 20), Vector2(88, 30),
		Vector2(82, 38),
		# Hind leg.
		Vector2(84, 46), Vector2(84, 55), Vector2(89, 58), Vector2(88, 61), Vector2(77, 61),
		Vector2(78, 55), Vector2(74, 47),
		# Belly and planted foreleg.
		Vector2(62, 46), Vector2(52, 46), Vector2(51, 55), Vector2(55, 59), Vector2(54, 62),
		Vector2(44, 62), Vector2(45, 55), Vector2(43, 47),
		# Raised forepaw, chest and open jaws.
		Vector2(38, 45), Vector2(31, 47), Vector2(24, 44), Vector2(26, 40), Vector2(32, 41),
		Vector2(36, 37), Vector2(32, 30), Vector2(25, 27), Vector2(17, 27), Vector2(8, 29),
		Vector2(14, 23), Vector2(6, 22),
	]
	var pts := PackedVector2Array()
	for p: Vector2 in outline:
		pts.append(origin + p * k)
	_poly(img, Color("d30731"), pts)
	# Tongue and eye.
	_segment(img, Color("d30731"), origin + Vector2(12, 25) * k, origin + Vector2(2, 26) * k, k * 1.2)
	_disc(img, Color.WHITE, origin + Vector2(19, 17) * k, k * 1.1)


## Northern Ireland has had no official national flag since the Ulster Banner
## lost official status in 1973, and its sports teams use varying emblems, so
## the game shows a neutral green field with a thin white border instead.
static func _northern_ireland(img: Image) -> void:
	img.fill(Color.WHITE)
	var s := _size(img)
	var b := s.y * 0.05
	img.fill_rect(_rect(b, b, s.x - b * 2.0, s.y - b * 2.0), Color("1a8a4a"))


static func _jamaica(img: Image) -> void:
	img.fill(Color.BLACK)
	var s := _size(img)
	var green := Color("009b3a")
	var mid := s * 0.5
	_poly(img, green, PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), mid]))
	_poly(img, green, PackedVector2Array([Vector2(0, s.y), Vector2(s.x, s.y), mid]))
	var gold := Color("fed100")
	var d := s.normalized() * s.y * 0.2
	_segment(img, gold, -d, s + d, s.y * 0.17)
	_segment(img, gold, Vector2(s.x, 0) + Vector2(d.x, -d.y), Vector2(0, s.y) + Vector2(-d.x, d.y), s.y * 0.17)


static func _trinidad(img: Image) -> void:
	img.fill(Color("ce1126"))
	var s := _size(img)
	var dir := s.normalized()
	_rot_rect(img, Color.WHITE, s * 0.5, dir, s.length(), s.y * 0.18)
	_rot_rect(img, Color.BLACK, s * 0.5, dir, s.length(), s.y * 0.14)


static func _barbados(img: Image) -> void:
	var blue := Color("00267f")
	_vertical(img, [blue, Color("ffc726"), blue])
	var s := _size(img)
	var u := s.y
	var x := s.x * 0.5
	var bk := Color.BLACK
	# Broken trident: a U of two side prongs, a centre spear and a short shaft.
	var u_pts := [Vector2(-0.145, 0.33), Vector2(-0.135, 0.46), Vector2(-0.085, 0.55), Vector2(0.0, 0.58),
		Vector2(0.085, 0.55), Vector2(0.135, 0.46), Vector2(0.145, 0.33)]
	for i in u_pts.size() - 1:
		_segment(img, bk, Vector2(x, 0) + u_pts[i] * u, Vector2(x, 0) + u_pts[i + 1] * u, u * 0.045)
	img.fill_rect(_rect(x - u * 0.022, u * 0.28, u * 0.044, u * 0.52), bk)
	img.fill_rect(_rect(x - u * 0.075, u * 0.63, u * 0.15, u * 0.035), bk)
	for tip in [-0.145, 0.0, 0.145]:
		var tx: float = x + float(tip) * u
		var top := u * (0.2 if tip == 0.0 else 0.24)
		_poly(img, bk, PackedVector2Array([Vector2(tx - u * 0.05, top + u * 0.12), Vector2(tx, top),
			Vector2(tx + u * 0.05, top + u * 0.12), Vector2(tx, top + u * 0.09)]))


static func _south_africa(img: Image) -> void:
	_stripes_h(img, [Color("e03c31"), Color("001489")])
	var s := _size(img)
	var h := s.y
	var j := Vector2(s.x * 0.4, h * 0.5)
	var green := Color("007749")
	# The Y: white-edged green arms from the hoist corners joining a horizontal band.
	for spec in [[Color.WHITE, h / 3.0], [green, h / 5.0]]:
		var c: Color = spec[0]
		var wd: float = spec[1]
		var top_dir := j.normalized()
		var bottom_dir := (j - Vector2(0, h)).normalized()
		_segment(img, c, -top_dir * h, j, wd)
		_segment(img, c, Vector2(0, h) - bottom_dir * h, j, wd)
		_segment(img, c, j, Vector2(s.x + h, h * 0.5), wd)
	# Hoist triangle: gold edge then black, nested inside the green arms.
	_hoist_triangle(img, Color("ffb81c"), j.x, h / 10.0)
	_hoist_triangle(img, Color.BLACK, j.x, h / 10.0 + h / 15.0)


static func _uganda(img: Image) -> void:
	var yellow := Color("fcdc04")
	var red := Color("d90000")
	_stripes_h(img, [Color.BLACK, yellow, red, Color.BLACK, yellow, red])
	var s := _size(img)
	var u := s.y
	var c := s * 0.5
	_disc(img, Color.WHITE, c, u * 0.2)
	# Grey crowned crane facing the hoist, right leg raised.
	u *= 1.05
	c += Vector2(0, u * 0.02)
	var grey := Color("8f9391")
	_segment(img, grey, c + Vector2(u * 0.03, u * 0.04), c + Vector2(u * 0.03, u * 0.155), u * 0.012)
	_segment(img, grey, c + Vector2(-u * 0.0, u * 0.04), c + Vector2(-u * 0.05, u * 0.09), u * 0.012)
	_segment(img, grey, c + Vector2(-u * 0.05, u * 0.09), c + Vector2(-u * 0.015, u * 0.115), u * 0.012)
	_segment(img, grey, c + Vector2(u * 0.06, u * 0.0), c + Vector2(u * 0.12, u * 0.06), u * 0.04)
	_ellipse(img, grey, c + Vector2(u * 0.03, u * 0.0), u * 0.07, u * 0.05)
	_ellipse(img, Color.WHITE, c + Vector2(u * 0.05, -u * 0.005), u * 0.035, u * 0.022)
	_segment(img, grey, c + Vector2(-u * 0.02, -u * 0.02), c + Vector2(-u * 0.04, -u * 0.11), u * 0.025)
	_segment(img, grey, c + Vector2(-u * 0.05, -u * 0.12), c + Vector2(-u * 0.1, -u * 0.105), u * 0.012)
	for a in [-2.2, -1.9, -1.6, -1.3, -1.0]:
		var head := c + Vector2(-u * 0.042, -u * 0.13)
		_segment(img, yellow, head, head + Vector2.from_angle(a) * u * 0.06, u * 0.01)
	_disc(img, Color.BLACK, c + Vector2(-u * 0.042, -u * 0.12), u * 0.022)
	_disc(img, Color.WHITE, c + Vector2(-u * 0.035, -u * 0.115), u * 0.009)
	_disc(img, red, c + Vector2(-u * 0.05, -u * 0.095), u * 0.01)


static func _malawi(img: Image) -> void:
	var s := _size(img)
	var red := Color("ce1126")
	_band_h(img, 0.0, 1.0 / 3.0, Color.BLACK)
	# Rising sun with 31 rays, its lower half hidden by the red stripe below.
	var c := Vector2(s.x * 0.5, s.y / 3.0)
	var r := s.y * 0.12
	var reach := s.y * 0.27
	var step := PI / 31.0
	for i in 31:
		var a := PI + step * (i + 0.5)
		_poly(img, red, PackedVector2Array([c + Vector2.from_angle(a - step * 0.42) * r,
			c + Vector2.from_angle(a) * reach, c + Vector2.from_angle(a + step * 0.42) * r]))
	_disc(img, red, c, r)
	_band_h(img, 1.0 / 3.0, 2.0 / 3.0, red)
	_band_h(img, 2.0 / 3.0, 1.0, Color("339e35"))


static func _zambia(img: Image) -> void:
	img.fill(Color("198a00"))
	var s := _size(img)
	var orange := Color("ef7d00")
	# Red, black and orange stripes in the lower fly.
	var bw := s.x * 0.25
	var x0 := s.x - bw
	var cols := [Color("de2010"), Color.BLACK, orange]
	for i in 3:
		img.fill_rect(_rect(x0 + bw * i / 3.0, s.y * 0.375, bw / 3.0 + 1.0, s.y * 0.625), cols[i])
	# Fish eagle in flight above the stripes.
	var e := s.y * 0.1
	var c := Vector2(x0 + bw * 0.5, s.y * 0.2)
	var wing := PackedVector2Array()
	for p in [Vector2(-1.7, -0.5), Vector2(-0.9, -0.95), Vector2(-0.3, -0.2), Vector2(0.3, -0.2),
			Vector2(0.9, -0.95), Vector2(1.7, -0.5), Vector2(0.9, 0.1), Vector2(0.3, 0.3),
			Vector2(-0.3, 0.3), Vector2(-0.9, 0.1)]:
		wing.append(c + p * e)
	_poly(img, orange, wing)
	_ellipse(img, orange, c + Vector2(0, 0.25) * e, 0.25 * e, 0.5 * e)
	_poly(img, orange, PackedVector2Array([c + Vector2(-0.3, 0.6) * e, c + Vector2(0.3, 0.6) * e, c + Vector2(0, 1.0) * e]))
	_disc(img, orange, c + Vector2(-0.05, -0.45) * e, 0.2 * e)
	_poly(img, orange, PackedVector2Array([c + Vector2(-0.2, -0.55) * e, c + Vector2(-0.45, -0.4) * e, c + Vector2(-0.15, -0.35) * e]))


static func _zimbabwe(img: Image) -> void:
	var green := Color("319208")
	var yellow := Color("ffd200")
	var red := Color("de2010")
	_stripes_h(img, [green, yellow, red, Color.BLACK, red, yellow, green])
	var s := _size(img)
	var h := s.y
	_hoist_triangle(img, Color.BLACK, h * 0.62, 0.0)
	_hoist_triangle(img, Color.WHITE, h * 0.62, h * 0.035)
	# Red star with the yellow Zimbabwe Bird perched over it.
	var c := Vector2(h * 0.21, h * 0.5)
	_star(img, red, c, h * 0.16, h * 0.065, 5, -PI * 0.5)
	var u := h * 0.01
	img.fill_rect(_rect(c.x - u * 3.0, c.y + u * 6.0, u * 6.0, u * 5.0), yellow)
	_ellipse(img, yellow, c + Vector2(0, u * 1.0), u * 3.2, u * 6.0)
	_segment(img, yellow, c + Vector2(-u * 1.0, u * 3.0), c + Vector2(-u * 3.0, u * 8.0), u * 2.0)
	_disc(img, yellow, c + Vector2(u * 0.5, -u * 6.0), u * 2.4)
	_poly(img, yellow, PackedVector2Array([c + Vector2(u * 2.0, -u * 7.5), c + Vector2(u * 5.0, -u * 5.5), c + Vector2(u * 2.0, -u * 4.5)]))


static func _botswana(img: Image) -> void:
	var blue := Color("6da9d2")
	_band_h(img, 0.0, 9.0 / 24.0, blue)
	_band_h(img, 9.0 / 24.0, 10.0 / 24.0, Color.WHITE)
	_band_h(img, 10.0 / 24.0, 14.0 / 24.0, Color.BLACK)
	_band_h(img, 14.0 / 24.0, 15.0 / 24.0, Color.WHITE)
	_band_h(img, 15.0 / 24.0, 1.0, blue)


static func _namibia(img: Image) -> void:
	var s := _size(img)
	var blue := Color("003580")
	var gold := Color("ffce00")
	img.fill(blue)
	_poly(img, Color("009543"), PackedVector2Array([Vector2(s.x, -1), Vector2(s.x + 1, s.y + 1), Vector2(-1, s.y + 1)]))
	# Red band from the lower hoist to the upper fly, edged white.
	var dir := Vector2(s.x, -s.y).normalized()
	_rot_rect(img, Color.WHITE, s * 0.5, dir, s.length(), s.y * 0.155)
	_rot_rect(img, Color("d21034"), s * 0.5, dir, s.length(), s.y * 0.12)
	# Twelve-rayed gold sun with a blue ring.
	var c := Vector2(s.y * 0.3, s.y * 0.28)
	_star(img, gold, c, s.y * 0.19, s.y * 0.11, 12, -PI * 0.5)
	_disc(img, blue, c, s.y * 0.1)
	_disc(img, gold, c, s.y * 0.084)


static func _tonga(img: Image) -> void:
	var red := Color("c10000")
	img.fill(red)
	var s := _size(img)
	var cw := s.x * 0.42
	var ch := s.y * 0.5
	img.fill_rect(_rect(0, 0, cw, ch), Color.WHITE)
	var c := Vector2(cw * 0.5, ch * 0.5)
	var t := ch * 0.2
	var arm := ch * 0.36
	img.fill_rect(_rect(c.x - t * 0.5, c.y - arm, t, arm * 2.0), red)
	img.fill_rect(_rect(c.x - arm, c.y - t * 0.5, arm * 2.0, t), red)


static func _samoa(img: Image) -> void:
	img.fill(Color("ce1126"))
	var s := _size(img)
	var cw := s.x * 0.5
	var ch := s.y * 0.5
	img.fill_rect(_rect(0, 0, cw, ch), Color("002b7f"))
	for st in [[0.5, 0.2, 0.1], [0.3, 0.48, 0.09], [0.7, 0.4, 0.09], [0.5, 0.8, 0.11], [0.6, 0.6, 0.055]]:
		var r := ch * float(st[2])
		_star(img, Color.WHITE, Vector2(cw * float(st[0]), ch * float(st[1])), r, r * 0.42, 5, -PI * 0.5)


static func _fiji(img: Image) -> void:
	var blue := Color("68bfe5")
	img.fill(blue)
	var s := _size(img)
	_union_jack(img, Rect2(0, 0, s.x * 0.5, s.y * 0.5), Color("012169"))
	# Shield: red chief with a gold lion over a white field quartered by a red cross.
	var red := Color("ce1126")
	var sw := s.y * 0.3
	var sh := s.y * 0.44
	var top := Vector2(s.x * 0.75 - sw * 0.5, s.y * 0.5 - sh * 0.45)
	var side := sh * 0.55
	var pts := PackedVector2Array([top, top + Vector2(sw, 0)])
	for i in 13:
		var a := PI * i / 12.0
		pts.append(top + Vector2(sw * 0.5 + cos(a) * sw * 0.5, side + sin(a) * (sh - side)))
	_poly(img, Color.WHITE, pts)
	var chief := sh * 0.24
	img.fill_rect(_rect(top.x, top.y, sw, chief), red)
	var lion := top + Vector2(sw * 0.5, chief * 0.55)
	_ellipse(img, Color("ffd100"), lion + Vector2(sw * 0.05, 0), sw * 0.2, chief * 0.18)
	_disc(img, Color("ffd100"), lion - Vector2(sw * 0.2, chief * 0.1), chief * 0.2)
	_segment(img, Color("ffd100"), lion + Vector2(sw * 0.24, 0), lion + Vector2(sw * 0.34, -chief * 0.25), chief * 0.08)
	var t := sw * 0.13
	var cross_y := top.y + chief + (sh - chief) * 0.35
	img.fill_rect(_rect(top.x + (sw - t) * 0.5, top.y + chief, t, sh - chief - t * 0.2), red)
	img.fill_rect(_rect(top.x, cross_y - t * 0.5, sw, t), red)


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


static func _malaysia(img: Image) -> void:
	# Fourteen red and white stripes, a blue canton with a yellow crescent and fourteen-pointed star.
	var cols := []
	for i in 14:
		cols.append(Color("cc0001") if i % 2 == 0 else Color.WHITE)
	_stripes_h(img, cols)
	var s := _size(img)
	var cw := s.x * 0.5
	var ch := s.y * 8.0 / 14.0
	img.fill_rect(_rect(0, 0, cw, ch), Color("010066"))
	var c := Vector2(cw * 0.36, ch * 0.5)
	_crescent(img, Color("ffcc00"), c, ch * 0.38, c + Vector2(ch * 0.1, 0), ch * 0.33)
	_star(img, Color("ffcc00"), Vector2(cw * 0.66, ch * 0.5), ch * 0.3, ch * 0.13, 14, -PI * 0.5)


static func _singapore(img: Image) -> void:
	_stripes_h(img, [Color("ef3340"), Color.WHITE])
	var s := _size(img)
	var c := Vector2(s.y * 0.3, s.y * 0.25)
	_crescent(img, Color.WHITE, c, s.y * 0.17, c + Vector2(s.y * 0.06, 0), s.y * 0.15)
	for i in 5:
		var a := -PI * 0.5 + TAU * i / 5.0
		_star(img, Color.WHITE, c + Vector2(s.y * 0.11, 0) + Vector2.from_angle(a) * s.y * 0.07, s.y * 0.028, s.y * 0.011, 5, -PI * 0.5)


## Union Jack filling a canton rect: counterchanged saltires under the St George cross.
static func _union_jack(img: Image, r: Rect2, blue: Color) -> void:
	img.fill_rect(Rect2i(r), blue)
	var red := Color("c8102e")
	var u := r.size.y / 30.0
	var c := r.get_center()
	var half := r.size * 0.5
	# Signed distance from the diagonal arm through p, positive on its anticlockwise side,
	# which is where the red stripe sits (broad white uppermost at the hoist).
	var arm := func(p: Vector2) -> float:
		var q := p - c
		var d := Vector2(signf(q.x) * half.x, signf(q.y) * half.y).normalized()
		return q.dot(Vector2(d.y, -d.x))
	_fill(img, Color.WHITE, r, func(p: Vector2) -> bool:
		return r.has_point(p) and absf(arm.call(p)) <= u * 3.0)
	_fill(img, red, r, func(p: Vector2) -> bool:
		var t: float = arm.call(p)
		return r.has_point(p) and t >= 0.0 and t <= u * 2.0)
	img.fill_rect(_rect(c.x - u * 5.0, r.position.y, u * 10.0, r.size.y), Color.WHITE)
	img.fill_rect(_rect(r.position.x, c.y - u * 5.0, r.size.x, u * 10.0), Color.WHITE)
	img.fill_rect(_rect(c.x - u * 3.0, r.position.y, u * 6.0, r.size.y), red)
	img.fill_rect(_rect(r.position.x, c.y - u * 3.0, r.size.x, u * 6.0), red)


## Triangle on the hoist edge with its apex at x = apex mid-height, shrunk by inset on each slanted side.
static func _hoist_triangle(img: Image, c: Color, apex: float, inset: float) -> void:
	var h := float(img.get_height())
	var phi := atan2(h * 0.5, apex)
	var off := inset / cos(phi)
	var tip := (h * 0.5 - off) / tan(phi)
	_poly(img, c, PackedVector2Array([Vector2(-1.0, off - tan(phi)), Vector2(tip, h * 0.5), Vector2(-1.0, h - off + tan(phi))]))


## Equal vertical stripes, hoist to fly.
static func _vertical(img: Image, colours: Array) -> void:
	var n := colours.size()
	var w := img.get_width()
	for i in n:
		img.fill_rect(Rect2i(roundi(float(i) / n * w), 0, roundi(float(i + 1) / n * w) - roundi(float(i) / n * w), img.get_height()), colours[i])


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
