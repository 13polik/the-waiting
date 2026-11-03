extends "res://scripts/world/room_base.gd"
## The Still Garden: a hidden grotto behind the loose stones of the Hall of
## Echoes. Glowing moss, a warm spring, and grey light from another crack far
## above — under which grows the pale bloom.

const Texts := preload("res://scripts/data/world_texts.gd")
const TunnelMouth := preload("res://scripts/world/props/tunnel_mouth.gd")
const GlowFeatures := preload("res://scripts/world/props/glow_features.gd")
const LightShaft := preload("res://scripts/world/props/light_shaft.gd")
const Pool := preload("res://scripts/world/props/pool.gd")
const BloomSprout := preload("res://scripts/world/props/bloom_sprout.gd")

const SKY_X := 1250.0
const SPRING_X := 1580.0


func _configure() -> void:
	room_id = "garden"
	title_key = "ROOM_GARDEN"
	bounds = Rect2(0, 0, 2000, 1100)
	left_limit = 200.0
	right_limit = 1820.0
	spawn_x = 320.0
	noise_seed = 7307
	floor_keys = [Vector2(-400, 795), Vector2(300, 800), Vector2(700, 810), Vector2(1100, 800), Vector2(1400, 790),
		Vector2(SPRING_X, 806), Vector2(1800, 800), Vector2(2400, 800)]
	ceil_keys = [Vector2(-400, 330), Vector2(400, 350), Vector2(900, 300), Vector2(1300, 320), Vector2(1800, 360), Vector2(2400, 360)]
	ceiling_slots = [SKY_X]
	spike_clear = [[SKY_X, 50.0], [SPRING_X, 50.0]]
	hero_spikes = [[SPRING_X, 30.0, 90.0]]
	stalagmites = [[500.0, 30.0, 60.0], [1700.0, 36.0, 80.0]]
	fg_humps = [[100.0, 880.0, 180.0], [950.0, 950.0, 130.0], [1900.0, 870.0, 200.0]]
	fg_spikes = [[700.0, 340.0, 32.0]]
	modulate_color = Color(0.29, 0.33, 0.35)
	stone = Color(0.19, 0.205, 0.19)
	wash_top = Color(0.08, 0.095, 0.09)
	wash_bottom = Color(0.15, 0.17, 0.155)
	strata = Color(0.17, 0.2, 0.17, 0.5)
	sound_space = "garden"
	entries = {"from_hall": {"x": 320.0, "facing": 1}}
	exit_specs = [{"id": "west", "x0": 150.0, "x1": 222.0, "side": "left", "to_room": "hall", "to_entry": "from_garden"}]


## The moss: its own words — or, with the bloom, a place to plant it, and
## then how the planted flower is coming along.
func _moss_lines(count: int) -> Array:
	var stage := BloomSprout.stage()
	if stage >= 0:
		return [["OBJ_SPROUT_STAGE0", "OBJ_SPROUT_STAGE1", "OBJ_SPROUT_STAGE2", "OBJ_SPROUT_STAGE3"][stage]]
	if WorldManager.has_item("bloom"):
		return ["OBJ_PLANT_1", "OBJ_PLANT_2"]
	var data: Dictionary = Texts.OBJECTS["moss"]
	if count <= 1:
		return data["first"]
	return [data["repeat"][(count - 2) % data["repeat"].size()]]


func _on_moss_examined(_count: int) -> void:
	if BloomSprout.stage() < 0 and WorldManager.has_item("bloom"):
		WorldManager.use_item("bloom")
		WorldManager.set_flag(BloomSprout.FLAG_PLANTED_DAY, TimeManager.day_index())


func _light_specs() -> Array:
	return [[Vector2(SKY_X + 30, floor_y(SKY_X) - 30), Color(0.62, 0.7, 0.78), 0.55, 2.2]]


func _add_props(parent: Node) -> void:
	var mouth := TunnelMouth.new()
	mouth.inward = -1.0
	mouth.position = Vector2(left_limit, floor_y(left_limit))
	parent.add_child(mouth)
	queue_bake(mouth)

	var moss_spots := [[700.0, 1], [1050.0, 2], [1480.0, 3], [1720.0, 4]]
	for m in moss_spots:
		var moss := GlowFeatures.new()
		moss.kind = "moss"
		moss.seed_value = m[1]
		moss.color = Color(0.5, 0.85, 0.72)
		moss.position = Vector2(m[0], floor_y(m[0]) + 2)
		parent.add_child(moss)
		queue_bake(moss)
	var sprout := BloomSprout.new()
	sprout.position = Vector2(745, floor_y(745))
	parent.add_child(sprout)
	var moss_i := add_interactable(parent, "moss", Texts.OBJECTS["moss"], Vector2(700, floor_y(700)), {"hit": Vector2(200, 90), "hit_offset": Vector2(0, -20), "prompt": Vector2(0, -60), "stand": 60.0})
	moss_i.dynamic_lines = _moss_lines
	moss_i.on_examined = _on_moss_examined

	var shaft := LightShaft.new()
	shaft.position = Vector2(SKY_X, 160)
	shaft.length = floor_y(SKY_X) - 160.0
	parent.add_child(shaft)
	add_interactable(parent, "skylight", Texts.OBJECTS["skylight"], Vector2(SKY_X - 60, floor_y(SKY_X)), {"hit": Vector2(160, 480), "hit_offset": Vector2(0, -280), "prompt": Vector2(0, -230), "stand": 40.0})
	add_collectible(parent, "bloom", Vector2(SKY_X + 32, floor_y(SKY_X + 32) - 6), {"stand": 50.0})

	pool = Pool.new()
	pool.position = Vector2(SPRING_X, floor_y(SPRING_X))
	pool.drop_height = floor_y(SPRING_X) - (ceil_y(SPRING_X) + 90.0)
	parent.add_child(pool)
	queue_bake(pool)
	add_interactable(parent, "spring", Texts.OBJECTS["spring"], pool.position, {"stand": 125.0, "radius": 150.0, "hit": Vector2(240, 120), "hit_offset": Vector2(0, -20), "prompt": Vector2(0, -70)})
