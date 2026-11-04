extends Node2D
## Things that make the cave a home (0.7). One prop per [member kind]:
##  * "shelf" — a niche carved into the wall with a stone ledge; the books
##    found so far stand on it ([member books], 0–3), and a few small things.
##  * "jar"   — a glass jar of glowing caps hanging from a root (a night light).
##  * "roots" — pale roots hanging down from the ceiling (origin: ceiling).
##  * "mat"   — a plaited rush mat on the floor.
## Origin: floor contact (shelf: the ledge; jar: where the cord meets the
## ceiling). Static: baked by Baker; the shelf is re-baked when a book arrives.

const Painter := preload("res://scripts/world/painter.gd")
const BOOK_COLORS := [Color(0.42, 0.2, 0.16), Color(0.2, 0.32, 0.22), Color(0.2, 0.24, 0.4)]

var baked: bool = false
var kind: String = "shelf"
## Shelf: which of the three books stand on it.
var books: Array = [false, false, false]
## Jar: length of the cord.
var drop: float = 160.0


func bake_rect() -> Rect2:
	match kind:
		"shelf": return Rect2(-140, -150, 280, 175)
		"jar": return Rect2(-40, -10, 80, drop + 70)
		"roots": return Rect2(-120, -10, 240, 190)
		"mat": return Rect2(-150, -16, 300, 30)
	return Rect2(-100, -100, 200, 200)


func _draw() -> void:
	if baked:
		return
	match kind:
		"shelf": _shelf()
		"jar": _jar()
		"roots": _roots()
		"mat": _mat()


func _shelf() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	# The niche: dark hollow in the rock above the ledge.
	var niche := PackedVector2Array([Vector2(-120, 0), Vector2(-126, -96), Vector2(-96, -136), Vector2(96, -136),
		Vector2(126, -96), Vector2(120, 0)])
	draw_colored_polygon(niche, Color(0.035, 0.033, 0.04))
	draw_polyline(Painter.closed(niche), Painter.INK, 2.2, true)
	draw_polyline(PackedVector2Array([Vector2(-118, -4), Vector2(-122, -94), Vector2(-94, -132)]), Color(0.3, 0.29, 0.3, 0.4), 1.2, true)
	# Books standing on the ledge, spines out.
	var x := -100.0
	for i in 3:
		if not books[i]:
			continue
		var h := 74.0 + i * 6.0
		var w := 22.0 + (i % 2) * 6.0
		var spine := PackedVector2Array([Vector2(x, 0), Vector2(x, -h), Vector2(x + w, -h - 1), Vector2(x + w, 0)])
		Painter.gradient_polygon(self, spine, -h, 0, BOOK_COLORS[i].lightened(0.15), BOOK_COLORS[i].darkened(0.2))
		for y in [-h + 10.0, -14.0]:
			draw_line(Vector2(x + 2, y), Vector2(x + w - 2, y), Color(0.85, 0.7, 0.4, 0.7), 1.2, true)
		draw_polyline(Painter.closed(spine), Painter.INK, 1.4, true)
		x += w + 3.0
	# A few small things: a smooth pebble, a little bowl, a tied bundle of twigs.
	Painter.stone(self, Vector2(40, -8), 9, rng, Color(0.45, 0.44, 0.42), 0.6, 1.4)
	var bowl := PackedVector2Array([Vector2(62, -14), Vector2(66, -2), Vector2(86, -2), Vector2(90, -14)])
	draw_colored_polygon(bowl, Color(0.4, 0.33, 0.26))
	draw_polyline(Painter.closed(bowl), Painter.INK, 1.2, true)
	for k in 5:
		draw_line(Vector2(98 + k * 2, -2), Vector2(94 + k * 3, -44), Color(0.5, 0.44, 0.34), 1.3, true)
	draw_line(Vector2(95, -20), Vector2(108, -20), Color(0.7, 0.5, 0.35), 2.0, true)
	# The ledge itself.
	var ledge := PackedVector2Array([Vector2(-134, 0), Vector2(134, 0), Vector2(128, 16), Vector2(-128, 18)])
	Painter.gradient_polygon(self, ledge, 0, 18, Color(0.32, 0.3, 0.3), Color(0.18, 0.17, 0.18))
	draw_line(Vector2(-132, 0), Vector2(132, 0), Color(0.5, 0.48, 0.46, 0.5), 1.2, true)
	draw_polyline(Painter.closed(ledge), Painter.INK, 1.8, true)


func _jar() -> void:
	draw_line(Vector2.ZERO, Vector2(0, drop), Color(0.45, 0.4, 0.33), 1.6, true)
	var c := Vector2(0, drop + 28)
	var glass := PackedVector2Array([Vector2(-14, drop + 4), Vector2(14, drop + 4), Vector2(20, drop + 14), Vector2(22, drop + 44),
		Vector2(14, drop + 54), Vector2(-14, drop + 54), Vector2(-22, drop + 44), Vector2(-20, drop + 14)])
	draw_colored_polygon(glass, Color(0.55, 0.75, 0.72, 0.18))
	# Glowing caps inside.
	for k in 4:
		var p := c + Vector2(-9 + k * 6, 12 - (k % 2) * 6)
		draw_line(p, p + Vector2(0, 10), Color(0.7, 0.95, 0.9, 0.8), 1.4, true)
		draw_colored_polygon(Painter.ellipse(p, 6, 3.5, 12), Color(0.75, 1.0, 0.94, 0.9))
	draw_polyline(Painter.closed(glass), Color(0.75, 0.9, 0.88, 0.7), 1.4, true)
	draw_rect(Rect2(-15, drop - 1, 30, 6), Color(0.38, 0.32, 0.26))
	draw_rect(Rect2(-15, drop - 1, 30, 6), Painter.INK, false, 1.2)


func _roots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	for i in 9:
		var x := rng.randf_range(-110, 110)
		var len := rng.randf_range(60, 170)
		var pts := PackedVector2Array()
		var steps := 7
		for k in steps + 1:
			var t := float(k) / steps
			pts.append(Vector2(x + sin(t * 3.0 + i) * 8.0 * t, t * len))
		draw_polyline(pts, Color(0.12, 0.11, 0.1), 4.0 - i % 3, true)
		draw_polyline(pts, Color(0.46, 0.41, 0.33, 0.8), 2.2 - (i % 3) * 0.5, true)
		if i % 2 == 0:
			var tip := pts[pts.size() - 1]
			draw_line(tip, tip + Vector2(rng.randf_range(-10, 10), 14), Color(0.46, 0.41, 0.33, 0.6), 1.0, true)


func _mat() -> void:
	var mat := Painter.ellipse(Vector2(0, 2), 140, 10, 32)
	draw_colored_polygon(mat, Color(0.38, 0.32, 0.22))
	for i in 14:
		var x := -126.0 + i * 18.0
		draw_line(Vector2(x, -5), Vector2(x + 12, 9), Color(0.55, 0.47, 0.32, 0.7), 2.0, true)
	draw_polyline(Painter.closed(Painter.ellipse(Vector2(0, 2), 128, 7, 32)), Color(0.6, 0.5, 0.35, 0.6), 1.0, true)
	draw_polyline(Painter.closed(mat), Painter.INK, 1.6, true)
