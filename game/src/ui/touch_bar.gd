class_name TouchBar
extends HBoxContainer
## Touch buttons (P1-24) along the bottom edge, next to the minimap:
## - Clear: deselect everything.
## - Box: while on, a one-finger drag box-selects instead of panning.
## - 1–5: control groups. Tap selects (tap twice quickly to jump the camera);
##   hold for HOLD_SEC to store the current selection in that group.
## Shown on every device; mouse users can use them too.

const GROUPS: int = 5
const HOLD_SEC: float = 0.5
const BUTTON_SIZE := Vector2(64, 56)

var selection: SelectionController
var box_toggle: Button
var group_buttons: Array[Button] = []
var _press_ms: Dictionary[int, int] = {}   ## group -> press time, while held


func setup(selection_controller: SelectionController) -> void:
	name = "TouchBar"
	selection = selection_controller
	add_theme_constant_override("separation", 6)
	var clear := _make("Clear", "Deselect all")
	clear.name = "Clear"
	clear.pressed.connect(func() -> void: selection.select_ids([]))
	box_toggle = _make("Box", "One-finger drag selects instead of panning")
	box_toggle.name = "BoxToggle"
	box_toggle.toggle_mode = true
	box_toggle.toggled.connect(func(on: bool) -> void: selection.touch.box_mode = on)
	for n: int in range(1, GROUPS + 1):
		var b := _make(str(n), Loc.t("Tap: select group %d. Hold: store the selection as group %d") % [n, n])
		b.name = "Group%d" % n
		b.button_down.connect(func() -> void: _press_ms[n] = Time.get_ticks_msec())
		b.button_up.connect(func() -> void: release_group(n, Time.get_ticks_msec()))
		group_buttons.append(b)
	selection.selection_changed.connect(func(_ids: Array[int]) -> void: refresh())
	refresh()


## Finishes a press on group button n: a long hold stores, a short tap selects.
func release_group(n: int, now_ms: int) -> void:
	var held_ms: int = now_ms - _press_ms.get(n, now_ms)
	_press_ms.erase(n)
	var store: bool = held_ms >= int(HOLD_SEC * 1000.0)
	selection.groups.use_group(n, store, false, selection, now_ms)
	refresh()


## Shows how many living units each group has.
func refresh() -> void:
	if selection == null:
		return
	for i: int in group_buttons.size():
		var n: int = i + 1
		var count: int = selection.groups.members(n, selection.runner.world).size()
		group_buttons[i].text = "%d" % n if count == 0 else "%d\n(%d)" % [n, count]


func _make(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = BUTTON_SIZE
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	add_child(b)
	return b
