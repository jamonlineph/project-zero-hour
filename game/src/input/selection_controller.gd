class_name SelectionController
extends Node
## Turns pointer input (mouse, trackpad and touch) into selection changes and
## SimCommands. Selection is local UI state; only commands reach the sim.
##
## Mouse: left-click select, left-drag box select (Shift adds), right-click
## move (or attack, on an enemy), A then left-click attack-move, H hold, S stop.
## Keys: Ctrl+1–9 store a control group, 1–9 recall it (twice quickly jumps
## the camera), Shift+1–9 add it. Space + left-drag pans instead of selecting.
## Touch: see TouchGestures (touch_gestures.gd). The HUD adds touch buttons
## (TouchBar) and the long-press radial menu (RadialMenu).
## See docs/design/controls-and-ui.md.

signal selection_changed(ids: Array[int])
## A finger held still on the battlefield (the HUD opens the radial menu).
signal long_pressed(screen_pos: Vector2)

const DRAG_THRESHOLD_PX: float = 10.0
const MIN_PICK_RADIUS_PX: float = 28.0

var runner: SimRunner
var game_view: GameView
var rts_camera: RtsCamera
var box_overlay: SelectionBox
var local_player_id: int = 1
var selected: Array[int] = []

## True after pressing A: the next left-click is an attack-move target.
var attack_move_armed: bool = false
## After the Patrol button: the next click or tap is the patrol's far end.
var patrol_armed: bool = false
## After G or the Guard button: the next click or tap picks what to guard.
var guard_armed: bool = false
## After the Spoof button: the next click or tap is where to spoof drones (P2-03).
var spoof_armed: bool = false
## A targeted commander power waiting for its point (P2-09b), or "".
var power_armed: String = ""
## Building placement gets every pointer event first while it is active.
var placement: PlacementController
## Command-grid hotkeys (CommandGrid.handle_key): checked before our own keys.
var hotkey_handler: Callable
var groups := ControlGroups.new()
var _mouse_down: bool = false
var _mouse_dragging: bool = false
var _mouse_start: Vector2 = Vector2.ZERO

## Touch gestures live in their own class; see touch_gestures.gd.
var touch := TouchGestures.new(self)


func setup(sim_runner: SimRunner, view: GameView, cam: RtsCamera, overlay: SelectionBox, player_id: int) -> void:
	runner = sim_runner
	game_view = view
	rts_camera = cam
	box_overlay = overlay
	local_player_id = player_id


func _process(_delta: float) -> void:
	_prune_selection()
	var held: Variant = touch.poll_long_press(Time.get_ticks_msec())
	if held != null:
		long_pressed.emit(held)


func _unhandled_input(event: InputEvent) -> void:
	if placement != null and placement.handle_input(event):
		return
	if hotkey_handler.is_valid() and hotkey_handler.call(event):
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventScreenTouch:
		touch.on_touch(event as InputEventScreenTouch, Time.get_ticks_msec())
	elif event is InputEventScreenDrag:
		touch.on_drag(event as InputEventScreenDrag, Time.get_ticks_msec())
	elif event is InputEventKey and groups.handle_key(event as InputEventKey, self):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cmd_stop"):
		order_stop()
	elif event.is_action_pressed("cmd_hold"):
		order_hold()
	elif event.is_action_pressed("cmd_attack_move") and not selected.is_empty():
		attack_move_armed = true
	elif event.is_action_pressed("cmd_guard") and not selected.is_empty():
		guard_armed = true



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


## Runs a pending attack-move, patrol or guard order at a click or tap.
## Returns true if one was pending.
func handle_armed_click(screen_pos: Vector2) -> bool:
	if attack_move_armed:
		order_attack_move(screen_pos)
		return true
	if patrol_armed:
		order_patrol(screen_pos)
		return true
	if power_armed != "":
		var power: String = power_armed
		power_armed = ""
		var at: Variant = rts_camera.screen_to_ground(screen_pos)
		if at != null:
			runner.submit(SimCommand.make_use_power(power, Fx.from_float((at as Vector3).x), Fx.from_float((at as Vector3).z)))
		return true
	if spoof_armed:
		spoof_armed = false
		var ground: Variant = rts_camera.screen_to_ground(screen_pos)
		if ground != null and not selected.is_empty():
			var p: Vector3 = ground
			runner.submit(SimCommand.make_spoof(selected, Fx.from_float(p.x), Fx.from_float(p.z)))
		return true
	if guard_armed:
		guard_armed = false
		var ward: int = pick_own_entity(screen_pos)
		if ward != 0:
			order_guard(ward)
		return true
	return false


func disarm() -> void:
	attack_move_armed = false
	patrol_armed = false
	guard_armed = false
	spoof_armed = false
	power_armed = ""


## Patrol between where the units are and the ground point there.
func order_patrol(screen_pos: Vector2) -> void:
	patrol_armed = false
	if selected.is_empty():
		return
	var ground: Variant = rts_camera.screen_to_ground(screen_pos)
	if ground == null:
		return
	var point: Vector3 = ground
	runner.submit(SimCommand.make_patrol(selected, Fx.from_float(point.x), Fx.from_float(point.z)))
	game_view.show_move_marker(point)


## Armed units in the selection guard an own unit or building.
func order_guard(ward_id: int) -> void:
	if not selected.is_empty():
		runner.submit(SimCommand.make_guard(selected, ward_id))


## Own unit or building nearest a screen position (within the pick radius), or 0.
func pick_own_entity(screen_pos: Vector2) -> int:
	return _pick(screen_pos, func(e: SimEntity) -> bool:
		return e.player_id == local_player_id and (e.mover != null or e.building != null))


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
		order_rally(screen_pos)
		return
	order_move(screen_pos)


## Sets the rally point of every selected building to the ground there.
func order_rally(screen_pos: Vector2) -> void:
	var world: SimWorld = runner.world
	var ground: Variant = rts_camera.screen_to_ground(screen_pos)
	if ground == null:
		return
	var point: Vector3 = ground
	for id: int in selected:
		if world.entities.has(id) and world.entities[id].building != null:
			runner.submit(SimCommand.make_rally(id, Fx.from_float(point.x), Fx.from_float(point.z)))
	game_view.show_move_marker(point)


func _selected_any(predicate: Callable) -> bool:
	for id: int in selected:
		var e: SimEntity = runner.world.get_entity(id)
		if e != null and predicate.call(e):
			return true
	return false


# --- Mouse ---

func _on_mouse_button(mb: InputEventMouseButton) -> void:
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and rts_camera.space_pan_held():
		return  # Space + drag pans the camera (RtsCamera handles it)
	if mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and handle_armed_click(mb.position):
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
					select_same_type_on_screen(hit)
				elif hit != 0:
					select_ids([hit], mb.shift_pressed)
				elif not mb.shift_pressed:
					select_ids([])
	elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
		if attack_move_armed or patrol_armed or guard_armed or spoof_armed or power_armed != "":
			disarm()   # right-click cancels a pending order
			return
		order_at(mb.position)


func _on_mouse_motion(mm: InputEventMouseMotion) -> void:
	if not _mouse_down:
		return
	if not _mouse_dragging and mm.position.distance_to(_mouse_start) > DRAG_THRESHOLD_PX:
		_mouse_dragging = true
	if _mouse_dragging:
		box_overlay.show_box(Rect2(_mouse_start, mm.position - _mouse_start).abs())


# --- Helpers ---

func _own_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in runner.world.entity_ids:
		var e: SimEntity = runner.world.entities[id]
		if e.player_id == local_player_id and e.strike == null and not e.sensor and e.ttl == 0:   # strikes, sensors and timed units can't be selected
			ids.append(id)
	return ids


func _screen_pos(entity_id: int) -> Variant:
	var v: UnitView = game_view.get_view(entity_id)
	if v == null or rts_camera.camera.is_position_behind(v.global_position):
		return null
	return rts_camera.camera.unproject_position(v.global_position)


func _pick_radius_px() -> float:
	return maxf(MIN_PICK_RADIUS_PX, get_viewport().get_visible_rect().size.y * 0.045)


## Public picking for hover feedback: own unit (own = true) or visible enemy.
func pick_unit(screen_pos: Vector2, own: bool) -> int:
	return _pick_unit(screen_pos, own)


## True if any selected entity matches `predicate`.
func selected_any(predicate: Callable) -> bool:
	return _selected_any(predicate)


## Own unit nearest to a screen position, within the pick radius, or 0.
func _pick_own_unit(screen_pos: Vector2) -> int:
	return _pick_unit(screen_pos, true)


## Nearest own (own = true) or visible enemy (own = false) entity within the
## pick radius, or 0.
func _pick_unit(screen_pos: Vector2, own: bool) -> int:
	var world: SimWorld = runner.world
	return _pick(screen_pos, func(e: SimEntity) -> bool:
		if own:
			return e.player_id == local_player_id and e.strike == null and not e.sensor and e.ttl == 0
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


func select_same_type_on_screen(entity_id: int) -> void:
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
