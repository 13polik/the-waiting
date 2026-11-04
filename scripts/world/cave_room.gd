extends "res://scripts/world/room_base.gd"
## The creature's first home, left to right: the choked passage, the tally
## wall, The Nest, the cairn, the crack of grey light, the still pool, the
## pale caps, the carved door — and, beside the door, a crevice leading east
## into the Narrow Way (0.3). The old passage can be dug out, one stone per
## real day; after seven it opens west into the Scribe's Alcove (0.4).

const Texts := preload("res://scripts/data/home_texts.gd")
const Nest := preload("res://scripts/world/props/nest.gd")
const Cairn := preload("res://scripts/world/props/cairn.gd")
const Tally := preload("res://scripts/world/props/tally.gd")
const Passage := preload("res://scripts/world/props/passage.gd")
const LightShaft := preload("res://scripts/world/props/light_shaft.gd")
const Pool := preload("res://scripts/world/props/pool.gd")
const PaleCaps := preload("res://scripts/world/props/pale_caps.gd")
const Door := preload("res://scripts/world/props/door.gd")
const TunnelMouth := preload("res://scripts/world/props/tunnel_mouth.gd")
const HomeDecor := preload("res://scripts/world/props/home_decor.gd")
const Books := preload("res://scripts/data/books.gd")
const SHELF_X := 1130.0
const SHELF_UP := 200.0
## Set by the Lamplighter (0.7): a book left on the shelf.
const FLAG_LAMP_BOOK := "lamp_book_left"

const ROOM_ID := "home"
const CRACK_X := 1562.0
const POOL_X := 1880.0
## The cairn grows by one stone when the smooth stone is placed on it.
const FLAG_CAIRN_EIGHTH := "cairn_eighth_stone"
const FLAG_PASSAGE_STONES := "passage_stones"
const FLAG_PASSAGE_LAST_DAY := "passage_last_day"
const FLAG_PASSAGE_OPEN := "passage_open"

var passage: Node2D
var door: Node2D
const FLAG_DOOR_SEEN_OPEN := "door_seen_open"

var tally: Node2D
var shelf: Node2D
var caps: Node2D
var cairn: Node2D


func _configure() -> void:
	room_id = ROOM_ID
	title_key = "ROOM_HOME"
	bounds = Rect2(0, 0, 3200, 1100)
	left_limit = 330.0
	right_limit = 3005.0
	spawn_x = 1000.0
	noise_seed = 4001
	floor_keys = [
		Vector2(-400, 760), Vector2(150, 768), Vector2(380, 790), Vector2(700, 800), Vector2(1000, 812),
		Vector2(1150, 806), Vector2(1350, 797), Vector2(1600, 793), Vector2(1880, 812), Vector2(2060, 806),
		Vector2(2300, 798), Vector2(2580, 786), Vector2(2760, 774), Vector2(3000, 772), Vector2(3600, 760)]
	ceil_keys = [
		Vector2(-400, 300), Vector2(300, 330), Vector2(700, 365), Vector2(1000, 385), Vector2(1300, 352),
		Vector2(1480, 305), Vector2(1650, 300), Vector2(1880, 360), Vector2(2200, 352), Vector2(2500, 300),
		Vector2(2750, 250), Vector2(3000, 262), Vector2(3600, 280)]
	ceiling_slots = [CRACK_X]
	spike_clear = [[CRACK_X, 50.0], [POOL_X, 60.0]]
	hero_spikes = [[POOL_X, 36.0, 130.0]]
	stalagmites = [[760.0, 34.0, 74.0], [1730.0, 46.0, 118.0], [1772.0, 22.0, 46.0], [2470.0, 38.0, 88.0], [2530.0, 20.0, 34.0]]
	fg_humps = [[60.0, 880.0, 200.0], [560.0, 920.0, 150.0], [1180.0, 960.0, 110.0], [1980.0, 930.0, 170.0], [2700.0, 950.0, 140.0], [3150.0, 860.0, 240.0]]
	fg_spikes = [[1320.0, 410.0, 46.0], [2440.0, 380.0, 38.0], [380.0, 360.0, 30.0]]
	sound_space = "home"
	entries = {"from_narrow": {"x": 2925.0, "facing": -1}, "from_alcove": {"x": 420.0, "facing": 1}, "from_dungeon": {"x": 1000.0, "facing": 1}, "from_beyond": {"x": 2760.0, "facing": -1}}
	exit_specs = [
		{"id": "east", "x0": 2962.0, "x1": 3020.0, "side": "right", "to_room": "narrow", "to_entry": "from_home"},
		{"id": "west", "x0": 296.0, "x1": 340.0, "side": "left", "to_room": "alcove", "to_entry": "from_home", "flag": FLAG_PASSAGE_OPEN},
	]


func _light_specs() -> Array:
	return [
		[Vector2(CRACK_X + 30, floor_y(CRACK_X) - 30), Color(0.62, 0.68, 0.8), 0.6, 2.4],
		[Vector2(CRACK_X, 330), Color(0.62, 0.68, 0.8), 0.35, 1.3],
		[Vector2(1000, floor_y(1000) - 24), Color(0.9, 0.64, 0.4), 0.32, 1.1],
		# The jar of caps over the nest: a soft night light.
		[Vector2(880, ceil_y(880) + 200), Color(0.7, 0.95, 0.9), 0.45, 1.5],
	]


func _add_props(parent: Node) -> void:
	passage = Passage.new()
	passage.position = Vector2(250, floor_y(250))
	passage.progress = int(WorldManager.get_flag(FLAG_PASSAGE_STONES, 0))
	parent.add_child(passage)
	var passage_i := _interactable(parent, "passage", Vector2(262, floor_y(262)), {"stand": 100.0, "hit": Vector2(200, 230), "hit_offset": Vector2(-10, -105), "prompt": Vector2(0, -230), "radius": 130.0})
	passage_i.dynamic_lines = _passage_lines
	passage_i.on_examined = _on_passage_examined

	tally = Tally.new()
	tally.position = Vector2(640, floor_y(640) - 165)
	parent.add_child(tally)
	var tally_i := _interactable(parent, "tally", Vector2(640, floor_y(640)), {"hit": Vector2(270, 200), "hit_offset": Vector2(0, -150), "prompt": Vector2(0, -260), "stand": 30.0})
	tally_i.dynamic_lines = _tally_lines

	# 0.7: the nest corner, made a home.
	var mat := HomeDecor.new()
	mat.kind = "mat"
	mat.position = Vector2(1000, floor_y(1000) + 6)
	parent.add_child(mat)
	var roots := HomeDecor.new()
	roots.kind = "roots"
	roots.position = Vector2(1010, ceil_y(1010) - 4)
	parent.add_child(roots)
	var jar := HomeDecor.new()
	jar.kind = "jar"
	jar.drop = 150.0
	jar.position = Vector2(880, ceil_y(880) - 4)
	parent.add_child(jar)
	shelf = HomeDecor.new()
	shelf.kind = "shelf"
	shelf.position = Vector2(SHELF_X, floor_y(SHELF_X) - SHELF_UP)
	shelf.books = _shelf_books()
	parent.add_child(shelf)
	var shelf_i := add_interactable(parent, "shelf", {"title": "OBJ_SHELF_TITLE", "first": [], "repeat": []}, Vector2(SHELF_X, floor_y(SHELF_X)),
		{"hit": Vector2(260, 150), "hit_offset": Vector2(-20, -SHELF_UP - 60), "prompt": Vector2(-60, -SHELF_UP - 170), "stand": 30.0})
	shelf_i.dynamic_lines = _shelf_lines
	if WorldManager.get_flag(FLAG_LAMP_BOOK, false):
		add_collectible(parent, "book_tales", Vector2(SHELF_X + 60, floor_y(SHELF_X) - SHELF_UP - 4),
			{"stand": 30.0, "hit": Vector2(90, 90), "hit_offset": Vector2(0, -SHELF_UP - 30), "prompt": Vector2(0, -SHELF_UP - 80)})
	if not WorldManager.item_added.is_connected(_on_item_added):
		WorldManager.item_added.connect(_on_item_added)
	for p in [mat, roots, jar, shelf]:
		queue_bake(p)

	var nest := Nest.new()
	nest.position = Vector2(1000, floor_y(1000))
	parent.add_child(nest)
	_interactable(parent, "nest", nest.position, {"stand": 50.0, "hit": Vector2(200, 110), "hit_offset": Vector2(0, -30), "prompt": Vector2(0, -60)})

	cairn = Cairn.new()
	cairn.position = Vector2(1290, floor_y(1290))
	cairn.stones = 8 if WorldManager.get_flag(FLAG_CAIRN_EIGHTH, false) else 7
	parent.add_child(cairn)
	var cairn_i := _interactable(parent, "cairn", cairn.position, {"stand": 64.0, "hit": Vector2(130, 150), "hit_offset": Vector2(0, -55), "prompt": Vector2(0, -130)})
	cairn_i.dynamic_lines = _cairn_lines
	cairn_i.on_examined = _on_cairn_examined

	var shaft := LightShaft.new()
	shaft.position = Vector2(CRACK_X, 150)
	shaft.length = floor_y(CRACK_X) - 150.0
	parent.add_child(shaft)
	_interactable(parent, "crack", Vector2(CRACK_X + 20, floor_y(CRACK_X)), {"stand": 40.0, "hit": Vector2(200, 520), "hit_offset": Vector2(0, -260), "prompt": Vector2(0, -200)})

	pool = Pool.new()
	pool.position = Vector2(POOL_X, floor_y(POOL_X))
	pool.drop_height = floor_y(POOL_X) - (ceil_y(POOL_X) + 120.0)
	parent.add_child(pool)
	_interactable(parent, "pool", pool.position, {"stand": 125.0, "radius": 150.0, "hit": Vector2(240, 120), "hit_offset": Vector2(0, -20), "prompt": Vector2(0, -70)})

	caps = PaleCaps.new()
	caps.position = Vector2(2290, floor_y(2290) + 2)
	parent.add_child(caps)
	var caps_i := _interactable(parent, "caps", caps.position, {"stand": 80.0, "hit": Vector2(170, 120), "hit_offset": Vector2(0, -35), "prompt": Vector2(0, -90)})
	caps_i.dynamic_lines = _caps_lines

	door = Door.new()
	door.position = Vector2(2830, floor_y(2830))
	door.is_open = TimeManager.is_complete()
	parent.add_child(door)
	var door_i := _interactable(parent, "door", door.position, {"stand": 0.0, "radius": 130.0, "hit": Vector2(260, 400), "hit_offset": Vector2(0, -190), "prompt": Vector2(0, -420)})
	door_i.dynamic_lines = _door_lines
	door_i.on_examined = _on_door_examined
	if not TimeManager.wait_completed.is_connected(_on_wait_completed):
		TimeManager.wait_completed.connect(_on_wait_completed)

	# Beside the door, the rock has split: a crack just wide enough.
	var crevice := TunnelMouth.new()
	crevice.style = "crevice"
	crevice.position = Vector2(3004, floor_y(3004))
	parent.add_child(crevice)

	for p in [passage, tally, nest, cairn, pool, caps, door, crevice]:
		queue_bake(p)


func _interactable(parent: Node, id: String, pos: Vector2, opts: Dictionary) -> Node2D:
	return add_interactable(parent, id, Texts.OBJECTS[id], pos, opts)


## Lines are Loc entries; "#KEY" entries pick a plural form at display time.
func _tally_lines(count: int) -> Array:
	var n: int = tally.mark_count()
	if count <= 1:
		return [Texts.OBJECTS["tally"]["first"][0], "OBJ_TALLY_ONLY_ONE" if n == 1 else ["#OBJ_TALLY_COUNT", n]]
	if n == 1:
		return ["OBJ_TALLY_STILL_ONE"]
	var options := [["#OBJ_TALLY_R1", n], ["OBJ_TALLY_R2", n]]
	return [options[count % options.size()]]


func _caps_lines(count: int) -> Array:
	if count <= 1:
		return Texts.OBJECTS["caps"]["first"]
	var visible: int = caps.visible_caps()
	if visible <= 6:
		return ["OBJ_CAPS_SAME"]
	if visible < 11:
		return ["OBJ_CAPS_MORE"]
	return ["OBJ_CAPS_SPREAD"]


## The door: its old words while closed; after four hundred days, the way on.
func _door_lines(count: int) -> Array:
	if door.is_open:
		if not WorldManager.get_flag(FLAG_DOOR_SEEN_OPEN, false):
			return ["OBJ_DOOR_OPEN_1", "OBJ_DOOR_OPEN_2", "OBJ_DOOR_OPEN_3"]
		return ["OBJ_DOOR_OPEN_R"]
	var data: Dictionary = Texts.OBJECTS["door"]
	if count <= 1:
		return data["first"]
	return [data["repeat"][(count - 2) % data["repeat"].size()]]


func _on_door_examined(_count: int) -> void:
	if not door.is_open:
		return
	WorldManager.set_flag(FLAG_DOOR_SEEN_OPEN, true)
	after_text(exit_reached.emit.bind("beyond", "from_door"))


func _on_wait_completed() -> void:
	door.open_now()
	AudioManager.play("rumble", -2.0, 0.5)
	await get_tree().create_timer(2.6).timeout
	if is_instance_valid(door) and door.baked:
		Baker.rebake(door)
	elif is_instance_valid(door):
		door.queue_redraw()


func _exit_tree() -> void:
	if TimeManager.wait_completed.is_connected(_on_wait_completed):
		TimeManager.wait_completed.disconnect(_on_wait_completed)
	if WorldManager.item_added.is_connected(_on_item_added):
		WorldManager.item_added.disconnect(_on_item_added)


## Books found stand on the shelf at home (the one being carried, too).
func _shelf_books() -> Array:
	var on: Array = []
	for id in Books.ORDER:
		on.append(WorldManager.is_collected(id))
	return on


func _shelf_lines(_count: int) -> Array:
	var n := 0
	for b in _shelf_books():
		n += 1 if b else 0
	if n == 0:
		return ["OBJ_SHELF_EMPTY"]
	if n < Books.ORDER.size():
		return ["OBJ_SHELF_SOME", ["OBJ_SHELF_COUNT", n, Books.ORDER.size()]]
	return ["OBJ_SHELF_FULL"]


func _on_item_added(item_id: String) -> void:
	if Books.is_book(item_id) and is_instance_valid(shelf):
		shelf.books = _shelf_books()
		if shelf.baked:
			Baker.rebake(shelf)
		else:
			shelf.queue_redraw()


## The old passage: one stone may be pulled away each (real) day.
func _passage_lines(count: int) -> Array:
	var stones := int(WorldManager.get_flag(FLAG_PASSAGE_STONES, 0))
	if WorldManager.get_flag(FLAG_PASSAGE_OPEN, false):
		return ["OBJ_PASSAGE_OPEN_R"]
	if _dug_today():
		return ["OBJ_PASSAGE_TOMORROW", ["OBJ_PASSAGE_COUNT", stones]]
	var lines: Array = ["OBJ_PASSAGE_1"] if count <= 1 else []
	lines.append("OBJ_PASSAGE_DIG")
	if stones + 1 >= Passage.STONES_TO_CLEAR:
		lines.append("OBJ_PASSAGE_OPENED")
	else:
		lines.append(["OBJ_PASSAGE_COUNT", stones + 1])
	return lines


func _dug_today() -> bool:
	var last: Variant = WorldManager.get_flag(FLAG_PASSAGE_LAST_DAY)
	return last != null and int(last) == TimeManager.day_index()


func _on_passage_examined(_count: int) -> void:
	if WorldManager.get_flag(FLAG_PASSAGE_OPEN, false) or _dug_today():
		return
	var stones := int(WorldManager.get_flag(FLAG_PASSAGE_STONES, 0)) + 1
	WorldManager.set_flag(FLAG_PASSAGE_STONES, stones)
	WorldManager.set_flag(FLAG_PASSAGE_LAST_DAY, TimeManager.day_index())
	AudioManager.play("rumble", -9.0, 1.5)
	if stones >= Passage.STONES_TO_CLEAR:
		WorldManager.set_flag(FLAG_PASSAGE_OPEN, true)
		refresh_exits()
	passage.progress = stones
	if passage.baked:
		Baker.rebake(passage)
	else:
		passage.queue_redraw()


## With the smooth stone from the Narrow Way, the cairn can be finished.
func _cairn_lines(count: int) -> Array:
	if WorldManager.get_flag(FLAG_CAIRN_EIGHTH, false):
		var r := ["OBJ_CAIRN_EIGHT_R1", "OBJ_CAIRN_EIGHT_R2"]
		return [r[count % r.size()]]
	if WorldManager.has_item("stone"):
		return ["OBJ_CAIRN_PLACE_1", "OBJ_CAIRN_PLACE_2"]
	var data: Dictionary = Texts.OBJECTS["cairn"]
	if count <= 1:
		return data["first"]
	return [data["repeat"][(count - 2) % data["repeat"].size()]]


func _on_cairn_examined(_count: int) -> void:
	if WorldManager.has_item("stone") and not WorldManager.get_flag(FLAG_CAIRN_EIGHTH, false):
		WorldManager.use_item("stone")
		WorldManager.set_flag(FLAG_CAIRN_EIGHTH, true)
		cairn.stones = 8
		if cairn.baked:
			Baker.rebake(cairn)
		else:
			cairn.queue_redraw()
