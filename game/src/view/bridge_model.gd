class_name BridgeModel
extends RefCounted
## River bridges (P3-11 entities; the deck look from P2-12): a concrete deck
## with railings in three parts along the crossing. When the bridge collapses
## the middle span drops into the river as two broken slabs, and comes back
## once it is repaired. View only.

const DECK := Color(0.52, 0.50, 0.46)
const RAIL := Color(0.30, 0.30, 0.30)
const RUBBLE := Color(0.36, 0.34, 0.31)
const THICKNESS: float = 0.5
const RAIL_HEIGHT: float = 0.9


## A bridge `w_m` by `d_m` meters (x by z), centered on its origin, its deck
## top just above the ground there.
static func make(w_m: float, d_m: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Bridge"
	var along_x: bool = w_m >= d_m
	var length: float = w_m if along_x else d_m
	var width: float = d_m if along_x else w_m
	var parts: Array = [["EndA", -0.375, 0.25], ["Span", 0.0, 0.5], ["EndB", 0.375, 0.25]]
	for p: Array in parts:
		var seg := Node3D.new()
		seg.name = p[0]
		seg.position = _along(along_x, length * float(p[1]))
		root.add_child(seg)
		var len_part: float = length * float(p[2])
		seg.add_child(_box(_size(along_x, len_part, THICKNESS, width), DECK, Vector3(0.0, 0.05 - THICKNESS * 0.5, 0.0)))
		for side: int in [-1, 1]:
			var off: Vector3 = _across(along_x, side * (width * 0.5 - 0.15))
			seg.add_child(_box(_size(along_x, len_part, RAIL_HEIGHT, 0.3), RAIL, off + Vector3(0.0, 0.05 + RAIL_HEIGHT * 0.5, 0.0)))
	var wreck := Node3D.new()
	wreck.name = "Wreck"
	wreck.visible = false
	root.add_child(wreck)
	# The crossing under the deck is dry ground, so the gap gets its own
	# water surface, just above the ground.
	var water := _box(_size(along_x, length * 0.5, 0.04, width * 1.3), Biomes.palette(HouseModel.biome)["water"], Vector3(0.0, 0.03, 0.0))
	water.name = "Water"
	wreck.add_child(water)
	for side: int in [-1, 1]:
		var slab := _box(_size(along_x, length * 0.27, THICKNESS, width * 0.92), RUBBLE, Vector3.ZERO)
		slab.position = _along(along_x, side * length * 0.12) + Vector3(0.0, -0.25, 0.0)
		# Each broken half hangs from its end and dips toward the middle.
		var tilt: float = deg_to_rad(12.0) * side
		if along_x:
			slab.rotation.z = tilt
		else:
			slab.rotation.x = -tilt
		wreck.add_child(slab)
	return root


## Shows the deck whole, or with its middle span fallen into the river.
static func set_collapsed(bridge: Node3D, collapsed: bool) -> void:
	var span: Node3D = bridge.get_node_or_null("Span")
	var wreck: Node3D = bridge.get_node_or_null("Wreck")
	if span == null or wreck == null:
		return
	span.visible = not collapsed
	wreck.visible = collapsed


static func _along(along_x: bool, v: float) -> Vector3:
	return Vector3(v, 0.0, 0.0) if along_x else Vector3(0.0, 0.0, v)


static func _across(along_x: bool, v: float) -> Vector3:
	return Vector3(0.0, 0.0, v) if along_x else Vector3(v, 0.0, 0.0)


static func _size(along_x: bool, length: float, height: float, width: float) -> Vector3:
	return Vector3(length, height, width) if along_x else Vector3(width, height, length)


static func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	mi.position = pos
	return mi
