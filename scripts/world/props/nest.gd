extends Node2D
## The creature's nest: a low mound of moss and pale fibres with a dip in the
## middle. The only warm colour in the cave. Origin: floor contact, centre.

const Painter := preload("res://scripts/world/painter.gd")
const MOSS := Color(0.17, 0.19, 0.14)
const MOSS_LIGHT := Color(0.30, 0.32, 0.22)
const FIBRE := Color(0.52, 0.42, 0.28)

## Static drawing is baked into a texture by Baker (see bake_rect).
var baked: bool = false


func bake_rect() -> Rect2:
	return Rect2(-100, -40, 200, 52)


func _draw() -> void:
	if baked:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1101
	var mound := PackedVector2Array([
		Vector2(-92, 4), Vector2(-80, -10), Vector2(-64, -22), Vector2(-46, -20), Vector2(-28, -12),
		Vector2(0, -8), Vector2(28, -12), Vector2(46, -21), Vector2(66, -23), Vector2(82, -11), Vector2(94, 4)])
	Painter.gradient_polygon(self, mound, -24, 4, MOSS_LIGHT, MOSS.darkened(0.4))
	# Lining: a soft warm hollow where the creature rests.
	draw_colored_polygon(Painter.ellipse(Vector2(0, -6), 42, 6, 20), Color(FIBRE, 0.45))
	# Fibres and lint following the curve of the mound.
	for i in 46:
		var x := rng.randf_range(-84, 84)
		var y := -_height(x) + rng.randf_range(0, 10)
		var len := rng.randf_range(8, 22)
		var a := rng.randf_range(-0.35, 0.35) + (0.25 if x < 0 else -0.25)
		var col := FIBRE if rng.randf() < 0.45 else MOSS_LIGHT
		var p1 := Vector2(x, y)
		var p2 := p1 + Vector2.from_angle(a) * len
		var mid := (p1 + p2) * 0.5 + Vector2(0, -rng.randf_range(1, 4))
		draw_polyline(PackedVector2Array([p1, mid, p2]), Color(col, rng.randf_range(0.45, 0.85)), rng.randf_range(1.0, 1.8), true)
	# Tufts standing up from the rim.
	for i in 22:
		var x := rng.randf_range(-86, 86)
		var base := Vector2(x, -_height(x) + 2)
		for k in 3:
			var tip := base + Vector2(rng.randf_range(-4, 4), -rng.randf_range(4, 10))
			draw_line(base, tip, Color(MOSS_LIGHT, 0.7), 1.0, true)
	draw_polyline(mound, Painter.INK, 1.8, true)


func _height(x: float) -> float:
	var ax := absf(x)
	if ax < 30.0:
		return 8.0 + ax * 0.12
	return lerpf(14.0, 22.0, clampf((ax - 30.0) / 36.0, 0.0, 1.0)) * clampf((94.0 - ax) / 28.0, 0.0, 1.0)
