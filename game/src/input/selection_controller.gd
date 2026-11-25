class_name SelectionController
extends Node
## Turns pointer input (mouse, trackpad and touch) into selection changes and
## SimCommands. Selection is local UI state; only commands reach the sim.
##
## Mouse: left-click select, left-drag box select (Shift adds), right-click
## move, S stop.
## Touch: tap your unit to select it, tap ground to move the selection,
## one-finger drag pans, hold still then drag for box select, double-tap a unit
## to select all of that type on screen, two fingers zoom, rotate and pan.
## See docs/design/controls-and-ui.md.

signal selection_changed(ids: Array[int])

const DRAG_THRESHOLD_PX: float = 10.0
const LONG_PRESS_SEC: float = 0.35
const MIN_PICK_RADIUS_PX: float = 28.0

var runner: SimRunner
var game_view: GameView
var rts_camera: RtsCamera
var box_overlay: SelectionBox
var local_player_id: int = 1
var selected: Array[int] = []

var _mouse_down: bool = false
var _mouse_dragging: bool = false
var _mouse_start: Vector2 = Vector2.ZERO

var _touches: Dictionary[int, Vector2] = {}   ## finger index -> position
var _touch_start: Vector2 = Vector2.ZERO
var _touch_start_ms: int = 0
var _touch_moved: bool = false
var _touch_box: bool = false
var _pinch_dist: float = 0.0
var _pinch_angle: float = 0.0
var _pinch_mid: Vector2 = Vector2.ZERO


func setup(sim_runner: SimRunner, view: GameView, cam: RtsCamera, overlay: SelectionBox, player_id: int) -> void:
	runner = sim_runner
	game_view = view
	rts_camera = cam
	box_overlay = overlay
	local_player_id = player_id


func _process(_delta: float) -> void:
	_prune_selection()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventScreenTouch:
		_on_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_drag(event as InputEventScreenDrag)
	elif event.is_action_pressed("cmd_stop"):
		order_stop()


# --- Public actions (also used by tests and, later, HUD buttons) ---

func select_ids(ids: Array[int], additive: bool = false) -> void:
	var result: Array[int] = []
	if additive:
		result = selected.duplicate()
	for id: int in ids:
		if not result.has(id):
			result.append(id)
	result.sort()
	_set_selection(result)


func box_select(rect: Rect2, additive: bool = false) -> void:
	var ids: Array[int] = []
	for id: int in _own_ids():
		var sp: Variant = _screen_pos(id)
		if sp != null and rect.has_point(sp):
			ids.append(id)
	select_ids(ids, additive)


## Moves the current selection to the ground point under a screen position.
func order_move(screen_pos: Vector2) -> void:
	if selected.is_empty():
		return
	var ground: Variant = rts_camera.screen_to_ground(screen_pos)
	if ground == null:
		return
	var point: Vector3 = ground
	runner.submit(SimCommand.make_move(selected, Fx.from_float(point.x), Fx.from_float(point.z)))
	game_view.show_move_marker(point)


func order_stop() -> void:
	if not selected.is_empty():
		runner.submit(SimCommand.make_stop(selected))


# --- Mouse ---

func _on_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_mouse_down = true
			_mouse_dragging = false
			_mouse_start = mb.position
		elif _mouse_down:
			_mouse_down = false
			box_overlay.hide_box()
			if _mouse_dragging:
				box_select(Rect2(_mouse_start, mb.position - _mouse_start).abs(), mb.shift_pressed)
			else:
				var hit: int = _pick_own_unit(mb.position)
				if mb.double_click and hit != 0:
					_select_same_type_on_screen(hit)
				elif hit != 0:
					select_ids([hit], mb.shift_pressed)
				elif not mb.shift_pressed:
					select_ids([])
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		order_move(mb.position)


func _on_mouse_motion(mm: InputEventMouseMotion) -> void:
	if not _mouse_down:
		return
	if not _mouse_dragging and mm.position.distance_to(_mouse_start) > DRAG_THRESHOLD_PX:
		_mouse_dragging = true
	if _mouse_dragging:
		box_overlay.show_box(Rect2(_mouse_start, mm.position - _mouse_start).abs())


# --- Touch ---

func _on_touch(st: InputEventScreenTouch) -> void:
	if st.pressed:
		_touches[st.index] = st.position
		if _touches.size() == 1:
			_touch_start = st.position
			_touch_start_ms = Time.get_ticks_msec()
			_touch_moved = false
			_touch_box = false
			if st.double_tap:
				var hit: int = _pick_own_unit(st.position)
				if hit != 0:
					_select_same_type_on_screen(hit)
					_touch_moved = true   # consumed; not a tap
		elif _touches.size() == 2:
			_touch_moved = true       # a second finger cancels the tap
			_touch_box = false
			box_overlay.hide_box()
			_begin_pinch()
		return
	var was_single: bool = _touches.size() == 1
	_touches.erase(st.index)
	if was_single:
		if _touch_box:
			box_select(Rect2(_touch_start, st.position - _touch_start).abs())
			box_overlay.hide_box()
		elif not _touch_moved:
			_tap(st.position)
	elif _touches.size() == 1:
		# Two fingers became one: continue as a pan, never as a tap.
		_touch_start = _touches.values()[0]
		_touch_moved = true
		_touch_box = false


func _on_drag(sd: InputEventScreenDrag) -> void:
	_touches[sd.index] = sd.position
	if _touches.size() == 1:
		if not _touch_moved and sd.position.distance_to(_touch_start) > DRAG_THRESHOLD_PX:
			_touch_moved = true
			_touch_box = Time.get_ticks_msec() - _touch_start_ms >= int(LONG_PRESS_SEC * 1000.0)
		if _touch_moved:
			if _touch_box:
				box_overlay.show_box(Rect2(_touch_start, sd.position - _touch_start).abs())
			else:
				rts_camera.pan_screen(sd.relative)
	elif _touches.size() == 2:
		_update_pinch()


func _tap(pos: Vector2) -> void:
	var hit: int = _pick_own_unit(pos)
	if hit != 0:
		select_ids([hit])
	elif not selected.is_empty():
		order_move(pos)


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
	if _pinch_dist > 1.0 and dist > 1.0:
		rts_camera.zoom_by(_pinch_dist / dist)
	rts_camera.rotate_by(angle_difference(_pinch_angle, angle))
	rts_camera.pan_screen(mid - _pinch_mid)
	_pinch_dist = dist
	_pinch_angle = angle
	_pinch_mid = mid


# --- Helpers ---

func _own_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in runner.world.entity_ids:
		if runner.world.entities[id].player_id == local_player_id:
			ids.append(id)
	return ids


func _screen_pos(entity_id: int) -> Variant:
	var v: UnitView = game_view.get_view(entity_id)
	if v == null or rts_camera.camera.is_position_behind(v.global_position):
		return null
	return rts_camera.camera.unproject_position(v.global_position)


func _pick_radius_px() -> float:
	return maxf(MIN_PICK_RADIUS_PX, get_viewport().get_visible_rect().size.y * 0.045)


## Own unit nearest to a screen position, within the pick radius, or 0.
func _pick_own_unit(screen_pos: Vector2) -> int:
	var best_id: int = 0
	var best_dist: float = _pick_radius_px()
	for id: int in _own_ids():
		var sp: Variant = _screen_pos(id)
		if sp == null:
			continue
		var d: float = (sp as Vector2).distance_to(screen_pos)
		if d < best_dist:
			best_dist = d
			best_id = id
	return best_id


func _select_same_type_on_screen(entity_id: int) -> void:
	var def_id: String = runner.world.entities[entity_id].def_id
	var rect: Rect2 = get_viewport().get_visible_rect()
	var ids: Array[int] = []
	for id: int in _own_ids():
		if runner.world.entities[id].def_id != def_id:
			continue
		var sp: Variant = _screen_pos(id)
		if sp != null and rect.has_point(sp):
			ids.append(id)
	select_ids(ids)


func _set_selection(ids: Array[int]) -> void:
	for id: int in selected:
		var v: UnitView = game_view.get_view(id)
		if v != null:
			v.set_selected(false)
	selected = ids
	for id: int in selected:
		var v: UnitView = game_view.get_view(id)
		if v != null:
			v.set_selected(true)
	selection_changed.emit(selected)


## Drops ids of entities that no longer exist (for example after they die).
func _prune_selection() -> void:
	var alive: Array[int] = []
	for id: int in selected:
		if runner.world.entities.has(id):
			alive.append(id)
	if alive.size() != selected.size():
		_set_selection(alive)
