extends TestCase
# Cross-device determinism check (P1-37): the stored hash must match what this
# machine computes. After an intended sim change, run tools/regen_golden_replays.sh.


func test_stored_hash_matches_this_machine() -> void:
	var db := ContentDb.new()
	assert_true(db.load_all(), ", ".join(db.errors))
	assert_false(db.determinism_check.is_empty(), "data/determinism_check.json did not load")
	var check := DeterminismCheck.new(db)
	var got: int = check.run()
	assert_eq(got, check.expected,
		"determinism check hash changed; if the sim changed on purpose, run tools/regen_golden_replays.sh")
	assert_true(check.matches())
