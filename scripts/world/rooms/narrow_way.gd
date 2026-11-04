extends "res://scripts/world/room_base.gd"
## The Narrow Way: a low tunnel running east from the crevice beside the
## door. A draught moves through it. On the walls: a fossil spiral, and
## someone else's tally. Under a thread of water lies the smooth stone.

const Texts := preload("res://scripts/data/world_texts.gd")
const TunnelMouth := preload("res://scripts/world/props/tunnel_mouth.gd")
const WallDetails := preload("res://scripts/world/props/wall_details.gd")
const Draft := preload("res://scripts/world/props/draft.gd")

const TRICKLE_X := 1250.0


func _configure() -> void:
	room_id = "narrow"
	title_key = "ROOM_NARROW"
	bounds = Rect2(0, 0, 2400, 1100)
	left_limit = 150.0
	right_limit = 2250.0
	spawn_x = 260.0
	noise_seed = 5113
	ceil_noise = 14.0
	floor_keys = [Vector2(-400, 790), Vector2(100, 795), Vector2(400, 805), Vector2(800, 800), Vector2(TRICKLE_X, 814),
		Vector2(1600, 805), Vector2(2000, 795), Vector2(2400, 790), Vector2(2800, 790)]
	ceil_keys = [Vector2(-400, 520), Vector2(300, 540), Vector2(700, 565), Vector2(1100, 550), Vector2(1500, 575),
		Vector2(1900, 548), Vector2(2400, 530), Vector2(2800, 520)]
	spike_clear = [[TRICKLE_X, 40.0]]
	stalagmites = [[620.0, 26.0, 50.0], [1720.0, 30.0, 62.0]]
	fg_humps = [[300.0, 900.0, 160.0], [1100.0, 950.0, 120.0], [1950.0, 920.0, 180.0]]
	fg_spikes = []
	modulate_color = Color(0.27, 0.29, 0.33)
	stone = Color(0.21, 0.195, 0.185)
	wash_top = Color(0.09, 0.085, 0.09)
	sound_space = "tunnel"
	entries = {"from_home": {"x": 255.0, "facing": 1}, "from_hall": {"x": 2145.0, "facing": -1}}
	exit_specs = [
		{"id": "west", "x0": 100.0, "x1": 172.0, "side": "left", "to_room": "home", "to_entry": "from_narrow"},
		{"id": "east", "x0": 2228.0, "x1": 2290.0, "side": "right", "to_room": "hall", "to_entry": "from_narrow"},
	]


func _light_specs() -> Array:
	return [[Vector2(TRICKLE_X, floor_y(TRICKLE_X) - 60), Color(0.5, 0.65, 0.8), 0.35, 1.2]]


func _add_props(parent: Node) -> void:
	for spec in [[left_limit, -1.0], [right_limit, 1.0]]:
		var mouth := TunnelMouth.new()
		mouth.inward = spec[1]
		mouth.position = Vector2(spec[0], floor_y(spec[0]))
		parent.add_child(mouth)
		queue_bake(mouth)

	var fossil := _detail(parent, "fossil", Vector2(700, floor_y(700) - 150))
	add_interactable(parent, "fossil", Texts.OBJECTS["fossil"], Vector2(700, floor_y(700)), {"hit": Vector2(140, 140), "hit_offset": Vector2(0, -150), "prompt": Vector2(0, -230), "stand": 40.0})
	var marks := _detail(parent, "marks", Vector2(1720, floor_y(1720) - 150))
	add_interactable(parent, "marks", Texts.OBJECTS["marks"], Vector2(1760, floor_y(1760)), {"hit": Vector2(250, 140), "hit_offset": Vector2(-40, -150), "prompt": Vector2(-40, -230), "stand": 40.0})
	var trickle := _detail(parent, "trickle", Vector2(TRICKLE_X, floor_y(TRICKLE_X)))
	add_interactable(parent, "trickle", Texts.OBJECTS["trickle"], Vector2(TRICKLE_X - 30, floor_y(TRICKLE_X)), {"hit": Vector2(110, 260), "hit_offset": Vector2(30, -190), "prompt": Vector2(30, -300), "stand": 70.0, "radius": 90.0})
	add_collectible(parent, "stone", Vector2(TRICKLE_X + 4, floor_y(TRICKLE_X) - 4), {"stand": 60.0})
	add_collectible(parent, "book_door", Vector2(2000, floor_y(2000) - 6), {"stand": 55.0})
	for p in [fossil, marks, trickle]:
		queue_bake(p)

	var draft := Draft.new()
	draft.length = 2000.0
	draft.direction_x = -1.0
	draft.position = Vector2(1200, floor_y(1200) - 120)
	parent.add_child(draft)


func _detail(parent: Node, kind: String, pos: Vector2) -> Node2D:
	var d := WallDetails.new()
	d.kind = kind
	d.position = pos
	parent.add_child(d)
	return d
