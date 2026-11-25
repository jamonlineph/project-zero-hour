class_name Formation
extends RefCounted
## Deterministic formation offsets, so a group ordered to one point spreads out.


## Returns `count` offsets (fixed-point meters) on a square grid centered on
## (0, 0), filled row by row. `spacing` is fixed-point meters.
static func grid_offsets(count: int, spacing: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if count <= 0:
		return result
	var cols: int = Fx.isqrt(count)
	if cols * cols < count:
		cols += 1
	var rows: int = (count + cols - 1) / cols
	for i: int in count:
		var col: int = i % cols
		var row: int = i / cols
		var ox: int = ((col * 2 - (cols - 1)) * spacing) / 2
		var oy: int = ((row * 2 - (rows - 1)) * spacing) / 2
		result.append(Vector2i(ox, oy))
	return result
