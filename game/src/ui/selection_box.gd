class_name SelectionBox
extends Control
## Draws the drag-selection rectangle. Never takes input itself.

const FILL := Color(0.3, 0.9, 0.4, 0.15)
const EDGE := Color(0.3, 0.9, 0.4, 0.9)

var _rect: Rect2 = Rect2()
var _active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_box(rect: Rect2) -> void:
	_rect = rect
	_active = true
	queue_redraw()


func hide_box() -> void:
	_active = false
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	draw_rect(_rect, FILL, true)
	draw_rect(_rect, EDGE, false, 2.0)
