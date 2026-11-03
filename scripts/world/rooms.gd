extends RefCounted
## The map: every area, its name, and how to build it.
##   home ── (crevice by the door) ── narrow ── hall ══ (hidden) ══ garden

const ORDER := ["home", "narrow", "hall", "garden"]
const TITLES := {
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
}


static func exists(room_id: String) -> bool:
	return PATHS.has(room_id)


static func create(room_id: String) -> Node2D:
	var path: String = PATHS.get(room_id, PATHS["home"])
	return load(path).new()
