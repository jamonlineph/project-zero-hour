extends TestCase
# Expected values come from an independent Python implementation of xorshift32.
# If these fail on any platform, the sim is not deterministic there.


func test_known_sequence() -> void:
	var rng := SimRng.new(12345)
	var expected: Array[int] = [3336926330, 1697253807, 2816511904, 1955480042, 718842323]
	for value: int in expected:
		assert_eq(rng.next_u32(), value)


func test_zero_seed_is_replaced() -> void:
	var rng := SimRng.new(0)
	assert_eq(rng.next_u32(), 1085196063)
	assert_eq(rng.next_u32(), 2447379481)


func test_range_stays_in_bounds() -> void:
	var rng := SimRng.new(99)
	for i: int in 1000:
		var v: int = rng.range_int(7)
		assert_true(v >= 0 and v < 7, "value %d out of range" % v)


func test_same_seed_same_sequence() -> void:
	var a := SimRng.new(42)
	var b := SimRng.new(42)
	for i: int in 100:
		assert_eq(a.next_u32(), b.next_u32())
