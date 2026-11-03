extends RefCounted
## Registers input actions in code, keeping project.godot readable and leaving
## room for a remapping screen later. Touch input is handled by WorldInput.

const BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"interact": [KEY_E, KEY_SPACE, KEY_ENTER],
	"pause": [KEY_ESCAPE, KEY_P],
	"inventory": [KEY_I, KEY_TAB],
	"debug_overlay": [KEY_F3],
	"debug_add_day": [KEY_F5],
	"debug_add_hour": [KEY_F6],
	"debug_save": [KEY_F8],
}


static func register() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: int in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
