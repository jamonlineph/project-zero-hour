class_name TouchGestures
extends RefCounted
## Touch gestures for the SelectionController (moved out of it in P1-24).
##
## - Tap your unit: select it. Tap an enemy: attack. Tap ground: move.
## - One-finger drag pans. Hold still for HOLD_FOR_BOX_SEC, then drag: box
##   select. With box mode on, every one-finger drag box-selects.
## - Hold still for LONG_PRESS_SEC without moving: long_pressed (the HUD opens
##   the radial menu there).
## - Double-tap a unit: select all of that type on screen.
## - Two fingers: pinch zooms, twist rotates, drag pans.

const DRAG_THRESHOLD_PX: float = 10.0
const HOLD_FOR_BOX_SEC: float = 0.35
const LONG_PRESS_SEC: float = 0.6

## When true, a one-finger drag selects instead of panning (HUD toggle).
var box_mode: bool = false

var _sel: SelectionController
var _touches: Dictionary[int, Vector2] = {}   ## finger index -> position
var _start: Vector2 = Vector2.ZERO
var _start_ms: int = 0
var _moved: bool = false
var _box: bool = false
var _pinch_dist: float = 0.0
var _pinch_angle: float = 0.0
var _pinch_mid: Vector2 = Vector2.ZERO


func _init(selection: SelectionController) -> void:
	_sel = selection


func touch_count() -> int:
	return _touches.size()


## Called every frame: fires a long press once a single finger has stayed
## still long enough. Returns the press position, or null.
func poll_long_press(now_ms: int) -> Variant:
	if _touches.size() != 1 or _moved:
		return null
	if now_ms - _start_ms < int(LONG_PRESS_SEC * 1000.0):
		return null
	_moved = true   # consumed: releasing the finger is not a tap
	return _start


func on_touch(st: InputEventScreenTouch, now_ms: int) -> void:
	if st.pressed:
		_touches[st.index] = st.position
		if _touches.size() == 1:
			_start = st.position
			_start_ms = now_ms
			_moved = false
			_box = false
			if st.double_tap:
				var hit: int = _sel.pick_unit(st.position, true)
				if hit != 0:
					_sel.select_same_type_on_screen(hit)
					_moved = true   # consumed; not a tap
		elif _touches.size() == 2:
			_moved = true       # a second finger cancels the tap
			_box = false
			_sel.box_overlay.hide_box()
			_begin_pinch()
		return
	var was_single: bool = _touches.size() == 1
	_touches.erase(st.index)
	if was_single:
		if _box:
			_sel.box_select(Rect2(_start, st.position - _start).abs())
			_sel.box_overlay.hide_box()
		elif not _moved:
			tap(st.position)
	elif _touches.size() == 1:
		# Two fingers became one: continue as a pan, never as a tap.
		_start = _touches.values()[0]
		_moved = true
		_box = false


func on_drag(sd: InputEventScreenDrag, now_ms: int) -> void:
	_touches[sd.index] = sd.position
	if _touches.size() == 1:
		if not _moved and sd.position.distance_to(_start) > DRAG_THRESHOLD_PX:
			_moved = true
			_box = box_mode or now_ms - _start_ms >= int(HOLD_FOR_BOX_SEC * 1000.0)
		if _moved:
			if _box:
				_sel.box_overlay.show_box(Rect2(_start, sd.position - _start).abs())
			else:
				_sel.rts_camera.pan_screen(sd.relative)
	elif _touches.size() == 2:
		_update_pinch()


func tap(pos: Vector2) -> void:
	if _sel.handle_armed_click(pos):
		return
	var hit: int = _sel.pick_unit(pos, true)
	if hit != 0:
		_sel.select_ids([hit])
	elif not _sel.selected.is_empty():
		_sel.order_at(pos)


func _begin_pinch() -> void:
	var pts: Array = _touches.values()
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	_pinch_dist = a.distance_to(b)
	_pinch_angle = (b - a).angle()
	_pinch_mid = (a + b) * 0.5


func _update_pinch() -> void:
	var pts: Array = _touches.values()
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	var dist: float = a.distance_to(b)
	var angle: float = (b - a).angle()
	var mid: Vector2 = (a + b) * 0.5
	var cam: RtsCamera = _sel.rts_camera
	if _pinch_dist > 1.0 and dist > 1.0:
		cam.zoom_by(_pinch_dist / dist)
	cam.rotate_by(angle_difference(_pinch_angle, angle))
	cam.pan_screen(mid - _pinch_mid)
	_pinch_dist = dist
	_pinch_angle = angle
	_pinch_mid = mid
