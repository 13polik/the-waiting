extends Node2D
## Seven flat stones stacked with care — eight, once the smooth stone from
## the Narrow Way is set on top. Origin: floor contact, centre.

const Painter := preload("res://scripts/world/painter.gd")

const STONES := [
	[56.0, 15.0], [48.0, 14.0], [42.0, 13.0], [34.0, 12.0], [27.0, 10.0], [20.0, 9.0], [13.0, 8.0],
]

## Static drawing is baked into a texture by Baker (see bake_rect).
var baked: bool = false
## 7, or 8 with the smooth stone (set by the room; rebake after changing).
var stones: int = 7


func bake_rect() -> Rect2:
	return Rect2(-46, -116, 92, 126)


func _draw() -> void:
	if baked:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var y := 0.0
	var x := 0.0
	for s in STONES:
		var w: float = s[0]
		var h: float = s[1]
		y -= h * 0.82
		x += rng.randf_range(-3.0, 3.0)
		var shade := rng.randf_range(-0.03, 0.03)
		var fill := Color(0.30 + shade, 0.29 + shade, 0.29 + shade * 0.5)
		Painter.stone(self, Vector2(x, y), w * 0.5, rng, fill, h / w * 1.25, 1.7)
		y -= h * 0.18
	if stones >= 8:
		# The smooth stone: rounder and paler than the rest, worn by water.
		var top := Vector2(x + 1.0, y - 6.0)
		draw_colored_polygon(Painter.ellipse(top, 8.5, 6.0, 18), Color(0.44, 0.43, 0.41))
		draw_colored_polygon(Painter.ellipse(top + Vector2(-2, -2), 4.5, 2.6, 12), Color(0.6, 0.6, 0.58, 0.6))
		draw_polyline(Painter.closed(Painter.ellipse(top, 8.5, 6.0, 18)), Painter.INK, 1.5, true)
	draw_colored_polygon(Painter.ellipse(Vector2(0, 2), 36, 4, 16), Color(0, 0, 0, 0.35))
