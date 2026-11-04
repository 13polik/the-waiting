extends "res://scripts/world/room_base.gd"
## The Dungeon (0.5): where the creature wakes when the clock has been moved.
## A low cell closed by bars. The skipped days are taken back, and the bars
## stay down for one day of real waiting (TimeManager.jail_remaining); then
## they slide up and the way east leads home. Not on the map of places.

const TunnelMouth := preload("res://scripts/world/props/tunnel_mouth.gd")
const WallDetails := preload("res://scripts/world/props/wall_details.gd")
const CellBars := preload("res://scripts/world/props/cell_bars.gd")

const BARS_X := 1250.0
const FLAG_OPEN := "dungeon_open"

var bars: Node2D
var _gate: StaticBody2D


func _configure() -> void:
	room_id = "dungeon"
	title_key = "ROOM_DUNGEON"
	bounds = Rect2(0, 0, 1800, 1100)
	left_limit = 230.0
	right_limit = 1620.0
	spawn_x = 620.0
	noise_seed = 6203
	floor_keys = [Vector2(-400, 812), Vector2(400, 815), Vector2(900, 810), Vector2(1400, 806), Vector2(2200, 806)]
	ceil_keys = [Vector2(-400, 470), Vector2(500, 500), Vector2(1000, 480), Vector2(1500, 470), Vector2(2200, 470)]
	ceil_noise = 10.0
	stalagmites = [[420.0, 22.0, 40.0]]
	fg_humps = [[100.0, 900.0, 170.0], [1750.0, 880.0, 190.0]]
	modulate_color = Color(0.24, 0.24, 0.29)
	stone = Color(0.17, 0.17, 0.2)
	wash_top = Color(0.06, 0.06, 0.08)
	wash_bottom = Color(0.13, 0.13, 0.16)
	strata = Color(0.16, 0.16, 0.19, 0.5)
	sound_space = "tunnel"
	entries = {"cell": {"x": 620.0, "facing": 1}}
	exit_specs = [{"id": "east", "x0": 1560.0, "x1": 1660.0, "side": "right", "to_room": "home", "to_entry": "from_dungeon", "flag": FLAG_OPEN}]


func _light_specs() -> Array:
	# A thin cold light falling through the bars.
	return [[Vector2(BARS_X + 120, floor_y(BARS_X) - 200), Color(0.55, 0.6, 0.75), 0.35, 1.8]]


func _add_props(parent: Node) -> void:
	var free := not TimeManager.is_jailed()
	WorldManager.set_flag(FLAG_OPEN, free)

	var mouth := TunnelMouth.new()
	mouth.inward = 1.0
	mouth.position = Vector2(right_limit, floor_y(right_limit))
	parent.add_child(mouth)
	queue_bake(mouth)

	var marks := WallDetails.new()
	marks.kind = "marks"
	marks.position = Vector2(420, floor_y(420) - 150)
	parent.add_child(marks)
	queue_bake(marks)
	add_interactable(parent, "cell_marks", {"title": "OBJ_CELLMARKS_TITLE", "first": ["OBJ_CELLMARKS_1", "OBJ_CELLMARKS_2"], "repeat": ["OBJ_CELLMARKS_R1"]},
		Vector2(420, floor_y(420)), {"hit": Vector2(240, 140), "hit_offset": Vector2(0, -150), "prompt": Vector2(0, -240), "stand": 40.0})

	bars = CellBars.new()
	bars.position = Vector2(BARS_X, floor_y(BARS_X))
	bars.is_open = free
	parent.add_child(bars)
	var it := add_interactable(parent, "bars", {"title": "OBJ_BARS_TITLE", "first": [], "repeat": []},
		Vector2(BARS_X - 60, floor_y(BARS_X)), {"hit": Vector2(170, 420), "hit_offset": Vector2(60, -220), "prompt": Vector2(60, -450), "stand": 0.0, "radius": 120.0})
	it.dynamic_lines = _bars_lines

	# The bars are solid while they are down.
	_gate = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = Vector2(BARS_X - 80, -200)
	seg.b = Vector2(BARS_X - 80, 1100)
	shape.shape = seg
	_gate.add_child(shape)
	add_child(_gate)
	if free:
		_gate.process_mode = Node.PROCESS_MODE_DISABLED
		shape.disabled = true
	if not TimeManager.jail_released.is_connected(_on_released):
		TimeManager.jail_released.connect(_on_released)


func _exit_tree() -> void:
	if TimeManager.jail_released.is_connected(_on_released):
		TimeManager.jail_released.disconnect(_on_released)


func _bars_lines(_count: int) -> Array:
	if not TimeManager.is_jailed():
		return ["OBJ_BARS_OPEN"]
	return [["OBJ_BARS_1"], ["OBJ_BARS_WAIT", Loc.duration(maxf(60.0, TimeManager.jail_remaining()))]]


func is_gate_closed() -> bool:
	return _gate != null and not (_gate.get_child(0) as CollisionShape2D).disabled


func _on_released() -> void:
	WorldManager.set_flag(FLAG_OPEN, true)
	(_gate.get_child(0) as CollisionShape2D).set_deferred("disabled", true)
	bars.open(true)
	AudioManager.play("rumble", -6.0, 0.8)
	refresh_exits()
	UIManager.toast(Loc.t("JAIL_RELEASED"))
