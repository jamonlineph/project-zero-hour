class_name SelectionController
extends Node
## Turns pointer input (mouse, trackpad and touch) into selection changes and
## SimCommands. Selection is local UI state; only commands reach the sim.
##
## Mouse: left-click select, left-drag box select (Shift adds), right-click
## move (or attack, on an enemy), A then left-click attack-move, H hold, S stop.
## Touch: tap your unit to select it, tap an enemy to attack it, tap ground to
## move the selection,
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

## True after pressing A: the next left-click is an attack-move target.
var attack_move_armed: bool = false
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
	elif event.is_action_pressed("cmd_hold"):
		order_hold()
	elif event.is_action_pressed("cmd_attack_move") and not selected.is_empty():
		attack_move_armed = true
	elif event.is_action_pressed("debug_build_power"):
		debug_build(["microreactor", "power_plant", "power_station"], get_viewport().get_mouse_position())
	elif event.is_action_pressed("debug_build_barracks"):
		debug_build(["barracks"], get_viewport().get_mouse_position())
	elif event.is_action_pressed("debug_build_hub"):
		debug_build(["logistics_hub"], get_viewport().get_mouse_position())
	elif event.is_action_pressed("debug_build_vehicles"):
		debug_build(["vehicle_depot", "vehicle_plant", "vehicle_factory"], get_viewport().get_mouse_position())
	elif event.is_action_pressed("debug_produce"):
		debug_produce()


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


func order_hold() -> void:
	if not selected.is_empty():
		runner.submit(SimCommand.make_hold(selected))


func order_attack(target_id: int) -> void:
	if not selected.is_empty():
		runner.submit(SimCommand.make_attack(selected, target_id))


## Attack-move: drive to the ground point, fighting anything met on the way.
func order_attack_move(screen_pos: Vector2) -> void:
	attack_move_armed = false
	if selected.is_empty():
		return
	var ground: Variant = rts_camera.screen_to_ground(screen_pos)
	if ground == null:
		return
	var point: Vector3 = ground
	runner.submit(SimCommand.make_attack_move(selected, Fx.from_float(point.x), Fx.from_float(point.z)))
	game_view.show_move_marker(point)


## Right-click / tap on a point. In order of preference: attack a visible
## enemy there; send gatherers to a supply site; send builders to finish or
## repair one of our buildings; set the rally point when only buildings are
## selected; otherwise move.
func order_at(screen_pos: Vector2) -> void:
	var world: SimWorld = runner.world
	var enemy: int = _pick_unit(screen_pos, false)
	if enemy != 0:
		order_attack(enemy)
		return
	var site: int = _pick(screen_pos, func(e: SimEntity) -> bool: return e.supply != null)
	if site != 0 and _selected_any(func(e: SimEntity) -> bool: return e.gatherer != null):
		runner.submit(SimCommand.make_gather(selected, site))
		return
	var own_building: int = _pick(screen_pos, func(e: SimEntity) -> bool:
		return e.building != null and e.player_id == local_player_id)
	if own_building != 0 and _selected_any(func(e: SimEntity) -> bool: return e.builder != null):
		runner.submit(SimCommand.make_repair(selected, own_building))
		return
	if not selected.is_empty() and not _selected_any(func(e: SimEntity) -> bool: return e.mover != null):
		var ground: Variant = rts_camera.screen_to_ground(screen_pos)
		if ground != null:
			var point: Vector3 = ground
			for id: int in selected:
				if world.entities.has(id) and world.entities[id].building != null:
					runner.submit(SimCommand.make_rally(id, Fx.from_float(point.x), Fx.from_float(point.z)))
			game_view.show_move_marker(point)
		return
	order_move(screen_pos)


## Places a building of the player's faction whose id ends with one of the
## suffixes, centered under the cursor, using the selected builders.
func debug_build(suffixes: PackedStringArray, screen_pos: Vector2) -> void:
	var world: SimWorld = runner.world
	if world.content == null:
		return
	var faction: String = world.get_player(local_player_id).faction
	var building_id: String = ""
	for suffix: String in suffixes:
		if world.content.get_building(faction + "_" + suffix) != null:
			building_id = faction + "_" + suffix
			break
	var ground: Variant = rts_camera.screen_to_ground(screen_pos)
	if building_id == "" or ground == null or selected.is_empty():
		return
	var point: Vector3 = ground
	runner.submit(SimCommand.make_build(selected, building_id, Fx.from_float(point.x), Fx.from_float(point.z)))


## Queues the first unit each selected building can make.
func debug_produce() -> void:
	var world: SimWorld = runner.world
	for id: int in selected:
		var e: SimEntity = world.get_entity(id)
		if e != null and e.building != null and not e.building.produces.is_empty():
			runner.submit(SimCommand.make_produce(id, e.building.produces[0]))


func _selected_any(predicate: Callable) -> bool:
	for id: int in selected:
		var e: SimEntity = runner.world.get_entity(id)
		if e != null and predicate.call(e):
			return true
	return false


# --- Mouse ---

func _on_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and attack_move_armed:
			order_attack_move(mb.position)
			_mouse_down = false
			return
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
		attack_move_armed = false
		order_at(mb.position)


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
		order_at(pos)


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
	return _pick_unit(screen_pos, true)


## Nearest own (own = true) or visible enemy (own = false) entity within the
## pick radius, or 0.
func _pick_unit(screen_pos: Vector2, own: bool) -> int:
	var world: SimWorld = runner.world
	return _pick(screen_pos, func(e: SimEntity) -> bool:
		if own:
			return e.player_id == local_player_id
		return world.are_enemies(local_player_id, e.player_id) and world.can_see(local_player_id, e.x, e.y))


## Nearest entity accepted by `predicate` within the pick radius, or 0.
func _pick(screen_pos: Vector2, predicate: Callable) -> int:
	var best_id: int = 0
	var best_dist: float = _pick_radius_px()
	for id: int in runner.world.entity_ids:
		if not predicate.call(runner.world.entities[id]):
			continue
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
