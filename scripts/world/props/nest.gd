extends Node2D
## The creature's nest (0.7 makeover): a low bowl woven from pale roots,
## filled with a moss cushion, a stitched blanket thrown over one side and a
## small round pillow. The warmest thing in the cave. Origin: floor, centre.

const Painter := preload("res://scripts/world/painter.gd")
const MOSS := Color(0.2, 0.24, 0.16)
const MOSS_LIGHT := Color(0.34, 0.38, 0.24)
const ROOT := Color(0.5, 0.42, 0.32)
const ROOT_DARK := Color(0.3, 0.25, 0.2)
const BLANKET := Color(0.52, 0.3, 0.22)
const BLANKET_LIGHT := Color(0.66, 0.42, 0.3)
const PILLOW := Color(0.62, 0.58, 0.5)

## Static drawing is baked into a texture by Baker (see bake_rect).
var baked: bool = false


func bake_rect() -> Rect2:
	return Rect2(-140, -86, 280, 100)


func _draw() -> void:
	if baked:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1101
	# Shadow under the bowl.
	draw_colored_polygon(Painter.ellipse(Vector2(0, 4), 128, 9, 28), Color(0, 0, 0, 0.35))
	# The woven bowl: a wide, low ellipse of roots.
	var bowl := PackedVector2Array()
	for i in 25:
		var a := PI * i / 24.0
		bowl.append(Vector2(-cos(a) * 118.0, -sin(a) * 8.0 + 2.0 - (46.0 if i == 0 or i == 24 else 0.0) * 0.0))
	var outer := PackedVector2Array([Vector2(-118, 2), Vector2(-122, -22), Vector2(-112, -40), Vector2(112, -40), Vector2(122, -22), Vector2(118, 2)])
	Painter.gradient_polygon(self, outer, -40, 2, ROOT, ROOT_DARK)
	# Weave: diagonal strands crossing both ways.
	for i in 26:
		var x := -112.0 + i * 9.0
		draw_line(Vector2(x, -38), Vector2(x + 10, 0), Color(ROOT_DARK, 0.7), 1.4, true)
		draw_line(Vector2(x + 10, -38), Vector2(x, 0), Color(ROOT.lightened(0.15), 0.45), 1.0, true)
	for y in [-30.0, -18.0, -6.0]:
		draw_line(Vector2(-118, y), Vector2(118, y), Color(ROOT_DARK, 0.5), 1.2, true)
	draw_polyline(Painter.closed(outer), Painter.INK, 1.8, true)
	# Moss cushion heaped inside, above the rim.
	var cushion := PackedVector2Array([Vector2(-106, -38), Vector2(-90, -52), Vector2(-50, -58), Vector2(0, -54),
		Vector2(50, -58), Vector2(92, -52), Vector2(106, -38)])
	Painter.gradient_polygon(self, cushion, -58, -38, MOSS_LIGHT, MOSS)
	for i in 30:
		var x := rng.randf_range(-98, 98)
		var base := Vector2(x, -40 - rng.randf_range(2, 14))
		draw_line(base, base + Vector2(rng.randf_range(-3, 3), -rng.randf_range(3, 7)), Color(MOSS_LIGHT.lightened(0.2), 0.6), 1.0, true)
	draw_polyline(cushion, Painter.INK, 1.4, true)
	# The pillow, at the left end.
	var pillow := Painter.ellipse(Vector2(-66, -62), 26, 13, 22)
	Painter.gradient_polygon(self, pillow, -75, -49, PILLOW.lightened(0.12), PILLOW.darkened(0.2))
	draw_line(Vector2(-84, -62), Vector2(-48, -63), Color(PILLOW.darkened(0.3), 0.6), 1.0, true)
	draw_polyline(Painter.closed(pillow), Painter.INK, 1.4, true)
	# The blanket, thrown over the right side and hanging down the bowl.
	var blanket := PackedVector2Array([Vector2(-6, -56), Vector2(40, -62), Vector2(88, -56), Vector2(116, -40),
		Vector2(124, -10), Vector2(112, 4), Vector2(96, -16), Vector2(84, -36), Vector2(50, -44), Vector2(10, -44)])
	Painter.gradient_polygon(self, blanket, -62, 4, BLANKET_LIGHT, BLANKET.darkened(0.15))
	# Stitches along its edge and a patch.
	for i in 12:
		var t := float(i) / 11.0
		var p := Vector2(lerpf(-2, 108, t), lerpf(-52, -36, t * t) - 2.0)
		draw_line(p, p + Vector2(4, 1), Color(0.9, 0.78, 0.6, 0.8), 1.0, true)
	var patch := PackedVector2Array([Vector2(52, -54), Vector2(72, -55), Vector2(74, -41), Vector2(54, -40)])
	draw_colored_polygon(patch, Color(0.45, 0.38, 0.28))
	draw_polyline(Painter.closed(patch), Color(0.9, 0.78, 0.6, 0.7), 1.0, true)
	draw_polyline(Painter.closed(blanket), Painter.INK, 1.6, true)
