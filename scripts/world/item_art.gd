extends RefCounted
## How each collectible looks — used both where it lies in the world and in
## the satchel, so the two always match. Drawn around [param c], ~20 px wide
## at scale 1.

const Painter := preload("res://scripts/world/painter.gd")
const INK := Color(0.04, 0.035, 0.045, 0.9)


static func draw(ci: CanvasItem, item_id: String, c: Vector2, s: float = 1.0) -> void:
	match item_id:
		"stone": _stone(ci, c, s)
		"wing": _wing(ci, c, s)
		"fragment": _fragment(ci, c, s)
		"bloom": _bloom(ci, c, s)


static func _stone(ci: CanvasItem, c: Vector2, s: float) -> void:
	var body := Painter.ellipse(c, 10.0 * s, 7.0 * s, 20)
	ci.draw_colored_polygon(body, Color(0.46, 0.45, 0.43))
	ci.draw_colored_polygon(Painter.ellipse(c + Vector2(-2.5, -2.5) * s, 5.0 * s, 2.8 * s, 14), Color(0.66, 0.66, 0.63, 0.7))
	ci.draw_polyline(Painter.closed(body), INK, 1.4 * s, true)


static func _wing(ci: CanvasItem, c: Vector2, s: float) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := PI * 0.15 + PI * 1.3 * i / 15.0
		var r := (11.0 + 3.0 * sin(a * 2.0)) * s
		pts.append(c + Vector2(cos(a) * r, -sin(a) * r * 0.7) + Vector2(-4.0, 2.0) * s)
	pts.append(c + Vector2(-6.0, 4.0) * s)
	ci.draw_colored_polygon(pts, Color(0.86, 0.82, 0.70))
	var veins := PackedVector2Array()
	for i in 4:
		var a := PI * 0.25 + PI * 0.28 * i
		veins.append(c + Vector2(-6.0, 4.0) * s)
		veins.append(c + Vector2(-4.0, 2.0) * s + Vector2(cos(a), -sin(a) * 0.7) * 10.0 * s)
	ci.draw_multiline(veins, Color(0.55, 0.5, 0.4, 0.7), 0.8 * s)
	ci.draw_circle(c + Vector2(0.5, -2.0) * s, 2.0 * s, Color(0.45, 0.38, 0.3, 0.8))
	ci.draw_polyline(pts, INK, 1.1 * s, true)


static func _fragment(ci: CanvasItem, c: Vector2, s: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-11, 6) * s, c + Vector2(-9, -6) * s, c + Vector2(-1, -10) * s,
		c + Vector2(9, -7) * s, c + Vector2(12, 3) * s, c + Vector2(3, 8) * s])
	ci.draw_colored_polygon(pts, Color(0.32, 0.30, 0.29))
	# Two grooves of a circle much larger than the fragment, as on the door.
	for r in [14.0, 20.0]:
		ci.draw_arc(c + Vector2(4, 14) * s, r * s, -PI * 0.85, -PI * 0.35, 12, Color(0.06, 0.05, 0.05, 0.85), 1.2 * s, true)
	var notches := PackedVector2Array()
	for i in 5:
		var a := -PI * 0.8 + PI * 0.1 * i
		notches.append(c + Vector2(4, 14) * s + Vector2.from_angle(a) * 22.0 * s)
		notches.append(c + Vector2(4, 14) * s + Vector2.from_angle(a) * 24.5 * s)
	ci.draw_multiline(notches, Color(0.06, 0.05, 0.05, 0.8), 1.0 * s)
	ci.draw_polyline(Painter.closed(pts), INK, 1.4 * s, true)


static func _bloom(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_line(c + Vector2(0, 2) * s, c + Vector2(1, 12) * s, Color(0.45, 0.55, 0.48), 1.4 * s, true)
	for i in 5:
		var a := TAU * i / 5.0 - PI * 0.5
		var p := c + Vector2.from_angle(a) * 5.0 * s
		ci.draw_colored_polygon(Painter.ellipse(p, 4.2 * s, 2.6 * s, 12), Color(0.90, 0.92, 0.88))
	ci.draw_circle(c, 2.0 * s, Color(0.78, 0.82, 0.62))
