extends Node2D
## A cluster of faintly glowing fungus caps. More caps appear, and all grow a
## little, as real days pass. The glow pulses through modulate (no redraw).
## Origin: floor contact.

const LightTextures := preload("res://scripts/world/light_textures.gd")
const Baker := preload("res://scripts/world/baker.gd")
const GLOW := Color(0.62, 0.92, 0.94)
const MAX_CAPS := 14

## Static drawing is baked into a texture by Baker (see bake_rect).
var baked: bool = false

var _t: float = 0.0
var light: PointLight2D


func _ready() -> void:
	material = LightTextures.unshaded()
	TimeManager.day_changed.connect(func(_d: int) -> void: Baker.rebake(self))
	light = LightTextures.make_light(Color(0.45, 0.85, 0.88), 0.85, 1.6)
	light.position = Vector2(0, -26)
	add_child(light)


## 0..1 over the whole wait, quick at first.
func growth() -> float:
	return clampf(sqrt(TimeManager.days_elapsed() / 400.0), 0.0, 1.0)


func visible_caps() -> int:
	return 6 + int(round(growth() * (MAX_CAPS - 6)))


func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.82 + 0.18 * sin(_t * 0.9) * sin(_t * 0.37 + 1.0)
	modulate = Color(pulse, pulse, pulse, 1.0)
	light.energy = 0.55 + 0.35 * pulse


func bake_rect() -> Rect2:
	return Rect2(-100, -110, 200, 120)


func _draw() -> void:
	if baked:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 6601
	var size := 1.05 + 0.4 * growth()
	var caps := visible_caps()
	for i in MAX_CAPS:
		var x := rng.randf_range(-58.0, 58.0)
		var h := rng.randf_range(8.0, 34.0) * size
		var w := rng.randf_range(6.0, 13.0) * size
		var lean := rng.randf_range(-0.25, 0.25)
		if i >= caps:
			continue
		var top := Vector2(x + lean * h, -h)
		draw_circle(top, w * 2.6, Color(GLOW, 0.05))
		draw_line(Vector2(x, 2), top, Color(0.55, 0.72, 0.72, 0.7), maxf(1.2, w * 0.22), true)
		var cap := PackedVector2Array()
		for k in 11:
			var a := PI + PI * k / 10.0
			cap.append(top + Vector2(cos(a) * w, sin(a) * w * 0.62))
		cap.append(top + Vector2(w * 0.7, w * 0.12))
		cap.append(top + Vector2(-w * 0.7, w * 0.12))
		draw_colored_polygon(cap, Color(GLOW, 0.88))
		draw_line(top + Vector2(-w * 0.6, w * 0.08), top + Vector2(w * 0.6, w * 0.08), Color(0.25, 0.4, 0.42, 0.8), 1.0, true)
		draw_circle(top + Vector2(-w * 0.3, -w * 0.3), w * 0.18, Color(1, 1, 1, 0.5))
