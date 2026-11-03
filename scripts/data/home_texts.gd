extends RefCounted
## Examine text for the home cave, as translation keys (the text itself is in
## localization/strings.csv). "first" plays on the first examination; after
## that one "repeat" line is shown each time, in order. The tally and the pale
## caps build lines that depend on real days passed (see cave_room.gd).

const OBJECTS := {
	"nest": {
		"title": "OBJ_NEST_TITLE",
		"first": ["OBJ_NEST_1", "OBJ_NEST_2"],
		"repeat": ["OBJ_NEST_R1", "OBJ_NEST_R2", "OBJ_NEST_R3"],
	},
	"cairn": {
		"title": "OBJ_CAIRN_TITLE",
		"first": ["OBJ_CAIRN_1", "OBJ_CAIRN_2"],
		"repeat": ["OBJ_CAIRN_R1", "OBJ_CAIRN_R2", "OBJ_CAIRN_R3"],
	},
	"passage": {
		"title": "OBJ_PASSAGE_TITLE",
		"first": ["OBJ_PASSAGE_1", "OBJ_PASSAGE_2"],
		"repeat": ["OBJ_PASSAGE_R1", "OBJ_PASSAGE_R2", "OBJ_PASSAGE_R3"],
	},
	"tally": {
		"title": "OBJ_TALLY_TITLE",
		"first": ["OBJ_TALLY_1"],
		"repeat": [],
	},
	"crack": {
		"title": "OBJ_CRACK_TITLE",
		"first": ["OBJ_CRACK_1", "OBJ_CRACK_2"],
		"repeat": ["OBJ_CRACK_R1", "OBJ_CRACK_R2", "OBJ_CRACK_R3"],
	},
	"pool": {
		"title": "OBJ_POOL_TITLE",
		"first": ["OBJ_POOL_1", "OBJ_POOL_2"],
		"repeat": ["OBJ_POOL_R1", "OBJ_POOL_R2", "OBJ_POOL_R3"],
	},
	"caps": {
		"title": "OBJ_CAPS_TITLE",
		"first": ["OBJ_CAPS_1", "OBJ_CAPS_2"],
		"repeat": [],
	},
	"door": {
		"title": "OBJ_DOOR_TITLE",
		"first": ["OBJ_DOOR_1", "OBJ_DOOR_2", "OBJ_DOOR_3"],
		"repeat": ["OBJ_DOOR_R1", "OBJ_DOOR_R2", "OBJ_DOOR_R3"],
	},
}
