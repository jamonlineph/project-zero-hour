class_name Fx
extends RefCounted
## Deterministic 16.16 fixed-point math for the simulation.
##
## Every simulation quantity that is not a plain count is a fixed-point int:
## the real value multiplied by ONE (65536). GDScript ints are 64-bit, so the
## product of two fixed values is exact while each stays within +/-32768.0
## (MAX_ABS). The simulation never uses float: floats can round differently on
## different CPUs, which would break replays and lockstep multiplayer.

const SHIFT: int = 16
const ONE: int = 1 << SHIFT
const HALF: int = 1 << (SHIFT - 1)
## Largest magnitude (in fixed units) that is safe to multiply.
const MAX_ABS: int = (1 << 31) - 1


## Whole number -> fixed.
static func from_int(value: int) -> int:
	return value * ONE


## numerator / denominator -> fixed. Example: from_ratio(150, 100) is 1.5.
static func from_ratio(numerator: int, denominator: int) -> int:
	assert(denominator != 0, "Fx.from_ratio: denominator is zero")
	return (numerator * ONE) / denominator


## Input boundary ONLY: converts a float (for example a tapped ground point)
## to fixed before it goes into a SimCommand. Never call inside the sim.
static func from_float(value: float) -> int:
	return int(roundf(value * ONE))


## View ONLY: fixed -> float for rendering. Never call inside the sim.
static func to_float(value: int) -> float:
	return float(value) / float(ONE)


## Fixed -> whole number, rounding toward negative infinity.
static func floor_to_int(value: int) -> int:
	return value >> SHIFT


## Fixed -> nearest whole number (halves round up).
static func round_to_int(value: int) -> int:
	return (value + HALF) >> SHIFT


static func mul(a: int, b: int) -> int:
	return (a * b) >> SHIFT


static func div(a: int, b: int) -> int:
	assert(b != 0, "Fx.div: division by zero")
	return (a * ONE) / b


## Fixed-point square root: input and output are fixed. Input must be >= 0.
static func sqrt_fx(value: int) -> int:
	return isqrt(value * ONE)


## Length of the fixed-point vector (dx, dy), returned as fixed.
static func length(dx: int, dy: int) -> int:
	return isqrt(dx * dx + dy * dy)


## Squared length as a raw int. Compare distances without a square root:
## length_sq(dx, dy) <= r * r.
static func length_sq(dx: int, dy: int) -> int:
	return dx * dx + dy * dy


## Integer square root: floor(sqrt(n)) for n >= 0, exact on every platform.
static func isqrt(n: int) -> int:
	assert(n >= 0, "Fx.isqrt: negative input")
	if n < 2:
		return n
	# Newton's method, starting from a power of two that is >= sqrt(n). The
	# sequence decreases until it reaches floor(sqrt(n)).
	var x: int = 1 << ((_bit_length(n) + 1) >> 1)
	while true:
		var y: int = (x + n / x) >> 1
		if y >= x:
			return x
		x = y
	return x


static func _bit_length(n: int) -> int:
	var bits: int = 0
	while n > 0:
		n >>= 1
		bits += 1
	return bits
