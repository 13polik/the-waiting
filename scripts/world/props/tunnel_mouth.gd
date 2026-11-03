extends Node2D
## The dark mouth of a way on, set into a side wall.
##   "crevice" — a tall, narrow split in the rock (home, beside the door).
##   "arch"    — a low tunnel opening (between areas).
## [member inward] is the direction the tunnel runs: 1 east, -1 west.
## Origin: floor contact at the wall face.

const Painter := preload("res://scripts/world/painter.gd")

var style: String = "arch"
var inward: float = 1.0
var baked: bool = false


func bake_rect() -> Rect2:
	return Rect2(-110, -260, 220, 272) if style == "arch" else Rect2(-60, -330, 120, 342)


func _draw() -> void:
	if baked:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 6100 + (1 if style == "arch" else 2)
	var outline := PackedVector2Array()
	if style == "crevice":
		for i in 15:
			var k := float(i) / 14.0
			outline.append(Vector2(-12.0 * sin(PI * k) - 6.0 + rng.randf_range(-2, 2), -k * 310.0))
		for i in range(14, -1, -1):
			var k := float(i) / 14.0
			outline.append(Vector2(14.0 * sin(PI * k) + 4.0 + rng.randf_range(-2, 2), -k * 310.0))
	else:
		for i in 19:
			var a := PI + PI * i / 18.0
			outline.append(Vector2(cos(a) * 82.0 + rng.randf_range(-3, 3), sin(a) * 170.0 + rng.randf_range(-3, 3)))
	# Darkness deepening toward the far end of the tunnel.
	Painter.gradient_polygon(self, outline, -300, 0, Color(0.01, 0.01, 0.015), Color(0.03, 0.03, 0.04))
	var deep := PackedVector2Array()
	for p in outline:
		deep.append(Vector2(p.x * 0.55 + inward * 10.0, p.y * 0.8))
	draw_colored_polygon(deep, Color(0.0, 0.0, 0.004, 0.9))
	draw_polyline(outline, Painter.INK, 2.6, true)
	var lit := PackedVector2Array()
	for p in outline:
		lit.append(p * 1.04)
	draw_polyline(lit, Color(0.36, 0.34, 0.32, 0.35), 1.2, true)
	for i in 6:
		var x := rng.randf_range(-70.0, 70.0) if style == "arch" else rng.randf_range(-30.0, 30.0)
		Painter.stone(self, Vector2(x, rng.randf_range(-6, 2)), rng.randf_range(4, 10), rng, Color(0.2, 0.19, 0.19), 0.6, 1.2)
