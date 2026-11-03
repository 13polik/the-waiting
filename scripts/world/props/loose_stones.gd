extends Node2D
## A section of wall that is only piled stones. Pulled away (see echo_hall.gd)
## it opens a low tunnel; the fallen stones lie in a heap beside it.
## Origin: floor contact at the wall face.

const Painter := preload("res://scripts/world/painter.gd")

var opened: bool = false
var baked: bool = false


func bake_rect() -> Rect2:
	return Rect2(-150, -240, 270, 252)


func _draw() -> void:
	if baked:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7301
	var mouth := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		mouth.append(Vector2(cos(a) * 70.0 + rng.randf_range(-3, 3), sin(a) * 150.0 + rng.randf_range(-3, 3)))
	if opened:
		Painter.gradient_polygon(self, mouth, -150, 0, Color(0.01, 0.01, 0.015), Color(0.03, 0.035, 0.04))
		draw_polyline(mouth, Painter.INK, 2.4, true)
		# The pulled stones, heaped to one side.
		for i in 9:
			var p := Vector2(rng.randf_range(-140, -80), rng.randf_range(-30, 0) * (1.0 - i / 12.0))
			Painter.stone(self, p, rng.randf_range(10, 20), rng, Color(0.24, 0.23, 0.22), 0.7, 1.6)
		return
	# Closed: a patch of loosely fitted stones, paler where they meet.
	draw_colored_polygon(mouth, Color(0.08, 0.08, 0.09))
	var r := RandomNumberGenerator.new()
	r.seed = 7302
	for row in 6:
		var y := -14.0 - row * 24.0
		var half := 66.0 * sqrt(maxf(0.0, 1.0 - pow(y / 150.0, 2.0)))
		var x := -half + 12.0
		while x < half - 6.0:
			var rad := r.randf_range(10, 15)
			Painter.stone(self, Vector2(x, y + r.randf_range(-3, 3)), rad, r, Color(0.25, 0.24, 0.23), 0.75, 1.5)
			x += rad * 1.8
	draw_polyline(mouth, Color(0.45, 0.44, 0.42, 0.3), 1.2, true)
