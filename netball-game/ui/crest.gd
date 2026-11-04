class_name Crest
extends Control
## A team's crest: a shield in the franchise colours with its short name, or a country's
## flag in a rounded frame.

var team_id := ""


const BAKE_MAX := 48.0          # px: a crest this tall or less draws its shield from a baked texture

static var _baked := {}


static func make(id: String, px := 64.0) -> Crest:
	var c := Crest.new()
	c.team_id = id
	c.custom_minimum_size = Vector2(px, px * 1.12)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var t := DB.team(team_id)
	if t.is_empty():
		return
	var w := size.x
	var h := size.y
	if t.kind == "country":
		var fh := w * 0.66
		var r := Rect2(0, (h - fh) * 0.5, w, fh)
		draw_texture_rect(Flags.texture(team_id, int(w * 2), int(fh * 2)), r, false)
		draw_rect(r, Color(1, 1, 1, 0.25), false, 1.5)
		return
	var c1: Color = t.c1
	var c2: Color = t.c2
	if h <= BAKE_MAX:
		# Small (the scoreboard's, the tables'): the shield baked once, one draw call, not five (a Club Season
		# match on Low drew 104 calls with the scoreboard's two crests, 90 without: 0.9.9).
		draw_texture_rect(shield_texture(team_id, ceili(w * 2.0), ceili(h * 2.0), maxf(1.5, w * 0.04) * 2.0), Rect2(0, 0, w, h), false)
	else:
		var shield := _shield(w, h)
		draw_colored_polygon(shield, c1)
		# A sash in the second colour.
		draw_colored_polygon(_sash(w, h), Color(c2, 0.85))
		var outline := shield.duplicate()
		outline.append(shield[0])
		draw_polyline(outline, c2.lightened(0.2), maxf(1.5, w * 0.04), true)
	var f: Font = Game.font_display
	var fs := int(h * 0.36)
	var code := String(t.get("short", team_id))
	var tw := f.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ink := Color.WHITE if c1.get_luminance() < 0.6 else Color("101820")
	draw_string_outline(f, Vector2((w - tw) * 0.5, h * 0.74), code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.18), Color(0, 0, 0, 0.45))
	draw_string(f, Vector2((w - tw) * 0.5, h * 0.74), code, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


static func _shield(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(w * 0.08, h * 0.06), Vector2(w * 0.92, h * 0.06), Vector2(w * 0.92, h * 0.52),
		Vector2(w * 0.78, h * 0.76), Vector2(w * 0.5, h * 0.96), Vector2(w * 0.22, h * 0.76), Vector2(w * 0.08, h * 0.52)])


static func _sash(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(w * 0.08, h * 0.36), Vector2(w * 0.92, h * 0.16), Vector2(w * 0.92, h * 0.3),
		Vector2(w * 0.08, h * 0.5)])


## A club's shield at w x h pixels as _draw paints it (its colour, the sash, a rim rim pixels wide), drawn once
## (4x over, scaled down) and kept.
static func shield_texture(id: String, w: int, h: int, rim: float) -> ImageTexture:
	var key := "%s_%d_%d_%.1f" % [id, w, h, rim]
	if _baked.has(key):
		return _baked[key]
	var t := DB.team(id)
	const SS := 4
	var img := Image.create_empty(w * SS, h * SS, false, Image.FORMAT_RGBA8)
	var c1: Color = t.get("c1", Color.GRAY)
	var c2: Color = t.get("c2", Color.WHITE)
	var shield := _shield(w * SS, h * SS)
	var half := rim * SS * 0.5
	var outer: Array = Geometry2D.offset_polygon(shield, half, Geometry2D.JOIN_MITER)
	var inner: Array = Geometry2D.offset_polygon(shield, -half, Geometry2D.JOIN_MITER)
	_fill_convex(img, outer[0] if not outer.is_empty() else shield, c2.lightened(0.2))
	if not inner.is_empty():
		_fill_convex(img, inner[0], c1)
		for part: PackedVector2Array in Geometry2D.intersect_polygons(_sash(w * SS, h * SS), inner[0]):
			_fill_convex(img, part, c1.lerp(c2, 0.85))
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	_baked[key] = tex
	return tex


## Paints a convex polygon, a row at a time.
static func _fill_convex(img: Image, pts: PackedVector2Array, c: Color) -> void:
	var y0 := INF
	var y1 := -INF
	for q in pts:
		y0 = minf(y0, q.y)
		y1 = maxf(y1, q.y)
	var n := pts.size()
	for y in range(maxi(0, floori(y0)), mini(img.get_height(), ceili(y1))):
		var yc := y + 0.5
		var xa := INF
		var xb := -INF
		for i in n:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
				var x := a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x)
				xa = minf(xa, x)
				xb = maxf(xb, x)
		var x0 := clampi(roundi(xa), 0, img.get_width()) if xa < INF else 0
		var x1 := clampi(roundi(xb), 0, img.get_width()) if xb > -INF else 0
		if x1 > x0:
			img.fill_rect(Rect2i(x0, y, x1 - x0, 1), c)
