extends TestCase


func test_from_int_and_back() -> void:
	assert_eq(Fx.from_int(3), 3 * 65536)
	assert_eq(Fx.floor_to_int(Fx.from_int(-7)), -7)
	assert_eq(Fx.round_to_int(Fx.from_ratio(5, 2)), 3)


func test_from_ratio() -> void:
	assert_eq(Fx.from_ratio(150, 100), Fx.ONE + Fx.HALF)
	assert_eq(Fx.from_ratio(-1, 2), -Fx.HALF)


func test_mul_and_div() -> void:
	var a: int = Fx.from_ratio(3, 2)
	var b: int = Fx.from_int(4)
	assert_eq(Fx.mul(a, b), Fx.from_int(6))
	assert_eq(Fx.div(b, a), Fx.from_ratio(8, 3))
	assert_eq(Fx.mul(Fx.from_int(-2), Fx.from_int(3)), Fx.from_int(-6))


func test_isqrt_exact_values() -> void:
	var cases: Dictionary = {0: 0, 1: 1, 2: 1, 3: 1, 4: 2, 15: 3, 16: 4, 17: 4, 99: 9, 100: 10}
	for n: int in cases:
		assert_eq(Fx.isqrt(n), cases[n], "isqrt(%d)" % n)
	var big: int = 1 << 56
	assert_eq(Fx.isqrt(big), 1 << 28)
	assert_eq(Fx.isqrt(big - 1), (1 << 28) - 1)


func test_length_and_sqrt() -> void:
	assert_eq(Fx.length(Fx.from_int(3), Fx.from_int(4)), Fx.from_int(5))
	assert_eq(Fx.length(Fx.from_int(-3), Fx.from_int(-4)), Fx.from_int(5))
	assert_eq(Fx.sqrt_fx(Fx.from_int(9)), Fx.from_int(3))
	assert_eq(Fx.sqrt_fx(Fx.from_int(2)), 92681)  # floor(sqrt(2) * 65536)


func test_float_boundary_round_trip() -> void:
	assert_eq(Fx.from_float(1.5), Fx.from_ratio(3, 2))
	assert_true(absf(Fx.to_float(Fx.from_ratio(1, 4)) - 0.25) < 0.000001)
