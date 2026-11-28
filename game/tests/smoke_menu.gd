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
		# P2-12: Riverside is the default skirmish map, and the map button cycles.
		if menu.get("map_id") != "riverside":
			failures.append("the default skirmish map is not Riverside")
		var map_button: Button = menu.find_child("Map", true, false)
		map_button.pressed.emit()
		if menu.get("map_id") == "riverside":
			failures.append("the map button did not change the map")
		# 2v2 (P3-23b): the mode button switches to a four-start map and back.
		var mode_button: Button = menu.find_child("Mode", true, false)
		mode_button.pressed.emit()
		var map4: MapDef = menu.get("content").get_map(str(menu.get("map_id")))
		if not menu.get("team_mode") or map4 == null or map4.start_positions.size() != 4:
			failures.append("the mode button didn't switch to a 2v2 map")
		mode_button.pressed.emit()
		# Cycle on round to Riverside, however many maps there are.
		for i: int in 20:
			if menu.get("map_id") == "riverside":
				break
			map_button.pressed.emit()
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
			if runner.world.map_width != Fx.from_int(256) or game.get_node_or_null("MapFeatures/Water") == null:
				failures.append("the skirmish did not start on Riverside with its river drawn")
			var pause: PauseMenu = game.get("pause_menu")
			pause.toggle()
			await process_frame
			# The overlay must cover the screen (it once kept a zero size, so
			# the end screen sat in a corner).
			if pause.size.x < 640.0 or pause.size.y < 360.0:
				failures.append("the pause menu is %s, not full screen" % str(pause.size))
			var tick: int = runner.world.tick
			for i: int in 30:
				await process_frame
			if runner.world.tick != tick:
				failures.append("the game kept running while paused")
			var pause_settings: SettingsMenu = pause.open_settings()
			await process_frame
			if pause_settings.size.x < 640.0:
				failures.append("the settings screen is %s, not full screen" % str(pause_settings.size))
			pause_settings.close()
			await process_frame
			pause.toggle()
			for i: int in 30:
				await process_frame
			if runner.world.tick == tick:
				failures.append("the game did not resume")
			failures.append_array(await _check_save_and_load(game))
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


## P3-22: save from the pause menu, then load it through the real game scene
## and arrive at the same tick and state.
func _check_save_and_load(game: Node) -> PackedStringArray:
	var problems: PackedStringArray = []
	SaveGame.dir = "user://test_saves_smoke/"
	var pause: PauseMenu = game.get("pause_menu")
	pause.toggle()
	await process_frame
	var runner: SimRunner = game.get("runner")
	var saved_tick: int = runner.world.tick
	var saved_hash: int = runner.world.state_hash()
	var path: String = pause.save_game()
	if path == "":
		problems.append("the pause menu could not save the game")
		return problems
	MatchConfig.load_save = SaveGame.read(path)
	change_scene_to_file("res://scenes/main.tscn")
	for i: int in 600:
		await process_frame
		var g: Node = current_scene
		if g != null and g.get("runner") != null and g.get("loader") == null:
			break
	var loaded: SimRunner = current_scene.get("runner")
	if loaded == null:
		problems.append("loading did not open the game scene")
	elif current_scene.get("loader") != null:
		problems.append("loading never finished")
	elif loaded.world.tick < saved_tick:
		problems.append("the loaded game stopped at tick %d, before %d" % [loaded.world.tick, saved_tick])
	elif loaded.world.tick == saved_tick and loaded.world.state_hash() != saved_hash:
		problems.append("the loaded game differs from the saved one")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	SaveGame.dir = "user://saves/"
	return problems


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
