extends RefCounted
## The map: every area, its name, and how to build it.
##   alcove ══ (old passage, dug out over 7 days) ══ home ── (crevice by the
##   door) ── narrow ── hall ══ (hidden) ══ garden
## Rooms from enabled mods hang off side passages in narrow / hall / garden.

const MOD_ROOM_PATH := "res://scripts/world/rooms/mod_room.gd"
const ORDER := ["home", "narrow", "hall", "garden", "alcove"]
const TITLES := {
	"alcove": "ROOM_ALCOVE",
	"home": "ROOM_HOME",
	"narrow": "ROOM_NARROW",
	"hall": "ROOM_HALL",
	"garden": "ROOM_GARDEN",
}
const PATHS := {
	"home": "res://scripts/world/cave_room.gd",
	"narrow": "res://scripts/world/rooms/narrow_way.gd",
	"hall": "res://scripts/world/rooms/echo_hall.gd",
	"garden": "res://scripts/world/rooms/still_garden.gd",
	"alcove": "res://scripts/world/rooms/scribes_alcove.gd",
}


static func exists(room_id: String) -> bool:
	return PATHS.has(room_id) or not _mod_def(room_id).is_empty()


static func create(room_id: String) -> Node2D:
	if not PATHS.has(room_id):
		var def := _mod_def(room_id)
		if not def.is_empty():
			var r: Node2D = load(MOD_ROOM_PATH).new()
			r.def = def
			r.room_id_full = room_id
			return r
	var path: String = PATHS.get(room_id, PATHS["home"])
	return load(path).new()


static func title(room_id: String) -> String:
	if TITLES.has(room_id):
		return TITLES[room_id]
	return str(_mod_def(room_id).get("title", ""))


## The game's places, then those of enabled mods.
static func all_ids() -> Array:
	var mm := _mods()
	return ORDER + (mm.room_ids() if mm != null else [])


## The ModManager autoload, looked up at run time so this script also compiles
## where autoloads are not registered (unit tests run with -s).
static func _mods() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("ModManager") if tree != null else null


static func _mod_def(room_id: String) -> Dictionary:
	var mm := _mods()
	return mm.room_def(room_id) if mm != null else {}
