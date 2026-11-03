extends Node2D
## A thread of grey light falling from the crack in the ceiling, with dust
## turning slowly inside it. Origin: the crack; [member length] reaches the floor.

const LightTextures := preload("res://scripts/world/light_textures.gd")

var length: float = 520.0
var _t: float = 0.0


func _ready() -> void:
	material = LightTextures.additive()
	var dust := CPUParticles2D.new()
	dust.material = LightTextures.additive()
	dust.amount = 22
	dust.lifetime = 14.0
	dust.preprocess = 14.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(40, length * 0.45)
	dust.position = Vector2(0, length * 0.5)
	dust.direction = Vector2(0.2, 1)
	dust.spread = 60.0
	dust.gravity = Vector2(0, 1.5)
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 5.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.2
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(0.8, 0.85, 0.9, 0), Color(0.8, 0.85, 0.9, 0.35), Color(0.8, 0.85, 0.9, 0.35), Color(0.8, 0.85, 0.9, 0)])
	dust.color_ramp = fade
	add_child(dust)


func _process(delta: float) -> void:
	_t += delta
	# The light breathes almost imperceptibly, as if clouds passed far above.
	modulate.a = 0.85 + 0.15 * sin(_t * 0.21) * sin(_t * 0.067)


func _draw() -> void:
	var top_w := 14.0
	var bot_w := 92.0
	var cols := PackedColorArray([
		Color(0.55, 0.60, 0.68, 0.16), Color(0.55, 0.60, 0.68, 0.16),
		Color(0.55, 0.60, 0.68, 0.0), Color(0.55, 0.60, 0.68, 0.0)])
	var core := PackedVector2Array([Vector2(-top_w, 0), Vector2(top_w, 0), Vector2(bot_w + 30, length), Vector2(-bot_w + 30, length)])
	draw_polygon(core, PackedColorArray([cols[0], cols[1], Color(0.55, 0.6, 0.68, 0.05), Color(0.55, 0.6, 0.68, 0.05)]))
	var halo := PackedVector2Array([Vector2(-top_w * 2.5, 0), Vector2(top_w * 2.5, 0), Vector2(bot_w * 1.8 + 30, length), Vector2(-bot_w * 1.8 + 30, length)])
	draw_polygon(halo, PackedColorArray([Color(0.5, 0.55, 0.65, 0.05), Color(0.5, 0.55, 0.65, 0.05), cols[2], cols[3]]))
	# Where it lands: a pale smudge on the floor.
	var smudge := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		smudge.append(Vector2(30 + cos(a) * 90, length + sin(a) * 9))
	draw_colored_polygon(smudge, Color(0.55, 0.6, 0.66, 0.08))
