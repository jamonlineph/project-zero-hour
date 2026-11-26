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


## Orders the player's units to attack an enemy and waits for damage.
func _check_attack(world: SimWorld, selection: SelectionController) -> PackedStringArray:
	var problems: PackedStringArray = []
	var target_id: int = 0
	for id: int in world.entity_ids:
		if world.entities[id].player_id == 2:
			target_id = id
			break
	if target_id == 0:
		problems.append("no enemy unit to attack")
		return problems
	selection.box_select(Rect2(Vector2(-10000, -10000), Vector2(20000, 20000)))
	selection.order_attack(target_id)
	for i: int in 1200:
		await process_frame
		var t: SimEntity = world.get_entity(target_id)
		if t == null or t.hp < t.max_hp:
			return problems
	problems.append("an attack order dealt no damage within 1200 frames")
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
