extends Node2D
## Things that give off their own faint light, unshaded and pulsing through
## modulate only (drawn once, never redrawn per frame):
##   "veins" — pale mineral threads in a wall (Hall of Echoes); [method flash]
##             brightens them when the hanging stones ring.
##   "moss"  — a bed of glowing moss with a soft light (Still Garden).
## Origin: veins — the centre of the patch; moss — floor contact.

const Painter := preload("res://scripts/world/painter.gd")
const LightTextures := preload("res://scripts/world/light_textures.gd")

var kind: String = "veins"
var seed_value: int = 1
var color: Color = Color(0.66, 0.84, 0.9)
## Static drawing is baked by Baker; the pulse stays (modulate on this node).
var baked: bool = false
var _t: float = 0.0
var _flash: float = 0.0
var _light: PointLight2D


func _ready() -> void:
	material = LightTextures.unshaded()
	_t = float(seed_value) * 1.7
	var energy := 0.35 if kind == "veins" else 0.7
	_light = LightTextures.make_light(color, energy, 1.6 if kind == "veins" else 1.9)
	_light.position = Vector2(0, -20 if kind == "moss" else 0)
	add_child(_light)


func bake_rect() -> Rect2:
	return Rect2(-150, -130, 300, 260) if kind == "veins" else Rect2(-112, -36, 224, 48)


func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 0.35)
	var pulse := 0.75 + 0.25 * sin(_t * 0.7) * sin(_t * 0.23 + 1.0) + 0.5 * _flash
	modulate = Color(pulse, pulse, pulse, 1.0)
	_light.energy = (0.25 if kind == "veins" else 0.55) * (0.6 + 0.4 * pulse)


func _draw() -> void:
	if baked:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + seed_value
	if kind == "veins":
		for v in 5:
			var p := Vector2(rng.randf_range(-80, 80), rng.randf_range(-60, 60))
			var a := rng.randf_range(-0.6, 0.6) + (PI if rng.randf() < 0.5 else 0.0)
			var pts := PackedVector2Array([p])
			for i in 9:
				a += rng.randf_range(-0.5, 0.5)
				p += Vector2.from_angle(a) * rng.randf_range(8, 16)
				pts.append(p)
			draw_polyline(pts, Color(color, 0.18), 5.0, true)
			draw_polyline(pts, Color(color, 0.8), 1.4, true)
		return
	# Moss: a low mound of soft glowing tufts.
	for i in 26:
		var x := rng.randf_range(-90, 90)
		var h := rng.randf_range(4, 12) * (1.0 - absf(x) / 110.0)
		var c := Vector2(x, -h * 0.5)
		draw_circle(c, rng.randf_range(6, 12), Color(color, 0.08))
		draw_colored_polygon(Painter.ellipse(c, rng.randf_range(5, 9), h * 0.6 + 2.0, 10), Color(color.darkened(0.25), 0.85))
		for k in 3:
			draw_circle(c + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 1)), 1.1, Color(color.lightened(0.4), 0.9))
