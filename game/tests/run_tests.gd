extends SceneTree
## Headless unit-test runner. From the repo root:
##   tools/run_tests.sh          (or tools/run_tests.ps1 on Windows)
## which runs:
##   godot --headless --path game --import
##   godot --headless --path game --script res://tests/run_tests.gd
##
## Runs every method named test_* in every res://tests/unit/test_*.gd file.
## Exit code 0 means everything passed. Script errors (a crash inside a test,
## such as calling a method on null) also count as failures. push_error() calls
## do not, because tests deliberately trigger them to check error handling.

const TEST_DIR: String = "res://tests/unit/"


class ErrorCounter extends Logger:
	var count: int = 0

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_SCRIPT:
			count += 1


func _initialize() -> void:
	# Never read or write the player's real settings from a test.
	GameSettings.file_path = "user://test_settings_unit.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.file_path))
	GameSettings.reset_current()
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	var total: int = 0
	var failed: int = 0
	var files: PackedStringArray = DirAccess.get_files_at(TEST_DIR)
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load(TEST_DIR + file)
		# A script with a parse error still loads, but can't be instantiated.
		if script == null or not script.can_instantiate():
			printerr("FAIL could not load ", file)
			failed += 1
			continue
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			var errors_before: int = errors.count
			var test: TestCase = script.new()
			test.current_test = "%s::%s" % [file.get_basename(), method_name]
			test.call(method_name)
			if errors.count > errors_before:
				test.failures.append("%s: script error (see the log above)" % test.current_test)
			if test.failures.is_empty():
				print("  ok    ", test.current_test)
			else:
				failed += 1
				for message: String in test.failures:
					printerr("  FAIL  ", message)
	OS.remove_logger(errors)
	print("\n%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)
