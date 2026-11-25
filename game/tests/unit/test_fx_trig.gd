extends TestCase
# Fixed-point angles (P1-01). Reference values are from Python's math module:
# round(sin(a * 2pi / 4096) * 65536).


func test_known_sine_values() -> void:
	var expected: Dictionary = {
		0: 0, 512: 46341, 1024: 65536, 1536: 46341, 2048: 0,
		2560: -46341, 3072: -65536, 3584: -46341, 4096: 0,
		341: 32739, 100: 10014, 3000: -65137,
	}
	for angle: int in expected:
		assert_eq(Fx.sin_a(angle), expected[angle], "sin_a(%d)" % angle)


func test_cosine_and_wrapping() -> void:
	assert_eq(Fx.cos_a(0), Fx.ONE)
	assert_eq(Fx.cos_a(2048), -Fx.ONE)
	assert_eq(Fx.sin_a(-1024), -Fx.ONE)
	assert_eq(Fx.sin_a(4096 + 1024), Fx.ONE)
	assert_eq(Fx.wrap_angle(-1), 4095)


func test_pythagorean_identity() -> void:
	for angle: int in range(0, 4096, 7):
		var s: int = Fx.sin_a(angle)
		var c: int = Fx.cos_a(angle)
		var sum: int = Fx.mul(s, s) + Fx.mul(c, c)
		assert_true(absi(sum - Fx.ONE) <= 3, "sin^2+cos^2 at %d = %d" % [angle, sum])


func test_atan2_cardinal_and_diagonal_directions() -> void:
	assert_eq(Fx.atan2_a(0, 1), 0)
	assert_eq(Fx.atan2_a(1, 1), 512)
	assert_eq(Fx.atan2_a(1, 0), 1024)
	assert_eq(Fx.atan2_a(1, -1), 1536)
	assert_eq(Fx.atan2_a(0, -1), 2048)
	assert_eq(Fx.atan2_a(-1, -1), 2560)
	assert_eq(Fx.atan2_a(-1, 0), 3072)
	assert_eq(Fx.atan2_a(-1, 1), 3584)
	assert_eq(Fx.atan2_a(0, 0), 0)


func test_atan2_round_trip_every_angle() -> void:
	# Pointing a long vector in every one of the 4096 directions must give the
	# same angle back, within one unit.
	var r: int = Fx.from_int(200)
	var worst: int = 0
	for angle: int in Fx.ANGLE_FULL:
		var x: int = Fx.mul(Fx.cos_a(angle), r)
		var y: int = Fx.mul(Fx.sin_a(angle), r)
		var back: int = Fx.atan2_a(y, x)
		worst = maxi(worst, absi(Fx.angle_diff(angle, back)))
	assert_true(worst <= 1, "worst atan2 error %d units" % worst)


func test_atan2_with_python_references() -> void:
	# round(atan2(dy, dx) * 4096 / 2pi) mod 4096
	var cases: Array = [[3, 4, 419], [4, 3, 605], [-5, 12, 3839], [7, -24, 1863], [-1, -1000, 2049], [250, 1, 1021]]
	for c: Array in cases:
		var got: int = Fx.atan2_a(c[0], c[1])
		assert_true(absi(Fx.angle_diff(c[2], got)) <= 1, "atan2(%d, %d) = %d, expected about %d" % [c[0], c[1], got, c[2]])


func test_angle_diff_takes_short_way() -> void:
	assert_eq(Fx.angle_diff(100, 300), 200)
	assert_eq(Fx.angle_diff(4000, 100), 196)
	assert_eq(Fx.angle_diff(100, 4000), -196)
	assert_eq(Fx.angle_diff(0, 2048), 2048)


func test_degrees() -> void:
	assert_eq(Fx.angle_from_degrees(90), 1024)
	assert_eq(Fx.angle_from_degrees(-90), 3072)
	assert_eq(Fx.angle_from_degrees(360), 0)
