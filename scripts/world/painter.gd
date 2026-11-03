extends RefCounted
## Drawing helpers that give THE WAITING its hand-inked look: wobbling
## outlines, catch-lights on the upper-left of every stone, heavier ink on
## the shadow side, charcoal hatching and fine cracks.
## All functions draw into a CanvasItem from inside its _draw().

const INK := Color(0.03, 0.028, 0.036, 0.92)


static func blob(center: Vector2, radius: float, rng: RandomNumberGenerator, verts: int = 9,
		irregular: float = 0.25, squash: float = 1.0, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a0 := rng.randf() * TAU
	var step := TAU / float(verts)
	for i in verts:
		var a := a0 + step * float(i) + rng.randf_range(-0.25, 0.25) * step
		var r := radius * (1.0 + rng.randf_range(-irregular, irregular))
		pts.append(center + Vector2(cos(a) * r, sin(a) * r * squash).rotated(rot))
	return pts


static func ellipse(center: Vector2, rx: float, ry: float, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c := pts.duplicate()
	c.append(pts[0])
	return c


## Fills [param pts] with a vertical gradient between [param y0] and [param y1].
static func gradient_polygon(ci: CanvasItem, pts: PackedVector2Array, y0: float, y1: float,
		top: Color, bottom: Color) -> void:
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf(inverse_lerp(y0, y1, p.y), 0.0, 1.0)))
	ci.draw_polygon(pts, cols)


## A stone: fill, a catch-light toward the upper left, and an ink outline
## that grows heavier along the underside.
static func stone(ci: CanvasItem, center: Vector2, radius: float, rng: RandomNumberGenerator,
		fill: Color, squash: float = 0.75, ink_width: float = 1.6, ink: Color = INK) -> void:
	var pts := blob(center, radius, rng, 8 + rng.randi() % 4, 0.22, squash, rng.randf_range(-0.4, 0.4))
	ci.draw_colored_polygon(pts, fill)
	var hl := PackedVector2Array()
	var off := Vector2(-radius * 0.10, -radius * squash * 0.20)
	for p in pts:
		hl.append(center + (p - center) * 0.66 + off)
	ci.draw_colored_polygon(hl, Color(fill.lightened(0.16), 0.55))
	ci.draw_polyline(closed(pts), ink, ink_width, true)
	var heavy := Color(ink, ink.a * 0.75)
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		if a.y > center.y and b.y > center.y:
			ci.draw_line(a, b, heavy, ink_width * 2.0, true)


## A thin, branching crack wandering from [param start].
static func crack(ci: CanvasItem, start: Vector2, rng: RandomNumberGenerator, segments: int,
		step: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array([start])
	var a := rng.randf_range(0.0, TAU)
	var p := start
	for i in segments:
		a += rng.randf_range(-0.7, 0.7)
		p += Vector2(cos(a), sin(a)) * step * rng.randf_range(0.6, 1.3)
		pts.append(p)
	ci.draw_polyline(pts, color, width, true)
	if segments > 4 and rng.randf() < 0.5:
		var half := int(segments * 0.5)
		crack(ci, pts[half], rng, half, step * 0.7, Color(color, color.a * 0.7), width * 0.7)


## A patch of parallel charcoal strokes.
static func hatch(ci: CanvasItem, center: Vector2, rng: RandomNumberGenerator, count: int,
		length: float, spacing: float, angle: float, color: Color, width: float = 1.0) -> void:
	var dir := Vector2.from_angle(angle)
	var perp := dir.orthogonal()
	var pts := PackedVector2Array()
	for i in count:
		var o := center + perp * (float(i) - count * 0.5) * spacing + dir * rng.randf_range(-3.0, 3.0)
		var l := length * rng.randf_range(0.55, 1.1)
		pts.append(o - dir * l * 0.5)
		pts.append(o + dir * l * 0.5)
	ci.draw_multiline(pts, color, width)


## A hanging or rising spike of rock. [param dir] is 1 for stalactites
## (pointing down) and -1 for stalagmites (pointing up).
static func spike(ci: CanvasItem, base: Vector2, width: float, length: float, dir: float,
		rng: RandomNumberGenerator, fill: Color, light: Color) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 6
	for i in steps + 1:
		var k := float(i) / steps
		var w := width * 0.5 * pow(1.0 - k, 0.8)
		pts.append(base + Vector2(-w + rng.randf_range(-1.5, 1.5), dir * length * k))
	var tip := pts[pts.size() - 1]
	for i in range(steps - 1, -1, -1):
		var k := float(i) / steps
		var w := width * 0.5 * pow(1.0 - k, 0.8)
		pts.append(base + Vector2(w + rng.randf_range(-1.5, 1.5), dir * length * k))
	ci.draw_colored_polygon(pts, fill)
	# A lit ridge down one flank.
	ci.draw_line(base + Vector2(-width * 0.18, dir * 4.0), tip.lerp(base, 0.12), light, maxf(1.0, width * 0.08), true)
	ci.draw_polyline(closed(pts), INK, 1.6, true)
	return pts
