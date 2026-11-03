extends Node
## WorldManager — persistent world state and the registry of things in it.
##
## Holds story flags, how often each object has been examined, and where the
## creature was. Rooms register their interactables here; examining goes
## through [method examine] so counts, text, sound and saving stay in one place.

signal flag_changed(key: String, value: Variant)
signal object_examined(object_id: String, count: int)
signal item_added(item_id: String)
signal item_removed(item_id: String)
signal room_discovered(room_id: String)

var flags: Dictionary = {}
var examined: Dictionary = {}
## Items carried, in the order they were found.
var inventory: Array[String] = []
## item id → unix time it was picked up (stays after the item is used).
var collected: Dictionary = {}
## room id → unix time of the first visit.
var discovered: Dictionary = {}
## Items the player has not looked at in the satchel yet.
var unseen_items: Array[String] = []
var player_state: Dictionary = {}
var current_room: String = "home"
var player = null
var interactables: Array = []
## Horizontal ranges (Vector2(min_x, max_x)) where footsteps splash.
var wet_ranges: Array[Vector2] = []


func _ready() -> void:
	_load_state()
	SaveManager.before_save.connect(_on_before_save)
	SaveManager.data_reloaded.connect(_load_state)


func _load_state() -> void:
	flags = {}
	examined = {}
	inventory = []
	collected = {}
	discovered = {}
	unseen_items = []
	var world := SaveManager.get_section("world")
	var saved_flags: Variant = world.get("flags")
	if typeof(saved_flags) == TYPE_DICTIONARY:
		flags = saved_flags
	var saved_examined: Variant = world.get("examined")
	if typeof(saved_examined) == TYPE_DICTIONARY:
		for key in saved_examined:
			examined[str(key)] = maxi(0, int(saved_examined[key]))
	var saved_inv: Variant = world.get("inventory")
	if typeof(saved_inv) == TYPE_ARRAY:
		for id in saved_inv:
			if typeof(id) == TYPE_STRING and not inventory.has(id):
				inventory.append(id)
	collected = _times(world.get("collected"))
	discovered = _times(world.get("discovered"))
	var saved_unseen: Variant = world.get("unseen")
	if typeof(saved_unseen) == TYPE_ARRAY:
		for id in saved_unseen:
			if typeof(id) == TYPE_STRING and inventory.has(id):
				unseen_items.append(id)
	player_state = SaveManager.get_section("player")
	current_room = str(player_state.get("room", "home"))


## {id: unix time} from saved data, ignoring anything malformed.
func _times(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) == TYPE_DICTIONARY:
		for id in v:
			if typeof(v[id]) == TYPE_FLOAT or typeof(v[id]) == TYPE_INT:
				out[str(id)] = float(v[id])
	return out


func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)


func set_flag(key: String, value: Variant) -> void:
	flags[key] = value
	flag_changed.emit(key, value)


func examine_count(object_id: String) -> int:
	return int(examined.get(object_id, 0))


# --- Items and places -------------------------------------------------------

func has_item(item_id: String) -> bool:
	return inventory.has(item_id)


func is_collected(item_id: String) -> bool:
	return collected.has(item_id)


## Picks an item up (once per game). Returns false if it was already taken.
func collect(item_id: String) -> bool:
	if collected.has(item_id):
		return false
	collected[item_id] = Time.get_unix_time_from_system()
	inventory.append(item_id)
	unseen_items.append(item_id)
	item_added.emit(item_id)
	return true


## Gives an item up (placed somewhere in the world). It stays "collected".
func use_item(item_id: String) -> bool:
	if not inventory.has(item_id):
		return false
	inventory.erase(item_id)
	unseen_items.erase(item_id)
	item_removed.emit(item_id)
	return true


func mark_items_seen() -> void:
	unseen_items.clear()


## Records a visit. Returns true the first time the place is entered.
func enter_room(room_id: String) -> bool:
	current_room = room_id
	if discovered.has(room_id):
		return false
	discovered[room_id] = Time.get_unix_time_from_system()
	room_discovered.emit(room_id)
	return true


func register_player(p) -> void:
	player = p


func register_interactable(node: Node) -> void:
	if node not in interactables:
		interactables.append(node)


func unregister_interactable(node: Node) -> void:
	interactables.erase(node)


func clear_room() -> void:
	interactables.clear()
	wet_ranges.clear()


func is_wet(x: float) -> bool:
	for r in wet_ranges:
		if x >= r.x and x <= r.y:
			return true
	return false


## The interactable whose tap area contains [param world_pos], if any.
func find_interactable_at(world_pos: Vector2) -> Node:
	var best: Node = null
	var best_d := INF
	for node in interactables:
		if node.contains_point(world_pos):
			var d: float = node.global_position.distance_to(world_pos)
			if d < best_d:
				best_d = d
				best = node
	return best


func examine(target: Node) -> void:
	var id: String = target.object_id
	var count := examine_count(id) + 1
	examined[id] = count
	var lines: Array = target.get_examine_lines(count)
	UIManager.show_text(target.title, lines)
	target.ping()
	if target.on_examined.is_valid():
		target.on_examined.call(count)
	AudioManager.play("examine", -14.0, randf_range(0.97, 1.03), AudioManager.BUS_CHARACTER)
	object_examined.emit(id, count)
	SaveManager.save_now.call_deferred("examine")


## Where to place the creature when a room loads: the saved spot if it is
## valid for this room, otherwise [param default_pos].
## [param walkable] is Vector2(min_x, max_x). Returns {"x": float, "facing": int}.
func resolve_spawn(room_id: String, default_pos: Vector2, walkable: Vector2) -> Dictionary:
	var spawn := {"x": default_pos.x, "facing": 1}
	if str(player_state.get("room", "")) != room_id:
		return spawn
	var x: Variant = player_state.get("x")
	if (typeof(x) == TYPE_FLOAT or typeof(x) == TYPE_INT) and is_finite(float(x)):
		if float(x) >= walkable.x and float(x) <= walkable.y:
			spawn["x"] = float(x)
	spawn["facing"] = -1 if int(player_state.get("facing", 1)) < 0 else 1
	return spawn


func _on_before_save() -> void:
	if player != null and is_instance_valid(player) and player.is_inside_tree():
		player_state = {
			"room": current_room,
			"x": player.global_position.x,
			"y": player.global_position.y,
			"facing": player.facing,
		}
	SaveManager.set_section("world", {
		"flags": flags,
		"examined": examined,
		"inventory": inventory,
		"collected": collected,
		"discovered": discovered,
		"unseen": unseen_items,
	})
	SaveManager.set_section("player", player_state)
