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
		failures.append_array(await _check_hud_build_and_produce(main, world, selection))
		failures.append_array(await _check_attack(world, selection))

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
