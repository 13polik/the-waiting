extends Node2D
## A still pool fed by a single drip from the stalactite above. Each drop is
## seen falling, ripples the surface, and is heard where it lands.
## Origin: floor contact, centre of the pool.

const Painter := preload("res://scripts/world/painter.gd")
const HALF_W := 108.0

## Static drawing is baked into a texture by Baker (see bake_rect).
var baked: bool = false

## Height of the stalactite tip above the pool surface.
var drop_height: float = 400.0
var _rng := RandomNumberGenerator.new()
var _ripples: Array[float] = []
var _drop_y: float = -1.0
var _drop_v: float = 0.0
var _next_drip: float = 2.0


func _ready() -> void:
	_rng.randomize()
	WorldManager.wet_ranges.append(Vector2(global_position.x - HALF_W + 10, global_position.x + HALF_W - 10))


func _process(delta: float) -> void:
	var dirty := false
	_next_drip -= delta
	if _next_drip <= 0.0 and _drop_y < 0.0:
		_drop_y = 0.0
		_drop_v = 0.0
	if _drop_y >= 0.0:
		_drop_v += 900.0 * delta
		_drop_y += _drop_v * delta
		dirty = true
		if _drop_y >= drop_height:
			_drop_y = -1.0
			_next_drip = _rng.randf_range(4.0, 13.0)
			_ripples.append(0.0)
			AudioManager.play_at("drip", global_position, -9.0, _rng.randf_range(0.85, 1.12))
	for i in range(_ripples.size() - 1, -1, -1):
		_ripples[i] += delta
		if _ripples[i] > 2.6:
			_ripples.remove_at(i)
	if not _ripples.is_empty():
		dirty = true
	if dirty:
		queue_redraw()


## Called by the creature when it steps in the water.
func splash() -> void:
	_ripples.append(0.9)


func bake_rect() -> Rect2:
	return Rect2(-HALF_W - 30, -20, HALF_W * 2 + 60, 40)


func _draw() -> void:
	if not baked:
		_draw_static()
	_draw_motion()


## Water, sheen and rim stones: baked.
func _draw_static() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5507
	var water := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		water.append(Vector2(cos(a) * HALF_W * (1.0 + rng.randf_range(-0.03, 0.03)), 3.0 + sin(a) * 9.0))
	draw_colored_polygon(water, Color(0.03, 0.04, 0.055))
	# Sheen: the cold light on the surface.
	draw_colored_polygon(Painter.ellipse(Vector2(-6, 2), 86, 4, 20), Color(0.30, 0.36, 0.44, 0.35))
	draw_line(Vector2(-70, 0), Vector2(50, -1), Color(0.65, 0.72, 0.8, 0.45), 1.4, true)
	draw_line(Vector2(-30, 3), Vector2(80, 3), Color(0.6, 0.68, 0.76, 0.22), 1.0, true)
	draw_polyline(Painter.closed(water), Color(Painter.INK, 0.8), 1.4, true)
	for i in 9:
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * rng.randf_range(HALF_W - 18, HALF_W + 8)
		Painter.stone(self, Vector2(x, rng.randf_range(-2, 4)), rng.randf_range(5, 11), rng, Color(0.24, 0.24, 0.25), 0.6, 1.3)


## Ripples and the falling drop: drawn live, over the baked water.
func _draw_motion() -> void:
	for r in _ripples:
		var k := r / 2.6
		var rx := 6.0 + r * 46.0
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.09))
		draw_arc(Vector2.ZERO, rx, 0.0, TAU, 40, Color(0.7, 0.78, 0.85, 0.4 * (1.0 - k)), 9.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _drop_y >= 0.0:
		var p := Vector2(0, -drop_height + _drop_y)
		draw_line(p - Vector2(0, minf(14.0, _drop_v * 0.02)), p, Color(0.7, 0.8, 0.86, 0.35), 1.2, true)
		draw_circle(p, 1.8, Color(0.82, 0.9, 0.95, 0.85))
