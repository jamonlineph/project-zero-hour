extends SceneTree
## Smoke test for the menus (P1-32): open the main menu, start a skirmish
## against the computer, check the match loaded with an AI opponent, pause
## and resume, and that no errors were logged. Run by tools/run_tests.sh.

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
	GameSettings.file_path = "user://test_settings_smoke_menu.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.file_path))
	GameSettings.reset_current()
	OS.add_logger(_errors)
	_run.call_deferred()


func _run() -> void:
	var failures: PackedStringArray = []
	change_scene_to_file("res://scenes/menu.tscn")
	for i: int in 5:
		await process_frame
	var menu: Node = current_scene
	if menu == null or not menu.has_method("start_skirmish"):
		failures.append("the main menu did not load")
	else:
		failures.append_array(await _check_settings(menu))
		menu.call("start_skirmish")
		for i: int in 20:
			await process_frame
		var game: Node = current_scene
		var runner: SimRunner = game.get("runner") if game != null else null
		if runner == null:
			failures.append("starting a skirmish did not open the game scene")
		else:
			if not runner.ai_players.has(2):
				failures.append("the skirmish has no computer opponent")
			var hqs: int = 0
			for id: int in runner.world.entity_ids:
				if runner.world.entities[id].def_id.ends_with("_command_hq"):
					hqs += 1
			if hqs != 2:
				failures.append("expected 2 HQs, found %d" % hqs)
			var pause: PauseMenu = game.get("pause_menu")
			pause.toggle()
			var tick: int = runner.world.tick
			for i: int in 30:
				await process_frame
			if runner.world.tick != tick:
				failures.append("the game kept running while paused")
			var pause_settings: SettingsMenu = pause.open_settings()
			await process_frame
			pause_settings.close()
			await process_frame
			pause.toggle()
			for i: int in 30:
				await process_frame
			if runner.world.tick == tick:
				failures.append("the game did not resume")
	if _errors.count > 0:
		failures.append("%d error(s) were logged" % _errors.count)
	OS.remove_logger(_errors)
	if failures.is_empty():
		print("smoke_menu: ok")
		quit(0)
	else:
		for f: String in failures:
			printerr("smoke_menu FAIL: ", f)
		quit(1)


## P1-35: the settings screen opens from the main menu, battery saver applies
## at once and is saved, and Back closes it.
func _check_settings(menu: Node) -> PackedStringArray:
	var problems: PackedStringArray = []
	var screen: SettingsMenu = menu.call("open_settings")
	await process_frame
	var saver: Button = screen.find_child("BatterySaver", true, false)
	if saver == null:
		problems.append("the settings screen has no battery saver row")
		return problems
	saver.pressed.emit()
	await process_frame
	if Engine.max_fps != GameSettings.SAVER_FPS:
		problems.append("battery saver did not cap the frame rate (max_fps %d)" % Engine.max_fps)
	var saved := GameSettings.new()
	saved.load_from(GameSettings.file_path)
	if not saved.battery_saver:
		problems.append("battery saver was not saved to the settings file")
	# Turn it back off so the rest of the test runs at normal speed.
	saver = screen.find_child("BatterySaver", true, false)
	saver.pressed.emit()
	await process_frame
	# P1-37: the in-game determinism check runs and matches the stored hash.
	(screen.find_child("DeterminismCheck", true, false) as Button).pressed.emit()
	for i: int in 400:
		await process_frame
		if screen.determinism_result() != "":
			break
	if not screen.determinism_result().begins_with("Match"):
		problems.append("the determinism check did not match: '%s'" % screen.determinism_result())
	screen.close()
	await process_frame
	if is_instance_valid(screen) and screen.is_inside_tree():
		problems.append("Back did not close the settings screen")
	return problems
