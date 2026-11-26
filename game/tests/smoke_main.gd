extends SceneTree
## Smoke test: loads the real main scene headless, runs it for a while, selects
## the player's units, issues a move order, and checks that they moved and that
## no errors were logged (script errors or push_error, warnings are ignored).
## Run by tools/run_tests.sh after the unit tests.

class ErrorCounter extends Logger:
	var count: int = 0

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_ERROR or error_type == Logger.ERROR_TYPE_SCRIPT:
			count += 1


var _errors := ErrorCounter.new()


func _initialize() -> void:
	# Never read or write the player's real settings from a test.
	GameSettings.file_path = "user://test_settings_smoke_main.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.file_path))
	GameSettings.reset_current()
	OS.add_logger(_errors)
	_run.call_deferred()


func _run() -> void:
	var failures: PackedStringArray = []
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	for i: int in 10:
		await process_frame

	var selection: SelectionController = main.get("selection")
	var world: SimWorld = main.get("world")
	var game_view: GameView = main.get("game_view")
	if selection == null or world == null or game_view == null:
		failures.append("main scene did not create its selection controller, world or view")
	else:
		failures.append_array(_check_unit_visuals(world, game_view))
		selection.box_select(Rect2(Vector2(-10000, -10000), Vector2(20000, 20000)))
		if selection.selected.is_empty():
			failures.append("box select over the whole screen selected nothing")
		var before: Dictionary = {}
		for id: int in selection.selected:
			before[id] = Vector2i(world.entities[id].x, world.entities[id].y)
		var center: Vector2 = root.get_visible_rect().size * 0.5
		selection.order_move(center + Vector2(120, -60))
		var start_tick: int = world.tick
		for i: int in 120:
			await process_frame
		if world.tick <= start_tick:
			failures.append("the simulation did not advance")
		var moved: int = 0
		for id: int in before:
			var e: SimEntity = world.entities[id]
			if Vector2i(e.x, e.y) != before[id]:
				moved += 1
		if moved == 0:
			failures.append("no selected unit moved after a move order")
		failures.append_array(_check_desktop_controls(main, world, selection))
		failures.append_array(await _check_touch_controls(main, world, selection))
		failures.append_array(await _check_hud_build_and_produce(main, world, selection))
		failures.append_array(await _check_attack(world, selection))
		if game_view.effects == null or game_view.effects.played == 0:
			failures.append("combat played no effects (muzzle flashes, tracers or explosions)")
		if game_view.sounds == null or game_view.sounds.played == 0:
			failures.append("combat played no sounds")
		failures.append_array(await _check_unit_views(world, game_view, selection))
		failures.append_array(_check_fog(main, world, game_view))

	if _errors.count > 0:
		failures.append("%d error(s) were logged" % _errors.count)
	OS.remove_logger(_errors)
	if failures.is_empty():
		print("smoke_main: ok")
		quit(0)
	else:
		for f: String in failures:
			printerr("smoke_main FAIL: ", f)
		quit(1)


## Uses the HUD like a player: build a power plant through the build menu
## and placement, then queue a unit from the HQ's production grid.
func _check_hud_build_and_produce(main: Node, world: SimWorld, selection: SelectionController) -> PackedStringArray:
	var problems: PackedStringArray = []
	var hud: Hud = main.get("hud")
	var placement: PlacementController = main.get("placement")
	var engineer: int = 0
	var hq: int = 0
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.player_id == 1 and e.builder != null and engineer == 0:
			engineer = id
		if e.player_id == 1 and e.def_id.ends_with("_command_hq"):
			hq = id
	selection.select_ids([engineer])
	if hud.command_grid.entry_count() == 0:
		problems.append("selecting an engineer showed no build menu")
		return problems
	var power_slot: int = -1
	var player: SimPlayer = world.get_player(1)
	var i: int = 0
	for def: BuildingDef in world.content.buildings.values():
		if def.faction == player.faction:
			if def.power > 0 and power_slot < 0:
				power_slot = i
			i += 1
	hud.command_grid.activate(power_slot)
	if not placement.active:
		problems.append("the build button did not start placement")
		return problems
	placement.set_ground_point(Fx.from_int(40), Fx.from_int(80))
	if not placement.valid:
		problems.append("placement at (40, 80) m was refused")
		placement.cancel()
		return problems
	var credits_before: int = player.credits
	placement.confirm()
	for f: int in 30:
		await process_frame
	if player.credits >= credits_before:
		problems.append("confirming placement did not start construction")
	selection.select_ids([hq])
	var queued_before: int = world.get_entity(hq).building.queue.size()
	hud.command_grid.activate(0)
	for f: int in 30:
		await process_frame
	var b: SimBuilding = world.get_entity(hq).building
	var made: bool = b.queue.size() > queued_before or b.queue_progress > 0
	for id: int in world.entity_ids:
		if world.entities[id].def_id == "us_engineer" and id != engineer:
			made = true
	if not made:
		problems.append("the production button did not queue a unit")
	return problems


## Attack-moves the player's units toward the enemy and waits for damage.
func _check_attack(world: SimWorld, selection: SelectionController) -> PackedStringArray:
	var problems: PackedStringArray = []
	var enemies: Array[int] = []
	for id: int in world.entity_ids:
		if world.entities[id].player_id == 2:
			enemies.append(id)
	if enemies.is_empty():
		problems.append("no enemy unit to attack")
		return problems
	var first: SimEntity = world.get_entity(enemies[0])
	selection.box_select(Rect2(Vector2(-10000, -10000), Vector2(20000, 20000)))
	selection.runner.submit(SimCommand.make_attack_move(selection.selected, first.x, first.y))
	for i: int in 1500:
		await process_frame
		for id: int in enemies:
			var t: SimEntity = world.get_entity(id)
			if t == null or t.hp < t.max_hp:
				return problems
	problems.append("an attack-move toward the enemy dealt no damage within 1500 frames")
	return problems


## Units whose data names an existing .glb must show that model (not the
## placeholder), and its "team_color" material must have been recolored.
func _check_unit_visuals(world: SimWorld, game_view: GameView) -> PackedStringArray:
	var problems: PackedStringArray = []
	var content: ContentDb = game_view.content
	for id: int in world.entity_ids:
		var def: UnitDef = content.get_unit(world.entities[id].def_id)
		if def == null or not ResourceLoader.exists(def.model_path):
			continue
		var uv: UnitView = game_view.get_view(id)
		if uv == null:
			problems.append("entity %d has no view" % id)
			continue
		if uv.get_node_or_null("Placeholder") != null:
			problems.append("%s shows a placeholder although %s exists" % [def.id, def.model_path])
			continue
		var recolored: bool = false
		for node: Node in uv.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			for i: int in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(i) != null:
					recolored = true
		if not recolored:
			problems.append("%s has no team_color surface that was recolored" % def.id)
	return problems


## P1-22: health bars, veterancy pips, turret aiming and wrecks.
func _check_unit_views(world: SimWorld, game_view: GameView, selection: SelectionController) -> PackedStringArray:
	var problems: PackedStringArray = []
	var tank: int = 0
	var healthy: int = 0
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var v: UnitView = game_view.get_view(id)
		if e.player_id != 1 or v == null or e.building != null:
			continue
		if tank == 0 and v.has_turret():
			tank = id
		if healthy == 0 and e.hp == e.max_hp and v.kind != UnitView.Kind.DRONE:
			healthy = id
	if tank == 0 or healthy == 0:
		problems.append("no own turreted unit or undamaged unit to check views with")
		return problems

	# Turret aiming: aim due east (+X) with a large delta, then compare the
	# turret's real front (+Z in Godot) with the expected direction.
	var tv: UnitView = game_view.get_view(tank)
	tv.aim(tv.global_position + Vector3(20.0, 0.0, 0.0), true, 0.0, 100.0)
	var front: Vector3 = tv.find_child("turret", true, false).global_basis.z
	front.y = 0.0
	if front.normalized().dot(Vector3.RIGHT) < 0.99:
		problems.append("turret did not turn to face its target (front %s)" % front)
	tv.aim(Vector3.ZERO, false, 0.0, 100.0)

	# Health bar: hidden while healthy and unselected, shown when selected.
	var hv: UnitView = game_view.get_view(healthy)
	selection.select_ids([])
	game_view.sync(0.0)
	if hv.status.bar_visible():
		problems.append("an undamaged, unselected unit shows a health bar")
	selection.select_ids([healthy])
	game_view.sync(0.0)
	if not hv.status.bar_visible():
		problems.append("a selected unit shows no health bar")
	selection.select_ids([])

	# Damaged units show a bar at the right fill.
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var v: UnitView = game_view.get_view(id)
		if v != null and v.visible and e.hp < e.max_hp and v.status != null:
			game_view.sync(0.0)
			if not v.status.bar_visible():
				problems.append("damaged %s shows no health bar" % e.def_id)
			elif absf(v.status.health_ratio() - float(e.hp) / float(e.max_hp)) > 0.02:
				problems.append("health bar fill does not match hp for %s" % e.def_id)
			break

	# Veterancy pips follow the rank (the test sets the rank directly).
	var he: SimEntity = world.get_entity(healthy)
	var old_rank: int = he.vet_rank
	he.vet_rank = 2
	game_view.sync(0.0)
	if hv.status.pip_count() != 2:
		problems.append("rank 2 shows %d pips" % hv.status.pip_count())
	he.vet_rank = old_rank
	game_view.sync(0.0)

	# A destroyed vehicle leaves a wreck.
	var made: int = game_view.wrecks_made
	world.apply_damage(world.get_entity(tank), 1000000, "anti_tank", 0)
	for i: int in 10:
		await process_frame
	if world.get_entity(tank) != null:
		problems.append("the tank survived lethal damage")
	elif game_view.wrecks_made <= made or not is_instance_valid(tv) or not tv.is_wreck:
		problems.append("a destroyed tank left no wreck")
	return problems


## P1-27: enemy views are hidden outside vision and the terrain fog texture
## matches the sim's vision grid.
func _check_fog(main: Node, world: SimWorld, game_view: GameView) -> PackedStringArray:
	var problems: PackedStringArray = []
	var fog: FogOfWar = main.get("fog")
	if fog == null:
		problems.append("the match scene has no fog of war")
		return problems
	fog.refresh()
	game_view.sync(0.0)
	var team: int = world.team_of(1)
	var hidden: int = 0
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		var v: UnitView = game_view.get_view(id)
		if v == null or not world.are_enemies(1, e.player_id):
			continue
		var seen: bool = world.can_see(1, e.x, e.y)
		if v.visible != seen:
			problems.append("enemy %s is %s although it is %s" % [e.def_id,
					"drawn" if v.visible else "hidden", "seen" if seen else "not seen"])
		if not seen:
			hidden += 1
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.player_id == 1:
			var want: int = FogOfWar.VISIBLE if world.vision.is_visible(team, e.x, e.y) else FogOfWar.EXPLORED
			var got: int = fog.value_at(Fx.to_float(e.x), Fx.to_float(e.y))
			if got != want:
				problems.append("fog texture is %d under own %s (want %d)" % [got, e.def_id, want])
			break
	# Somewhere on the map should still be unexplored or remembered.
	var dark: int = 0
	for cy: int in world.vision.rows:
		for cx: int in world.vision.cols:
			if fog.value_at(cx * 8.0 + 4.0, cy * 8.0 + 4.0) != FogOfWar.VISIBLE:
				dark += 1
	if dark == 0:
		problems.append("the whole map is lit: fog texture shows no fog anywhere")
	return problems


## P1-23: control groups, camera bookmarks, Space-drag panning, hover and
## cursor states.
func _check_desktop_controls(main: Node, world: SimWorld, selection: SelectionController) -> PackedStringArray:
	var problems: PackedStringArray = []
	var cam: RtsCamera = main.get("rts_camera")
	var pointer: PointerFeedback = main.get("pointer")
	var own: Array[int] = []
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.player_id == 1 and e.mover != null and not e.weapons.is_empty():
			own.append(id)
	if own.size() < 2:
		problems.append("not enough own armed units to test controls")
		return problems

	# Control groups: store, clear, recall, double tap jumps the camera.
	selection.select_ids(own)
	selection.groups.use_group(3, true, false, selection, 0)
	selection.select_ids([])
	cam.focus_on(Vector3(5, 0, 5))
	selection.groups.use_group(3, false, false, selection, 10000)
	if selection.selected != own:
		problems.append("recalling group 3 selected %s, not %s" % [selection.selected, own])
	var before: Vector3 = cam.position
	selection.groups.use_group(3, false, false, selection, 10100)
	var c: Vector3 = selection.groups.center(3, world)
	if cam.position.distance_to(Vector3(c.x, 0, c.z)) > 0.5 or cam.position == before:
		problems.append("double-tapping group 3 did not center the camera on it")

	# Camera bookmarks through real key events: Ctrl+F6 saves, F6 jumps back.
	cam.focus_on(Vector3(30, 0, 30))
	cam._unhandled_input(_key(KEY_F6, true))
	cam.focus_on(Vector3(80, 0, 70))
	cam._unhandled_input(_key(KEY_F6, false))
	if cam.position.distance_to(Vector3(30, 0, 30)) > 0.01:
		problems.append("F6 did not return to the view saved with Ctrl+F6 (at %s)" % cam.position)

	# Space + left-drag pans and does not box-select.
	selection.select_ids([])
	Input.parse_input_event(_key(KEY_SPACE, false))
	Input.flush_buffered_events()
	var start: Vector3 = cam.position
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(400, 300)
	selection._unhandled_input(press)
	cam._unhandled_input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(300, 250)
	drag.relative = Vector2(-100, -50)
	selection._unhandled_input(drag)
	cam._unhandled_input(drag)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.position = drag.position
	selection._unhandled_input(release)
	cam._unhandled_input(release)
	var space_up := _key(KEY_SPACE, false)
	space_up.pressed = false
	Input.parse_input_event(space_up)
	Input.flush_buffered_events()
	if cam.position == start:
		problems.append("Space + drag did not pan the camera")
	if not selection.selected.is_empty():
		problems.append("Space + drag box-selected units")

	# Cursor states and hover.
	selection.select_ids([])
	if pointer.state_for(0, 0) != PointerFeedback.CursorState.DEFAULT:
		problems.append("cursor is not the default with nothing selected")
	if pointer.state_for(own[0], 0) != PointerFeedback.CursorState.SELECT:
		problems.append("cursor over an own unit is not the select cursor")
	selection.select_ids(own)
	if pointer.state_for(0, 0) != PointerFeedback.CursorState.MOVE:
		problems.append("cursor over ground with units selected is not the move cursor")
	if pointer.state_for(0, 99999) != PointerFeedback.CursorState.ATTACK:
		problems.append("cursor over an enemy with armed units selected is not the attack cursor")
	selection.select_ids([])
	cam.focus_on(Vector3(Fx.to_float(world.get_entity(own[1]).x), 0, Fx.to_float(world.get_entity(own[1]).y)))
	var sp: Vector2 = cam.camera.unproject_position(main.get("game_view").get_view(own[1]).global_position)
	pointer.update_at(sp)
	var hv: UnitView = main.get("game_view").get_view(pointer.hovered_id) if pointer.hovered_id != 0 else null
	if hv == null or not hv.is_ring_visible():
		problems.append("hovering an own unit shows no highlight")
	pointer.update_at(Vector2(-500, -500))
	if hv != null and hv.is_ring_visible():
		problems.append("the hover highlight stayed after the mouse left")
	return problems


func _key(code: Key, ctrl: bool) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = true
	k.ctrl_pressed = ctrl
	return k


## P1-24: touch bar (Clear, Box mode, group buttons), long press and the
## radial menu, driven through the same code paths as real touches.
func _check_touch_controls(main: Node, world: SimWorld, selection: SelectionController) -> PackedStringArray:
	var problems: PackedStringArray = []
	var hud: Hud = main.get("hud")
	var cam: RtsCamera = main.get("rts_camera")
	var bar: TouchBar = hud.touch_bar
	if bar == null:
		problems.append("the HUD has no touch bar")
		return problems
	var own: Array[int] = []
	for id: int in world.entity_ids:
		var e: SimEntity = world.entities[id]
		if e.player_id == 1 and e.mover != null and not e.weapons.is_empty():
			own.append(id)

	# Group button: hold stores, Clear deselects, a short tap recalls.
	selection.select_ids(own)
	bar._press_ms[2] = 1000
	bar.release_group(2, 1000 + 700)
	(bar.find_child("Clear", true, false) as Button).pressed.emit()
	if not selection.selected.is_empty():
		problems.append("Clear did not deselect")
	bar._press_ms[2] = 5000
	bar.release_group(2, 5000 + 100)
	if selection.selected != own:
		problems.append("tapping group button 2 did not select the stored group")
	if not bar.group_buttons[1].text.contains("(%d)" % own.size()):
		problems.append("group button 2 does not show its size (%s)" % bar.group_buttons[1].text)

	# Box mode: a one-finger drag selects instead of panning.
	selection.select_ids([])
	var box: Button = bar.find_child("BoxToggle", true, false)
	box.button_pressed = true
	var cam_before: Vector3 = cam.position
	var view_size: Vector2 = main.get_viewport().get_visible_rect().size
	selection.touch.on_touch(_touch(0, Vector2(2, 2), true), 0)
	selection.touch.on_drag(_drag(0, view_size - Vector2(2, 2)), 10)
	selection.touch.on_touch(_touch(0, view_size - Vector2(2, 2), false), 20)
	box.button_pressed = false
	if selection.selected.is_empty():
		problems.append("a drag in box mode selected nothing")
	if cam.position != cam_before:
		problems.append("a drag in box mode panned the camera")

	# Long press: fires once, and releasing afterwards is not a tap.
	var ground := Vector2(view_size.x * 0.5, view_size.y * 0.45)
	selection.select_ids(own)
	selection.touch.on_touch(_touch(0, ground, true), 0)
	if selection.touch.poll_long_press(300) != null:
		problems.append("a long press fired too early")
	var held: Variant = selection.touch.poll_long_press(700)
	if held == null or selection.touch.poll_long_press(800) != null:
		problems.append("a long press did not fire exactly once")
	selection.touch.on_touch(_touch(0, ground, false), 900)

	# Radial menu: offers orders for armed units, and "Move here" moves them.
	var menu: RadialMenu = hud.open_radial(ground)
	if menu == null:
		problems.append("the radial menu did not open for armed units")
		return problems
	var labels: PackedStringArray = menu.button_labels()
	for want: String in ["Attack-move here", "Move here", "Stop"]:
		if not labels.has(want):
			problems.append("the radial menu lacks \"%s\" (has %s)" % [want, labels])
	(menu.find_child("Movehere", true, false) as Button).pressed.emit()
	for i: int in 20:
		await process_frame
	if is_instance_valid(menu) and menu.is_inside_tree():
		problems.append("the radial menu stayed open after a choice")
	var moving: bool = false
	for id: int in own:
		var e: SimEntity = world.get_entity(id)
		if e != null and e.mover.has_target:
			moving = true
	if not moving:
		problems.append("\"Move here\" from the radial menu did not move the units")
	selection.select_ids([])
	if hud.open_radial(ground) != null:
		problems.append("the radial menu opened with nothing selected")
	return problems


func _touch(index: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.position = pos
	t.pressed = pressed
	return t


func _drag(index: int, pos: Vector2) -> InputEventScreenDrag:
	var d := InputEventScreenDrag.new()
	d.index = index
	d.position = pos
	d.relative = Vector2(5, 5)
	return d
