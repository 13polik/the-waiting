extends RefCounted
## What the creature was doing while the player was away (0.8). When the game
## is opened after at least [constant MIN_AWAY] seconds, one activity is picked
## (from these and those of enabled mods): the creature is found where it did
## it, and a short line says what it was. Purely what happened — it never
## hurries anything along (no pages read, no stones moved).

const MIN_AWAY := 1800.0
## text, room ("" = anywhere), x (where it is found), needs_item / needs_flag.
const ACTIVITIES := [
	{"text": "AWAY_NEST", "room": "home", "x": 1000.0},
	{"text": "AWAY_TALLY", "room": "home", "x": 660.0},
	{"text": "AWAY_POOL", "room": "home", "x": 1760.0},
	{"text": "AWAY_DOOR", "room": "home", "x": 2700.0},
	{"text": "AWAY_CAPS", "room": "home", "x": 2200.0},
	{"text": "AWAY_CAIRN", "room": "home", "x": 1360.0},
	{"text": "AWAY_SHELF", "room": "home", "x": 1130.0, "needs_any_book": true},
	{"text": "AWAY_READ", "room": "home", "x": 1060.0, "needs_any_book": true},
	{"text": "AWAY_DARK", "room": ""},
	{"text": "AWAY_LISTEN", "room": ""},
	{"text": "AWAY_CHIMES", "room": "hall", "x": 980.0},
	{"text": "AWAY_MOSS", "room": "garden", "x": 760.0},
	{"text": "AWAY_DUST", "room": "narrow", "x": 1250.0},
	{"text": "AWAY_DESK", "room": "alcove", "x": 1000.0},
]
const BOOK_IDS := ["book_door", "book_herbs", "book_tales"]


## One activity for coming back to [param room_id], or {} (too short an
## absence, or nothing fits). [param seed] varies the choice from day to day.
static func pick(room_id: String, away_seconds: float, extra: Array, seed: int) -> Dictionary:
	if away_seconds < MIN_AWAY:
		return {}
	var pool: Array = []
	for a in ACTIVITIES + extra:
		if not str(a.get("room", "")).is_empty() and a["room"] != room_id:
			continue
		if a.get("needs_any_book", false) and not _has_any_book():
			continue
		var need := str(a.get("needs_item", ""))
		if not need.is_empty() and not _wm().has_item(need):
			continue
		pool.append(a)
	if pool.is_empty():
		return {}
	return pool[absi(seed) % pool.size()]


static func all_keys() -> Array:
	var keys: Array = ["AWAY_TITLE"]
	for a in ACTIVITIES:
		keys.append(a["text"])
	return keys


static func _has_any_book() -> bool:
	for id in BOOK_IDS:
		if _wm().has_item(id):
			return true
	return false


## WorldManager, looked up at run time (unit tests run without autoloads).
static func _wm() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("WorldManager")
