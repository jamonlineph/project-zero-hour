class_name SimRng
extends RefCounted
## Deterministic random numbers for the simulation (xorshift32).
##
## The same seed gives the same sequence on every platform. Simulation code
## must never call randi(), randf() or RandomNumberGenerator.

const MASK_32: int = 0xFFFFFFFF
## Used instead of 0, because xorshift gets stuck on a zero state.
const ZERO_SEED_REPLACEMENT: int = 0x6D2B79F5

var state: int = ZERO_SEED_REPLACEMENT


func _init(seed_value: int = 1) -> void:
	set_seed(seed_value)


func set_seed(seed_value: int) -> void:
	state = seed_value & MASK_32
	if state == 0:
		state = ZERO_SEED_REPLACEMENT


## Next raw value in [0, 2^32).
func next_u32() -> int:
	var x: int = state
	x ^= (x << 13) & MASK_32
	x ^= x >> 17
	x ^= (x << 5) & MASK_32
	state = x
	return x


## Value in [0, bound). The small modulo bias is fine for gameplay.
func range_int(bound: int) -> int:
	assert(bound > 0, "SimRng.range_int: bound must be positive")
	return next_u32() % bound


## True with probability numerator / denominator.
func chance(numerator: int, denominator: int) -> bool:
	return range_int(denominator) < numerator
