class_name TestCase
extends RefCounted
## Base class for headless unit tests. See res://tests/run_tests.gd.
## Name test methods test_*, and use these helpers instead of assert(),
## which is skipped in release builds and would stop the whole run.

var failures: PackedStringArray = []
var current_test: String = ""


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("expected true. " + message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_fail("expected false. " + message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		_fail("expected <%s> (%s) but got <%s> (%s). %s" % [
			str(expected), type_string(typeof(expected)),
			str(actual), type_string(typeof(actual)), message])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		_fail("did not expect <%s>. %s" % [str(actual), message])


func _fail(text: String) -> void:
	failures.append("%s: %s" % [current_test, text])
