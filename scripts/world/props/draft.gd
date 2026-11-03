extends CPUParticles2D
## A faint draught carrying motes of dust along a tunnel, toward
## [member direction_x]. A handful of particles; additive and unshaded.

const LightTextures := preload("res://scripts/world/light_textures.gd")

var length: float = 1800.0
var direction_x: float = 1.0


func _ready() -> void:
	material = LightTextures.additive()
	amount = 26
	lifetime = 18.0
	preprocess = 18.0
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(length * 0.5, 70)
	direction = Vector2(direction_x, -0.05)
	spread = 8.0
	gravity = Vector2(0, 0.4)
	initial_velocity_min = 10.0
	initial_velocity_max = 22.0
	scale_amount_min = 1.0
	scale_amount_max = 1.8
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	fade.colors = PackedColorArray([Color(0.8, 0.86, 0.9, 0), Color(0.8, 0.86, 0.9, 0.22), Color(0.8, 0.86, 0.9, 0.22), Color(0.8, 0.86, 0.9, 0)])
	color_ramp = fade
