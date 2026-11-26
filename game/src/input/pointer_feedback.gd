class_name PointerFeedback
extends Node
## Mouse feedback (P1-23): highlights the entity under the cursor and sets the
## cursor shape for what a click would do. Only active once a real mouse has
## moved, so touch screens never see it. Reads state only.

enum CursorState { DEFAULT, SELECT, MOVE, ATTACK, PLACE_OK, PLACE_BAD }

const CURSOR_SHAPES: Dictionary = {
	CursorState.DEFAULT: Input.CURSOR_ARROW,
	CursorState.SELECT: Input.CURSOR_POINTING_HAND,
	CursorState.MOVE: Input.CURSOR_CROSS,
	CursorState.ATTACK: Input.CURSOR_HELP,       # shows the custom attack cursor
	CursorState.PLACE_OK: Input.CURSOR_CAN_DROP,
	CursorState.PLACE_BAD: Input.CURSOR_FORBIDDEN,
}
const UPDATE_EVERY_FRAMES: int = 3

var selection: SelectionController
var state: CursorState = CursorState.DEFAULT
var hovered_id: int = 0
var _hover_view: UnitView
var _last_mouse: Vector2 = Vector2(-1, -1)
var _frame: int = 0


func setup(selection_controller: SelectionController) -> void:
	name = "PointerFeedback"
	selection = selection_controller
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(_attack_cursor(), Input.CURSOR_HELP, Vector2(16, 16))


func _exit_tree() -> void:
	# Release the custom cursor before the renderer shuts down.
	if DisplayServer.get_name() != "headless":
		Input.set_custom_mouse_cursor(null, Input.CURSOR_HELP)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _process(_delta: float) -> void:
	_frame += 1
	if selection == null or not selection.rts_camera.edge_pan_enabled:
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	if mouse == _last_mouse and _frame % UPDATE_EVERY_FRAMES != 0:
		return
	_last_mouse = mouse
	update_at(mouse)


## Recomputes hover and cursor for a screen position.
func update_at(screen_pos: Vector2) -> void:
	var own: int = selection.pick_unit(screen_pos, true)
	var enemy: int = 0 if own != 0 else selection.pick_unit(screen_pos, false)
	_set_hover(own if own != 0 else enemy, enemy != 0)
	var new_state: CursorState = state_for(own, enemy)
	if new_state != state:
		state = new_state
		Input.set_default_cursor_shape(CURSOR_SHAPES[state])


## What a click would do with the current selection and mode.
func state_for(own_under: int, enemy_under: int) -> CursorState:
	var placement: PlacementController = selection.placement
	if placement != null and placement.active:
		return CursorState.PLACE_OK if placement.valid else CursorState.PLACE_BAD
	var armed: bool = selection.selected_any(func(e: SimEntity) -> bool: return not e.weapons.is_empty())
	if selection.attack_move_armed:
		return CursorState.ATTACK
	if enemy_under != 0 and armed:
		return CursorState.ATTACK
	if own_under != 0:
		return CursorState.SELECT
	if selection.selected_any(func(e: SimEntity) -> bool: return e.mover != null):
		return CursorState.MOVE
	return CursorState.DEFAULT


func _set_hover(id: int, enemy: bool) -> void:
	if id == hovered_id:
		return
	if _hover_view != null and is_instance_valid(_hover_view):
		_hover_view.set_hovered(false, false)
	hovered_id = id
	_hover_view = selection.game_view.get_view(id) if id != 0 else null
	if _hover_view != null:
		_hover_view.set_hovered(true, enemy)


## A red ring with a cross, drawn in code (no image file needed).
static func _attack_cursor() -> ImageTexture:
	var size: int = 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var red := Color(1.0, 0.25, 0.2)
	var c := Vector2(15.5, 15.5)
	for y: int in size:
		for x: int in size:
			var d: float = Vector2(x, y).distance_to(c)
			var on_ring: bool = d > 10.0 and d < 12.5
			var on_cross: bool = (absi(x - 15) <= 0 or absi(y - 15) <= 0) and d > 4.0 and d < 15.0
			if on_ring or on_cross:
				img.set_pixel(x, y, red)
	return ImageTexture.create_from_image(img)
