extends "res://scripts/world/room_base.gd"
## The Hall of Echoes: a tall chamber, its roof lost in the dark. Hanging
## stones that ring (and make the mineral veins brighten), a fallen carved
## pillar, a moth wing on a stalagmite — and at the far end, a wall that is
## only piled stones. Pulling them away opens the way to the Still Garden.

const Texts := preload("res://scripts/data/world_texts.gd")
const TunnelMouth := preload("res://scripts/world/props/tunnel_mouth.gd")
const WallDetails := preload("res://scripts/world/props/wall_details.gd")
const LooseStones := preload("res://scripts/world/props/loose_stones.gd")
const ChimeStones := preload("res://scripts/world/props/chime_stones.gd")
const GlowFeatures := preload("res://scripts/world/props/glow_features.gd")

const FLAG_PASSAGE := "hall_passage_open"
const CHIMES_X := 900.0
const WING_STALAGMITE_X := 2150.0

var loose: Node2D
var veins: Node2D


func _configure() -> void:
	room_id = "hall"
	title_key = "ROOM_HALL"
	bounds = Rect2(0, 0, 3000, 1100)
	left_limit = 200.0
	right_limit = 2860.0
	spawn_x = 300.0
	noise_seed = 6211
	ceil_noise = 30.0
	floor_keys = [Vector2(-400, 780), Vector2(200, 790), Vector2(500, 800), Vector2(900, 795), Vector2(1200, 780),
		Vector2(1500, 770), Vector2(1800, 785), Vector2(2200, 800), Vector2(2600, 805), Vector2(3000, 800), Vector2(3400, 795)]
	ceil_keys = [Vector2(-400, 250), Vector2(300, 210), Vector2(800, 150), Vector2(1500, 120), Vector2(2200, 160),
		Vector2(2800, 230), Vector2(3400, 260)]
	spike_clear = [[CHIMES_X, 80.0]]
	hero_spikes = [[1150.0, 50.0, 260.0], [1900.0, 44.0, 230.0], [2420.0, 38.0, 200.0]]
	stalagmites = [[600.0, 50.0, 150.0], [1350.0, 64.0, 190.0], [WING_STALAGMITE_X, 56.0, 170.0], [2560.0, 34.0, 80.0]]
	fg_humps = [[150.0, 860.0, 200.0], [1000.0, 940.0, 140.0], [1750.0, 900.0, 200.0], [2900.0, 870.0, 220.0]]
	fg_spikes = [[500.0, 330.0, 40.0], [2600.0, 300.0, 36.0]]
	modulate_color = Color(0.26, 0.28, 0.36)
	stone = Color(0.19, 0.19, 0.21)
	wash_top = Color(0.07, 0.075, 0.095)
	wash_bottom = Color(0.15, 0.15, 0.17)
	sound_space = "hall"
	entries = {"from_narrow": {"x": 305.0, "facing": 1}, "from_garden": {"x": 2755.0, "facing": -1}}
	exit_specs = [
		{"id": "west", "x0": 150.0, "x1": 222.0, "side": "left", "to_room": "narrow", "to_entry": "from_hall"},
		{"id": "east", "x0": 2838.0, "x1": 2900.0, "side": "right", "to_room": "garden", "to_entry": "from_hall", "flag": FLAG_PASSAGE},
	]


func _light_specs() -> Array:
	return [
		[Vector2(CHIMES_X, floor_y(CHIMES_X) - 320), Color(0.6, 0.7, 0.85), 0.3, 1.4],
		[Vector2(1500, 300), Color(0.55, 0.62, 0.78), 0.4, 3.0],
	]


func _add_props(parent: Node) -> void:
	var mouth := TunnelMouth.new()
	mouth.inward = -1.0
	mouth.position = Vector2(left_limit, floor_y(left_limit))
	parent.add_child(mouth)

	veins = GlowFeatures.new()
	veins.kind = "veins"
	veins.seed_value = 3
	veins.position = Vector2(1300, floor_y(1300) - 330)
	parent.add_child(veins)
	add_interactable(parent, "veins", Texts.OBJECTS["veins"], Vector2(1300, floor_y(1300)), {"hit": Vector2(200, 160), "hit_offset": Vector2(0, -330), "prompt": Vector2(0, -420), "stand": 40.0})

	var chimes := ChimeStones.new()
	chimes.position = Vector2(CHIMES_X, floor_y(CHIMES_X))
	parent.add_child(chimes)
	chimes.rung.connect(veins.flash)
	var chimes_i := add_interactable(parent, "chimes", Texts.OBJECTS["chimes"], chimes.position, {"hit": Vector2(150, 140), "hit_offset": Vector2(-6, -300), "prompt": Vector2(-6, -400), "stand": 60.0})
	chimes_i.on_examined = func(_count: int) -> void: chimes.strike()

	var pillar := WallDetails.new()
	pillar.kind = "pillar"
	pillar.position = Vector2(1640, floor_y(1640))
	parent.add_child(pillar)
	add_interactable(parent, "pillar", Texts.OBJECTS["pillar"], pillar.position, {"hit": Vector2(420, 120), "hit_offset": Vector2(0, -50), "prompt": Vector2(0, -130), "stand": 230.0, "radius": 200.0})
	add_collectible(parent, "fragment", Vector2(1890, floor_y(1890) - 3), {"stand": 55.0})
	add_collectible(parent, "wing", Vector2(WING_STALAGMITE_X, floor_y(WING_STALAGMITE_X) - 162), {"stand": 50.0, "radius": 90.0})

	loose = LooseStones.new()
	loose.opened = WorldManager.get_flag(FLAG_PASSAGE, false)
	loose.position = Vector2(right_limit, floor_y(right_limit))
	parent.add_child(loose)
	var loose_i := add_interactable(parent, "loose", Texts.OBJECTS["loose"], Vector2(right_limit - 40, floor_y(right_limit)), {"hit": Vector2(160, 220), "hit_offset": Vector2(10, -100), "prompt": Vector2(10, -210), "stand": 90.0, "radius": 120.0})
	loose_i.dynamic_lines = _loose_lines
	loose_i.on_examined = _on_loose_examined

	for p in [mouth, pillar, loose, veins]:
		queue_bake(p)


func _loose_lines(count: int) -> Array:
	var data: Dictionary = Texts.OBJECTS["loose"]
	if not WorldManager.get_flag(FLAG_PASSAGE, false):
		return data["first"]
	return [data["repeat"][count % data["repeat"].size()]]


## The first examination pulls the stones away and opens the passage.
func _on_loose_examined(_count: int) -> void:
	if WorldManager.get_flag(FLAG_PASSAGE, false):
		return
	WorldManager.set_flag(FLAG_PASSAGE, true)
	AudioManager.play("rumble", -6.0, 1.3)
	loose.opened = true
	if loose.baked:
		Baker.rebake(loose)
	else:
		loose.queue_redraw()
	refresh_exits()
