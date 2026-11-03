extends Node2D
## The great carved door. Concentric circles, four hundred notches, and a
## seam that glows a dull ember red in a very slow breathing rhythm.
## Origin: floor contact at the door's centre.

const Painter := preload("res://scripts/world/painter.gd")
const LightTextures := preload("res://scripts/world/light_textures.gd")
const HALF_W := 116.0
const HEIGHT := 360.0
const RING_CENTER := Vector2(0, -205)

## Static drawing is baked into a texture by Baker (see bake_rect).
var baked: bool = false

var _t: float = 0.0
var _seam: Node2D
var _light: PointLight2D


func _ready() -> void:
	_seam = Node2D.new()
	_seam.material = LightTextures.unshaded()
	_seam.draw.connect(_draw_seam)
	add_child(_seam)
	_light = LightTextures.make_light(Color(0.75, 0.32, 0.22), 0.3, 1.8)
	_light.position = Vector2(0, -180)
	add_child(_light)


## A breath roughly every 13 s: slow in, a pause, slower out.
func breath() -> float:
	var p := fmod(_t, 13.0)
	if p < 5.0:
		return smoothstep(0.0, 5.0, p)
	if p < 6.5:
		return 1.0
	return 1.0 - smoothstep(6.5, 13.0, p)


func _process(delta: float) -> void:
	_t += delta
	var b := breath()
	_seam.modulate.a = 0.15 + 0.6 * b
	_light.energy = 0.12 + 0.32 * b


func bake_rect() -> Rect2:
	return Rect2(-HALF_W - 70, -HEIGHT - 80, HALF_W * 2 + 140, HEIGHT + 96)


func _draw() -> void:
	if baked:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7703
	# Recess in the rock.
	var recess := PackedVector2Array([
		Vector2(-HALF_W - 30, 0), Vector2(-HALF_W - 34, -HEIGHT - 10), Vector2(-HALF_W + 20, -HEIGHT - 52),
		Vector2(HALF_W - 20, -HEIGHT - 52), Vector2(HALF_W + 34, -HEIGHT - 10), Vector2(HALF_W + 30, 0)])
	draw_colored_polygon(recess, Color(0.05, 0.048, 0.055))
	draw_polyline(Painter.closed(recess), Painter.INK, 2.4, true)
	# Two leaves of the door.
	for side: float in [-1.0, 1.0]:
		var leaf := PackedVector2Array()
		var inner := 1.5 * side
		var outer := HALF_W * side
		leaf.append(Vector2(inner, 0))
		leaf.append(Vector2(outer, 0))
		for k in 6:
			leaf.append(Vector2(outer + rng.randf_range(-1.5, 1.5), -HEIGHT * (k + 1) / 6.0))
		leaf.append(Vector2(inner, -HEIGHT))
		Painter.gradient_polygon(self, leaf, -HEIGHT, 0, Color(0.27, 0.25, 0.24), Color(0.17, 0.16, 0.16))
		draw_polyline(Painter.closed(leaf), Painter.INK, 2.0, true)
	# Carving: dark cut with a pale lower lip, like chisel work catching light.
	for r: float in [34.0, 62.0, 92.0]:
		draw_arc(RING_CENTER, r, 0, TAU, 64, Color(0.05, 0.045, 0.05, 0.9), 2.4, true)
		draw_arc(RING_CENTER + Vector2(0, 1.6), r, 0.15 * PI, 0.85 * PI, 40, Color(0.42, 0.40, 0.37, 0.35), 1.0, true)
	var spokes := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		spokes.append(RING_CENTER + Vector2.from_angle(a) * 36.0)
		spokes.append(RING_CENTER + Vector2.from_angle(a) * 60.0)
	draw_multiline(spokes, Color(0.05, 0.045, 0.05, 0.85), 1.8)
	var notches := PackedVector2Array()
	for i in 400:
		var a := TAU * i / 400.0
		var l := 7.0 if i % 10 == 0 else 3.5
		notches.append(RING_CENTER + Vector2.from_angle(a) * 99.0)
		notches.append(RING_CENTER + Vector2.from_angle(a) * (99.0 + l))
	draw_multiline(notches, Color(0.06, 0.05, 0.055, 0.8), 1.0)
	# Lintel and steps.
	var lintel := Painter.blob(Vector2(0, -HEIGHT - 16), HALF_W + 46, rng, 12, 0.04, 0.15)
	draw_colored_polygon(lintel, Color(0.21, 0.20, 0.20))
	draw_polyline(Painter.closed(lintel), Painter.INK, 2.0, true)
	for i in 2:
		var w := HALF_W + 50.0 - i * 20.0
		var y := -i * 9.0
		var step := PackedVector2Array([Vector2(-w, y + 2), Vector2(-w + 4, y - 9), Vector2(w - 4, y - 9), Vector2(w, y + 2)])
		draw_colored_polygon(step, Color(0.2, 0.19, 0.19))
		draw_line(Vector2(-w + 4, y - 9), Vector2(w - 4, y - 9), Color(0.38, 0.36, 0.34, 0.5), 1.0, true)
		draw_polyline(step, Painter.INK, 1.6, true)
	for i in 30:
		Painter.crack(self, Vector2(rng.randf_range(-HALF_W, HALF_W), rng.randf_range(-HEIGHT, -20)), rng, 3, 7.0, Color(0.05, 0.05, 0.05, 0.4), 0.9)


func _draw_seam() -> void:
	var c := Color(0.85, 0.36, 0.24)
	_seam.draw_line(Vector2(0, -12), Vector2(0, -HEIGHT + 2), Color(c, 0.9), 1.6, true)
	_seam.draw_line(Vector2(0, -12), Vector2(0, -HEIGHT + 2), Color(c, 0.18), 7.0, true)
	_seam.draw_arc(RING_CENTER, 34.0, 0, TAU, 48, Color(c, 0.45), 1.2, true)
	_seam.draw_circle(RING_CENTER, 4.0, Color(c, 0.6))
