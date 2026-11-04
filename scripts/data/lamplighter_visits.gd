extends RefCounted
## The Lamplighter (0.7): an old, tall creature with a lantern on a pole who
## walks the tunnels tending the lights of those who wait. Twelve meetings
## spread over the four hundred days, each in a given place from a given day
## on. One meeting a day at most; the next waits until the previous is done.
## Pure data — the logic lives in scripts/world/props/lamplighter.gd.

## day: first day (TimeManager.day_index) it can happen; room; x; lines;
## "needs": a WorldManager flag that must be set; "complete": only after the wait.
const VISITS := [
	{"day": 1, "room": "narrow", "x": 900.0, "lines": ["LAMP_1_1", "LAMP_1_2", "LAMP_1_3"]},
	{"day": 3, "room": "hall", "x": 1080.0, "lines": ["LAMP_2_1", "LAMP_2_2", "LAMP_2_3"]},
	{"day": 6, "room": "home", "x": 2600.0, "lines": ["LAMP_3_1", "LAMP_3_2", "LAMP_3_3"]},
	{"day": 10, "room": "garden", "x": 1420.0, "lines": ["LAMP_4_1", "LAMP_4_2", "LAMP_4_3"]},
	{"day": 15, "room": "alcove", "x": 830.0, "needs": "passage_open", "lines": ["LAMP_5_1", "LAMP_5_2", "LAMP_5_3"]},
	{"day": 30, "room": "hall", "x": 1080.0, "lines": ["LAMP_6_1", "LAMP_6_2"]},
	{"day": 60, "room": "narrow", "x": 900.0, "lines": ["LAMP_7_1", "LAMP_7_2"]},
	{"day": 100, "room": "home", "x": 2600.0, "lines": ["LAMP_8_1", "LAMP_8_2", "LAMP_8_3"]},
	{"day": 150, "room": "garden", "x": 1420.0, "lines": ["LAMP_9_1", "LAMP_9_2"]},
	{"day": 200, "room": "hall", "x": 1080.0, "lines": ["LAMP_10_1", "LAMP_10_2"]},
	{"day": 300, "room": "home", "x": 2600.0, "lines": ["LAMP_11_1", "LAMP_11_2", "LAMP_11_3"]},
	{"day": 399, "room": "beyond", "x": 2450.0, "complete": true, "lines": ["LAMP_12_1", "LAMP_12_2", "LAMP_12_3"]},
]
## After this meeting (index) a book is left on the shelf at home.
const BOOK_AFTER := 3
## After this meeting the Scribe's lantern burns again.
const RELIGHT_AFTER := 4


static func all_keys() -> Array:
	var keys: Array = ["LAMP_TITLE", "LAMP_GONE"]
	for v in VISITS:
		keys.append_array(v["lines"])
	return keys
