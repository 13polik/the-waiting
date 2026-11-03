extends Node2D
## Small static features set into walls and floors of the new areas, all drawn
## once and baked: [member kind] picks one.
##   "fossil"  — a spiral pressed into the rock (Narrow Way)
##   "marks"   — someone else's tally, in groups of seven (Narrow Way)
##   "trickle" — a thread of water and the hollow it has worn (Narrow Way)
##   "pillar"  — a carved pillar fallen across the floor (Hall of Echoes)
##   "desk"    — a stone slab on two stones, worn smooth (Scribe's Alcove)
##   "lamp"    — a dark bulb on a long dried stalk, lying in the dust (Alcove)
## Origin: floor contact (fossil and marks: the centre of the feature).

const Painter := preload("res://scripts/world/painter.gd")

var kind: String = "fossil"
var baked: bool = false


func bake_rect() -> Rect2:
	match kind:
		"fossil": return Rect2(-60, -60, 120, 120)
		"marks": return Rect2(-120, -60, 240, 120)
		"trickle": return Rect2(-60, -330, 120, 342)
		"pillar": return Rect2(-230, -110, 460, 122)
		"desk": return Rect2(-170, -90, 300, 102)
		"lamp": return Rect2(-110, -40, 230, 52)
	return Rect2(-50, -50, 100, 100)


func _draw() -> void:
	if baked:
		return
	match kind:
		"fossil": _fossil()
		"marks": _marks()
		"trickle": _trickle()
		"pillar": _pillar()
		"desk": _desk()
		"lamp": _lamp()


func _fossil() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	draw_colored_polygon(Painter.blob(Vector2.ZERO, 46, rng, 12, 0.08, 0.85), Color(0.24, 0.23, 0.22))
	var spiral := PackedVector2Array()
	for i in 90:
		var a := i * 0.21
		var r := 3.0 + a * 4.6
		spiral.append(Vector2(cos(a), sin(a) * 0.9) * r)
	draw_polyline(spiral, Color(0.06, 0.05, 0.05, 0.85), 2.0, true)
	var lit := PackedVector2Array()
	for p in spiral:
		lit.append(p + Vector2(0.8, 1.2))
	draw_polyline(lit, Color(0.48, 0.46, 0.42, 0.3), 1.0, true)
	var ribs := PackedVector2Array()
	for i in range(8, 90, 6):
		var a := i * 0.21
		var r := 3.0 + a * 4.6
		ribs.append(Vector2(cos(a), sin(a) * 0.9) * r)
		ribs.append(Vector2(cos(a), sin(a) * 0.9) * (r + 4.0))
	draw_multiline(ribs, Color(0.06, 0.05, 0.05, 0.6), 1.0)


## Groups of seven, not five: not your hand.
func _marks() -> void:
	var dark := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9002
	for g in 9:
		var gx := -105.0 + (g % 5) * 44.0
		var gy := -40.0 + (g / 5) * 30.0
		for m in 7:
			var x := gx + m * 4.2 + rng.randf_range(-0.8, 0.8)
			dark.append(Vector2(x, gy + rng.randf_range(-1, 1)))
			dark.append(Vector2(x + rng.randf_range(-2.5, 2.5), gy + 16.0 + rng.randf_range(-1, 1)))
	draw_multiline(dark, Color(0.62, 0.6, 0.55, 0.55), 1.4)


func _trickle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9003
	var line := PackedVector2Array()
	var x := 0.0
	for i in 22:
		x += rng.randf_range(-2.2, 2.2)
		line.append(Vector2(x, -320.0 + i * 14.5))
	draw_polyline(line, Color(0.5, 0.6, 0.68, 0.55), 2.2, true)
	draw_polyline(line, Color(0.75, 0.85, 0.9, 0.35), 0.9, true)
	var hollow := Painter.ellipse(Vector2(x, -2), 34, 7, 18)
	draw_colored_polygon(hollow, Color(0.03, 0.04, 0.06))
	draw_line(Vector2(x - 20, -4), Vector2(x + 14, -4), Color(0.6, 0.7, 0.78, 0.4), 1.2, true)
	draw_polyline(Painter.closed(hollow), Painter.INK, 1.4, true)


func _desk() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9005
	for lx in [-120.0, 40.0]:
		Painter.stone(self, Vector2(lx, -22), 22, rng, Color(0.22, 0.21, 0.2), 1.0, 1.6)
	var slab := PackedVector2Array([Vector2(-158, -44), Vector2(-150, -70), Vector2(110, -66), Vector2(118, -42)])
	Painter.gradient_polygon(self, slab, -70, -42, Color(0.33, 0.31, 0.29), Color(0.22, 0.21, 0.2))
	# One long edge worn smooth and pale: someone leaned here a long time.
	draw_line(Vector2(-140, -68), Vector2(100, -64), Color(0.5, 0.48, 0.44, 0.6), 2.0, true)
	draw_polyline(Painter.closed(slab), Painter.INK, 2.0, true)
	var scratches := PackedVector2Array()
	for i in 12:
		var x := rng.randf_range(-130, 90)
		scratches.append(Vector2(x, -58 + rng.randf_range(-3, 3)))
		scratches.append(Vector2(x + rng.randf_range(4, 12), -56 + rng.randf_range(-3, 3)))
	draw_multiline(scratches, Color(0.06, 0.05, 0.05, 0.5), 1.0)


## Like the creature's own lantern, but dark and dry — and long fallen.
func _lamp() -> void:
	var stalk := PackedVector2Array()
	for i in 12:
		var k := float(i) / 11.0
		stalk.append(Vector2(lerpf(-90, 70, k), -4.0 - sin(k * PI) * 14.0 + k * 2.0))
	draw_polyline(stalk, Painter.INK, 4.0, true)
	draw_polyline(stalk, Color(0.3, 0.28, 0.25), 2.0, true)
	var bulb := Vector2(78, -6)
	draw_circle(bulb, 9.0, Color(0.14, 0.14, 0.15))
	draw_circle(bulb + Vector2(-3, -3), 3.0, Color(0.3, 0.3, 0.32, 0.6))
	draw_arc(bulb, 9.2, 0.0, TAU, 20, Painter.INK, 1.6, true)
	draw_colored_polygon(Painter.ellipse(Vector2(-10, 2), 100, 4, 18), Color(0, 0, 0, 0.3))


func _pillar() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9004
	# Three broken drums lying in a row, carved with circles like the door.
	for d in 3:
		var cx := -150.0 + d * 140.0 + rng.randf_range(-8, 8)
		var r := 46.0 - d * 6.0
		var drum := Painter.blob(Vector2(cx, -r * 0.9), r, rng, 12, 0.08, 0.9, rng.randf_range(-0.3, 0.3))
		draw_colored_polygon(drum, Color(0.27, 0.255, 0.24))
		for rr in [r * 0.35, r * 0.65]:
			draw_arc(Vector2(cx, -r * 0.9), rr, 0.0, TAU, 32, Color(0.06, 0.05, 0.05, 0.8), 1.6, true)
			draw_arc(Vector2(cx, -r * 0.9 + 1.4), rr, 0.2 * PI, 0.8 * PI, 18, Color(0.45, 0.43, 0.4, 0.3), 1.0, true)
		draw_polyline(Painter.closed(drum), Painter.INK, 2.0, true)
	for i in 14:
		Painter.stone(self, Vector2(rng.randf_range(-220, 210), rng.randf_range(-6, 2)), rng.randf_range(3, 9), rng, Color(0.25, 0.24, 0.23), 0.6, 1.1)
