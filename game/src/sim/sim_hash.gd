class_name SimHash
extends RefCounted
## 32-bit FNV-1a-style hash over simulation values.
##
## Used to detect desyncs (two machines whose states differ) and in
## determinism tests. Do not replace it with hash(): the engine's hash may
## change between Godot versions.

const OFFSET: int = 2166136261
const PRIME: int = 16777619
const MASK_32: int = 0xFFFFFFFF

var value: int = OFFSET


func add_int(v: int) -> void:
	# Mix both 32-bit halves so every 64-bit int is fully covered.
	_mix(v & MASK_32)
	_mix((v >> 32) & MASK_32)


func add_bool(b: bool) -> void:
	_mix(1 if b else 0)


func add_string(s: String) -> void:
	var bytes: PackedByteArray = s.to_utf8_buffer()
	_mix(bytes.size())
	for b: int in bytes:
		_mix(b)


func _mix(word: int) -> void:
	value = ((value ^ word) * PRIME) & MASK_32
