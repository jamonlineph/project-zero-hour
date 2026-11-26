class_name ControlGroups
extends RefCounted
## Control groups 1–9 (P1-23): Ctrl+N stores the selection, N recalls it,
## Shift+N adds the group to the selection, and pressing N twice quickly
## jumps the camera to the group. Pure logic, so it is easy to test; the
## SelectionController feeds it key presses and reads the results.

const DOUBLE_TAP_MS: int = 350

var _groups: Dictionary[int, Array] = {}
var _last_group: int = 0
var _last_ms: int = -100000


## Stores `ids` as group n (1–9), replacing what was there.
func assign(n: int, ids: Array[int]) -> void:
	var copy: Array[int] = ids.duplicate()
	copy.sort()
	_groups[n] = copy


## Group n without entities that no longer exist in `world`.
func members(n: int, world: SimWorld) -> Array[int]:
	var out: Array[int] = []
	for id: int in _groups.get(n, []):
		if world.entities.has(id):
			out.append(id)
	return out


## Records a recall of group n at time now_ms and reports whether it was a
## double tap (the same group within DOUBLE_TAP_MS), which jumps the camera.
func recall(n: int, now_ms: int) -> bool:
	var double: bool = n == _last_group and now_ms - _last_ms <= DOUBLE_TAP_MS
	_last_group = n
	_last_ms = now_ms
	return double


func has_group(n: int) -> bool:
	return not (_groups.get(n, []) as Array).is_empty()


## Average ground position of the group's living members, in meters
## (Godot x/z), or null if none are left.
func center(n: int, world: SimWorld) -> Variant:
	var ids: Array[int] = members(n, world)
	if ids.is_empty():
		return null
	var sx: float = 0.0
	var sz: float = 0.0
	for id: int in ids:
		var e: SimEntity = world.entities[id]
		sx += Fx.to_float(e.x)
		sz += Fx.to_float(e.y)
	return Vector3(sx / ids.size(), 0.0, sz / ids.size())


## Handles a number-key press for `selection`. Returns true if it used it.
func handle_key(key: InputEventKey, selection: SelectionController) -> bool:
	if not key.pressed or key.echo:
		return false
	var n: int = group_for_key(key.physical_keycode)
	if n == 0:
		return false
	use_group(n, key.ctrl_pressed or key.meta_pressed, key.shift_pressed, selection, Time.get_ticks_msec())
	return true


## Ctrl: store the selection as group n. Shift: add group n to the selection.
## Neither: select group n, and jump the camera to it on a double tap.
func use_group(n: int, store: bool, add: bool, selection: SelectionController, now_ms: int) -> void:
	var world: SimWorld = selection.runner.world
	if store:
		assign(n, selection.selected)
		return
	var ids: Array[int] = members(n, world)
	if ids.is_empty():
		return
	selection.select_ids(ids, add)
	if recall(n, now_ms) and not add:
		var c: Variant = center(n, world)
		if c != null:
			selection.rts_camera.focus_on(c)


## 1–9 for the number keys (top row and keypad), 0 for anything else.
static func group_for_key(keycode: Key) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_0
	if keycode >= KEY_KP_1 and keycode <= KEY_KP_9:
		return keycode - KEY_KP_0
	return 0
