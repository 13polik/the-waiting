extends Node2D
## The old passage in the left wall, choked with fallen rock. One stone can be
## pulled away each real day (see cave_room.gd); [member progress] counts them
## and the heap shrinks; at 7 the way west is open.
## Origin: floor contact at the mouth of the passage.

const Painter := preload("res://scripts/world/painter.gd")

## Static drawing is baked into a texture by Baker (see bake_rect).
var baked: bool = false
var progress: int = 0
const STONES_TO_CLEAR := 7


func bake_rect() -> Rect2:
	return Rect2(-112, -240, 232, 252)


func _draw() -> void:
	if baked:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4409
	# The dark mouth, taller than the creature.
	var mouth := Painter.blob(Vector2(-8, -104), 84, rng, 14, 0.12, 1.25)
	draw_colored_polygon(mouth, Color(0.012, 0.012, 0.018))
	draw_polyline(Painter.closed(mouth), Painter.INK, 2.6, true)
	# A faint lip of light around the opening.
	draw_polyline(Painter.closed(Painter.blob(Vector2(-8, -104), 88, rng, 14, 0.06, 1.25)), Color(0.32, 0.31, 0.30, 0.35), 1.2, true)
	if progress >= STONES_TO_CLEAR:
		# Open: a low way west. The pulled stones lie heaped to one side.
		var deep := PackedVector2Array()
		for p in mouth:
			deep.append(Vector2(-8, -104) + (p - Vector2(-8, -104)) * 0.62)
		draw_colored_polygon(deep, Color(0.0, 0.0, 0.004, 0.95))
		for i in 9:
			Painter.stone(self, Vector2(rng.randf_range(70, 110), rng.randf_range(-24, 0) * (1.0 - i / 10.0)), rng.randf_range(8, 16), rng, Color(0.22, 0.21, 0.21), 0.7, 1.6)
		return
	# Rubble heaped from the floor up, leaving a thin gap at the top. Each
	# stone pulled away removes two from the top of the heap.
	var heap := [
		[Vector2(-62, -14), 26.0], [Vector2(-20, -16), 30.0], [Vector2(26, -12), 24.0], [Vector2(58, -8), 16.0],
		[Vector2(-44, -50), 24.0], [Vector2(0, -52), 26.0], [Vector2(36, -40), 18.0],
		[Vector2(-26, -86), 22.0], [Vector2(14, -84), 20.0], [Vector2(-50, -96), 15.0],
		[Vector2(-6, -116), 17.0], [Vector2(28, -112), 12.0], [Vector2(-34, -132), 11.0],
		[Vector2(76, -4), 9.0], [Vector2(-80, -6), 10.0],
	]
	var keep := heap.size() - progress * 2
	for i in heap.size():
		var h: Array = heap[i]
		var shade := rng.randf_range(-0.03, 0.03)
		if i >= keep:
			continue
		Painter.stone(self, h[0], h[1], rng, Color(0.22 + shade, 0.21 + shade, 0.21 + shade), rng.randf_range(0.6, 0.85), 1.8)
	for i in 14:
		draw_circle(Vector2(rng.randf_range(-90, 90), rng.randf_range(-6, 2)), rng.randf_range(1.5, 3.5), Color(0.2, 0.19, 0.19))
