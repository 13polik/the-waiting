extends "res://scripts/world/room_base.gd"
## The Scribe's Alcove (0.4): behind the old passage at home, opened by
## pulling one stone a day for seven days. Someone waited here before: a stone
## desk worn smooth, a dark bulb on a dried stalk, walls of marks in sevens,
## and a bundle of pages whose ink comes back a little each day.

const Texts := preload("res://scripts/data/world_texts.gd")
const TunnelMouth := preload("res://scripts/world/props/tunnel_mouth.gd")
const WallDetails := preload("res://scripts/world/props/wall_details.gd")
const GlowFeatures := preload("res://scripts/world/props/glow_features.gd")

const DESK_X := 1050.0
## Day the pages were found (TimeManager.day_index), for the daily reading.
const FLAG_PAGES_DAY := "pages_found_day"


func _configure() -> void:
	room_id = "alcove"
	title_key = "ROOM_ALCOVE"
	bounds = Rect2(0, 0, 2000, 1100)
	left_limit = 200.0
	right_limit = 1820.0
	spawn_x = 1700.0
	noise_seed = 8419
	floor_keys = [Vector2(-400, 800), Vector2(400, 805), Vector2(900, 812), Vector2(1300, 800), Vector2(1800, 795), Vector2(2400, 795)]
	ceil_keys = [Vector2(-400, 420), Vector2(500, 450), Vector2(1000, 430), Vector2(1500, 460), Vector2(2400, 440)]
	ceil_noise = 16.0
	stalagmites = [[480.0, 28.0, 56.0], [1580.0, 34.0, 70.0]]
	fg_humps = [[120.0, 880.0, 180.0], [900.0, 950.0, 120.0], [1900.0, 870.0, 200.0]]
	modulate_color = Color(0.29, 0.28, 0.3)
	stone = Color(0.21, 0.2, 0.19)
	wash_top = Color(0.09, 0.085, 0.08)
	wash_bottom = Color(0.17, 0.155, 0.145)
	strata = Color(0.2, 0.185, 0.17, 0.5)
	sound_space = "tunnel"
	entries = {"from_home": {"x": 1715.0, "facing": -1}}
	exit_specs = [{"id": "east", "x0": 1798.0, "x1": 1860.0, "side": "right", "to_room": "home", "to_entry": "from_alcove"}]


func _light_specs() -> Array:
	# A faint warmth around the desk, as if it remembered a lamp.
	return [[Vector2(DESK_X, floor_y(DESK_X) - 120), Color(0.85, 0.7, 0.5), 0.3, 1.6]]


func _add_props(parent: Node) -> void:
	var mouth := TunnelMouth.new()
	mouth.inward = 1.0
	mouth.position = Vector2(right_limit, floor_y(right_limit))
	parent.add_child(mouth)

	var veins := GlowFeatures.new()
	veins.kind = "veins"
	veins.seed_value = 7
	veins.color = Color(0.85, 0.75, 0.6)
	veins.position = Vector2(380, floor_y(380) - 300)
	parent.add_child(veins)

	var lamp := _detail(parent, "lamp", Vector2(650, floor_y(650)))
	add_interactable(parent, "lamp", Texts.OBJECTS["lamp"], lamp.position, {"hit": Vector2(200, 80), "hit_offset": Vector2(10, -20), "prompt": Vector2(10, -70), "stand": 90.0})
	var desk := _detail(parent, "desk", Vector2(DESK_X, floor_y(DESK_X)))
	add_interactable(parent, "desk", Texts.OBJECTS["desk"], desk.position, {"hit": Vector2(260, 110), "hit_offset": Vector2(-40, -40), "prompt": Vector2(-90, -130), "stand": 150.0, "radius": 170.0})
	var sevens := _detail(parent, "marks", Vector2(1420, floor_y(1420) - 160))
	add_interactable(parent, "sevens", Texts.OBJECTS["sevens"], Vector2(1420, floor_y(1420)), {"hit": Vector2(250, 140), "hit_offset": Vector2(0, -160), "prompt": Vector2(0, -240), "stand": 40.0})
	add_collectible(parent, "pages", Vector2(DESK_X + 30, floor_y(DESK_X) - 64), {"stand": 70.0, "radius": 100.0})
	if not WorldManager.item_added.is_connected(_on_item_added):
		WorldManager.item_added.connect(_on_item_added)
	for p in [mouth, veins, lamp, desk, sevens]:
		queue_bake(p)


func _exit_tree() -> void:
	if WorldManager.item_added.is_connected(_on_item_added):
		WorldManager.item_added.disconnect(_on_item_added)


func _on_item_added(item_id: String) -> void:
	if item_id == "pages" and WorldManager.get_flag(FLAG_PAGES_DAY) == null:
		WorldManager.set_flag(FLAG_PAGES_DAY, TimeManager.day_index())


func _detail(parent: Node, kind: String, pos: Vector2) -> Node2D:
	var d := WallDetails.new()
	d.kind = kind
	d.position = pos
	parent.add_child(d)
	return d
