class_name InputActions
extends RefCounted
## Registers keyboard input actions in code (not in project.godot), so they are
## easy to read and review. Rebinding comes with the settings menu (P1-35).
##
## Arrow keys move the camera, which keeps letter keys free for command hotkeys
## (docs/design/controls-and-ui.md).

const BINDINGS: Dictionary = {
	"cam_left": [KEY_LEFT],
	"cam_right": [KEY_RIGHT],
	"cam_forward": [KEY_UP],
	"cam_back": [KEY_DOWN],
	"cam_rotate_left": [KEY_COMMA],
	"cam_rotate_right": [KEY_PERIOD],
	"cam_zoom_in": [KEY_EQUAL],
	"cam_zoom_out": [KEY_MINUS],
	"cmd_stop": [KEY_S],
	"cmd_attack_move": [KEY_A],
	"cmd_hold": [KEY_H],
	"toggle_help": [KEY_F1],
}


## Safe to call more than once.
static func register() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for keycode: Key in BINDINGS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
