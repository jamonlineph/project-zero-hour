class_name RadialMenu
extends Control
## Long-press menu (P1-24): a ring of big buttons around the point a finger
## held still on, with the orders that make sense for the selection there.
## Tapping a button runs it; tapping anywhere else closes the menu.

const RADIUS_PX: float = 96.0
const BUTTON_SIZE := Vector2(132, 56)

var at: Vector2 = Vector2.ZERO
var _buttons: Array[Button] = []


## Builds the menu for `selection` at screen position `pos`. Returns false
## (and frees itself) when no order applies.
func open(selection: SelectionController, pos: Vector2) -> bool:
	name = "RadialMenu"
	at = pos
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var entries: Array[Array] = entries_for(selection)
	if entries.is_empty():
		queue_free()
		return false
	var view: Vector2 = get_viewport().get_visible_rect().size
	for i: int in entries.size():
		var angle: float = -PI * 0.5 + TAU * float(i) / float(entries.size())
		var b := Button.new()
		b.text = entries[i][0]
		b.name = str(entries[i][0]).replace(" ", "")
		b.custom_minimum_size = BUTTON_SIZE
		b.size = BUTTON_SIZE
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		var center: Vector2 = pos + Vector2(cos(angle), sin(angle)) * RADIUS_PX
		b.position = (center - BUTTON_SIZE * 0.5).clamp(Vector2.ZERO, view - BUTTON_SIZE)
		var action: Callable = entries[i][1]
		b.pressed.connect(func() -> void:
			action.call()
			queue_free())
		add_child(b)
		_buttons.append(b)
	return true


## [label, action] pairs for the current selection, in ring order.
func entries_for(selection: SelectionController) -> Array[Array]:
	var out: Array[Array] = []
	var p: Vector2 = at
	var movers: bool = selection.selected_any(func(e: SimEntity) -> bool: return e.mover != null)
	var armed: bool = selection.selected_any(func(e: SimEntity) -> bool:
		return e.mover != null and not e.weapons.is_empty())
	var producers: bool = selection.selected_any(func(e: SimEntity) -> bool: return e.building != null)
	if armed:
		out.append(["Attack-move here", func() -> void: selection.order_attack_move(p)])
	if movers:
		out.append(["Move here", func() -> void: selection.order_move(p)])
		out.append(["Patrol here", func() -> void: selection.order_patrol(p)])
		out.append(["Stop", selection.order_stop])
		out.append(["Hold", selection.order_hold])
	var ward: int = selection.pick_own_entity(p) if armed else 0
	if ward != 0 and not selection.selected.has(ward):
		out.append(["Guard this", func() -> void: selection.order_guard(ward)])
	if producers:
		out.append(["Rally here", func() -> void: selection.order_rally(p)])
	return out


func button_labels() -> PackedStringArray:
	var labels: PackedStringArray = []
	for b: Button in _buttons:
		labels.append(b.text)
	return labels


func _gui_input(event: InputEvent) -> void:
	# A tap or click outside the buttons closes the menu.
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		accept_event()
		queue_free()
