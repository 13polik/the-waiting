extends "res://scripts/world/room_base.gd"
## Beyond the Door (0.6): the place the creature waited four hundred days to
## see. Warmer and brighter than anything below: falls of light, a field of
## glowing blooms, and at the far end an opening full of daylight. Walking
## into that light ends the wait ([signal ending_reached]).

signal ending_reached

const TunnelMouth := preload("res://scripts/world/props/tunnel_mouth.gd")
const GlowFeatures := preload("res://scripts/world/props/glow_features.gd")
const LightShaft := preload("res://scripts/world/props/light_shaft.gd")

const OPENING_X := 2860.0


func _configure() -> void:
	room_id = "beyond"
	title_key = "ROOM_BEYOND"
	bounds = Rect2(0, 0, 3100, 1100)
	left_limit = 220.0
	right_limit = 2940.0
	spawn_x = 360.0
	noise_seed = 4001
	floor_keys = [Vector2(-400, 806), Vector2(500, 800), Vector2(1100, 780), Vector2(1800, 770), Vector2(2400, 760), Vector2(3500, 750)]
	ceil_keys = [Vector2(-400, 330), Vector2(800, 250), Vector2(1500, 200), Vector2(2200, 180), Vector2(3500, 160)]
	ceil_noise = 22.0
	ceiling_slots = [900.0, 1600.0, 2250.0]
	stalagmites = [[700.0, 26.0, 60.0], [1950.0, 30.0, 70.0]]
	fg_humps = [[80.0, 900.0, 180.0], [1300.0, 930.0, 140.0], [2600.0, 900.0, 200.0]]
	modulate_color = Color(0.78, 0.72, 0.6)
	stone = Color(0.4, 0.36, 0.3)
	wash_top = Color(0.42, 0.38, 0.3)
	wash_bottom = Color(0.55, 0.48, 0.36)
	strata = Color(0.32, 0.28, 0.24, 0.45)
	sound_space = "garden"
	entries = {"from_door": {"x": 360.0, "facing": 1}}
	exit_specs = [{"id": "west", "x0": 160.0, "x1": 240.0, "side": "left", "to_room": "home", "to_entry": "from_beyond"}]


func _light_specs() -> Array:
	return [
		[Vector2(900, 520), Color(1.0, 0.9, 0.7), 0.5, 2.2],
		[Vector2(1600, 470), Color(1.0, 0.9, 0.7), 0.55, 2.4],
		[Vector2(2250, 430), Color(1.0, 0.92, 0.75), 0.6, 2.6],
		[Vector2(OPENING_X, floor_y(OPENING_X) - 160), Color(1.0, 0.95, 0.85), 1.1, 3.2],
	]


func _add_props(parent: Node) -> void:
	var back := TunnelMouth.new()
	back.inward = -1.0
	back.position = Vector2(left_limit, floor_y(left_limit))
	parent.add_child(back)
	queue_bake(back)

	for x in [900.0, 1600.0, 2250.0]:
		var shaft := LightShaft.new()
		shaft.position = Vector2(x, ceil_y(x) + 10.0)
		shaft.length = floor_y(x) - ceil_y(x) - 10.0
		parent.add_child(shaft)

	var seeds := [[1150.0, 11], [1380.0, 12], [1720.0, 13], [2000.0, 14], [2420.0, 15]]
	for m in seeds:
		var bloom := GlowFeatures.new()
		bloom.kind = "moss"
		bloom.seed_value = m[1]
		bloom.color = Color(1.0, 0.86, 0.6)
		bloom.position = Vector2(m[0], floor_y(m[0]) + 2)
		parent.add_child(bloom)
		queue_bake(bloom)
	add_interactable(parent, "beyond_field", {"title": "OBJ_FIELD_TITLE", "first": ["OBJ_FIELD_1", "OBJ_FIELD_2"], "repeat": ["OBJ_FIELD_R1"]},
		Vector2(1380, floor_y(1380)), {"hit": Vector2(260, 90), "hit_offset": Vector2(0, -20), "prompt": Vector2(0, -70), "stand": 60.0})
	add_interactable(parent, "beyond_air", {"title": "OBJ_AIR_TITLE", "first": ["OBJ_AIR_1", "OBJ_AIR_2"], "repeat": ["OBJ_AIR_R1"]},
		Vector2(900, floor_y(900)), {"hit": Vector2(140, 300), "hit_offset": Vector2(0, -150), "prompt": Vector2(0, -330), "stand": 40.0})

	# The opening: daylight.
	var glow := Node2D.new()
	glow.material = LightTextures.additive()
	glow.position = Vector2(OPENING_X, floor_y(OPENING_X))
	glow.draw.connect(func() -> void:
		for i in 6:
			var r := 60.0 + i * 34.0
			glow.draw_circle(Vector2(0, -170), r, Color(1.0, 0.94, 0.8, 0.12)))
	parent.add_child(glow)
	var opening := add_interactable(parent, "beyond_opening", {"title": "OBJ_OPENING_TITLE", "first": ["OBJ_OPENING_1", "OBJ_OPENING_2"], "repeat": ["OBJ_OPENING_1"]},
		Vector2(OPENING_X, floor_y(OPENING_X)), {"hit": Vector2(220, 380), "hit_offset": Vector2(0, -180), "prompt": Vector2(0, -400), "stand": 80.0, "radius": 140.0})
	opening.on_examined = func(_count: int) -> void: after_text(ending_reached.emit)
