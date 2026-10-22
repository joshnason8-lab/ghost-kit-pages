extends Node
## Bakes the venue's texture sheet, assets/crowd/venue_atlas.png (1024 x 768): one strip per kind of surface, each
## tiling left to right (and top to bottom), so the rink's boards, the stands, the walls, the floor round the rink,
## the truss, the net and the advertising all share one texture and the venue stays a few draw calls (game/arena.gd,
## whose STRIPS table must match the one here). White where a surface takes its colour from the geometry.
## The advertising is the game's own name and plain slogans only: no real brands, clubs, leagues or federations.
## Needs a window:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/crowd/make_venue.tscn

const W := 1024
const H := 768
## name: [y, height] in pixels. Keep in step with Arena.STRIPS.
const STRIPS := {
	"plain": [0, 16], "board": [16, 64], "ads1": [80, 64], "ads2": [144, 64], "led": [208, 64], "seats": [272, 64],
	"slats": [336, 64], "panel": [400, 64], "parquet": [464, 48], "step": [512, 32], "windows": [544, 64],
	"score": [608, 64], "net": [672, 32], "truss": [704, 64],
}
const OUT := "res://assets/crowd/venue_atlas.png"

var _font: Font


func _ready() -> void:
	_font = load("res://fonts/BarlowCondensed-Bold.ttf")
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var canvas := Control.new()
	canvas.size = Vector2(W, H)
	canvas.draw.connect(_paint.bind(canvas))
	vp.add_child(canvas)
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	_grain(img)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/crowd"))
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("saved ", OUT)
	get_tree().quit()


func _r(name: String) -> Rect2:
	var s: Array = STRIPS[name]
	return Rect2(0, s[0], W, s[1])


func _text(c: Control, rect: Rect2, txt: String, size: int, col: Color, outline := Color(0, 0, 0, 0)) -> void:
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	while w > rect.size.x - 18 and size > 10:
		size -= 1
		w = _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := _font.get_ascent(size)
	var desc := _font.get_descent(size)
	var pos := Vector2(rect.position.x + (rect.size.x - w) * 0.5, rect.position.y + (rect.size.y + asc - desc) * 0.5)
	if outline.a > 0.0:
		c.draw_string_outline(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, outline)
	c.draw_string(_font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _seam(c: Control, x: float, r: Rect2) -> void:
	# The joint between two board panels: a dark line with a highlight beside it.
	c.draw_rect(Rect2(x, r.position.y, 2, r.size.y), Color(0.55, 0.57, 0.6))
	c.draw_rect(Rect2(x + 2, r.position.y, 1, r.size.y), Color(1, 1, 1))


func _panel_shade(c: Control, r: Rect2, base: Color) -> void:
	# Plastic panel: a touch brighter at the top (the overhead light), darker at the foot, a grey kick strip.
	for y in int(r.size.y):
		var k := float(y) / r.size.y
		c.draw_rect(Rect2(r.position.x, r.position.y + y, r.size.x, 1), base.lightened(0.04 * (1.0 - k)).darkened(0.08 * k * k))
	c.draw_rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 5), Color(0.62, 0.64, 0.67))
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 2), Color(1, 1, 1))


func _paint(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, W, STRIPS.net[0]), Color(1, 1, 1, 1))   # the net and truss strips stay clear
	# Boards: four white 2 m panels.
	var b := _r("board")
	for i in 4:
		_panel_shade(c, Rect2(i * 256, b.position.y, 256, b.size.y), Color(0.97, 0.97, 0.98))
		_seam(c, i * 256, b)
	# Advertising panels, 2 m each: the game's own name and plain slogans.
	var ads := [
		["ads1", Color("123a7a"), "FLOORBALL UNLEASHED", Color.WHITE, Color("f28c28")],
		["ads1", Color("f7f8fa"), "PLAY FAIR", Color("123a7a"), Color("d0202e")],
		["ads1", Color("d0202e"), "#UNLEASHED", Color.WHITE, Color("ffffff")],
		["ads1", Color("f7f8fa"), "FLOORBALL UNLEASHED", Color("d0202e"), Color("123a7a")],
		["ads2", Color("0f8b5f"), "GO FLOORBALL", Color.WHITE, Color("f7d046")],
		["ads2", Color("f7f8fa"), "KEEP MOVING", Color("0f8b5f"), Color("123a7a")],
		["ads2", Color("f28c28"), "FAST  LIGHT  FUN", Color.WHITE, Color("123a7a")],
		["ads2", Color("1d2633"), "FLOORBALL UNLEASHED", Color("5ad1f0"), Color("5ad1f0")],
	]
	for i in ads.size():
		var a: Array = ads[i]
		var s := _r(a[0])
		var r := Rect2((i % 4) * 256, s.position.y, 256, s.size.y)
		_panel_shade(c, r, a[1])
		c.draw_rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 5), (a[1] as Color).darkened(0.35))
		# A stripe of the accent colour, the text over it.
		c.draw_rect(Rect2(r.position.x + 10, r.position.y + 44, r.size.x - 20, 5), a[4])
		_text(c, Rect2(r.position.x, r.position.y + 2, r.size.x, 44), a[2], 34 if String(a[2]).length() > 14 else 40, a[3])
		_seam(c, r.position.x, Rect2(r.position.x, s.position.y, 3, s.size.y))
	# The LED ribbon round the stands' front: the name on a dark ground, chevrons between.
	var l := _r("led")
	c.draw_rect(l, Color("0a1426"))
	for k in 2:
		var x0 := k * 512.0
		_text(c, Rect2(x0, l.position.y, 360, l.size.y), "FLOORBALL UNLEASHED", 38, Color("e8f4ff"))
		for j in 3:
			var cx := x0 + 380 + j * 40
			c.draw_colored_polygon(PackedVector2Array([Vector2(cx, l.position.y + 14), Vector2(cx + 16, l.position.y + 14),
				Vector2(cx + 34, l.position.y + 32), Vector2(cx + 16, l.end.y - 14), Vector2(cx, l.end.y - 14),
				Vector2(cx + 18, l.position.y + 32)]), [Color("f28c28"), Color("5ad1f0"), Color("d0202e")][j])
	# Seats seen from the front, 0.5 m apart: eight across, white to take the stand's colour; dark between and below.
	var st := _r("seats")
	c.draw_rect(st, Color(0.13, 0.13, 0.14))
	for i in 8:
		var x := i * 128.0
		c.draw_rect(Rect2(x + 14, st.position.y + 4, 100, 34), Color(0.92, 0.92, 0.92))       # back
		c.draw_rect(Rect2(x + 14, st.position.y + 4, 100, 4), Color(1, 1, 1))                 # its top edge
		c.draw_rect(Rect2(x + 18, st.position.y + 38, 92, 12), Color(0.62, 0.62, 0.62))       # the seat, in shadow
		c.draw_rect(Rect2(x + 60, st.position.y + 50, 8, 14), Color(0.3, 0.3, 0.32))          # its leg
	# Birch slats on a wall, 10 cm, with dark gaps.
	var sl := _r("slats")
	for i in W / 16:
		var shade := 0.9 + 0.08 * sin(i * 2.7) * cos(i * 1.3)
		c.draw_rect(Rect2(i * 16, sl.position.y, 14, sl.size.y), Color(shade, shade, shade))
		c.draw_rect(Rect2(i * 16 + 14, sl.position.y, 2, sl.size.y), Color(0.45, 0.42, 0.4))
	# Acoustic panels: large rectangles with a seam round each.
	var pn := _r("panel")
	for i in 8:
		c.draw_rect(Rect2(i * 128, pn.position.y, 128, pn.size.y), Color(0.86, 0.86, 0.87) if i % 2 == 0 else Color(0.82, 0.82, 0.84))
		c.draw_rect(Rect2(i * 128, pn.position.y, 2, pn.size.y), Color(0.55, 0.55, 0.57))
	c.draw_rect(Rect2(0, pn.position.y, W, 2), Color(0.55, 0.55, 0.57))
	# Parquet: 8 m x 1 m of 7 cm boards, joints staggered.
	var pq := _r("parquet")
	c.draw_rect(pq, Color(0.55, 0.5, 0.45))
	var rows := 8
	for j in rows:
		var y := pq.position.y + j * pq.size.y / rows
		var x := -float((j * 97) % 180)
		var n := 0
		while x < W:
			var len_ := 150.0 + float((j * 31 + n * 57) % 120)
			var shade := 0.86 + 0.12 * fposmod(sin(j * 12.9 + n * 7.7) * 43.7, 1.0)
			c.draw_rect(Rect2(x, y, len_ - 1, pq.size.y / rows - 1), Color(shade, shade * 0.98, shade * 0.95))
			x += len_
			n += 1
	# Window band: frames and bright glass.
	var wn := _r("windows")
	c.draw_rect(wn, Color(0.25, 0.27, 0.3))
	for i in 8:
		var r := Rect2(i * 128 + 6, wn.position.y + 6, 116, wn.size.y - 12)
		for y in int(r.size.y):
			var k := float(y) / r.size.y
			c.draw_rect(Rect2(r.position.x, r.position.y + y, r.size.x, 1), Color(0.78, 0.86, 0.95).lerp(Color(0.92, 0.95, 1.0), k))
	# Scoreboard face: dark, the name in amber, panel lines.
	var sc := _r("score")
	c.draw_rect(sc, Color(0.05, 0.06, 0.08))
	for k in 2:
		_text(c, Rect2(k * 512, sc.position.y, 512, sc.size.y), "FLOORBALL UNLEASHED", 44, Color("ffb020"))
		c.draw_rect(Rect2(k * 512 + 8, sc.position.y + 4, 496, 2), Color("5ad1f0"))
		c.draw_rect(Rect2(k * 512 + 8, sc.end.y - 6, 496, 2), Color("5ad1f0"))
	# The goal net: 32 squares of 4 cm, white strings on nothing.
	var nt := _r("net")
	for i in 32:
		c.draw_rect(Rect2(i * 32, nt.position.y, 4, 32), Color(0.97, 0.97, 0.97, 1))
	c.draw_rect(Rect2(0, nt.position.y, W, 4), Color(0.97, 0.97, 0.97, 1))
	# A roof truss: top and bottom chords, posts and diagonals, 8 m of it, on nothing.
	var tr := _r("truss")
	var tc := Color(0.9, 0.9, 0.92, 1)
	c.draw_rect(Rect2(0, tr.position.y, W, 7), tc)
	c.draw_rect(Rect2(0, tr.end.y - 7, W, 7), tc)
	for i in 8:
		var x := i * 128.0
		c.draw_rect(Rect2(x, tr.position.y, 5, tr.size.y), tc)
		c.draw_line(Vector2(x + 3, tr.position.y + 5), Vector2(x + 64, tr.end.y - 5), tc, 4.0)
		c.draw_line(Vector2(x + 64, tr.end.y - 5), Vector2(x + 125, tr.position.y + 5), tc, 4.0)
	# Concrete step (filled by _grain).
	c.draw_rect(_r("step"), Color(0.8, 0.8, 0.8))
	c.draw_rect(_r("plain"), Color(1, 1, 1))


## A fine grain over the opaque strips (plastic, concrete, wood), so nothing is a flat colour up close.
func _grain(img: Image) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var amount := {"board": 0.012, "ads1": 0.01, "ads2": 0.01, "seats": 0.02, "slats": 0.05, "panel": 0.03,
		"parquet": 0.04, "step": 0.08}
	for name in amount:
		var s: Array = STRIPS[name]
		var a: float = amount[name]
		for y in range(s[0], s[0] + s[1]):
			for x in W:
				var c := img.get_pixel(x, y)
				var n := (rng.randf() - 0.5) * 2.0 * a
				if name == "slats" or name == "parquet":
					n += sin(x * 0.9 + y * 0.05 + sin(y * 0.3) * 2.0) * a * 0.5   # a grain along the wood
				img.set_pixel(x, y, Color(clampf(c.r + n, 0, 1), clampf(c.g + n, 0, 1), clampf(c.b + n, 0, 1), c.a))
