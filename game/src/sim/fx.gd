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


# --- Angles -----------------------------------------------------------------
# Binary angles: 4096 units per full turn. Angle 0 points along +X and angles
# grow toward +Y (sim Y is Godot +Z). Always wrap with wrap_angle().

const ANGLE_FULL: int = 4096
const ANGLE_HALF: int = 2048
const ANGLE_QUARTER: int = 1024
const ANGLE_MASK: int = ANGLE_FULL - 1
const _OCTANT: int = 512


## Whole degrees -> binary angle (truncated), e.g. 90 -> 1024.
static func angle_from_degrees(degrees: int) -> int:
	return wrap_angle((degrees * ANGLE_FULL) / 360)


static func wrap_angle(angle: int) -> int:
	return angle & ANGLE_MASK


## Sine of a binary angle, as fixed (-ONE..ONE). Exact table lookup.
static func sin_a(angle: int) -> int:
	var a: int = angle & ANGLE_MASK
	var idx: int = a & (ANGLE_QUARTER - 1)
	match a >> 10:
		0:
			return TrigTable.SINE_QUARTER[idx]
		1:
			return TrigTable.SINE_QUARTER[ANGLE_QUARTER - idx]
		2:
			return -TrigTable.SINE_QUARTER[idx]
		_:
			return -TrigTable.SINE_QUARTER[ANGLE_QUARTER - idx]


static func cos_a(angle: int) -> int:
	return sin_a(angle + ANGLE_QUARTER)


## Binary angle of the vector (dx, dy), within 1 unit of the true angle.
## Inputs are any ints (fixed or raw) within MAX_ABS. atan2_a(0, 0) is 0.
static func atan2_a(dy: int, dx: int) -> int:
	if dx == 0 and dy == 0:
		return 0
	var ax: int = absi(dx)
	var ay: int = absi(dy)
	# Angle in the first octant: theta = atan(small / big), 0..512.
	var small: int = mini(ax, ay)
	var big: int = maxi(ax, ay)
	var lo: int = 0
	var hi: int = _OCTANT
	# Largest theta with tan(theta) <= small / big, found without division:
	# sin(theta) * big <= cos(theta) * small.
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if TrigTable.SINE_QUARTER[mid] * big <= TrigTable.SINE_QUARTER[ANGLE_QUARTER - mid] * small:
			lo = mid
		else:
			hi = mid - 1
	var theta: int = lo
	# Round to the nearer of theta and theta + 1.
	if theta < _OCTANT:
		var err_lo: int = small * TrigTable.SINE_QUARTER[ANGLE_QUARTER - theta] - big * TrigTable.SINE_QUARTER[theta]
		var err_hi: int = big * TrigTable.SINE_QUARTER[theta + 1] - small * TrigTable.SINE_QUARTER[ANGLE_QUARTER - theta - 1]
		if err_hi < err_lo:
			theta += 1
	if ay > ax:
		theta = ANGLE_QUARTER - theta
	if dx < 0:
		theta = ANGLE_HALF - theta
	if dy < 0:
		theta = ANGLE_FULL - theta
	return theta & ANGLE_MASK


## Shortest signed turn from `from` to `to`, in (-2048, 2048].
static func angle_diff(from: int, to: int) -> int:
	var d: int = (to - from) & ANGLE_MASK
	if d > ANGLE_HALF:
		d -= ANGLE_FULL
	return d


static func _bit_length(n: int) -> int:
	var bits: int = 0
	while n > 0:
		n >>= 1
		bits += 1
	return bits
